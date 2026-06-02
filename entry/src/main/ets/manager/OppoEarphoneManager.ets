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

 * OPPO 蓝牙耳机电量管理器

 * 负责蓝牙扫描、GATT连接、服务发现和电量数据解析

 */

export class OppoEarphoneManager {

  // OPPO Enco Air5 Pro 固定的服务和特征 UUID

  private SERVICE_UUID: string = '0000079a-d102-11e1-9b23-00025b00a5a5';

  private NOTIFY_CHAR_UUID: string = '0200079a-d102-11e1-9b23-00025b00a5a5';

  private TARGET_DEVICE_NAME: string = 'OPPO Enco Air5 Pro';



  // 连接状态常量（ProfileConnectionState 已移除，使用数值常量）

  private readonly STATE_CONNECTED: number = 2;

  private readonly STATE_DISCONNECTED: number = 0;



  private gattClient: ble.GattClientDevice | null = null;

  private isScanning: boolean = false;

  private connectedMac: string = '';



  // 回调函数

  private batteryCallback: ((info: BatteryInfo) => void) | null = null;

  private statusCallback: ((status: ConnectionStatus) => void) | null = null;

  private rawDataCallback: ((hex: string) => void) | null = null;



  // 当前电量状态

  private batteryInfo: BatteryInfo = {

    leftBattery: -1,

    leftCharging: false,

    rightBattery: -1,

    rightCharging: false,

    caseBattery: -1,

    caseCharging: false

  };



  /**

   * 设置回调函数

   * @param batteryCb 电量更新回调

   * @param statusCb 连接状态变化回调

   */

  setCallbacks(batteryCb: (info: BatteryInfo) => void, statusCb: (status: ConnectionStatus) => void, rawCb?: (hex: string) => void): void {

    this.batteryCallback = batteryCb;

    this.statusCallback = statusCb;

    this.rawDataCallback = rawCb ?? null;

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



    // 监听扫描结果

    ble.on('BLEDeviceFind', (devices: Array<ble.ScanResult>) => {

      for (let device of devices) {

        let deviceName = device.deviceName;

        let deviceMac = device.deviceId;



        // 通过名字模糊匹配市面上所有的该型号耳机

        if (deviceName && deviceName.includes(this.TARGET_DEVICE_NAME)) {

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

    this.stopScan();

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



    try {

      this.gattClient = ble.createGattClientDevice(macAddress);



      // 监听连接状态变化

      this.gattClient.on('BLEConnectionStateChange', (state: ble.BLEConnectionChangeState) => {

        if (state.state === this.STATE_CONNECTED) {

          console.info(`[OppoManager] 成功连接到耳机 [${macAddress}]`);

          this.notifyStatus('connected');

          this.discoverServices();

        } else if (state.state === this.STATE_DISCONNECTED) {

          console.info('[OppoManager] 耳机断开连接');

          this.cleanup();

          this.notifyStatus('disconnected');

        }

      });



      this.gattClient.connect();

    } catch (err) {

      let error = err as BusinessError;

      console.error(`[OppoManager] 连接失败: ${error.message}`);

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

      // 通知原始HEX数据

      this.notifyRawData(valueArray);

      this.parseOppoBattery(valueArray);

    });



    // 开启通知订阅

    this.gattClient.setCharacteristicChangeNotification(characteristic, true, (err: BusinessError) => {

      if (err) {

        console.error(`[OppoManager] 订阅电量通知失败: ${JSON.stringify(err)}`);

      } else {

        console.info('[OppoManager] 电量监听订阅成功！');

        this.notifyStatus('subscribed');

      }

    });

  }



  /**
   * 核心逆向算法最新升级版（完美兼容 70% 等非满电状态及复杂前置序列）
   */
  private parseOppoBattery(data: Uint8Array): void {
    let updated = false;

    // 健壮性检查
    if (data.length < 5 || data[0] !== 0xAA) return;

    for (let i = 1; i < data.length - 1; i++) {
      let deviceType = data[i];
      let rawVal = data[i + 1];

      // === 1. 解析左耳 (0x01) ===
      if (deviceType === 0x01) {
        // 规避前置引导序列（如果 0x01 后面紧跟的是 0x03 类似的分发码，说明它不是电量值，跳过）
        if (rawVal === 0x03 || rawVal === 0x04) {
          continue;
        }

        // 处理离线/仓外拿走标记
        if (rawVal === 0x00 || rawVal === 0x05) {
          if (this.batteryInfo.leftBattery !== -1) {
            this.batteryInfo.leftBattery = -1; // 界面置为未知/离线
            this.batteryInfo.leftCharging = false;
            updated = true;
          }
          continue;
        }

        // 正常电量解析
        let charging = rawVal > 100;
        let battery = charging ? rawVal - 0x80 : rawVal;
        if (battery >= 0 && battery <= 100) {
          this.batteryInfo.leftBattery = battery;
          this.batteryInfo.leftCharging = charging;
          console.info(`[OppoManager] 动态捕获 L 耳电量: ${battery}% ${charging ? '(在仓充电)' : '(仓外使用)'}`);
          updated = true;
        }
      }

      // === 2. 解析右耳 (0x02) ===
      if (deviceType === 0x02) {
        if (rawVal === 0x03 || rawVal === 0x04) {
          continue;
        }

        if (rawVal === 0x00 || rawVal === 0x05) {
          if (this.batteryInfo.rightBattery !== -1) {
            this.batteryInfo.rightBattery = -1;
            this.batteryInfo.rightCharging = false;
            updated = true;
          }
          continue;
        }

        let charging = rawVal > 100;
        let battery = charging ? rawVal - 0x80 : rawVal;
        if (battery >= 0 && battery <= 100) {
          this.batteryInfo.rightBattery = battery;
          this.batteryInfo.rightCharging = charging;
          console.info(`[OppoManager] 动态捕获 R 耳电量: ${battery}% ${charging ? '(在仓充电)' : '(仓外使用)'}`);
          updated = true;
        }
      }

      // === 3. 解析充电仓 (0x03) ===
      if (deviceType === 0x03) {
        if (rawVal === 0x04) {
          continue; // 跳过索引包中的握手码
        }

        if (rawVal === 0x00) {
          if (this.batteryInfo.caseBattery !== -1) {
            this.batteryInfo.caseBattery = -1;
            this.batteryInfo.caseCharging = false;
            updated = true;
          }
          continue;
        }

        let charging = rawVal > 128; // 预留充电仓插线充电的可能（最高位拉高）
        let battery = charging ? rawVal - 0x80 : rawVal;
        if (battery >= 0 && battery <= 100) {
          this.batteryInfo.caseBattery = battery;
          this.batteryInfo.caseCharging = charging;
          console.info(`[OppoManager] 动态捕获 充电仓电量: ${battery}% ${charging ? '(充电仓充电中)' : ''}`);
          updated = true;
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

}

