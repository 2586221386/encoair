/**
 * 自定义 EQ 编辑器（10 段）
 * 频段: 31, 62, 125, 250, 500, 1K, 2K, 4K, 8K, 16K Hz
 */
import { OppoEarphoneManager } from '../manager/OppoEarphoneManager';
import router from '@ohos.router';
import { cardBg, textPrimary, textSecondary, textTertiary, textMuted, btnInactiveBg, accentPrimary, accentGreen, pageBg, tipTextColor } from '../common/AppTheme';
import { EqInfoEntry } from '../common/OppoProtocol';

/** 10 段 EQ 频段标签 */
const FREQ_BANDS: string[] = ['31', '62', '125', '250', '500', '1K', '2K', '4K', '8K', '16K'];

@Entry
@Component
export struct EqEditorPage {
  @StorageProp('isDarkMode') isDarkMode: boolean = true;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  private manager: OppoEarphoneManager = OppoEarphoneManager.getInstance();

  @State eqName: string = '';
  @State gains: number[] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  @State editEqId: number = -1;
  @State isEditMode: boolean = false;

  aboutToAppear(): void {
    // 检查是否是编辑模式
    const params = router.getParams() as Record<string, string>;
    if (params && params['eqId'] !== undefined) {
      const eqId = Number(params['eqId']);
      if (!isNaN(eqId) && eqId > 0) {
        this.editEqId = eqId;
        this.isEditMode = true;
        // 加载已有 EQ 数据
        const entries = this.manager.getDeviceEqEntries();
        for (const entry of entries) {
          if (entry.eqId === eqId) {
            this.eqName = entry.name;
            // 按 10 段映射：如果设备端不是 10 段，取前 min(10, length) 个
            for (let i = 0; i < Math.min(10, entry.gains.length); i++) {
              this.gains[i] = entry.gains[i];
            }
            break;
          }
        }
      }
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('‹ 返回')
          .fontSize(16)
          .fontColor(accentPrimary)
          .onClick(() => {
            router.back();
          })
        Blank()
        Text(this.isEditMode ? '编辑均衡器' : '添加均衡器')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(textPrimary(this.isDarkMode))
        Blank()
        Text('保存')
          .fontSize(16)
          .fontColor(accentPrimary)
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            this.saveEq();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })

      Scroll() {
        Column() {
          // ===== 名称输入 =====
          Row() {
            Text('名称')
              .fontSize(13)
              .fontColor(textSecondary(this.isDarkMode))
              .margin({ right: 12 })
            TextInput({ placeholder: '输入均衡器名称', text: this.eqName })
              .layoutWeight(1)
              .height(38)
              .fontSize(14)
              .onChange((val: string) => { this.eqName = val; })
          }
          .width('90%')
          .padding({ top: 20, bottom: 8 })

          // ===== 10 段 EQ 滑块 =====
          Column() {
            Row() {
              Text('频段')
                .fontSize(12)
                .fontColor(textMuted(this.isDarkMode))
                .width(50)
              Text('增益')
                .fontSize(12)
                .fontColor(textMuted(this.isDarkMode))
                .layoutWeight(1)
                .textAlign(TextAlign.End)
                .margin({ right: 30 })
            }
            .width('100%')
            .padding({ left: 12, right: 12, bottom: 4 })

            ForEach(FREQ_BANDS, (label: string, index: number) => {
              Row() {
                Text(label + 'Hz')
                  .fontSize(12)
                  .fontColor(this.gains[index] === 0 ? textTertiary(this.isDarkMode) : textPrimary(this.isDarkMode))
                  .width(45)
                  .textAlign(TextAlign.Start)

                Slider({
                  value: this.gains[index],
                  min: -6,
                  max: 6,
                  step: 1
                })
                .layoutWeight(1)
                .height(34)
                .onChange((val: number) => {
                  const newGains: number[] = [];
                  for (let i = 0; i < this.gains.length; i++) {
                    newGains.push(i === index ? val : this.gains[i]);
                  }
                  this.gains = newGains;
                })

                Text(this.gains[index] > 0 ? '+' + this.gains[index] : String(this.gains[index]))
                  .fontSize(12)
                  .fontColor(this.gains[index] === 0 ? textMuted(this.isDarkMode) : accentGreen)
                  .width(28)
                  .textAlign(TextAlign.End)
              }
              .width('100%')
              .height(36)
              .padding({ left: 8, right: 8 })
            }, (label: string) => label)
          }
          .width('90%')
          .borderRadius(20)
          .backgroundColor(cardBg(this.isDarkMode))
          .padding({ top: 8, bottom: 8, left: 4, right: 4 })

          // ===== 说明 =====
          Text('拖动滑块调节各频段增益（-6dB ~ +6dB）')
            .fontSize(11)
            .fontColor(tipTextColor(this.isDarkMode))
            .width('90%')
            .textAlign(TextAlign.Center)
            .margin({ top: 16 })

          // ===== 操作按钮 =====
          Row() {
            Button('重置')
              .fontSize(14)
              .fontColor(textSecondary(this.isDarkMode))
              .height(40)
              .backgroundColor(btnInactiveBg(this.isDarkMode))
              .borderRadius(24)
              .layoutWeight(1)
              .margin({ right: 8 })
              .onClick(() => {
                this.gains = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
              })

            Button('保存')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .height(40)
              .backgroundColor(accentPrimary)
              .borderRadius(24)
              .layoutWeight(1)
              .margin({ left: 8 })
              .onClick(() => {
                this.saveEq();
              })
          }
          .width('90%')
          .margin({ top: 24 })
        }
        .width('100%')
        .padding({ top: 8 })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .transition(TransitionEffect.opacity(0.3))
    .width('100%')
    .height('100%')
    .padding({ top: this.statusBarHeight })
    .backgroundColor(pageBg(this.isDarkMode))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  /** 保存自定义 EQ */
  private saveEq(): void {
    const freqValues: number[] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
    const name = this.eqName.length > 0 ? this.eqName : '自定义';

    if (this.isEditMode && this.editEqId > 0) {
      // 更新已有 EQ
      const entry = new EqInfoEntry();
      entry.eqId = this.editEqId;
      entry.name = name;
      entry.frequencies = freqValues;
      entry.gains = this.gains;
      this.manager.updateCustomEq(entry);
    } else {
      // 新建 EQ
      this.manager.createCustomEq(this.gains, freqValues, name);
    }
    router.back();
  }
}
