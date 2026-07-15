/**
 * OPPO 设备能力白名单数据库
 * 移植自 OppoPodsManager-main:
 *   - Data/DeviceModels.json
 *   - Models/DeviceProfileLoader.cs
 *
 * 每个设备条目按蓝牙名称匹配，支持精确 productId 定位。
 * 添加新型号只需在此文件中追加一行即可。
 */

// ============== 类型定义 ==============

/** ANC 模式选项（可含子模式） */
export interface AncOption {
  /** 主键（如 'NC', 'Transparency', 'Adaptive', 'Off'） */
  key: string;
  /** 显示标签（如 '降噪', '通透', '自适应'） */
  label: string;
  /** 协议索引 */
  protocolIndex: number;
  /** 是否可直接发送（false 表示主子模式，需进一步选择子项） */
  sendable: boolean;
  /** 子模式列表 */
  children?: AncOption[];
}

/** EQ 预设项 */
export interface EqModeEntry {
  protocolIndex: number;
  modeType: number;
  name?: string;
}

/** 游戏音效类型 */
export interface GameSoundEntry {
  type: number;
  name: string;
}

/** 设备功能能力 */
export interface DeviceFunctions {
  /** 空间音频三模式类型列表（0=Off, 1=Fixed, 2=Track） */
  spatialTypes?: number[];
  /** 使用空间音效开关协议（feature 0x1B） */
  spatialSoundSwitch?: boolean;
  /** 多设备连接数（0=不支持, 1=双设备, 2=多设备管理） */
  multiDevicesConnect?: number;
  /** 高清音频 */
  highAudio?: boolean;
  /** Dolby Atmos */
  dolbyAtmos?: boolean;
  /** 自定义 EQ */
  customEqualizer?: boolean;
  /** 自定义 EQ 频率数组 */
  customEqFrequency?: number[];
  /** 自定义 EQ 最大预设数 */
  customEqMax?: number;
  /** 自定义 EQ UI 版本 */
  customEqUiVersion?: number;
  /** 听力增强 */
  hearingEnhancement?: boolean;
  /** 个性化降噪 */
  personalNoise?: boolean;
  /** 佩戴检测 */
  wearDetection?: boolean;
  /** 双设备自动切换 */
  autoSwitchLink?: boolean;
  /** 查找设备 */
  findDevice?: boolean;
  /** 按键功能 */
  keyFunction?: boolean;
  /** 敲击拍照 */
  clickTakePic?: boolean;
  /** 禅模式 */
  zenMode?: boolean;
  /** 低音引擎 */
  bassEngineSupport?: boolean;
  /** 人声增强 */
  vocalEnhance?: boolean;
  /** 长续航模式 */
  longPowerMode?: boolean;
  /** 语音命令 */
  voiceCommand?: boolean;
  /** 语音感知 */
  speechPerception?: boolean;
  /** 睡眠检测 */
  sleepDetection?: boolean;
  /** 头部动作 */
  headMotion?: boolean;
  /** AI 翻译 */
  aiTranslate?: boolean;
  /** AI 摘要 */
  aiSummary?: boolean;
  /** 耳道扫描 */
  earScan?: boolean;
  /** 游戏模式（0=不支持, 1=支持） */
  gameMode?: number;
  /** 游戏音效列表 */
  gameSoundList?: GameSoundEntry[];
  /** 游戏音效互斥（1=与EQ互斥, 2=与空间音频互斥, 3=两者都互斥） */
  gameSoundMutexes?: number[];
  /** 降噪模式配置 */
  noiseReductionMode?: NoiseReductionModeEntry[];
  /** EQ 模式列表 */
  equalizerMode?: EqModeEntry[];
  /** 兼容 EQ 模式列表 */
  equalizerModeCompat?: EqModeEntry[];
}

/** 降噪模式条目 */
export interface NoiseReductionModeEntry {
  modeType: number;
  protocolIndex: number;
  childrenMode?: NoiseReductionModeEntry[];
}

/** 设备白名单条目 */
export interface DeviceModelEntry {
  /** 蓝牙名称（用于匹配） */
  name: string;
  /** 品牌 */
  brands?: string[];
  /** ProductId（6位十六进制，匹配 productId 查询响应） */
  id?: string;
  /** 协议类型 */
  protocolType?: number;
  /** 是否支持 SPP */
  supportSpp?: boolean;
  /** 功能配置 */
  function?: DeviceFunctions;
}

// ============== 设备白名单数据库 ==============

export const DEVICE_MODELS: DeviceModelEntry[] = [
  // ---- OPPO Enco Air5 Pro (ETB22) ----
  {
    name: 'OPPO Enco Air5 Pro',
    id: '0C2102',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      spatialSoundSwitch: true,
      multiDevicesConnect: 2,
      gameMode: 1,
      gameSoundList: [
        { type: 0, name: '关闭' },
        { type: 1, name: '游戏音效1' },
      ],
      gameSoundMutexes: [1],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0, childrenMode: [
          { modeType: 7, protocolIndex: 5 },  // 智能
          { modeType: 3, protocolIndex: 6 },  // 轻度
          { modeType: 8, protocolIndex: 7 },  // 中度
          { modeType: 4, protocolIndex: 8 },  // 深度
        ]},
        { modeType: 2, protocolIndex: 1 },
        { modeType: 1, protocolIndex: 2 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '至臻原音' },
        { protocolIndex: 1, modeType: 1, name: '澎湃低音' },
        { protocolIndex: 2, modeType: 2, name: '纯享人声' },
      ],
      customEqualizer: true,
      vocalEnhance: false,
      wearDetection: true,
      findDevice: true,
      autoSwitchLink: true,
    },
  },

  // ---- OPPO Enco Free4 ----
  {
    name: 'OPPO Enco Free4',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      spatialSoundSwitch: true,
      multiDevicesConnect: 1,
      gameMode: 1,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0, childrenMode: [
          { modeType: 7, protocolIndex: 5 },  // 智能
          { modeType: 3, protocolIndex: 6 },  // 轻度
          { modeType: 8, protocolIndex: 7 },  // 中度
          { modeType: 4, protocolIndex: 8 },  // 深度
        ]},
        { modeType: 6, protocolIndex: 4 }, // 自适应
        { modeType: 1, protocolIndex: 2 },
        { modeType: 2, protocolIndex: 1 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '至臻原音' },
        { protocolIndex: 1, modeType: 1, name: '澎湃低音' },
        { protocolIndex: 2, modeType: 2, name: '纯享人声' },
      ],
      customEqualizer: true,
      wearDetection: true,
    },
  },

  // ---- OPPO Enco X3 ----
  {
    name: 'OPPO Enco X3',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      spatialTypes: [0, 1, 2],
      multiDevicesConnect: 2,
      gameMode: 1,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0, childrenMode: [
          { modeType: 7, protocolIndex: 5 },  // 智能
          { modeType: 3, protocolIndex: 6 },  // 轻度
          { modeType: 8, protocolIndex: 7 },  // 中度
          { modeType: 4, protocolIndex: 8 },  // 深度
        ]},
        { modeType: 1, protocolIndex: 2 },
        { modeType: 2, protocolIndex: 1 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '至臻原音' },
        { protocolIndex: 1, modeType: 1, name: '澎湃低音' },
        { protocolIndex: 2, modeType: 2, name: '纯享人声' },
        { protocolIndex: 3, modeType: 3, name: '悠扬人声' },
      ],
      customEqualizer: true,
      wearDetection: true,
      autoSwitchLink: true,
    },
  },

  // ---- OPPO Enco Air2 Pro（旧版 ANC 反转）----
  {
    name: 'OPPO Enco Air2 Pro',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      spatialSoundSwitch: false,
      multiDevicesConnect: 1,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0 },
        { modeType: 2, protocolIndex: 1 },
        { modeType: 1, protocolIndex: 2 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '默认' },
      ],
    },
  },

  // ---- OPPO Enco Air4s (06F010) 空间音频+双设备+耳道扫描 ----
  {
    name: 'OPPO Enco Air4s',
    id: '06F010',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      spatialTypes: [0, 1],
      multiDevicesConnect: 1,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0 },
        { modeType: 1, protocolIndex: 1 },
        { modeType: 2, protocolIndex: 2 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '均衡' },
        { protocolIndex: 1, modeType: 0, name: '澎湃低音' },
        { protocolIndex: 2, modeType: 0, name: '明快清亮' },
      ],
      findDevice: true,
      wearDetection: true,
      autoSwitchLink: true,
      earScan: true,
      clickTakePic: true,
    },
  },

  // ---- OPPO Enco R5 (06B450) 空间音频+AI翻译 ----
  {
    name: 'OPPO Enco R5',
    id: '06B450',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      spatialTypes: [0, 1],
      multiDevicesConnect: 1,
      noiseReductionMode: [
        { modeType: 1, protocolIndex: 0 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 22, name: '纯粹原音' },
        { protocolIndex: 1, modeType: 32, name: '悠扬人声' },
        { protocolIndex: 2, modeType: 31, name: '脉冲低音' },
      ],
      findDevice: true,
      wearDetection: true,
      aiTranslate: true,
    },
  },

  // ---- OnePlus Flow Buds (067414) 完整功能（自定义EQ/游戏音效/多设备管理）----
  {
    name: 'OnePlus Flow Buds',
    id: '067414',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      spatialTypes: [0, 1],
      multiDevicesConnect: 2,
      gameMode: 1,
      gameSoundList: [
        { type: 0, name: '关闭' },
        { type: 3, name: '游戏音效' },
      ],
      gameSoundMutexes: [1, 2],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 1, childrenMode: [
          { modeType: 7, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 4 },
          { modeType: 3, protocolIndex: 6 },
        ]},
        { modeType: 1, protocolIndex: 0, childrenMode: [
          { modeType: 1, protocolIndex: 3 },
        ]},
        { modeType: 2, protocolIndex: 2, childrenMode: [
          { modeType: 2, protocolIndex: 8 },
        ]},
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11, name: '均衡' },
        { protocolIndex: 1, modeType: 12, name: '深海低音' },
        { protocolIndex: 2, modeType: 14, name: '纯净人声' },
      ],
      customEqualizer: true,
      customEqFrequency: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000],
      customEqUiVersion: 2,
      wearDetection: true,
      findDevice: true,
      autoSwitchLink: true,
      bassEngineSupport: true,
      clickTakePic: true,
      earScan: true,
    },
  },

  // ---- OPPO Enco X2 (063C10) 旗舰级空间音频 ----
  {
    name: 'OPPO Enco X2',
    id: '063C10',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      spatialTypes: [0, 1, 2],
      multiDevicesConnect: 2,
      gameMode: 1,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0, childrenMode: [
          { modeType: 7, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
          { modeType: 8, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 8 },
        ]},
        { modeType: 1, protocolIndex: 2 },
        { modeType: 2, protocolIndex: 1 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '均衡' },
        { protocolIndex: 1, modeType: 0, name: 'Dynaudio 淳朴悠然' },
        { protocolIndex: 2, modeType: 0, name: 'Dynaudio 温暖轻柔' },
        { protocolIndex: 3, modeType: 0, name: 'Dynaudio 澎湃爽朗' },
        { protocolIndex: 4, modeType: 0, name: 'Dynaudio 纯粹原音' },
      ],
      wearDetection: true,
      findDevice: true,
      autoSwitchLink: true,
    },
  },

  // ---- OPPO Enco Air3 Pro ----
  {
    name: 'OPPO Enco Air3 Pro',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      spatialSoundSwitch: true,
      multiDevicesConnect: 1,
      gameMode: 1,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0, childrenMode: [
          { modeType: 7, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
          { modeType: 8, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 8 },
        ]},
        { modeType: 2, protocolIndex: 1 },
        { modeType: 1, protocolIndex: 2 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '至臻原音' },
        { protocolIndex: 1, modeType: 0, name: '澎湃低音' },
        { protocolIndex: 2, modeType: 0, name: '纯享人声' },
      ],
      wearDetection: true,
      findDevice: true,
    },
  },

  // ---- OPPO Enco Free3 ----
  {
    name: 'OPPO Enco Free3',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      spatialSoundSwitch: true,
      multiDevicesConnect: 1,
      gameMode: 1,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0, childrenMode: [
          { modeType: 7, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
          { modeType: 8, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 8 },
        ]},
        { modeType: 1, protocolIndex: 2 },
        { modeType: 2, protocolIndex: 1 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '至臻原音' },
        { protocolIndex: 1, modeType: 0, name: '澎湃低音' },
        { protocolIndex: 2, modeType: 0, name: '纯享人声' },
      ],
      wearDetection: true,
    },
  },

  // ---- realme Buds Air 5 Pro (061C12) ----
  {
    name: 'realme Buds Air 5 Pro',
    id: '061C12',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      spatialSoundSwitch: true,
      multiDevicesConnect: 1,
      gameMode: 1,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0 },
        { modeType: 1, protocolIndex: 1 },
        { modeType: 2, protocolIndex: 2 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '至臻原音' },
        { protocolIndex: 1, modeType: 0, name: '澎湃低音' },
        { protocolIndex: 2, modeType: 0, name: '纯享人声' },
      ],
      wearDetection: true,
      autoSwitchLink: true,
    },
  },

  // ---- realme Buds Air 5 (062012) ----
  {
    name: 'realme Buds Air 5',
    id: '062012',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      gameMode: 1,
      noiseReductionMode: [
        { modeType: 1, protocolIndex: 0 },
        { modeType: 2, protocolIndex: 1 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '默认' },
      ],
      wearDetection: true,
    },
  },

  // ---- OPPO Enco Air5 (06D810) 基础款 ----
  {
    name: 'OPPO Enco Air5',
    id: '06D810',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      gameMode: 1,
      noiseReductionMode: [
        { modeType: 1, protocolIndex: 0 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '默认' },
      ],
      wearDetection: true,
    },
  },

  // ---- OPPO Enco Air5s (06C810) 星光版 ----
  {
    name: 'OPPO Enco Air5s',
    id: '06C810',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      gameMode: 1,
      noiseReductionMode: [
        { modeType: 1, protocolIndex: 0 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '默认' },
      ],
      wearDetection: true,
    },
  },

  // ---- OPPO Enco Air5s（星光版）(06E810) ----
  {
    name: 'OPPO Enco Air5s（星光版）',
    id: '06E810',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      gameMode: 1,
      noiseReductionMode: [
        { modeType: 1, protocolIndex: 0 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '默认' },
      ],
      wearDetection: true,
    },
  },

  // ---- OnePlus Buds Pro 3 ----
  {
    name: 'OnePlus Buds Pro 3',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      spatialTypes: [0, 1, 2],
      multiDevicesConnect: 2,
      gameMode: 1,
      gameSoundList: [
        { type: 0, name: '关闭' },
        { type: 1, name: '游戏音效' },
      ],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0, childrenMode: [
          { modeType: 7, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
          { modeType: 8, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 8 },
        ]},
        { modeType: 2, protocolIndex: 1 },
        { modeType: 1, protocolIndex: 2 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '均衡' },
        { protocolIndex: 1, modeType: 0, name: '澎湃低音' },
        { protocolIndex: 2, modeType: 0, name: '纯享人声' },
      ],
      customEqualizer: true,
      wearDetection: true,
      findDevice: true,
      autoSwitchLink: true,
    },
  },

  // ---- OnePlus Nord Buds 4 (067014) ----
  {
    name: 'OnePlus Nord Buds 4',
    id: '067014',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      gameMode: 1,
      noiseReductionMode: [
        { modeType: 1, protocolIndex: 0 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 0, name: '默认' },
      ],
      wearDetection: true,
    },
  },
];

// ============== 预设模式名称映射 ==============

/** modeType → 模式名 */
export function modeKey(type: number): string {
  switch (type) {
    case 1: return 'Off';
    case 2: return 'Transparency';
    case 3: return 'Light';
    case 4: return 'Deep';
    case 5: return 'NC';
    case 6: return 'Adaptive';
    case 7: return 'Smart';
    case 8: return 'Medium';
    case 10: return 'Adaptive';
    default: return `Mode${type}`;
  }
}

/** key → 中文标签 */
export function ancLabel(key: string): string {
  switch (key) {
    case 'Off': return '关闭';
    case 'Transparency': return '通透';
    case 'Adaptive': return '自适应';
    case 'NC': return '降噪';
    case 'Smart': return '智能';
    case 'Light': return '轻度';
    case 'Medium': return '中度';
    case 'Deep': return '深度';
    default: return key;
  }
}

/** ANC 主模式排序权重 */
export function mainRank(key: string): number {
  switch (key) {
    case 'NC': case 'Smart': return 0;
    case 'Transparency': return 1;
    case 'Adaptive': return 2;
    case 'Off': return 99;
    default: return 50;
  }
}

// ============== EQ ModeType → 显示名称映射 ==============

/**
 * EQ 模式类型映射表，从 OPPO 欢律 App v16.8.1 反编译提取
 * 来源: OppoPods EqModeNames.json
 */
export const EQ_MODE_NAMES: Record<number, string> = {
  0: '默认',
  1: '均衡（默认）',
  2: '深海低音',
  3: '明快清亮',
  4: '明亮通透',
  5: '默认',
  6: 'Dynaudio 淳朴悠然',
  7: 'Dynaudio 温暖轻柔',
  8: 'Dynaudio 澎湃爽朗',
  9: 'Dynaudio 纯粹原音',
  10: '久石让大师调音',
  11: '均衡（默认）',
  12: '深海低音',
  13: '明快清亮',
  14: '纯净人声',
  15: '微醺柔音',
  16: 'Enco X 怀旧经典',
  17: '均衡',
  18: '醇美音质',
  19: '澄澈人声',
  20: '通话音质',
  21: '醇厚人声',
  22: '纯粹原音',
  23: '澎湃爽朗',
  24: '纯享人声',
  25: 'Reno特调（幻紫星河）',
  26: '至臻原音',
  27: '高清解析',
  28: '纯享人声',
  29: '澎湃低音',
  30: '丹拿特调',
  31: '脉冲低音',
  32: '悠扬人声',
  33: '星河独白',
  34: '活力动感',
  35: '默认',
  36: 'Dynaudio 淳朴悠然',
  37: 'Dynaudio 温暖轻柔',
  38: 'Dynaudio 澎湃爽朗',
  39: 'Dynaudio 纯粹原音',
  40: '丹拿人声',
};

/** 根据 modeType 获取 EQ 预设显示名称 */
export function getEqModeName(modeType: number): string {
  return EQ_MODE_NAMES[modeType] ?? `模式${modeType}`;
}

// ============== 查询函数 ==============

/**
 * 按蓝牙名称匹配设备条目（模糊匹配）
 * 匹配策略：精确匹配 → 名称包含 → 被包含
 */
export function findModelByDeviceName(deviceName: string): DeviceModelEntry | null {
  if (!deviceName) return null;
  const norm = normalize(deviceName);

  // 精确匹配
  for (const entry of DEVICE_MODELS) {
    if (normalize(entry.name) === norm) return entry;
  }

  // 名称包含
  for (const entry of DEVICE_MODELS) {
    const entryNorm = normalize(entry.name);
    if (entryNorm.length >= 5 && norm.includes(entryNorm)) return entry;
  }

  // 被包含
  for (const entry of DEVICE_MODELS) {
    const entryNorm = normalize(entry.name);
    if (norm.length >= 5 && entryNorm.includes(norm)) return entry;
  }

  return null;
}

/**
 * 按 productId 精确匹配设备条目
 * @param productId 6位大写十六进制
 */
export function findModelByProductId(productId: string): DeviceModelEntry | null {
  if (!productId) return null;
  for (const entry of DEVICE_MODELS) {
    if (entry.id && entry.id.toUpperCase() === productId.toUpperCase()) return entry;
  }
  return null;
}

/** 获取所有已知设备型号名 */
export function getModelNames(): string[] {
  const names: string[] = [];
  for (const entry of DEVICE_MODELS) {
    if (entry.name && !names.includes(entry.name)) {
      names.push(entry.name);
    }
  }
  return names;
}

function normalize(name: string): string {
  return name.toLowerCase().replace(/\s/g, '');
}
