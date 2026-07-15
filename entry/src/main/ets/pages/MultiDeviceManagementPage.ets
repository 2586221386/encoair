/**
 * 多设备管理页面
 * 移植自 OppoPodsManager-main，针对 Air5 Pro 优化
 *
 * UI 结构（从上到下）:
 *   1. 双设备连接开关
 *   2. 优先设备设置（点击弹出选项列表）
 *   3. 已配对设备列表（点击触发连接/断开确认框）
 */

import { OppoEarphoneManager } from '../manager/OppoEarphoneManager';
import { MultiDeviceManager } from '../manager/MultiDeviceManager';
import { ConnectedDeviceInfo, MultiPriorityInfo, MultiDeviceOpResult } from '../common/ConnectedDeviceInfo';
import {
  cardBg, borderColor, textPrimary, textSecondary, textTertiary, textMuted,
  descTextColor, accentPrimary, accentGreen
} from '../common/AppTheme';

@Entry
@Component
export struct MultiDeviceManagementPage {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = true;

  @State deviceList: ConnectedDeviceInfo[] = [];
  @State priorityInfo: MultiPriorityInfo = new MultiPriorityInfo();
  @State dualDeviceEnabled: boolean = false;
  @State hasDualDevice: boolean = false;
  @State hasMultiConnectManage: boolean = false;
  @State isEarphoneConnected: boolean = false;
  @State toastMessage: string = '';
  @State isLoading: boolean = false;
  @State refreshKey: number = 0;

  /** 优先设备选择器弹窗可见 */
  @State showPrioritySelector: boolean = false;
  /** 确认对话框状态 */
  @State showConfirmDialog: boolean = false;
  @State confirmTitle: string = '';
  @State confirmTargetName: string = '';
  @State confirmTargetAddr: string = '';
  /** 确认操作类型: 'connect' | 'disconnect' */
  @State confirmAction: string = '';

  private manager: OppoEarphoneManager = OppoEarphoneManager.getInstance();
  private multiDeviceManager: MultiDeviceManager = this.manager.multiDeviceManager;
  private connectingPollTimer: number = -1;
  /** 连接状态监视定时器 */
  private connectionMonitorTimer: number = -1;
  private readonly POLL_INTERVAL_MS: number = 2000;
  private readonly MONITOR_INTERVAL_MS: number = 3000;

  // ==================== 生命周期 ====================

  aboutToAppear(): void {
    this.initMultiDevice();
  }

  aboutToDisappear(): void {
    this.stopConnectingPoll();
    this.stopConnectionMonitor();
    this.multiDeviceManager.onDeviceListChanged = null;
    this.multiDeviceManager.onPriorityChanged = null;
    this.multiDeviceManager.onDualDeviceToggleChanged = null;
    this.multiDeviceManager.onOperationResult = null;
  }

  private initMultiDevice(): void {
    const caps = this.manager.getDeviceCapabilities();
    this.hasDualDevice = caps.dualDeviceSupported;
    this.hasMultiConnectManage = caps.multiConnectManageSupported;
    this.isEarphoneConnected = this.manager.getIsConnected();
    // 从 AppStorage 读取双设备开关状态（与 MainPageContent 联动）
    this.dualDeviceEnabled = AppStorage.get<boolean>('dualDeviceEnabled') ?? this.manager.getDualDeviceEnabled();

    this.multiDeviceManager.setCapabilities(this.hasDualDevice, this.hasMultiConnectManage);

    this.multiDeviceManager.onDeviceListChanged = (devices: ConnectedDeviceInfo[]) => {
      this.deviceList = [...devices];
      this.refreshKey++;
      this.isLoading = false;
      // 设备列表还在更新时也顺便刷新连接状态
      this.isEarphoneConnected = this.manager.getIsConnected();
      this.checkAndStartPolling(devices);
    };

    this.multiDeviceManager.onPriorityChanged = (info: MultiPriorityInfo) => {
      this.priorityInfo = info;
    };

    this.multiDeviceManager.onDualDeviceToggleChanged = (enabled: boolean) => {
      this.dualDeviceEnabled = enabled;
      // 同步到 AppStorage，让 MainPageContent 也能感知变化
      AppStorage.setOrCreate('dualDeviceEnabled', enabled);
    };

    this.multiDeviceManager.onOperationResult = (result: MultiDeviceOpResult, message: string) => {
      this.showToast(result === MultiDeviceOpResult.SUCCESS ? '✓ ' + message : '✗ ' + message);
    };

    // 启动连接状态监视（每3秒检查耳机是否断连）
    this.startConnectionMonitor();

    if (this.isEarphoneConnected && this.hasDualDevice) {
      this.refreshDeviceList();
      if (this.hasMultiConnectManage) {
        this.multiDeviceManager.queryPriorityDevice();
      }
    }
  }

  // ==================== 数据刷新 ====================

  private refreshDeviceList(): void {
    this.isLoading = true;
    this.multiDeviceManager.queryDeviceList();
    setTimeout(() => {
      if (this.isLoading) {
        this.isLoading = false;
      }
    }, 3000);
  }

  private showToast(message: string): void {
    this.toastMessage = message;
    setTimeout(() => {
      this.toastMessage = '';
    }, 2500);
  }

  // ==================== 连接中轮询 ====================

  private checkAndStartPolling(devices: ConnectedDeviceInfo[]): void {
    const hasConnecting = devices.some((d: ConnectedDeviceInfo) => d.connectionState === 1);
    if (hasConnecting) {
      if (this.connectingPollTimer === -1) {
        console.info('[MultiDevicePage] 检测到连接中设备，启动主动轮询');
        this.startConnectingPoll();
      }
    } else {
      if (this.connectingPollTimer !== -1) {
        console.info('[MultiDevicePage] 所有设备连接状态已稳定，停止轮询');
        this.stopConnectingPoll();
      }
    }
  }

  private startConnectingPoll(): void {
    if (this.connectingPollTimer !== -1) {
      return;
    }
    this.connectingPollTimer = setInterval(() => {
      console.info('[MultiDevicePage] 连接中轮询查询...');
      this.multiDeviceManager.queryDeviceList();
    }, this.POLL_INTERVAL_MS);
  }

  private stopConnectingPoll(): void {
    if (this.connectingPollTimer !== -1) {
      clearInterval(this.connectingPollTimer);
      this.connectingPollTimer = -1;
    }
  }

  // ==================== 连接状态监视 ====================

  /** 启动连接状态监视，检测耳机断连后更新 UI */
  private startConnectionMonitor(): void {
    if (this.connectionMonitorTimer !== -1) {
      return;
    }
    this.connectionMonitorTimer = setInterval(() => {
      const connected = this.manager.getIsConnected();
      if (this.isEarphoneConnected !== connected) {
        console.info(`[MultiDevicePage] 连接状态变化: ${this.isEarphoneConnected} -> ${connected}`);
        this.isEarphoneConnected = connected;
      }
    }, this.MONITOR_INTERVAL_MS);
  }

  /** 停止连接状态监视 */
  private stopConnectionMonitor(): void {
    if (this.connectionMonitorTimer !== -1) {
      clearInterval(this.connectionMonitorTimer);
      this.connectionMonitorTimer = -1;
    }
  }

  // ==================== 确认对话框 ====================

  private openConfirmDialog(action: string, addr: string, name: string): void {
    this.confirmAction = action;
    this.confirmTargetAddr = addr;
    this.confirmTargetName = name;
    if (action === 'connect') {
      this.confirmTitle = '连接设备';
    } else {
      this.confirmTitle = '断开设备';
    }
    this.showConfirmDialog = true;
  }

  private executeConfirmAction(): void {
    this.showConfirmDialog = false;
    if (this.confirmAction === 'connect') {
      this.multiDeviceManager.connectDevice(this.confirmTargetAddr);
    } else if (this.confirmAction === 'disconnect') {
      this.multiDeviceManager.disconnectDevice(this.confirmTargetAddr);
    }
  }

  // ==================== 辅助方法 ====================

  private getDeviceIcon(deviceType: number): string {
    switch (deviceType) {
      case 0: return '📱';
      case 1: return '💻';
      case 2: return '📋';
      case 3: return '⌚';
      default: return '📱';
    }
  }

  private getConnStateText(device: ConnectedDeviceInfo): string {
    if (device.isCurrentDevice) {
      return '已连接（本机）';
    }
    if (device.connectionState === 2) {
      return '已连接';
    }
    if (device.connectionState === 1) {
      return '连接中...';
    }
    return '';
  }

  private getConnStateColor(device: ConnectedDeviceInfo): string {
    if (device.connectionState === 2) {
      return '#4CAF50';
    }
    if (device.connectionState === 1) {
      return '#FF9800';
    }
    return '#9E9E9E';
  }

  /** 当前优先设备显示文本 */
  private getPriorityDisplayText(): string {
    if (this.priorityInfo.autoMode) {
      return '自动选择';
    }
    if (this.priorityInfo.priorityAddress) {
      // 从设备列表中查找对应名称
      const found = this.deviceList.find((d) => d.address === this.priorityInfo.priorityAddress);
      if (found) {
        return found.getDisplayName();
      }
      return this.priorityInfo.priorityAddress;
    }
    return '自动选择';
  }

  /** 可用于优先选择的设备（所有已配对设备） */
  private getSelectableDevices(): ConnectedDeviceInfo[] {
    return this.deviceList;
  }

  // ==================== 构建 UI ====================

  build() {
    Stack() {
      Scroll() {
        Column() {
          // ---- 标题 ----
          Text('多设备管理')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(textPrimary(this.isDarkMode))
            .margin({ top: 20 })

          // ====== 1. 双设备连接开关 ======
          if (this.hasDualDevice) {
            Column() {
              Row() {
                Text('双设备连接')
                  .fontSize(15)
                  .fontColor(textPrimary(this.isDarkMode))
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.dualDeviceEnabled })
                  .selectedColor(accentPrimary)
                  .switchPointColor('#FFFFFF')
                  .enabled(this.isEarphoneConnected)
                  .onChange((isOn: boolean) => {
                    if (!this.isEarphoneConnected) {
                      return;
                    }
                    this.dualDeviceEnabled = isOn;
                    this.multiDeviceManager.setDualDeviceEnabled(isOn);
                    // 同步到 AppStorage，与 MainPageContent 联动
                    AppStorage.setOrCreate('dualDeviceEnabled', isOn);
                    if (isOn) {
                      setTimeout(() => {
                        this.refreshDeviceList();
                      }, 500);
                    }
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            }
            .width('85%')
            .borderRadius(16)
            .backgroundColor(cardBg(this.isDarkMode))
            .border({ width: 1, color: borderColor(this.isDarkMode) })
            .margin({ top: 24 })
          }

          // ====== 2. 优先设备设置（仅在已连接、双设备开启且支持时显示） ======
          if (this.hasDualDevice && this.isEarphoneConnected && this.dualDeviceEnabled && this.hasMultiConnectManage) {
            Column() {
              Row() {
                Column() {
                  Text('优先设备')
                    .fontSize(14)
                    .fontColor(textSecondary(this.isDarkMode))
                  Text(this.getPriorityDisplayText())
                    .fontSize(13)
                    .fontColor(textPrimary(this.isDarkMode))
                    .fontWeight(FontWeight.Medium)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text('›')
                  .fontSize(22)
                  .fontColor(textTertiary(this.isDarkMode))
              }
              .width('100%')
              .padding({ left: 16, right: 12, top: 14, bottom: 14 })
              .onClick(() => {
                this.showPrioritySelector = true;
              })
            }
            .width('85%')
            .borderRadius(16)
            .backgroundColor(cardBg(this.isDarkMode))
            .border({ width: 1, color: borderColor(this.isDarkMode) })
            .margin({ top: 12 })
          }

          // ====== 3. 已配对设备列表 ======
          if (this.hasDualDevice && this.dualDeviceEnabled && this.isEarphoneConnected) {
            Column() {
              Row() {
                Text('已配对设备')
                  .fontSize(14)
                  .fontColor(textSecondary(this.isDarkMode))
                  .layoutWeight(1)

                Row() {
                  Text('🔄')
                    .fontSize(14)
                  Text(' 刷新')
                    .fontSize(12)
                    .fontColor(textTertiary(this.isDarkMode))
                }
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .borderRadius(12)
                .border({ width: 1, color: borderColor(this.isDarkMode) })
                .onClick(() => {
                  this.refreshDeviceList();
                  if (this.hasMultiConnectManage) {
                    this.multiDeviceManager.queryPriorityDevice();
                  }
                })
              }
              .width('100%')
              .padding({ left: 16, right: 12, top: 14, bottom: 4 })

              if (this.isLoading && this.deviceList.length === 0) {
                Row() {
                  LoadingProgress()
                    .width(20)
                    .height(20)
                    .color(accentPrimary)
                  Text(' 获取设备列表...')
                    .fontSize(12)
                    .fontColor(textTertiary(this.isDarkMode))
                    .margin({ left: 6 })
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .padding({ top: 20, bottom: 16 })
              } else if (this.deviceList.length === 0) {
                Text('暂无已配对设备')
                  .fontSize(13)
                  .fontColor(textMuted(this.isDarkMode))
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 20, bottom: 16 })
              } else {
                Column() {
                  ForEach(this.deviceList, (device: ConnectedDeviceInfo) => {
                    this.DeviceRowBuilder(device)
                  }, (device: ConnectedDeviceInfo): string => {
                    return 'dev_' + device.address + '_r' + this.refreshKey.toString();
                  })
                }
                .width('100%')
                .padding({ bottom: 8 })
              }
            }
            .width('85%')
            .borderRadius(16)
            .backgroundColor(cardBg(this.isDarkMode))
            .border({ width: 1, color: borderColor(this.isDarkMode) })
            .margin({ top: 12 })
          }

          // ====== 未连接 / 不支持提示 ======
          if (!this.isEarphoneConnected) {
            Column() {
              Text('🔌')
                .fontSize(36)
              Text('请先连接耳机')
                .fontSize(14)
                .fontColor(textSecondary(this.isDarkMode))
                .margin({ top: 8 })
            }
            .width('85%')
            .borderRadius(16)
            .backgroundColor(cardBg(this.isDarkMode))
            .border({ width: 1, color: borderColor(this.isDarkMode) })
            .margin({ top: 24 })
            .padding({ top: 30, bottom: 30 })
            .alignItems(HorizontalAlign.Center)
          }

          if (!this.hasDualDevice && this.isEarphoneConnected) {
            Column() {
              Text('ℹ️')
                .fontSize(36)
              Text('当前设备不支持双设备连接')
                .fontSize(14)
                .fontColor(textSecondary(this.isDarkMode))
                .margin({ top: 8 })
            }
            .width('85%')
            .borderRadius(16)
            .backgroundColor(cardBg(this.isDarkMode))
            .border({ width: 1, color: borderColor(this.isDarkMode) })
            .margin({ top: 24 })
            .padding({ top: 30, bottom: 30 })
            .alignItems(HorizontalAlign.Center)
          }

          // 底部间距
          Column().height(120)
        }
        .width('100%')
        .padding({ top: this.statusBarHeight })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // ---- Toast ----
      if (this.toastMessage) {
        Text(this.toastMessage)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor('#CC333333')
          .borderRadius(20)
          .padding({ left: 20, right: 20, top: 10, bottom: 10 })
          .position({ bottom: 80 })
      }

      // ---- 优先设备选择器弹窗 ----
      if (this.showPrioritySelector) {
        Column() {
          // 半透明遮罩
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .onClick(() => {
          this.showPrioritySelector = false;
        })

        Column() {
          Text('选择优先设备')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(textPrimary(this.isDarkMode))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 20, bottom: 8 })

          // "自动选择" 按钮
          Row() {
            Text('🔄')
              .fontSize(18)
              .margin({ right: 10 })
            Text('自动选择')
              .fontSize(15)
              .fontColor(textPrimary(this.isDarkMode))
              .layoutWeight(1)
            if (this.priorityInfo.autoMode) {
              Text('✓')
                .fontSize(16)
                .fontColor(accentGreen)
            }
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 14, bottom: 14 })
          .onClick(() => {
            this.showPrioritySelector = false;
            this.multiDeviceManager.restoreAutoSwitch();
          })

          Divider()
            .strokeWidth(0.5)
            .color(borderColor(this.isDarkMode))
            .margin({ left: 20, right: 20 })

          // 设备列表（可滚动的子列表）
          if (this.getSelectableDevices().length > 0) {
            Scroll() {
              Column() {
                ForEach(this.getSelectableDevices(), (device: ConnectedDeviceInfo) => {
                  Row() {
                    Text(this.getDeviceIcon(device.deviceType))
                      .fontSize(18)
                      .margin({ right: 10 })
                    Text(device.getDisplayName())
                      .fontSize(15)
                      .fontColor(textPrimary(this.isDarkMode))
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (!this.priorityInfo.autoMode &&
                        this.priorityInfo.priorityAddress === device.address) {
                      Text('✓')
                        .fontSize(16)
                        .fontColor(accentGreen)
                    }
                  }
                  .width('100%')
                  .padding({ left: 20, right: 20, top: 14, bottom: 14 })
                  .onClick(() => {
                    this.showPrioritySelector = false;
                    this.multiDeviceManager.setPriorityDevice(device.address);
                  })
                }, (device: ConnectedDeviceInfo): string => {
                  return 'sel_' + device.address;
                })
              }
              .width('100%')
            }
            .height(Math.min(this.getSelectableDevices().length * 52, 260))
            .scrollBar(BarState.Off)
          } else {
            Text('暂无已配对设备')
              .fontSize(13)
              .fontColor(textMuted(this.isDarkMode))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 20, bottom: 16 })
          }

          Blank().height(20)
        }
        .width('85%')
        .backgroundColor(cardBg(this.isDarkMode))
        .borderRadius(20)
        .border({ width: 1, color: borderColor(this.isDarkMode) })
        .position({ x: '7.5%', y: '30%' })
      }

      // ---- 确认对话框 ----
      if (this.showConfirmDialog) {
        // 遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#80000000')
          .onClick(() => {
            this.showConfirmDialog = false;
          })

        Column() {
          Text(this.confirmTitle)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(textPrimary(this.isDarkMode))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 24, bottom: 4 })

          Text(this.confirmTargetName)
            .fontSize(14)
            .fontColor(textSecondary(this.isDarkMode))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ bottom: 4 })

          Text(this.confirmTargetAddr)
            .fontSize(11)
            .fontColor(textTertiary(this.isDarkMode))
            .fontFamily('monospace')
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ bottom: 16 })

          Divider()
            .strokeWidth(0.5)
            .color(borderColor(this.isDarkMode))

          Row() {
            Button('取消')
              .fontSize(15)
              .fontColor(textSecondary(this.isDarkMode))
              .backgroundColor('#00000000')
              .layoutWeight(1)
              .height(48)
              .onClick(() => {
                this.showConfirmDialog = false;
              })

            Divider()
              .strokeWidth(0.5)
              .color(borderColor(this.isDarkMode))
              .vertical(true)
              .height(48)

            Button('确认')
              .fontSize(15)
              .fontColor('#FFFFFF')
              .backgroundColor(accentPrimary)
              .layoutWeight(1)
              .height(48)
              .onClick(() => {
                this.executeConfirmAction();
              })
          }
          .width('100%')
          .height(48)
        }
        .width('80%')
        .backgroundColor(cardBg(this.isDarkMode))
        .borderRadius(20)
        .border({ width: 1, color: borderColor(this.isDarkMode) })
        .position({ x: '10%', y: '35%' })
      }
    }
    .width('100%')
    .height('100%')
  }

  // ==================== @Builder 方法 ====================

  @Builder
  DeviceRowBuilder(device: ConnectedDeviceInfo) {
    Row() {
      Text(this.getDeviceIcon(device.deviceType))
        .fontSize(22)
        .margin({ right: 12 })

      Column() {
        Text(device.getDisplayName())
          .fontSize(14)
          .fontColor(textPrimary(this.isDarkMode))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.getConnStateText(device)) {
          Text(this.getConnStateText(device))
            .fontSize(12)
            .fontColor(this.getConnStateColor(device))
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 12, top: 12, bottom: 12 })
    .onClick(() => {
      if (device.connectionState === 2) {
        // 已连接 → 确认断开
        this.openConfirmDialog('disconnect', device.address, device.getDisplayName());
      } else if (device.connectionState === 1) {
        // 连接中 → 无操作
      } else {
        // 断开 → 确认连接
        this.openConfirmDialog('connect', device.address, device.getDisplayName());
      }
    })
  }
}
