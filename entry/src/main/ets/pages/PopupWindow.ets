import { OppoEarphoneManager, BatteryInfo, ConnectionStatus } from '../manager/OppoEarphoneManager';
import { common } from '@kit.AbilityKit';

/**
 * 弹窗界面 - 显示耳机电量
 * 被"智慧生活"等外部应用唤醒时从屏幕底部弹出
 */
@Entry
@Component
struct PopupWindow {
  @State leftBattery: number = -1;
  @State leftCharging: boolean = false;
  @State rightBattery: number = -1;
  @State rightCharging: boolean = false;
  @State caseBattery: number = -1;
  @State caseCharging: boolean = false;
  @State connectionStatus: ConnectionStatus = 'disconnected';
  @State loadingText: string = '正在连接...';

  private manager: OppoEarphoneManager = new OppoEarphoneManager();
  private connectTimeout: number = -1;

  aboutToAppear(): void {
    console.info('[PopupWindow] 弹窗界面启动');
    
    // 设置回调
    this.manager.setCallbacks(
      (info: BatteryInfo) => {
        console.info(`[PopupWindow] 收到电量更新: 左=${info.leftBattery}, 右=${info.rightBattery}, 仓=${info.caseBattery}`);
        // 更新电量数据
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
        
        // 如果三个电量都已获取,更新提示文本
        if (this.leftBattery >= 0 && this.rightBattery >= 0 && this.caseBattery >= 0) {
          this.loadingText = '电量已获取';
        }
      },
      (status: ConnectionStatus) => {
        this.connectionStatus = status;
        console.info(`[PopupWindow] 连接状态: ${status}`);
        
        // 根据状态更新提示文本
        switch (status) {
          case 'scanning':
            this.loadingText = '正在扫描耳机...';
            break;
          case 'connecting':
            this.loadingText = '正在连接...';
            break;
          case 'connected':
            this.loadingText = '正在获取电量...';
            break;
          case 'subscribed':
            this.loadingText = '已连接';
            break;
          default:
            this.loadingText = '等待连接...';
            break;
        }
      }
    );

    // 立即开始自动连接
    this.manager.startContinuousMonitor();

    // 设置超时保护:15秒后如果还没获取到电量,显示超时提示
    this.connectTimeout = setTimeout(() => {
      if (this.leftBattery < 0 && this.rightBattery < 0 && this.caseBattery < 0) {
        this.loadingText = '连接超时,请确保耳机已开启';
      }
    }, 15000);
  }

  aboutToDisappear(): void {
    console.info('[PopupWindow] 弹窗界面退出');
    if (this.connectTimeout !== -1) {
      clearTimeout(this.connectTimeout);
    }
    this.manager.disconnect();
  }

  getBatteryColor(battery: number, charging: boolean): string {
    if (battery < 0) {
      return '#666666';
    }
    if (charging) {
      return '#FFD700';
    }
    if (battery < 20) {
      return '#FF4444';
    }
    if (battery < 60) {
      return '#FF9800';
    }
    return '#4CAF50';
  }

  getBatteryText(battery: number): string {
    return battery < 0 ? '--' : `${battery}%`;
  }

  build() {
    // 外层使用 Stack 布局,让内容只占据底部
    Stack() {
      // 透明背景,不影响后面内容
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          // 点击空白区域关闭弹窗
          this.closePopup();
        })

      // 底部弹窗内容
      Column() {
        // 顶部弹性空间,将内容推到底部
        Blank()

        // 弹窗卡片内容
        Column() {
          // 标题
          Text('OPPO Enco Air5 Pro')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .margin({ top: 16, bottom: 6 })

          // 连接状态提示
          Text(this.loadingText)
            .fontSize(12)
            .fontColor('#8888AA')
            .margin({ bottom: 16 })

          // 电量显示区域
          Row() {
            // 左耳
            Column() {
              Text('🎧')
                .fontSize(22)
              
              Stack() {
                Progress({ value: this.leftBattery < 0 ? 0 : this.leftBattery, total: 100, type: ProgressType.Ring })
                  .width(70)
                  .height(70)
                  .color(this.getBatteryColor(this.leftBattery, this.leftCharging))
                  .backgroundColor('#1E1E3E')

                Text(this.getBatteryText(this.leftBattery))
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
              }
              .width(70)
              .height(70)
              .margin({ top: 6 })

              Text('左耳')
                .fontSize(11)
                .fontColor('#AAAACC')
                .margin({ top: 6 })

              if (this.leftCharging) {
                Text('⚡')
                  .fontSize(12)
                  .margin({ top: 3 })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)

            // 右耳
            Column() {
              Text('🎧')
                .fontSize(22)
              
              Stack() {
                Progress({ value: this.rightBattery < 0 ? 0 : this.rightBattery, total: 100, type: ProgressType.Ring })
                  .width(70)
                  .height(70)
                  .color(this.getBatteryColor(this.rightBattery, this.rightCharging))
                  .backgroundColor('#1E1E3E')

                Text(this.getBatteryText(this.rightBattery))
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
              }
              .width(70)
              .height(70)
              .margin({ top: 6 })

              Text('右耳')
                .fontSize(11)
                .fontColor('#AAAACC')
                .margin({ top: 6 })

              if (this.rightCharging) {
                Text('⚡')
                  .fontSize(12)
                  .margin({ top: 3 })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)

            // 充电仓
            Column() {
              Text('🔋')
                .fontSize(22)
              
              Stack() {
                Progress({ value: this.caseBattery < 0 ? 0 : this.caseBattery, total: 100, type: ProgressType.Ring })
                  .width(70)
                  .height(70)
                  .color(this.getBatteryColor(this.caseBattery, this.caseCharging))
                  .backgroundColor('#1E1E3E')

                Text(this.getBatteryText(this.caseBattery))
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
              }
              .width(70)
              .height(70)
              .margin({ top: 6 })

              Text('充电仓')
                .fontSize(11)
                .fontColor('#AAAACC')
                .margin({ top: 6 })

              if (this.caseCharging) {
                Text('⚡')
                  .fontSize(12)
                  .margin({ top: 3 })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .padding({ left: 12, right: 12 })

          // 底部关闭按钮
          Button('关闭')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .width('50%')
            .height(36)
            .backgroundColor('#2A5CFF')
            .borderRadius(18)
            .margin({ top: 20, bottom: 16 })
            .onClick(() => {
              this.closePopup();
            })
        }
        .width('85%')
        .borderRadius(20)
        .linearGradient({
          angle: 180,
          colors: [['#1A1A3E', 0.0], ['#12122E', 1.0]]
        })
        .shadow({
          radius: 20,
          color: '#00000040',
          offsetX: 0,
          offsetY: -5
        })
        .border({
          width: 1,
          color: '#2A2A5E'
        })
        .margin({ bottom: 30 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End) // 确保内容对齐到底部
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  /**
   * 关闭弹窗
   */
  private closePopup(): void {
    let context = getContext(this) as common.UIAbilityContext;
    context.terminateSelf();
  }
}
