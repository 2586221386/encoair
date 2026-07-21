import router from '@ohos.router';
import { cardBg, textPrimary, textSecondary, textHint, textMuted, pageBg } from '../common/AppTheme';

/**
 * 帮助条目数据模型
 */
class HelpItem {
  title: string;
  content: string;
  isExpanded: boolean;

  constructor(title: string, content: string) {
    this.title = title;
    this.content = content;
    this.isExpanded = false;
  }
}

/**
 * 使用帮助页面
 */
@Entry
@Component
struct HelpPage {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = true;
  @State helpItems: HelpItem[] = [];

  aboutToAppear(): void {
    this.helpItems = [
      new HelpItem(
        '蓝牙连接',
        '打开软件后，主页面会自动启动持续监听模式，检测到已配对的耳机时自动连接。\n\n' +
        '软件通过 SPP/RFCOMM 协议与 OPPO Enco Air5 Pro 耳机建立连接，连接成功后即可查看电量、切换降噪模式、管理 EQ 预设等。\n\n' +
        '如果连接失败，请确认：\n' +
        '• 耳机已开机且与手机配对连接\n' +
        '• 手机蓝牙已开启\n' +
        '• 耳机未与其他设备同时连接'
      ),
      new HelpItem(
        '电量查看',
        '连接成功后，主界面会实时显示三部分电量信息：\n\n' +
        '• 左耳电量 — 左耳机的剩余电量百分比\n' +
        '• 右耳电量 — 右耳机的剩余电量百分比\n' +
        '• 充电仓电量 — 充电盒的剩余电量百分比\n\n' +
        '充电中的耳机会显示⚡闪电标识。当耳机断开连接时，电量会显示为"--"。\n\n' +
        '您也可以在桌面添加电量卡片，无需打开应用即可查看电量。'
      ),
      new HelpItem(
        '降噪模式 (ANC)',
        '连接耳机后，可以在主界面切换降噪模式：\n\n' +
        '• 关闭 — 关闭降噪功能\n' +
        '• 降噪 — 主动降噪，过滤环境噪音\n' +
        '• 通透 — 通透模式，可听到外界声音\n' +
        '• 自适应 — 根据环境自动切换降噪等级（部分设备支持）\n\n' +
        '降噪模式下还可选择子模式：\n' +
        '• 智能降噪 — 根据环境噪音自动调节强度\n' +
        '• 轻度/中度/深度降噪 — 不同强度的降噪效果\n\n' +
        '注意：降噪模式仅在耳机佩戴时生效，放入充电仓后会自动关闭。'
      ),
      new HelpItem(
        '佩戴检测',
        '部分耳机型号支持佩戴检测功能，可在主界面开启或关闭：\n\n' +
        '• 开启后，摘下耳机时自动暂停播放音乐\n' +
        '• 重新佩戴耳机时自动继续播放\n\n' +
        '佩戴状态区域会实时显示：\n' +
        '• 佩戴中 — 耳机正在耳朵上\n' +
        '• 已取下 — 耳机已从耳朵上取下\n' +
        '• 充电仓内 — 耳机已放入充电仓'
      ),
      new HelpItem(
        '空间音频',
        '连接耳机后，主界面会显示空间音频控制区域。\n\n' +
        '• 关闭 — 关闭空间音频效果\n' +
        '• 固定 — 开启空间音频，声场固定在前方\n' +
        '• 头部追踪 — 声场随头部转动而变化，沉浸感更强\n\n' +
        '部分设备仅支持开关式空间音效（关闭/开启），不支持头部追踪。\n\n' +
        '空间音频功能仅在支持的设备上显示。'
      ),
      new HelpItem(
        '游戏模式与游戏音效',
        '连接耳机后，主界面会显示游戏模式与游戏音效开关。\n\n' +
        '• 游戏模式 — 降低音频延迟，适合游戏场景\n' +
        '• 游戏音效 — 增强游戏场景的音频效果（部分设备支持）\n\n' +
        '两个开关可独立控制，状态会与耳机实时同步。'
      ),
      new HelpItem(
        '大师调音 (EQ)',
        '大师调音功能可让您自定义耳机音效，在主页面的"大师调音"卡片中点击进入。\n\n' +
        '推荐预设：\n' +
        '• 软件内置多组默认 EQ 预设，点击"应用"即可切换\n' +
        '• 当前使用中的预设会显示"使用中"标签\n\n' +
        '自定义均衡器：\n' +
        '• 支持 10 段均衡器调节（31Hz ~ 16KHz）\n' +
        '• 每段增益范围 -6dB ~ +6dB，步进 1dB\n' +
        '• 最多可保存 3 条自定义 EQ 预设\n' +
        '• 长按自定义 EQ 可删除\n\n' +
        '自定义 EQ 仅支持具备此能力的设备。'
      ),
      new HelpItem(
        '多设备管理',
        '在设置页面或主界面点击"双设备连接"可进入多设备管理页面：\n\n' +
        '• 双设备连接 — 开启后耳机可同时连接两台设备\n' +
        '• 优先设备 — 设置优先连接的设备（支持自动/手动选择）\n' +
        '• 已配对设备列表 — 查看所有已配对设备，点击可连接或断开\n\n' +
        '注意：多设备连接功能仅在耳机支持时显示。'
      ),
      new HelpItem(
        '深色模式与主题',
        '在设置页面的"主题设置"卡片中可以控制应用的显示模式：\n\n' +
        '• 跟随系统深色模式 — 开启后自动跟随系统切换深色/浅色模式（默认开启）\n' +
        '• 深色模式 — 关闭"跟随系统"后出现，可手动切换深色/浅色模式\n\n' +
        '应用采用轻量化卡片设计风格，柔和圆角、大留白，在两种模式下均有良好的可读性。'
      ),
      new HelpItem(
        '弹窗功能',
        '弹窗是软件的轻量级交互入口，可在以下场景使用：\n\n' +
        '• 从设置页面点击"预览弹窗"查看效果\n' +
        '• 被其他应用（例如智慧生活）通过意图唤醒时自动弹出\n\n' +
        '弹窗会显示耳机电量信息，获取到完整电量后 3 秒自动关闭。\n\n' +
        '你可以在设置页面自定义弹窗的背景图片，支持从相册选择任意图片。'
      ),
      new HelpItem(
        '桌面卡片',
        '点击设置页面的"添加桌面卡片"按钮，可以将电量卡片添加到手机桌面或负一屏。\n\n' +
        '桌面卡片会显示耳机的左耳、右耳和充电仓电量。\n\n' +
        '注意：\n' +
        '• 桌面卡片的电量数据会有延迟（通过后台定时刷新）\n' +
        '• 耳机断开时卡片会显示"--"\n' +
        '• 刷新频率由系统调度，非实时'
      ),
      new HelpItem(
        '常驻通知与后台保活',
        '在设置页面开启"常驻通知显示电量"开关后：\n\n' +
        '• 状态栏会常驻一条通知，显示电量和 ANC 状态\n' +
        '• 应用会保持后台运行，退到后台后耳机连接不会断开\n' +
        '• 点击通知可快速打开应用主界面\n\n' +
        '首次开启时，系统会弹出通知权限申请对话框，允许后即可使用。\n\n' +
        '即使耳机断开连接，通知也会显示"后台监听中"，并在检测到耳机时自动重连。\n\n' +
        '如不需要后台保活，关闭此开关即可停止。'
      ),
      new HelpItem(
        '常见问题',
        'Q: 连接后看不到电量？\n' +
        'A: 软件已开启持续监听模式，检测到耳机会自动连接。请确保耳机已开机且在附近，稍等几秒即可。\n\n' +
        'Q: 耳机断开后会自动重连吗？\n' +
        'A: 会。软件后台持续监听，检测到耳机后自动尝试重连。\n\n' +
        'Q: 后台运行会耗电吗？\n' +
        'A: 开启常驻通知时应用会保持后台运行，耗电量较低。如不需要可关闭。\n\n' +
        'Q: 如何切换深色/浅色模式？\n' +
        'A: 在设置页面的"主题设置"中，默认跟随系统。关闭"跟随系统"后可手动切换深色/浅色模式。\n\n' +
        'Q: 支持哪些耳机型号？\n' +
        'A: 项目适配了 OPPO 系 137 款设备（含 OPPO、OnePlus、realme 品牌），以 Enco Air5 Pro 为主力测试机型。'
      )
    ];
  }

  /**
   * 切换某个条目的展开/收起状态
   */
  private toggleItem(index: number): void {
    let items: HelpItem[] = [];
    for (let i = 0; i < this.helpItems.length; i++) {
      let item = new HelpItem(this.helpItems[i].title, this.helpItems[i].content);
      if (i === index) {
        item.isExpanded = !this.helpItems[i].isExpanded;
      } else {
        item.isExpanded = this.helpItems[i].isExpanded;
      }
      items.push(item);
    }
    this.helpItems = items;
  }

  build() {
    Column() {
      // 顶部导航栏
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
        Text('使用帮助')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(textPrimary(this.isDarkMode))
          .margin({ left: 8 })
        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      // 帮助列表
      Scroll() {
        Column() {
          ForEach(this.helpItems, (item: HelpItem, index: number) => {
            Column() {
              // 标题行（可点击展开/收起）
              Row() {
                Text(item.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(textPrimary(this.isDarkMode))
                  .layoutWeight(1)
                Text(item.isExpanded ? '收起 ▲' : '展开 ▼')
                  .fontSize(12)
                  .fontColor(textHint(this.isDarkMode))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => {
                this.toggleItem(index);
              })

              // 展开的内容
              if (item.isExpanded) {
                Text(item.content)
                  .fontSize(13)
                  .fontColor(textSecondary(this.isDarkMode))
                  .lineHeight(22)
                  .width('100%')
                  .padding({ left: 16, right: 16, bottom: 14 })
              }
            }
            .width('85%')
            .borderRadius(20)
            .backgroundColor(cardBg(this.isDarkMode))
            .margin({ top: 16 })
            .clip(true)
          }, (item: HelpItem, index: number) => `${index}_${item.isExpanded}`)
        }
        .transition(TransitionEffect.opacity(0.3))
        .width('100%')
        .padding({ bottom: 30 })
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
}
