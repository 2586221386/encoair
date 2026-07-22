/**
 * OPPO 私有蓝牙协议定义
 * 移植自 OppoPodsManager-main:
 *   - Protocol/OppoProtocol.cs
 *   - Protocol/OppoProtocol.Anc.cs
 *   - Protocol/OppoProtocol.Features.cs
 *   - Protocol/OppoProtocol.MultiDevice.cs
 *
 * 集中管理所有命令字、Feature 常量、ANC 载荷、帧构造工具。
 * 使用方式:
 *   import { CmdBattery, buildPacket, ... } from '../common/OppoProtocol'
 */

// ============== SPP 服务 UUID ==============
/** OPPO SPP 服务 UUID，所有支持设备共用 */
export const OPPO_SPP_UUID: string = '0000079A-D102-11E1-9B23-00025B00A5A5';

// ============== 协议帧头 ==============
export const PROTOCOL_HEADER: number = 0xAA;
export const PROTOCOL_SEQ: number = 0xF0;

// ============== 命令字：设备信息查询（0x1xx）与响应（0x81xx）==============
export const CmdQueryCapability     = 0x0100; // 基础能力位图
export const CmdCapabilityResp      = 0x8100; // 基础能力位图响应
export const CmdQueryMtu            = 0x0101; // 远程 MTU
export const CmdQueryVendorId       = 0x0102; // 远程 Vendor ID
export const CmdQueryProductId      = 0x0103; // 查询远程 Product ID（设备识别主键）
export const CmdProductIdResp       = 0x8103; // Product ID 响应
export const CmdQueryVersion        = 0x0105; // 远程固件版本
export const CmdQueryVersionResp    = 0x8105; // 固件版本响应
export const CmdBattery             = 0x0106; // 查询电量
export const CmdBatteryResp         = 0x8106; // 电量响应
export const CmdQueryUpgradeCap     = 0x0107; // 升级能力
export const CmdQueryFunctionKey    = 0x0108; // 按键功能
export const CmdQueryEarStatus      = 0x0109; // 耳机佩戴状态
export const CmdQueryColorId        = 0x010B; // 耳机颜色 ID
export const CmdQueryAnc            = 0x010C; // 查询降噪状态
export const CmdAncResp             = 0x810C; // 降噪状态响应
export const CmdBatchQuery          = 0x010D; // 批量查询功能状态
export const CmdBatchQueryResp      = 0x810D; // 批量查询响应
export const CmdQueryEq             = 0x010F; // 查询当前 EQ
export const CmdEqResp              = 0x810F; // EQ 查询响应
export const CmdMultiConnectInfo    = 0x0112; // 查询多设备连接列表
export const CmdMultiConnectResp    = 0x8112; // 多设备列表响应
export const CmdQueryCodecType      = 0x0114; // 当前编解码器类型
export const CmdQueryCodecTypeResp  = 0x8114; // 编解码器响应
export const CmdQueryHearing        = 0x0115; // 听力增强数据
export const CmdQueryHearingFilter  = 0x0116; // 听力增强滤波数据
export const CmdQueryEqAll          = 0x0122; // 全部 EQ 数据
export const CmdQueryEqAllResp      = 0x8122; // 全部 EQ 数据响应
export const CmdQueryBassEngine     = 0x0124; // 低音引擎值
export const CmdQueryHeadsetSpatial = 0x012A; // 空间音频三模式当前值
export const CmdHeadsetSpatialResp  = 0x812A; // 空间音频三模式查询响应
export const CmdQueryGameSound      = 0x012B; // 游戏音效信息
export const CmdQueryGameSoundResp  = 0x812B; // 游戏音效响应
export const CmdQueryMultiPriority  = 0x0132; // 多连接优先设备
export const CmdMultiPriorityResp   = 0x8132; // 多连接优先设备响应

// ============== 命令字：音量查询（0x13xx）==============
export const CmdQueryVolumeValue    = 0x0130; // 查询音量档位
export const CmdQueryVolumeValueResp = 0x8130; // 音量档位响应

// ============== 命令字：高级设置（0x4xx）==============
export const CmdSetFindMode         = 0x0400; // 查找耳机模式
export const CmdSetKeyFunction      = 0x0402; // 设置按键功能
export const CmdSetFeature          = 0x0403; // 通用功能开关 [featureType][status]
export const CmdSetFeatureResp      = 0x8403; // 功能开关响应
export const CmdSetNoiseMode        = 0x0404; // 设置降噪模式
export const CmdSetNoiseModeResp    = 0x8404; // 降噪设置响应
export const CmdSetCompactness      = 0x0405; // 贴合度检测开关
export const CmdSetEq               = 0x0406; // 设置 EQ 预设
export const CmdSetEqResp           = 0x8406; // EQ 设置响应
export const CmdSetRelatedDevice    = 0x0408; // 关联设备信息
export const CmdSetEqDetail         = 0x0418; // 设置详细 EQ（自定义频段）
export const CmdSetEqDetailResp     = 0x8418; // 详细 EQ 响应
export const CmdSetVolumeValue      = 0x0427; // 设置音量档位
export const CmdSetVolumeValueResp  = 0x8427; // 音量设置响应
export const CmdSetGameStatus       = 0x0420; // 游戏模式状态（独立命令）
export const CmdSpatialAudio        = 0x0422; // 空间音频三模式（Off/Fixed/Track）
export const CmdSpatialAudioResp    = 0x8422; // 空间音频 SET 响应
export const CmdSetFeatureSwitch    = 0x0423; // 游戏音效 [type][enable]
export const CmdSetFeatureSwitchResp = 0x8423; // 游戏音效响应
export const CmdOperateHandheld     = 0x0429; // 切换多设备中的活动设备
export const CmdOperateHandheldResp = 0x8429; // 多设备操作响应

// ============== 命令字：主动通知 ==============
export const CmdActiveReport        = 0x0204; // 主动通知事件

// ============== 命令字：EQ 通知 ==============
export const CmdEqNotify             = 0x0504; // EQ 变更通知

// ============== 命令字：通知注册 ==============
export const CmdRegisterNotify      = 0x0205; // 订阅设备主动通知

// ============== 0x0204 通知事件子类型（payload[0] 分发键）==============
export const EvtBattery         = 0x01; // 电池信息
export const EvtEarBudsStatus   = 0x02; // 佩戴/入耳状态
export const EvtNoiseMode       = 0x03; // 降噪模式变更
export const EvtCompactness     = 0x04; // 贴合度检测
export const EvtGameMode        = 0x05; // 游戏模式开关
export const EvtMultiConnect    = 0x06; // 多设备连接状态
export const EvtHearingDetect   = 0x08; // 听力检测状态
export const EvtCodecType       = 0x09; // 编解码器类型
export const EvtZenMode         = 0x0A; // 禅模式开关
export const EvtPersonalNoise   = 0x0B; // 个性化降噪结果
export const EvtTriangle        = 0x0D; // 空间音频三角信息
export const EvtEarScan         = 0x0E; // 耳道扫描结果
export const EvtGaming          = 0x0F; // 多连接游戏/手持/点击等级公共事件
export const EvtOneshot         = 0x10; // Oneshot 状态
export const EvtToneChange      = 0x11; // 耳音调变更
export const EvtUserInteraction = 0xF1; // 用户交互事件

/** 0x0204 子类型 → 可读名称 */
export function activeReportName(subType: number): string {
  switch (subType) {
    case EvtBattery: return '电池';
    case EvtEarBudsStatus: return '佩戴状态';
    case EvtNoiseMode: return '降噪变更';
    case EvtCompactness: return '贴合检测';
    case EvtGameMode: return '游戏模式';
    case EvtMultiConnect: return '多连接状态';
    case EvtHearingDetect: return '听力检测';
    case EvtCodecType: return '编解码';
    case EvtZenMode: return '禅模式';
    case EvtPersonalNoise: return '个性化降噪';
    case EvtTriangle: return '空间音频三角';
    case EvtEarScan: return '耳道扫描';
    case EvtGaming: return '游戏/手持公共事件';
    case EvtOneshot: return 'Oneshot';
    case EvtToneChange: return '耳音调';
    case EvtUserInteraction: return '用户交互';
    default: return `未知(0x${subType.toString(16)})`;
  }
}

// ============== ANC 模式载荷字节 ==============
export const AncOff         = [0x01, 0x01, 0x01];
export const AncSmart       = [0x01, 0x01, 0x80];
export const AncLight       = [0x01, 0x01, 0x40];
export const AncMedium      = [0x01, 0x01, 0x20];
export const AncDeep        = [0x01, 0x01, 0x10];
export const AncAdaptive    = [0x01, 0x01, 0x00, 0x08];
export const AncTransparency = [0x01, 0x01, 0x04];
export const AncNoiseCancellation = [0x01, 0x01, 0x02];

/** ANC 响应字节到模式名的反向查找 */
export const AncValues: Record<string, string> = {
  '8,0': 'Off',
  '2,0': 'NoiseCancellation',
  '0x80,0': 'Smart',
  '0x40,0': 'Light',
  '0x20,0': 'Medium',
  '0x10,0': 'Deep',
  '0,1': 'Transparency',
  '0,2': 'Transparency',
  '4,0': 'Transparency',
  '0,8': 'Adaptive',
};

/** 旧版 ANC 值交换：部分无子模式的设备 NC ↔ Transparency 对调 */
export function legacyAncSwap(mode: string): string {
  switch (mode) {
    case 'Smart': case 'Light': case 'Medium': case 'Deep': return 'Transparency';
    case 'Transparency': return 'Smart';
    default: return mode;
  }
}

/** 按 mode 名返回 ANC 载荷字节数组 */
export function ancPayloadByName(mode: string): number[] {
  switch (mode) {
    case 'Off': return AncOff;
    case 'Smart': return AncSmart;
    case 'Light': return AncLight;
    case 'Medium': return AncMedium;
    case 'Deep': return AncDeep;
    case 'Adaptive': return AncAdaptive;
    case 'Transparency': return AncTransparency;
    case 'NoiseCancellation': return AncNoiseCancellation;
    default: return AncOff;
  }
}

/** 按 ANC 模式数字 (1-8) 返回载荷字节数组 */
export function getAncPayloadForMode(mode: number): number[] | null {
  switch (mode) {
    case 1: return AncOff;
    case 2: return AncNoiseCancellation;
    case 3: return AncTransparency;
    case 4: return AncAdaptive;
    case 5: return AncSmart;
    case 6: return AncLight;
    case 7: return AncMedium;
    case 8: return AncDeep;
    default: return null;
  }
}

/** 按 protocolIndex 生成 ANC 载荷字节 */
export function ancPayloadByIndex(protocolIndex: number): number[] {
  const byteCount = Math.floor(protocolIndex / 8) + 1;
  const payload: number[] = [0x01, 0x01];
  for (let k = 0; k < byteCount; k++) payload.push(0x00);
  const bitPos = protocolIndex % 8;
  payload[2 + Math.floor(protocolIndex / 8)] = 1 << bitPos;
  return payload;
}

// ============== 空间音频模式（cmd 0x0422）==============
export const SpatialOff = [0x00];
export const SpatialFixed = [0x01];
export const SpatialTrack = [0x02];

/** 空间音频 mode 名 → 载荷字节数组 */
export function spatialPayload(mode: string): number[] {
  switch (mode) {
    case 'Fixed': return SpatialFixed;
    case 'Track': return SpatialTrack;
    default: return SpatialOff;
  }
}

/** 空间音频 spatialType 值 → 模式名 */
export function spatialTypeToName(type: number): string {
  switch (type) {
    case 1: return 'Fixed';
    case 2: return 'Track';
    default: return 'Off';
  }
}

// ============== 功能开关 featureType（命令 0x0403）==============
export const FeatureWearDetection    = 0x04;
export const FeatureGameLL           = 0x06;  // 旧版低延迟游戏模式
export const FeatureVocalEnhance     = 0x09;
export const FeatureHearingEnhance   = 0x0B;
export const FeaturePersonalNoise    = 0x0C;
export const FeatureClickTakePhoto   = 0x0D;
export const FeatureZenMode          = 0x0F;
export const FeatureDualDevice       = 0x11;
export const FeatureSoundRecord      = 0x13;
export const FeatureVoiceAssist      = 0x14;
export const FeatureFreeDialog       = 0x15;
export const FeatureSafeRemind       = 0x16;
export const FeatureLongPowerMode    = 0x17;
export const FeatureHiQualityAudio   = 0x18;
export const FeatureVoiceCommand     = 0x19;
export const FeatureSpatial          = 0x1B;
export const FeatureAutoVolume       = 0x1C;
export const FeatureBassEngine       = 0x1D;
export const FeatureSaveLog          = 0x1E;
export const FeatureGameEqualizer    = 0x21;
export const FeatureSpineLiveMonitor = 0x22;
export const FeatureSpineCervical    = 0x23;
export const FeatureSpineExercise    = 0x24;
export const FeatureGameSound        = 0x27;
export const FeatureGameMain         = 0x28;  // 新版游戏主开关
export const FeatureAdaptiveVolume   = 0x30;
export const FeatureAdaptiveEar      = 0x31;
export const FeatureSpeechPerception = 0x32;
export const FeatureMicControl       = 0x34;
export const FeatureLongPressVolume  = 0x35;
export const FeatureSwiftPair        = 0x37;
export const FeatureHearingOptimize  = 0x38;
export const FeatureIncomingCallCtrl = 0x39;
export const FeatureSleepDetection   = 0x3A;
export const FeatureHeadMotion       = 0x3B;

// ============== 多设备操作常量 ==============
export const MultiOpConnect     = 0x01;  // 连接手持设备
export const MultiOpDisconnect  = 0x02;  // 断开手持设备
export const MultiOpUnpair      = 0x03;  // 取消配对
export const MultiOpSetPriority = 0x04;  // 设置音频优先设备

// ============== 帧构造工具 ==============

/**
 * 构造 OPPO 协议帧
 * 对应 C# OppoProtocol.BuildPacket()
 *
 * 帧结构: [Header(1)][Len(1)][Reserved(2)][CmdL(1)][CmdH(1)][Seq(1)][PayLenL(1)][PayLenH(1)][Payload...]
 */
export function buildPacket(cmd: number, payload?: number[], seq?: number): Uint8Array {
  const payData = payload ?? [];
  const payLen = payData.length;
  const totalLen = 7 + payLen;
  const packet = new Uint8Array(2 + totalLen);
  packet[0] = PROTOCOL_HEADER;
  packet[1] = totalLen;
  packet[2] = 0x00;
  packet[3] = 0x00;
  packet[4] = cmd & 0xFF;
  packet[5] = (cmd >> 8) & 0xFF;
  packet[6] = seq ?? PROTOCOL_SEQ;
  packet[7] = payLen & 0xFF;
  packet[8] = (payLen >> 8) & 0xFF;
  for (let i = 0; i < payLen; i++) {
    packet[9 + i] = payData[i];
  }
  return packet;
}

/**
 * 构造功能开关帧（cmd 0x0403 + feature + on/off）
 * 对应 C# OppoProtocol.BuildFeaturePacket()
 */
export function buildFeaturePacket(feature: number, on: boolean): Uint8Array {
  return buildPacket(CmdSetFeature, [feature, on ? 0x01 : 0x00]);
}

/**
 * 构造功能开关载荷字节
 */
export function featurePayload(feature: number, on: boolean): number[] {
  return [feature, on ? 0x01 : 0x00];
}

// ============== 预构建的常用包 ==============
export const PktBattery = buildPacket(CmdBattery);
export const PktQueryAnc = buildPacket(CmdQueryAnc, [0x01, 0x01]);

/** 批量查询包：查询 12 个功能 feature 的状态 */
export const PktBatchQuery = buildPacket(CmdBatchQuery,
  [0x0B, 0x05, 0x04, 0x0B, 0x11, 0x13, 0x18, 0x06, 0x1B, 0x1C, 0x27, 0x28]);

/** 订阅主动通知：电池 + 佩戴 */
export const PktRegisterNotify = buildPacket(CmdRegisterNotify, [0x01, 0x01, 0x02, 0x02]);

// ============== 载荷常量 ==============
export const PayEmpty: number[] = [];
export const PayQueryAnc = [0x01, 0x01];
export const PayRegisterNotify = [0x01, 0x01, 0x02, 0x02];
export const PayQueryEqAll = [0x01, 0x05];

// ============== 多设备操作载荷构造 ==============

/**
 * 将 "AA:BB:CC:DD:EE:FF" 格式 MAC 地址解析为 6 字节数组（正序）
 * 对应 C# OppoProtocol.ParseMac()
 */
export function parseMac(address: string): Uint8Array {
  const mac = new Uint8Array(6);
  if (!address) return mac;
  const parts = address.split(':');
  for (let i = 0; i < 6 && i < parts.length; i++) {
    try {
      mac[i] = parseInt(parts[i], 16);
    } catch (_) {
      mac[i] = 0;
    }
  }
  return mac;
}

/**
 * 构造多设备操作帧（cmd 0x0429）
 * 对应 C# OppoProtocol.MultiConnectOpPayload()
 *
 * operateType 1/2/3: [type(1)][addr(6)]
 * operateType 4 (设置音频优先设备):
 *   - clearAddress=true: [04][00]
 *   - clearAddress=false: [04][01][addr(6)]
 */
export function buildMultiConnectOpPacket(operateType: number, targetAddress: string, clearAddress: boolean = false): Uint8Array {
  if (operateType === MultiOpSetPriority) {
    if (clearAddress) {
      return buildPacket(CmdOperateHandheld, [operateType, 0x00]);
    } else {
      const mac = parseMac(targetAddress);
      const payload: number[] = [operateType, 0x01];
      for (let i = 0; i < 6; i++) payload.push(mac[i]);
      return buildPacket(CmdOperateHandheld, payload);
    }
  } else {
    const mac = parseMac(targetAddress);
    const payload: number[] = [operateType];
    for (let i = 0; i < 6; i++) payload.push(mac[i]);
    return buildPacket(CmdOperateHandheld, payload);
  }
}

// ============== 工具函数 ==============

/** 字节数组转 HEX 字符串（空格分隔，大写） */
export function toHexStr(data: Uint8Array): string {
  const parts: string[] = [];
  for (let i = 0; i < data.length; i++) {
    parts.push(data[i].toString(16).toUpperCase().padStart(2, '0'));
  }
  return parts.join(' ');
}

/** 从完整帧中提取命令字 */
export function extractCmd(data: Uint8Array): number {
  if (data.length < 9) return -1;
  return (data[4] | (data[5] << 8));
}

/** 帧信息（payload 起始位置和长度） */
export class FrameInfo {
  start: number = 0;
  len: number = 0;
}

/** 从完整帧中提取 payload 起始位置和长度 */
export function extractPayload(data: Uint8Array): FrameInfo | null {
  if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return null;
  const payLen = (data[7] | (data[8] << 8));
  const start = 9;
  if (data.length < start + payLen) return null;
  const info = new FrameInfo();
  info.start = start;
  info.len = payLen;
  return info;
}

/** 编解码器 ID → 可读名称 */
export function codecName(id: number): string {
  switch (id) {
    case 0: return 'SBC';
    case 1: return 'LDAC';
    case 2: return 'AAC';
    case 3: return 'LHDC';
    case 4: return 'LC3';
    case 5: return 'aptX';
    case 6: return 'aptX HD';
    case 7: return 'aptX Adaptive';
    case 8: return 'LHDC';
    case -1: return '-';
    default: return `未知 (${id})`;
  }
}

/** 解析固件版本响应（0x8105）：[status(1)][n(1)][UTF-8 CSV] */
export function parseVersion(payload: Uint8Array): string | null {
  if (payload.length < 3 || payload[0] !== 0) return null;
  try {
    const s = String.fromCharCode(...payload.slice(2)).replace(/\0/g, '').trim();
    return s || null;
  } catch (_) {
    return null;
  }
}

/** 解析编解码器类型响应（0x8114） */
export function parseCodecType(payload: Uint8Array): number {
  if (payload.length >= 2 && payload[0] === 0) {
    return payload[1];
  }
  if (payload.length >= 4 && payload[0] === 0) {
    const n = payload[1];
    if (n > 0 && payload.length >= 2 + n * 2) {
      for (let i = 0; i < n; i++) {
        if (payload[3 + i * 2] !== 0) return payload[2 + i * 2];
      }
    }
  }
  return -1;
}

/** 解析产品ID响应（0x8103）：[status(1)][productId(3 LE)] → 6位大写十六进制 */
export function parseProductId(payload: Uint8Array): string | null {
  if (payload.length !== 4 || payload[0] !== 0) return null;
  const id = payload[1] + payload[2] * 256 + payload[3] * 65536;
  return id.toString(16).toUpperCase().padStart(6, '0');
}

/** 解析能力位图响应（0x8100）[status(1)][bitmap...] → 返回位图字节数组 */
export function parseCapabilityBitmap(payload: Uint8Array): Uint8Array | null {
  if (payload.length <= 1 || payload[0] !== 0) return null;
  return payload.slice(1);
}

/** 按 Melody 逻辑选择游戏模式 feature */
export function gameModeFeature(supportsGameSound: boolean): number {
  return supportsGameSound ? FeatureGameMain : FeatureGameLL;
}

// ============== 自定义 EQ 相关类型与工具 ==============

/**
 * 设备端 EQ 预设条目，由 0x0122 getAllEqInfo 响应解析而来。
 * 移植自 C# EqInfoEntry.cs
 */
export class EqInfoEntry {
  /** EQ 预设唯一 ID（protocolIndex） */
  eqId: number = 0;
  /** 设备端允许的最小增益值 */
  minValue: number = -6;
  /** 设备端允许的最大增益值 */
  maxValue: number = 6;
  /** 设备端存储的预设名称 */
  name: string = '';
  /** 是否当前选中激活的预设 */
  isSelected: boolean = false;
  /** 频段值列表（Hz） */
  frequencies: number[] = [];
  /** 频段增益值列表（dB） */
  gains: number[] = [];
}

/**
 * 解析 0x0122 getAllEqInfo 响应载荷，返回设备端所有 EQ 预设条目。
 * 移植自 C# OppoProtocol.ParseEqAll()
 *
 * 格式：[status(1)][count(1)][entry0][entry1]...
 * 每个 entry：[isSelect(1)][minSigned(1)][maxSigned(1)][eqId(1)][nameLen(1)][nameUTF8...][freqCount(1)][freqLE(2)][db(1)]...
 */
export function parseEqAll(payload: Uint8Array): EqInfoEntry[] {
  const entries: EqInfoEntry[] = [];
  if (payload == null || payload.length < 2) return entries;

  if (payload[0] !== 0) return entries;
  const count = payload[1];
  let pos = 2;

  for (let i = 0; i < count && pos < payload.length; i++) {
    if (pos + 5 > payload.length) break;

    const isSelected = payload[pos] !== 0;
    const minValue = (payload[pos + 1] << 24) >> 24;
    const maxValue = (payload[pos + 2] << 24) >> 24;
    const eqId = payload[pos + 3];
    const nameLen = payload[pos + 4];
    pos += 5;

    let name = '';
    if (nameLen > 0 && pos + nameLen <= payload.length) {
      const nameBytes = payload.slice(pos, pos + nameLen);
      name = decodeUtf8EqName(nameBytes);
      pos += nameLen;
    }

    if (pos + 1 > payload.length) break;
    const freqCount = payload[pos++];

    const freqs: number[] = [];
    const gains: number[] = [];

    for (let j = 0; j < freqCount && pos + 3 <= payload.length; j++) {
      freqs.push(payload[pos] | (payload[pos + 1] << 8));
      gains.push((payload[pos + 2] << 24) >> 24);
      pos += 3;
    }

    const entry = new EqInfoEntry();
    entry.eqId = eqId;
    entry.minValue = minValue;
    entry.maxValue = maxValue;
    entry.name = name;
    entry.isSelected = isSelected;
    entry.frequencies = freqs;
    entry.gains = gains;
    entries.push(entry);
  }

  return entries;
}

/**
 * 解码设备端返回的 UTF-8 编码的 EQ 预设名称
 * 移植自 C# PodManager 
 */
function decodeUtf8EqName(bytes: Uint8Array): string {
  let result = '';
  let i = 0;
  while (i < bytes.length) {
    const b = bytes[i];
    if (b < 0x80) {
      result += String.fromCharCode(b);
      i += 1;
    } else if ((b & 0xE0) === 0xC0) {
      if (i + 1 < bytes.length) {
        const code = ((b & 0x1F) << 6) | (bytes[i + 1] & 0x3F);
        result += String.fromCharCode(code);
        i += 2;
      } else {
        i += 1;
      }
    } else if ((b & 0xF0) === 0xE0) {
      if (i + 2 < bytes.length) {
        const code = ((b & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F);
        result += String.fromCharCode(code);
        i += 3;
      } else {
        i += 1;
      }
    } else {
      i += 1;
    }
  }
  return result.replace(/\0/g, '').trim();
}

/**
 * 构建自定义 EQ 指令的内部载荷（cmd 0x0418）。
 * 移植自 C# OppoProtocol.EqInfoPayload()
 *
 * @param actionType 1=新建, 2=更新/应用, 3=删除
 * @param gains 频段增益数组
 * @param frequencies 频率数组
 * @param name 预设名称
 * @param eqId 预设ID（新建时为0）
 * @param minValue 最小增益
 * @param maxValue 最大增益
 */
function buildEqInfoPayload(
  actionType: number,
  gains: number[],
  frequencies: number[],
  name: string,
  eqId: number,
  minValue: number,
  maxValue: number
): number[] {
  const count = Math.min(gains.length, frequencies.length, 32);
  const nameBytes: number[] = [];
  for (let i = 0; i < name.length; i++) {
    const code = name.charCodeAt(i);
    if (code < 0x80) {
      nameBytes.push(code);
    } else if (code < 0x800) {
      nameBytes.push(0xC0 | (code >> 6));
      nameBytes.push(0x80 | (code & 0x3F));
    } else {
      nameBytes.push(0xE0 | (code >> 12));
      nameBytes.push(0x80 | ((code >> 6) & 0x3F));
      nameBytes.push(0x80 | (code & 0x3F));
    }
  }
  const payload: number[] = [];
  payload.push(actionType);
  payload.push((minValue << 24) >> 24);
  payload.push((maxValue << 24) >> 24);
  payload.push(eqId);
  payload.push(nameBytes.length);
  for (let k = 0; k < nameBytes.length; k++) payload.push(nameBytes[k]);
  payload.push(count);
  for (let i = 0; i < count; i++) {
    const freq = frequencies[i];
    payload.push(freq & 0xFF);
    payload.push((freq >> 8) & 0xFF);
    const clamped = Math.max(minValue, Math.min(maxValue, gains[i]));
    payload.push((clamped << 24) >> 24);
  }
  return payload;
}

/**
 * 新建自定义 EQ 预设载荷（cmd 0x0418, actionType=1）。
 * 移植自 C# OppoProtocol.EqDetailPayload()
 */
export function buildEqCreatePayload(
  gains: number[],
  frequencies: number[],
  name: string
): number[] {
  return buildEqInfoPayload(1, gains, frequencies, name, 0, -6, 6);
}

/**
 * 更新/应用已有 EQ 预设载荷（cmd 0x0418, actionType=2）。
 * 移植自 C# OppoProtocol.EqUpdatePayload()
 */
export function buildEqUpdatePayload(entry: EqInfoEntry): number[] {
  return buildEqInfoPayload(
    2, entry.gains, entry.frequencies, entry.name,
    entry.eqId, entry.minValue, entry.maxValue
  );
}

/**
 * 删除设备端 EQ 预设载荷（cmd 0x0418, actionType=3）。
 * 移植自 C# OppoProtocol.EqDeletePayload()
 */
export function buildEqDeletePayload(eqId: number): number[] {
  return [3, 0xFA, 0x06, eqId, 0];
}
