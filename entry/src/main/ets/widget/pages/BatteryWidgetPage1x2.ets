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

  getBatteryColor(): string {
    if (this.batteryLevel < 0 || !this.isConnected) {
      return '#666666';
    }
    if (this.batteryLevel < 20) {
      return '#FF4444';
    }
    if (this.batteryLevel < 60) {
      return '#FF9800';
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
              .fontColor('#333333')
              .flexShrink(1)
              .maxLines(1)

            Text(' · ')
              .fontSize(10)
              .fontColor('#CCCCCC')

            Text(this.isConnected ? '已连接' : '未连接')
              .fontSize(10)
              .fontColor(this.isConnected ? '#4CAF50' : '#AAAAAA')
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
              .fontColor('#888888')
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
      .backgroundColor('#FFFFFF')
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
