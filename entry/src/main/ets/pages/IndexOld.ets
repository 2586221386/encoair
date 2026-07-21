import { MainPageContent } from './MainPageContent';
import { SettingsPage } from './SettingsPage';
import { pageBg, tabBarInactive } from '../common/AppTheme';

/**
 * 主页面（API 22 版）
 * 使用常规 Tabs 底部导航（兼容旧版系统，无 API 23 依赖）
 * 页面内容（状态/回调/UI）委托给 MainPageContent 共用组件
 */
@Entry
@Component
struct Index {
  @State rawHexLog: string = '';
  @State currentIndex: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = true;

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        MainPageContent({
          bottomPadding: 0,
          onRawHexLogChange: (hex: string) => { this.rawHexLog = hex; }
        })
      }
      .tabBar(this.TabBarItem('🏠', '主页', 0))

      TabContent() {
        SettingsPage({ rawHexLog: this.rawHexLog })
      }
      .tabBar(this.TabBarItem('⚙️', '设置', 1))
    }
    .barHeight(56)
    .barMode(BarMode.Fixed)
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor(pageBg(this.isDarkMode))
    .onChange((index: number) => {
      this.currentIndex = index;
    })
  }

  @Builder TabBarItem(icon: string, title: string, index: number) {
    Column() {
      Text(icon).fontSize(22)
      Text(title).fontSize(11).fontColor(this.currentIndex === index ? '#007AFF' : tabBarInactive(this.isDarkMode)).margin({ top: 2 })
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }
}
