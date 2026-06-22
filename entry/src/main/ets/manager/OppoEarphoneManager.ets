import { ble, socket, connection } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { formProvider, formBindingData } from '@kit.FormKit';
import { common, wantAgent, WantAgent, Want } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';

/**
 * 桌面卡片电量数据结构
 */
class WidgetBatteryData {
  leftBattery: number = -1;
  leftCharging: boolean = false;
  rightBattery: number = -1;
  rightCharging: boolean = false;
  caseBattery: number = -1;
  caseCharging: boolean = false;
  lastUpdated: string = '--:--';
  connected: boolean = false;
}

/**
 * 电池信息数据模型
 */
export interface BatteryInfo {
  leftBattery: number;    // -1 表示未知
  leftCharging: boolean;
  rightBattery: number;
  rightCharging: boolean;
  caseBattery: number;
  caseCharging: boolean;
}

/**
 * 连接状态枚举
 */
export type ConnectionStatus = 'disconnected' | 'scanning' | 'connecting' | 'connected' | 'subscribed';

/**
 * 佩戴状态枚举
 */
export enum WearState {
  DISCONNECTED = 0x00,
  IN_CASE = 0x04,
  REMOVED = 0x05,
  WEARING = 0x07
}

/**
 * 佩戴状态数据模型
 */
export interface WearStatus {
  left: WearState;
  right: WearState;
  case: WearState;
}

/**
 * ANC 模式名称映射
 */
export function getAncModeName(mode: number): string {
  switch (mode) {
    case 1: return '关闭';
    case 2: return '降噪';
    case 3: return '通透';
    case 4: return '自适应';
    case 5: return '智能降噪';
    case 6: return '轻度降噪';
    case 7: return '中度降噪';
    case 8: return '深度降噪';
    default: return '未知';
  }
}

/**
 * OPPO 蓝牙耳机电量管理器（SPP/RFCOMM UUID 连接模式）
 * 通过 SPP RFCOMM 与耳机通信，参考安卓 OppoPods 项目的连接方式
 * 相比 BLE GATT 方式更加稳定可靠
 */
export class OppoEarphoneManager {
  // 单例实例（用于后台任务获取Manager）
  private static instance: OppoEarphoneManager | null = null;

  /**
   * 获取单例实例（后台任务/WorkScheduler使用）
   */
  static getInstance(): OppoEarphoneManager {
    if (!OppoEarphoneManager.instance) {
      OppoEarphoneManager.instance = new OppoEarphoneManager();
    }
    return OppoEarphoneManager.instance;
  }

  // 应用前后台状态（后台任务跳过前台运行时的刷新）
  static isAppForeground: boolean = false;

  // 后台保活状态
  private isBackgroundTaskRunning: boolean = false;
  private static readonly NOTIFICATION_ID: number = 9001;

  // OPPO Enco Air5 Pro RFCOMM UUID（与安卓 OppoPods 项目一致）
  private RFCOMM_UUID: string = '0000079A-D102-11E1-9B23-00025B00A5A5';
  private TARGET_DEVICE_NAME: string = 'OPPO Enco Air5 Pro';

  // SPP RFCOMM 客户端 Socket Number（-1表示未连接）
  private sppClientNumber: number = -1;
  private isConnected: boolean = false;

  // 连接状态
  private isScanning: boolean = false;
  private connectedMac: string = '';

  // 自动连接相关
  private savedMac: string = '';
  private autoReconnectTimer: number = -1;
  private reconnectAttempts: number = 0;
  private readonly MAX_RECONNECT_ATTEMPTS: number = 5;
  private readonly RECONNECT_DELAY_MS: number = 3000;

  // 持续监听相关
  private continuousMonitorTimer: number = -1;
  private readonly MONITOR_INTERVAL_MS: number = 5000;
  private isMonitorRunning: boolean = false;

  // 回调函数
  private batteryCallback: ((info: BatteryInfo) => void) | null = null;
  private statusCallback: ((status: ConnectionStatus) => void) | null = null;
  private rawDataCallback: ((hex: string) => void) | null = null;
  private ancCallback: ((mode: number) => void) | null = null;
  private wearCallback: ((wear: WearStatus) => void) | null = null;
  private gameModeCallback: ((enabled: boolean) => void) | null = null;
  private spatialAudioCallback: ((enabled: boolean) => void) | null = null;

  // 当前电量状态
  private batteryInfo: BatteryInfo = {
    leftBattery: -1,
    leftCharging: false,
    rightBattery: -1,
    rightCharging: false,
    caseBattery: -1,
    caseCharging: false
  };

  // 当前ANC模式
  private currentAncMode: number = 1;

  // 当前佩戴状态
  private currentWearStatus: WearStatus = {
    left: WearState.DISCONNECTED,
    right: WearState.DISCONNECTED,
    case: WearState.DISCONNECTED
  };

  // 游戏模式状态
  private gameModeEnabled: boolean = false;

  // 空间音频状态（0=关闭, 1=固定/开启）
  private spatialAudioEnabled: boolean = false;

  // 定时查询定时器
  private queryTimer: number = -1;

  // 应用上下文（用于卡片数据刷新），使用静态属性以便所有实例共享
  private static appContext: common.Context | null = null;

  /**
   * 设置应用上下文（用于刷新桌面卡片）
   */
  setContext(ctx: common.Context): void {
    OppoEarphoneManager.appContext = ctx;
  }

  /**
   * 获取当前连接状态
   */
  getIsConnected(): boolean {
    return this.isConnected;
  }

  /**
   * 获取当前电量快照
   */
  getCurrentBatteryInfo(): BatteryInfo {
    return {
      leftBattery: this.batteryInfo.leftBattery,
      leftCharging: this.batteryInfo.leftCharging,
      rightBattery: this.batteryInfo.rightBattery,
      rightCharging: this.batteryInfo.rightCharging,
      caseBattery: this.batteryInfo.caseBattery,
      caseCharging: this.batteryInfo.caseCharging
    };
  }

  /**
   * 设置回调函数
   */
  setCallbacks(batteryCb: (info: BatteryInfo) => void, statusCb: (status: ConnectionStatus) => void, rawCb?: (hex: string) => void,
    ancCb?: (mode: number) => void, wearCb?: (wear: WearStatus) => void, gameCb?: (enabled: boolean) => void,
    spatialAudioCb?: (enabled: boolean) => void): void {
    this.batteryCallback = batteryCb;
    this.statusCallback = statusCb;
    this.rawDataCallback = rawCb ?? null;
    this.ancCallback = ancCb ?? null;
    this.wearCallback = wearCb ?? null;
    this.gameModeCallback = gameCb ?? null;
    this.spatialAudioCallback = spatialAudioCb ?? null;
  }

  /**
   * 启动持续监听模式(应用启动时调用)
   */
  startContinuousMonitor(): void {
    if (this.isMonitorRunning) {
      console.info('[OppoManager] 监听已在运行中');
      return;
    }
    console.info('[OppoManager] 启动持续监听模式(SPP RFCOMM)...');
    this.isMonitorRunning = true;
    // 第一步：优先尝试从已保存MAC或系统已配对设备中连接
    if (this.savedMac) {
      console.info(`[OppoManager] 发现已保存设备,优先连接: ${this.savedMac}`);
      this.connectToEarphone(this.savedMac);
    } else {
      this.tryConnectFromPairedDevices();
    }
    // 第二步：如果配对设备直连未成功，启动BLE扫描监听
    this.startMonitorCycle();
  }

  /**
   * 从系统已配对设备中查找OPPO耳机并直连SPP
   * 解决耳机已通过系统蓝牙配对连接后，BLE扫描无法发现的问题
   */
  private tryConnectFromPairedDevices(): boolean {
    try {
      let pairedDevices: Array<string> = connection.getPairedDevices();
      console.info(`[OppoManager] 系统已配对设备数量: ${pairedDevices.length}`);
      for (let i = 0; i < pairedDevices.length; i++) {
        let mac: string = pairedDevices[i];
        try {
          let deviceName: string = connection.getRemoteDeviceName(mac);
          console.info(`[OppoManager] 已配对设备[${i}]: MAC=${mac}, 名称=${deviceName}`);
          if (deviceName && deviceName.includes('OPPO Enco')) {
            console.info(`[OppoManager] 发现已配对的OPPO耳机! 跳过BLE扫描，直接SPP连接: ${deviceName} [${mac}]`);
            this.saveConnectedMac(mac);
            this.connectToEarphone(mac);
            return true;
          }
        } catch (nameErr) {
          let err = nameErr as BusinessError;
          console.warn(`[OppoManager] 获取设备名称失败[${mac}]: ${err.message}`);
        }
      }
      console.info('[OppoManager] 已配对设备中未发现OPPO耳机');
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[OppoManager] 获取已配对设备列表失败: ${error.message}`);
    }
    return false;
  }

  /**
   * 执行一次扫描周期（仍使用BLE扫描发现设备）
   */
  private startMonitorCycle(): void {
    if (!this.isMonitorRunning) return;
    if (this.connectedMac || this.isScanning) {
      console.info('[OppoManager] 已连接或正在扫描,跳过本次扫描');
      this.scheduleNextMonitorCycle();
      return;
    }
    // 每轮扫描前也检查已配对设备（用户可能在运行期间配对耳机）
    if (this.tryConnectFromPairedDevices()) {
      this.scheduleNextMonitorCycle();
      return;
    }
    console.info('[OppoManager] 开始监听扫描...');
    this.notifyStatus('scanning');
    const scanTimeout = setTimeout(() => {
      if (this.isScanning) {
        console.info('[OppoManager] 监听扫描超时,停止本次扫描');
        this.stopScan();
        this.notifyStatus('disconnected');
      }
    }, 10000);
    ble.on('BLEDeviceFind', (devices: Array<ble.ScanResult>) => {
      for (let device of devices) {
        let deviceName = device.deviceName;
        let deviceMac = device.deviceId;
        if (deviceName && deviceName.includes('OPPO Enco')) {
          console.info(`[OppoManager] 监听到OPPO耳机! 名字: ${deviceName}, MAC: ${deviceMac}`);
          clearTimeout(scanTimeout);
          this.stopScan();
          this.connectToEarphone(deviceMac);
          break;
        }
      }
    });
    try {
      ble.startBLEScan(null, {
        interval: 0,
        dutyMode: ble.ScanDuty.SCAN_MODE_LOW_LATENCY,
        matchMode: ble.MatchMode.MATCH_MODE_AGGRESSIVE
      });
      this.isScanning = true;
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[OppoManager] 监听扫描失败: ${error.message}`);
      clearTimeout(scanTimeout);
      this.isScanning = false;
      this.notifyStatus('disconnected');
      this.scheduleNextMonitorCycle();
    }
  }

  /**
   * 安排下一次扫描周期
   */
  private scheduleNextMonitorCycle(): void {
    if (!this.isMonitorRunning) return;
    this.continuousMonitorTimer = setTimeout(() => {
      this.startMonitorCycle();
    }, this.MONITOR_INTERVAL_MS);
  }

  /**
   * 停止持续监听
   */
  stopContinuousMonitor(): void {
    this.isMonitorRunning = false;
    if (this.continuousMonitorTimer !== -1) {
      clearTimeout(this.continuousMonitorTimer);
      this.continuousMonitorTimer = -1;
    }
    this.stopScan();
    console.info('[OppoManager] 持续监听已停止');
  }

  /**
   * 启动自动连接
   */
  startAutoConnect(): void {
    console.info('[OppoManager] 启动自动连接(SPP RFCOMM)...');
    if (this.savedMac) {
      console.info(`[OppoManager] 尝试连接已保存设备: ${this.savedMac}`);
      this.connectToEarphone(this.savedMac);
    } else {
      // 先检查系统已配对设备
      console.info('[OppoManager] 无已保存设备,检查系统已配对设备...');
      if (!this.tryConnectFromPairedDevices()) {
        console.info('[OppoManager] 开始扫描...');
        this.startScan();
      }
    }
  }

  /**
   * 保存已连接的设备MAC（同时持久化到Preferences供后台任务读取）
   */
  private saveConnectedMac(mac: string): void {
    this.savedMac = mac;
    console.info(`[OppoManager] 保存设备MAC: ${mac}`);
    // 持久化MAC以便后台任务读取
    if (OppoEarphoneManager.appContext) {
      try {
        let pref = preferences.getPreferencesSync(OppoEarphoneManager.appContext, { name: 'battery_widget_data' });
        pref.putSync('savedMac', mac);
        pref.flush();
      } catch (e) {
        // 不影响主流程
      }
    }
  }

  /**
   * 清除已保存的设备MAC
   */
  clearSavedMac(): void {
    this.savedMac = '';
    console.info('[OppoManager] 已清除保存的设备MAC');
  }

  /**
   * 尝试重新连接
   */
  private scheduleReconnect(): void {
    if (this.reconnectAttempts >= this.MAX_RECONNECT_ATTEMPTS) {
      console.warn(`[OppoManager] 达到最大重连次数(${this.MAX_RECONNECT_ATTEMPTS}),停止重连`);
      this.reconnectAttempts = 0;
      this.notifyStatus('disconnected');
      return;
    }
    this.reconnectAttempts++;
    console.info(`[OppoManager] 计划重连 (${this.reconnectAttempts}/${this.MAX_RECONNECT_ATTEMPTS})...`);
    this.notifyStatus('connecting');
    this.autoReconnectTimer = setTimeout(() => {
      if (this.savedMac) {
        this.connectToEarphone(this.savedMac);
      } else {
        // 重连时也检查系统已配对设备
        if (!this.tryConnectFromPairedDevices()) {
          this.startScan();
        }
      }
    }, this.RECONNECT_DELAY_MS);
  }

  /**
   * 取消重连定时器
   */
  private cancelReconnect(): void {
    if (this.autoReconnectTimer !== -1) {
      clearTimeout(this.autoReconnectTimer);
      this.autoReconnectTimer = -1;
    }
    this.reconnectAttempts = 0;
  }

  /**
   * 构造 OPPO 协议数据包
   */
  private buildPacket(cmd: number, seq: number = 0xF0, payload: number[] = []): Uint8Array {
    const payLen = payload.length;
    const totalLen = 7 + payLen;
    const packet = new Uint8Array(2 + totalLen);
    packet[0] = 0xAA;
    packet[1] = totalLen;
    packet[2] = 0x00;
    packet[3] = 0x00;
    packet[4] = cmd & 0xFF;
    packet[5] = (cmd >> 8) & 0xFF;
    packet[6] = seq;
    packet[7] = payLen & 0xFF;
    packet[8] = (payLen >> 8) & 0xFF;
    for (let i = 0; i < payLen; i++) {
      packet[9 + i] = payload[i];
    }
    return packet;
  }

  /**
   * 通过 SPP RFCOMM 发送指令
   */
  private sendPacket(packet: Uint8Array): void {
    if (this.sppClientNumber < 0 || !this.isConnected) {
      console.warn('[OppoManager] 未连接，无法发送指令');
      return;
    }
    try {
      socket.sppWrite(this.sppClientNumber, packet.buffer as ArrayBuffer);
      console.info(`[OppoManager] 指令发送成功: ${this.toHexStr(packet)}`);
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[OppoManager] 写入失败: ${error.message}, code=${error.code}, type=${typeof error.code}`);
      // 错误码2901054表示SPP IO错误（连接已断开）
      let errCode: number = Number(error.code);
      if (errCode === 2901054) {
        console.info('[OppoManager] 检测到SPP IO错误(2901054)，自然断开');
        this.disconnect(false);
      }
    }
  }

  /**
   * 查询电量
   */
  queryBattery(): void {
    const packet = this.buildPacket(0x0106, 0xF0, []);
    this.sendPacket(packet);
  }

  /**
   * 查询 ANC 模式
   */
  queryAncMode(): void {
    const packet = this.buildPacket(0x010C, 0x00, [0x01, 0x01]);
    this.sendPacket(packet);
  }

  /**
   * 设置 ANC 模式
   */
  setAncMode(mode: number): void {
    let payload: number[] = [];
    switch (mode) {
      case 1: payload = [0x01, 0x01, 0x01]; break;
      case 2: payload = [0x01, 0x01, 0x02]; break;
      case 3: payload = [0x01, 0x01, 0x04]; break;
      case 4: payload = [0x01, 0x01, 0x00, 0x08]; break;
      case 5: payload = [0x01, 0x01, 0x80]; break;
      case 6: payload = [0x01, 0x01, 0x40]; break;
      case 7: payload = [0x01, 0x01, 0x20]; break;
      case 8: payload = [0x01, 0x01, 0x10]; break;
      default: console.warn(`[OppoManager] 不支持的ANC模式: ${mode}`); return;
    }
    const packet = this.buildPacket(0x0404, 0x00, payload);
    this.sendPacket(packet);
    console.info(`[OppoManager] 发送 ANC 模式切换指令: ${getAncModeName(mode)}`);
    setTimeout(() => {
      this.queryAncMode();
    }, 350);
  }

  /**
   * 查询游戏模式
   */
  queryGameMode(): void {
    const packet = this.buildPacket(0x010D, 0x00, []);
    this.sendPacket(packet);
  }

  /**
   * 设置游戏模式
   */
  setGameMode(enabled: boolean): void {
    this.gameModeEnabled = enabled;
    this.notifyGameModeUpdate(enabled);
    const payload: number[] = [0x28, enabled ? 0x01 : 0x00];
    const packet = this.buildPacket(0x0403, 0x00, payload);
    this.sendPacket(packet);
    console.info(`[OppoManager] 发送游戏模式切换指令: ${enabled ? '开启' : '关闭'}`);
    setTimeout(() => {
      this.queryGameMode();
    }, 350);
  }

  /**
   * 查询空间音频状态（复用功能查询指令，feature=0x1B）
   */
  querySpatialAudio(): void {
    const packet = this.buildPacket(0x010D, 0x00, []);
    this.sendPacket(packet);
  }

  /**
   * 设置空间音频开关
   * 使用 cmd=0x0403 + feature=0x1B（空间音效特征码）
   */
  setSpatialAudio(enabled: boolean): void {
    this.spatialAudioEnabled = enabled;
    this.notifySpatialAudioUpdate(enabled);
    const payload: number[] = [0x1B, enabled ? 0x01 : 0x00];
    const packet = this.buildPacket(0x0403, 0x00, payload);
    this.sendPacket(packet);
    console.info(`[OppoManager] 发送空间音频切换指令: ${enabled ? '开启' : '关闭'}`);
    setTimeout(() => {
      this.querySpatialAudio();
    }, 350);
  }

  /**
   * 启用主动状态上报
   */
  enableStatusReport(): void {
    const packet = new Uint8Array([0xAA, 0x09, 0x00, 0x00, 0x05, 0x02, 0x3A, 0x02, 0x00, 0x01, 0x02]);
    this.sendPacket(packet);
  }

  /**
   * 查询状态（批量查询）
   */
  queryStatus(): void {
    const packet = new Uint8Array([
      0xAA, 0x13, 0x00, 0x00, 0x0D, 0x01, 0x00, 0x0C, 0x00,
      0x0B, 0x05, 0x04, 0x0B, 0x11, 0x13, 0x18, 0x06, 0x1B, 0x1C, 0x27, 0x28
    ]);
    this.sendPacket(packet);
  }

  /**
   * 启动定时查询
   */
  startPeriodicQuery(): void {
    this.stopPeriodicQuery();
    this.queryTimer = setInterval(() => {
      this.queryBattery();
    }, 30000);
  }

  /**
   * 停止定时查询
   */
  stopPeriodicQuery(): void {
    if (this.queryTimer !== -1) {
      clearInterval(this.queryTimer);
      this.queryTimer = -1;
    }
  }

  /**
   * 字节数组转 HEX 字符串
   */
  private toHexStr(data: Uint8Array): string {
    const parts: string[] = [];
    for (let i = 0; i < data.length; i++) {
      parts.push(data[i].toString(16).toUpperCase().padStart(2, '0'));
    }
    return parts.join(' ');
  }

  private notifyAncUpdate(mode: number): void {
    if (this.ancCallback) this.ancCallback(mode);
    // 更新常驻通知中的ANC状态
    if (this.isBackgroundTaskRunning) this.publishOrUpdateNotification();
  }

  private notifyWearUpdate(wear: WearStatus): void {
    if (this.wearCallback) this.wearCallback(wear);
  }

  private notifyGameModeUpdate(enabled: boolean): void {
    if (this.gameModeCallback) this.gameModeCallback(enabled);
  }

  private notifySpatialAudioUpdate(enabled: boolean): void {
    if (this.spatialAudioCallback) this.spatialAudioCallback(enabled);
  }

  /**
   * 开始扫描周围的 OPPO 耳机（使用BLE扫描）
   */
  startScan(): void {
    if (this.isScanning) return;
    console.info('[OppoManager] 开始扫描周围的 OPPO 耳机...');
    this.notifyStatus('scanning');
    this.isScanning = true;
    this.cancelReconnect();
    ble.on('BLEDeviceFind', (devices: Array<ble.ScanResult>) => {
      for (let device of devices) {
        let deviceName = device.deviceName;
        let deviceMac = device.deviceId;
        if (deviceName && deviceName.includes('OPPO Enco')) {
          console.info(`[OppoManager] 发现目标耳机! 名字: ${deviceName}, MAC: ${deviceMac}`);
          this.stopScan();
          this.connectToEarphone(deviceMac);
          break;
        }
      }
    });
    try {
      ble.startBLEScan(null, {
        interval: 0,
        dutyMode: ble.ScanDuty.SCAN_MODE_LOW_LATENCY,
        matchMode: ble.MatchMode.MATCH_MODE_AGGRESSIVE
      });
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[OppoManager] 启动扫描失败: ${error.message}`);
      this.isScanning = false;
      this.notifyStatus('disconnected');
    }
  }

  /**
   * 停止扫描
   */
  stopScan(): void {
    if (!this.isScanning) return;
    try {
      ble.stopBLEScan();
      ble.off('BLEDeviceFind');
      this.isScanning = false;
      console.info('[OppoManager] 扫描已停止。');
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[OppoManager] 停止扫描失败: ${error.message}`);
    }
  }

  /**
   * 获取已连接的 MAC 地址
   */
  getMacAddress(): string {
    return this.connectedMac;
  }

  /**
   * 断开连接并清理资源
   * @param silent 静默模式（页面销毁时用true，不更新桌面卡片）
   */
  disconnect(silent: boolean = false): void {
    this.stopContinuousMonitor();
    this.stopPeriodicQuery();
    this.cancelReconnect();
    // 停止后台保活 + 移除通知
    this.stopBackgroundService();
    this.cleanup(silent);
    this.notifyStatus('disconnected');
  }

  // ============== SPP RFCOMM 连接核心逻辑 ==============

  /**
   * 通过 SPP RFCOMM 连接到耳机
   * 参考安卓 OppoPods RfcommController.connectRfcomm() 方法
   */
  private connectToEarphone(macAddress: string): void {
    this.connectedMac = macAddress;
    this.notifyStatus('connecting');
    console.info(`[OppoManager] 正在通过 SPP RFCOMM 连接耳机 [${macAddress}]...`);
    console.info(`[OppoManager] RFCOMM UUID: ${this.RFCOMM_UUID}`);

    try {
      // 先清理旧连接
      this.closeSocket();

      // 配置 SPP 连接参数
      let sppOption: socket.SppOptions = {
        uuid: this.RFCOMM_UUID,
        secure: false,
        type: socket.SppType.SPP_RFCOMM
      };

      console.info(`[OppoManager] 发起 SPP RFCOMM 连接...`);

      // 发起 SPP RFCOMM 连接
      socket.sppConnect(macAddress, sppOption, (err: BusinessError, clientNum: number) => {
        if (err) {
          console.error(`[OppoManager] SPP RFCOMM 连接失败: errCode=${err.code}, errMessage=${err.message}`);
          this.cleanup();
          this.notifyStatus('disconnected');
          if (this.isMonitorRunning) {
            this.scheduleNextMonitorCycle();
          } else {
            this.scheduleReconnect();
          }
          return;
        }

        // 连接成功
        console.info(`[OppoManager] SPP RFCOMM 连接成功! clientNumber=${clientNum}, UUID=${this.RFCOMM_UUID}`);
        this.sppClientNumber = clientNum;
        this.isConnected = true;
        this.saveConnectedMac(macAddress);
        this.reconnectAttempts = 0;

        // 注册数据接收监听
        try {
          socket.on('sppRead', clientNum, (dataBuffer: ArrayBuffer) => {
            let valueArray = new Uint8Array(dataBuffer);
            // 空数据表示蓝牙连接已自然断开（耳机断电/超出范围）
            if (valueArray.length === 0) {
              console.info('[OppoManager] sppRead收到空数据，检测到自然断开');
              this.disconnect(false);
              return;
            }
            if (valueArray.length >= 9 && valueArray[0] === 0xAA) {
              const cmdLow = valueArray[4];
              const cmdHigh = valueArray[5];
              const cmd = cmdLow | (cmdHigh << 8);
              console.info(`[OppoManager] 接收数据: cmd=0x${cmd.toString(16)}, 长度=${valueArray.length}`);
            }
            // 通知原始HEX数据
            this.notifyRawData(valueArray);
            // 解析电量
            this.parseOppoBattery(valueArray);
            // 解析 ANC 模式
            this.parseAncMode(valueArray);
            // 解析佩戴状态
            this.parseWearStatus(valueArray);
            // 解析游戏模式
            this.parseGameMode(valueArray);
            // 解析空间音频
            this.parseSpatialAudio(valueArray);
          });
        } catch (readErr) {
          let error = readErr as BusinessError;
          console.error(`[OppoManager] 注册sppRead监听失败: ${error.message}`);
        }

        // SPP RFCOMM 连接成功即可通信，直接设为 subscribed（无需GATT服务发现）
        this.notifyStatus('subscribed');

        // 启动后台保活 + 常驻通知
        this.startBackgroundService();

        // 连接成功后启动查询（参考安卓 connectRfcomm 流程）
        setTimeout(() => {
          this.enableStatusReport();
          setTimeout(() => {
            this.queryStatus();
            setTimeout(() => {
              this.queryBattery();
              this.queryAncMode();
              this.queryGameMode();
              this.querySpatialAudio();
              this.startPeriodicQuery();
            }, 200);
          }, 200);
        }, 300);
      });

    } catch (err) {
      let error = err as BusinessError;
      console.error(`[OppoManager] SPP RFCOMM 连接异常: ${error.message}, code=${error.code}`);
      this.cleanup();
      this.notifyStatus('disconnected');
    }
  }

  /**
   * 关闭 SPP RFCOMM Socket
   */
  private closeSocket(): void {
    if (this.sppClientNumber >= 0) {
      try {
        socket.off('sppRead', this.sppClientNumber);
      } catch (err) {
        let error = err as BusinessError;
        console.error(`[OppoManager] 取消sppRead监听失败: ${error.message}`);
      }
      try {
        socket.sppCloseClientSocket(this.sppClientNumber);
      } catch (err) {
        let error = err as BusinessError;
        console.error(`[OppoManager] 关闭Socket失败: ${error.message}`);
      }
      this.sppClientNumber = -1;
    }
    this.isConnected = false;
  }

  /**
   * 清理连接资源
   */
  private cleanup(silent: boolean = false): void {
    this.closeSocket();
    this.connectedMac = '';
    // 重置电量信息
    this.batteryInfo = {
      leftBattery: -1,
      leftCharging: false,
      rightBattery: -1,
      rightCharging: false,
      caseBattery: -1,
      caseCharging: false
    };
    if (silent) {
      // 页面销毁时静默断开：不推送卡片更新，保留上次有效电量
      console.info('[OppoManager] 静默断开连接，不更新桌面卡片');
    } else {
      // 用户主动断开或自然断开：推送断开状态到卡片
      this.notifyBatteryUpdate();
    }
  }

  // ============== 数据解析（与 BLE 版本完全相同） ==============

  /**
   * 核心逆向算法最新升级版（完美兼容官方协议及复杂前置序列）
   */
  private parseOppoBattery(data: Uint8Array): void {
    let updated = false;
    if (data.length < 9 || data[0] !== 0xAA) return;
    const cmdLow = data[4];
    const cmdHigh = data[5];
    const cmd = cmdLow | (cmdHigh << 8);

    // === 1. 解析电量查询响应 (Cmd=0x8106) ===
    if (cmd === 0x8106) {
      const payLen = (data[7] | (data[8] << 8));
      const payloadStart = 9;
      if (data.length < payloadStart + payLen) return;
      let i = payloadStart;
      while (i + 1 < payloadStart + payLen) {
        const index = data[i];
        const rawValue = data[i + 1];
        const battery = rawValue & 0x7F;
        const charging = (rawValue & 0x80) !== 0;
        if (battery >= 0 && battery <= 100) {
          switch (index) {
            case 0x01:
              if (this.batteryInfo.leftBattery !== battery || this.batteryInfo.leftCharging !== charging) {
                this.batteryInfo.leftBattery = battery;
                this.batteryInfo.leftCharging = charging;
                updated = true;
              }
              break;
            case 0x02:
              if (this.batteryInfo.rightBattery !== battery || this.batteryInfo.rightCharging !== charging) {
                this.batteryInfo.rightBattery = battery;
                this.batteryInfo.rightCharging = charging;
                updated = true;
              }
              break;
            case 0x03:
              if (this.batteryInfo.caseBattery !== battery || this.batteryInfo.caseCharging !== charging) {
                this.batteryInfo.caseBattery = battery;
                this.batteryInfo.caseCharging = charging;
                updated = true;
              }
              break;
          }
        }
        i += 2;
      }
    }

    // === 2. 解析主动上报电量 (Cmd=0x0204, type=0x01) ===
    if (cmd === 0x0204) {
      const payLen = (data[7] | (data[8] << 8));
      const payloadStart = 9;
      if (data.length < payloadStart + payLen || payLen < 2) return;
      const reportType = data[payloadStart];
      if (reportType !== 0x01) return;
      const count = data[payloadStart + 1];
      if (payLen < 2 + count * 2) return;
      for (let j = 0; j < count; j++) {
        const idx = payloadStart + 2 + j * 2;
        if (idx + 1 >= data.length) break;
        const index = data[idx];
        const rawValue = data[idx + 1];
        const battery = rawValue & 0x7F;
        const charging = (rawValue & 0x80) !== 0;
        if (battery >= 0 && battery <= 100) {
          switch (index) {
            case 0x01:
              if (this.batteryInfo.leftBattery !== battery || this.batteryInfo.leftCharging !== charging) {
                this.batteryInfo.leftBattery = battery;
                this.batteryInfo.leftCharging = charging;
                updated = true;
              }
              break;
            case 0x02:
              if (this.batteryInfo.rightBattery !== battery || this.batteryInfo.rightCharging !== charging) {
                this.batteryInfo.rightBattery = battery;
                this.batteryInfo.rightCharging = charging;
                updated = true;
              }
              break;
            case 0x03:
              if (this.batteryInfo.caseBattery !== battery || this.batteryInfo.caseCharging !== charging) {
                this.batteryInfo.caseBattery = battery;
                this.batteryInfo.caseCharging = charging;
                updated = true;
              }
              break;
          }
        }
      }
    }
    if (updated) {
      this.notifyBatteryUpdate();
    }
  }

  /**
   * 通知电量更新
   */
  private notifyBatteryUpdate(): void {
    if (this.batteryCallback) {
      this.batteryCallback({
        leftBattery: this.batteryInfo.leftBattery,
        leftCharging: this.batteryInfo.leftCharging,
        rightBattery: this.batteryInfo.rightBattery,
        rightCharging: this.batteryInfo.rightCharging,
        caseBattery: this.batteryInfo.caseBattery,
        caseCharging: this.batteryInfo.caseCharging
      });
    }
    // 同步写入Preferences并刷新桌面卡片
    this.saveBatteryToWidget();
    // 更新常驻通知中的电量
    if (this.isBackgroundTaskRunning) this.publishOrUpdateNotification();
  }

  /**
   * 将电量数据写入Preferences并刷新桌面卡片
   */
  private async saveBatteryToWidget(): Promise<void> {
    if (!OppoEarphoneManager.appContext) {
      console.warn('[OppoManager] saveBatteryToWidget: appContext为空');
      return;
    }
    let isDisconnect = this.batteryInfo.leftBattery < 0 && this.batteryInfo.rightBattery < 0 && this.batteryInfo.caseBattery < 0;
    // 断开连接时强制写入-1，确保卡片显示"--"
    let writeLeft: number = this.isConnected ? this.batteryInfo.leftBattery : -1;
    let writeRight: number = this.isConnected ? this.batteryInfo.rightBattery : -1;
    let writeCase: number = this.isConnected ? this.batteryInfo.caseBattery : -1;
    let writeLeftCharging: boolean = this.isConnected ? this.batteryInfo.leftCharging : false;
    let writeRightCharging: boolean = this.isConnected ? this.batteryInfo.rightCharging : false;
    let writeCaseCharging: boolean = this.isConnected ? this.batteryInfo.caseCharging : false;
    try {
      let pref = preferences.getPreferencesSync(OppoEarphoneManager.appContext, { name: 'battery_widget_data' });
      pref.putSync('leftBattery', writeLeft);
      pref.putSync('leftCharging', writeLeftCharging);
      pref.putSync('rightBattery', writeRight);
      pref.putSync('rightCharging', writeRightCharging);
      pref.putSync('caseBattery', writeCase);
      pref.putSync('caseCharging', writeCaseCharging);
      pref.putSync('connected', this.isConnected);
      let now = new Date();
      let timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
      pref.putSync('lastUpdated', timeStr);
      pref.putSync('dataTimestamp', now.getTime());
      // 必须等待 flush 完成，确保数据持久化到磁盘
      await pref.flush();
      console.info(`[OppoManager] 电量数据已写入Preferences: L=${this.batteryInfo.leftBattery} R=${this.batteryInfo.rightBattery} C=${this.batteryInfo.caseBattery} connected=${this.isConnected} isDisconnect=${isDisconnect}`);

      // 从文件读取 formId 列表（由 BatteryFormAbility 写入，绕过 Preferences 跨进程缓存）
      let formIds: string[] = this.readFormIdsFromFile();
      console.info(`[OppoManager] 读取到 ${formIds.length} 个formId`);

      // 逐个刷新卡片
      for (let i = 0; i < formIds.length; i++) {
        let formId = formIds[i];
        try {
          let widgetData = new WidgetBatteryData();
          widgetData.leftBattery = writeLeft;
          widgetData.leftCharging = writeLeftCharging;
          widgetData.rightBattery = writeRight;
          widgetData.rightCharging = writeRightCharging;
          widgetData.caseBattery = writeCase;
          widgetData.caseCharging = writeCaseCharging;
          widgetData.lastUpdated = timeStr;
          widgetData.connected = this.isConnected;
          let data = formBindingData.createFormBindingData(widgetData);
          await formProvider.updateForm(formId, data);
          console.info(`[OppoManager] 卡片已刷新: formId=${formId}`);
        } catch (updateErr) {
          console.warn(`[OppoManager] 刷新卡片失败: formId=${formId}, err=${(updateErr as BusinessError).message}`);
        }
      }
    } catch (err) {
      // 卡片刷新失败不影响主流程
      console.warn(`[OppoManager] 刷新桌面卡片失败: ${(err as BusinessError).message}`);
    }
  }

  /**
   * 从文件读取 formId 列表（绕过 Preferences 跨进程缓存）
   */
  private readFormIdsFromFile(): string[] {
    if (!OppoEarphoneManager.appContext) return [];
    try {
      let filePath = `${OppoEarphoneManager.appContext.filesDir}/form_ids.json`;
      if (fileIo.accessSync(filePath)) {
        let content: string = fileIo.readTextSync(filePath);
        if (content && content.length > 0) {
          let parsed: string[] = JSON.parse(content) as string[];
          return parsed;
        }
      }
    } catch (err) {
      console.warn(`[OppoManager] 读取formIds文件失败: ${(err as BusinessError).message}`);
    }
    return [];
  }

  /**
   * 通知原始HEX数据
   */
  private notifyRawData(data: Uint8Array): void {
    if (this.rawDataCallback) {
      let hexParts: string[] = [];
      for (let i = 0; i < data.length; i++) {
        let hex = data[i].toString(16).toUpperCase().padStart(2, '0');
        hexParts.push(hex);
      }
      let hexStr = hexParts.join(' ');
      this.rawDataCallback(hexStr);
    }
  }

  /**
   * 通知连接状态变化
   */
  private notifyStatus(status: ConnectionStatus): void {
    if (this.statusCallback) {
      this.statusCallback(status);
    }
  }

  /**
   * 解析 ANC 模式
   */
  private parseAncMode(data: Uint8Array): void {
    if (data.length < 9 || data[0] !== 0xAA) return;
    const cmdLow = data[4];
    const cmdHigh = data[5];
    const cmd = cmdLow | (cmdHigh << 8);
    if (cmd !== 0x810C && cmd !== 0x0204) return;
    const payLen = (data[7] | (data[8] << 8));
    const payloadStart = 9;
    if (data.length < payloadStart + payLen) return;
    if (cmd === 0x0204 && payLen > 0) {
      const reportType = data[payloadStart];
      if (reportType === 0x01 || reportType === 0x02 || reportType === 0x03) return;
    }
    const payloadEnd = Math.min(payloadStart + payLen, data.length);
    for (let i = payloadStart; i < payloadEnd - 2; i++) {
      if (data[i] === 0x01 && data[i + 1] === 0x01) {
        const val1 = data[i + 2];
        const val2 = (i + 3 < payloadEnd) ? data[i + 3] : 0x00;
        let mode = 1;
        console.info(`[OppoManager] ANC解析: val1=0x${val1.toString(16).padStart(2, '0')}, val2=0x${val2.toString(16).padStart(2, '0')}`);
        if (val1 === 0x02 && val2 === 0x00) mode = 2;
        else if (val1 === 0x04 && val2 === 0x00) mode = 3;
        else if (val1 === 0x00 && val2 === 0x01) mode = 3;
        else if (val1 === 0x00 && val2 === 0x08) mode = 4;
        else if (val1 === 0x80) mode = 5;
        else if (val1 === 0x40) mode = 6;
        else if (val1 === 0x20) mode = 7;
        else if (val1 === 0x10) mode = 8;
        else if (val1 === 0x01) mode = 1;
        if (this.currentAncMode !== mode) {
          this.currentAncMode = mode;
          this.notifyAncUpdate(mode);
          console.info(`[OppoManager] ANC模式变更: ${getAncModeName(mode)}`);
        }
        return;
      }
    }
  }

  /**
   * 解析佩戴状态
   */
  private parseWearStatus(data: Uint8Array): void {
    if (data.length < 9 || data[0] !== 0xAA) return;
    const cmdLow = data[4];
    const cmdHigh = data[5];
    const cmd = cmdLow | (cmdHigh << 8);
    if (cmd !== 0x0204) return;
    const payLen = (data[7] | (data[8] << 8));
    const payloadStart = 9;
    if (data.length < payloadStart + payLen || payLen < 2) return;
    const reportType = data[payloadStart];
    if (reportType !== 0x02) return;
    const count = data[payloadStart + 1];
    if (payLen < 2 + count * 2) return;
    let left = WearState.DISCONNECTED;
    let right = WearState.DISCONNECTED;
    let caseState = WearState.DISCONNECTED;
    for (let j = 0; j < count; j++) {
      const idx = payloadStart + 2 + j * 2;
      if (idx + 1 >= data.length) break;
      const component = data[idx];
      const state = data[idx + 1];
      switch (component) {
        case 0x01: left = state as WearState; break;
        case 0x02: right = state as WearState; break;
        case 0x03: caseState = state as WearState; break;
      }
    }
    const newStatus: WearStatus = { left, right, case: caseState };
    if (JSON.stringify(this.currentWearStatus) !== JSON.stringify(newStatus)) {
      const oldLeft = this.currentWearStatus.left;
      const oldRight = this.currentWearStatus.right;
      this.currentWearStatus = newStatus;
      this.notifyWearUpdate(newStatus);
      console.info(`[OppoManager] 佩戴状态: L=${left}, R=${right}, C=${caseState}`);
      // 佩戴状态发生重大变化时，设备会自动切换ANC模式但不会主动上报
      // 需延迟查询ANC状态以保持UI同步
      const wasWearing = (oldLeft === WearState.WEARING || oldRight === WearState.WEARING);
      const isNowWearing = (left === WearState.WEARING || right === WearState.WEARING);
      const wasNotWearing = (oldLeft !== WearState.WEARING && oldRight !== WearState.WEARING);
      const isNowNotWearing = (left !== WearState.WEARING && right !== WearState.WEARING);
      if ((wasWearing && isNowNotWearing) || (wasNotWearing && isNowWearing)) {
        if (wasWearing && isNowNotWearing) {
          console.info('[OppoManager] 耳机入盒/取下，延迟查询ANC状态...');
        } else {
          console.info('[OppoManager] 耳机重新佩戴，延迟查询ANC状态...');
        }
        setTimeout(() => {
          this.queryAncMode();
        }, 1000);
      }
    }
  }

  /**
   * 解析游戏模式（cmd=0x810D 响应，扫描 0x28 游戏模式 和 0x1B 空间音频特征）
   */
  private parseGameMode(data: Uint8Array): void {
    if (data.length < 9 || data[0] !== 0xAA) return;
    const cmdLow = data[4];
    const cmdHigh = data[5];
    const cmd = cmdLow | (cmdHigh << 8);
    if (cmd !== 0x810D) return;
    const payLen = (data[7] | (data[8] << 8));
    const payloadStart = 9;
    if (data.length < payloadStart + payLen) return;
    if (payLen < 4) {
      console.info(`[OppoManager] parseGameMode 简短响应，跳过 (payLen=${payLen})`);
      return;
    }
    for (let i = payloadStart; i < payloadStart + payLen - 1; i++) {
      if (data[i] === 0x28) {
        const enabled = data[i + 1] === 0x01;
        console.info(`[OppoManager] parseGameMode 找到 0x28 特征值，游戏模式=${enabled ? '开启' : '关闭'}`);
        if (this.gameModeEnabled !== enabled) {
          this.gameModeEnabled = enabled;
          this.notifyGameModeUpdate(enabled);
          console.info(`[OppoManager] 游戏模式: ${enabled ? '开启' : '关闭'}`);
        }
      }
      if (data[i] === 0x1B) {
        const enabled = data[i + 1] === 0x01;
        console.info(`[OppoManager] parseGameMode 找到 0x1B 特征值，空间音频=${enabled ? '开启' : '关闭'}`);
        if (this.spatialAudioEnabled !== enabled) {
          this.spatialAudioEnabled = enabled;
          this.notifySpatialAudioUpdate(enabled);
          console.info(`[OppoManager] 空间音频: ${enabled ? '开启' : '关闭'}`);
        }
      }
    }
  }

  /**
   * 解析空间音频通知（cmd=0x0510 主动上报 和 cmd=0x8422 设置响应）
   */
  private parseSpatialAudio(data: Uint8Array): void {
    if (data.length < 9 || data[0] !== 0xAA) return;
    const cmdLow = data[4];
    const cmdHigh = data[5];
    const cmd = cmdLow | (cmdHigh << 8);
    const payLen = (data[7] | (data[8] << 8));
    const payloadStart = 9;
    if (data.length < payloadStart + payLen || payLen < 1) return;
    // 0x0510 = 空间音频模式主动通知，payload[0] = mode（0=关, 1=固定, 2=头部追踪）
    if (cmd === 0x0510) {
      const mode = data[payloadStart];
      const enabled = mode !== 0x00;
      console.info(`[OppoManager] 空间音频通知(0x0510): mode=${mode}, 开启=${enabled}`);
      if (this.spatialAudioEnabled !== enabled) {
        this.spatialAudioEnabled = enabled;
        this.notifySpatialAudioUpdate(enabled);
      }
    }
    // 0x8422 = 空间音频设置响应（专用指令），payload[0] = mode
    if (cmd === 0x8422) {
      const mode = data[payloadStart];
      const enabled = mode !== 0x00;
      console.info(`[OppoManager] 空间音频设置响应(0x8422): mode=${mode}, 开启=${enabled}`);
      if (this.spatialAudioEnabled !== enabled) {
        this.spatialAudioEnabled = enabled;
        this.notifySpatialAudioUpdate(enabled);
      }
    }
    // 0x8403 = 特征开关响应，扫描 0x1B 空间音效特征
    if (cmd === 0x8403 && payLen >= 2) {
      for (let i = payloadStart; i < payloadStart + payLen - 1; i++) {
        if (data[i] === 0x1B) {
          const enabled = data[i + 1] === 0x01;
          console.info(`[OppoManager] 空间音频开关响应(0x8403,0x1B): ${enabled ? '开启' : '关闭'}`);
          if (this.spatialAudioEnabled !== enabled) {
            this.spatialAudioEnabled = enabled;
            this.notifySpatialAudioUpdate(enabled);
          }
        }
      }
    }
  }

  // ============== 后台卡片刷新 ==============

  /**
   * 后台刷新桌面卡片电量（由WorkSchedulerExtension调用）
   * 流程：读取已保存MAC → 静默SPP连接 → 发送电量查询 → 等待响应 → 写入Preferences → 刷新卡片 → 断开
   */
  refreshWidgetInBackground(): void {
    console.info('[OppoManager] 后台卡片刷新开始');

    // 如果已有活跃连接（主应用正在运行），跳过
    if (this.isConnected) {
      console.info('[OppoManager] 已有活跃连接，跳过后台刷新');
      return;
    }

    // 读取保存的MAC地址
    let mac = this.savedMac;
    if (!mac && OppoEarphoneManager.appContext) {
      try {
        let pref = preferences.getPreferencesSync(OppoEarphoneManager.appContext, { name: 'battery_widget_data' });
        mac = pref.getSync('savedMac', '') as string;
        if (mac) {
          this.savedMac = mac;
        }
      } catch (e) {
        // 忽略
      }
    }

    if (!mac) {
      console.info('[OppoManager] 后台刷新: 无已保存MAC地址，跳过');
      return;
    }

    console.info(`[OppoManager] 后台刷新: 尝试连接 ${mac}`);
    this.connectForBackgroundQuery(mac);
  }

  /**
   * 静默SPP连接并查询电量（后台专用）
   * 不触发UI状态回调，不影响主界面显示
   */
  private connectForBackgroundQuery(macAddress: string): void {
    try {
      let sppOption: socket.SppOptions = {
        uuid: this.RFCOMM_UUID,
        secure: false,
        type: socket.SppType.SPP_RFCOMM
      };

      socket.sppConnect(macAddress, sppOption, (err: BusinessError, clientNum: number) => {
        if (err) {
          console.warn(`[OppoManager] 后台SPP连接失败: ${err.message}`);
          return;
        }

        console.info(`[OppoManager] 后台SPP连接成功: clientNum=${clientNum}`);
        this.sppClientNumber = clientNum;
        this.isConnected = true;

        // 标记已收到所有电量（用于判断是否可以断开）
        let allBatteriesReceived: boolean = false;

        // 超时保护：12秒后强制断开
        let bgTimeout: number = setTimeout(() => {
          console.warn('[OppoManager] 后台查询超时，强制断开');
          allBatteriesReceived = true;
          this.disconnectSilently();
          // 超时时不更新卡片，保留上次有效数据
          if (this.batteryInfo.leftBattery >= 0 || this.batteryInfo.rightBattery >= 0 ||
              this.batteryInfo.caseBattery >= 0) {
            this.saveBatteryToWidget();
          }
        }, 12000);

        // 注册数据接收监听
        try {
          socket.on('sppRead', clientNum, (dataBuffer: ArrayBuffer) => {
            let valueArray = new Uint8Array(dataBuffer);
            if (valueArray.length >= 9 && valueArray[0] === 0xAA) {
              const cmdLow = valueArray[4];
              const cmdHigh = valueArray[5];
              const cmd = cmdLow | (cmdHigh << 8);
              console.info(`[OppoManager] 后台接收: cmd=0x${cmd.toString(16)}, 长度=${valueArray.length}`);
            }
            // 解析电量数据
            this.parseOppoBattery(valueArray);

            // 检查是否三个电量都已获取
            if (this.batteryInfo.leftBattery >= 0 && this.batteryInfo.rightBattery >= 0 &&
                this.batteryInfo.caseBattery >= 0 && !allBatteriesReceived) {
              allBatteriesReceived = true;
              clearTimeout(bgTimeout);
              console.info('[OppoManager] 后台电量获取完成，断开连接并更新卡片');
              this.disconnectSilently();
              this.saveBatteryToWidget();
            }
          });
        } catch (readErr) {
          let error = readErr as BusinessError;
          console.error(`[OppoManager] 后台注册sppRead失败: ${error.message}`);
        }

        // 发送使能状态报告和电量查询
        setTimeout(() => {
          this.enableStatusReport();
          setTimeout(() => {
            this.queryBattery();
          }, 200);
        }, 300);
      });
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[OppoManager] 后台SPP连接异常: ${error.message}`);
    }
  }

  /**
   * 静默断开SPP连接（不影响UI状态，不触发卡片更新）
   */
  private disconnectSilently(): void {
    if (this.sppClientNumber >= 0) {
      try {
        socket.off('sppRead', this.sppClientNumber);
      } catch (e) {
        // 忽略
      }
      try {
        socket.sppCloseClientSocket(this.sppClientNumber);
      } catch (e) {
        // 忽略
      }
      this.sppClientNumber = -1;
    }
    this.isConnected = false;
    console.info('[OppoManager] 后台静默断开完成');
  }

  // ============== 后台保活 + 常驻通知 ==============

  /**
   * 启动后台保活任务并发布常驻通知
   * 连接成功后调用，确保应用退后台后SPP连接不断
   * 仅在用户开启“常驻通知”开关时执行
   */
  startBackgroundService(): void {
    if (this.isBackgroundTaskRunning || !OppoEarphoneManager.appContext) return;
    // 检查用户是否开启了常驻通知开关
    try {
      let pref = preferences.getPreferencesSync(OppoEarphoneManager.appContext, { name: 'app_settings' });
      let enabled = pref.getSync('persistentNotifyEnabled', false) as boolean;
      if (!enabled) {
        console.info('[OppoManager] 常驻通知未开启，跳过后台保活');
        return;
      }
    } catch (e) {
      console.warn('[OppoManager] 读取通知设置失败');
      return;
    }
    try {
      let context = OppoEarphoneManager.appContext;
      // 创建 wantAgent，点击通知时打开主界面
      let wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: 'com.hzx.encoair',
          abilityName: 'EntryAbility'
        } as Want],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      wantAgent.getWantAgent(wantAgentInfo).then((agent: WantAgent) => {
        backgroundTaskManager.startBackgroundRunning(context,
          backgroundTaskManager.BackgroundMode.BLUETOOTH_INTERACTION, agent)
          .then(() => {
            this.isBackgroundTaskRunning = true;
            console.info('[OppoManager] 后台保活任务已启动');
            this.publishOrUpdateNotification();
          })
          .catch((err: BusinessError) => {
            console.error(`[OppoManager] 启动后台任务失败: ${err.code} ${err.message}`);
          });
      });
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[OppoManager] startBackgroundService 异常: ${error.message}`);
    }
  }

  /**
   * 停止后台保活任务并移除通知
   * 断开连接时调用
   */
  stopBackgroundService(): void {
    if (!this.isBackgroundTaskRunning || !OppoEarphoneManager.appContext) return;
    try {
      backgroundTaskManager.stopBackgroundRunning(OppoEarphoneManager.appContext)
        .then(() => {
          this.isBackgroundTaskRunning = false;
          console.info('[OppoManager] 后台保活任务已停止');
        })
        .catch((err: BusinessError) => {
          console.error(`[OppoManager] 停止后台任务失败: ${err.code} ${err.message}`);
        });
      // 取消通知
      notificationManager.cancel(OppoEarphoneManager.NOTIFICATION_ID);
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[OppoManager] stopBackgroundService 异常: ${error.message}`);
    }
  }

  /**
   * 发布或更新常驻通知
   * 显示电量和ANC状态
   */
  publishOrUpdateNotification(): void {
    // 先检查通知权限是否仍然有效
    try {
      if (!notificationManager.isNotificationEnabledSync()) {
        console.warn('[OppoManager] 通知权限已被禁用，停止后台服务');
        this.stopBackgroundService();
        return;
      }
    } catch (e) {
      // 检查失败时继续尝试发布
    }
    try {
      let ancName = getAncModeName(this.currentAncMode);
      let l = this.batteryInfo.leftBattery >= 0 ? `${this.batteryInfo.leftBattery}%` : '--';
      let r = this.batteryInfo.rightBattery >= 0 ? `${this.batteryInfo.rightBattery}%` : '--';
      let c = this.batteryInfo.caseBattery >= 0 ? `${this.batteryInfo.caseBattery}%` : '--';
      let chargingL = this.batteryInfo.leftCharging ? '⚡' : '';
      let chargingR = this.batteryInfo.rightCharging ? '⚡' : '';
      let chargingC = this.batteryInfo.caseCharging ? '⚡' : '';

      let title = `Air5 Pro 已连接 | ANC: ${ancName}`;
      let text = `左耳 ${l}${chargingL}  右耳 ${r}${chargingR}  仓 ${c}${chargingC}`;

      let notification: notificationManager.NotificationRequest = {
        id: OppoEarphoneManager.NOTIFICATION_ID,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: text,
            additionalText: 'Air5 Pro 耳机助手'
          }
        },
        isOngoing: true,
        isAlertOnce: true
      };
      notificationManager.publish(notification);
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[OppoManager] 发布通知失败: ${error.message}`);
    }
  }
}
