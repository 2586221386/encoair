import { ble, socket, connection, constant } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { formProvider, formBindingData } from '@kit.FormKit';
import { common, wantAgent, WantAgent, Want } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { detectDeviceCapabilities, DeviceCapabilities, CapabilityOverrides, CAP_OVERRIDE_AUTO, detectDeviceCapabilitiesById, parseCapabilityBitmap, resolveGameModeProtocol } from '../common/DeviceCapabilities';
import { MultiDeviceManager } from './MultiDeviceManager';
import { ConnectedDeviceInfo, MultiPriorityInfo } from '../common/ConnectedDeviceInfo';
import {
  buildPacket, buildFeaturePacket, OPPO_SPP_UUID, PROTOCOL_SEQ,
  CmdBattery, CmdQueryAnc, CmdSetNoiseMode, CmdBatchQuery, CmdSetFeature, CmdSpatialAudio,
  CmdSetEq, CmdQueryEq, CmdRegisterNotify, CmdQueryProductId, CmdQueryCapability,
  CmdQueryVersion, CmdQueryCodecType, CmdQueryGameSound, CmdQueryHeadsetSpatial,
  CmdMultiConnectInfo, CmdQueryMultiPriority,
  CmdQueryEqAll, CmdSetEqDetail,
  FeatureDualDevice, FeatureSpatial, FeatureGameMain, FeatureGameLL, FeatureWearDetection,
  PayEmpty, PayQueryAnc, PayRegisterNotify, PayQueryEqAll,
  toHexStr, featurePayload, gameModeFeature, codecName, getAncPayloadForMode,
  EqInfoEntry, parseEqAll, buildEqCreatePayload, buildEqUpdatePayload, buildEqDeletePayload
} from '../common/OppoProtocol';
import { ResponseParser } from '../common/ResponseParser';

/** 空间音频模式常量 */
export const SPATIAL_AUDIO_OFF = 0;
export const SPATIAL_AUDIO_FIXED = 1;
export const SPATIAL_AUDIO_HEAD_TRACKING = 2;

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
  isDarkMode: boolean = false;
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

  // 应用深色模式标志（主应用 EntryAbility 设置，供卡片推送时注入）
  static isAppDarkMode: boolean = true;

  // 后台保活状态
  private isBackgroundTaskRunning: boolean = false;
  private static readonly NOTIFICATION_ID: number = 9001;

  // OPPO Enco Air5 Pro RFCOMM UUID（与安卓 OppoPods 项目一致）
  private RFCOMM_UUID: string = OPPO_SPP_UUID;
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
  private spatialAudioCallback: ((mode: number) => void) | null = null;
  private dualDeviceCallback: ((enabled: boolean) => void) | null = null;
  private eqPresetCallback: ((preset: number) => void) | null = null;

  // 固件版本和编解码器状态
  private firmwareVersion: string = '';
  private codecType: number = -1;
  private firmwareCallback: ((version: string) => void) | null = null;
  private codecCallback: ((codec: number) => void) | null = null;

  // === EQ大师调音预设（动态，从 DeviceCapabilities 读取）===
  static readonly EQ_PRESETS: Record<number, string> = {};
  static readonly EQ_PRESET_IDS: number[] = [];

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
  // 智能降噪实时档位（如 "深度","中度","轻度"）
  private intelligentAncLevel: string = '';
  private intelligentAncCallback: ((level: string) => void) | null = null;

  // 当前佩戴状态
  private currentWearStatus: WearStatus = {
    left: WearState.DISCONNECTED,
    right: WearState.DISCONNECTED,
    case: WearState.DISCONNECTED
  };

  // 游戏模式状态
  private gameModeEnabled: boolean = false;
  // 佩戴检测开关状态
  private wearDetectionEnabled: boolean = false;
  // 游戏音效状态
  private gameSoundEnabled: boolean = false;
  private gameSoundCallback: ((enabled: boolean) => void) | null = null;

  // 空间音频模式（0=关闭, 1=固定/开启, 2=头部追踪）
  private spatialAudioMode: number = SPATIAL_AUDIO_OFF;

  // 双设备连接状态
  private dualDeviceEnabled: boolean = false;

  // EQ预设状态 (-1=未知)
  private currentEqPreset: number = -1;

  /** 设备端完整的 EQ 预设条目列表（0x8122 响应解析） */
  private deviceEqEntries: EqInfoEntry[] = [];
  /** 设备端 EQ 列表变更回调 */
  private deviceEqListCallback: ((entries: EqInfoEntry[]) => void) | null = null;

  // ============== 多设备管理 ==============
  /** 多设备协议管理器 */
  multiDeviceManager: MultiDeviceManager = new MultiDeviceManager((packet: Uint8Array) => {
    this.sendRawPacket(packet);
  });
  /** 多设备列表变化回调 */
  private multiDeviceListCallback: ((devices: ConnectedDeviceInfo[]) => void) | null = null;
  /** 多设备优先级变化回调 */
  private multiPriorityCallback: ((info: MultiPriorityInfo) => void) | null = null;

  // 设备能力检测
  /** 已连接设备的蓝牙名称（用于能力白名单匹配） */
  private cachedDeviceName: string = '';
  /** 当前设备的能力配置 */
  private deviceCapabilities: DeviceCapabilities = new DeviceCapabilities();
  /** 用户能力覆写（从 Preferences 加载） */
  private capabilityOverrides: CapabilityOverrides = new CapabilityOverrides();
  /** 已连接设备的 ProductId（0x8103 响应） */
  private connectedProductId: string = '';

  // 定时查询定时器
  private queryTimer: number = -1;

  // 系统级断开检测定时器（每5秒检查系统音频配置状态）
  private disconnectCheckTimer: number = -1;

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
   * 获取当前EQ预设
   */
  getCurrentEqPreset(): number {
    return this.currentEqPreset;
  }

  /**
   * 检查是否已有活跃的状态回调（主页面是否在运行）
   * 预览弹窗用此判断是否需要自己接管连接，避免覆盖主页面回调
   */
  hasActiveCallbacks(): boolean {
    return this.statusCallback !== null;
  }

  /**
   * 设置回调函数（独立注册，替代旧版多参数 setCallbacks）
   */
  setBatteryCallback(cb: (info: BatteryInfo) => void): void { this.batteryCallback = cb; }
  setStatusCallback(cb: (status: ConnectionStatus) => void): void { this.statusCallback = cb; }
  setRawDataCallback(cb: (hex: string) => void): void { this.rawDataCallback = cb; }
  setAncCallback(cb: (mode: number) => void): void { this.ancCallback = cb; }
  setWearCallback(cb: (wear: WearStatus) => void): void { this.wearCallback = cb; }
  setGameModeCallback(cb: (enabled: boolean) => void): void { this.gameModeCallback = cb; }
  setSpatialAudioCallback(cb: (mode: number) => void): void { this.spatialAudioCallback = cb; }
  setDualDeviceCallback(cb: (enabled: boolean) => void): void { this.dualDeviceCallback = cb; }
  setEqPresetCallback(cb: (preset: number) => void): void { this.eqPresetCallback = cb; }

  /** 设备端 EQ 列表变更回调 */
  setDeviceEqListCallback(cb: (entries: EqInfoEntry[]) => void): void { this.deviceEqListCallback = cb; }

  /** 游戏音效回调 */
  setGameSoundCallback(cb: (enabled: boolean) => void): void { this.gameSoundCallback = cb; }
  /** 智能 ANC 档位回调 */
  setIntelligentAncCallback(cb: (level: string) => void): void { this.intelligentAncCallback = cb; }

  /** 固件版本回调 */
  setFirmwareCallback(cb: (version: string) => void): void { this.firmwareCallback = cb; }
  /** 编解码器回调 */
  setCodecCallback(cb: (codec: number) => void): void { this.codecCallback = cb; }

  /** 获取固件版本 */
  getFirmwareVersion(): string { return this.firmwareVersion; }
  /** 获取编解码器类型ID */
  getCodecType(): number { return this.codecType; }
  /** 获取编解码器可读名称 */
  getCodecName(): string { return this.codecType >= 0 ? codecName(this.codecType) : '--'; }

  /**
   * 设置多设备列表变化回调
   */
  setMultiDeviceListCallback(cb: (devices: ConnectedDeviceInfo[]) => void): void {
    this.multiDeviceListCallback = cb;
    this.multiDeviceManager.onDeviceListChanged = cb;
  }

  /**
   * 设置多设备优先级变化回调
   */
  setMultiPriorityCallback(cb: (info: MultiPriorityInfo) => void): void {
    this.multiPriorityCallback = cb;
    this.multiDeviceManager.onPriorityChanged = cb;
  }

  /**
   * 获取当前双设备开关状态
   */
  getDualDeviceEnabled(): boolean {
    return this.dualDeviceEnabled;
  }

  /**
   * 获取当前设备能力配置（供外部查询）
   */
  getDeviceCapabilities(): DeviceCapabilities {
    return this.deviceCapabilities;
  }

  /**
   * 获取当前设备支持的 EQ 预设名映射（从 DeviceCapabilities 动态读取）
   */
  getEqPresetNames(): Record<number, string> {
    const caps = this.deviceCapabilities;
    if (caps.eqNames.size > 0) {
      const result: Record<number, string> = {};
      caps.eqNames.forEach((name: string, id: number) => {
        result[id] = name;
      });
      return result;
    }
    if (Object.keys(OppoEarphoneManager.EQ_PRESETS).length > 0) {
      return OppoEarphoneManager.EQ_PRESETS;
    }
    return { 0: '至臻原音', 1: '澎湃低音', 2: '纯享人声' };
  }

  /**
   * 获取当前设备支持的 EQ 预设 ID 列表
   */
  getEqPresetIds(): number[] {
    const caps = this.deviceCapabilities;
    if (caps.eqNames.size > 0) {
      const ids: number[] = [];
      caps.eqNames.forEach((_: string, id: number) => {
        ids.push(id);
      });
      return ids.sort((a, b) => a - b);
    }
    if (OppoEarphoneManager.EQ_PRESET_IDS.length > 0) {
      return OppoEarphoneManager.EQ_PRESET_IDS;
    }
    return [0, 1, 2]; // 硬编码降级
  }

  /**
   * 根据设备名称检测能力并应用
   * 在 SPP 连接成功后调用
   */
  private detectAndApplyCapabilities(deviceName: string): void {
    this.cachedDeviceName = deviceName;
    this.loadCapabilityOverrides();
    this.deviceCapabilities = detectDeviceCapabilities(deviceName, this.capabilityOverrides);
    // 同步多设备管理器能力
    this.multiDeviceManager.setCapabilities(
      this.deviceCapabilities.dualDeviceSupported,
      this.deviceCapabilities.multiConnectManageSupported
    );
    console.info(`[OppoManager] 设备能力检测完成: name="${deviceName}"` +
      `, spatialSoundSwitch=${this.deviceCapabilities.spatialSoundSwitchSupported}` +
      `, legacyAnc=${this.deviceCapabilities.legacyAnc}` +
      `, dualDevice=${this.deviceCapabilities.dualDeviceSupported}`);
  }

  /**
   * 从 Preferences 加载用户能力覆写
   */
  private loadCapabilityOverrides(): void {
    try {
      if (!OppoEarphoneManager.appContext) return;
      let pref = preferences.getPreferencesSync(OppoEarphoneManager.appContext, { name: 'capability_overrides' });
      this.capabilityOverrides.spatialAudio = pref.getSync('spatialAudio', CAP_OVERRIDE_AUTO) as number;
      this.capabilityOverrides.spatialSoundSwitch = pref.getSync('spatialSoundSwitch', CAP_OVERRIDE_AUTO) as number;
      this.capabilityOverrides.ancLegacy = pref.getSync('ancLegacy', CAP_OVERRIDE_AUTO) as number;
      this.capabilityOverrides.adaptiveAnc = pref.getSync('adaptiveAnc', CAP_OVERRIDE_AUTO) as number;
    } catch (e) {
      console.warn('[OppoManager] 加载能力覆写失败，使用默认');
    }
  }

  /**
   * 保存用户能力覆写并重新检测
   */
  applyCapabilityOverrides(overrides: CapabilityOverrides): void {
    this.capabilityOverrides = overrides;
    // 持久化
    try {
      if (!OppoEarphoneManager.appContext) return;
      let pref = preferences.getPreferencesSync(OppoEarphoneManager.appContext, { name: 'capability_overrides' });
      pref.putSync('spatialAudio', overrides.spatialAudio);
      pref.putSync('spatialSoundSwitch', overrides.spatialSoundSwitch);
      pref.putSync('ancLegacy', overrides.ancLegacy);
      pref.putSync('adaptiveAnc', overrides.adaptiveAnc);
      pref.flush();
    } catch (e) {
      console.warn('[OppoManager] 保存能力覆写失败');
    }
    // 重新检测
    if (this.cachedDeviceName) {
      this.deviceCapabilities = detectDeviceCapabilities(this.cachedDeviceName, overrides);
      this.multiDeviceManager.setCapabilities(
        this.deviceCapabilities.dualDeviceSupported,
        this.deviceCapabilities.multiConnectManageSupported
      );
      console.info('[OppoManager] 能力覆写已应用，重新检测完成');
      // 已连接时重新通知 subscribed 状态，触发 UI（MainPageContent）重读能力标志
      if (this.isConnected) {
        this.notifyStatus('subscribed');
      }
    }
  }

  /**
   * 检查系统蓝牙音频配置是否已连接
   * 通过 getProfileConnectionState() 检查是否有任何音频配置(A2DP/HFP)处于连接状态
   * 用于确保系统音频连接已建立后再发起SPP连接，避免抢占系统音频连接
   */
  private isSystemAudioConnected(): boolean {
    try {
      let state = connection.getProfileConnectionState();
      let connected = state === constant.ProfileConnectionState.STATE_CONNECTED;
      console.info(`[OppoManager] 系统音频配置连接状态: ${connected ? '已连接' : '未连接'}`);
      return connected;
    } catch (err) {
      let error = err as BusinessError;
      console.warn(`[OppoManager] 检查系统音频配置状态失败: ${error.message}，默认允许连接`);
      return true; // 检查失败时默认允许连接
    }
  }

  /**
   * 启动系统级断开检测定时器
   * 每5秒检查系统音频配置状态，一旦检测到系统蓝牙音频断开，立即触发断开
   * 比定时发送SPP信号检测更快更可靠
   */
  private startDisconnectMonitor(): void {
    this.stopDisconnectMonitor();
    this.disconnectCheckTimer = setInterval(() => {
      if (!this.isConnected) return;
      try {
        let state = connection.getProfileConnectionState();
        if (state !== constant.ProfileConnectionState.STATE_CONNECTED) {
          console.info('[OppoManager] 系统音频配置已断开，清理SPP连接并重启监听...');
          this.handleNaturalDisconnect('系统音频配置已断开，SPP连接已清理');
        }
      } catch (err) {
        let error = err as BusinessError;
        console.warn(`[OppoManager] 系统断开检测失败: ${error.message}`);
      }
    }, 5000);
    console.info('[OppoManager] 系统级断开检测已启动');
  }

  /**
   * 停止系统级断开检测定时器
   */
  private stopDisconnectMonitor(): void {
    if (this.disconnectCheckTimer !== -1) {
      clearInterval(this.disconnectCheckTimer);
      this.disconnectCheckTimer = -1;
    }
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
    // 第一步：优先尝试从已保存MAC或系统已配对设备中连接（需先确认系统音频已连接）
    if (this.savedMac && this.isSystemAudioConnected()) {
      console.info(`[OppoManager] 发现已保存设备且系统音频已连接,优先连接: ${this.savedMac}`);
      this.connectToEarphone(this.savedMac);
    } else if (this.savedMac) {
      console.info(`[OppoManager] 已保存设备 ${this.savedMac} 存在但系统音频未连接，等待系统先建立音频连接`);
    } else {
      this.tryConnectFromPairedDevices();
    }
    // 第二步：如果配对设备直连未成功，启动BLE扫描监听
    this.startMonitorCycle();
  }

  /**
   * 从系统已配对设备中查找OPPO耳机并直连SPP
   * 解决耳机已通过系统蓝牙配对连接后，BLE扫描无法发现的问题
   * 仅在系统音频配置已连接时才发起SPP连接
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
            // 检查系统音频配置是否已连接
            if (!this.isSystemAudioConnected()) {
              console.info(`[OppoManager] 发现已配对OPPO耳机，但系统音频未连接，等待系统先建立音频连接`);
              return false;
            }
            console.info(`[OppoManager] 发现已配对的OPPO耳机且系统音频已连接! 直接SPP连接: ${deviceName} [${mac}]`);
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
    this.startScan();
    this.scheduleNextMonitorCycle();
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
      // 先检查系统音频是否已连接
      if (!this.isSystemAudioConnected()) {
        console.info(`[OppoManager] 已保存设备 ${this.savedMac} 存在但系统音频未连接，启动持续监听等待`);
        this.startContinuousMonitor();
        return;
      }
      console.info(`[OppoManager] 尝试连接已保存设备: ${this.savedMac}`);
      this.connectToEarphone(this.savedMac);
    } else {
      // 先检查系统已配对设备
      console.info('[OppoManager] 无已保存设备,检查系统已配对设备...');
      if (!this.tryConnectFromPairedDevices()) {
        console.info('[OppoManager] 启动持续监听...');
        this.startContinuousMonitor();
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
        // 重连时也检查系统已配对设备，无结果则启动持续监听
        if (!this.tryConnectFromPairedDevices()) {
          this.startContinuousMonitor();
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
   * 构造 OPPO 协议数据包（委托 OppoProtocol）
   */
  private buildPacket(cmd: number, seq: number = 0xF0, payload: number[] = []): Uint8Array {
    return buildPacket(cmd, payload, seq);
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
        this.handleNaturalDisconnect('SPP IO错误(2901054)，自然断开');
      }
    }
  }

  /**
   * 公开的发送原始数据包方法（供 MultiDeviceManager 等外部模块调用）
   */
  sendRawPacket(packet: Uint8Array): void {
    this.sendPacket(packet);
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
   * 查询智能降噪实时档位（Cmd 0x010C + [0x04, 0x01]）
   */
  queryIntelligentAnc(): void {
    const packet = this.buildPacket(0x010C, 0x00, [0x04, 0x01]);
    this.sendPacket(packet);
  }

  /**
   * 设置 ANC 模式
   * 支持旧版 ANC 指令反转型号（Air2 Pro 等: 0x01=降噪, 0x02=关闭）
   */
  setAncMode(mode: number): void {
    // 旧版兼容模式需转换 mode
    const actualMode = (this.deviceCapabilities.legacyAnc && mode === 1) ? 2 :
                       (this.deviceCapabilities.legacyAnc && mode === 2) ? 1 : mode;
    const payload = getAncPayloadForMode(actualMode);
    if (!payload) {
      console.warn(`[OppoManager] 不支持的ANC模式: ${mode}`);
      return;
    }
    const packet = this.buildPacket(0x0404, 0x00, payload);
    this.sendPacket(packet);
    const modeName = getAncModeName(actualMode);
    console.info(`[OppoManager] 发送 ANC 模式切换指令: ${modeName}` +
      (this.deviceCapabilities.legacyAnc ? ' (兼容模式)' : ''));
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
   * 查询游戏音效状态（Cmd 0x012B）
   */
  queryGameSound(): void {
    if (!this.deviceCapabilities.gameSoundSupported) return;
    const packet = this.buildPacket(0x012B, 0x00, []);
    this.sendPacket(packet);
  }

  /**
   * 设置游戏音效开关（Cmd 0x0423）
   * 开：[gameSoundType, 1], 关：[0, 1]
   */
  setGameSoundEnabled(enabled: boolean): void {
    if (!this.deviceCapabilities.gameSoundSupported) return;
    this.gameSoundEnabled = enabled;
    if (this.gameSoundCallback) this.gameSoundCallback(enabled);
    const type = enabled ? this.deviceCapabilities.gameSoundType : 0x00;
    const packet = this.buildPacket(0x0423, 0x00, [type, 0x01]);
    this.sendPacket(packet);
    console.info(`[OppoManager] 发送游戏音效切换: ${enabled ? '开启' : '关闭'} (type=${type})`);
    setTimeout(() => { this.queryGameSound(); }, 400);
  }

  /**
   * 设置游戏模式
   */
  setGameMode(enabled: boolean): void {
    this.gameModeEnabled = enabled;
    this.notifyGameModeUpdate(enabled);
    const featureId = this.deviceCapabilities.gameModeFeatureId || 0x28;
    const payload: number[] = [featureId, enabled ? 0x01 : 0x00];
    const packet = this.buildPacket(0x0403, 0x00, payload);
    this.sendPacket(packet);
    console.info(`[OppoManager] 发送游戏模式切换指令: ${enabled ? '开启' : '关闭'} (feature=0x${featureId.toString(16)})`);
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
   * 设置空间音频模式
   * 根据设备能力自动选择协议:
   * - spatialSoundSwitchSupported (Air5) → 0x1B switch，仅 ON/OFF，mode>=1 视为开启
   * - spatialAudioSupported (X3) → 0x0422，支持 OFF/FIXED/HEAD_TRACKING 三态
   */
  setSpatialAudio(mode: number): void {
    const normalized = Math.max(SPATIAL_AUDIO_OFF, Math.min(SPATIAL_AUDIO_HEAD_TRACKING, mode));
    this.spatialAudioMode = normalized;
    this.notifySpatialAudioUpdate(normalized);
    if (this.deviceCapabilities.spatialSoundSwitchSupported) {
      // Air5 / Free4: 0x1B switch，仅判断开/关
      const enabled = normalized >= SPATIAL_AUDIO_FIXED;
      const payload: number[] = [0x1B, enabled ? 0x01 : 0x00];
      const packet = this.buildPacket(0x0403, 0x00, payload);
      this.sendPacket(packet);
      console.info(`[OppoManager] 发送空间音频(0x1B): ${enabled ? '开启' : '关闭'}`);
    } else if (this.deviceCapabilities.spatialAudioSupported) {
      // X3: 0x0422 标准空间音频，发送 mode 值
      const payload: number[] = [normalized];
      const packet = this.buildPacket(0x0422, 0x00, payload);
      this.sendPacket(packet);
      console.info(`[OppoManager] 发送空间音频(0x0422): mode=${normalized}`);
    }
    setTimeout(() => {
      this.querySpatialAudio();
    }, 350);
  }

  /**
   * 获取当前空间音频模式
   */
  getSpatialAudioMode(): number {
    return this.spatialAudioMode;
  }

  /**
   * 设置双设备连接开关
   * 使用 cmd=0x0403 + feature=0x11（双设备连接特征码）
   */
  setDualDeviceConnection(enabled: boolean): void {
    this.dualDeviceEnabled = enabled;
    this.notifyDualDeviceUpdate(enabled);
    const payload: number[] = [0x11, enabled ? 0x01 : 0x00];
    const packet = this.buildPacket(0x0403, 0x00, payload);
    this.sendPacket(packet);
    console.info(`[OppoManager] 发送双设备连接指令: ${enabled ? '开启' : '关闭'}`);
    setTimeout(() => {
      this.queryDualDevice();
    }, 350);
  }

  /**
   * 设置佩戴检测开关（智能播放暂停）
   * 使用 cmd=0x0403 + feature=0x04
   */
  setWearDetection(enabled: boolean): void {
    this.wearDetectionEnabled = enabled;
    AppStorage.setOrCreate('wearDetectionEnabled', enabled);
    const packet = buildFeaturePacket(FeatureWearDetection, enabled);
    this.sendPacket(packet);
    console.info(`[OppoManager] 发送佩戴检测指令: ${enabled ? '开启' : '关闭'}`);
  }

  /**
   * 获取佩戴检测开关状态
   */
  getWearDetectionEnabled(): boolean {
    return this.wearDetectionEnabled;
  }

  /**
   * 查询双设备连接状态
   */
  private queryDualDevice(): void {
    const packet = this.buildPacket(0x010D, 0x00, []);
    this.sendPacket(packet);
  }

  /**
   * 设置EQ大师调音预设
   * Cmd=0x0406, payload=[presetId]
   */
  setEqPreset(presetId: number): void {
    const validIds = this.getEqPresetIds();
    // 同时检查内置预设 ID 和自定义 EQ 的 ID
    const isBuiltin = validIds.length === 0 || validIds.includes(presetId);
    const isCustom = this.deviceEqEntries.some((e: EqInfoEntry) => e.eqId === presetId);
    if (!isBuiltin && !isCustom) {
      console.warn(`[OppoManager] 不支持的EQ预设ID: ${presetId}`);
      return;
    }
    this.currentEqPreset = presetId;
    this.notifyEqPresetUpdate(presetId);
    const packet = this.buildPacket(0x0406, 0x00, [presetId]);
    this.sendPacket(packet);
    const eqNames = this.getEqPresetNames();
    console.info(`[OppoManager] 发送EQ预设切换: ${eqNames[presetId] ?? '自定义'} (id=${presetId})`);
    setTimeout(() => {
      this.queryEqPreset();
    }, 350);
  }

  /**
   * 查询当前EQ预设
   * Cmd=0x010F, 无payload
   */
  private queryEqPreset(): void {
    const packet = this.buildPacket(0x010F, 0x00, []);
    this.sendPacket(packet);
  }

  /**
   * 查询设备端全部 EQ 预设（Cmd 0x0122）
   * 结果由 handleEqAllResponse 解析
   */
  queryEqAll(): void {
    if (!this.deviceCapabilities.hasCustomEq) {
      console.info('[OppoManager] 设备不支持自定义 EQ，跳过查询');
      return;
    }
    const packet = this.buildPacket(CmdQueryEqAll, 0x00, [0x01, 0x05]);
    this.sendPacket(packet);
    console.info('[OppoManager] 查询设备端全部 EQ 预设');
  }

  /**
   * 创建设备端自定义 EQ 预设（cmd 0x0418, actionType=1）
   * 对应 C# PodManager.SendCustomEq()
   */
  createCustomEq(gains: number[], frequencies: number[], name: string): void {
    if (!this.deviceCapabilities.hasCustomEq) return;
    const payload = buildEqCreatePayload(gains, frequencies, name);
    const packet = this.buildPacket(CmdSetEqDetail, 0x00, payload);
    this.sendPacket(packet);
    console.info(`[OppoManager] 创建自定义 EQ: ${name}`);
    setTimeout(() => { this.queryEqAll(); }, 500);
  }

  /**
   * 更新设备端自定义 EQ 预设（cmd 0x0418, actionType=2）
   * 对应 C# PodManager.UpdateCustomEq()
   */
  updateCustomEq(entry: EqInfoEntry): void {
    if (!this.deviceCapabilities.hasCustomEq) return;
    const payload = buildEqUpdatePayload(entry);
    const packet = this.buildPacket(CmdSetEqDetail, 0x00, payload);
    this.sendPacket(packet);
    console.info(`[OppoManager] 更新自定义 EQ: ${entry.name} (id=${entry.eqId})`);
    setTimeout(() => { this.queryEqAll(); }, 500);
  }

  /**
   * 删除设备端自定义 EQ 预设（cmd 0x0418, actionType=3）
   * 对应 C# PodManager.DeleteEq()
   */
  deleteCustomEq(eqId: number): void {
    if (!this.deviceCapabilities.hasCustomEq) return;
    const payload = buildEqDeletePayload(eqId);
    const packet = this.buildPacket(CmdSetEqDetail, 0x00, payload);
    this.sendPacket(packet);
    console.info(`[OppoManager] 删除自定义 EQ: id=${eqId}`);
    setTimeout(() => { this.queryEqAll(); }, 800);
  }

  /**
   * 获取设备端 EQ 列表（供 UI 读取）
   */
  getDeviceEqEntries(): EqInfoEntry[] {
    return this.deviceEqEntries;
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

  // ============== 工具方法 ==============

  /**
   * 异步延迟（替代嵌套 setTimeout）
   */
  private delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => setTimeout(resolve, ms));
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

  private notifySpatialAudioUpdate(mode: number): void {
    if (this.spatialAudioCallback) this.spatialAudioCallback(mode);
  }

  private notifyDualDeviceUpdate(enabled: boolean): void {
    if (this.dualDeviceCallback) this.dualDeviceCallback(enabled);
  }

  private notifyEqPresetUpdate(preset: number): void {
    if (this.eqPresetCallback) this.eqPresetCallback(preset);
    // 同步到 AppStorage 实现跨页面状态同步
    AppStorage.Set<number>('currentEqPreset', preset);
  }

  /**
   * 开始扫描周围的 OPPO 耳机（统一BLE扫描入口）
   * 包含系统音频检查 + 超时保护 + 卡片状态更新
   * 由 startMonitorCycle / startAutoConnect / scheduleReconnect 共同调用
   */
  startScan(): void {
    if (this.isScanning || this.connectedMac) return;
    console.info('[OppoManager] 开始扫描周围的 OPPO 耳机...');
    this.notifyStatus('scanning');
    this.isScanning = true;
    this.cancelReconnect();

    const scanTimeout = setTimeout(() => {
      if (this.isScanning) {
        console.info('[OppoManager] 扫描超时,停止本次扫描');
        this.stopScan();
        this.notifyStatus('disconnected');
        // 扫描超时未连接，更新桌面卡片为断开状态
        this.saveBatteryToWidget();
      }
    }, 10000);

    ble.on('BLEDeviceFind', (devices: Array<ble.ScanResult>) => {
      for (let device of devices) {
        let deviceName = device.deviceName;
        let deviceMac = device.deviceId;
        if (deviceName && deviceName.includes('OPPO Enco')) {
          console.info(`[OppoManager] 发现目标耳机! 名字: ${deviceName}, MAC: ${deviceMac}`);
          // 检查系统音频配置是否已连接，避免抢占系统音频连接
          if (!this.isSystemAudioConnected()) {
            console.info('[OppoManager] 系统音频未连接，跳过SPP连接，等待下一轮扫描');
            return;
          }
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
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[OppoManager] 启动扫描失败: ${error.message}`);
      clearTimeout(scanTimeout);
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
    this.stopDisconnectMonitor();
    this.cancelReconnect();
    // 停止后台保活 + 移除通知
    this.stopBackgroundService();
    // 重置设备能力检测状态
    this.cachedDeviceName = '';
    this.deviceCapabilities = new DeviceCapabilities();
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

        // 检测设备能力（基于蓝牙设备名）
        try {
          let name: string = connection.getRemoteDeviceName(macAddress);
          this.detectAndApplyCapabilities(name);
        } catch (nameErr) {
          console.warn(`[OppoManager] 获取设备名失败，使用默认能力: ${(nameErr as BusinessError).message}`);
        }

        // 注册数据接收监听
        try {
          socket.on('sppRead', clientNum, (dataBuffer: ArrayBuffer) => {
            let valueArray = new Uint8Array(dataBuffer);
            // 空数据表示蓝牙连接已自然断开（耳机断电/超出范围）
            if (valueArray.length === 0) {
              console.info('[OppoManager] sppRead收到空数据，检测到自然断开');
              this.handleNaturalDisconnect('sppRead收到空数据，自然断开');
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
            // 解析产品ID（0x8103）
            this.handleProductIdResponse(valueArray);
            // 解析电量
            this.parseOppoBattery(valueArray);
            // 解析 ANC 模式
            this.parseAncMode(valueArray);
            // 解析智能 ANC 档位
            this.handleIntelligentAnc(valueArray);
            // 解析佩戴状态
            this.parseWearStatus(valueArray);
            // 解析游戏模式
            this.parseFeatureFlags(valueArray);
            // 解析空间音频
            this.parseSpatialAudio(valueArray);
            // 解析功能设置响应 (0x8403)
            this.parseSwitchFeatureResponse(valueArray);
            // 解析 EQ 预设
            this.parseEqPreset(valueArray);
            // 解析固件版本（0x8105）
            this.handleFirmwareVersion(valueArray);
            // 解析编解码器类型（0x8114）
            this.handleCodecType(valueArray);
            // 解析游戏音效（0x812B）
            this.handleGameSound(valueArray);
            // 解析多设备连接响应
            this.multiDeviceManager.handleResponse(valueArray);
            // 解析设备端全部 EQ 条目（0x8122）
            this.handleEqAllResponse(valueArray);
            // 解析自定义 EQ 设置响应（0x8418）
            this.handleEqSetDetailResponse(valueArray);
          });
        } catch (readErr) {
          let error = readErr as BusinessError;
          console.error(`[OppoManager] 注册sppRead监听失败: ${error.message}`);
        }

        // SPP RFCOMM 连接成功即可通信，直接设为 subscribed（无需GATT服务发现）
        this.notifyStatus('subscribed');

        // 启动后台保活 + 常驻通知
        this.startBackgroundService();

        // 启动系统级断开检测（每5秒检查系统音频配置状态）
        this.startDisconnectMonitor();

        // 连接成功后启动 5 阶段初始化（参考 OppoPods ConnectAsync 流程）
        setTimeout(async () => {
          // 阶段1: 设备识别 — ProductID + 能力位图
          this.sendRawPacket(buildPacket(CmdQueryProductId));
          await this.delay(120);
          this.sendRawPacket(buildPacket(CmdQueryCapability));
          await this.delay(120);

          // 阶段2: 使能状态报告 + 批量查询
          this.enableStatusReport();
          await this.delay(200);
          this.queryStatus();
          await this.delay(200);

          // 阶段3: 能力门控状态查询
          this.queryBattery();
          this.sendRawPacket(buildPacket(CmdQueryVersion)); // 固件版本
          this.sendRawPacket(buildPacket(CmdQueryCodecType)); // 编解码器
          // 游戏音效（仅支持的设备）
          if (this.deviceCapabilities.gameSoundSupported) {
            this.queryGameSound();
          }
          // 智能降噪档位（仅自适应 ANC 设备）
          if (this.deviceCapabilities.adaptiveSupported) {
            this.queryIntelligentAnc();
          }
          this.queryAncMode();
          this.queryGameMode();
          this.querySpatialAudio();
          this.queryDualDevice();
          this.queryEqPreset();
          // 查询设备端全部 EQ 条目（仅支持自定义 EQ 的设备）
          if (this.deviceCapabilities.hasCustomEq) {
            this.queryEqAll();
          }
          // 查询多设备连接列表和优先设备
          if (this.deviceCapabilities.dualDeviceSupported) {
            this.multiDeviceManager.queryDeviceList();
          }
          if (this.deviceCapabilities.multiConnectManageSupported) {
            this.multiDeviceManager.queryPriorityDevice();
          }
          this.startPeriodicQuery();
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

  /**
   * 统一处理自然断开（系统音频断开/SPP空数据/SPP IO错误）
   * 清理所有定时器和后台服务，通知UI断开，自动重启监听等待重连
   */
  private handleNaturalDisconnect(reason: string): void {
    console.info(`[OppoManager] ${reason}`);
    this.stopDisconnectMonitor();
    this.stopPeriodicQuery();
    this.cancelReconnect();
    this.stopBackgroundService();
    this.cleanup(false);
    this.notifyStatus('disconnected');
    // 系统断开后自动重启监听，等待耳机重连
    this.startContinuousMonitor();
  }

  // ============== 数据解析（与 BLE 版本完全相同） ==============

  /**
   * 核心逆向算法最新升级版（完美兼容官方协议及复杂前置序列）
   */
  private parseOppoBattery(data: Uint8Array): void {
    const result = ResponseParser.parseBattery(data);
    if (!result) return;

    const updated = (this.batteryInfo.leftBattery !== result.leftBattery ||
                     this.batteryInfo.leftCharging !== result.leftCharging ||
                     this.batteryInfo.rightBattery !== result.rightBattery ||
                     this.batteryInfo.rightCharging !== result.rightCharging ||
                     this.batteryInfo.caseBattery !== result.caseBattery ||
                     this.batteryInfo.caseCharging !== result.caseCharging);
    if (!updated) return;

    this.batteryInfo.leftBattery = result.leftBattery;
    this.batteryInfo.leftCharging = result.leftCharging;
    this.batteryInfo.rightBattery = result.rightBattery;
    this.batteryInfo.rightCharging = result.rightCharging;
    this.batteryInfo.caseBattery = result.caseBattery;
    this.batteryInfo.caseCharging = result.caseCharging;
    this.notifyBatteryUpdate();
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
          widgetData.isDarkMode = OppoEarphoneManager.isAppDarkMode;
          let data = formBindingData.createFormBindingData(widgetData);
          await formProvider.updateForm(formId, data);
          console.info(`[OppoManager] 2×2卡片已刷新: formId=${formId}`);
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
    const result = ResponseParser.parseAncMode(data, this.deviceCapabilities.legacyAnc);
    if (!result) return;
    const mode = result.mode;
    if (this.currentAncMode !== mode) {
      this.currentAncMode = mode;
      this.notifyAncUpdate(mode);
      console.info(`[OppoManager] ANC模式变更: ${getAncModeName(mode)}` +
        (this.deviceCapabilities.legacyAnc ? ' (兼容模式)' : ''));
    }
  }

  /**
   * 解析佩戴状态
   */
  private parseWearStatus(data: Uint8Array): void {
    const result = ResponseParser.parseWearStatus(data);
    if (!result) return;

    // 将 ParserWearState 映射到 WearState
    const mapState = (s: number | null, oldVal: WearState): WearState => {
      if (s === null) return oldVal;  // 未上报的组件保留旧值
      switch (s) {
        case 0x00: return WearState.DISCONNECTED;
        case 0x01: return WearState.REMOVED;      // 摘下 (C# st==1)
        case 0x03: return WearState.WEARING;       // 佩戴 (C# st==3)
        case 0x04: return WearState.IN_CASE;
        case 0x05: return WearState.REMOVED;
        case 0x07: return WearState.WEARING;
        default: return WearState.DISCONNECTED;
      }
    };

    const oldLeft = this.currentWearStatus.left;
    const oldRight = this.currentWearStatus.right;
    const oldCase = this.currentWearStatus.case;
    const newLeft = mapState(result.left, oldLeft);
    const newRight = mapState(result.right, oldRight);
    const newCase = mapState(result.case, oldCase);

    if (newLeft === oldLeft && newRight === oldRight && newCase === oldCase) return;

    const newStatus: WearStatus = { left: newLeft, right: newRight, case: newCase };
    this.currentWearStatus = newStatus;
    this.notifyWearUpdate(newStatus);
    console.info(`[OppoManager] 佩戴状态: L=${newLeft}, R=${newRight}, C=${newCase}`);

    // 佩戴状态变化时延迟查询ANC状态
    const leftWearChanged = (oldLeft === WearState.WEARING) !== (newLeft === WearState.WEARING);
    const rightWearChanged = (oldRight === WearState.WEARING) !== (newRight === WearState.WEARING);
    if (leftWearChanged || rightWearChanged) {
      const wearingToNot = (oldLeft === WearState.WEARING && newLeft !== WearState.WEARING)
                        || (oldRight === WearState.WEARING && newRight !== WearState.WEARING);
      console.info(wearingToNot
        ? '[OppoManager] 耳机入盒/取下，延迟查询ANC状态...'
        : '[OppoManager] 耳机重新佩戴，延迟查询ANC状态...');
      setTimeout(() => { this.queryAncMode(); }, 1000);
    }
  }

  /**
   * 解析特性标志（cmd=0x810D 响应）
   * 扫描 0x28(游戏模式) / 0x1B(空间音频) / 0x11(双设备连接)
   */
  private parseFeatureFlags(data: Uint8Array): void {
    const result = ResponseParser.parseFeatureFlags(data);
    if (!result) return;
    // 动态解析游戏模式协议：根据设备实际返回的 feature 判定使用 0x06 还是 0x28
    if (result.features.size > 0) {
      resolveGameModeProtocol(result.features, this.deviceCapabilities, 0x06, 0x28);
      // 读取佩戴检测状态（feature 0x04）
      const wearVal = result.features.get(0x04);
      if (wearVal !== undefined) {
        this.wearDetectionEnabled = wearVal !== 0;
        AppStorage.setOrCreate('wearDetectionEnabled', this.wearDetectionEnabled);
      }
    }
    if (result.gameMode !== undefined && this.gameModeEnabled !== result.gameMode) {
      this.gameModeEnabled = result.gameMode;
      this.notifyGameModeUpdate(result.gameMode);
      console.info(`[OppoManager] 游戏模式: ${result.gameMode ? '开启' : '关闭'}`);
    }
    if (result.spatialMode !== undefined) {
      const mode = result.spatialMode ? SPATIAL_AUDIO_FIXED : SPATIAL_AUDIO_OFF;
      if (this.spatialAudioMode !== mode) {
        this.spatialAudioMode = mode;
        this.notifySpatialAudioUpdate(mode);
        console.info(`[OppoManager] 空间音频: ${result.spatialMode ? '开启' : '关闭'}`);
      }
    }
    if (result.dualDevice !== undefined) {
      if (this.dualDeviceEnabled !== result.dualDevice) {
        this.dualDeviceEnabled = result.dualDevice;
        this.notifyDualDeviceUpdate(result.dualDevice);
        console.info(`[OppoManager] 双设备连接: ${result.dualDevice ? '开启' : '关闭'}`);
      }
      this.multiDeviceManager.handleDualDeviceFeature(result.dualDevice ? 0x01 : 0x00);
    }
  }

  /**
   * 解析空间音频通知（cmd=0x0510 主动上报 和 cmd=0x8422 设置响应）
   */
  private parseSpatialAudio(data: Uint8Array): void {
    const result = ResponseParser.parseSpatialAudio(data);
    if (!result) return;
    const normalized = Math.max(SPATIAL_AUDIO_OFF, Math.min(SPATIAL_AUDIO_HEAD_TRACKING, result.mode));
    console.info(`[OppoManager] 空间音频解析: mode=${normalized}`);
    if (this.spatialAudioMode !== normalized) {
      this.spatialAudioMode = normalized;
      this.notifySpatialAudioUpdate(normalized);
    }
  }

  /**
   * 解析功能设置响应（cmd=0x8403），处理双设备连接(0x11)等特征
   */
  private parseSwitchFeatureResponse(data: Uint8Array): void {
    const result = ResponseParser.parseSwitchFeatureResponse(data);
    if (!result) return;
    console.info(`[OppoManager] 开关响应(0x8403): feature=0x${result.feature.toString(16)}, enabled=${result.enabled}`);
    if (result.feature === 0x11) {
      if (this.dualDeviceEnabled !== result.enabled) {
        this.dualDeviceEnabled = result.enabled;
        this.notifyDualDeviceUpdate(result.enabled);
      }
      this.multiDeviceManager.handleDualDeviceFeature(result.enabled ? 0x01 : 0x00);
    }
  }

  /**
   * 解析 EQ 大师调音预设
   * 处理 cmd=0x810F（查询响应: [status, preset]）和 cmd=0x0504（主动通知: [preset]）
   */
  private parseEqPreset(data: Uint8Array): void {
    const validIds = this.getEqPresetIds();
    const result = ResponseParser.parseEqPreset(data, validIds);
    if (!result) return;
    const presetId = result.presetId;
    const eqNames = this.getEqPresetNames();
    console.info(`[OppoManager] EQ预设响应: ${eqNames[presetId]} (id=${presetId})`);
    this.currentEqPreset = presetId;
    this.notifyEqPresetUpdate(presetId);
  }

  /**
   * 解析设备端全部 EQ 条目（0x8122）
   * 对应 C# PodManager.ParseEqAll()
   */
  private handleEqAllResponse(data: Uint8Array): void {
    if (data.length < 9 || data[0] !== 0xAA) return;
    const cmdLow = data[4];
    const cmdHigh = data[5];
    const cmd = cmdLow | (cmdHigh << 8);
    if (cmd !== 0x8122) return;

    const payLen = (data[7] | (data[8] << 8));
    const start = 9;
    if (data.length < start + payLen) return;

    const payload = data.slice(start, start + payLen);
    const entries = parseEqAll(payload);
    if (entries.length === 0) return;

    this.deviceEqEntries = entries;
    console.info(`[OppoManager] 设备端 EQ 列表: ${entries.length} 个预设`);
    for (const e of entries) {
      console.info(`[OppoManager]   EQ[${e.eqId}] "${e.name}" selected=${e.isSelected}`);
    }
    if (this.deviceEqListCallback) {
      this.deviceEqListCallback(entries);
    }
  }

  /**
   * 解析自定义 EQ 设置响应（0x8418），记录结果
   */
  private handleEqSetDetailResponse(data: Uint8Array): void {
    if (data.length < 9 || data[0] !== 0xAA) return;
    const cmdLow = data[4];
    const cmdHigh = data[5];
    const cmd = cmdLow | (cmdHigh << 8);
    if (cmd !== 0x8418) return;
    const status = data.length > 9 ? data[9] : -1;
    console.info(`[OppoManager] 自定义 EQ 设置响应: status=${status === 0 ? '成功' : '失败(' + status + ')'}`);
  }

  /**
   * 解析产品ID响应（0x8103），成功后根据 productId 重新检测设备能力
   */
  private handleProductIdResponse(data: Uint8Array): void {
    const productId = ResponseParser.parseProductId(data);
    if (!productId) return;
    if (this.connectedProductId === productId) return;
    this.connectedProductId = productId;
    console.info(`[OppoManager] 识别到设备 ProductId: ${productId}`);
    const capsById = detectDeviceCapabilitiesById(productId, this.cachedDeviceName);
    if (capsById) {
      console.info(`[OppoManager] 根据 ProductId 精确定位: ${capsById.modelName}`);
      this.deviceCapabilities = capsById;
      this.multiDeviceManager.setCapabilities(
        capsById.dualDeviceSupported,
        capsById.multiConnectManageSupported
      );
      if (this.isConnected) {
        this.notifyStatus('subscribed');
      }
    }
  }

  /**
   * 解析固件版本响应（0x8105）
   */
  private handleFirmwareVersion(data: Uint8Array): void {
    const result = ResponseParser.parseFirmwareVersion(data);
    if (!result) return;
    if (this.firmwareVersion === result.version) return;
    this.firmwareVersion = result.version;
    console.info(`[OppoManager] 固件版本: ${result.version}`);
    if (this.firmwareCallback) {
      this.firmwareCallback(result.version);
    }
  }

  /**
   * 解析智能降噪实时档位响应
   * 0x810C 响应中，智能档位数据格式: [status(1)][subType(1)=0x04][level(1)]
   * level 值: 0x08=关闭, 0x10=深度, 0x20=中度, 0x40=轻度, 0x80=智能
   */
  private handleIntelligentAnc(data: Uint8Array): void {
    if (data.length < 12 || data[0] !== 0xAA) return;
    const cmd = (data[4] | (data[5] << 8));
    if (cmd !== 0x810C) return;
    const payLen = (data[7] | (data[8] << 8));
    const payloadStart = 9;
    if (data.length < payloadStart + payLen || payLen < 3) return;
    // 检查是否为智能档位响应: payload[1] === 0x04
    if (data[payloadStart + 1] !== 0x04) return;
    const levelVal = data[payloadStart + 2];
    let levelName = '';
    if (levelVal === 0x10) levelName = '深度';
    else if (levelVal === 0x20) levelName = '中度';
    else if (levelVal === 0x40) levelName = '轻度';
    else if (levelVal === 0x80) levelName = '智能';
    else if (levelVal === 0x08) levelName = '关闭';
    else levelName = `档位(0x${levelVal.toString(16)})`;
    if (this.intelligentAncLevel !== levelName) {
      this.intelligentAncLevel = levelName;
      console.info(`[OppoManager] 智能降噪档位: ${levelName}`);
      if (this.intelligentAncCallback) {
        this.intelligentAncCallback(levelName);
      }
    }
  }

  /**
   * 解析游戏音效响应（0x812B）
   */
  private handleGameSound(data: Uint8Array): void {
    const result = ResponseParser.parseGameSound(data);
    if (!result) return;
    if (this.gameSoundEnabled !== result.enabled) {
      this.gameSoundEnabled = result.enabled;
      console.info(`[OppoManager] 游戏音效: ${result.enabled ? '开启' : '关闭'} (selectType=${result.selectType})`);
      if (this.gameSoundCallback) {
        this.gameSoundCallback(result.enabled);
      }
    }
  }

  /**
   * 解析编解码器类型响应（0x8114）
   */
  private handleCodecType(data: Uint8Array): void {
    const result = ResponseParser.parseCodecType(data);
    if (!result) return;
    if (this.codecType === result.codec) return;
    this.codecType = result.codec;
    const name = codecName(result.codec);
    // 打印原始数据辅助调试
    if (data.length >= 11) {
      const hexStr = toHexStr(data.slice(9, 11));
      console.info(`[OppoManager] 编解码器原始数据: ${hexStr}`);
    }
    console.info(`[OppoManager] 编解码器: ${name} (id=${result.codec})`);
    if (this.codecCallback) {
      this.codecCallback(result.codec);
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
