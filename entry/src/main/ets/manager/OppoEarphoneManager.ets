import { ble } from '@kit.ConnectivityKit';

import { BusinessError } from '@kit.BasicServicesKit';



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

 * OPPO 蓝牙耳机电量管理器

 * 负责蓝牙扫描、GATT连接、服务发现和电量数据解析

 */

export class OppoEarphoneManager {

  // OPPO Enco Air5 Pro 固定的服务和特征 UUID

  private SERVICE_UUID: string = '0000079a-d102-11e1-9b23-00025b00a5a5';

  private NOTIFY_CHAR_UUID: string = '0200079a-d102-11e1-9b23-00025b00a5a5';

  private WRITE_CHAR_UUID: string = '0100079a-d102-11e1-9b23-00025b00a5a5';

  private TARGET_DEVICE_NAME: string = 'OPPO Enco Air5 Pro';



  // 连接状态常量（ProfileConnectionState 已移除，使用数值常量）

  private readonly STATE_CONNECTED: number = 2;

  private readonly STATE_DISCONNECTED: number = 0;



  private gattClient: ble.GattClientDevice | null = null;

  private isScanning: boolean = false;

  private connectedMac: string = '';

  private isSubscribed: boolean = false;

  // 自动连接相关
  private savedMac: string = ''; // 保存上次成功连接的MAC地址
  private autoReconnectTimer: number = -1;
  private reconnectAttempts: number = 0;
  private readonly MAX_RECONNECT_ATTEMPTS: number = 5;
  private readonly RECONNECT_DELAY_MS: number = 3000; // 重连延迟3秒
  
  // 持续监听相关
  private continuousMonitorTimer: number = -1;
  private readonly MONITOR_INTERVAL_MS: number = 5000; // 每5秒扫描一次
  private isMonitorRunning: boolean = false;

  // 回调函数

  private batteryCallback: ((info: BatteryInfo) => void) | null = null;

  private statusCallback: ((status: ConnectionStatus) => void) | null = null;

  private rawDataCallback: ((hex: string) => void) | null = null;
  private ancCallback: ((mode: number) => void) | null = null;
  private wearCallback: ((wear: WearStatus) => void) | null = null;
  private gameModeCallback: ((enabled: boolean) => void) | null = null;



  // 当前电量状态

  private batteryInfo: BatteryInfo = {

    leftBattery: -1,

    leftCharging: false,

    rightBattery: -1,

    rightCharging: false,

    caseBattery: -1,

    caseCharging: false

  };



  // 当前ANC模式 (1=关闭, 2=降噪, 3=通透, 4=自适应)

  private currentAncMode: number = 1;



  // 当前佩戴状态

  private currentWearStatus: WearStatus = {

    left: WearState.DISCONNECTED,

    right: WearState.DISCONNECTED,

    case: WearState.DISCONNECTED

  };



  // 游戏模式状态

  private gameModeEnabled: boolean = false;



  // 定时查询定时器

  private queryTimer: number = -1;



  /**

   * 设置回调函数

   * @param batteryCb 电量更新回调

   * @param statusCb 连接状态变化回调

   */

  setCallbacks(batteryCb: (info: BatteryInfo) => void, statusCb: (status: ConnectionStatus) => void, rawCb?: (hex: string) => void,
    ancCb?: (mode: number) => void, wearCb?: (wear: WearStatus) => void, gameCb?: (enabled: boolean) => void): void {

    this.batteryCallback = batteryCb;

    this.statusCallback = statusCb;

    this.rawDataCallback = rawCb ?? null;

    this.ancCallback = ancCb ?? null;

    this.wearCallback = wearCb ?? null;

    this.gameModeCallback = gameCb ?? null;

  }


  /**
   * 启动持续监听模式(应用启动时调用)
   * 持续扫描蓝牙设备,发现OPPO耳机立即连接
   */
  startContinuousMonitor(): void {
    if (this.isMonitorRunning) {
      console.info('[OppoManager] 监听已在运行中');
      return;
    }
    
    console.info('[OppoManager] 启动持续监听模式...');
    this.isMonitorRunning = true;
    
    // 如果已有保存的设备,优先尝试连接
    if (this.savedMac) {
      console.info(`[OppoManager] 发现已保存设备,优先连接: ${this.savedMac}`);
      this.connectToEarphone(this.savedMac);
    }
    
    // 启动周期性扫描
    this.startMonitorCycle();
  }


  /**
   * 执行一次扫描周期
   */
  private startMonitorCycle(): void {
    if (!this.isMonitorRunning) return;
    
    // 如果已连接,不需要扫描
    if (this.connectedMac || this.isScanning) {
      console.info('[OppoManager] 已连接或正在扫描,跳过本次扫描');
      this.scheduleNextMonitorCycle();
      return;
    }
    
    console.info('[OppoManager] 开始监听扫描...');
    this.notifyStatus('scanning');
    
    // 设置扫描超时(10秒后停止本次扫描)
    const scanTimeout = setTimeout(() => {
      if (this.isScanning) {
        console.info('[OppoManager] 监听扫描超时,停止本次扫描');
        this.stopScan();
        this.notifyStatus('disconnected');
      }
    }, 10000);
    
    // 监听扫描结果
    ble.on('BLEDeviceFind', (devices: Array<ble.ScanResult>) => {
      for (let device of devices) {
        let deviceName = device.deviceName;
        let deviceMac = device.deviceId;

        // 发现OPPO耳机立即连接
        if (deviceName && deviceName.includes('OPPO Enco')) {
          console.info(`[OppoManager] 监听到OPPO耳机! 名字: ${deviceName}, MAC: ${deviceMac}`);
          clearTimeout(scanTimeout); // 取消超时定时器
          this.stopScan();
          this.connectToEarphone(deviceMac);
          break;
        }
      }
    });

    // 启动扫描
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
   * 启动自动连接(应用启动时调用)
   * 优先尝试连接上次成功的设备,如果没有则扫描新设备
   */
  startAutoConnect(): void {
    console.info('[OppoManager] 启动自动连接...');
    
    // 如果有保存的MAC地址,优先尝试直连
    if (this.savedMac) {
      console.info(`[OppoManager] 尝试连接已保存设备: ${this.savedMac}`);
      this.connectToEarphone(this.savedMac);
    } else {
      // 没有保存的设备,开始扫描
      console.info('[OppoManager] 无已保存设备,开始扫描...');
      this.startScan();
    }
  }


  /**
   * 保存已连接的设备MAC(连接成功后自动调用)
   */
  private saveConnectedMac(mac: string): void {
    this.savedMac = mac;
    console.info(`[OppoManager] 保存设备MAC: ${mac}`);
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
        this.startScan();
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

   * 发送 GATT 写入指令

   */

  private sendPacket(packet: Uint8Array): void {

    if (!this.gattClient || !this.isSubscribed) {

      console.warn('[OppoManager] 未连接或未订阅，无法发送指令');

      return;

    }



    const characteristic: ble.BLECharacteristic = {

      serviceUuid: this.SERVICE_UUID,

      characteristicUuid: this.WRITE_CHAR_UUID,

      characteristicValue: packet.buffer,

      descriptors: []

    };



    this.gattClient.writeCharacteristicValue(characteristic, ble.GattWriteType.WRITE_NO_RESPONSE, (err) => {

      if (err) {

        console.error(`[OppoManager] 写入失败: ${JSON.stringify(err)}`);

      } else {

        console.info(`[OppoManager] 指令发送成功: ${this.toHexStr(packet)}`);

      }

    });

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

    // 参考 OppoPods：不立即更新 UI，等待设备响应后由 parseAncMode 更新

    // 延迟查询设备状态，确保 UI 与设备实际状态同步

    setTimeout(() => {

      this.queryAncMode();

    }, 350);

  }



  /**

   * 查询游戏模式

   */

  queryGameMode(): void {

    // 通过查询状态来获取游戏模式

    const packet = this.buildPacket(0x010D, 0x00, []);

    this.sendPacket(packet);

  }



  /**

   * 设置游戏模式

   */

  setGameMode(enabled: boolean): void {

    // 参考 OppoPods：立即更新UI，不等待响应

    this.gameModeEnabled = enabled;

    this.notifyGameModeUpdate(enabled);

    // 发送协议指令

    const payload: number[] = [0x28, enabled ? 0x01 : 0x00];

    const packet = this.buildPacket(0x0403, 0x00, payload);

    this.sendPacket(packet);

    console.info(`[OppoManager] 发送游戏模式切换指令: ${enabled ? '开启' : '关闭'}`);

    // 延迟查询设备状态进行验证

    setTimeout(() => {

      this.queryGameMode();

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

  }



  private notifyWearUpdate(wear: WearStatus): void {

    if (this.wearCallback) this.wearCallback(wear);

  }



  private notifyGameModeUpdate(enabled: boolean): void {

    if (this.gameModeCallback) this.gameModeCallback(enabled);

  }



  /**

   * 开始扫描周围的 OPPO 耳机

   */

  startScan(): void {

    if (this.isScanning) {

      return;

    }



    console.info('[OppoManager] 开始扫描周围的 OPPO 耳机...');

    this.notifyStatus('scanning');

    this.isScanning = true;

    this.cancelReconnect(); // 扫描时取消重连



    // 监听扫描结果

    ble.on('BLEDeviceFind', (devices: Array<ble.ScanResult>) => {

      for (let device of devices) {

        let deviceName = device.deviceName;

        let deviceMac = device.deviceId;



        // 通过名字模糊匹配市面上所有的该型号耳机

        if (deviceName && deviceName.includes('OPPO Enco')) {

          console.info(`[OppoManager] 发现目标耳机! 名字: ${deviceName}, MAC: ${deviceMac}`);

          this.stopScan();

          this.connectToEarphone(deviceMac);

          break;

        }

      }

    });



    // 启动低延迟扫描

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

    if (!this.isScanning) {

      return;

    }

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

   */

  disconnect(): void {
    this.stopContinuousMonitor(); // 停止监听
    this.stopPeriodicQuery();
    this.cancelReconnect(); // 取消重连
    this.cleanup();

    this.notifyStatus('disconnected');

  }



  // ============== 私有方法 ==============



  /**

   * 连接到耳机

   */

  private connectToEarphone(macAddress: string): void {

    this.connectedMac = macAddress;

    this.notifyStatus('connecting');

    console.info(`[OppoManager] 正在连接耳机 [${macAddress}]...`);



    try {

      this.gattClient = ble.createGattClientDevice(macAddress);

      console.info(`[OppoManager] GATT客户端创建成功`);



      // 监听连接状态变化

      this.gattClient.on('BLEConnectionStateChange', (state: ble.BLEConnectionChangeState) => {

        console.info(`[OppoManager] 连接状态变化: state=${state.state}, deviceId=${state.deviceId}`);

        if (state.state === this.STATE_CONNECTED) {

          console.info(`[OppoManager] 成功连接到耳机 [${macAddress}]`);

          this.saveConnectedMac(macAddress); // 保存成功连接的MAC

          this.reconnectAttempts = 0; // 重置重连计数

          this.notifyStatus('connected');

          this.discoverServices();

        } else if (state.state === this.STATE_DISCONNECTED) {

          console.info('[OppoManager] 耳机断开连接');

          this.cleanup();

          this.notifyStatus('disconnected');
          
          // 如果监听还在运行,重新开始监听周期
          if (this.isMonitorRunning) {
            console.info('[OppoManager] 监听模式:断开后继续监听');
            this.scheduleNextMonitorCycle();
          } else {
            // 否则尝试自动重连
            this.scheduleReconnect();
          }
        }

      });



      console.info(`[OppoManager] 调用 gattClient.connect()...`);

      this.gattClient.connect();

      console.info(`[OppoManager] gattClient.connect() 调用完成`);

    } catch (err) {

      let error = err as BusinessError;

      console.error(`[OppoManager] 连接失败: ${error.message}, code=${error.code}`);

      this.notifyStatus('disconnected');

    }

  }



  /**

   * 发现 GATT 服务

   */

  private discoverServices(): void {

    if (!this.gattClient) {

      return;

    }



    this.gattClient.getServices((error, gattServices) => {

      if (error) {

        console.error(`[OppoManager] 发现服务失败: ${JSON.stringify(error)}`);

        return;

      }



      // 检查目标服务是否存在

      let found = false;

      if (gattServices) {

        for (let service of gattServices) {

          if (service.serviceUuid === this.SERVICE_UUID) {

            found = true;

            console.info('[OppoManager] 找到目标电量服务');

            break;

          }

        }

      }



      if (!found) {

        console.warn('[OppoManager] 未找到目标服务 UUID，仍尝试订阅');

      }



      this.subscribeBatteryNotifications();

    });

  }



  /**

   * 订阅电量特征值通知

   */

  private subscribeBatteryNotifications(): void {

    if (!this.gattClient) {

      return;

    }



    let characteristic: ble.BLECharacteristic = {

      serviceUuid: this.SERVICE_UUID,

      characteristicUuid: this.NOTIFY_CHAR_UUID,

      characteristicValue: new ArrayBuffer(0),

      descriptors: []

    };



    // 监听特征值变化

    this.gattClient.on('BLECharacteristicChange', (charChange: ble.BLECharacteristic) => {

      let valueArray = new Uint8Array(charChange.characteristicValue);

      // 打印接收到的数据（用于调试）
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

    });



    // 开启通知订阅

    this.gattClient.setCharacteristicChangeNotification(characteristic, true, (err: BusinessError) => {

      if (err) {

        console.error(`[OppoManager] 订阅电量通知失败: ${JSON.stringify(err)}`);

      } else {

        console.info('[OppoManager] 电量监听订阅成功！');

        this.isSubscribed = true;

        this.notifyStatus('subscribed');

        // 连接成功后启动查询

        setTimeout(() => {

          this.enableStatusReport();

          setTimeout(() => {

            this.queryStatus();

            setTimeout(() => {

              this.queryBattery();

              this.queryAncMode();

              this.queryGameMode();

              this.startPeriodicQuery();

            }, 200);

          }, 200);

        }, 300);

      }

    });

  }



  /**
   * 核心逆向算法最新升级版（完美兼容官方协议及复杂前置序列）
   */
  private parseOppoBattery(data: Uint8Array): void {
    let updated = false;

    // 健壮性检查
    if (data.length < 9 || data[0] !== 0xAA) return;

    // 解析命令字段 (小端序)
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
            case 0x01: // 左耳
              if (this.batteryInfo.leftBattery !== battery || this.batteryInfo.leftCharging !== charging) {
                this.batteryInfo.leftBattery = battery;
                this.batteryInfo.leftCharging = charging;
                updated = true;
              }
              break;
            case 0x02: // 右耳
              if (this.batteryInfo.rightBattery !== battery || this.batteryInfo.rightCharging !== charging) {
                this.batteryInfo.rightBattery = battery;
                this.batteryInfo.rightCharging = charging;
                updated = true;
              }
              break;
            case 0x03: // 充电仓
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
      if (reportType !== 0x01) return; // 不是电量报告

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

    // 有更新时通知 UI
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

   * 清理 GATT 连接资源

   */

  private cleanup(): void {

    if (this.gattClient) {

      try {

        this.gattClient.off('BLEConnectionStateChange');

        this.gattClient.off('BLECharacteristicChange');

        this.gattClient.disconnect();

        this.gattClient.close();

      } catch (err) {

        let error = err as BusinessError;

        console.error(`[OppoManager] 清理连接失败: ${error.message}`);

      }

      this.gattClient = null;

    }



    this.connectedMac = '';

    this.isSubscribed = false;



    // 重置电量信息

    this.batteryInfo = {

      leftBattery: -1,

      leftCharging: false,

      rightBattery: -1,

      rightCharging: false,

      caseBattery: -1,

      caseCharging: false

    };

    this.notifyBatteryUpdate();

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

    // 对于0x0204主动上报，需要过滤电量和佩戴状态报告
    if (cmd === 0x0204 && payLen > 0) {

      const reportType = data[payloadStart];

      // 0x01=电量报告, 0x02=佩戴状态报告, 0x03=其他状态（非ANC）
      if (reportType === 0x01 || reportType === 0x02 || reportType === 0x03) return;

    }

    const payloadEnd = Math.min(payloadStart + payLen, data.length);

    for (let i = payloadStart; i < payloadEnd - 2; i++) {

      if (data[i] === 0x01 && data[i + 1] === 0x01) {

        const val1 = data[i + 2];

        const val2 = (i + 3 < payloadEnd) ? data[i + 3] : 0x00;

        let mode = 1;

        // 调试日志：输出原始值
        console.info(`[OppoManager] ANC解析: val1=0x${val1.toString(16).padStart(2, '0')}, val2=0x${val2.toString(16).padStart(2, '0')}`);

        if (val1 === 0x02 && val2 === 0x00) mode = 2;

        else if (val1 === 0x04 && val2 === 0x00) mode = 3;

        else if (val1 === 0x00 && val2 === 0x01) mode = 3;  // 通透模式（OPPO Enco Air5 Pro）

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

      this.currentWearStatus = newStatus;

      this.notifyWearUpdate(newStatus);

      console.info(`[OppoManager] 佩戴状态: L=${left}, R=${right}, C=${caseState}`);

    }

  }



  /**

   * 解析游戏模式

   */

  private parseGameMode(data: Uint8Array): void {

    if (data.length < 9 || data[0] !== 0xAA) return;

    const cmdLow = data[4];

    const cmdHigh = data[5];

    const cmd = cmdLow | (cmdHigh << 8);

    // 只处理 0x810D（状态查询响应），0x8403 只是确认响应不包含状态

    if (cmd !== 0x810D) return;

    const payLen = (data[7] | (data[8] << 8));

    const payloadStart = 9;

    if (data.length < payloadStart + payLen) return;

    // 如果payload太短（<4字节），说明是简短响应，不包含完整特征值

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

        return;

      }

    }

  }

}
