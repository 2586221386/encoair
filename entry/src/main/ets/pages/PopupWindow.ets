import { OppoEarphoneManager, BatteryInfo, ConnectionStatus } from '../manager/OppoEarphoneManager';
import { common, Want } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import EntryAbility from '../entryability/EntryAbility';

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
  @State popupBgImage: string = '';
  @State isGifBg: boolean = false;
  @State cardHeight: number = 0;

  private manager: OppoEarphoneManager = OppoEarphoneManager.getInstance();
  private connectTimeout: number = -1;
  private autoCloseTimeout: number = -1;

  aboutToAppear(): void {
    console.info('[PopupWindow] 弹窗界面启动');

    // 加载弹窗背景图片
    this.loadPopupBackground();

    // 设置应用上下文
    this.manager.setContext(getContext(this) as common.UIAbilityContext);

    // 检查是否已连接（从主页面共享连接）
    if (this.manager.getIsConnected()) {
      console.info('[PopupWindow] 检测到已有连接，直接读取电量快照');
      this.connectionStatus = 'subscribed';
      let info = this.manager.getCurrentBatteryInfo();
      this.leftBattery = info.leftBattery;
      this.leftCharging = info.leftCharging;
      this.rightBattery = info.rightBattery;
      this.rightCharging = info.rightCharging;
      this.caseBattery = info.caseBattery;
      this.caseCharging = info.caseCharging;
      this.loadingText = '已连接';
      // 不替换回调、不重新连接，避免影响主页面
    } else if (this.manager.hasActiveCallbacks()) {
      // 主页面正在运行（预览模式），不接管连接，只读取当前扫描状态快照
      console.info('[PopupWindow] 主页面监听运行中,不接管连接,读取快照');
      let info = this.manager.getCurrentBatteryInfo();
      this.leftBattery = info.leftBattery;
      this.leftCharging = info.leftCharging;
      this.rightBattery = info.rightBattery;
      this.rightCharging = info.rightCharging;
      this.caseBattery = info.caseBattery;
      this.caseCharging = info.caseCharging;
      this.loadingText = '等待连接...';
      // 不替换回调、不启动监听，避免干扰主页面
    } else {
      // 未连接（外部唤醒场景），走完整连接流程
      this.manager.setBatteryCallback((info: BatteryInfo) => {
          console.info(`[PopupWindow] 收到电量更新: 左=${info.leftBattery}, 右=${info.rightBattery}, 仓=${info.caseBattery}`);
          if (info.leftBattery < 0 && info.rightBattery < 0 && info.caseBattery < 0) {
            this.leftBattery = -1;
            this.rightBattery = -1;
            this.caseBattery = -1;
            this.leftCharging = false;
            this.rightCharging = false;
            this.caseCharging = false;
            return;
          }
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
          if (this.leftBattery >= 0 && this.rightBattery >= 0 && this.caseBattery >= 0) {
            this.loadingText = '电量已获取';
            if (this.autoCloseTimeout === -1) {
              this.autoCloseTimeout = setTimeout(() => {
                this.closePopup();
              }, 3000);
            }
          }
        });
      this.manager.setStatusCallback((status: ConnectionStatus) => {
          this.connectionStatus = status;
          console.info(`[PopupWindow] 连接状态: ${status}`);
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
        });
      this.manager.startContinuousMonitor();

      // 超时保护
      this.connectTimeout = setTimeout(() => {
        if (this.leftBattery < 0 && this.rightBattery < 0 && this.caseBattery < 0) {
          this.loadingText = '连接超时,请确保耳机已开启';
        }
      }, 15000);
    }
  }

  aboutToDisappear(): void {
    console.info('[PopupWindow] 弹窗界面退出');
    if (this.connectTimeout !== -1) {
      clearTimeout(this.connectTimeout);
    }
    if (this.autoCloseTimeout !== -1) {
      clearTimeout(this.autoCloseTimeout);
    }
    // 不调用 disconnect，避免断开主页面的共享连接
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

  /**
   * 加载弹窗背景图片
   */
  private loadPopupBackground(): void {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let pref = preferences.getPreferencesSync(context, { name: 'popup_settings' });
      let savedPath = pref.getSync('popupBgImage', '') as string;
      if (savedPath && fileIo.accessSync(savedPath)) {
        this.isGifBg = savedPath.toLowerCase().endsWith('.gif');
        this.popupBgImage = 'file://' + savedPath;
      }
    } catch (e) {
      console.warn('[PopupWindow] 加载弹窗背景失败');
    }
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
          // GIF 背景图层（绝对定位在 Column 内，由 clip 裁剪）
          if (this.popupBgImage && this.isGifBg) {
            Image(this.popupBgImage)
              .objectFit(ImageFit.Cover)
              .width('100%')
              .height(this.cardHeight > 0 ? this.cardHeight : 0)
              .position({ x: 0, y: 0 })
          }

          // 标题
          Text('Air5 Pro')
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

          // 底部操作按钮
          Row() {
            Button('设置')
              .fontSize(13)
              .fontColor('#FFFFFF')
              .height(36)
              .layoutWeight(1)
              .backgroundColor('#1E1E3E')
              .borderRadius(18)
              .border({ width: 1, color: '#2A2A5E' })
              .onClick(() => {
                this.openMainPage();
              })

            Blank()
              .width(16)

            Button('关闭')
              .fontSize(13)
              .fontColor('#FFFFFF')
              .height(36)
              .layoutWeight(1)
              .backgroundColor('#2A5CFF')
              .borderRadius(18)
              .onClick(() => {
                this.closePopup();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ top: 20, bottom: 16 })
        }
        .width('85%')
        .borderRadius(20)
        .clip(true)
        .backgroundColor(this.popupBgImage ? '#00000000' : '#12122E')
        .backgroundImage(this.popupBgImage && !this.isGifBg ? this.popupBgImage : '')
        .backgroundImageSize(ImageSize.Cover)
        .backgroundImagePosition(Alignment.Center)
        .linearGradient({
          angle: 180,
          colors: this.popupBgImage
            ? [['#66000000', 0.0], ['#99000000', 1.0]]
            : [['#1A1A3E', 0.0], ['#12122E', 1.0]]
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
        .onAreaChange((oldValue: Area, newValue: Area) => {
          let h = newValue.height;
          if (typeof h === 'number' && h > 0) {
            this.cardHeight = h;
          }
        })
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
   * 跳转到主页面
   * 子窗口模式下只需关闭子窗口即可露出主页面
   */
  private openMainPage(): void {
    this.tryCloseSubWindow(() => {
      let context = getContext(this) as common.UIAbilityContext;
      let want: Want = {
        bundleName: 'com.hzx.encoair',
        abilityName: 'EntryAbility'
      };
      context.startAbility(want).then(() => {
        context.terminateSelf();
      }).catch((err: Error) => {
        console.error(`[PopupWindow] 跳转主页面失败: ${err.message}`);
      });
    });
  }

  /**
   * 关闭弹窗
   */
  private closePopup(): void {
    this.tryCloseSubWindow(() => {
      let context = getContext(this) as common.UIAbilityContext;
      context.terminateSelf();
    });
  }

  /**
   * 尝试关闭子窗口，成功则执行 onSuccess，失败则执行 onFallback
   */
  private tryCloseSubWindow(onFallback: () => void): void {
    let subWin = EntryAbility.previewSubWindow;
    if (subWin) {
      try {
        subWin.destroyWindow();
        EntryAbility.previewSubWindow = null;
        console.info('[PopupWindow] 子窗口已销毁');
      } catch (e) {
        console.warn('[PopupWindow] 销毁子窗口失败，回退到 terminateSelf');
        EntryAbility.previewSubWindow = null;
        onFallback();
      }
    } else {
      onFallback();
    }
  }
}
