/**
 * 应用主题色彩定义 — 轻量化卡片分层风格
 * 深色模式与浅色模式双套配色方案
 * 组件通过 @StorageProp('isDarkMode') 感知当前模式
 *
 * 设计原则：
 * - 卡片分层：依靠背景色明度差异，无边框
 * - 柔和圆角：卡片 20，按钮 24/16
 * - 简约配色：中性灰底 + 柔和蓝主色
 * - 无Material：无厚重阴影、无高饱和渐变
 */

// ============== 基础色板 ==============
/** 主色调（柔和蓝） */
export const accentPrimary = '#007AFF';
/** 成功绿色 */
export const accentGreen = '#34C759';
/** 断开红色 */
export const accentRed = '#FF3B30';
/** 连接中橙色 */
export const accentOrange = '#FF9500';

// ============== 背景分层体系 ==============
/** 页面背景（最底层） */
export function pageBg(dark: boolean): string { return dark ? '#111115' : '#F5F5F7'; }
/** 卡片背景（第二层） */
export function cardBg(dark: boolean): string { return dark ? '#1C1C1E' : '#FFFFFF'; }
/** 次级卡片背景（第三层，卡片内再嵌套） */
export function statusBg(dark: boolean): string { return dark ? '#28282B' : '#F2F2F5'; }
/** 按钮/控件非激活背景 */
export function btnInactiveBg(dark: boolean): string { return dark ? '#2C2C2E' : '#E8E8ED'; }
/** 子按钮非激活背景 */
export function btnSubBg(dark: boolean): string { return dark ? '#28282B' : '#E0E0E5'; }

// ============== 文字色阶体系 ==============
/** 主文字色（最高强调） */
export function textPrimary(dark: boolean): string { return dark ? '#FFFFFF' : '#1C1C1E'; }
/** 次级文字色（标题/副标题，中等强调） */
export function textSecondary(dark: boolean): string { return dark ? '#8E8E93' : '#3A3A3C'; }
/** 辅助文字色（弱强调） */
export function textTertiary(dark: boolean): string { return dark ? '#8E8E93' : '#6E6E72'; }
/** 弱化文字色（最弱） */
export function textMuted(dark: boolean): string { return dark ? '#636366' : '#8E8E93'; }
/** 提示文字色 */
export function textHint(dark: boolean): string { return dark ? '#636366' : '#8E8E93'; }
/** 扫描中蓝色 */
export function accentBlue(dark: boolean): string { return dark ? '#007AFF' : '#007AFF'; }
/** 分隔线/装饰色 */
export function dividerColor(dark: boolean): string { return dark ? '#38383A' : '#D1D1D6'; }

// ============== 功能色 ==============
/** 充电金色 */
export function accentGold(dark: boolean): string { return dark ? '#FFD60A' : '#C89B3C'; }
/** 取消按钮橙 */
export function cancelOrange(dark: boolean): string { return dark ? '#FF9500' : '#E65100'; }
/** 充电徽章背景 */
export function chargingBadgeBg(dark: boolean): string { return dark ? '#3A3200' : '#FFF8E1'; }
/** 低电量徽章背景 */
export function lowBattBadgeBg(dark: boolean): string { return dark ? '#3D0000' : '#FFEBEE'; }
/** 未连接灰色 */
export function disconnectedGray(dark: boolean): string { return dark ? '#8E8E93' : '#8E8E93'; }
/** 灰色开关/按钮 */
export function grayBtn(dark: boolean): string { return dark ? '#636366' : '#AEAEB2'; }

// ============== 设置页专用 ==============
/** HEX 数据文字色 */
export function hexTextColor(dark: boolean): string { return dark ? '#8E8E93' : '#636366'; }
/** 设置页描述文字 */
export function descTextColor(dark: boolean): string { return dark ? '#8E8E93' : '#6E6E72'; }
/** 设置页提示文字 */
export function tipTextColor(dark: boolean): string { return dark ? '#636366' : '#8E8E93'; }
/** 底部水印文字 */
export function watermarkText(dark: boolean): string { return dark ? '#636366' : '#AEAEB2'; }

// ============== TabBar ==============
/** 未选中 TabBar 文字 */
export function tabBarInactive(dark: boolean): string { return dark ? '#636366' : '#8E8E93'; }
/** 分隔点颜色 */
export function dotSeparator(dark: boolean): string { return dark ? '#38383A' : '#D1D1D6'; }

// ============== 弹窗专用 ==============
/** 弹窗背景色（纯色替代渐变） */
export function popupBg(dark: boolean): string { return dark ? '#1C1C1E' : '#FFFFFF'; }
/** 弹窗半透明遮罩 */
export function popupScrim(dark: boolean): string { return dark ? '#B8000000' : '#B3000000'; }

// ============== 桌面卡片专用 ==============
export function widgetBg(dark: boolean): string { return dark ? '#1C1C1E' : '#FFFFFF'; }
export function widgetTextPrimary(dark: boolean): string { return dark ? '#FFFFFF' : '#1C1C1E'; }
export function widgetTextSecondary(dark: boolean): string { return dark ? '#8E8E93' : '#3A3A3C'; }
export function widgetTextMuted(dark: boolean): string { return dark ? '#636366' : '#8E8E93'; }
export function widgetProgressBg(dark: boolean): string { return dark ? '#38383A' : '#E8E8ED'; }
export function widgetDotSep(dark: boolean): string { return dark ? '#38383A' : '#D1D1D6'; }

// ============== 废弃兼容（保留定义避免编译错误） ==============
/** @deprecated 不再使用边框，保留为空字符串 */
export function borderColor(dark: boolean): string { return 'transparent'; }
/** @deprecated 不再使用发光色 */
export const accentPrimaryGlow = '#007AFF';
/** @deprecated 进度条底色，兼容引用 */
export function progressBg(dark: boolean): string { return btnInactiveBg(dark); }
/** @deprecated 不再使用渐变背景 */
export function popupGradient1(dark: boolean): string { return popupBg(dark); }
export function popupGradient2(dark: boolean): string { return popupBg(dark); }
/** @deprecated 弹窗遮罩统一使用 popupScrim */
export function popupScrimTop(dark: boolean): string { return popupScrim(dark); }
export function popupScrimBottom(dark: boolean): string { return popupScrim(dark); }
