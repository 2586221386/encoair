/**
 * 多设备连接列表数据模型
 * 移植自 OppoPodsManager-main Models/ConnectedDeviceInfo.cs
 *
 * 对应 OPPO 协议 0x8112 (CmdMultiConnectResp) 响应中的单条设备记录。
 * 耳机通过 SPP 上报已配对/已连接的手持设备信息。
 */

/**
 * 多设备列表中的单条设备条目
 */
export class ConnectedDeviceInfo {
  /** 对端手持设备 MAC 地址，如 "AA:BB:CC:DD:EE:FF" */
  address: string = '';

  /** 设备名（耳机上报的对端蓝牙名） */
  deviceName: string = '';

  /** 设备类型（flag bit3-5）：0=手机 1=电脑 2=平板 3=手表 */
  deviceType: number = 0;

  /** 连接状态：0=已断开 1=连接中 2=已连接 */
  connectionState: number = 0;

  /** 是否当前运行本程序的设备（flag bit0） */
  isCurrentDevice: boolean = false;

  /** 是否主音频设备（flag bit1）：耳机侧标记的主音频通道设备 */
  isMainAudioDevice: boolean = false;

  /** 是否音频活动设备（flag bit2）：当前正在输出音频的设备 */
  isAudioActive: boolean = false;

  /** 0x8112 响应中的 elemByte6（设备级别/类型字段，0x0408 下发时用作 type） */
  elemByte6: number = 0;

  /** 原始设备条目字节（MAC LE 6B + elemByte6 + connState + flag + nameLen + name） */
  rawEntryBytes: Uint8Array = new Uint8Array(0);

  /**
   * 连接状态可读文案
   */
  getConnectionStatusText(): string {
    switch (this.connectionState) {
      case 2:
        return this.isCurrentDevice ? '当前设备' : '已连接';
      case 1:
        return '连接中';
      default:
        return '已断开';
    }
  }

  /**
   * 设备类型可读文案
   */
  getDeviceTypeText(): string {
    switch (this.deviceType) {
      case 0:
        return '手机';
      case 1:
        return '电脑';
      case 2:
        return '平板';
      case 3:
        return '手表';
      default:
        return '未知';
    }
  }

  /**
   * UI 显示名称
   */
  getDisplayName(): string {
    return this.deviceName || this.address;
  }
}

/**
 * 多设备优先/自动切换状态
 * 对应 OPPO 协议 0x8132 (CmdMultiPriorityResp) 响应
 */
export class MultiPriorityInfo {
  /** 是否处于自动切换模式（耳机自动决定音频输出）。默认 true：紧凑格式无法区分时假定为自动 */
  autoMode: boolean = true;

  /** 手动模式下用户指定的优先设备 MAC */
  priorityAddress: string = '';

  /** 优先级级别（2=高级别） */
  level: number = 0;
}

/**
 * 多设备操作类型枚举
 * 对应 OppoProtocol.MultiDevice.cs 中的操作常量
 */
export enum MultiDeviceOpType {
  /** 连接手持设备 */
  CONNECT = 0x01,
  /** 断开手持设备 */
  DISCONNECT = 0x02,
  /** 取消配对 */
  UNPAIR = 0x03,
  /** 设置音频优先设备 */
  SET_PRIORITY = 0x04
}

/**
 * 多设备操作结果
 */
export enum MultiDeviceOpResult {
  /** 操作成功 */
  SUCCESS = 0,
  /** 操作失败 */
  FAILED = 1,
  /** 操作超时 */
  TIMEOUT = 2
}
