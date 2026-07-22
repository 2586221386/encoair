/**
 * OPPO 私有协议响应解析器
 * 移植自 OppoPodsManager-main:
 *   - Services/PodManager.Parsing.cs
 *   - Services/PodManager.cs (DispatchFrame)
 *
 * 将所有 parseXxx 方法从 OppoEarphoneManager 中提取为独立模块，
 * 每个方法为纯函数风格，只接收原始帧数据和必要参数，返回解析结果。
 */

import {
  CmdBatteryResp, CmdActiveReport, CmdAncResp,
  CmdBatchQueryResp, CmdSpatialAudioResp, CmdSetFeatureResp,
  CmdEqResp, CmdEqNotify, CmdProductIdResp, CmdCapabilityResp,
  CmdQueryVolumeValueResp, CmdSetVolumeValueResp,
  EvtBattery, EvtEarBudsStatus, EvtNoiseMode,
  extractCmd, extractPayload, PROTOCOL_HEADER
} from './OppoProtocol';

// ============== 本地类型定义 ==============

/** 佩戴状态值枚举 */
export enum ParserWearState {
  DISCONNECTED = 0x00,
  IN_CASE = 0x04,
  REMOVED = 0x05,
  WEARING = 0x07
}

/** 佩戴状态数据模型 */
export interface ParserWearStatus {
  left: ParserWearState | null;
  right: ParserWearState | null;
  case: ParserWearState | null;
}

// ============== 导出类型定义 ==============

/** 电池解析结果 */
export interface BatteryParseResult {
  leftBattery: number;
  leftCharging: boolean;
  rightBattery: number;
  rightCharging: boolean;
  caseBattery: number;
  caseCharging: boolean;
}

/** ANC 解析结果 */
export interface AncParseResult {
  mode: number;
}

/** 功能标志解析结果 */
export interface FeatureFlagsResult {
  gameMode?: boolean;
  spatialMode?: boolean;
  dualDevice?: boolean;
  /** 所有 feature→value 的完整映射（供 ResolveGameModeProtocol 动态决策） */
  features: Map<number, number>;
}

/** 空间音频解析结果 */
export interface SpatialAudioResult {
  mode: number;
}

/** 功能开关响应解析结果 */
export interface SwitchFeatureResult {
  feature: number;
  enabled: boolean;
}

/** EQ 预设解析结果 */
export interface EqPresetResult {
  presetId: number;
}

/** 固件版本解析结果 */
export interface FirmwareVersionResult {
  version: string;
}

/** 编解码器解析结果 */
export interface CodecTypeResult {
  codec: number;
}

/** 音量解析结果 */
export interface VolumeResult {
  value: number;
}

/** 游戏音效解析结果 */
export interface GameSoundResult {
  enabled: boolean;
  selectType: number;
}

// ============== 响应解析器 ==============

export class ResponseParser {
  /**
   * 解析电量数据
   * 支持两种命令：
   *   - 0x8106 (查询响应): [index,len]... 每个条目 [component(1)][battery(1)]
   *   - 0x0204 type=0x01 (主动上报): [reportType(1)][count(1)][component,battery]...
   *
   * battery 字节编码: bit6-0=电量, bit7=充电标志
   */
  static parseBattery(data: Uint8Array): BatteryParseResult | null {
    if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return null;
    const cmd = extractCmd(data);
    if (cmd !== CmdBatteryResp && cmd !== CmdActiveReport) return null;

    const frame = extractPayload(data);
    if (!frame) return null;

    const start = frame.start;
    const payLen = frame.len;
    let result: Partial<BatteryParseResult> = {};
    let updated = false;

    if (cmd === CmdBatteryResp) {
      // 0x8106 格式: [component(1)][battery(1)]... (battery: bit6-0=电量, bit7=充电)
      let i = start;
      while (i + 1 < start + payLen) {
        const component = data[i];
        const rawValue = data[i + 1];
        const battery = rawValue & 0x7F;
        const charging = (rawValue & 0x80) !== 0;
        if (battery >= 0 && battery <= 100) {
          ResponseParser.applyBatteryComponent(result, component, battery, charging);
          updated = true;
        }
        i += 2;
      }
    } else if (cmd === CmdActiveReport) {
      // 0x0204 type=0x01 格式: [subType(1)][count(1)][component,battery]...
      if (payLen < 2) return null;
      const reportType = data[start];
      if (reportType !== EvtBattery) return null;
      const count = data[start + 1];
      if (payLen < 2 + count * 2) return null;

      for (let j = 0; j < count; j++) {
        const idx = start + 2 + j * 2;
        const component = data[idx];
        const rawValue = data[idx + 1];
        const battery = rawValue & 0x7F;
        const charging = (rawValue & 0x80) !== 0;
        if (battery >= 0 && battery <= 100) {
          ResponseParser.applyBatteryComponent(result, component, battery, charging);
          updated = true;
        }
      }
    }

    if (!updated) return null;
    return {
      leftBattery: result.leftBattery ?? -1,
      leftCharging: result.leftCharging ?? false,
      rightBattery: result.rightBattery ?? -1,
      rightCharging: result.rightCharging ?? false,
      caseBattery: result.caseBattery ?? -1,
      caseCharging: result.caseCharging ?? false,
    };
  }

  private static applyBatteryComponent(
    result: Partial<BatteryParseResult>,
    component: number,
    battery: number,
    charging: boolean
  ): void {
    switch (component) {
      case 0x01:
        result.leftBattery = battery;
        result.leftCharging = charging;
        break;
      case 0x02:
        result.rightBattery = battery;
        result.rightCharging = charging;
        break;
      case 0x03:
        result.caseBattery = battery;
        result.caseCharging = charging;
        break;
    }
  }

  /**
   * 解析 ANC 降噪模式
   * 支持命令：
   *   - 0x810C (查询响应)
   *   - 0x0204 type=0x03 (主动上报)
   *
   * 匹配逻辑: 查找 [0x01, 0x01, val1, val2] 模式
   *   val1=0x08 → 关闭, val1=0x02 → 降噪, val1=0x80/0x40/0x20/0x10 → 智能/轻度/中度/深度
   *   val1=0x04 → 通透, val1=0x00+val2=0x01 → 通透, val1=0x00+val2=0x08 → 自适应
   * @param legacyAnc 是否为旧版 ANC 反转（Air2 Pro等）
   */
  static parseAncMode(data: Uint8Array, legacyAnc: boolean = false): AncParseResult | null {
    if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return null;
    const cmd = extractCmd(data);
    if (cmd !== CmdAncResp && cmd !== CmdActiveReport) return null;

    const frame = extractPayload(data);
    if (!frame) return null;

    const start = frame.start;
    const payLen = frame.len;
    const payloadEnd = start + payLen;

    // 0x0204 时跳过非 ANC 上报类型
    if (cmd === CmdActiveReport && payLen > 0) {
      const reportType = data[start];
      if (reportType === EvtBattery || reportType === EvtEarBudsStatus) return null;
    }

    for (let i = start; i < payloadEnd - 2; i++) {
      if (data[i] === 0x01 && data[i + 1] === 0x01) {
        const val1 = data[i + 2];
        const val2 = (i + 3 < payloadEnd) ? data[i + 3] : 0x00;

        let mode = 1;
        if (val1 === 0x08 && val2 === 0x00) mode = 1;
        else if (val1 === 0x80 && val2 === 0x00) mode = 5;
        else if (val1 === 0x40 && val2 === 0x00) mode = 6;
        else if (val1 === 0x20 && val2 === 0x00) mode = 7;
        else if (val1 === 0x10 && val2 === 0x00) mode = 8;
        else if (val1 === 0x02 && val2 === 0x00) mode = 2;
        else if (val1 === 0x04 && val2 === 0x00) mode = 3;
        else if (val1 === 0x00 && val2 === 0x01) mode = 3;
        else if (val1 === 0x00 && val2 === 0x08) mode = 4;
        else if (val1 === 0x01 && val2 === 0x00) mode = 1;

        // 旧版 ANC 兼容：接收方向互换
        if (legacyAnc) {
          if (mode === 1) mode = 2;
          else if (mode === 2) mode = 1;
        }

        return { mode };
      }
    }
    return null;
  }

  /**
   * 解析佩戴状态（0x0204 type=0x02）
   * 格式: [subType(1)][count(1)][component(1),value(1)]...
   * component: 0x01=左耳, 0x02=右耳, 0x03=充电仓
   * value: 0x00=断开, 0x04=在仓, 0x05=取出, 0x07=佩戴
   */
  static parseWearStatus(data: Uint8Array): ParserWearStatus | null {
    if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return null;
    const cmd = extractCmd(data);
    if (cmd !== CmdActiveReport) return null;

    const frame = extractPayload(data);
    if (!frame || frame.len < 2) return null;
    const start = frame.start;
    const payLen = frame.len;

    const reportType = data[start];
    if (reportType !== EvtEarBudsStatus) return null;

    const count = data[start + 1];
    if (payLen < 2 + count * 2) return null;

    // 仅从上报数据更新，不修改未上报的组件
    let left: ParserWearState | null = null;
    let right: ParserWearState | null = null;
    let caseState: ParserWearState | null = null;

    for (let j = 0; j < count; j++) {
      const idx = start + 2 + j * 2;
      const component = data[idx];
      const rawVal = data[idx + 1];
      const state = ResponseParser.toWearState(rawVal);
      if (state === null) continue;

      switch (component) {
        case 0x01: left = state; break;
        case 0x02: right = state; break;
        case 0x03: caseState = state; break;
      }
    }

    if (left === null && right === null && caseState === null) return null;

    return {
      left: left,
      right: right,
      case: caseState,
    };
  }

  private static toWearState(value: number): ParserWearState | null {
    switch (value) {
      case 0x00: return ParserWearState.DISCONNECTED;
      case 0x01: return ParserWearState.REMOVED;    // 摘下（C# st==1）
      case 0x03: return ParserWearState.WEARING;     // 佩戴（C# st==3）
      case 0x04: return ParserWearState.IN_CASE;
      case 0x05: return ParserWearState.REMOVED;
      case 0x07: return ParserWearState.WEARING;
      default: return null;
    }
  }

  /**
   * 解析批量功能状态（0x810D）
   * 格式: [feature(1),value(1)]... （feature=0x28=游戏, 0x1B=空间音效, 0x11=双设备）
   */
  static parseFeatureFlags(data: Uint8Array): FeatureFlagsResult | null {
    if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return null;
    const cmd = extractCmd(data);
    if (cmd !== CmdBatchQueryResp) return null;

    const frame = extractPayload(data);
    if (!frame || frame.len < 4) return null;

    const start = frame.start;
    const payLen = frame.len;
    const features: Map<number, number> = new Map();
    const result: FeatureFlagsResult = { features: features };
    let found = false;

    for (let i = start; i < start + payLen - 1; i += 2) {
      const feature = data[i];
      const value = data[i + 1];
      features.set(feature, value);

      if (feature === 0x28) {
        result.gameMode = value === 0x01;
        found = true;
      }
      if (feature === 0x1B) {
        result.spatialMode = value === 0x01;
        found = true;
      }
      if (feature === 0x11) {
        result.dualDevice = value === 0x01;
        found = true;
      }
    }

    return found ? result : null;
  }

  /**
   * 解析空间音频状态
   * 支持命令：
   *   - 0x0510 (主动通知): payload[0]=mode
   *   - 0x8422 (设置响应): payload[0]=mode
   *   - 0x8403 feature=0x1B: payload[feature,value]
   */
  static parseSpatialAudio(data: Uint8Array): SpatialAudioResult | null {
    if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return null;
    const cmd = extractCmd(data);

    const frame = extractPayload(data);
    if (!frame || frame.len < 1) return null;
    const start = frame.start;
    const payLen = frame.len;

    // 0x0510 主动通知
    if (cmd === 0x0510) {
      const mode = data[start];
      return { mode: Math.max(0, Math.min(2, mode)) };
    }

    // 0x8422 空间音频设置响应
    if (cmd === CmdSpatialAudioResp) {
      const mode = data[start];
      return { mode: Math.max(0, Math.min(2, mode)) };
    }

    // 0x8403 特征开关响应（feature 0x1B）
    if (cmd === CmdSetFeatureResp && payLen >= 2) {
      for (let i = start; i < start + payLen - 1; i++) {
        if (data[i] === 0x1B) {
          const enabled = data[i + 1] === 0x01;
          return { mode: enabled ? 1 : 0 };
        }
      }
    }

    return null;
  }

  /**
   * 解析功能设置响应（0x8403）
   * 目前处理双设备连接 feature 0x11
   */
  static parseSwitchFeatureResponse(data: Uint8Array): SwitchFeatureResult | null {
    if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return null;
    const cmd = extractCmd(data);
    if (cmd !== CmdSetFeatureResp) return null;

    const frame = extractPayload(data);
    if (!frame || frame.len < 2) return null;
    const start = frame.start;
    const payLen = frame.len;

    for (let i = start; i < start + payLen - 1; i++) {
      if (data[i] === 0x11) {
        return { feature: 0x11, enabled: data[i + 1] === 0x01 };
      }
    }
    return null;
  }

  /**
   * 解析 EQ 预设
   * 支持命令：
   *   - 0x810F (查询响应): [status(1)][preset(1)]
   *   - 0x0504 (主动通知): [preset(1)]
   */
  static parseEqPreset(data: Uint8Array, validPresets?: number[]): EqPresetResult | null {
    if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return null;
    const cmd = extractCmd(data);

    const frame = extractPayload(data);
    if (!frame) return null;
    const start = frame.start;
    const payLen = frame.len;

    let presetId: number = -1;

    if (cmd === CmdEqNotify && payLen >= 1) {
      // 0x0504 主动通知
      presetId = data[start];
    } else if (cmd === CmdEqResp && payLen >= 2) {
      // 0x810F 查询响应
      const status = data[start];
      if (status === 0x00) {
        presetId = data[start + 1];
      }
    } else {
      return null;
    }

    if (presetId >= 0 && (!validPresets || validPresets.includes(presetId))) {
      return { presetId };
    }
    return null;
  }

  /**
   * 解析产品ID响应（0x8103）
   * 格式: [status(1)][productId(3 LE)]
   * @returns 6位大写十六进制字符串，如 "0C2102"
   */
  static parseProductId(data: Uint8Array): string | null {
    if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return null;
    const cmd = extractCmd(data);
    if (cmd !== CmdProductIdResp) return null;

    const frame = extractPayload(data);
    if (!frame || frame.len !== 4) return null;

    const status = data[frame.start];
    if (status !== 0) return null;

    const id = data[frame.start + 1] + data[frame.start + 2] * 256 + data[frame.start + 3] * 65536;
    return id.toString(16).toUpperCase().padStart(6, '0');
  }

  /**
   * 解析能力位图响应（0x8100）
   * 格式: [status(1)][bitmap...]
   * @returns 位图字节数组或 null
   */
  static parseCapabilityBitmap(data: Uint8Array): Uint8Array | null {
    if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return null;
    const cmd = extractCmd(data);
    if (cmd !== CmdCapabilityResp) return null;

    const frame = extractPayload(data);
    if (!frame || frame.len <= 1) return null;

    const status = data[frame.start];
    if (status !== 0) return null;

    return data.slice(frame.start + 1, frame.start + frame.len);
  }

  /**
   * 解析固件版本响应（0x8105）
   * 格式: [status(1)][n(1)][UTF-8 CSV] — 逗号分隔的数字字段
   * CSV 包含类型/主/次版本分组，提取 >= 100 的数值为主版本号，用点拼接
   * 例: "1,2,158,2,2,158,3,1,01,3,2,105" → "158.158.105"
   */
  static parseFirmwareVersion(data: Uint8Array): FirmwareVersionResult | null {
    if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return null;
    const cmd = extractCmd(data);
    if (cmd !== 0x8105) return null;

    const frame = extractPayload(data);
    if (!frame || frame.len < 3) return null;

    const status = data[frame.start];
    if (status !== 0) return null;

    try {
      // 跳过 status 和 n 字节，读取 CSV 文本
      let text = '';
      for (let i = frame.start + 2; i < frame.start + frame.len; i++) {
        const b = data[i];
        if (b === 0) break;
        if (b >= 32 && b <= 126) {
          text += String.fromCharCode(b);
        }
      }
      text = text.trim();
      if (!text) return null;
      // CSV 格式: type,major,minor,type,major,minor,type,major,minor,...
      // 提取 >= 100 的数值作为主版本号（过滤掉类型/次版本等小数字段）
      const fields = text.split(',');
      const versionParts: string[] = [];
      for (const f of fields) {
        const num = parseInt(f.trim(), 10);
        if (!isNaN(num) && num >= 100) {
          versionParts.push(num.toString());
        }
      }
      if (versionParts.length === 0) return { version: text };
      return { version: versionParts.join('.') };
    } catch (_) {
      return null;
    }
  }

  /**
   * 解析编解码器类型响应（0x8114）
   * 格式: [status(1)][codec(1)] 或 [status(1)][n(1)][id,val]...
   */
  static parseCodecType(data: Uint8Array): CodecTypeResult | null {
    if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return null;
    const cmd = extractCmd(data);
    if (cmd !== 0x8114) return null;

    const frame = extractPayload(data);
    if (!frame || frame.len < 2) return null;

    // 尝试多种格式
    // 格式A [status(1)][codec(1)] — SPP短格式
    if (frame.len >= 2 && data[frame.start] === 0) {
      return { codec: data[frame.start + 1] };
    }
    // 格式B [status(1)][count(1)][id(1)][val(1)]... — GATT长格式
    if (frame.len >= 4 && data[frame.start] === 0) {
      const n = data[frame.start + 1];
      if (n > 0 && frame.len >= 2 + n * 2) {
        for (let i = 0; i < n; i++) {
          if (data[frame.start + 3 + i * 2] !== 0) {
            return { codec: data[frame.start + 2 + i * 2] };
          }
        }
      }
    }

    return null;
  }

  /**
   * 解析游戏音效信息响应（0x812B）
   * 格式: [status(1)][selectType(1)][count(1)][supportTypes...]
   * selectType != 0 → 已开启
   */
  static parseGameSound(data: Uint8Array): GameSoundResult | null {
    if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return null;
    const cmd = extractCmd(data);
    if (cmd !== 0x812B) return null;

    const frame = extractPayload(data);
    if (!frame || frame.len < 2) return null;

    const status = data[frame.start];
    if (status !== 0) return null;

    const selectType = data[frame.start + 1];
    return {
      enabled: selectType !== 0,
      selectType,
    };
  }

  /**
   * 解析音量档位响应（0x8130）
   * 格式: [status(1)][volume(1)]
   */
  static parseVolumeValue(data: Uint8Array): VolumeResult | null {
    if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return null;
    const cmd = extractCmd(data);
    if (cmd !== 0x8130) return null;

    const frame = extractPayload(data);
    if (!frame || frame.len < 1) return null;

    // 格式A [status(1)][volume(1)] — 带status字节
    if (frame.len >= 2 && data[frame.start] === 0) {
      return { value: data[frame.start + 1] };
    }
    // 格式B [volume(1)] — 无status字节，首字节即为音量值
    if (frame.len >= 1) {
      return { value: data[frame.start] };
    }

    return null;
  }

  /**
   * 解析音量设置响应（0x8427）
   * 格式: [status(1)]
   */
  static parseVolumeSetResp(data: Uint8Array): boolean {
    if (data.length < 9 || data[0] !== PROTOCOL_HEADER) return false;
    const cmd = extractCmd(data);
    if (cmd !== 0x8427) return false;

    const frame = extractPayload(data);
    if (!frame || frame.len < 1) return false;

    return data[frame.start] === 0;
  }
}
