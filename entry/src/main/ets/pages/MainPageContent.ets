import { OppoEarphoneManager, BatteryInfo, ConnectionStatus, WearState, WearStatus, getAncModeName, SPATIAL_AUDIO_OFF, SPATIAL_AUDIO_FIXED, SPATIAL_AUDIO_HEAD_TRACKING } from '../manager/OppoEarphoneManager';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import router from '@ohos.router';
import { pageBg, cardBg, statusBg, btnInactiveBg, btnSubBg, textPrimary, textSecondary, textTertiary, textMuted, textHint, accentGreen, accentRed, accentOrange, accentBlue, accentGold, accentPrimary, cancelOrange, chargingBadgeBg, lowBattBadgeBg, hexTextColor, disconnectedGray, grayBtn, tipTextColor, watermarkText, dotSeparator } from '../common/AppTheme';

/**
 * 电量卡片子组件
 * 使用 @Prop 装饰器与父组件 @State 建立单向响应式绑定，确保电量数据变化能驱动 UI 更新
 * 注意：@Builder 按值传参无法建立响应式依赖，是导致 UI 不更新的根因
 */
@Component
struct BatteryCardComponent {
  @Prop battery: number = -1;
  @Prop charging: boolean = false;
  @StorageProp('isDarkMode') isDarkMode: boolean = true;
  private label: string = '';
  private iconType: string = 'L';

  getBatteryColor(): string {
    if (this.battery < 0) {
      return disconnectedGray(this.isDarkMode);
    }
    if (this.charging) {
      return accentGold(this.isDarkMode);
    }
    if (this.battery < 20) {
      return accentRed;
    }
    if (this.battery < 60) {
      return accentOrange;
    }
    return accentGreen;
  }

  getBatteryText(): string {
    return this.battery < 0 ? '--' : `${this.battery}%`;
  }

  build() {
    Column() {
      // 设备图标
      Text(this.iconType === 'L' ? '🎧' : this.iconType === 'R' ? '🎧' : '🔋')
        .fontSize(30)

      // 环形电量进度条
      Stack() {
        Progress({ value: this.battery < 0 ? 0 : this.battery, total: 100, type: ProgressType.Ring })
          .width(100)
          .height(100)
          .color(this.getBatteryColor())
          .backgroundColor(btnInactiveBg(this.isDarkMode))

        // 中间电量百分比
        Text(this.getBatteryText())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(textPrimary(this.isDarkMode))
      }
      .width(100)
      .height(100)
      .margin({ top: 12 })

      // 设备名称
      Text(this.label)
        .fontSize(14)
        .fontColor(textSecondary(this.isDarkMode))
        .margin({ top: 10 })

      // 充电状态
      if (this.charging) {
        Row() {
          Text('⚡')
            .fontSize(14)
          Text('充电中')
            .fontSize(13)
            .fontColor(accentGold(this.isDarkMode))
            .margin({ left: 2 })
        }
        .margin({ top: 6 })
        .padding({ left: 10, right: 10, top: 3, bottom: 3 })
        .borderRadius(12)
        .backgroundColor(chargingBadgeBg(this.isDarkMode))
      } else if (this.battery >= 0 && this.battery < 20) {
        Text('电量低')
          .fontSize(13)
          .fontColor(accentRed)
          .margin({ top: 6 })
          .padding({ left: 10, right: 10, top: 3, bottom: 3 })
          .borderRadius(12)
          .backgroundColor(lowBattBadgeBg(this.isDarkMode))
      }
    }
    .width('30%')
    .padding({ top: 24, bottom: 20, left: 12, right: 12 })
    .borderRadius(20)
    .backgroundColor(cardBg(this.isDarkMode))
    .alignItems(HorizontalAlign.Center)
  }
}

/**
 * 共用主页面内容（API 22/23 复用）
 * 由 Index.ets / IndexOld.ets 作为 TabContent 子组件使用
 */
@Component
export struct MainPageContent {
  /** 底部留白（API23=100 为悬浮TabBar留空间, API22=0） */
  bottomPadding: number = 0;
  /** HEX原始数据变化回调，通知父组件传给 SettingsPage */
  onRawHexLogChange: (hex: string) => void = () => {};
  @StorageProp('isDarkMode') isDarkMode: boolean = true;
  @State connectionStatus: ConnectionStatus = 'disconnected';
  @State leftBattery: number = -1;
  @State leftCharging: boolean = false;
  @State rightBattery: number = -1;
  @State rightCharging: boolean = false;
  @State caseBattery: number = -1;
  @State caseCharging: boolean = false;
  @State macAddress: string = '';
  @State hasPermission: boolean = false;
  @State scanTipVisible: boolean = false;
  // HEX原始数据展示
  @State rawHexLog: string = '';
  @State showRawData: boolean = false;
  // ANC模式
  @State ancMode: number = 1;
  // 佩戴状态
  @State leftWear: WearState = WearState.DISCONNECTED;
  @State rightWear: WearState = WearState.DISCONNECTED;
  @State caseWear: WearState = WearState.DISCONNECTED;
  // 游戏模式
  @State gameModeEnabled: boolean = false;
  // 空间音频模式（0=关闭, 1=固定/开启, 2=头部追踪）
  @State spatialAudioMode: number = SPATIAL_AUDIO_OFF;
  // 设备能力缓存（连接后从 Manager 同步，驱动 UI 条件渲染）
  @State capsSpatialAudio: boolean = false;
  @State capsSpatialSoundSwitch: boolean = false;
  @State capsAdaptiveAnc: boolean = false;
  @State capsGameSound: boolean = false;
  @State gameSoundEnabled: boolean = false;
  // 智能 ANC 实时档位
  @State intelligentAncLevel: string = '';
  // 设备能力缓存 — EQ 预设列表
  @State eqPresetNames: Record<number, string> = {};
  @State eqPresetIds: number[] = [];
  // 固件版本和编解码器
  @State firmwareVersion: string = '';
  @State codecName: string = '--';
  @State deviceModelName: string = '';
  // 双设备连接（通过 AppStorage 与多设备管理页双向联动）
  @StorageLink('dualDeviceEnabled') dualDeviceEnabled: boolean = false;
  // 佩戴检测
  @StorageLink('wearDetectionEnabled') wearDetectionEnabled: boolean = false;
  // EQ预设
  @StorageProp('currentEqPreset') currentEqPreset: number = -1;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  // TabBar
  @State currentIndex: number = 0;

  private manager: OppoEarphoneManager = OppoEarphoneManager.getInstance();

  aboutToAppear(): void {
    // 设置应用上下文，用于桌面卡片数据刷新
    this.manager.setContext(getContext(this) as common.UIAbilityContext);
    this.manager.setBatteryCallback((info: BatteryInfo) => {
        console.info(`[Index] 收到电量更新: 左=${info.leftBattery}, 右=${info.rightBattery}, 仓=${info.caseBattery}`);
        // 断开连接时电量为-1，直接重置UI电量显示
        if (info.leftBattery < 0 && info.rightBattery < 0 && info.caseBattery < 0) {
          this.leftBattery = -1;
          this.rightBattery = -1;
          this.caseBattery = -1;
          this.leftCharging = false;
          this.rightCharging = false;
          this.caseCharging = false;
          return;
        }
        // 仅响应整十电量数据（0, 10, 20, ..., 100），非整十不刷新UI
        if (info.leftBattery >= 0 && info.leftBattery % 10 === 0) {
          this.leftBattery = info.leftBattery;
          this.leftCharging = info.leftCharging;
        }
        if (info.rightBattery >= 0 && info.rightBattery % 10 === 0) {
          this.rightBattery = info.rightBattery;
          this.rightCharging = info.rightCharging;
        }
        if (info.caseBattery >= 0 && info.caseBattery % 10 === 0) {
          this.caseBattery = info.caseBattery;
          this.caseCharging = info.caseCharging;
        }
      });
    this.manager.setStatusCallback((status: ConnectionStatus) => {
        this.connectionStatus = status;
        if (status === 'connected' || status === 'subscribed') {
          this.macAddress = this.manager.getMacAddress();
        }
        if (status === 'subscribed') {
          // 同步设备能力到 @State，驱动空间音频 UI 条件渲染
          let caps = this.manager.getDeviceCapabilities();
          this.capsSpatialAudio = caps.spatialAudioSupported;
          this.capsSpatialSoundSwitch = caps.spatialSoundSwitchSupported;
          this.capsAdaptiveAnc = caps.adaptiveSupported;
          this.capsGameSound = caps.gameSoundSupported;
          // 同步 EQ 预设列表
          this.eqPresetNames = this.manager.getEqPresetNames();
          this.eqPresetIds = this.manager.getEqPresetIds();
          // 同步设备型号
          this.deviceModelName = caps.modelName !== 'Unknown' && caps.modelName !== '' ? caps.modelName : this.manager.getMacAddress();
        }
        if (status === 'disconnected') {
          this.macAddress = '';
        }
      });
    this.manager.setRawDataCallback((hex: string) => {
        let timestamp = new Date().toLocaleTimeString();
        let newLine = `[${timestamp}] ${hex}`;
        let lines = this.rawHexLog ? this.rawHexLog.split('\n') : [];
        lines.push(newLine);
        if (lines.length > 20) {
          lines = lines.slice(lines.length - 20);
        }
        this.rawHexLog = lines.join('\n');
        // 通知父组件，以便 SettingsPage 获取 HEX 数据
        this.onRawHexLogChange(this.rawHexLog);
      });
    this.manager.setAncCallback((mode: number) => {
        this.ancMode = mode;
        console.info(`[Index] ANC模式: ${getAncModeName(mode)}`);
      });
    this.manager.setWearCallback((wear: WearStatus) => {
        this.leftWear = wear.left;
        this.rightWear = wear.right;
        this.caseWear = wear.case;
        console.info(`[Index] 佩戴状态: L=${wear.left}, R=${wear.right}, C=${wear.case}`);
      });
    this.manager.setGameModeCallback((enabled: boolean) => {
        this.gameModeEnabled = enabled;
        console.info(`[Index] 游戏模式: ${enabled ? '开启' : '关闭'}`);
      });
    this.manager.setGameSoundCallback((enabled: boolean) => {
        this.gameSoundEnabled = enabled;
        console.info(`[Index] 游戏音效: ${enabled ? '开启' : '关闭'}`);
      });
    this.manager.setSpatialAudioCallback((mode: number) => {
        this.spatialAudioMode = mode;
        console.info(`[Index] 空间音频模式: ${mode}`);
      });
    this.manager.setDualDeviceCallback((enabled: boolean) => {
        this.dualDeviceEnabled = enabled;
        // 同步到 AppStorage，与多设备管理页联动
        AppStorage.setOrCreate('dualDeviceEnabled', enabled);
        console.info(`[Index] 双设备连接: ${enabled ? '开启' : '关闭'}`);
      });
    this.manager.setEqPresetCallback((preset: number) => {
        this.currentEqPreset = preset;
        console.info(`[Index] EQ预设: ${this.eqPresetNames[preset] ?? '未知'}`);
      });
    this.manager.setFirmwareCallback((version: string) => {
        this.firmwareVersion = version;
      });
    this.manager.setCodecCallback((codec: number) => {
        this.codecName = this.manager.getCodecName();
      });
    this.manager.setIntelligentAncCallback((level: string) => {
        this.intelligentAncLevel = level;
        console.info(`[Index] 智能 ANC 档位: ${level}`);
      });
    
    // 立即请求权限并开始监听
    this.requestBluetoothPermissionAndStartMonitor();
  }

  aboutToDisappear(): void {
    this.manager.disconnect(true);
  }

  /**
   * 请求蓝牙权限
   */
  async requestBluetoothPermission(): Promise<void> {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let atManager = abilityAccessCtrl.createAtManager();
      let permissions: Array<Permissions> = ['ohos.permission.ACCESS_BLUETOOTH'];
      let result = await atManager.requestPermissionsFromUser(context, permissions);
      this.hasPermission = result.authResults[0] === 0;
      if (!this.hasPermission) {
        console.warn('[Index] 蓝牙权限被拒绝');
      }
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[Index] 请求权限失败: ${error.message}`);
    }
  }

  /**
   * 请求蓝牙权限并立即开始监听
   */
  async requestBluetoothPermissionAndStartMonitor(): Promise<void> {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let atManager = abilityAccessCtrl.createAtManager();
      let permissions: Array<Permissions> = ['ohos.permission.ACCESS_BLUETOOTH'];
      let result = await atManager.requestPermissionsFromUser(context, permissions);
      this.hasPermission = result.authResults[0] === 0;
      
      if (this.hasPermission) {
        console.info('[Index] 蓝牙权限已获取，立即开始持续监听...');
        // 权限获取成功后，立即启动持续监听模式
        this.manager.startContinuousMonitor();
      } else {
        console.warn('[Index] 蓝牙权限被拒绝');
      }
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[Index] 请求权限失败: ${error.message}`);
    }
  }

  /**
   * 获取连接状态文本
   */
  getStatusText(): string {
    switch (this.connectionStatus) {
      case 'disconnected':
        return '蓝牙已断开，请点击重新连接...';
      case 'scanning':
        return '正在扫描耳机...';
      case 'connecting':
        return '正在连接...';
      case 'connected':
        return '正在发现服务...';
      case 'subscribed':
        return '已连接';
      default:
        return '未知';
    }
  }

  /**
   * 获取连接状态颜色
   */
  getStatusColor(): string {
    switch (this.connectionStatus) {
      case 'disconnected':
        return disconnectedGray(this.isDarkMode);
      case 'scanning':
        return accentBlue(this.isDarkMode);
      case 'connecting':
        return accentOrange;
      case 'connected':
        return accentBlue(this.isDarkMode);
      case 'subscribed':
        return accentGreen;
      default:
        return disconnectedGray(this.isDarkMode);
    }
  }

  /**
   * 判断是否正在处理中（扫描/连接/发现服务）
   */
  isBusy(): boolean {
    return this.connectionStatus === 'scanning' ||
      this.connectionStatus === 'connecting' ||
      this.connectionStatus === 'connected';
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          // 标题区域
          this.TitleSection();

          // 连接状态区域
          this.StatusSection();

          // 电量卡片区域
          this.BatterySection();

          // 设备状态区域 (ANC/佩戴/游戏模式)
          this.DeviceStatusSection();

          // 操作按钮区域
          this.ActionSection();

          // 底部提示
          this.TipSection();
        }
        .width('100%')
        .padding({ top: this.statusBarHeight, bottom: this.bottomPadding })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(pageBg(this.isDarkMode))
  }

  // ============== 标题区域 ==============
  @Builder TitleSection() {
    Column() {
      Text('Air5 Pro')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(textPrimary(this.isDarkMode))
        .letterSpacing(1)

      Text('耳机助手')
        .fontSize(16)
        .fontColor(textTertiary(this.isDarkMode))
        .margin({ top: 6 })
    }
    .margin({ top: 12 })
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  // ============== 连接状态区域 ==============
  @Builder StatusSection() {
    Column() {
      Row() {
        // 状态指示灯
        Row()
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(this.getStatusColor())

        Text(this.getStatusText())
          .fontSize(15)
          .fontColor(this.getStatusColor())
          .margin({ left: 8 })
          .fontWeight(FontWeight.Medium)

        if (this.macAddress) {
          Text(this.macAddress)
            .fontSize(12)
            .fontColor(textMuted(this.isDarkMode))
            .margin({ left: 10 })
            .fontFamily('monospace')
        }
      }
    }
    .width('85%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .borderRadius(20)
    .backgroundColor(statusBg(this.isDarkMode))
    .margin({ top: 32 })
    .alignItems(HorizontalAlign.Center)
  }

  // ============== 电量卡片区域 ==============
  @Builder BatterySection() {
    Row() {
      BatteryCardComponent({ battery: this.leftBattery, charging: this.leftCharging, label: '左耳', iconType: 'L' })
      BatteryCardComponent({ battery: this.rightBattery, charging: this.rightCharging, label: '右耳', iconType: 'R' })
      BatteryCardComponent({ battery: this.caseBattery, charging: this.caseCharging, label: '充电仓', iconType: 'C' })
    }
    .transition(TransitionEffect.opacity(0.3))
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .margin({ top: 32 })
    .padding({ left: 12, right: 12 })
  }

  // ============== 操作按钮区域 ==============
  @Builder ActionSection() {
    Column() {
      if (this.connectionStatus === 'disconnected') {
        // 未连接 - 显示重连按钮
        Button() {
          Row() {
            Text('🔄')
              .fontSize(18)
            Text('  重新连接')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
          }
        }
        .width('80%')
        .height(52)
        .backgroundColor(accentPrimary)
        .borderRadius(24)
        .enabled(this.hasPermission)
        .opacity(this.hasPermission ? 1.0 : 0.5)
        .onClick(() => {
          if (this.hasPermission) {
            this.manager.startAutoConnect();
          }
        })
      } else if (this.isBusy()) {
        // 处理中 - 显示取消按钮
        Button() {
          Row() {
            Text('⏹')
              .fontSize(18)
            Text('  取消')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
          }
        }
        .width('80%')
        .height(52)
        .backgroundColor(accentOrange)
        .borderRadius(24)
        .onClick(() => {
          this.manager.disconnect();
        })
      } else {
        // 已连接 - 显示断开按钮
        Button() {
          Row() {
            Text('🔗')
              .fontSize(18)
            Text('  断开连接')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
          }
        }
        .width('80%')
        .height(52)
        .backgroundColor(accentRed)
        .borderRadius(24)
        .onClick(() => {
          this.manager.disconnect();
        })
      }

      // 权限未授予时的提示
      if (!this.hasPermission) {
        Text('请授予蓝牙权限后使用')
          .fontSize(13)
          .fontColor(accentRed)
          .margin({ top: 12 })
      }
    }
    .margin({ top: 32 })
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  // ============== HEX原始数据区域 ==============
  @Builder RawDataSection() {
    Column() {
      // 标题行，可点击展开/收起
      Row() {
        Text('HEX 原始数据')
          .fontSize(14)
          .fontColor(textSecondary(this.isDarkMode))
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(this.showRawData ? '收起 ▲' : '展开 ▼')
          .fontSize(12)
          .fontColor(textHint(this.isDarkMode))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .onClick(() => {
        this.showRawData = !this.showRawData;
      })

      if (this.showRawData) {
        Scroll() {
          Text(this.rawHexLog || '等待数据...')
            .fontSize(11)
            .fontColor(hexTextColor(this.isDarkMode))
            .fontFamily('monospace')
            .width('100%')
            .copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .height(120)
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
      }
    }
    .width('85%')
    .borderRadius(20)
    .backgroundColor(cardBg(this.isDarkMode))
    .margin({ top: 24 })
    .clip(true)
  }

  // ============== 设备状态区域 ==============
  @Builder DeviceStatusSection() {
    Column() {
      // ANC 标题
      Row() {
        Text('🎵')
          .fontSize(18)
        Text(' ANC 模式')
          .fontSize(14)
          .fontColor(textSecondary(this.isDarkMode))
          .margin({ left: 6 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // ANC 三个按键（降噪、关闭、通透）
      if (this.connectionStatus === 'subscribed') {
        Row() {
          // 降噪按钮
          Column() {
            Button('降噪')
              .fontSize(14)
              .fontWeight(this.ancMode === 2 || this.ancMode === 5 || this.ancMode === 6 || this.ancMode === 7 || this.ancMode === 8 ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.ancMode === 2 || this.ancMode === 5 || this.ancMode === 6 || this.ancMode === 7 || this.ancMode === 8 ? '#FFFFFF' : textSecondary(this.isDarkMode))
              .width('90%')
              .height(45)
              .backgroundColor(this.ancMode === 2 || this.ancMode === 5 || this.ancMode === 6 || this.ancMode === 7 || this.ancMode === 8 ? accentPrimary : btnInactiveBg(this.isDarkMode))
              .borderRadius(16)
              .onClick(() => {
                this.manager.setAncMode(2);
              })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          // 自适应降噪按钮（仅支持设备如 Free4 时显示）
          if (this.capsAdaptiveAnc) {
            Column() {
              Button('自适应')
                .fontSize(14)
                .fontWeight(this.ancMode === 4 ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.ancMode === 4 ? '#FFFFFF' : textSecondary(this.isDarkMode))
                .width('90%')
                .height(45)
                .backgroundColor(this.ancMode === 4 ? accentPrimary : btnInactiveBg(this.isDarkMode))
                .borderRadius(16)
                .onClick(() => {
                  this.manager.setAncMode(4);
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }

          // 关闭按钮
          Column() {
            Button('关闭')
              .fontSize(14)
              .fontWeight(this.ancMode === 1 ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.ancMode === 1 ? '#FFFFFF' : textSecondary(this.isDarkMode))
              .width('90%')
              .height(45)
              .backgroundColor(this.ancMode === 1 ? accentPrimary : btnInactiveBg(this.isDarkMode))
              .borderRadius(16)
              .onClick(() => {
                this.manager.setAncMode(1);
              })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          // 通透按钮
          Column() {
            Button('通透')
              .fontSize(14)
              .fontWeight(this.ancMode === 3 ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.ancMode === 3 ? '#FFFFFF' : textSecondary(this.isDarkMode))
              .width('90%')
              .height(45)
              .backgroundColor(this.ancMode === 3 ? accentPrimary : btnInactiveBg(this.isDarkMode))
              .borderRadius(16)
              .onClick(() => {
                this.manager.setAncMode(3);
              })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 4 })

        // 降噪子模式选择（智能/轻度/中度/深度）
        if (this.isNoiseCancellationMode()) {
          Row() {
            // 智能降噪按钮
            Column() {
              Button('智能')
                .fontSize(13)
                .fontWeight(this.ancMode === 5 ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.ancMode === 5 ? '#FFFFFF' : textTertiary(this.isDarkMode))
                .width('90%')
                .height(36)
                .backgroundColor(this.ancMode === 5 ? accentPrimary : btnSubBg(this.isDarkMode))
                .borderRadius(16)
                .onClick(() => {
                  this.manager.setAncMode(5);
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)

            // 轻度降噪按钮
            Column() {
              Button('轻度')
                .fontSize(13)
                .fontWeight(this.ancMode === 6 ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.ancMode === 6 ? '#FFFFFF' : textTertiary(this.isDarkMode))
                .width('90%')
                .height(36)
                .backgroundColor(this.ancMode === 6 ? accentPrimary : btnSubBg(this.isDarkMode))
                .borderRadius(16)
                .onClick(() => {
                  this.manager.setAncMode(6);
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)

            // 中度降噪按钮
            Column() {
              Button('中度')
                .fontSize(13)
                .fontWeight(this.ancMode === 7 ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.ancMode === 7 ? '#FFFFFF' : textTertiary(this.isDarkMode))
                .width('90%')
                .height(36)
                .backgroundColor(this.ancMode === 7 ? accentPrimary : btnSubBg(this.isDarkMode))
                .borderRadius(16)
                .onClick(() => {
                  this.manager.setAncMode(7);
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)

            // 深度降噪按钮
            Column() {
              Button('深度')
                .fontSize(13)
                .fontWeight(this.ancMode === 8 ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.ancMode === 8 ? '#FFFFFF' : textTertiary(this.isDarkMode))
                .width('90%')
                .height(36)
                .backgroundColor(this.ancMode === 8 ? accentPrimary : btnSubBg(this.isDarkMode))
                .borderRadius(16)
                .onClick(() => {
                  this.manager.setAncMode(8);
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 4 })
        }
        // 智能降噪实时档位显示
        if (this.ancMode === 5 && this.intelligentAncLevel) {
          Row() {
            Text('📊').fontSize(14)
            Text(' 当前档位: ' + this.intelligentAncLevel)
              .fontSize(12).fontColor(accentGreen).margin({ left: 4 })
          }
          .width('100%').padding({ left: 16, right: 16, bottom: 8 })
        }
      } else {
        Text('--')
          .fontSize(14)
          .fontColor(textMuted(this.isDarkMode))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 20, bottom: 20 })
      }

      // 佩戴状态
      Row() {
        Text('👂')
          .fontSize(18)
        Text(' 佩戴状态')
          .fontSize(14)
          .fontColor(textSecondary(this.isDarkMode))
          .margin({ left: 6 })

        Blank()

        if (this.connectionStatus === 'subscribed') {
          Row() {
            Text(`L:${this.getWearText(this.leftWear)}`)
              .fontSize(12)
              .fontColor(this.getWearColor(this.leftWear))
            Text('  ')
            Text(`R:${this.getWearText(this.rightWear)}`)
              .fontSize(12)
              .fontColor(this.getWearColor(this.rightWear))
            Text('  ')
            Text(`C:${this.getWearText(this.caseWear)}`)
              .fontSize(12)
              .fontColor(this.getWearColor(this.caseWear))
          }
        } else {
          Text('--')
            .fontSize(14)
            .fontColor(textMuted(this.isDarkMode))
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })

      // 游戏模式
      Row() {
        Text('🎮')
          .fontSize(18)
        Text(' 游戏模式')
          .fontSize(14)
          .fontColor(textSecondary(this.isDarkMode))
          .margin({ left: 6 })

        Blank()

        if (this.connectionStatus === 'subscribed') {
          Button(this.gameModeEnabled ? '已开启' : '已关闭')
            .fontSize(13)
            .height(32)
            .backgroundColor(this.gameModeEnabled ? accentGreen : grayBtn(this.isDarkMode))
            .borderRadius(16)
            .onClick(() => {
              // 切换游戏模式
              this.manager.setGameMode(!this.gameModeEnabled);
            })
        } else {
          Text('--')
            .fontSize(14)
            .fontColor(textMuted(this.isDarkMode))
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })

      // 游戏音效（仅支持设备）
      if (this.capsGameSound) {
        Row() {
          Text('🎵').fontSize(18)
          Text(' 游戏音效').fontSize(14).fontColor(textSecondary(this.isDarkMode)).margin({ left: 6 })
          Blank()
          if (this.connectionStatus === 'subscribed') {
            Button(this.gameSoundEnabled ? '已开启' : '已关闭')
              .fontSize(13).height(32)
              .backgroundColor(this.gameSoundEnabled ? accentGreen : grayBtn(this.isDarkMode))
              .borderRadius(16)
              .onClick(() => {
                this.manager.setGameSoundEnabled(!this.gameSoundEnabled);
              })
          } else {
            Text('--').fontSize(14).fontColor(textMuted(this.isDarkMode))
          }
        }
        .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 12 })
      }

      // 空间音频（按能力动态渲染）
      if (this.capsSpatialAudio) {
        // 支持头部追踪 (X3) → 三段式: 关闭 | 固定 | 头跟
        Row() {
          Text('🎧').fontSize(18)
          Text(' 空间音频').fontSize(14).fontColor(textSecondary(this.isDarkMode)).margin({ left: 6 })
          Blank()
          if (this.connectionStatus === 'subscribed') {
            Button('关闭').fontSize(12).height(28)
              .fontWeight(this.spatialAudioMode === SPATIAL_AUDIO_OFF ? FontWeight.Bold : FontWeight.Normal)
              .backgroundColor(this.spatialAudioMode === SPATIAL_AUDIO_OFF ? accentPrimary : btnSubBg(this.isDarkMode))
              .borderRadius(14)
              .onClick(() => { this.manager.setSpatialAudio(SPATIAL_AUDIO_OFF); })
            Button('固定').fontSize(12).height(28)
              .fontWeight(this.spatialAudioMode === SPATIAL_AUDIO_FIXED ? FontWeight.Bold : FontWeight.Normal)
              .backgroundColor(this.spatialAudioMode === SPATIAL_AUDIO_FIXED ? accentPrimary : btnSubBg(this.isDarkMode))
              .borderRadius(14)
              .onClick(() => { this.manager.setSpatialAudio(SPATIAL_AUDIO_FIXED); })
            Button('头跟').fontSize(12).height(28)
              .fontWeight(this.spatialAudioMode === SPATIAL_AUDIO_HEAD_TRACKING ? FontWeight.Bold : FontWeight.Normal)
              .backgroundColor(this.spatialAudioMode === SPATIAL_AUDIO_HEAD_TRACKING ? accentPrimary : btnSubBg(this.isDarkMode))
              .borderRadius(14)
              .onClick(() => { this.manager.setSpatialAudio(SPATIAL_AUDIO_HEAD_TRACKING); })
          } else {
            Text('--').fontSize(14).fontColor(textMuted(this.isDarkMode))
          }
        }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 12 })
      } else if (this.capsSpatialSoundSwitch) {
        // 支持空间音效开关 (Air5/Free4) → 两端式: 关闭 | 开启
        Row() {
          Text('🎧').fontSize(18)
          Text(' 空间音频').fontSize(14).fontColor(textSecondary(this.isDarkMode)).margin({ left: 6 })
          Blank()
          if (this.connectionStatus === 'subscribed') {
            Button('关闭').fontSize(12).height(28)
              .fontWeight(this.spatialAudioMode === SPATIAL_AUDIO_OFF ? FontWeight.Bold : FontWeight.Normal)
              .backgroundColor(this.spatialAudioMode === SPATIAL_AUDIO_OFF ? accentPrimary : btnSubBg(this.isDarkMode))
              .borderRadius(14)
              .onClick(() => { this.manager.setSpatialAudio(SPATIAL_AUDIO_OFF); })
            Button('开启').fontSize(12).height(28)
              .fontWeight(this.spatialAudioMode >= SPATIAL_AUDIO_FIXED ? FontWeight.Bold : FontWeight.Normal)
              .backgroundColor(this.spatialAudioMode >= SPATIAL_AUDIO_FIXED ? accentPrimary : btnSubBg(this.isDarkMode))
              .borderRadius(14)
              .onClick(() => { this.manager.setSpatialAudio(SPATIAL_AUDIO_FIXED); })
          } else {
            Text('--').fontSize(14).fontColor(textMuted(this.isDarkMode))
          }
        }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 12 })
      }
    }
    .width('85%')
    .borderRadius(20)
    .backgroundColor(cardBg(this.isDarkMode))
    .margin({ top: 24 })

    // 双设备连接
    Column() {
      Row() {
        Text('📱')
          .fontSize(18)
        Text(' 双设备连接')
          .fontSize(14)
          .fontColor(textSecondary(this.isDarkMode))
          .margin({ left: 6 })

        Blank()

        if (this.connectionStatus === 'subscribed') {
          Toggle({ type: ToggleType.Switch, isOn: this.dualDeviceEnabled })
            .selectedColor(accentPrimary)
            .switchPointColor('#FFFFFF')
            .onChange((isOn: boolean) => {
              this.dualDeviceEnabled = isOn;
              this.manager.setDualDeviceConnection(isOn);
              // 同步到 AppStorage，与多设备管理页联动
              AppStorage.setOrCreate('dualDeviceEnabled', isOn);
            })
        } else {
          Text('--')
            .fontSize(14)
            .fontColor(textMuted(this.isDarkMode))
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 16 })
      .onClick(() => {
        // 点击"双设备连接"文字区域进入多设备管理页面
        router.pushUrl({ url: 'pages/MultiDeviceManagementPage' });
      })
    }
    .width('85%')
    .borderRadius(20)
    .backgroundColor(cardBg(this.isDarkMode))
    .margin({ top: 16 })

    // 佩戴检测（智能播放暂停）
    if (this.connectionStatus === 'subscribed' && this.manager.getDeviceCapabilities().hasWearDetection) {
      Column() {
        Row() {
          Text('👂')
            .fontSize(18)
          Text(' 佩戴检测')
            .fontSize(14)
            .fontColor(textSecondary(this.isDarkMode))
            .margin({ left: 6 })

          Blank()

          Toggle({ type: ToggleType.Switch, isOn: this.wearDetectionEnabled })
            .selectedColor(accentPrimary)
            .switchPointColor('#FFFFFF')
            .onChange((isOn: boolean) => {
              this.wearDetectionEnabled = isOn;
              this.manager.setWearDetection(isOn);
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 4 })

        Text('摘下耳机时自动暂停播放，重新佩戴时继续播放')
          .fontSize(10)
          .fontColor(tipTextColor(this.isDarkMode))
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12 })
      }
      .width('85%')
      .borderRadius(20)
      .backgroundColor(cardBg(this.isDarkMode))
      .margin({ top: 16 })
    }

    // EQ 大师调音预设（点击进入完整 EQ 管理页面）
    Column() {
      Row() {
        Text('🎵')
          .fontSize(18)
        Text(' 大师调音')
          .fontSize(14)
          .fontColor(textSecondary(this.isDarkMode))
          .margin({ left: 6 })

        Blank()

        if (this.connectionStatus === 'subscribed' && this.currentEqPreset >= 0) {
          Text(this.eqPresetNames[this.currentEqPreset] ?? '')
            .fontSize(12)
            .fontColor(accentGreen)
        } else if (this.connectionStatus === 'subscribed' && this.eqPresetIds.length > 0) {
          Text('点击选择')
            .fontSize(12)
            .fontColor(accentPrimary)
        } else if (this.connectionStatus !== 'subscribed') {
          Text('--')
            .fontSize(14)
            .fontColor(textMuted(this.isDarkMode))
        }

        Text('›')
          .fontSize(18)
          .fontColor(textTertiary(this.isDarkMode))
          .margin({ left: 4 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/EqMasterPage' });
      })
    }
    .width('85%')
    .borderRadius(20)
    .backgroundColor(cardBg(this.isDarkMode))
    .margin({ top: 16 })

    // 设备信息（固件版本 + 编解码器）
    Column() {
      if (this.connectionStatus === 'subscribed') {
        Row() {
          Text('📋').fontSize(18)
          Text(' 设备信息').fontSize(14).fontColor(textSecondary(this.isDarkMode)).margin({ left: 6 })
        }
        .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 0 })
        if (this.deviceModelName) {
          Text('  ' + this.deviceModelName)
            .fontSize(13).fontColor(textPrimary(this.isDarkMode)).fontWeight(FontWeight.Medium)
            .width('100%').padding({ left: 16, right: 16, top: 6, bottom: 0 })
        }
        if (this.firmwareVersion) {
          Text('  固件版本: ' + this.firmwareVersion)
            .fontSize(12).fontColor(textTertiary(this.isDarkMode))
            .width('100%').padding({ left: 16, right: 16, top: 6, bottom: 0 })
        }
        Text('  编解码器: ' + this.codecName)
          .fontSize(12).fontColor(textTertiary(this.isDarkMode))
          .width('100%').padding({ left: 16, right: 16, top: this.firmwareVersion ? 4 : 6, bottom: 12 })
      }
    }
    .transition(TransitionEffect.opacity(0.3))
    .width('85%').borderRadius(20).backgroundColor(cardBg(this.isDarkMode))
    .margin({ top: 16 })
  }

  // ANC 单个按钮组件
  @Builder AncButton(label: string, isSelected: boolean, onClick: () => void) {
    Column() {
      // 按钮容器
      Button(label)
        .fontSize(14)
        .fontWeight(isSelected ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(isSelected ? '#FFFFFF' : textSecondary(this.isDarkMode))
        .width('90%')
        .height(45)
        .backgroundColor(isSelected ? accentPrimary : btnInactiveBg(this.isDarkMode))
        .borderRadius(16)
        .onClick(onClick)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  // ANC 子模式按钮组件（智能/轻度/中度/深度）
  @Builder AncSubButton(label: string, isSelected: boolean, onClick: () => void) {
    Column() {
      Button(label)
        .fontSize(13)
        .fontWeight(isSelected ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(isSelected ? '#FFFFFF' : textTertiary(this.isDarkMode))
        .width('90%')
        .height(36)
        .backgroundColor(isSelected ? accentPrimary : btnSubBg(this.isDarkMode))
        .borderRadius(16)
        .onClick(onClick)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  // 判断是否为降噪模式（包含所有降噪子模式）
  isNoiseCancellationMode(): boolean {
    return this.ancMode === 2 || this.ancMode === 5 || 
           this.ancMode === 6 || this.ancMode === 7 || this.ancMode === 8;
  }

  // 佩戴状态文本
  getWearText(state: WearState): string {
    switch (state) {
      case WearState.WEARING: return '佩戴';
      case WearState.IN_CASE: return '在仓';
      case WearState.REMOVED: return '取出';
      default: return '断开';
    }
  }

  // 佩戴状态颜色
  getWearColor(state: WearState): string {
    switch (state) {
      case WearState.WEARING: return accentGreen;
      case WearState.IN_CASE: return accentGold(this.isDarkMode);
      case WearState.REMOVED: return accentBlue(this.isDarkMode);
      default: return textMuted(this.isDarkMode);
    }
  }

  // ============== 底部提示区域 ==============
  @Builder TipSection() {
    Column() {
      if (this.connectionStatus === 'disconnected' || this.connectionStatus === 'scanning') {
        Text('已开启自动监听,检测到耳机会自动连接')
          .fontSize(12)
          .fontColor(textHint(this.isDarkMode))
          .textAlign(TextAlign.Center)
          .padding({ left: 30, right: 30 })
      }

      Blank()

      Text('Air5 Pro 耳机助手')
        .fontSize(11)
        .fontColor(watermarkText(this.isDarkMode))
        .margin({ bottom: 30 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ bottom: 20 })
  }
}
