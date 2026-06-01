import { OppoEarphoneManager, BatteryInfo, ConnectionStatus } from '../manager/OppoEarphoneManager';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 电量卡片子组件
 * 使用 @Prop 装饰器与父组件 @State 建立单向响应式绑定，确保电量数据变化能驱动 UI 更新
 * 注意：@Builder 按值传参无法建立响应式依赖，是导致 UI 不更新的根因
 */
@Component
struct BatteryCardComponent {
  @Prop battery: number = -1;
  @Prop charging: boolean = false;
  private label: string = '';
  private iconType: string = 'L';

  getBatteryColor(): string {
    if (this.battery < 0) {
      return '#666666';
    }
    if (this.charging) {
      return '#FFD700';
    }
    if (this.battery < 20) {
      return '#FF4444';
    }
    if (this.battery < 60) {
      return '#FF9800';
    }
    return '#4CAF50';
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
          .backgroundColor('#1E1E3E')

        // 中间电量百分比
        Text(this.getBatteryText())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(100)
      .height(100)
      .margin({ top: 12 })

      // 设备名称
      Text(this.label)
        .fontSize(14)
        .fontColor('#AAAACC')
        .margin({ top: 10 })

      // 充电状态
      if (this.charging) {
        Row() {
          Text('⚡')
            .fontSize(14)
          Text('充电中')
            .fontSize(13)
            .fontColor('#FFD700')
            .margin({ left: 2 })
        }
        .margin({ top: 6 })
        .padding({ left: 10, right: 10, top: 3, bottom: 3 })
        .borderRadius(12)
        .backgroundColor('#332200')
      } else if (this.battery >= 0 && this.battery < 20) {
        Text('电量低')
          .fontSize(13)
          .fontColor('#FF4444')
          .margin({ top: 6 })
          .padding({ left: 10, right: 10, top: 3, bottom: 3 })
          .borderRadius(12)
          .backgroundColor('#330000')
      }
    }
    .width('30%')
    .padding({ top: 20, bottom: 16, left: 8, right: 8 })
    .borderRadius(20)
    .backgroundColor('#12122E')
    .border({ width: 1, color: '#2A2A5E' })
    .alignItems(HorizontalAlign.Center)
  }
}

@Entry
@Component
struct Index {
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

  private manager: OppoEarphoneManager = new OppoEarphoneManager();

  aboutToAppear(): void {
    this.requestBluetoothPermission();
    this.manager.setCallbacks(
      (info: BatteryInfo) => {
        console.info(`[Index] 收到电量更新: 左=${info.leftBattery}, 右=${info.rightBattery}, 仓=${info.caseBattery}`);
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
      },
      (status: ConnectionStatus) => {
        this.connectionStatus = status;
        if (status === 'connected' || status === 'subscribed') {
          this.macAddress = this.manager.getMacAddress();
        }
        if (status === 'disconnected') {
          this.macAddress = '';
        }
      },
      (hex: string) => {
        // 追加原始HEX数据日志，保留最近20条
        let timestamp = new Date().toLocaleTimeString();
        let newLine = `[${timestamp}] ${hex}`;
        let lines = this.rawHexLog ? this.rawHexLog.split('\n') : [];
        lines.push(newLine);
        if (lines.length > 20) {
          lines = lines.slice(lines.length - 20);
        }
        this.rawHexLog = lines.join('\n');
      }
    );
  }

  aboutToDisappear(): void {
    this.manager.disconnect();
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
   * 获取连接状态文本
   */
  getStatusText(): string {
    switch (this.connectionStatus) {
      case 'disconnected':
        return '未连接';
      case 'scanning':
        return '正在扫描...';
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
        return '#9E9E9E';
      case 'scanning':
        return '#2196F3';
      case 'connecting':
        return '#FF9800';
      case 'connected':
        return '#2196F3';
      case 'subscribed':
        return '#4CAF50';
      default:
        return '#9E9E9E';
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
      // 标题区域
      this.TitleSection();

      // 连接状态区域
      this.StatusSection();

      // 电量卡片区域
      this.BatterySection();

      // 操作按钮区域
      this.ActionSection();

      // HEX原始数据区域
      this.RawDataSection();

      // 底部提示
      this.TipSection();
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: [['#0D0D1A', 0.0], ['#1A1A3E', 0.5], ['#0D0D2B', 1.0]]
    })
  }

  // ============== 标题区域 ==============
  @Builder TitleSection() {
    Column() {
      Text('OPPO Enco Air5 Pro')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .letterSpacing(1)

      Text('蓝牙电量监控')
        .fontSize(16)
        .fontColor('#8888AA')
        .margin({ top: 6 })
    }
    .margin({ top: 60 })
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
            .fontColor('#666688')
            .margin({ left: 10 })
            .fontFamily('monospace')
        }
      }
    }
    .width('85%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .borderRadius(25)
    .backgroundColor('#1A1A3E')
    .border({ width: 1, color: '#2A2A5E' })
    .margin({ top: 25 })
    .alignItems(HorizontalAlign.Center)
  }

  // ============== 电量卡片区域 ==============
  @Builder BatterySection() {
    Row() {
      BatteryCardComponent({ battery: this.leftBattery, charging: this.leftCharging, label: '左耳', iconType: 'L' })
      BatteryCardComponent({ battery: this.rightBattery, charging: this.rightCharging, label: '右耳', iconType: 'R' })
      BatteryCardComponent({ battery: this.caseBattery, charging: this.caseCharging, label: '充电仓', iconType: 'C' })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .margin({ top: 35 })
    .padding({ left: 12, right: 12 })
  }

  // ============== 操作按钮区域 ==============
  @Builder ActionSection() {
    Column() {
      if (this.connectionStatus === 'disconnected') {
        // 开始扫描按钮
        Button() {
          Row() {
            Text('🔍')
              .fontSize(18)
            Text('  开始扫描')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
          }
        }
        .width('80%')
        .height(52)
        .backgroundColor('#2A5CFF')
        .borderRadius(26)
        .enabled(this.hasPermission)
        .opacity(this.hasPermission ? 1.0 : 0.5)
        .onClick(() => {
          if (this.hasPermission) {
            this.manager.startScan();
            this.scanTipVisible = true;
            // 5秒后隐藏扫描提示
            setTimeout(() => {
              this.scanTipVisible = false;
            }, 5000);
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
        .backgroundColor('#FF6B35')
        .borderRadius(26)
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
        .backgroundColor('#FF4444')
        .borderRadius(26)
        .onClick(() => {
          this.manager.disconnect();
        })
      }

      // 权限未授予时的提示
      if (!this.hasPermission) {
        Text('请授予蓝牙权限后使用')
          .fontSize(13)
          .fontColor('#FF6B6B')
          .margin({ top: 12 })
      }
    }
    .margin({ top: 40 })
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
          .fontColor('#AAAACC')
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(this.showRawData ? '收起 ▲' : '展开 ▼')
          .fontSize(12)
          .fontColor('#6666AA')
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
            .fontColor('#88AACC')
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
    .borderRadius(16)
    .backgroundColor('#12122E')
    .border({ width: 1, color: '#2A2A5E' })
    .margin({ top: 20 })
    .clip(true)
  }

  // ============== 底部提示区域 ==============
  @Builder TipSection() {
    Column() {
      if (this.scanTipVisible) {
        Text('请确保耳机充电仓盖子已打开，且耳机在蓝牙范围内')
          .fontSize(12)
          .fontColor('#6666AA')
          .textAlign(TextAlign.Center)
          .padding({ left: 30, right: 30 })
      }

      Blank()

      Text('OPPO Enco Air5 Pro 专用电量监控')
        .fontSize(11)
        .fontColor('#444466')
        .margin({ bottom: 30 })
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}
