/**
 * OPPO 蓝牙耳机设备能力检测模块
 * 参考 OppoPods-2.0.7 DeviceCapabilities.kt + ConfigManager.kt 设计
 *
 * 架构:
 *   设备名(BluetoothDevice.name) → 白名单匹配 → DeviceCapabilities
 *   用户设置(SettingsPage) → 能力覆写 → 最终生效的能力
 *
 * 添加新型号只需在对应白名单数组中加一行设备名即可。
 */

// ============== 能力白名单 ==============

/** 支持空间音频头部追踪的型号（标准 0x0422 协议） */
const SPATIAL_AUDIO_DEVICES: string[] = [
  'OPPO Enco X3',
];

/** 使用空间音效开关协议的型号（0x1B feature switch，替代标准 0x0422） */
const SPATIAL_SOUND_SWITCH_DEVICES: string[] = [
  'OPPO Enco Free4',
  'OPPO Enco Air5',  // 同时匹配 Air5 和 Air5 Pro
];

/** 旧版 ANC 指令反转型号（0x01=降噪, 0x02=关闭） */
const LEGACY_ANC_DEVICES: string[] = [
  'OPPO Enco Air2 Pro',
];

/** 支持自适应降噪的型号 */
const ADAPTIVE_ANC_DEVICES: string[] = [
  'OPPO Enco Free4',
];

/** 支持双设备连接的型号 */
const DUAL_DEVICE_DEVICES: string[] = [
  'OPPO Enco Air5',  // 同时匹配 Air5 和 Air5 Pro
  'OPPO Enco Free4',
  'OPPO Enco X3',
];

/** 支持多连接管理（优先设备/自动切换）的型号 */
const MULTI_CONNECT_MANAGE_DEVICES: string[] = [
  'OPPO Enco Air5',  // 同时匹配 Air5 和 Air5 Pro
  'OPPO Enco X3',
];

// ============== 能力覆写常量 ==============

/** 三态覆写值 */
export const CAP_OVERRIDE_AUTO = 0;           // 自动检测
export const CAP_OVERRIDE_FORCE_ENABLED = 1;  // 强制开启
export const CAP_OVERRIDE_FORCE_DISABLED = 2; // 强制关闭

// ============== 类型定义 ==============

/** 设备能力数据类 */
export class DeviceCapabilities {
  /** 是否支持自适应降噪 */
  adaptiveSupported: boolean = false;
  /** 是否支持标准空间音频（0x0422 头部追踪） */
  spatialAudioSupported: boolean = false;
  /** 是否使用空间音效开关协议（0x1B switch） */
  spatialSoundSwitchSupported: boolean = false;
  /** 是否为旧版 ANC 指令反转 */
  legacyAnc: boolean = false;
  /** 是否支持双设备连接（feature 0x11） */
  dualDeviceSupported: boolean = false;
  /** 是否支持多连接管理（优先设备/自动切换，cmd 0x0132） */
  multiConnectManageSupported: boolean = false;
}

/** 能力覆写配置（持久化到 Preferences） */
export class CapabilityOverrides {
  spatialAudio: number = CAP_OVERRIDE_AUTO;
  spatialSoundSwitch: number = CAP_OVERRIDE_AUTO;
  ancLegacy: number = CAP_OVERRIDE_AUTO;
  adaptiveAnc: number = CAP_OVERRIDE_AUTO;
}

// ============== 核心检测函数 ==============

/**
 * 检测设备能力（主入口）
 * @param deviceName 蓝牙设备名（如 "OPPO Enco Air5 Pro"）
 * @param overrides 用户手动覆写配置（可选）
 */
export function detectDeviceCapabilities(
  deviceName: string,
  overrides: CapabilityOverrides | null = null
): DeviceCapabilities {
  if (!deviceName) return new DeviceCapabilities();

  const caps = new DeviceCapabilities();
  caps.spatialAudioSupported = resolveCap(
    overrides?.spatialAudio ?? CAP_OVERRIDE_AUTO,
    isInList(deviceName, SPATIAL_AUDIO_DEVICES)
  );
  caps.spatialSoundSwitchSupported = resolveCap(
    overrides?.spatialSoundSwitch ?? CAP_OVERRIDE_AUTO,
    isInList(deviceName, SPATIAL_SOUND_SWITCH_DEVICES)
  );
  caps.legacyAnc = resolveCap(
    overrides?.ancLegacy ?? CAP_OVERRIDE_AUTO,
    isInList(deviceName, LEGACY_ANC_DEVICES)
  );
  caps.adaptiveSupported = resolveCap(
    overrides?.adaptiveAnc ?? CAP_OVERRIDE_AUTO,
    isInList(deviceName, ADAPTIVE_ANC_DEVICES)
  );
  caps.dualDeviceSupported = isInList(deviceName, DUAL_DEVICE_DEVICES);
  caps.multiConnectManageSupported = isInList(deviceName, MULTI_CONNECT_MANAGE_DEVICES);

  return caps;
}

/**
 * 判断设备名是否在白名单中（子串匹配，不区分大小写）
 * 如 "OPPO Enco Air5 Pro" 能匹配白名单 "OPPO Enco Air5"
 */
function isInList(deviceName: string, list: string[]): boolean {
  const normalized = normalize(deviceName);
  return list.some((entry) => {
    const normEntry = normalize(entry);
    return normalized.includes(normEntry) || normEntry.includes(normalized);
  });
}

/** 归一化设备名：去空格 + 转小写 */
function normalize(name: string): string {
  return name.toLowerCase().replace(/\s/g, '');
}

/**
 * 三态覆写解析
 * AUTO → 返回自动检测值; FORCE_ENABLED → true; FORCE_DISABLED → false
 */
function resolveCap(override: number, autoDetected: boolean): boolean {
  if (override === CAP_OVERRIDE_FORCE_ENABLED) return true;
  if (override === CAP_OVERRIDE_FORCE_DISABLED) return false;
  return autoDetected;
}
