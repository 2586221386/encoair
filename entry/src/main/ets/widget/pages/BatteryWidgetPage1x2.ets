let storage1x2 = new LocalStorage();

/**
 * 桌面电量卡片 UI（1×2 尺寸）
 * 显示通用电量值（通过 HFP 系统 API 获取，无需唤醒主应用）
 * 点击卡片可跳转主应用
 */
@Entry(storage1x2)
@Component
struct BatteryWidgetPage1x2 {
  @LocalStorageProp('batteryLevel') batteryLevel: number = -1;
  @LocalStorageProp('isConnected') isConnected: boolean = false;
  @LocalStorageProp('isDarkMode') isDarkMode: boolean = false;

  private get widgetBg(): string { return this.isDarkMode ? '#1C1C1E' : '#FFFFFF'; }
  private get textPrimary(): string { return this.isDarkMode ? '#FFFFFF' : '#1C1C1E'; }
  private get textSecondary(): string { return this.isDarkMode ? '#9999AA' : '#555568'; }
  private get dotSep(): string { return this.isDarkMode ? '#555588' : '#BBBBCC'; }

  getBatteryColor(): string {
    if (this.batteryLevel < 0 || !this.isConnected) {
      return this.isDarkMode ? '#666666' : '#999999';
    }
    if (this.batteryLevel < 20) {
      return this.isDarkMode ? '#FF4444' : '#D32F2F';
    }
    if (this.batteryLevel < 60) {
      return this.isDarkMode ? '#FF9800' : '#E65100';
    }
    return '#4CAF50';
  }

  getBatteryText(): string {
    if (!this.isConnected) return '--';
    return this.batteryLevel < 0 ? '--' : `${this.batteryLevel}%`;
  }

  build() {
    Stack() {
      Row() {
        // 耳机图标
        Text('🎧')
          .fontSize(28)

        // 电量信息
        Column() {
          Row() {
            Text('Air5 Pro')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.textPrimary)
              .flexShrink(1)
              .maxLines(1)

            Text(' · ')
              .fontSize(10)
              .fontColor(this.dotSep)

            Text(this.isConnected ? '已连接' : '未连接')
              .fontSize(10)
              .fontColor(this.isConnected ? '#4CAF50' : (this.isDarkMode ? '#AAAAAA' : '#90909A'))
              .flexShrink(0)
          }

          Row() {
            Text(this.getBatteryText())
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getBatteryColor())
              .flexShrink(0)

            Text(' 电量')
              .fontSize(11)
              .fontColor(this.textSecondary)
              .flexShrink(0)
          }
        }
        .layoutWeight(1)
        .margin({ left: 10 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .backgroundColor(this.widgetBg)
      .borderRadius(16)

      // 透明点击层：点击跳转主应用
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
              'widget_refresh': true
            }
          });
        })
    }
    .width('100%')
    .height('100%')
  }
}
