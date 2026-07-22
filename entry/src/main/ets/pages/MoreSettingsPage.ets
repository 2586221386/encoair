import router from '@ohos.router';
import { OppoEarphoneManager } from '../manager/OppoEarphoneManager';
import { common } from '@kit.AbilityKit';
import {
  pageBg, cardBg, textPrimary, textSecondary, descTextColor, tipTextColor,
  accentPrimary, accentGreen
} from '../common/AppTheme';

/**
 * 更多设置页面
 * 收纳佩戴检测、提示音量等次要功能
 */
@Entry
@Component
struct MoreSettingsPage {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = true;
  @StorageLink('wearDetectionEnabled') wearDetectionEnabled: boolean = false;
  @State volumeValue: number = -1;
  private manager: OppoEarphoneManager = OppoEarphoneManager.getInstance();

  aboutToAppear(): void {
    // 注册音量回调
    this.manager.setVolumeCallback((value: number) => {
      this.volumeValue = value;
    });
    // 已连接时查询当前音量
    if (this.manager.getIsConnected()) {
      this.manager.queryVolumeValue();
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('‹')
          .fontSize(24)
          .fontColor(textPrimary(this.isDarkMode))
          .onClick(() => {
            router.back();
          })
        Text(' 更多设置')
          .fontSize(18)
          .fontColor(textPrimary(this.isDarkMode))
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .padding({ left: 16, top: 12, bottom: 8 })
      .margin({ top: this.statusBarHeight })

      Scroll() {
        Column() {
          // ====== 佩戴检测 ======
          if (this.manager.getIsConnected() && this.manager.getDeviceCapabilities().hasWearDetection) {
            Column() {
              Row() {
                Row() {
                  Text('👂')
                    .fontSize(18)
                  Text(' 佩戴检测')
                    .fontSize(14)
                    .fontColor(textSecondary(this.isDarkMode))
                    .margin({ left: 6 })
                }
                .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: this.wearDetectionEnabled })
                  .selectedColor(accentPrimary)
                  .switchPointColor('#FFFFFF')
                  .onChange((isOn: boolean) => {
                    this.wearDetectionEnabled = isOn;
                    this.manager.setWearDetection(isOn);
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 4 })

              Text('摘下耳机时自动暂停播放，重新佩戴时继续播放')
                .fontSize(11)
                .fontColor(descTextColor(this.isDarkMode))
                .width('100%')
                .padding({ left: 16, right: 16, bottom: 12 })
            }
            .width('100%')
            .borderRadius(20)
            .backgroundColor(cardBg(this.isDarkMode))
          }

          // ====== 提示音量 ======
          if (this.manager.getIsConnected() && this.manager.getDeviceCapabilities().hasPromptVolume) {
            Column() {
              Row() {
                Text('🔊')
                  .fontSize(18)
                Text(' 提示音量')
                  .fontSize(14)
                  .fontColor(textSecondary(this.isDarkMode))
                  .margin({ left: 6 })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 8 })

              Row() {
                Slider({
                  value: this.volumeValue >= 0 ? this.volumeValue : 5,
                  min: this.manager.getDeviceCapabilities().promptVolumeMin,
                  max: this.manager.getDeviceCapabilities().promptVolumeMax,
                  step: 1,
                })
                  .layoutWeight(1)
                  .blockColor(accentPrimary)
                  .selectedColor(accentPrimary)
                  .trackThickness(6)
                  .onChange((val: number) => {
                    this.volumeValue = val;
                    this.manager.setVolumeValue(val);
                  })

                Text(this.volumeValue >= 0 ? this.volumeValue.toString() : '--')
                  .fontSize(16)
                  .fontColor(textPrimary(this.isDarkMode))
                  .width(30)
                  .textAlign(TextAlign.Center)
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 12 })
            }
            .width('100%')
            .borderRadius(20)
            .backgroundColor(cardBg(this.isDarkMode))
            .margin({ top: 16 })
          }

          // 未连接提示
          if (!this.manager.getIsConnected()) {
            Column() {
              Text('请先连接耳机')
                .fontSize(14)
                .fontColor(tipTextColor(this.isDarkMode))
                .textAlign(TextAlign.Center)
                .width('100%')
                .padding(20)
            }
            .width('100%')
            .borderRadius(20)
            .backgroundColor(cardBg(this.isDarkMode))
          }
        }
        .width('85%')
        .margin({ top: 24 })
      }
      .width('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
    .backgroundColor(pageBg(this.isDarkMode))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
