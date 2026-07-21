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
  /** 版本化 EQ 模式列表 */
  equalizerModeByVersion?: EqModeEntry[];
  /** 白噪音 */
  whiteNoise?: boolean;
  /** 会议助手 */
  meetingAssistant?: boolean;
  /** 脊椎健康 */
  spineHealth?: boolean;
  /** 设备诊断 */
  diagnostic?: boolean;
  /** 自动固件更新 */
  autoFirmwareUpdate?: boolean;
  /** 贴合检测 */
  fitDetection?: boolean;
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
  // ============== 以下条目从 OPPO 欢律 App DeviceModels.json 同步 ==============


  // ---- OPPO Enco Clip2 (06E010) ----
  {
    name: 'OPPO Enco Clip2',
    id: '06E010',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 2,
      highAudio: true,
      wearDetection: true,
      autoSwitchLink: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      voiceCommand: true,
      aiTranslate: true,
      aiSummary: true,
      whiteNoise: true,
      meetingAssistant: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 26 },
        { protocolIndex: 3, modeType: 34 },
        { protocolIndex: 2, modeType: 28 },
        { protocolIndex: 4, modeType: 30 },
      ],
    },
  },

  // ---- OPPO Enco Clip (06B810) ----
  {
    name: 'OPPO Enco Clip',
    id: '06B810',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      wearDetection: true,
      autoSwitchLink: true,
      keyFunction: true,
      clickTakePic: true,
      aiTranslate: true,
      aiSummary: true,
      meetingAssistant: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 35 },
        { protocolIndex: 1, modeType: 34 },
        { protocolIndex: 2, modeType: 28 },
      ],
      equalizerModeByVersion: [
        { protocolIndex: 3, modeType: 12 },
      ],
    },
  },

  // ---- OPPO Enco X (061410) ----
  {
    name: 'OPPO Enco X',
    id: '061410',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      highAudio: true,
      dolbyAtmos: true,
      wearDetection: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      noiseReductionMode: [
        { modeType: 4, protocolIndex: 3 },
        { modeType: 3, protocolIndex: 2 },
        { modeType: 1, protocolIndex: 0 },
        { modeType: 2, protocolIndex: 1 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 5 },
        { protocolIndex: 1, modeType: 6 },
        { protocolIndex: 2, modeType: 7 },
      ],
    },
  },

  // ---- OPPO Enco Free (060410) ----
  {
    name: 'OPPO Enco Free',
    id: '060410',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      findDevice: true,
      keyFunction: true,
      autoFirmwareUpdate: true,
    },
  },

  // ---- OPPO Enco Free2 (062010) ----
  {
    name: 'OPPO Enco Free2',
    id: '062010',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      dolbyAtmos: true,
      hearingEnhancement: true,
      personalNoise: true,
      wearDetection: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0 },
        { modeType: 1, protocolIndex: 1 },
        { modeType: 2, protocolIndex: 2 },
        { modeType: 6, protocolIndex: 3 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
        { protocolIndex: 3, modeType: 4 },
      ],
    },
  },

  // ---- OPPO Enco Play (061C10) ----
  {
    name: 'OPPO Enco Play',
    id: '061C10',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      vocalEnhance: true,
      autoFirmwareUpdate: true,
    },
  },

  // ---- OPPO Enco Air (061810) ----
  {
    name: 'OPPO Enco Air',
    id: '061810',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      autoFirmwareUpdate: true,
    },
  },

  // ---- OPPO Enco Buds (062410) ----
  {
    name: 'OPPO Enco Buds',
    id: '062410',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      keyFunction: true,
      autoFirmwareUpdate: true,
    },
  },

  // ---- OPPO Enco Air Lite (062810) ----
  {
    name: 'OPPO Enco Air Lite',
    id: '062810',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      keyFunction: true,
      autoFirmwareUpdate: true,
    },
  },

  // ---- OPPO Enco W51 (060C10) ----
  {
    name: 'OPPO Enco W51',
    id: '060C10',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      wearDetection: true,
      findDevice: true,
      keyFunction: true,
      autoFirmwareUpdate: true,
    },
  },

  // ---- OPPO Enco W31 (060810) ----
  {
    name: 'OPPO Enco W31',
    id: '060810',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      autoFirmwareUpdate: true,
    },
  },

  // ---- OPPO Enco W11 (061010) ----
  {
    name: 'OPPO Enco W11',
    id: '061010',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: false,
    function: {
      dolbyAtmos: true,
    },
  },

  // ---- OPPO O-Free (060412) ----
  {
    name: 'OPPO O-Free',
    id: '060412',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: false,
  },

  // ---- OPPO Enco W31 Lite (062C10) ----
  {
    name: 'OPPO Enco W31 Lite',
    id: '062C10',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: false,
    function: {
      dolbyAtmos: true,
    },
  },

  // ---- OPPO Enco M31 (050410) ----
  {
    name: 'OPPO Enco M31',
    id: '050410',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      autoFirmwareUpdate: true,
    },
  },

  // ---- OPPO Enco Quiet (050010) ----
  {
    name: 'OPPO Enco Quiet',
    id: '050010',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: false,
    function: {
      dolbyAtmos: true,
    },
  },

  // ---- OPPO Enco Air3 (064C10) ----
  {
    name: 'OPPO Enco Air3',
    id: '064C10',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      dolbyAtmos: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco R2 (065810) ----
  {
    name: 'OPPO Enco R2',
    id: '065810',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      dolbyAtmos: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 21 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco M32 (050810) ----
  {
    name: 'OPPO Enco M32',
    id: '050810',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: false,
    function: {
      dolbyAtmos: true,
    },
  },

  // ---- OPPO Enco R (063010) ----
  {
    name: 'OPPO Enco R',
    id: '063010',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
        { protocolIndex: 3, modeType: 4 },
      ],
    },
  },

  // ---- OPPO Enco Air2 (063410) ----
  {
    name: 'OPPO Enco Air2',
    id: '063410',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco Free2i (064010) ----
  {
    name: 'OPPO Enco Free2i',
    id: '064010',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      dolbyAtmos: true,
      personalNoise: true,
      wearDetection: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0 },
        { modeType: 1, protocolIndex: 1 },
        { modeType: 2, protocolIndex: 2 },
        { modeType: 6, protocolIndex: 3 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
        { protocolIndex: 3, modeType: 4 },
      ],
    },
  },

  // ---- OPPO Enco Air2i (064410) ----
  {
    name: 'OPPO Enco Air2i',
    id: '064410',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      keyFunction: true,
      clickTakePic: true,
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco Buds2 (064810) ----
  {
    name: 'OPPO Enco Buds2',
    id: '064810',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      keyFunction: true,
      clickTakePic: true,
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco R Pro (065010) ----
  {
    name: 'OPPO Enco R Pro',
    id: '065010',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      wearDetection: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0 },
        { modeType: 1, protocolIndex: 1 },
        { modeType: 2, protocolIndex: 2 },
        { modeType: 6, protocolIndex: 3 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 18 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco Air2（新声版） (066C10) ----
  {
    name: 'OPPO Enco Air2（新声版）',
    id: '066C10',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      spatialTypes: [0, 1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco Air3i (067010) ----
  {
    name: 'OPPO Enco Air3i',
    id: '067010',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      spatialTypes: [0, 1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco M33 (050C10) ----
  {
    name: 'OPPO Enco M33',
    id: '050C10',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      findDevice: true,
      keyFunction: true,
      bassEngineSupport: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0 },
        { modeType: 1, protocolIndex: 1 },
        { modeType: 2, protocolIndex: 2 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 2, modeType: 13 },
        { protocolIndex: 3, modeType: 3 },
        { protocolIndex: 1, modeType: 2 },
      ],
    },
  },

  // ---- OPPO Enco X3i (066810) ----
  {
    name: 'OPPO Enco X3i',
    id: '066810',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      highAudio: true,
      dolbyAtmos: true,
      hearingEnhancement: true,
      wearDetection: true,
      autoSwitchLink: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      bassEngineSupport: true,
      earScan: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      spatialTypes: [0, 1],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 1, childrenMode: [
          { modeType: 7, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 4 },
          { modeType: 8, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
        ] },
        { modeType: 1, protocolIndex: 0, childrenMode: [
          { modeType: 1, protocolIndex: 3 },
        ] },
        { modeType: 2, protocolIndex: 2, childrenMode: [
          { modeType: 2, protocolIndex: 8 },
        ] },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
      equalizerModeCompat: [
        { protocolIndex: 3, modeType: 13 },
      ],
    },
  },

  // ---- OPPO Enco Air3s (067810) ----
  {
    name: 'OPPO Enco Air3s',
    id: '067810',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      dolbyAtmos: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco Buds2 Pro (068010) ----
  {
    name: 'OPPO Enco Buds2 Pro',
    id: '068010',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 2, modeType: 12 },
        { protocolIndex: 1, modeType: 13 },
      ],
    },
  },

  // ---- OPPO Enco Air 3i (068810) ----
  {
    name: 'OPPO Enco Air 3i',
    id: '068810',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      keyFunction: true,
      clickTakePic: true,
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco R3 (068410) ----
  {
    name: 'OPPO Enco R3',
    id: '068410',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      spatialTypes: [0, 1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 25 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco Air4 Pro (067C10) ----
  {
    name: 'OPPO Enco Air4 Pro',
    id: '067C10',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      highAudio: true,
      dolbyAtmos: true,
      hearingEnhancement: true,
      personalNoise: true,
      wearDetection: true,
      autoSwitchLink: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      earScan: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      spatialTypes: [0, 1],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 1, childrenMode: [
          { modeType: 7, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 4 },
          { modeType: 8, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
        ] },
        { modeType: 1, protocolIndex: 0, childrenMode: [
          { modeType: 1, protocolIndex: 3 },
        ] },
        { modeType: 2, protocolIndex: 2, childrenMode: [
          { modeType: 2, protocolIndex: 8 },
        ] },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco Air4 (069010) ----
  {
    name: 'OPPO Enco Air4',
    id: '069010',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      dolbyAtmos: true,
      hearingEnhancement: true,
      autoSwitchLink: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      earScan: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0 },
        { modeType: 1, protocolIndex: 1 },
        { modeType: 2, protocolIndex: 2 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco R3 Pro (069C10) ----
  {
    name: 'OPPO Enco R3 Pro',
    id: '069C10',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      highAudio: true,
      dolbyAtmos: true,
      hearingEnhancement: true,
      personalNoise: true,
      wearDetection: true,
      autoSwitchLink: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      earScan: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      spatialTypes: [0, 1],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 1, childrenMode: [
          { modeType: 7, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 4 },
          { modeType: 8, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
        ] },
        { modeType: 1, protocolIndex: 0, childrenMode: [
          { modeType: 1, protocolIndex: 3 },
        ] },
        { modeType: 2, protocolIndex: 2, childrenMode: [
          { modeType: 2, protocolIndex: 8 },
        ] },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 33 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco Buds3 Pro+ (06A010) ----
  {
    name: 'OPPO Enco Buds3 Pro+',
    id: '06A010',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      dolbyAtmos: true,
      hearingEnhancement: true,
      autoSwitchLink: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      earScan: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0 },
        { modeType: 1, protocolIndex: 1 },
        { modeType: 2, protocolIndex: 2 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 1 },
        { protocolIndex: 1, modeType: 2 },
        { protocolIndex: 2, modeType: 3 },
      ],
    },
  },

  // ---- OPPO Enco Free4（丹拿版） (06C010) ----
  {
    name: 'OPPO Enco Free4（丹拿版）',
    id: '06C010',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      highAudio: true,
      dolbyAtmos: true,
      customEqualizer: true,
      hearingEnhancement: true,
      wearDetection: true,
      autoSwitchLink: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      aiTranslate: true,
      aiSummary: true,
      earScan: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      spatialTypes: [0, 1],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 1, childrenMode: [
          { modeType: 4, protocolIndex: 4 },
          { modeType: 8, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
          { modeType: 7, protocolIndex: 7 },
        ] },
        { modeType: 10, protocolIndex: 11 },
        { modeType: 2, protocolIndex: 2, childrenMode: [
          { modeType: 2, protocolIndex: 8 },
        ] },
        { modeType: 1, protocolIndex: 0, childrenMode: [
          { modeType: 1, protocolIndex: 3 },
        ] },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 26 },
        { protocolIndex: 1, modeType: 28 },
        { protocolIndex: 2, modeType: 29 },
        { protocolIndex: 3, modeType: 30 },
      ],
      equalizerModeCompat: [
        { protocolIndex: 7, modeType: 34 },
      ],
      equalizerModeByVersion: [
        { protocolIndex: 8, modeType: 40 },
      ],
    },
  },

  // ---- OPPO Enco X3s (06BC10) ----
  {
    name: 'OPPO Enco X3s',
    id: '06BC10',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      highAudio: true,
      dolbyAtmos: true,
      customEqualizer: true,
      hearingEnhancement: true,
      wearDetection: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      aiTranslate: true,
      aiSummary: true,
      earScan: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      spatialTypes: [0, 1],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 1, childrenMode: [
          { modeType: 4, protocolIndex: 4 },
          { modeType: 8, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
          { modeType: 7, protocolIndex: 7 },
        ] },
        { modeType: 10, protocolIndex: 11 },
        { modeType: 2, protocolIndex: 2, childrenMode: [
          { modeType: 2, protocolIndex: 8 },
        ] },
        { modeType: 1, protocolIndex: 0, childrenMode: [
          { modeType: 1, protocolIndex: 3 },
        ] },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 26 },
        { protocolIndex: 1, modeType: 28 },
        { protocolIndex: 2, modeType: 29 },
        { protocolIndex: 3, modeType: 30 },
      ],
      equalizerModeByVersion: [
        { protocolIndex: 8, modeType: 40 },
      ],
    },
  },

  // ---- OPPO Enco Buds3 Pro (06A850) ----
  {
    name: 'OPPO Enco Buds3 Pro',
    id: '06A850',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      gameMode: 1,
      dolbyAtmos: true,
      customEqualizer: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      gameSoundMutexes: [1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 22 },
        { protocolIndex: 2, modeType: 31 },
        { protocolIndex: 1, modeType: 32 },
      ],
      gameSoundList: [
        { type: 3, name: '游戏音效3' },
        { type: 0, name: '关闭' },
      ],
    },
  },

  // ---- OPPO Enco Air4i (069850) ----
  {
    name: 'OPPO Enco Air4i',
    id: '069850',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      gameMode: 1,
      dolbyAtmos: true,
      customEqualizer: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      gameSoundMutexes: [1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 22 },
        { protocolIndex: 2, modeType: 31 },
        { protocolIndex: 1, modeType: 32 },
      ],
      gameSoundList: [
        { type: 3, name: '游戏音效3' },
        { type: 0, name: '关闭' },
      ],
    },
  },

  // ---- OPPO Enco R4 (06AC50) ----
  {
    name: 'OPPO Enco R4',
    id: '06AC50',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      gameMode: 1,
      dolbyAtmos: true,
      customEqualizer: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      gameSoundMutexes: [1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 22 },
        { protocolIndex: 2, modeType: 31 },
        { protocolIndex: 1, modeType: 32 },
      ],
      gameSoundList: [
        { type: 3, name: '游戏音效3' },
        { type: 0, name: '关闭' },
      ],
    },
  },

  // ---- OPPO Enco Buds3 (06A450) ----
  {
    name: 'OPPO Enco Buds3',
    id: '06A450',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      dolbyAtmos: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      aiTranslate: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 22 },
        { protocolIndex: 2, modeType: 31 },
        { protocolIndex: 1, modeType: 32 },
      ],
    },
  },

  // ---- OPPO Enco Air4（新声版） (06B050) ----
  {
    name: 'OPPO Enco Air4（新声版）',
    id: '06B050',
    brands: ['OPPO'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      dolbyAtmos: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      aiTranslate: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 22 },
        { protocolIndex: 2, modeType: 31 },
        { protocolIndex: 1, modeType: 32 },
      ],
    },
  },

  // ---- OnePlus Buds Ace 3 (066414) ----
  {
    name: 'OnePlus Buds Ace 3',
    id: '066414',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 2,
      gameMode: 1,
      highAudio: true,
      dolbyAtmos: true,
      customEqualizer: true,
      hearingEnhancement: true,
      wearDetection: true,
      autoSwitchLink: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      bassEngineSupport: true,
      aiTranslate: true,
      earScan: true,
      whiteNoise: true,
      meetingAssistant: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      customEqFrequency: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000],
      spatialTypes: [0, 1],
      gameSoundMutexes: [1, 2, 3],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 1, childrenMode: [
          { modeType: 7, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 4 },
          { modeType: 8, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
        ] },
        { modeType: 1, protocolIndex: 0, childrenMode: [
          { modeType: 1, protocolIndex: 3 },
        ] },
        { modeType: 2, protocolIndex: 2, childrenMode: [
          { modeType: 2, protocolIndex: 8 },
        ] },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 2, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
      ],
      gameSoundList: [
        { type: 3, name: '游戏音效3' },
        { type: 0, name: '关闭' },
      ],
    },
  },

  // ---- OnePlus Nord Buds 4 Pro (066814) ----
  {
    name: 'OnePlus Nord Buds 4 Pro',
    id: '066814',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 2,
      gameMode: 1,
      highAudio: true,
      dolbyAtmos: true,
      customEqualizer: true,
      hearingEnhancement: true,
      wearDetection: true,
      autoSwitchLink: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      bassEngineSupport: true,
      aiTranslate: true,
      earScan: true,
      whiteNoise: true,
      meetingAssistant: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      customEqFrequency: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000],
      spatialTypes: [0, 1],
      gameSoundMutexes: [1, 2, 3],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 1, childrenMode: [
          { modeType: 7, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 4 },
          { modeType: 8, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
        ] },
        { modeType: 1, protocolIndex: 0, childrenMode: [
          { modeType: 1, protocolIndex: 3 },
        ] },
        { modeType: 2, protocolIndex: 2, childrenMode: [
          { modeType: 2, protocolIndex: 8 },
        ] },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 2, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
      ],
      gameSoundList: [
        { type: 3, name: '游戏音效3' },
        { type: 0, name: '关闭' },
      ],
    },
  },

  // ---- OnePlus Buds 3V (066054) ----
  {
    name: 'OnePlus Buds 3V',
    id: '066054',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      gameMode: 1,
      dolbyAtmos: true,
      customEqualizer: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      aiTranslate: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      gameSoundMutexes: [1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 2, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
      ],
      gameSoundList: [
        { type: 3, name: '游戏音效3' },
        { type: 0, name: '关闭' },
      ],
    },
  },

  // ---- OnePlus Nord Buds 3r (065854) ----
  {
    name: 'OnePlus Nord Buds 3r',
    id: '065854',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      dolbyAtmos: true,
      customEqualizer: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      aiTranslate: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      gameSoundMutexes: [1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 2, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
      ],
    },
  },

  // ---- OnePlus Open Buds (065C14) ----
  {
    name: 'OnePlus Open Buds',
    id: '065C14',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      wearDetection: true,
      autoSwitchLink: true,
      keyFunction: true,
      clickTakePic: true,
      aiTranslate: true,
      aiSummary: true,
      meetingAssistant: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 35 },
        { protocolIndex: 1, modeType: 34 },
        { protocolIndex: 2, modeType: 28 },
      ],
      equalizerModeByVersion: [
        { protocolIndex: 3, modeType: 12 },
      ],
    },
  },

  // ---- OnePlus Buds (060414) ----
  {
    name: 'OnePlus Buds',
    id: '060414',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      findDevice: true,
      keyFunction: true,
      autoFirmwareUpdate: true,
    },
  },

  // ---- OnePlus Buds Z (060814) ----
  {
    name: 'OnePlus Buds Z',
    id: '060814',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      findDevice: true,
      keyFunction: true,
      autoFirmwareUpdate: true,
    },
  },

  // ---- OnePlus Buds Pro (060C14) ----
  {
    name: 'OnePlus Buds Pro',
    id: '060C14',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      dolbyAtmos: true,
      customEqualizer: true,
      hearingEnhancement: true,
      wearDetection: true,
      findDevice: true,
      keyFunction: true,
      zenMode: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      noiseReductionMode: [
        { modeType: 7, protocolIndex: 4 },
        { modeType: 4, protocolIndex: 3 },
        { modeType: 3, protocolIndex: 2 },
        { modeType: 1, protocolIndex: 0 },
        { modeType: 2, protocolIndex: 1 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 3, modeType: 13 },
        { protocolIndex: 2, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
      ],
    },
  },

  // ---- OnePlus Buds Pro 2 (062014) ----
  {
    name: 'OnePlus Buds Pro 2',
    id: '062014',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      highAudio: true,
      dolbyAtmos: true,
      customEqualizer: true,
      hearingEnhancement: true,
      personalNoise: true,
      wearDetection: true,
      autoSwitchLink: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      zenMode: true,
      bassEngineSupport: true,
      earScan: true,
      spineHealth: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      spatialTypes: [0, 1, 2],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 1, childrenMode: [
          { modeType: 7, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 4 },
          { modeType: 8, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
        ] },
        { modeType: 1, protocolIndex: 0, childrenMode: [
          { modeType: 1, protocolIndex: 3 },
        ] },
        { modeType: 2, protocolIndex: 2, childrenMode: [
          { modeType: 2, protocolIndex: 8 },
        ] },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 3, modeType: 13 },
        { protocolIndex: 2, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
      ],
      equalizerModeCompat: [
        { protocolIndex: 7, modeType: 19 },
      ],
    },
  },

  // ---- OnePlus Buds Pro 2（轻享版） (063014) ----
  {
    name: 'OnePlus Buds Pro 2（轻享版）',
    id: '063014',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      highAudio: true,
      dolbyAtmos: true,
      customEqualizer: true,
      hearingEnhancement: true,
      personalNoise: true,
      wearDetection: true,
      autoSwitchLink: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      zenMode: true,
      bassEngineSupport: true,
      earScan: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 1, childrenMode: [
          { modeType: 7, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 4 },
          { modeType: 8, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
        ] },
        { modeType: 1, protocolIndex: 0, childrenMode: [
          { modeType: 1, protocolIndex: 3 },
        ] },
        { modeType: 2, protocolIndex: 2, childrenMode: [
          { modeType: 2, protocolIndex: 8 },
        ] },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 3, modeType: 13 },
        { protocolIndex: 2, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
      ],
      equalizerModeCompat: [
        { protocolIndex: 7, modeType: 19 },
      ],
    },
  },

  // ---- OnePlus Buds Pro 2R (063414) ----
  {
    name: 'OnePlus Buds Pro 2R',
    id: '063414',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      highAudio: true,
      dolbyAtmos: true,
      customEqualizer: true,
      hearingEnhancement: true,
      personalNoise: true,
      wearDetection: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      zenMode: true,
      bassEngineSupport: true,
      earScan: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 1, childrenMode: [
          { modeType: 7, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 4 },
          { modeType: 8, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
        ] },
        { modeType: 1, protocolIndex: 0, childrenMode: [
          { modeType: 1, protocolIndex: 3 },
        ] },
        { modeType: 2, protocolIndex: 2, childrenMode: [
          { modeType: 2, protocolIndex: 8 },
        ] },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 3, modeType: 13 },
        { protocolIndex: 2, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
      ],
      equalizerModeCompat: [
        { protocolIndex: 7, modeType: 19 },
      ],
    },
  },

  // ---- OnePlus Buds Z2 (061014) ----
  {
    name: 'OnePlus Buds Z2',
    id: '061014',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      customEqualizer: true,
      wearDetection: true,
      findDevice: true,
      keyFunction: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      noiseReductionMode: [
        { modeType: 4, protocolIndex: 3 },
        { modeType: 3, protocolIndex: 2 },
        { modeType: 1, protocolIndex: 0 },
        { modeType: 2, protocolIndex: 1 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 3, modeType: 13 },
        { protocolIndex: 2, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
      ],
    },
  },

  // ---- OnePlus Nord Buds CE (061C14) ----
  {
    name: 'OnePlus Nord Buds CE',
    id: '061C14',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      equalizerMode: [
        { protocolIndex: 1, modeType: 12 },
        { protocolIndex: 0, modeType: 17 },
        { protocolIndex: 2, modeType: 14 },
        { protocolIndex: 3, modeType: 15 },
      ],
    },
  },

  // ---- OnePlus Buds (068414) ----
  {
    name: 'OnePlus Buds',
    id: '068414',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      keyFunction: true,
      autoFirmwareUpdate: true,
    },
  },

  // ---- OnePlus Buds Z (068814) ----
  {
    name: 'OnePlus Buds Z',
    id: '068814',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      keyFunction: true,
      autoFirmwareUpdate: true,
    },
  },

  // ---- OnePlus Bullets Wireless Z2 (050414) ----
  {
    name: 'OnePlus Bullets Wireless Z2',
    id: '050414',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: false,
  },

  // ---- OnePlus Nord Buds (061414) ----
  {
    name: 'OnePlus Nord Buds',
    id: '061414',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      customEqualizer: true,
      findDevice: true,
      keyFunction: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 3, modeType: 13 },
        { protocolIndex: 2, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
      ],
    },
  },

  // ---- OnePlus Buds N (061814) ----
  {
    name: 'OnePlus Buds N',
    id: '061814',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      customEqualizer: true,
      findDevice: true,
      keyFunction: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 3, modeType: 13 },
        { protocolIndex: 2, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
      ],
    },
  },

  // ---- OnePlus Nord Buds 2 (062414) ----
  {
    name: 'OnePlus Nord Buds 2',
    id: '062414',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      customEqualizer: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      bassEngineSupport: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0 },
        { modeType: 1, protocolIndex: 1 },
        { modeType: 2, protocolIndex: 2 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 2, modeType: 13 },
        { protocolIndex: 3, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
      ],
    },
  },

  // ---- OnePlus Nord Buds 2r (062C14) ----
  {
    name: 'OnePlus Nord Buds 2r',
    id: '062C14',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      customEqualizer: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 2, modeType: 12 },
        { protocolIndex: 1, modeType: 13 },
      ],
    },
  },

  // ---- OnePlus Buds Ace (062814) ----
  {
    name: 'OnePlus Buds Ace',
    id: '062814',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      customEqualizer: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      bassEngineSupport: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0 },
        { modeType: 1, protocolIndex: 1 },
        { modeType: 2, protocolIndex: 2 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 2, modeType: 13 },
        { protocolIndex: 1, modeType: 12 },
      ],
    },
  },

  // ---- OnePlus BulletsWireless Z2 ANC (050C14) ----
  {
    name: 'OnePlus BulletsWireless Z2 ANC',
    id: '050C14',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      customEqualizer: true,
      findDevice: true,
      keyFunction: true,
      bassEngineSupport: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0 },
        { modeType: 1, protocolIndex: 1 },
        { modeType: 2, protocolIndex: 2 },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 2, modeType: 13 },
        { protocolIndex: 3, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
      ],
    },
  },

  // ---- OnePlus Bullets Wireless Z3 (051014) ----
  {
    name: 'OnePlus Bullets Wireless Z3',
    id: '051014',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      keyFunction: true,
      bassEngineSupport: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 3, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
        { protocolIndex: 2, modeType: 13 },
      ],
    },
  },

  // ---- OnePlus Buds 3 (063C14) ----
  {
    name: 'OnePlus Buds 3',
    id: '063C14',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      gameMode: 1,
      highAudio: true,
      dolbyAtmos: true,
      customEqualizer: true,
      hearingEnhancement: true,
      wearDetection: true,
      autoSwitchLink: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      bassEngineSupport: true,
      earScan: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      spatialTypes: [0, 1],
      gameSoundMutexes: [1, 2, 3],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 1, childrenMode: [
          { modeType: 7, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 4 },
          { modeType: 8, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
        ] },
        { modeType: 1, protocolIndex: 0, childrenMode: [
          { modeType: 1, protocolIndex: 3 },
        ] },
        { modeType: 2, protocolIndex: 2, childrenMode: [
          { modeType: 2, protocolIndex: 8 },
        ] },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 2, modeType: 14 },
        { protocolIndex: 1, modeType: 12 },
      ],
      equalizerModeCompat: [
        { protocolIndex: 3, modeType: 13 },
      ],
      gameSoundList: [
        { type: 1, name: '游戏音效1' },
        { type: 0, name: '关闭' },
      ],
    },
  },

  // ---- OnePlus Buds V (064814) ----
  {
    name: 'OnePlus Buds V',
    id: '064814',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      dolbyAtmos: true,
      customEqualizer: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      diagnostic: true,
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 2, modeType: 12 },
        { protocolIndex: 1, modeType: 13 },
      ],
    },
  },

  // ---- OnePlus Nord Buds 3 Pro (064414) ----
  {
    name: 'OnePlus Nord Buds 3 Pro',
    id: '064414',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      highAudio: true,
      dolbyAtmos: true,
      customEqualizer: true,
      hearingEnhancement: true,
      personalNoise: true,
      wearDetection: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      bassEngineSupport: true,
      earScan: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      spatialTypes: [0, 1],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 1, childrenMode: [
          { modeType: 7, protocolIndex: 7 },
          { modeType: 4, protocolIndex: 4 },
          { modeType: 8, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
        ] },
        { modeType: 1, protocolIndex: 0, childrenMode: [
          { modeType: 1, protocolIndex: 3 },
        ] },
        { modeType: 2, protocolIndex: 2, childrenMode: [
          { modeType: 2, protocolIndex: 8 },
        ] },
      ],
      equalizerMode: [
        { protocolIndex: 3, modeType: 11 },
        { protocolIndex: 4, modeType: 14 },
        { protocolIndex: 5, modeType: 12 },
      ],
    },
  },

  // ---- OnePlus Nord Buds 3 (065014) ----
  {
    name: 'OnePlus Nord Buds 3',
    id: '065014',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      dolbyAtmos: true,
      customEqualizer: true,
      hearingEnhancement: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      bassEngineSupport: true,
      earScan: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0 },
        { modeType: 1, protocolIndex: 1 },
        { modeType: 2, protocolIndex: 2 },
      ],
      equalizerMode: [
        { protocolIndex: 3, modeType: 11 },
        { protocolIndex: 4, modeType: 14 },
        { protocolIndex: 5, modeType: 12 },
      ],
    },
  },

  // ---- OnePlus Buds Ace 2 (064C14) ----
  {
    name: 'OnePlus Buds Ace 2',
    id: '064C14',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      dolbyAtmos: true,
      customEqualizer: true,
      hearingEnhancement: true,
      autoSwitchLink: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      bassEngineSupport: true,
      earScan: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      spatialTypes: [0, 1],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 0 },
        { modeType: 1, protocolIndex: 1 },
        { modeType: 2, protocolIndex: 2 },
      ],
      equalizerMode: [
        { protocolIndex: 3, modeType: 11 },
        { protocolIndex: 4, modeType: 14 },
        { protocolIndex: 5, modeType: 12 },
      ],
    },
  },

  // ---- OnePlus Buds 4 (065414) ----
  {
    name: 'OnePlus Buds 4',
    id: '065414',
    brands: ['OnePlus'],
    protocolType: 1,
    supportSpp: true,
    function: {
      multiDevicesConnect: 1,
      highAudio: true,
      dolbyAtmos: true,
      customEqualizer: true,
      hearingEnhancement: true,
      wearDetection: true,
      autoSwitchLink: true,
      findDevice: true,
      keyFunction: true,
      clickTakePic: true,
      bassEngineSupport: true,
      aiTranslate: true,
      aiSummary: true,
      earScan: true,
      diagnostic: true,
      autoFirmwareUpdate: true,
      fitDetection: true,
      spatialTypes: [0, 1],
      noiseReductionMode: [
        { modeType: 5, protocolIndex: 1, childrenMode: [
          { modeType: 4, protocolIndex: 4 },
          { modeType: 8, protocolIndex: 5 },
          { modeType: 3, protocolIndex: 6 },
          { modeType: 7, protocolIndex: 7 },
        ] },
        { modeType: 10, protocolIndex: 11 },
        { modeType: 2, protocolIndex: 2, childrenMode: [
          { modeType: 2, protocolIndex: 8 },
        ] },
        { modeType: 1, protocolIndex: 0, childrenMode: [
          { modeType: 1, protocolIndex: 3 },
        ] },
      ],
      equalizerMode: [
        { protocolIndex: 0, modeType: 11 },
        { protocolIndex: 1, modeType: 14 },
        { protocolIndex: 2, modeType: 12 },
      ],
    },
  },

  // ---- realme Buds Air8 (066812) ----
  {
    name: 'realme Buds Air8',
    id: '066812',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      wearDetection: true,
      findDevice: true,
      clickTakePic: true,
    },
  },

  // ---- realme Buds Air (3D59CF) ----
  {
    name: 'realme Buds Air',
    id: '3D59CF',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
  },

  // ---- realme Buds Air Neo (F85450) ----
  {
    name: 'realme Buds Air Neo',
    id: 'F85450',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
  },

  // ---- realme Buds Wireless Pro (E3009F) ----
  {
    name: 'realme Buds Wireless Pro',
    id: 'E3009F',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
  },

  // ---- realme Buds Air Pro (8CD10F) ----
  {
    name: 'realme Buds Air Pro',
    id: '8CD10F',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
  },

  // ---- realme Buds Air 2 (BA5D56) ----
  {
    name: 'realme Buds Air 2',
    id: 'BA5D56',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
  },

  // ---- realme Buds Air 2 Neo (1B5374) ----
  {
    name: 'realme Buds Air 2 Neo',
    id: '1B5374',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
  },

  // ---- realme Buds Wireless 2 (C1E2B1) ----
  {
    name: 'realme Buds Wireless 2',
    id: 'C1E2B1',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
  },

  // ---- realme Buds Wireless 2 Neo (C70A6D) ----
  {
    name: 'realme Buds Wireless 2 Neo',
    id: 'C70A6D',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
  },

  // ---- realme Buds Q2 (693878) ----
  {
    name: 'realme Buds Q2',
    id: '693878',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
  },

  // ---- realme Cobble Speaker (49074B) ----
  {
    name: 'realme Cobble Speaker',
    id: '49074B',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
  },

  // ---- realme Pocket Speaker (C70A75) ----
  {
    name: 'realme Pocket Speaker',
    id: 'C70A75',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
  },

  // ---- realme Brick Speaker (A5FD66) ----
  {
    name: 'realme Brick Speaker',
    id: 'A5FD66',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
  },

  // ---- realme Buds Air 3 (060812) ----
  {
    name: 'realme Buds Air 3',
    id: '060812',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
  },

  // ---- realme Buds Q2s (060C12) ----
  {
    name: 'realme Buds Q2s',
    id: '060C12',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
  },

  // ---- realme Buds Wireless 2S (050412) ----
  {
    name: 'realme Buds Wireless 2S',
    id: '050412',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
  },

  // ---- realme Buds Air 3 Neo (061812) ----
  {
    name: 'realme Buds Air 3 Neo',
    id: '061812',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
  },

  // ---- realme Buds T100 (061412) ----
  {
    name: 'realme Buds T100',
    id: '061412',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
  },

  // ---- realme Buds Air 3S (061012) ----
  {
    name: 'realme Buds Air 3S',
    id: '061012',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      findDevice: true,
      clickTakePic: true,
      diagnostic: true,
    },
  },

  // ---- realme Buds Air6 Pro (063012) ----
  {
    name: 'realme Buds Air6 Pro',
    id: '063012',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      wearDetection: true,
      findDevice: true,
      clickTakePic: true,
    },
  },

  // ---- realme Buds Wireless 3 (050812) ----
  {
    name: 'realme Buds Wireless 3',
    id: '050812',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      clickTakePic: true,
      diagnostic: true,
    },
  },

  // ---- realme Buds Air6 (063412) ----
  {
    name: 'realme Buds Air6',
    id: '063412',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      wearDetection: true,
      findDevice: true,
      clickTakePic: true,
    },
  },

  // ---- realme Buds N1 Pro (063812) ----
  {
    name: 'realme Buds N1 Pro',
    id: '063812',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      findDevice: true,
      clickTakePic: true,
    },
  },

  // ---- realme Buds T310 (063C12) ----
  {
    name: 'realme Buds T310',
    id: '063C12',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      findDevice: true,
      clickTakePic: true,
    },
  },

  // ---- realme Buds N1 (064012) ----
  {
    name: 'realme Buds N1',
    id: '064012',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      findDevice: true,
      clickTakePic: true,
    },
  },

  // ---- realme Buds T300 (062412) ----
  {
    name: 'realme Buds T300',
    id: '062412',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      findDevice: true,
      clickTakePic: true,
    },
  },

  // ---- realme Buds Air7 (064812) ----
  {
    name: 'realme Buds Air7',
    id: '064812',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      wearDetection: true,
      findDevice: true,
      clickTakePic: true,
    },
  },

  // ---- realme Buds Air7 Pro (064C12) ----
  {
    name: 'realme Buds Air7 Pro',
    id: '064C12',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      wearDetection: true,
      findDevice: true,
      clickTakePic: true,
    },
  },

  // ---- realme Buds Air8 Pro (066C12) ----
  {
    name: 'realme Buds Air8 Pro',
    id: '066C12',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      wearDetection: true,
      findDevice: true,
      clickTakePic: true,
    },
  },

  // ---- realme Buds T500 Pro (066452) ----
  {
    name: 'realme Buds T500 Pro',
    id: '066452',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      wearDetection: true,
      findDevice: true,
      clickTakePic: true,
    },
  },

  // ---- realme Buds T500 Pro Harry Potter Edition (067452) ----
  {
    name: 'realme Buds T500 Pro Harry Potter Edition',
    id: '067452',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      wearDetection: true,
      findDevice: true,
      clickTakePic: true,
    },
  },

  // ---- realme Buds T500 (067052) ----
  {
    name: 'realme Buds T500',
    id: '067052',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      findDevice: true,
      clickTakePic: true,
    },
  },

  // ---- realme Buds Clip (065C12) ----
  {
    name: 'realme Buds Clip',
    id: '065C12',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      findDevice: true,
    },
  },

  // ---- realme Buds T200 (065452) ----
  {
    name: 'realme Buds T200',
    id: '065452',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      findDevice: true,
      clickTakePic: true,
    },
  },

  // ---- realme Buds T110 (062812) ----
  {
    name: 'realme Buds T110',
    id: '062812',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
  },

  // ---- realme Buds T01 (064412) ----
  {
    name: 'realme Buds T01',
    id: '064412',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
  },

  // ---- realme Buds T200 Lite (065052) ----
  {
    name: 'realme Buds T200 Lite',
    id: '065052',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
  },

  // ---- realme Buds T200x (065852) ----
  {
    name: 'realme Buds T200x',
    id: '065852',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
  },

  // ---- realme TechLife Buds (066012) ----
  {
    name: 'realme TechLife Buds',
    id: '066012',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      findDevice: true,
    },
  },

  // ---- realme Buds Wireless 3 Neo (050C12) ----
  {
    name: 'realme Buds Wireless 3 Neo',
    id: '050C12',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
  },

  // ---- realme Buds Wireless 5 ANC (051412) ----
  {
    name: 'realme Buds Wireless 5 ANC',
    id: '051412',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
  },

  // ---- realme Buds Wireless 6 ANC (052052) ----
  {
    name: 'realme Buds Wireless 6 ANC',
    id: '052052',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
  },

  // ---- realme Buds Wireless 6 Neo (051812) ----
  {
    name: 'realme Buds Wireless 6 Neo',
    id: '051812',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      findDevice: true,
    },
  },

  // ---- realme Buds Wireless 6 (051C52) ----
  {
    name: 'realme Buds Wireless 6',
    id: '051C52',
    brands: ['realme'],
    protocolType: 1,
    supportSpp: true,
    function: {
      findDevice: true,
    },
  },

  // ---- DIZO Wireless (C70A6E) ----
  {
    name: 'DIZO Wireless',
    id: 'C70A6E',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
  },

  // ---- DIZO GoPods D (C70A6F) ----
  {
    name: 'DIZO GoPods D',
    id: 'C70A6F',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
  },

  // ---- DIZO GoPods (C70A70) ----
  {
    name: 'DIZO GoPods',
    id: 'C70A70',
    brands: ['realme'],
    protocolType: 2,
    supportSpp: true,
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
