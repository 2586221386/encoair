import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import { MainPageContent } from './MainPageContent';
import { SettingsPage } from './SettingsPage';
import { pageBg, tabBarInactive, accentPrimary } from '../common/AppTheme';

/**
 * 主页面（API 23+ 版）
 * 使用 HdsTabs 悬浮底部导航 + 沉浸光感材质
 * 页面内容（状态/回调/UI）委托给 MainPageContent 共用组件
 */
@Entry
@Component
struct Index {
  @State rawHexLog: string = '';
  @State currentIndex: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = true;
  private tabsController: HdsTabsController = new HdsTabsController();

  build() {
    HdsTabs({ controller: this.tabsController }) {
      TabContent() {
        MainPageContent({
          bottomPadding: 100,
          onRawHexLogChange: (hex: string) => { this.rawHexLog = hex; }
        })
      }
      .tabBar(this.TabBarItem('🏠', '主页', 0))

      TabContent() {
        SettingsPage({ rawHexLog: this.rawHexLog })
      }
      .tabBar(this.TabBarItem('⚙️', '设置', 1))
    }
    .barOverlap(true)
    .vertical(false)
    .barPosition(BarPosition.End)
    .barFloatingStyle({
      barBottomMargin: 28,
      gradientMask: {
        maskHeight: 88,
        maskColor: Color.Transparent
      },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    })
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
      Text(title).fontSize(11).fontColor(this.currentIndex === index ? accentPrimary : tabBarInactive(this.isDarkMode)).margin({ top: 2 })
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }
}
