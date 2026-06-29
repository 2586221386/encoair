/**
 * 应用主题色彩定义
 * 深色模式（默认）与浅色模式双套配色方案
 * 组件通过 @StorageProp('isDarkMode') 感知当前模式
 */

/** 页面背景色 */
export function pageBg(dark: boolean): string { return dark ? '#0D0D1A' : '#F1F3F5'; }
/** 卡片背景色 */
export function cardBg(dark: boolean): string { return dark ? '#12122E' : '#FFFFFF'; }
/** 状态栏/二级卡片背景 */
export function statusBg(dark: boolean): string { return dark ? '#1A1A3E' : '#F0F0F5'; }
/** 按钮/选中项非激活背景 */
export function btnInactiveBg(dark: boolean): string { return dark ? '#1E1E3E' : '#E8E8F0'; }
/** 子按钮非激活背景 */
export function btnSubBg(dark: boolean): string { return dark ? '#1A1A3E' : '#E0E0EB'; }
/** 卡片边框色 */
export function borderColor(dark: boolean): string { return dark ? '#2A2A5E' : '#D0D5E0'; }
/** 主文字色 */
export function textPrimary(dark: boolean): string { return dark ? '#FFFFFF' : '#1A1A2E'; }
/** 次级文字色（标题/副标题） */
export function textSecondary(dark: boolean): string { return dark ? '#AAAACC' : '#3A3A4A'; }
/** 辅助文字色 */
export function textTertiary(dark: boolean): string { return dark ? '#8888AA' : '#555568'; }
/** 弱化文字色 */
export function textMuted(dark: boolean): string { return dark ? '#666688' : '#6E6E7E'; }
/** 提示/箭头色 */
export function textHint(dark: boolean): string { return dark ? '#6666AA' : '#5A5A72'; }
/** 连接成功绿色 */
export const accentGreen = '#4CAF50';
/** 断开红色 */
export function accentRed(dark: boolean): string { return dark ? '#FF4444' : '#D32F2F'; }
/** 连接中橙色 */
export function accentOrange(dark: boolean): string { return dark ? '#FF9800' : '#E65100'; }
/** 扫描蓝色 */
export function accentBlue(dark: boolean): string { return dark ? '#2196F3' : '#1565C0'; }
/** 充电金色 */
export function accentGold(dark: boolean): string { return dark ? '#FFD700' : '#B8860B'; }
/** 主色调蓝 */
export const accentPrimary = '#2A5CFF';
/** 主色调蓝（发光） */
export const accentPrimaryGlow = '#4A7CFF';
/** 取消按钮橙 */
export function cancelOrange(dark: boolean): string { return dark ? '#FF6B35' : '#E65100'; }
/** 充电徽章背景 */
export function chargingBadgeBg(dark: boolean): string { return dark ? '#332200' : '#FFF3E0'; }
/** 低电量徽章背景 */
export function lowBattBadgeBg(dark: boolean): string { return dark ? '#330000' : '#FFEBEE'; }
/** HEX 数据文字色 */
export function hexTextColor(dark: boolean): string { return dark ? '#88AACC' : '#445566'; }
/** 设置页描述文字 */
export function descTextColor(dark: boolean): string { return dark ? '#666688' : '#5A5A6A'; }
/** 设置页提示文字（极弱） */
export function tipTextColor(dark: boolean): string { return dark ? '#555577' : '#72727E'; }
/** 底部水印文字 */
export function watermarkText(dark: boolean): string { return dark ? '#444466' : '#90909A'; }
/** 弹窗背景渐变色标1 */
export function popupGradient1(dark: boolean): string { return dark ? '#1A1A3E' : '#E8E8F5'; }
/** 弹窗背景渐变色标2 */
export function popupGradient2(dark: boolean): string { return dark ? '#12122E' : '#FFFFFF'; }
/** 弹窗半透明遮罩 */
export function popupScrimTop(dark: boolean): string { return dark ? '#66000000' : '#44FFFFFF'; }
export function popupScrimBottom(dark: boolean): string { return dark ? '#99000000' : '#88FFFFFF'; }
/** 进度条底色 */
export function progressBg(dark: boolean): string { return dark ? '#1E1E3E' : '#E0E0EB'; }
/** 未连接灰色 */
export function disconnectedGray(dark: boolean): string { return dark ? '#9E9E9E' : '#757575'; }
/** 灰色开关/按钮 */
export function grayBtn(dark: boolean): string { return dark ? '#666666' : '#999999'; }
/** 面板背景色（带透明度） */
export function panelBgAlpha(dark: boolean): string { return dark ? '#28FFFFFF' : '#18000000'; }
/** 未选中 TabBar 文字 */
export function tabBarInactive(dark: boolean): string { return dark ? '#666688' : '#6E6E80'; }
/** 分隔点颜色 */
export function dotSeparator(dark: boolean): string { return dark ? '#CCCCCC' : '#AAAAAA'; }

// ============== 桌面卡片专用主题 ==============
/** 卡片背景色 */
export function widgetBg(dark: boolean): string { return dark ? '#1A1D2E' : '#FFFFFF'; }
/** 卡片主文字 */
export function widgetTextPrimary(dark: boolean): string { return dark ? '#E8E8EC' : '#1A1A2E'; }
/** 卡片次级文字（标签） */
export function widgetTextSecondary(dark: boolean): string { return dark ? '#9999AA' : '#555568'; }
/** 卡片弱化文字（时间戳等） */
export function widgetTextMuted(dark: boolean): string { return dark ? '#777788' : '#90909A'; }
/** 卡片进度条底色 */
export function widgetProgressBg(dark: boolean): string { return dark ? '#2A2A3E' : '#E8E8EC'; }
/** 卡片分隔点 */
export function widgetDotSep(dark: boolean): string { return dark ? '#555588' : '#BBBBCC'; }
