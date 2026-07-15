/**
 * 多设备连接协议管理器
 * 移植自 OppoPodsManager-main:
 *   - Protocol/OppoProtocol.MultiDevice.cs (多设备操作载荷构造)
 *   - Protocol/OppoProtocol.cs (多设备命令字定义)
 *   - Services/PodManager.cs (多设备操作入口)
 *   - Services/PodManager.Parsing.cs (ParseMultiConnect / ParseMultiPriority)
 *
 * 负责多设备连接列表查询、解析、操作（连接/断开/取消配对/设置优先级）。
 * 通过回调与 OppoEarphoneManager 的 SPP 传输层解耦。
 */

import { ConnectedDeviceInfo, MultiPriorityInfo, MultiDeviceOpType, MultiDeviceOpResult } from '../common/ConnectedDeviceInfo';

// ============== 多设备协议常量 ==============

/** 查询多设备连接列表 (0x0112) */
const CMD_MULTI_CONNECT_INFO: number = 0x0112;
/** 多设备列表响应 (0x8112) */
const CMD_MULTI_CONNECT_RESP: number = 0x8112;
/** 操作多设备手持设备 (0x0429) */
const CMD_OPERATE_HANDHELD: number = 0x0429;
/** 操作多设备响应 (0x8429) */
const CMD_OPERATE_HANDHELD_RESP: number = 0x8429;
/** 查询多连接优先设备 (0x0132) */
const CMD_QUERY_MULTI_PRIORITY: number = 0x0132;
/** 多连接优先设备响应 (0x8132) */
const CMD_MULTI_PRIORITY_RESP: number = 0x8132;
/** 主动通知事件 (0x0204) */
const CMD_ACTIVE_REPORT: number = 0x0204;
/** 多设备连接状态变更通知子类型 (0x06) */
const EVT_MULTI_CONNECT: number = 0x06;
/** Air5 Pro 移位后的多设备列表响应 (实际 0x8112，因额外 status 字节右移 1 位) */
const CMD_MULTI_CONNECT_RESP_SHIFTED: number = 0x1200;
/** 设置关联设备信息 (0x0408) */
const CMD_SET_RELATED_DEVICE: number = 0x0408;
/** 双设备连接 feature (0x11) */
const FEATURE_DUAL_DEVICE: number = 0x11;
/** 功能开关设置 (0x0403) */
const CMD_SET_FEATURE: number = 0x0403;

// ============== 回调类型定义 ==============

/** 发送数据包的回调函数类型 */
export type SendPacketCallback = (packet: Uint8Array) => void;

/** 多设备列表变化回调 */
export type MultiDeviceListCallback = (devices: ConnectedDeviceInfo[]) => void;

/** 多设备优先状态变化回调 */
export type MultiPriorityCallback = (info: MultiPriorityInfo) => void;

/** 双设备开关状态变化回调 */
export type DualDeviceToggleCallback = (enabled: boolean) => void;

/** 多设备操作结果回调 */
export type MultiDeviceOpCallback = (result: MultiDeviceOpResult, message: string) => void;

// ============== 协议载荷构造 ==============

/**
 * 将 "AA:BB:CC:DD:EE:FF" 格式 MAC 地址解析为 6 字节数组（正序）
 * 对应 C# OppoProtocol.ParseMac()
 */
function parseMac(address: string): Uint8Array {
  const mac = new Uint8Array(6);
  if (!address) {
    return mac;
  }
  const parts = address.split(':');
  for (let i = 0; i < 6 && i < parts.length; i++) {
    try {
      mac[i] = parseInt(parts[i], 16);
    } catch (e) {
      mac[i] = 0;
    }
  }
  return mac;
}

/**
 * 构造多设备操作载荷 (cmd 0x0429)
 * 对应 C# OppoProtocol.MultiConnectOpPayload()
 *
 * operateType 1/2/3: [type(1)][addr(6)]，MAC 按显示顺序正序写入
 * operateType 4 (设置音频优先设备):
 *   - clearAddress=true (恢复自动切换): [04][00]
 *   - clearAddress=false (指定某设备): [04][01][addr(6)]
 */
function buildMultiConnectOpPayload(operateType: number, targetAddress: string, clearAddress: boolean = false): Uint8Array {
  if (operateType === MultiDeviceOpType.SET_PRIORITY) {
    if (clearAddress) {
      return new Uint8Array([operateType, 0x00]);
    } else {
      const mac = parseMac(targetAddress);
      const payload = new Uint8Array(8);
      payload[0] = operateType;
      payload[1] = 0x01;
      payload.set(mac, 2);
      return payload;
    }
  } else {
    const mac = parseMac(targetAddress);
    const payload = new Uint8Array(7);
    payload[0] = operateType;
    payload.set(mac, 1);
    return payload;
  }
}

/**
 * 构造 OPPO 协议帧
 * 对应 C# OppoProtocol.BuildPacket()
 */
function buildPacket(cmd: number, payload: Uint8Array = new Uint8Array(0)): Uint8Array {
  const payLen = payload.length;
  const totalLen = 7 + payLen;
  const packet = new Uint8Array(2 + totalLen);
  packet[0] = 0xAA;        // Header
  packet[1] = totalLen;    // Length
  packet[2] = 0x00;        // Reserved
  packet[3] = 0x00;        // Reserved
  packet[4] = cmd & 0xFF;  // Cmd Low
  packet[5] = (cmd >> 8) & 0xFF; // Cmd High
  packet[6] = 0xF0;        // Seq
  packet[7] = payLen & 0xFF;
  packet[8] = (payLen >> 8) & 0xFF;
  for (let i = 0; i < payLen; i++) {
    packet[9 + i] = payload[i];
  }
  return packet;
}

// ============== 响应解析 ==============

/**
 * 解析多设备连接列表响应 - 带显式偏移（供 Air5 Pro 移位响应使用）
 * @param data 原始数据帧
 * @param payloadStart payload 起始位置
 * @param payLen payload 长度
 */
export function parseMultiConnectResponseWithOffset(data: Uint8Array, payloadStart: number, payLen: number): ConnectedDeviceInfo[] {
  const devices: ConnectedDeviceInfo[] = [];

  if (data.length < payloadStart + payLen || payLen < 2) {
    return devices;
  }

  const count = data[payloadStart + 1]; // payload[1] = count
  if (count <= 0 || count > 8) {
    console.info(`[MultiDevice] parseMultiConnectWithOffset: invalid count=${count}`);
    return devices;
  }

  let pos = payloadStart + 2;
  const endPos = payloadStart + payLen;

  for (let i = 0; i < count && pos + 8 < endPos; i++) {
    const entryStart = pos;

    // MAC 以小端(倒序)传输，需反转为显示序
    const macParts: string[] = [];
    for (let j = 0; j < 6; j++) {
      macParts.push(data[pos + 5 - j].toString(16).toUpperCase().padStart(2, '0'));
    }
    const addr = macParts.join(':');
    pos += 6;

    const elemByte6 = data[pos++];
    const connState = data[pos++];
    const flag = data[pos++];
    const nameLen = data[pos++];

    if (nameLen < 0 || pos + nameLen > endPos) {
      console.info(`[MultiDevice] parseMultiConnectWithOffset: device[${i}] invalid nameLen=${nameLen}`);
      break;
    }

    let deviceName = '';
    if (nameLen > 0) {
      try {
        const nameBytes = data.slice(pos, pos + nameLen);
        deviceName = decodeUtf8(nameBytes);
      } catch (e) {
        deviceName = '';
      }
    }
    if (!deviceName) {
      deviceName = 'Device ' + addr.substring(Math.max(0, addr.length - 5));
    }
    pos += Math.max(nameLen, 0);

    const entryLen = pos - entryStart;
    const rawEntry = new Uint8Array(entryLen);
    for (let k = 0; k < entryLen; k++) {
      rawEntry[k] = data[entryStart + k];
    }

    const isCurrentDevice = (flag & 0x01) !== 0;
    const isMainAudio = (flag & 0x02) !== 0;
    const isAudioActive = (flag & 0x04) !== 0;
    // 注意：flag bit3-5 的设备类型编码不可靠，与 C# 一致默认 0（手机）

    const deviceInfo = new ConnectedDeviceInfo();
    deviceInfo.address = addr;
    deviceInfo.deviceName = deviceName;
    deviceInfo.connectionState = connState;
    deviceInfo.isCurrentDevice = isCurrentDevice;
    deviceInfo.isMainAudioDevice = isMainAudio;
    deviceInfo.isAudioActive = isAudioActive;
    deviceInfo.rawEntryBytes = rawEntry;
    deviceInfo.elemByte6 = elemByte6;

    devices.push(deviceInfo);

    console.info(`[MultiDevice] device[${i}]: addr=${addr}, name="${deviceName}", ` +
      `connState=${connState}, flag=0x${flag.toString(16)}, cur=${isCurrentDevice}`);
  }

  devices.sort((a, b) => {
    if (a.isCurrentDevice !== b.isCurrentDevice) {
      return a.isCurrentDevice ? -1 : 1;
    }
    return a.deviceName.localeCompare(b.deviceName);
  });

  console.info(`[MultiDevice] parseMultiConnectWithOffset: ${devices.length} 个设备`);
  return devices;
}

/**
 * 解析多设备连接列表响应 (0x8112) - 标准格式
 * 对应 C# PodManager.ParseMultiConnect()
 *
 * 响应格式:
 *   [count(1)][device0][device1]...
 *   每个 device: [macLE(6)][elemByte6(1)][connState(1)][flag(1)][nameLen(1)][nameUTF8(nameLen)]
 *
 * flag bit 定义:
 *   bit0 (0x01) = isCurrentDevice (当前运行本程序的设备)
 *   bit1 (0x02) = isMainAudioDevice (主音频通道设备)
 *   bit2 (0x04) = isAudioActive (当前正在输出音频)
 *   bit3-5 = deviceType (0=手机 1=电脑 2=平板 3=手表)
 */
export function parseMultiConnectResponse(data: Uint8Array): ConnectedDeviceInfo[] {
  const devices: ConnectedDeviceInfo[] = [];

  if (data.length < 9 || data[0] !== 0xAA) {
    return devices;
  }

  const payLen = (data[7] | (data[8] << 8));
  const start = 9;

  if (data.length < start + payLen || payLen < 2) {
    return devices;
  }

  const count = data[start + 1]; // payload[1] = count
  if (count <= 0 || count > 8) {
    console.info(`[MultiDevice] parseMultiConnect: invalid count=${count}`);
    return devices;
  }

  let pos = start + 2; // skip count byte
  for (let i = 0; i < count && pos + 8 < start + payLen; i++) {
    const entryStart = pos;

    // MAC 以小端(倒序)传输，需反转为显示序 "AA:BB:CC:DD:EE:FF"
    const macParts: string[] = [];
    for (let j = 0; j < 6; j++) {
      macParts.push(data[pos + 5 - j].toString(16).toUpperCase().padStart(2, '0'));
    }
    const addr = macParts.join(':');
    pos += 6;

    const elemByte6 = data[pos++];
    const connState = data[pos++];
    const flag = data[pos++];
    const nameLen = data[pos++];

    if (nameLen < 0 || pos + nameLen > start + payLen) {
      console.info(`[MultiDevice] parseMultiConnect: device[${i}] invalid nameLen=${nameLen}`);
      break;
    }

    let deviceName = '';
    if (nameLen > 0) {
      // UTF-8 解码设备名
      try {
        const nameBytes = data.slice(pos, pos + nameLen);
        deviceName = decodeUtf8(nameBytes);
      } catch (e) {
        deviceName = '';
      }
    }
    if (!deviceName) {
      deviceName = 'Device ' + addr.substring(Math.max(0, addr.length - 5));
    }
    pos += Math.max(nameLen, 0);

    // 保存原始条目字节
    const entryLen = pos - entryStart;
    const rawEntry = new Uint8Array(entryLen);
    for (let k = 0; k < entryLen; k++) {
      rawEntry[k] = data[entryStart + k];
    }

    // 解析 flag 位
    const isCurrentDevice = (flag & 0x01) !== 0;
    const isMainAudio = (flag & 0x02) !== 0;
    const isAudioActive = (flag & 0x04) !== 0;
    
    const deviceInfo = new ConnectedDeviceInfo();
    deviceInfo.address = addr;
    deviceInfo.deviceName = deviceName;
    deviceInfo.connectionState = connState;
    deviceInfo.isCurrentDevice = isCurrentDevice;
    deviceInfo.isMainAudioDevice = isMainAudio;
    deviceInfo.isAudioActive = isAudioActive;
    deviceInfo.rawEntryBytes = rawEntry;
    deviceInfo.elemByte6 = elemByte6;
    
    devices.push(deviceInfo);
    
    console.info(`[MultiDevice] device[${i}]: addr=${addr}, name="${deviceName}", ` +
      `connState=${connState}, flag=0x${flag.toString(16)}, cur=${isCurrentDevice}, ` +
      `mainAudio=${isMainAudio}, audioActive=${isAudioActive}`);
  }

  // 排序：当前设备优先，再按名称排序
  devices.sort((a, b) => {
    if (a.isCurrentDevice !== b.isCurrentDevice) {
      return a.isCurrentDevice ? -1 : 1;
    }
    return a.deviceName.localeCompare(b.deviceName);
  });

  console.info(`[MultiDevice] parseMultiConnect: ${devices.length} 个设备: ` +
    devices.map(d => d.getDisplayName()).join(', '));

  return devices;
}

/**
 * 解析多连接优先设备响应 (0x8132)
 * 对应 C# PodManager.ParseMultiPriority()
 *
 * 响应格式: [status(1)][level(1)][modeByte(1)][addrLE(6)?]
 *   level=2 且 modeByte=0 → autoMode=true
 *   level=2 且 modeByte≠0 → autoMode=false, priorityAddr 由后面 6 字节 MAC 提供
 *   level≠2 且 modeByte≠0 → priorityAddr 由后面 6 字节 MAC 提供
 */
export function parseMultiPriorityResponse(data: Uint8Array): MultiPriorityInfo | null {
  const info = new MultiPriorityInfo();

  if (data.length < 9 || data[0] !== 0xAA) {
    console.info('[MultiDevice] parseMultiPriority: 帧头校验失败');
    return null;
  }

  const payLen = (data[7] | (data[8] << 8));
  const start = 9;

  console.info(`[MultiDevice] parseMultiPriority: payLen=${payLen}, payload[0]=0x${data.length > start ? data[start].toString(16) : '??'}, ` +
    `payload[1]=0x${data.length > start + 1 ? data[start + 1].toString(16) : '??'}`);

  if (data.length < start + payLen) {
    console.info(`[MultiDevice] parseMultiPriority: 帧长度不足 dataLen=${data.length} need=${start + payLen}`);
    return null;
  }

  // Air5 Pro 等设备 payLen=2 格式: [level(1)][modeByte(1)]（无 status 字节）
  // 标准格式 payLen>=3: [status(1)][level(1)][modeByte(1)][addrLE(6)?]
  let level: number;
  let modeByte: number;

  if (payLen === 2) {
    // Air5 Pro 紧凑格式：无 status 字节
    level = data[start];
    modeByte = data[start + 1];
    console.info(`[MultiDevice] parseMultiPriority: Air5 Pro 紧凑格式 level=${level} modeByte=0x${modeByte.toString(16)}`);
  } else if (payLen >= 3) {
    // 标准格式：有 status 字节
    const statusByte = data[start];
    if (statusByte !== 0) {
      console.info(`[MultiDevice] parseMultiPriority: status=0x${statusByte.toString(16)} (非零但仍尝试解析)`);
    }
    level = data[start + 1];
    modeByte = data[start + 2];
  } else {
    console.info(`[MultiDevice] parseMultiPriority: payLen=${payLen} 过小，无法解析`);
    return null;
  }
  let autoMode = false;
  let priorityAddr = '';
  const isHighLevel = level === 2;

  if (isHighLevel) {
    if (payLen >= 9) {
      // 有完整地址数据时才能可靠判断 auto/manual
      autoMode = modeByte === 0;
      if (!autoMode) {
        const macParts: string[] = [];
        for (let j = 0; j < 6; j++) {
          macParts.push(data[start + 3 + 5 - j].toString(16).toUpperCase().padStart(2, '0'));
        }
        priorityAddr = macParts.join(':');
      }
    } else {
      // payLen<9 时无地址数据，保持之前状态不变（不覆盖乐观更新）
      console.info('[MultiDevice] 紧凑格式无地址，保持现有 autoMode 不变');
      return null; // 返回 null 让调用方不更新状态
    }
  } else {
    if (modeByte !== 0 && payLen >= 9) {
      const macParts: string[] = [];
      for (let j = 0; j < 6; j++) {
        macParts.push(data[start + 3 + 5 - j].toString(16).toUpperCase().padStart(2, '0'));
      }
      priorityAddr = macParts.join(':');
    }
  }

  info.autoMode = autoMode;
  info.priorityAddress = priorityAddr;
  info.level = level;

  console.info(`[MultiDevice] parseMultiPriority: level=${level} high=${isHighLevel} auto=${autoMode} addr="${priorityAddr}"`);

  return info;
}

/**
 * UTF-8 字节解码为字符串
 */
function decodeUtf8(bytes: Uint8Array): string {
  // 手动 UTF-8 解码（避免依赖 TextDecoder 在部分鸿蒙设备不可用）
  let result = '';
  let i = 0;
  while (i < bytes.length) {
    const b = bytes[i];
    if (b < 0x80) {
      // 单字节 ASCII
      result += String.fromCharCode(b);
      i += 1;
    } else if ((b & 0xE0) === 0xC0) {
      // 双字节
      if (i + 1 < bytes.length) {
        const code = ((b & 0x1F) << 6) | (bytes[i + 1] & 0x3F);
        result += String.fromCharCode(code);
        i += 2;
      } else {
        i += 1;
      }
    } else if ((b & 0xF0) === 0xE0) {
      // 三字节
      if (i + 2 < bytes.length) {
        const code = ((b & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F);
        result += String.fromCharCode(code);
        i += 3;
      } else {
        i += 1;
      }
    } else {
      i += 1; // 跳过无效字节
    }
  }
  // 去除尾部的 null 字符
  return result.replace(/\0/g, '').trim();
}

// ============== 多设备管理器 ==============

/**
 * 多设备连接管理器
 * 负责多设备协议操作和状态管理，与 OppoEarphoneManager 的 SPP 传输层协作。
 *
 * 使用方式:
 *   const multiDev = new MultiDeviceManager((pkt) => manager.sendRawPacket(pkt));
 *   multiDev.onDeviceListChanged = (devices) => { ... };
 *   multiDev.queryDeviceList();
 *   multiDev.connectDevice("AA:BB:CC:DD:EE:FF");
 */
export class MultiDeviceManager {
  /** 发送数据包的回调（由外部注入 SPP 发送能力） */
  private sendPacket: SendPacketCallback;

  /** 当前多设备列表 */
  private deviceList: ConnectedDeviceInfo[] = [];

  /** 当前优先设备信息 */
  private priorityInfo: MultiPriorityInfo = new MultiPriorityInfo();

  /** 双设备连接开关状态 */
  private dualDeviceEnabled: boolean = false;

  /** 是否支持双设备连接 */
  private hasDualDevice: boolean = false;

  /** 是否支持多连接管理（优先级/自动切换） */
  private hasMultiConnectManage: boolean = false;

  /** 设备列表变化回调 */
  onDeviceListChanged: MultiDeviceListCallback | null = null;

  /** 优先设备状态变化回调 */
  onPriorityChanged: MultiPriorityCallback | null = null;

  /** 双设备开关状态变化回调 */
  onDualDeviceToggleChanged: DualDeviceToggleCallback | null = null;

  /** 多设备操作结果回调 */
  onOperationResult: MultiDeviceOpCallback | null = null;

  constructor(sendPacket: SendPacketCallback) {
    this.sendPacket = sendPacket;
  }

  /**
   * 设置设备能力标志
   * 在 OppoEarphoneManager 检测完设备能力后调用
   */
  setCapabilities(hasDualDevice: boolean, hasMultiConnectManage: boolean): void {
    this.hasDualDevice = hasDualDevice;
    this.hasMultiConnectManage = hasMultiConnectManage;
  }

  /**
   * 获取当前设备列表
   */
  getDeviceList(): ConnectedDeviceInfo[] {
    return this.deviceList;
  }

  /**
   * 获取当前优先设备信息
   */
  getPriorityInfo(): MultiPriorityInfo {
    return this.priorityInfo;
  }

  /**
   * 获取双设备开关状态
   */
  isDualDeviceEnabled(): boolean {
    return this.dualDeviceEnabled;
  }

  /**
   * 判断命令字是否属于多设备协议
   * 由 OppoEarphoneManager 的 sppRead 回调调用，用于路由响应到正确的解析器
   */
  isMultiDeviceCommand(cmd: number): boolean {
    return cmd === CMD_MULTI_CONNECT_RESP ||
           cmd === CMD_MULTI_PRIORITY_RESP ||
           cmd === CMD_OPERATE_HANDHELD_RESP ||
           (cmd === CMD_ACTIVE_REPORT);
  }

  /**
   * 处理传入的协议响应数据
   * 由 OppoEarphoneManager 的 sppRead 回调调用
   * @param data 原始数据帧
   * @returns 如果数据被处理返回 true，否则返回 false
   */
  handleResponse(data: Uint8Array): boolean {
    if (data.length < 9 || data[0] !== 0xAA) {
      return false;
    }

    const cmdLow = data[4];
    const cmdHigh = data[5];
    const cmd = cmdLow | (cmdHigh << 8);
    const payLen = (data[7] | (data[8] << 8));
    const start = 9;

    switch (cmd) {
      case CMD_MULTI_CONNECT_RESP:
        // 0x8112: 多设备列表响应（标准格式）
        this.handleMultiConnectResponse(data);
        return true;

      case CMD_MULTI_CONNECT_RESP_SHIFTED:
        // 0x1200: Air5 Pro 移位后的 0x8112（额外 status 字节导致 cmd 右移）
        // 实际 cmd 位于 data[5-6]，payLen 位于 data[8-9]，payload 从 data[10] 开始
        console.info('[MultiDevice] 检测到 Air5 Pro 移位响应(0x1200→0x8112)，按+1偏移解析');
        this.handleShiftedMultiConnectResponse(data);
        return true;

      case CMD_MULTI_PRIORITY_RESP:
        // 0x8132: 多连接优先设备响应
        this.handleMultiPriorityResponse(data);
        return true;

      case CMD_OPERATE_HANDHELD_RESP:
        // 0x8429: 多设备操作响应
        this.handleOperateResponse(data);
        return true;

      case CMD_ACTIVE_REPORT:
        // 0x0204: 主动通知 - 检查是否为多连接状态变更
        if (payLen > 0 && data[start] === EVT_MULTI_CONNECT) {
          console.info('[MultiDevice] 收到多连接状态变更通知，刷新设备列表');
          this.queryDeviceList();
          return true;
        }
        return false;

      default:
        return false;
    }
  }

  /**
   * 处理功能状态响应中的双设备开关 (0x810D 或 0x8403)
   * 由 OppoEarphoneManager 的 parseFeatureFlags 等调用
   */
  handleDualDeviceFeature(value: number): void {
    const enabled = value === 0x01;
    if (this.dualDeviceEnabled !== enabled) {
      this.dualDeviceEnabled = enabled;
      if (this.onDualDeviceToggleChanged) {
        this.onDualDeviceToggleChanged(enabled);
      }
      console.info(`[MultiDevice] 双设备连接: ${enabled ? '开启' : '关闭'}`);
    }
  }

  // ============== 查询 ==============

  /**
   * 查询多设备连接列表 (cmd 0x0112)
   */
  queryDeviceList(): void {
    if (!this.hasDualDevice) {
      console.info('[MultiDevice] 设备不支持双设备连接，跳过查询');
      return;
    }
    console.info('[MultiDevice] 查询多设备连接列表');
    const packet = buildPacket(CMD_MULTI_CONNECT_INFO);
    this.sendPacket(packet);
  }

  /**
   * 查询多连接优先设备 (cmd 0x0132)
   */
  queryPriorityDevice(): void {
    if (!this.hasMultiConnectManage) {
      console.info('[MultiDevice] 设备不支持多连接管理，跳过优先设备查询');
      return;
    }
    console.info('[MultiDevice] 查询多连接优先设备');
    const packet = buildPacket(CMD_QUERY_MULTI_PRIORITY);
    this.sendPacket(packet);
  }

  // ============== 操作 ==============

  /**
   * 连接指定手持设备 (cmd 0x0429, type=0x01)
   * @param targetAddress 目标设备 MAC 地址
   */
  connectDevice(targetAddress: string): void {
    if (!this.hasDualDevice) {
      return;
    }
    console.info(`[MultiDevice] 多设备操作: 连接 addr=${targetAddress}`);
    const payload = buildMultiConnectOpPayload(MultiDeviceOpType.CONNECT, targetAddress);
    const packet = buildPacket(CMD_OPERATE_HANDHELD, payload);
    this.sendPacket(packet);
  }

  /**
   * 断开指定手持设备连接 (cmd 0x0429, type=0x02)
   * @param targetAddress 目标设备 MAC 地址
   */
  disconnectDevice(targetAddress: string): void {
    if (!this.hasDualDevice) {
      return;
    }
    console.info(`[MultiDevice] 多设备操作: 断开 addr=${targetAddress}`);
    const payload = buildMultiConnectOpPayload(MultiDeviceOpType.DISCONNECT, targetAddress);
    const packet = buildPacket(CMD_OPERATE_HANDHELD, payload);
    this.sendPacket(packet);
  }

  /**
   * 取消指定设备的配对 (cmd 0x0429, type=0x03)
   * @param targetAddress 目标设备 MAC 地址
   */
  unpairDevice(targetAddress: string): void {
    if (!this.hasDualDevice) {
      return;
    }
    console.info(`[MultiDevice] 多设备操作: 取消配对 addr=${targetAddress}`);
    const payload = buildMultiConnectOpPayload(MultiDeviceOpType.UNPAIR, targetAddress);
    const packet = buildPacket(CMD_OPERATE_HANDHELD, payload);
    this.sendPacket(packet);
  }

  /**
   * 设置指定设备为音频优先设备 (cmd 0x0429, type=0x04, clearAddress=false)
   * @param targetAddress 目标设备 MAC 地址
   */
  setPriorityDevice(targetAddress: string): void {
    if (!this.hasDualDevice) {
      return;
    }
    console.info(`[MultiDevice] 多设备操作: 设为优先设备 addr=${targetAddress}`);
    const payload = buildMultiConnectOpPayload(MultiDeviceOpType.SET_PRIORITY, targetAddress, false);
    const packet = buildPacket(CMD_OPERATE_HANDHELD, payload);
    this.sendPacket(packet);
    // 乐观更新：立即显示手动优先模式
    this.priorityInfo.autoMode = false;
    this.priorityInfo.priorityAddress = targetAddress;
    if (this.onPriorityChanged) {
      this.onPriorityChanged(this.priorityInfo);
    }
  }

  /**
   * 恢复自动切换模式 (cmd 0x0429, type=0x04, clearAddress=true)
   * 清除手动优先设备，交回耳机自动决定音频输出
   */
  restoreAutoSwitch(): void {
    if (!this.hasDualDevice) {
      return;
    }
    console.info('[MultiDevice] 多设备操作: 恢复自动切换');
    const payload = buildMultiConnectOpPayload(MultiDeviceOpType.SET_PRIORITY, '', true);
    const packet = buildPacket(CMD_OPERATE_HANDHELD, payload);
    this.sendPacket(packet);
    // 乐观更新：立即设置 autoMode，确保 UI 即时反映
    this.priorityInfo.autoMode = true;
    this.priorityInfo.priorityAddress = '';
    if (this.onPriorityChanged) {
      this.onPriorityChanged(this.priorityInfo);
    }
  }

  /**
   * 设置双设备连接开关 (cmd 0x0403, feature=0x11)
   * @param enabled 是否开启
   */
  setDualDeviceEnabled(enabled: boolean): void {
    if (!this.hasDualDevice) {
      return;
    }
    console.info(`[MultiDevice] 设置双设备连接: ${enabled ? '开启' : '关闭'}`);
    const payload = new Uint8Array([FEATURE_DUAL_DEVICE, enabled ? 0x01 : 0x00]);
    const packet = buildPacket(CMD_SET_FEATURE, payload);
    this.sendPacket(packet);
  }

  // ============== 内部响应处理 ==============

  /**
   * HEX 数据片段转字符串（用于诊断日志）
   */
  private hexDump(data: Uint8Array, start: number, len: number): string {
    const parts: string[] = [];
    const end = Math.min(start + len, data.length);
    for (let i = start; i < end; i++) {
      parts.push(data[i].toString(16).toUpperCase().padStart(2, '0'));
    }
    return parts.join(' ');
  }

  /**
   * 处理 Air5 Pro 移位后的 0x8112 多设备列表响应
   * 标准帧: AA LL 00 00 cmdL cmdH seq payLL payLH [payload]
   * Air5 Pro: AA LL 00 00 status cmdL cmdH seq payLL payLH [payload]
   * 因此 cmd 实际在 data[5-6]，payLen 在 data[8-9]，payload 从 data[10] 开始
   */
  private handleShiftedMultiConnectResponse(data: Uint8Array): void {
    if (data.length < 10 || data[0] !== 0xAA) {
      return;
    }
    // 验证移位后的 cmd 确实是 0x8112
    const realCmdLow = data[5];
    const realCmdHigh = data[6];
    const realCmd = realCmdLow | (realCmdHigh << 8);
    if (realCmd !== CMD_MULTI_CONNECT_RESP) {
      console.info(`[MultiDevice] 移位响应实际 cmd=0x${realCmd.toString(16)}，不是 0x8112，忽略`);
      return;
    }
    // 按 +1 偏移读取 payLen 和 payload
    const shiftedPayLen = (data[8] | (data[9] << 8));
    const shiftedStart = 10;
    console.info(`[MultiDevice] 移位解析: realCmd=0x8112, payLen=${shiftedPayLen}, dataLen=${data.length}`);
    // 调用解析器（传入原始 data，但通过 start 偏移让解析器从 payload 开始处理）
    // 解析器期望从 data[start] 开始读取 payload，所以我们传入 data 并指定 start=shiftedStart
    const devices = parseMultiConnectResponseWithOffset(data, shiftedStart, shiftedPayLen);
    if (devices.length > 0) {
      this.deviceList = devices;
      if (this.onDeviceListChanged) {
        this.onDeviceListChanged(devices);
      }
    }
  }

  /**
   * 处理 0x8112 多设备列表响应（标准格式）
   */
  private handleMultiConnectResponse(data: Uint8Array): void {
    const devices = parseMultiConnectResponse(data);
    if (devices.length > 0) {
      this.deviceList = devices;
      if (this.onDeviceListChanged) {
        this.onDeviceListChanged(devices);
      }
    }
  }

  /**
   * 处理 0x8132 多连接优先设备响应
   */
  private handleMultiPriorityResponse(data: Uint8Array): void {
    const payLen = (data[7] | (data[8] << 8));
    const start = 9;
    // 诊断日志：打印关键字节
    const statusByte = data.length > start ? data[start] : -1;
    console.info(`[MultiDevice] handleMultiPriorityResponse: payLen=${payLen}, status=0x${statusByte.toString(16)}, ` +
      `dataLen=${data.length}, raw[9-12]=${this.hexDump(data, start, Math.min(4, data.length - start))}`);

    const info = parseMultiPriorityResponse(data);
    if (info) {
      this.priorityInfo = info;
      console.info(`[MultiDevice] 优先级解析成功: autoMode=${info.autoMode}, addr=${info.priorityAddress}`);
      if (this.onPriorityChanged) {
        this.onPriorityChanged(info);
      }
    } else {
      console.info('[MultiDevice] 优先级解析返回 null，请检查原始数据');
    }
  }

  /**
   * 处理 0x8429 多设备操作响应
   */
  private handleOperateResponse(data: Uint8Array): void {
    const payLen = (data[7] | (data[8] << 8));
    const start = 9;

    if (payLen > 0 && data[start] === 0x00) {
      // status=0 → 成功
      console.info('[MultiDevice] 多设备操作 ACK 成功，刷新设备列表');
      if (this.onOperationResult) {
        this.onOperationResult(MultiDeviceOpResult.SUCCESS, '操作成功');
      }
      // 操作成功后自动刷新列表
      setTimeout(() => {
        this.queryDeviceList();
        if (this.hasMultiConnectManage) {
          this.queryPriorityDevice();
        }
      }, 300);
    } else {
      // status!=0 → 失败
      const status = payLen > 0 ? data[start] : -1;
      console.info(`[MultiDevice] 多设备操作 ACK 失败 status=${status}`);
      if (this.onOperationResult) {
        this.onOperationResult(MultiDeviceOpResult.FAILED, `操作失败 (status=${status})`);
      }
    }
  }
}
