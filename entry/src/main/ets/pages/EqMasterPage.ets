/**
 * EQ 大师调音管理页面
 * 展示默认推荐 EQ 和自定义 EQ，支持应用、编辑、删除
 */
import { OppoEarphoneManager } from '../manager/OppoEarphoneManager';
import router from '@ohos.router';
import { cardBg, textPrimary, textSecondary, textTertiary, textMuted, btnInactiveBg, accentPrimary, accentGreen, accentRed, pageBg, tipTextColor } from '../common/AppTheme';
import { EqInfoEntry } from '../common/OppoProtocol';

@Entry
@Component
export struct EqMasterPage {
  @StorageProp('isDarkMode') isDarkMode: boolean = true;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  private manager: OppoEarphoneManager = OppoEarphoneManager.getInstance();

  @State eqPresetNames: Record<number, string> = {};
  @State eqPresetIds: number[] = [];
  @StorageProp('currentEqPreset') currentEqPreset: number = -1;
  @State deviceEqList: EqInfoEntry[] = [];
  @State connectionStatus: string = 'disconnected';

  aboutToAppear(): void {
    this.refreshEqData();
    // 注册设备端 EQ 列表回调
    this.manager.setDeviceEqListCallback((entries: EqInfoEntry[]) => {
      this.deviceEqList = entries;
    });
  }

  private refreshEqData(): void {
    this.eqPresetNames = this.manager.getEqPresetNames();
    this.eqPresetIds = this.manager.getEqPresetIds();
    this.currentEqPreset = this.manager.getCurrentEqPreset();
    this.deviceEqList = this.manager.getDeviceEqEntries();
    this.connectionStatus = this.manager.getIsConnected() ? 'subscribed' : 'disconnected';
    // 刷新设备端 EQ 列表
    if (this.manager.getDeviceCapabilities().hasCustomEq) {
      this.manager.queryEqAll();
    }
  }

  build() {
    Column() {
      // 导航标题栏（固定在顶部，不随滑动移动）
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor(textPrimary(this.isDarkMode))
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.back();
          })
        Text('大师调音')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(textPrimary(this.isDarkMode))
          .margin({ left: 8 })
        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      Scroll() {
        Column() {
          if (this.connectionStatus === 'subscribed') {
          // ===== 默认推荐 EQ =====
          if (this.eqPresetIds.length > 0) {
            Column() {
              Row() {
                Text('推荐预设')
                  .fontSize(13)
                  .fontColor(textSecondary(this.isDarkMode))
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 6 })

              ForEach(this.eqPresetIds, (presetId: number) => {
                Row() {
                  Text(this.eqPresetNames[presetId] ?? '预设')
                    .fontSize(14)
                    .fontColor(textPrimary(this.isDarkMode))
                    .layoutWeight(1)

                  if (this.currentEqPreset === presetId) {
                    Text('使用中')
                      .fontSize(11)
                      .fontColor(accentGreen)
                      .margin({ right: 8 })
                  }

                  Button('应用')
                    .fontSize(12)
                    .fontColor(this.currentEqPreset === presetId ? accentGreen : '#FFFFFF')
                    .height(30)
                    .backgroundColor(this.currentEqPreset === presetId ? '#1A3A2A' : accentPrimary)
                    .borderRadius(15)
                    .padding({ left: 14, right: 14 })
                    .onClick(() => {
                      this.manager.setEqPreset(presetId);
                      this.currentEqPreset = presetId;
                    })
                }
                .width('100%')
                .height(52)
                .padding({ left: 16, right: 12 })
                .borderRadius(12)
                .backgroundColor(cardBg(this.isDarkMode))
                .margin({ top: 4 })
              }, (presetId: number) => presetId.toString())
            }
            .width('85%')
            .borderRadius(20)
            .backgroundColor(cardBg(this.isDarkMode))
            .margin({ top: 16 })
            .padding({ bottom: 8 })
          }

          // ===== 自定义 EQ =====
          if (this.manager.getDeviceCapabilities().hasCustomEq) {
            Column() {
              Row() {
                Text('自定义均衡器')
                  .fontSize(13)
                  .fontColor(textSecondary(this.isDarkMode))
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 6 })

              if (this.deviceEqList.length > 0) {
                ForEach(this.deviceEqList, (entry: EqInfoEntry) => {
                  Row() {
                    Column() {
                      Text(entry.name)
                        .fontSize(14)
                        .fontColor(textPrimary(this.isDarkMode))
                        .width('100%')

                      Text(entry.frequencies.map((f: number) => f + 'Hz').join(' · '))
                        .fontSize(10)
                        .fontColor(textMuted(this.isDarkMode))
                        .width('100%')
                        .margin({ top: 2 })
                    }
                    .layoutWeight(1)

                    if (this.currentEqPreset === entry.eqId) {
                      Text('使用中')
                        .fontSize(11)
                        .fontColor(accentGreen)
                        .margin({ right: 6 })
                    }

                    Button('编辑')
                      .fontSize(11)
                      .fontColor(textSecondary(this.isDarkMode))
                      .height(28)
                      .backgroundColor(btnInactiveBg(this.isDarkMode))
                      .borderRadius(14)
                      .margin({ right: 4 })
                      .onClick(() => {
                        router.pushUrl({
                          url: 'pages/EqEditorPage',
                          params: { eqId: entry.eqId }
                        });
                      })

                    Button('应用')
                      .fontSize(11)
                      .fontColor('#FFFFFF')
                      .height(28)
                      .backgroundColor(accentPrimary)
                      .borderRadius(14)
                      .padding({ left: 12, right: 12 })
                      .margin({ right: 4 })
                      .onClick(() => {
                        this.manager.setEqPreset(entry.eqId);
                      })
                  }
                  .width('100%')
                  .height(56)
                  .padding({ left: 16, right: 8 })
                  .borderRadius(12)
                  .backgroundColor(cardBg(this.isDarkMode))
                  .margin({ top: 4 })
                  .gesture(
                    LongPressGesture({ repeat: false, duration: 500 })
                      .onAction(() => {
                        this.showDeleteConfirm(entry);
                      })
                  )
                }, (entry: EqInfoEntry) => String(entry.eqId))
              }

              if (this.deviceEqList.length < 3) {
                Button('+ 添加均衡器')
                  .fontSize(13)
                  .fontColor(accentPrimary)
                  .width('100%')
                  .height(44)
                  .backgroundColor(btnInactiveBg(this.isDarkMode))
                  .borderRadius(16)
                  .margin({ top: 6 })
                  .onClick(() => {
                    router.pushUrl({ url: 'pages/EqEditorPage' });
                  })
              }
            }
            .width('85%')
            .borderRadius(20)
            .backgroundColor(cardBg(this.isDarkMode))
            .margin({ top: 16 })
            .padding({ bottom: 12 })
          }

          Text('长按自定义 EQ 可删除')
            .fontSize(11)
            .fontColor(tipTextColor(this.isDarkMode))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 24, bottom: 40 })
        } else {
          // 未连接时显示提示
          Column() {
            Text('🎵')
              .fontSize(48)
              .margin({ bottom: 16 })
            Text('请先连接耳机')
              .fontSize(16)
              .fontColor(textPrimary(this.isDarkMode))
            Text('连接后可查看和切换 EQ 预设')
              .fontSize(12)
              .fontColor(tipTextColor(this.isDarkMode))
              .margin({ top: 6 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 80 })
        }
      }
      .transition(TransitionEffect.opacity(0.3))
      .width('100%')
      .padding({ bottom: 40 })
      .alignItems(HorizontalAlign.Center)
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
  .width('100%')
  .height('100%')
  .padding({ top: this.statusBarHeight })
  .backgroundColor(pageBg(this.isDarkMode))
  .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
}

  /** 长按删除确认弹窗 */
  private showDeleteConfirm(entry: EqInfoEntry): void {
    AlertDialog.show({
      title: '删除 EQ',
      message: `确认删除 "${entry.name}" ？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#FF3B30',
        action: () => {
          this.manager.deleteCustomEq(entry.eqId);
          setTimeout(() => {
            this.deviceEqList = this.manager.getDeviceEqEntries();
          }, 600);
        }
      }
    });
  }
}
