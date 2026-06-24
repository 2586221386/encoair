# Air5pro 耳机助手

鸿蒙 6 平台 OPPO Enco Air5 Pro 蓝牙耳机管理工具。通过 SPP/RFCOMM 私有协议与耳机通信，提供电量监控、ANC 降噪控制、佩戴检测、EQ 调音、桌面卡片等全功能管理。

## 功能概览

| 功能 | 说明 |
|------|------|
| 🎧 **电量监控** | 实时显示左耳、右耳、充电仓三段电量，环形进度条可视化 |
| 🎵 **ANC 降噪控制** | 支持降噪(智能/轻度/中度/深度)、关闭、通透三模式切换 |
| 👂 **佩戴检测** | 实时显示各耳机佩戴状态：佩戴、在仓、取出、断开 |
| 🎮 **游戏模式** | 低延迟游戏模式开关 |
| 🎧 **空间音频** | 空间音频效果开关 |
| 📱 **双设备连接** | 支持同时连接两台设备的开关控制 |
| 🎚️ **EQ 大师调音** | 至臻原音 / 澎湃低音 / 纯享人声三档预设切换 |
| 🔔 **常驻通知** | 状态栏显示电量和 ANC 状态，后台保活保持连接 |
| 🖼️ **弹窗背景** | 自定义弹窗背景图片（支持 GIF 动画） |
| 📊 **桌面卡片** | 2×2 全量卡片 + 1×2 精简卡片，系统电量降级保障 |
| 🔄 **预览弹窗** | 预览弹窗样式效果 |
| 🏠 **桌面组件** | 添加电量卡片到桌面 |
| ❓ **使用帮助** | 内置使用说明和常见问题 |

## 技术架构

```
Index.ets (HdsTabs API23 / Tabs API22)
├── MainPageContent.ets (共用主页面内容)
├── SettingsPage.ets (独立设置页)
└── HelpPage.ets (使用帮助)

PopupWindow.ets (弹窗/子窗口预览)

BatteryWidgetPage.ets (2×2卡片)
BatteryWidgetPage1x2.ets (1×2卡片)

OppoEarphoneManager.ets (核心管理器)
├── SPP RFCOMM 连接管理
├── 私有协议解析 (电量/ANC/佩戴/游戏/EQ)
├── 系统音频状态检测
├── 后台保活 (BLUETOOTH_INTERACTION)
├── 桌面卡片推送 (formProvider.updateForm)
└── 常驻通知 (notificationManager)

EntryAbility.ets (API版本分发 + 弹窗唤醒)
BatteryFormAbility.ets (2×2卡片生命周期)
BatteryFormAbility1x2.ets (1×2卡片生命周期)
```

## 桌面卡片

| 卡片 | 尺寸 | 数据来源 |
|------|------|----------|
| 2×2 耳机电量 | 2 × 2 | 主应用 SPP → Preferences → formProvider.updateForm() |
| 1×2 精简电量 | 1 × 2 | 系统蓝牙 API 降级 |

当主应用停止运行时，1×2 卡片为系统蓝牙 API（connection.getRemoteDeviceBatteryInfo()）获取通用电量。

## API 版本兼容

| 版本 | 导航栏 | SDK |
|------|--------|-----|
| API 22 (HarmonyOS 6.0) | 常规 Tabs | compatibleSdkVersion |
| API 23+ (HarmonyOS 6.1+) | HdsTabs 悬浮 + 沉浸光感 | targetSdkVersion |

EntryAbility 启动时通过 deviceInfo.sdkApiVersion 动态路由到 Index.ets（API23+）或 IndexOld.ets（API22）。

## 后台保活

- 使用 backgroundTaskManager + BackgroundMode.BLUETOOTH_INTERACTION 长时任务
- 搭配 isOngoing: true 常驻通知防止系统杀进程
- 连接断开后自动重启持续监听，检测到耳机自动重连

## 构建与运行

前置条件：
1. 安装 HarmonyOS SDK API 22/23
2. API 23 需额外安装 UI Design Kit（DevEco Studio → Settings → Huawei SDK → UI Design Kit）

使用 DevEco Studio 打开项目后直接编译运行即可。支持 phone 和 tablet 设备。

## 下载

- Hap Store：https://sydxky.cn/detail.php?id=547&msg=published
- 华为应用市场：搜索 "Air5pro耳机助手"

## 致谢

- [OppoPods]


本项目仅供学习研究使用。
