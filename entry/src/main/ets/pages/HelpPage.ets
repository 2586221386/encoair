import router from '@ohos.router';
import { cardBg, borderColor, textPrimary, textSecondary, textHint, pageBg } from '../common/AppTheme';

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
        '打开软件后，点击主页面下方的连接按钮即可搜索并连接已配对的的 OPPO Enco Air5 Pro 耳机。\n\n' +
        '软件会通过 SPP/RFCOMM 协议与耳机建立连接，连接成功后即可查看电量、切换降噪模式等。\n\n' +
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
        '充电中的耳机会显示⚡闪电标识。当耳机断开连接时，电量会显示为"--"。'
      ),
      new HelpItem(
        '降噪模式 (ANC)',
        '连接耳机后，可以在主界面切换降噪模式：\n\n' +
        '• 关闭 — 关闭降噪功能\n' +
        '• 降噪 — 主动降噪，过滤环境噪音\n' +
        '• 通透 — 通透模式，可听到外界声音\n' +
        '• 自适应 — 根据环境自动切换降噪等级\n' +
        '• 深度/中度/轻度降噪 — 不同强度的降噪效果\n\n' +
        '注意：降噪模式仅在耳机佩戴时生效，放入充电仓后会自动关闭。'
      ),
      new HelpItem(
        '佩戴状态',
        '软件会实时检测耳机的佩戴状态：\n\n' +
        '• 佩戴中 — 耳机正在耳朵上\n' +
        '• 已取下 — 耳机已从耳朵上取下\n' +
        '• 充电仓内 — 耳机已放入充电仓\n\n' +
        '佩戴状态变化时，ANC 模式会自动调整。例如取下耳机后降噪会自动暂停。'
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
        '常驻通知',
        '在设置页面开启"常驻通知显示电量"开关后：\n\n' +
        '• 状态栏会常驻一条通知，显示电量和 ANC 状态\n' +
        '• 应用会保持后台运行，退到后台后耳机连接不会断开\n' +
        '• 点击通知可快速打开应用主界面\n\n' +
        '首次开启时，系统会弹出通知权限申请对话框，允许后即可使用。\n\n' +
        '如不需要后台保活，关闭此开关即可停止。'
      ),
      new HelpItem(
        '弹窗背景自定义',
        '在设置页面的"弹窗背景"卡片中：\n\n' +
        '• 点击"设置弹窗背景"从相册选择图片\n' +
        '• 支持任意图片格式（包括 HEIC），会自动转换为 JPEG\n' +
        '• 图片会填充覆盖整个弹窗区域\n' +
        '• 点击"恢复默认背景"可恢复原始纯色背景\n\n' +
        '点击"预览弹窗"可以立即查看弹窗效果。'
      ),
      new HelpItem(
        '游戏模式',
        '连接耳机后，主界面会显示游戏模式开关。\n\n' +
        '• 开启游戏模式 — 降低音频延迟，适合游戏场景\n' +
        '• 关闭游戏模式 — 恢复普通音频模式\n\n' +
        '游戏模式的状态会与耳机实时同步。'
      ),
      new HelpItem(
        '常见问题',
        'Q: 连接后看不到电量？\n' +
        'A: 请稍等几秒，或点击重新连接，软件会在连接成功后自动查询电量。\n\n' +
        'Q: 耳机断开后自动重连吗？\n' +
        'A: 会。软件在检测到断开后会自动尝试重连（最多5次）。\n\n' +
        'Q: 后台运行会耗电吗？\n' +
        'A: 开启常驻通知时应用会保持后台运行，耗电量较低。如不需要可关闭。\n\n' +
        'Q: 支持哪些耳机型号？\n' +
        'A: 目前仅支持 OPPO Enco Air5 Pro，其他OPPO设备请自行测试。'
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
            .borderRadius(12)
            .backgroundColor(cardBg(this.isDarkMode))
            .border({ width: 1, color: borderColor(this.isDarkMode) })
            .margin({ top: index === 0 ? 16 : 12 })
            .clip(true)
          }, (item: HelpItem, index: number) => `${index}_${item.isExpanded}`)
        }
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
    .backgroundColor(pageBg(this.isDarkMode))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .padding({ top: this.statusBarHeight })
  }
}
