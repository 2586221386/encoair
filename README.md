# Air5pro 耳机助手

鸿蒙 6 平台 OPPO Enco Air5 Pro 蓝牙耳机管理工具。通过 SPP/RFCOMM 私有协议与耳机通信，提供电量监控、ANC 降噪控制、佩戴检测、EQ 大师调音、多设备连接管理、桌面卡片等全功能管理。

## 功能概览

| 功能 | 说明 |
|------|------|
| 🎧 **电量监控** | 实时显示左耳、右耳、充电仓三段电量，环形进度条可视化 |
| 🎵 **ANC 降噪控制** | 支持降噪(智能/轻度/中度/深度)、关闭、通透、自适应等多模式切换 |
| 👂 **佩戴检测** | 实时显示各耳机佩戴状态：佩戴、在仓、取出、断开 |
| 🎮 **游戏模式** | 低延迟游戏模式 + 游戏音效开关 |
| 🎧 **空间音频** | 空间音频效果开关（0x1B）/ 三模式（0x0422 头部追踪）自适应 |
| 📱 **多设备连接** | 双设备开关、设备列表查询、连接/断开/取消配对、音频优先级控制、自动切换 |
| 🎚️ **EQ 大师调音** | 按设备型号动态加载预设 + 自定义 EQ 创建/编辑/删除（10 段 PEQ） |
| 🔔 **常驻通知** | 状态栏显示电量、ANC 状态和连接状态；断连时自动切换为"后台监听中" |
| 🖼️ **弹窗背景** | 自定义弹窗背景图片（支持 GIF 动画） |
| 📊 **桌面卡片** | 2×2 全量卡片 + 1×2 精简卡片，系统蓝牙电量降级保障 |
| 🔄 **预览弹窗** | 预览弹窗样式效果 |
| 🏠 **桌面组件** | 添加电量卡片到桌面 |
| ❓ **使用帮助** | 内置使用说明和常见问题 |
| 🛠️ **高级设置** | 空间音频协议选择、旧版 ANC 兼容、自适应降噪等能力覆写 |

## 技术架构

```
Index.ets (HdsTabs API23 / Tabs API22)
├── MainPageContent.ets (共用主页面内容)
├── SettingsPage.ets (独立设置页)
│   ├── 主题设置 (跟随系统 / 手动深色浅色)
│   ├── 通知管理 (常驻通知 + 断连保持后台活动)
│   ├── 弹窗背景 (自定义图片/GIF)
│   ├── 高级设置 (能力覆写)
│   └── 多设备管理入口
├── HelpPage.ets (使用帮助)
├── EqMasterPage.ets (EQ 大师调音)
├── EqEditorPage.ets (自定义 EQ 编辑)
└── MultiDeviceManagementPage.ets (多设备管理)

PopupWindow.ets (弹窗/子窗口预览)

BatteryWidgetPage.ets (2×2 卡片)
BatteryWidgetPage1x2.ets (1×2 卡片)

OppoEarphoneManager.ets (核心管理器 — 单例模式)
├── SPP RFCOMM 连接管理
│   ├── 自动连接 (已配对/已保存 MAC)
│   ├── 断连自动重连 (差异化策略)
│   ├── 持续 BLE 监听 (5s 周期)
│   ├── 系统音频状态检测 (自适应间隔轮询 3s→5s)
│   └── SPP 心跳保活 (30s)
├── 私有协议解析
│   ├── 电量 (三段式)
│   ├── ANC (多级模式)
│   ├── 佩戴状态 (双向同步)
│   ├── 游戏模式 (动态 feature 选择 0x06/0x28)
│   ├── 空间音频 (0x1B/0x0422)
│   ├── EQ 预设
│   ├── 固件版本 & 编解码器
│   └── 游戏音效
├── 多设备协议管理器 (MultiDeviceManager)
│   ├── 设备列表查询 (0x0112)
│   ├── 连接/断开/取消配对 (0x0429)
│   ├── 优先级/自动切换 (0x0132)
│   └── 状态变更通知 (0x0204)
├── 设备能力检测 (DeviceCapabilities)
│   ├── 白名单匹配 (137 型号)
│   ├── 产品 ID 精确定位
│   └── 运行时能力位图
├── 后台保活 (backgroundTaskManager BLUETOOTH_INTERACTION)
├── 桌面卡片推送 (formProvider.updateForm)
└── 常驻通知 (notificationManager, isOngoing, id=9001)

EntryAbility.ets (全屏适配 + API 版本分发 + 弹窗唤醒)
├── setWindowLayoutFullScreen(true)
├── 动态路由 Index(API23+) / IndexOld(API22)
└── PopupWindow 子窗口启动

BatteryFormAbility.ets (2×2 卡片生命周期)
BatteryFormAbility1x2.ets (1×2 卡片生命周期)
```

## 私有协议参考

| 命令 | 方向 | 说明 |
|------|------|------|
| `0x0106` | → | 查询电量 |
| `0x8106` | ← | 电量响应 |
| `0x010C` | → | 查询 ANC 模式 |
| `0x810C` | ← | ANC 模式 / 智能档位响应 |
| `0x0404` | → | 设置 ANC 模式 |
| `0x0403` | → | 设置功能开关（游戏/空间/双设备/佩戴检测） |
| `0x810D` | ← | 功能状态响应 |
| `0x010D` | → | 查询功能状态 |
| `0x0112` | → | 查询多设备连接列表 |
| `0x8112` | ← | 多设备列表响应 |
| `0x0429` | → | 多设备操作（连接/断开/取消配对/设优先） |
| `0x8429` | ← | 多设备操作响应 |
| `0x0132` | → | 查询多连接优先设备 |
| `0x8132` | ← | 优先设备响应 |
| `0x0204` | ← | 主动通知（含多连接状态变更） |
| `0x0406` | → | 设置 EQ 预设 |
| `0x810F` | ← | EQ 预设响应 |
| `0x0418` | → | 自定义 EQ 操作（创建/更新/删除） |
| `0x0122` | → | 查询设备端全部 EQ 条目 |
| `0x8122` | ← | 设备端 EQ 列表响应 |
| `0x8103` | ← | 产品 ID 响应 |
| `0x8100` | ← | 能力位图响应 |
| `0x0504` | ← | EQ 变更主动通知 |

## 设备支持

通过 `DeviceModelsData.ets` 白名单数据库匹配，支持 **137 个蓝牙耳机型号**，覆盖：

- **OPPO**：Enco X3/X3s/X3i、Enco Free4(丹拿版)、Enco Air4s/Air4 Pro、Enco R5/R4/R3 Pro、Enco Buds3/3 Pro、Enco Clip2 等
- **OnePlus**：Buds 3/4、Buds Pro 3、Nord Buds 3/3 Pro、Buds Ace 2、Flow Buds 等
- **realme**：Buds Air 5/5 Pro、Buds Air8、Buds Wireless 3 等

匹配策略：蓝牙名称模糊匹配 → productId（0x8103 响应）精确定位。

## 桌面卡片

| 卡片 | 尺寸 | 数据来源 |
|------|------|----------|
| 2×2 耳机电量 | 2 × 2 | 主应用 SPP → Preferences → formProvider.updateForm() |
| 1×2 精简电量 | 1 × 2 | 系统蓝牙 API 降级 |

当主应用停止运行时，1×2 卡片由系统蓝牙 API（connection.getRemoteDeviceBatteryInfo()）获取通用电量。2×2 卡片通过 dataTimestamp 检测数据新鲜度（30s 阈值），超时自动降级显示 "--"。

## API 版本兼容

| 版本 | 导航栏 | SDK |
|------|--------|-----|
| API 22 (HarmonyOS 6.0) | 常规 Tabs | compatibleSdkVersion |
| API 23+ (HarmonyOS 6.1+) | HdsTabs 悬浮 + 沉浸光感 | targetSdkVersion |

EntryAbility 启动时通过 deviceInfo.sdkApiVersion 动态路由到 Index.ets（API23+）或 IndexOld.ets（API22）。

## 连接状态检测

多层检测机制确保连接状态实时准确：

| 检测方式 | 间隔 | 说明 |
|----------|------|------|
| 系统音频轮询 | 3s→5s 自适应 | 连接初期快速轮询，稳定后降频 |
| SPP 心跳 | 30s | 保持通道活跃 + 写入失败即时感知断开 |
| SPP 空数据 | 实时 | sppRead 收到空 buffer 触发断开 |
| SPP IO 错误 | 实时 | 错误码 2901054 触发断开 |
| 多设备协议 | 查询时 | connState 交叉验证 |
| 系统音频断开事件 | — | 监听系统蓝牙连接状态变化（如有） |

## 后台保活

- 使用 `backgroundTaskManager` + `BackgroundMode.BLUETOOTH_INTERACTION` 长时任务
- 搭配 `isOngoing: true` 常驻通知防止系统杀进程
- 通知内容根据连接状态动态切换：已连接 → 显示电量+ANC / 断开 → 显示"后台监听中"
- **断连保持后台**（可选）："常驻通知显示电量"开启后，可额外启用"耳机未连接时保持后台活动"，在自然断开时保持后台保活运行，加速重连
- 连接断开后自动重启持续监听，检测到耳机自动重连
- 通知权限使用 `isNotificationEnabledSync()` 同步实时校验

## 构建与运行

前置条件：
1. 安装 HarmonyOS SDK API 22/23
2. API 23 需额外安装 UI Design Kit（DevEco Studio → Settings → Huawei SDK → UI Design Kit）

使用 DevEco Studio 打开项目后直接编译运行即可。支持 phone 和 tablet 设备。

## 下载

- Hap Store：https://sydxky.cn/detail.php?id=547&msg=published
- 华为应用市场：搜索 "Air5pro耳机助手"

## 致谢

- [OppoPods](https://github.com/1812z/OppoPods/releases)
- [OppoPodsManager](https://github.com/Zhaoyi-ya/OppoPodsManager)

本项目仅供学习研究使用。
