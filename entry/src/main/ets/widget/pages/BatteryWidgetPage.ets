let storage = new LocalStorage();

/**
 * 桌面电量卡片 UI（2*2尺寸）
 * 显示左耳、右耳、充电仓三部分电量
 * 点击卡片可通过 postCardAction 唤醒应用刷新电量
 */
@Entry(storage)
@Component
struct BatteryWidgetPage {
  @LocalStorageProp('leftBattery') leftBattery: number = -1;
  @LocalStorageProp('leftCharging') leftCharging: boolean = false;
  @LocalStorageProp('rightBattery') rightBattery: number = -1;
  @LocalStorageProp('rightCharging') rightCharging: boolean = false;
  @LocalStorageProp('caseBattery') caseBattery: number = -1;
  @LocalStorageProp('caseCharging') caseCharging: boolean = false;
  @LocalStorageProp('lastUpdated') lastUpdated: string = '--:--';
  @LocalStorageProp('connected') connected: boolean = false;
  @LocalStorageProp('isDarkMode') isDarkMode: boolean = false;

  private get widgetBg(): string { return this.isDarkMode ? '#1A1D2E' : '#FFFFFF'; }
  private get textPrimary(): string { return this.isDarkMode ? '#E8E8EC' : '#1A1A2E'; }
  private get textSecondary(): string { return this.isDarkMode ? '#9999AA' : '#555568'; }
  private get textMuted(): string { return this.isDarkMode ? '#777788' : '#90909A'; }
  private get progressBg(): string { return this.isDarkMode ? '#2A2A3E' : '#E8E8EC'; }

  /**
   * 根据电量返回颜色
   */
  getBatteryColor(battery: number): string {
    if (battery < 0) {
      return this.isDarkMode ? '#666666' : '#999999';
    }
    if (battery < 20) {
      return this.isDarkMode ? '#FF4444' : '#D32F2F';
    }
    if (battery < 60) {
      return this.isDarkMode ? '#FF9800' : '#E65100';
    }
    return '#4CAF50';
  }

  /**
   * 电量文本
   */
  getBatteryText(battery: number): string {
    return battery < 0 ? '--' : `${battery}%`;
  }

  build() {
    Stack() {
      Column() {
      // 顶部标题
      Row() {
        Text('Air5 Pro')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')

      // 三电量区域
      Row() {
        // 左耳
        
        Column() {
          Stack({ alignContent: Alignment.Center }) {
            Progress({
              value: this.leftBattery < 0 ? 0 : this.leftBattery,
              total: 100,
              type: ProgressType.Ring
            })
              .width(42)
              .height(42)
              .color(this.getBatteryColor(this.leftBattery))
              .backgroundColor(this.progressBg)
              .style({ strokeWidth: 4 })

            Text(this.getBatteryText(this.leftBattery))
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textPrimary)
          }
          .width(42)
          .height(42)
          .margin({ top: 6 })

          Text('左耳')
            .fontSize(10)
            .fontColor(this.textSecondary)
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        // 右耳
        Column() {
          Stack({ alignContent: Alignment.Center }) {
            Progress({
              value: this.rightBattery < 0 ? 0 : this.rightBattery,
              total: 100,
              type: ProgressType.Ring
            })
              .width(42)
              .height(42)
              .color(this.getBatteryColor(this.rightBattery))
              .backgroundColor(this.progressBg)
              .style({ strokeWidth: 4 })

            Text(this.getBatteryText(this.rightBattery))
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textPrimary)
          }
          .width(42)
          .height(42)
          .margin({ top: 6 })

          Text('右耳')
            .fontSize(10)
            .fontColor(this.textSecondary)
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        // 充电仓
        Column() {
          Stack({ alignContent: Alignment.Center }) {
            Progress({
              value: this.caseBattery < 0 ? 0 : this.caseBattery,
              total: 100,
              type: ProgressType.Ring
            })
              .width(42)
              .height(42)
              .color(this.getBatteryColor(this.caseBattery))
              .backgroundColor(this.progressBg)
              .style({ strokeWidth: 4 })

            Text(this.getBatteryText(this.caseBattery))
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textPrimary)
          }
          .width(42)
          .height(42)
          .margin({ top: 6 })

          Text('充电仓')
            .fontSize(10)
            .fontColor(this.textSecondary)
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .margin({ top: 4 })

      // 底部更新时间 + 刷新提示
      Row() {
        Text(`${this.lastUpdated} 更新 · 点击刷新`)
          .fontSize(10)
          .fontColor(this.textMuted)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor(this.widgetBg)
    .borderRadius(16)

      // 透明点击覆盖层：点击卡片任意位置触发刷新
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#00000000')
        .onClick(() => {
          postCardAction(this, {
            action: 'router',
            bundleName: 'com.hzx.encoair',
            abilityName: 'EntryAbility',
            params: {
              'show_popup': true,
              'widget_refresh': true
            }
          });
        })
    }
    .width('100%')
    .height('100%')
  }
}
