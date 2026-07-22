/**
 * OPPO 蓝牙耳机设备能力检测模块
 * 参考 OppoPods-2.0.7 DeviceProfileLoader.cs + DeviceCapabilities.cs 设计
 *
 * 架构:
 *   设备名(BluetoothDevice.name) → DeviceModelsData 白名单匹配 → DeviceCapabilities
 *   用户设置(SettingsPage) → 能力覆写 → 最终生效的能力
 *
 * 能力来源优先级:
 *   1. 运行时能力位图 (0x0100 响应)
 *   2. 用户手动覆写 (Preferences)
 *   3. 白名单预配置 (DeviceModelsData)
 */

import {
  DeviceModelEntry, DeviceFunctions, AncOption as ModelAncOption,
  findModelByDeviceName, findModelByProductId,
  modeKey, ancLabel, mainRank, getEqModeName
} from './DeviceModelsData';

// ============== 能力覆写常量 ==============

export const CAP_OVERRIDE_AUTO = 0;
export const CAP_OVERRIDE_FORCE_ENABLED = 1;
export const CAP_OVERRIDE_FORCE_DISABLED = 2;

// ============== ANC 选项类型 ==============

/** ANC 模式选项（UI 渲染用） */
export class AncOption {
  key: string = '';
  label: string = '';
  protocolIndex: number = 0;
  sendable: boolean = true;
  children: AncOption[] = [];
}

// ============== 类型定义 ==============

/** 设备能力数据类 */
export class DeviceCapabilities {
  /** 设备识别信息 */
  deviceName: string = '';
  modelName: string = 'Unknown';
  modelId: string = '';

  /** 自适应降噪 */
  adaptiveSupported: boolean = false;
  /** 标准空间音频（0x0422 头部追踪） */
  spatialAudioSupported: boolean = false;
  /** 空间音效开关协议（0x1B switch） */
  spatialSoundSwitchSupported: boolean = false;
  /** 空间音频三模式类型列表 */
  spatialTypes: number[] = [];
  /** 旧版 ANC 指令反转 */
  legacyAnc: boolean = false;
  /** 双设备连接 */
  dualDeviceSupported: boolean = false;
  /** 多连接管理（优先设备/自动切换） */
  multiConnectManageSupported: boolean = false;
  /** 游戏模式 */
  gameModeSupported: boolean = false;
  /** 游戏模式 feature ID（运行时决定 0x06/0x28） */
  gameModeFeatureId: number = 0;
  /** 游戏音效 */
  gameSoundSupported: boolean = false;
  /** 游戏音效类型 */
  gameSoundType: number = 0;

  // ========== 扩展功能标志 ==========
  hasHighAudio: boolean = false;
  hasCustomEq: boolean = false;
  hasWearDetection: boolean = false;
  hasFindDevice: boolean = false;
  hasKeyFunction: boolean = false;
  hasClickTakePic: boolean = false;
  hasZenMode: boolean = false;
  hasBassEngine: boolean = false;
  hasVocalEnhance: boolean = false;
  hasLongPowerMode: boolean = false;
  hasVoiceCommand: boolean = false;
  hasSpeechPerception: boolean = false;
  hasSleepDetection: boolean = false;
  hasHeadMotion: boolean = false;
  hasWhiteNoise: boolean = false;
  hasMeetingAssistant: boolean = false;
  hasSpineHealth: boolean = false;
  hasDiagnostic: boolean = false;
  hasAutoFirmwareUpdate: boolean = false;
  hasFitDetection: boolean = false;
  hasPromptVolume: boolean = false;
  promptVolumeMin: number = 0;
  promptVolumeMax: number = 10;

  // ========== ANC 配置 ==========
  /** protocolIndex → UI 模式名 */
  ancIndexToName: Map<number, string> = new Map();
  /** UI 模式名 → protocolIndex */
  ancNameToIndex: Map<string, number> = new Map();
  /** 层级化 ANC 选项（UI 动态渲染） */
  ancOptions: AncOption[] = [];

  // ========== EQ 配置 ==========
  /** EQ 预设名 → protocolIndex */
  eqPresets: Map<string, number> = new Map();
  /** protocolIndex → EQ 预设名 */
  eqNames: Map<number, string> = new Map();
  // 自定义 EQ 频率数组
  customEqFrequencies: number[] = [];
}

/**
 * 根据 0x810D 实际返回的 feature 选择游戏模式协议。
 * 移植自 C# DeviceCapabilities.ResolveGameModeProtocol()
 * @param returnedFeatures 0x810D 响应中解析出的 feature→value 映射
 * @param featureGameLL 旧版低延迟 feature ID (0x06)
 * @param featureGameMain 新版主开关 feature ID (0x28)
 */
export function resolveGameModeProtocol(
  returnedFeatures: Map<number, number>,
  caps: DeviceCapabilities,
  featureGameLL: number,
  featureGameMain: number
): void {
  const hasLegacy = returnedFeatures.has(featureGameLL);
  const hasMain = returnedFeatures.has(featureGameMain);

  if (caps.gameSoundSupported && hasMain) {
    caps.gameModeFeatureId = featureGameMain;
  } else if (hasLegacy) {
    caps.gameModeFeatureId = featureGameLL;
  } else if (hasMain) {
    caps.gameModeFeatureId = featureGameMain;
  } else if (caps.gameModeSupported) {
    // 白名单已声明但 0x810D 未返回实际 feature：使用白名单默认值
    caps.gameModeFeatureId = caps.gameSoundSupported ? featureGameMain : featureGameLL;
  }

  caps.gameModeSupported = caps.gameModeFeatureId !== 0;
}

/** 能力覆写配置 */
export class CapabilityOverrides {
  spatialAudio: number = CAP_OVERRIDE_AUTO;
  spatialSoundSwitch: number = CAP_OVERRIDE_AUTO;
  ancLegacy: number = CAP_OVERRIDE_AUTO;
  adaptiveAnc: number = CAP_OVERRIDE_AUTO;
}

/** 能力位图解析结果 */
export class CapabilityBitmapResult {
  /** 设备支持的命令字集合 */
  supportedCommands: Set<number> = new Set();
  /** 原始位图字节 */
  rawBitmap: Uint8Array = new Uint8Array(0);
}

// ============== 核心检测函数 ==============

/**
 * 按蓝牙名称检测设备能力
 */
export function detectDeviceCapabilities(
  deviceName: string,
  overrides: CapabilityOverrides | null = null
): DeviceCapabilities {
  const caps = new DeviceCapabilities();
  caps.deviceName = deviceName;

  if (!deviceName) return caps;

  // 从 DeviceModelsData 白名单匹配
  const entry = findModelByDeviceName(deviceName);
  if (entry) {
    caps.modelName = entry.name;
    caps.modelId = entry.id ?? '';
    applyDeviceEntry(caps, entry);
  }

  // 应用用户覆写
  if (overrides) {
    applyOverrides(caps, overrides);
  }

  return caps;
}

/**
 * 按 productId 精确检测设备能力
 * @param productId 6位大写十六进制
 * @param deviceName 可选蓝牙名称
 */
export function detectDeviceCapabilitiesById(
  productId: string,
  deviceName: string | null = null
): DeviceCapabilities | null {
  if (!productId) return null;
  const entry = findModelByProductId(productId);
  if (!entry) return null;

  const caps = new DeviceCapabilities();
  caps.modelName = entry.name;
  caps.modelId = entry.id ?? '';
  caps.deviceName = deviceName ?? entry.name;
  applyDeviceEntry(caps, entry);
  return caps;
}

// ============== 内部实现 ==============

function applyDeviceEntry(caps: DeviceCapabilities, entry: DeviceModelEntry): void {
  const func = entry.function;
  if (!func) return;

  // 空间音频
  if (func.spatialTypes && func.spatialTypes.length > 0) {
    caps.spatialTypes = [...func.spatialTypes];
    caps.spatialAudioSupported = func.spatialTypes.includes(1) || func.spatialTypes.includes(2);
  }
  caps.spatialSoundSwitchSupported = func.spatialSoundSwitch ?? false;

  // 多设备
  const multiDev = func.multiDevicesConnect ?? 0;
  caps.dualDeviceSupported = multiDev >= 1;
  caps.multiConnectManageSupported = multiDev >= 2;

  // 游戏模式
  buildGameMode(caps, func);

  // ANC 选项
  if (func.noiseReductionMode) {
    buildAncOptions(caps, func.noiseReductionMode);
    caps.adaptiveSupported = caps.ancNameToIndex.has('Adaptive');
    caps.legacyAnc = detectLegacyAnc(func.noiseReductionMode);
  }

  // EQ 预设
  if (func.equalizerMode) {
    buildEqPresets(caps, func.equalizerMode);
  }

  // 扩展能力
  caps.hasHighAudio = func.highAudio ?? false;
  caps.hasCustomEq = func.customEqualizer ?? false;
  caps.hasWearDetection = func.wearDetection ?? false;
  caps.hasFindDevice = func.findDevice ?? false;
  caps.hasKeyFunction = func.keyFunction ?? false;
  caps.hasClickTakePic = func.clickTakePic ?? false;
  caps.hasZenMode = func.zenMode ?? false;
  caps.hasBassEngine = func.bassEngineSupport ?? false;
  caps.hasVocalEnhance = func.vocalEnhance ?? false;
  caps.hasLongPowerMode = func.longPowerMode ?? false;
  caps.hasVoiceCommand = func.voiceCommand ?? false;
  caps.hasSpeechPerception = func.speechPerception ?? false;
  caps.hasSleepDetection = func.sleepDetection ?? false;
  caps.hasHeadMotion = func.headMotion ?? false;
  caps.hasWhiteNoise = func.whiteNoise ?? false;
  caps.hasMeetingAssistant = func.meetingAssistant ?? false;
  caps.hasSpineHealth = func.spineHealth ?? false;
  caps.hasDiagnostic = func.diagnostic ?? false;
  caps.hasAutoFirmwareUpdate = func.autoFirmwareUpdate ?? false;
  caps.hasFitDetection = func.fitDetection ?? false;
  caps.hasPromptVolume = func.promptVolume ?? false;
  if (func.promptVolumeRange && func.promptVolumeRange.length >= 2) {
    caps.promptVolumeMin = func.promptVolumeRange[0];
    caps.promptVolumeMax = func.promptVolumeRange[1];
  }

  // 自定义 EQ 频率
  if (func.customEqFrequency) {
    caps.customEqFrequencies = [...func.customEqFrequency];
  }
}

function applyOverrides(caps: DeviceCapabilities, overrides: CapabilityOverrides): void {
  if (overrides.spatialAudio === CAP_OVERRIDE_FORCE_ENABLED) caps.spatialAudioSupported = true;
  else if (overrides.spatialAudio === CAP_OVERRIDE_FORCE_DISABLED) caps.spatialAudioSupported = false;

  if (overrides.spatialSoundSwitch === CAP_OVERRIDE_FORCE_ENABLED) caps.spatialSoundSwitchSupported = true;
  else if (overrides.spatialSoundSwitch === CAP_OVERRIDE_FORCE_DISABLED) caps.spatialSoundSwitchSupported = false;

  if (overrides.ancLegacy === CAP_OVERRIDE_FORCE_ENABLED) caps.legacyAnc = true;
  else if (overrides.ancLegacy === CAP_OVERRIDE_FORCE_DISABLED) caps.legacyAnc = false;

  if (overrides.adaptiveAnc === CAP_OVERRIDE_FORCE_ENABLED) caps.adaptiveSupported = true;
  else if (overrides.adaptiveAnc === CAP_OVERRIDE_FORCE_DISABLED) caps.adaptiveSupported = false;
}

function buildGameMode(caps: DeviceCapabilities, func: DeviceFunctions): void {
  // 检查 gameSoundList
  if (func.gameSoundList) {
    for (const item of func.gameSoundList) {
      if (item.type !== 0) {
        caps.gameSoundSupported = true;
        caps.gameModeSupported = true;
        caps.gameModeFeatureId = 0x28;
        caps.gameSoundType = item.type;
        break;
      }
    }
  }
  // 检查 gameMode 标志
  if (!caps.gameModeSupported && (func.gameMode ?? 0) === 1) {
    caps.gameModeSupported = true;
    caps.gameModeFeatureId = 0x06;
  }
}

// 用于 ANC 构建的条目类型
interface AncBuildEntry {
  modeType: number;
  protocolIndex: number;
  childrenMode?: AncBuildChildEntry[];
}

interface AncBuildChildEntry {
  modeType: number;
  protocolIndex: number;
}

interface EqBuildEntry {
  protocolIndex: number;
  modeType: number;
  name?: string;
}

function buildAncOptions(caps: DeviceCapabilities, modes: AncBuildEntry[]): void {
  const idxToName = caps.ancIndexToName;
  const nameToIdx = caps.ancNameToIndex;
  const options: AncOption[] = [];

  for (const entry of modes) {
    const type = entry.modeType;
    const key = modeKey(type);
    const ownIdx = entry.protocolIndex;
    const hasChildren = entry.childrenMode && entry.childrenMode.length > 0;

    const childOpts: AncOption[] = [];
    if (hasChildren && entry.childrenMode) {
      for (const child of entry.childrenMode) {
        const ctype = child.modeType;
        const cidx = child.protocolIndex;
        const ckey = modeKey(ctype);
        registerFlat(idxToName, nameToIdx, cidx, ckey);
        childOpts.push({ key: ckey, label: ancLabel(ckey), protocolIndex: cidx, sendable: true, children: [] });
      }
    }

    if (childOpts.length === 1 && childOpts[0].key === key) {
      registerFlat(idxToName, nameToIdx, ownIdx, key);
      nameToIdx.set(key, ownIdx);
      if (childOpts[0].protocolIndex !== ownIdx) {
        idxToName.set(childOpts[0].protocolIndex, key);
      }
      options.push({ key, label: ancLabel(key), protocolIndex: ownIdx, sendable: true, children: [] });
      continue;
    }

    if (childOpts.length > 0) {
      options.push({ key, label: ancLabel(key), protocolIndex: ownIdx, sendable: false, children: childOpts });
    } else {
      registerFlat(idxToName, nameToIdx, ownIdx, key);
      options.push({ key, label: ancLabel(key), protocolIndex: ownIdx, sendable: true, children: [] });
    }
  }

  options.sort((a, b) => mainRank(a.key) - mainRank(b.key));
  for (const o of options) {
    o.children.sort((a, b) => mainRank(a.key) - mainRank(b.key));
  }
  caps.ancOptions = options;
}

function registerFlat(
  idxToName: Map<number, string>,
  nameToIdx: Map<string, number>,
  idx: number,
  name: string
): void {
  idxToName.set(idx, name);
  if (!nameToIdx.has(name)) {
    nameToIdx.set(name, idx);
  }
}

function detectLegacyAnc(modes: AncBuildEntry[]): boolean {
  // 判断是否为旧版 ANC：有modeType=5且protocolIndex=0且无子模式的条目
  for (const mode of modes) {
    if (mode.modeType === 5 && mode.protocolIndex === 0 && (!mode.childrenMode || mode.childrenMode.length === 0)) {
      return true;
    }
  }
  return false;
}

function buildEqPresets(caps: DeviceCapabilities, eqModes: EqBuildEntry[]): void {
  caps.eqPresets.clear();
  caps.eqNames.clear();

  for (const mode of eqModes) {
    // 优先使用白名单中声明的 name，其次按 modeType 从全局 EQ 名称映射表查找
    const name = mode.name ?? getEqModeName(mode.modeType);
    caps.eqPresets.set(name, mode.protocolIndex);
    caps.eqNames.set(mode.protocolIndex, name);
  }

  if (caps.eqPresets.size === 0) {
    caps.eqPresets.set('默认', 0);
    caps.eqNames.set(0, '默认');
  }
}

/**
 * 解析能力位图响应（0x8100）[status(1)][bitmap...]
 * 按 67 位能力位图提取支持的命令字集合
 */
export function parseCapabilityBitmap(payload: Uint8Array): CapabilityBitmapResult {
  const result = new CapabilityBitmapResult();
  if (payload.length <= 1 || payload[0] !== 0) {
    return result;
  }

  const bitmap = payload.slice(1);
  result.rawBitmap = bitmap;

  // 67 位能力位图 → 命令字映射（移植自 C# OppoProtocol.CapabilityCommands）
  const capCommands: number[][] = [
    [261], [262], [263], [264, 1025, 1046], [265], [1024], [1026], [1027], [268, 1028], [1029],
    [1030, 271], [1031], [], [1032], [1033], [], [], [276], [], [1038, 1037, 277, 278],
    [1039], [1040, 281], [517], [3840], [], [280, 1041], [282, 1042], [284, 1043], [],
    [274, 1035], [286, 287, 1045], [1037], [], [289, 1047], [290, 1048], [], [285, 1044],
    [291, 1050], [292, 1051], [293, 1052, 295, 1053, 1055], [1057, 35, 36, 34, 294, 297],
    [61185], [61186], [61187, 1054], [1056], [28], [], [1058, 298], [61188], [1059, 299], [],
    [1060], [61190], [], [], [1061, 302, 1062], [303], [1063, 304], [305, 1064], [1065, 306],
    [20], [1069, 307], [1070], [61191], [61192], [61193], [1073, 308],
  ];

  const bitCount = Math.min(bitmap.length * 8, capCommands.length);
  for (let bit = 0; bit < bitCount; bit++) {
    const byteIdx = Math.floor(bit / 8);
    const bitIdx = bit % 8;
    if ((bitmap[byteIdx] & (1 << bitIdx)) !== 0) {
      for (const cmd of capCommands[bit]) {
        result.supportedCommands.add(cmd);
      }
    }
  }

  return result;
}
