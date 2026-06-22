import { OppoEarphoneManager, BatteryInfo, ConnectionStatus, WearState, WearStatus, getAncModeName } from '../manager/OppoEarphoneManager';
import { abilityAccessCtrl, common, Permissions, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { preferences } from '@kit.ArkData';
import { image } from '@kit.ImageKit';
import { formProvider } from '@kit.FormKit';
import { notificationManager } from '@kit.NotificationKit';
import router from '@ohos.router';

/**
 * 电量卡片子组件
 * 使用 @Prop 装饰器与父组件 @State 建立单向响应式绑定，确保电量数据变化能驱动 UI 更新
 * 注意：@Builder 按值传参无法建立响应式依赖，是导致 UI 不更新的根因
 */
@Component
struct BatteryCardComponent {
  @Prop battery: number = -1;
  @Prop charging: boolean = false;
  private label: string = '';
  private iconType: string = 'L';

  getBatteryColor(): string {
    if (this.battery < 0) {
      return '#666666';
    }
    if (this.charging) {
      return '#FFD700';
    }
    if (this.battery < 20) {
      return '#FF4444';
    }
    if (this.battery < 60) {
      return '#FF9800';
    }
    return '#4CAF50';
  }

  getBatteryText(): string {
    return this.battery < 0 ? '--' : `${this.battery}%`;
  }

  build() {
    Column() {
      // 设备图标
      Text(this.iconType === 'L' ? '🎧' : this.iconType === 'R' ? '🎧' : '🔋')
        .fontSize(30)

      // 环形电量进度条
      Stack() {
        Progress({ value: this.battery < 0 ? 0 : this.battery, total: 100, type: ProgressType.Ring })
          .width(100)
          .height(100)
          .color(this.getBatteryColor())
          .backgroundColor('#1E1E3E')

        // 中间电量百分比
        Text(this.getBatteryText())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(100)
      .height(100)
      .margin({ top: 12 })

      // 设备名称
      Text(this.label)
        .fontSize(14)
        .fontColor('#AAAACC')
        .margin({ top: 10 })

      // 充电状态
      if (this.charging) {
        Row() {
          Text('⚡')
            .fontSize(14)
          Text('充电中')
            .fontSize(13)
            .fontColor('#FFD700')
            .margin({ left: 2 })
        }
        .margin({ top: 6 })
        .padding({ left: 10, right: 10, top: 3, bottom: 3 })
        .borderRadius(12)
        .backgroundColor('#332200')
      } else if (this.battery >= 0 && this.battery < 20) {
        Text('电量低')
          .fontSize(13)
          .fontColor('#FF4444')
          .margin({ top: 6 })
          .padding({ left: 10, right: 10, top: 3, bottom: 3 })
          .borderRadius(12)
          .backgroundColor('#330000')
      }
    }
    .width('30%')
    .padding({ top: 20, bottom: 16, left: 8, right: 8 })
    .borderRadius(20)
    .backgroundColor('#12122E')
    .border({ width: 1, color: '#2A2A5E' })
    .alignItems(HorizontalAlign.Center)
  }
}

@Entry
@Component
struct Index {
  @State connectionStatus: ConnectionStatus = 'disconnected';
  @State leftBattery: number = -1;
  @State leftCharging: boolean = false;
  @State rightBattery: number = -1;
  @State rightCharging: boolean = false;
  @State caseBattery: number = -1;
  @State caseCharging: boolean = false;
  @State macAddress: string = '';
  @State hasPermission: boolean = false;
  @State scanTipVisible: boolean = false;
  // HEX原始数据展示
  @State rawHexLog: string = '';
  @State showRawData: boolean = false;
  // ANC模式
  @State ancMode: number = 1;
  // 佩戴状态
  @State leftWear: WearState = WearState.DISCONNECTED;
  @State rightWear: WearState = WearState.DISCONNECTED;
  @State caseWear: WearState = WearState.DISCONNECTED;
  // 游戏模式
  @State gameModeEnabled: boolean = false;
  // 空间音频
  @State spatialAudioEnabled: boolean = false;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  // 弹窗背景图片
  @State popupBgImage: string = '';
  @State popupBgMessage: string = '';
  // 通知管理
  @State persistentNotifyEnabled: boolean = false;
  // TabBar
  @State currentIndex: number = 0;

  private manager: OppoEarphoneManager = OppoEarphoneManager.getInstance();

  aboutToAppear(): void {
    // 设置应用上下文，用于桌面卡片数据刷新
    this.manager.setContext(getContext(this) as common.UIAbilityContext);
    this.manager.setCallbacks(
      (info: BatteryInfo) => {
        console.info(`[Index] 收到电量更新: 左=${info.leftBattery}, 右=${info.rightBattery}, 仓=${info.caseBattery}`);
        // 断开连接时电量为-1，直接重置UI电量显示
        if (info.leftBattery < 0 && info.rightBattery < 0 && info.caseBattery < 0) {
          this.leftBattery = -1;
          this.rightBattery = -1;
          this.caseBattery = -1;
          this.leftCharging = false;
          this.rightCharging = false;
          this.caseCharging = false;
          return;
        }
        // 仅响应整十电量数据（0, 10, 20, ..., 100），非整十不刷新UI
        if (info.leftBattery >= 0 && info.leftBattery % 10 === 0) {
          this.leftBattery = info.leftBattery;
          this.leftCharging = info.leftCharging;
        }
        if (info.rightBattery >= 0 && info.rightBattery % 10 === 0) {
          this.rightBattery = info.rightBattery;
          this.rightCharging = info.rightCharging;
        }
        if (info.caseBattery >= 0 && info.caseBattery % 10 === 0) {
          this.caseBattery = info.caseBattery;
          this.caseCharging = info.caseCharging;
        }
      },
      (status: ConnectionStatus) => {
        this.connectionStatus = status;
        if (status === 'connected' || status === 'subscribed') {
          this.macAddress = this.manager.getMacAddress();
        }
        if (status === 'disconnected') {
          this.macAddress = '';
        }
      },
      (hex: string) => {
        // 追加原始HEX数据日志，保留最近20条
        let timestamp = new Date().toLocaleTimeString();
        let newLine = `[${timestamp}] ${hex}`;
        let lines = this.rawHexLog ? this.rawHexLog.split('\n') : [];
        lines.push(newLine);
        if (lines.length > 20) {
          lines = lines.slice(lines.length - 20);
        }
        this.rawHexLog = lines.join('\n');
      },
      (mode: number) => {
        // ANC 模式更新
        this.ancMode = mode;
        console.info(`[Index] ANC模式: ${getAncModeName(mode)}`);
      },
      (wear: WearStatus) => {
        // 佩戴状态更新
        this.leftWear = wear.left;
        this.rightWear = wear.right;
        this.caseWear = wear.case;
        console.info(`[Index] 佩戴状态: L=${wear.left}, R=${wear.right}, C=${wear.case}`);
      },
      (enabled: boolean) => {
        // 游戏模式更新
        this.gameModeEnabled = enabled;
        console.info(`[Index] 游戏模式: ${enabled ? '开启' : '关闭'}`);
      },
      (enabled: boolean) => {
        // 空间音频更新
        this.spatialAudioEnabled = enabled;
        console.info(`[Index] 空间音频: ${enabled ? '开启' : '关闭'}`);
      }
    );
    
    // 立即请求权限并开始监听
    this.requestBluetoothPermissionAndStartMonitor();

    // 加载已保存的弹窗背景图片
    this.loadPopupBackground();

    // 加载通知设置
    this.loadNotificationSettings();
  }

  aboutToDisappear(): void {
    this.manager.disconnect(true);
  }

  /**
   * 请求蓝牙权限
   */
  async requestBluetoothPermission(): Promise<void> {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let atManager = abilityAccessCtrl.createAtManager();
      let permissions: Array<Permissions> = ['ohos.permission.ACCESS_BLUETOOTH'];
      let result = await atManager.requestPermissionsFromUser(context, permissions);
      this.hasPermission = result.authResults[0] === 0;
      if (!this.hasPermission) {
        console.warn('[Index] 蓝牙权限被拒绝');
      }
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[Index] 请求权限失败: ${error.message}`);
    }
  }

  /**
   * 请求蓝牙权限并立即开始监听
   */
  async requestBluetoothPermissionAndStartMonitor(): Promise<void> {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let atManager = abilityAccessCtrl.createAtManager();
      let permissions: Array<Permissions> = ['ohos.permission.ACCESS_BLUETOOTH'];
      let result = await atManager.requestPermissionsFromUser(context, permissions);
      this.hasPermission = result.authResults[0] === 0;
      
      if (this.hasPermission) {
        console.info('[Index] 蓝牙权限已获取，立即开始持续监听...');
        // 权限获取成功后，立即启动持续监听模式
        this.manager.startContinuousMonitor();
      } else {
        console.warn('[Index] 蓝牙权限被拒绝');
      }
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[Index] 请求权限失败: ${error.message}`);
    }
  }

  /**
   * 获取连接状态文本
   */
  getStatusText(): string {
    switch (this.connectionStatus) {
      case 'disconnected':
        return '正在监听蓝牙设备...';
      case 'scanning':
        return '正在扫描耳机...';
      case 'connecting':
        return '正在连接...';
      case 'connected':
        return '正在发现服务...';
      case 'subscribed':
        return '已连接';
      default:
        return '未知';
    }
  }

  /**
   * 获取连接状态颜色
   */
  getStatusColor(): string {
    switch (this.connectionStatus) {
      case 'disconnected':
        return '#9E9E9E';
      case 'scanning':
        return '#2196F3';
      case 'connecting':
        return '#FF9800';
      case 'connected':
        return '#2196F3';
      case 'subscribed':
        return '#4CAF50';
      default:
        return '#9E9E9E';
    }
  }

  /**
   * 判断是否正在处理中（扫描/连接/发现服务）
   */
  isBusy(): boolean {
    return this.connectionStatus === 'scanning' ||
      this.connectionStatus === 'connecting' ||
      this.connectionStatus === 'connected';
  }

  /**
   * 加载已保存的弹窗背景图片路径
   */
  private loadPopupBackground(): void {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let pref = preferences.getPreferencesSync(context, { name: 'popup_settings' });
      let savedPath = pref.getSync('popupBgImage', '') as string;
      if (savedPath && fileIo.accessSync(savedPath)) {
        this.popupBgImage = savedPath;
      }
    } catch (e) {
      console.warn('[Index] 加载弹窗背景失败');
    }
  }

  /**
   * 加载通知设置
   */
  private loadNotificationSettings(): void {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let pref = preferences.getPreferencesSync(context, { name: 'app_settings' });
      this.persistentNotifyEnabled = pref.getSync('persistentNotifyEnabled', false) as boolean;
      // 如果开关打开且已连接，启动后台服务
      if (this.persistentNotifyEnabled && this.manager.getIsConnected()) {
        this.manager.startBackgroundService();
      }
    } catch (e) {
      console.warn('[Index] 加载通知设置失败');
    }
  }

  /**
   * 切换常驻通知开关
   */
  private togglePersistentNotification(isOn: boolean): void {
    if (isOn) {
      // 开启：先检查通知权限（使用同步版本，避免异步缓存问题）
      try {
        let enabled = notificationManager.isNotificationEnabledSync();
        if (!enabled) {
          // 未授权，弹出系统申请对话框
          this.requestNotificationPermission();
          return;
        }
        // 已授权，直接启动
        this.persistentNotifyEnabled = true;
        this.saveNotifySetting(true);
        if (this.manager.getIsConnected()) {
          this.manager.startBackgroundService();
        }
      } catch (err) {
        let error = err as BusinessError;
        console.error(`[Index] 检查通知权限失败: ${error.message}`);
        // 检查失败时不默认开启，让用户重试
      }
    } else {
      // 关闭
      this.persistentNotifyEnabled = false;
      this.saveNotifySetting(false);
      this.manager.stopBackgroundService();
    }
  }

  /**
   * 保存通知设置到 Preferences
   */
  private saveNotifySetting(enabled: boolean): void {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let pref = preferences.getPreferencesSync(context, { name: 'app_settings' });
      pref.putSync('persistentNotifyEnabled', enabled);
      pref.flush();
    } catch (e) {
      console.warn('[Index] 保存通知设置失败');
    }
  }

  /**
   * 申请通知权限
   */
  private async requestNotificationPermission(): Promise<void> {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      await notificationManager.requestEnableNotification(context);
      // 用户授权成功
      this.persistentNotifyEnabled = true;
      this.saveNotifySetting(true);
      if (this.manager.getIsConnected()) {
        this.manager.startBackgroundService();
      }
    } catch (err) {
      let error = err as BusinessError;
      if (error.code === 1600004) {
        // 用户拒绝授权
        this.persistentNotifyEnabled = false;
      } else {
        console.error(`[Index] 请求通知权限失败: ${error.code} ${error.message}`);
      }
    }
  }

  /**
   * 选择图片作为弹窗背景
   */
  private async selectPopupBackground(): Promise<void> {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let picker = new photoAccessHelper.PhotoViewPicker();
      let result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris && result.photoUris.length > 0) {
        let srcUri = result.photoUris[0];
        let destPath = context.filesDir + '/popup_bg.jpg';
        // 通过 image 框架解码源图片并转为 JPEG，兼容 HEIC 等格式
        let srcFile = fileIo.openSync(srcUri, fileIo.OpenMode.READ_ONLY);
        let imgSource = image.createImageSource(srcFile.fd);
        let packer = image.createImagePacker();
        let destFile = fileIo.openSync(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
        await packer.packToFile(imgSource, destFile.fd, { format: 'image/jpeg', quality: 90 });
        packer.release();
        imgSource.release();
        fileIo.closeSync(destFile.fd);
        fileIo.closeSync(srcFile.fd);
        // 保存到 Preferences
        let pref = preferences.getPreferencesSync(context, { name: 'popup_settings' });
        pref.putSync('popupBgImage', destPath);
        pref.flush();
        this.popupBgImage = destPath;
        this.popupBgMessage = '弹窗背景已设置';
        setTimeout(() => { this.popupBgMessage = ''; }, 3000);
      }
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[Index] 选择图片失败: ${error.message}`);
      this.popupBgMessage = '选择失败，请重试';
      setTimeout(() => { this.popupBgMessage = ''; }, 3000);
    }
  }

  /**
   * 预览弹窗
   */
  private previewPopup(): void {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let want: Want = {
        bundleName: 'com.hzx.encoair',
        abilityName: 'EntryAbility',
        parameters: {
          'show_popup': true as Object
        } as Record<string, Object>
      };
      context.startAbility(want);
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[Index] 预览弹窗失败: ${error.message}`);
    }
  }

  /**
   * 打开系统桌面卡片选择器
   */
  private openWidgetPicker(): void {
    let want: Want = {
      bundleName: 'com.hzx.encoair',
      abilityName: 'BatteryFormAbility',
      parameters: {
        'ohos.extra.param.key.form_dimension': 2 as Object,
        'ohos.extra.param.key.form_name': 'BatteryWidget' as Object,
        'ohos.extra.param.key.module_name': 'entry' as Object
      } as Record<string, Object>
    };
    try {
      formProvider.openFormManager(want);
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[Index] 打开卡片管理器失败: ${error.message}`);
    }
  }

  /**
   * 重置弹窗背景为默认
   */
  private resetPopupBackground(): void {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let destPath = context.filesDir + '/popup_bg.jpg';
      // 删除沙箱中的图片文件
      if (fileIo.accessSync(destPath)) {
        fileIo.unlinkSync(destPath);
      }
      let pref = preferences.getPreferencesSync(context, { name: 'popup_settings' });
      pref.deleteSync('popupBgImage');
      pref.flush();
      this.popupBgImage = '';
      this.popupBgMessage = '已恢复默认背景';
      setTimeout(() => { this.popupBgMessage = ''; }, 3000);
    } catch (e) {
      console.warn('[Index] 重置弹窗背景失败');
    }
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        Column() {
          Scroll() {
            Column() {
              // 标题区域
              this.TitleSection();

              // 连接状态区域
              this.StatusSection();

              // 电量卡片区域
              this.BatterySection();

              // 设备状态区域 (ANC/佩戴/游戏模式)
              this.DeviceStatusSection();

              // 操作按钮区域
              this.ActionSection();

              // 底部提示
              this.TipSection();
            }
            .width('100%')
            .padding({ top: this.statusBarHeight })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .width('100%')
        .height('100%')
      }
      .tabBar(this.TabBarItem('🏠', '主页', 0))

      TabContent() {
        this.SettingsPage()
      }
      .tabBar(this.TabBarItem('⚙️', '设置', 1))
    }
    .barHeight(56)
    .barMode(BarMode.Fixed)
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .linearGradient({
      angle: 180,
      colors: [['#0D0D1A', 0.0], ['#1A1A3E', 0.5], ['#0D0D2B', 1.0]]
    })
    .onChange((index: number) => {
      this.currentIndex = index;
    })
  }

  // ============== 标题区域 ==============
  @Builder TitleSection() {
    Column() {
      Text('Air5 Pro')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .letterSpacing(1)

      Text('耳机助手')
        .fontSize(16)
        .fontColor('#8888AA')
        .margin({ top: 6 })
    }
    .margin({ top: 12 })
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  // ============== 连接状态区域 ==============
  @Builder StatusSection() {
    Column() {
      Row() {
        // 状态指示灯
        Row()
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(this.getStatusColor())

        Text(this.getStatusText())
          .fontSize(15)
          .fontColor(this.getStatusColor())
          .margin({ left: 8 })
          .fontWeight(FontWeight.Medium)

        if (this.macAddress) {
          Text(this.macAddress)
            .fontSize(12)
            .fontColor('#666688')
            .margin({ left: 10 })
            .fontFamily('monospace')
        }
      }
    }
    .width('85%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .borderRadius(25)
    .backgroundColor('#1A1A3E')
    .border({ width: 1, color: '#2A2A5E' })
    .margin({ top: 25 })
    .alignItems(HorizontalAlign.Center)
  }

  // ============== 电量卡片区域 ==============
  @Builder BatterySection() {
    Row() {
      BatteryCardComponent({ battery: this.leftBattery, charging: this.leftCharging, label: '左耳', iconType: 'L' })
      BatteryCardComponent({ battery: this.rightBattery, charging: this.rightCharging, label: '右耳', iconType: 'R' })
      BatteryCardComponent({ battery: this.caseBattery, charging: this.caseCharging, label: '充电仓', iconType: 'C' })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .margin({ top: 35 })
    .padding({ left: 12, right: 12 })
  }

  // ============== 操作按钮区域 ==============
  @Builder ActionSection() {
    Column() {
      if (this.connectionStatus === 'disconnected') {
        // 未连接 - 显示重连按钮
        Button() {
          Row() {
            Text('🔄')
              .fontSize(18)
            Text('  重新连接')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
          }
        }
        .width('80%')
        .height(52)
        .backgroundColor('#2A5CFF')
        .borderRadius(26)
        .enabled(this.hasPermission)
        .opacity(this.hasPermission ? 1.0 : 0.5)
        .onClick(() => {
          if (this.hasPermission) {
            this.manager.startAutoConnect();
          }
        })
      } else if (this.isBusy()) {
        // 处理中 - 显示取消按钮
        Button() {
          Row() {
            Text('⏹')
              .fontSize(18)
            Text('  取消')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
          }
        }
        .width('80%')
        .height(52)
        .backgroundColor('#FF6B35')
        .borderRadius(26)
        .onClick(() => {
          this.manager.disconnect();
        })
      } else {
        // 已连接 - 显示断开按钮
        Button() {
          Row() {
            Text('🔗')
              .fontSize(18)
            Text('  断开连接')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
          }
        }
        .width('80%')
        .height(52)
        .backgroundColor('#FF4444')
        .borderRadius(26)
        .onClick(() => {
          this.manager.disconnect();
        })
      }

      // 权限未授予时的提示
      if (!this.hasPermission) {
        Text('请授予蓝牙权限后使用')
          .fontSize(13)
          .fontColor('#FF6B6B')
          .margin({ top: 12 })
      }
    }
    .margin({ top: 40 })
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  // ============== HEX原始数据区域 ==============
  @Builder RawDataSection() {
    Column() {
      // 标题行，可点击展开/收起
      Row() {
        Text('HEX 原始数据')
          .fontSize(14)
          .fontColor('#AAAACC')
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(this.showRawData ? '收起 ▲' : '展开 ▼')
          .fontSize(12)
          .fontColor('#6666AA')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .onClick(() => {
        this.showRawData = !this.showRawData;
      })

      if (this.showRawData) {
        Scroll() {
          Text(this.rawHexLog || '等待数据...')
            .fontSize(11)
            .fontColor('#88AACC')
            .fontFamily('monospace')
            .width('100%')
            .copyOption(CopyOptions.LocalDevice)
        }
        .width('100%')
        .height(120)
        .padding({ left: 16, right: 16, top: 4, bottom: 8 })
      }
    }
    .width('85%')
    .borderRadius(16)
    .backgroundColor('#12122E')
    .border({ width: 1, color: '#2A2A5E' })
    .margin({ top: 20 })
    .clip(true)
  }

  // ============== 设备状态区域 ==============
  @Builder DeviceStatusSection() {
    Column() {
      // ANC 标题
      Row() {
        Text('🎵')
          .fontSize(18)
        Text(' ANC 模式')
          .fontSize(14)
          .fontColor('#AAAACC')
          .margin({ left: 6 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // ANC 三个按键（降噪、关闭、通透）
      if (this.connectionStatus === 'subscribed') {
        Row() {
          // 降噪按钮
          Column() {
            Button('降噪')
              .fontSize(15)
              .fontWeight(this.ancMode === 2 || this.ancMode === 5 || this.ancMode === 6 || this.ancMode === 7 || this.ancMode === 8 ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.ancMode === 2 || this.ancMode === 5 || this.ancMode === 6 || this.ancMode === 7 || this.ancMode === 8 ? '#FFFFFF' : '#AAAACC')
              .width('90%')
              .height(45)
              .backgroundColor(this.ancMode === 2 || this.ancMode === 5 || this.ancMode === 6 || this.ancMode === 7 || this.ancMode === 8 ? '#2A5CFF' : '#1E1E3E')
              .borderRadius(12)
              .border({
                width: 1,
                color: this.ancMode === 2 || this.ancMode === 5 || this.ancMode === 6 || this.ancMode === 7 || this.ancMode === 8 ? '#4A7CFF' : '#2A2A5E'
              })
              .shadow({ radius: 10, color: this.ancMode === 2 || this.ancMode === 5 || this.ancMode === 6 || this.ancMode === 7 || this.ancMode === 8 ? '#4A7CFF' : '#00000000', offsetX: this.ancMode === 2 || this.ancMode === 5 || this.ancMode === 6 || this.ancMode === 7 || this.ancMode === 8 ? 8 : 0, offsetY: this.ancMode === 2 || this.ancMode === 5 || this.ancMode === 6 || this.ancMode === 7 || this.ancMode === 8 ? 8 : 0 })
              .onClick(() => {
                this.manager.setAncMode(2);
              })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          // 关闭按钮
          Column() {
            Button('关闭')
              .fontSize(15)
              .fontWeight(this.ancMode === 1 ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.ancMode === 1 ? '#FFFFFF' : '#AAAACC')
              .width('90%')
              .height(45)
              .backgroundColor(this.ancMode === 1 ? '#2A5CFF' : '#1E1E3E')
              .borderRadius(12)
              .border({
                width: 1,
                color: this.ancMode === 1 ? '#4A7CFF' : '#2A2A5E'
              })
              .shadow({ radius: 10, color: this.ancMode === 1 ? '#4A7CFF' : '#00000000', offsetX: this.ancMode === 1 ? 8 : 0, offsetY: this.ancMode === 1 ? 8 : 0 })
              .onClick(() => {
                this.manager.setAncMode(1);
              })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          // 通透按钮
          Column() {
            Button('通透')
              .fontSize(15)
              .fontWeight(this.ancMode === 3 ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.ancMode === 3 ? '#FFFFFF' : '#AAAACC')
              .width('90%')
              .height(45)
              .backgroundColor(this.ancMode === 3 ? '#2A5CFF' : '#1E1E3E')
              .borderRadius(12)
              .border({
                width: 1,
                color: this.ancMode === 3 ? '#4A7CFF' : '#2A2A5E'
              })
              .shadow({ radius: 10, color: this.ancMode === 3 ? '#4A7CFF' : '#00000000', offsetX: this.ancMode === 3 ? 8 : 0, offsetY: this.ancMode === 3 ? 8 : 0 })
              .onClick(() => {
                this.manager.setAncMode(3);
              })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 4 })

        // 降噪子模式选择（智能/轻度/中度/深度）
        if (this.isNoiseCancellationMode()) {
          Row() {
            // 智能降噪按钮
            Column() {
              Button('智能')
                .fontSize(13)
                .fontWeight(this.ancMode === 5 ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.ancMode === 5 ? '#FFFFFF' : '#8888AA')
                .width('90%')
                .height(36)
                .backgroundColor(this.ancMode === 5 ? '#2A5CFF' : '#1A1A3E')
                .borderRadius(10)
                .border({
                  width: 1,
                  color: this.ancMode === 5 ? '#4A7CFF' : '#2A2A5E'
                })
                .shadow({ radius: 6, color: this.ancMode === 5 ? '#4A7CFF' : '#00000000', offsetX: this.ancMode === 5 ? 4 : 0, offsetY: this.ancMode === 5 ? 4 : 0 })
                .onClick(() => {
                  this.manager.setAncMode(5);
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)

            // 轻度降噪按钮
            Column() {
              Button('轻度')
                .fontSize(13)
                .fontWeight(this.ancMode === 6 ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.ancMode === 6 ? '#FFFFFF' : '#8888AA')
                .width('90%')
                .height(36)
                .backgroundColor(this.ancMode === 6 ? '#2A5CFF' : '#1A1A3E')
                .borderRadius(10)
                .border({
                  width: 1,
                  color: this.ancMode === 6 ? '#4A7CFF' : '#2A2A5E'
                })
                .shadow({ radius: 6, color: this.ancMode === 6 ? '#4A7CFF' : '#00000000', offsetX: this.ancMode === 6 ? 4 : 0, offsetY: this.ancMode === 6 ? 4 : 0 })
                .onClick(() => {
                  this.manager.setAncMode(6);
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)

            // 中度降噪按钮
            Column() {
              Button('中度')
                .fontSize(13)
                .fontWeight(this.ancMode === 7 ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.ancMode === 7 ? '#FFFFFF' : '#8888AA')
                .width('90%')
                .height(36)
                .backgroundColor(this.ancMode === 7 ? '#2A5CFF' : '#1A1A3E')
                .borderRadius(10)
                .border({
                  width: 1,
                  color: this.ancMode === 7 ? '#4A7CFF' : '#2A2A5E'
                })
                .shadow({ radius: 6, color: this.ancMode === 7 ? '#4A7CFF' : '#00000000', offsetX: this.ancMode === 7 ? 4 : 0, offsetY: this.ancMode === 7 ? 4 : 0 })
                .onClick(() => {
                  this.manager.setAncMode(7);
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)

            // 深度降噪按钮
            Column() {
              Button('深度')
                .fontSize(13)
                .fontWeight(this.ancMode === 8 ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.ancMode === 8 ? '#FFFFFF' : '#8888AA')
                .width('90%')
                .height(36)
                .backgroundColor(this.ancMode === 8 ? '#2A5CFF' : '#1A1A3E')
                .borderRadius(10)
                .border({
                  width: 1,
                  color: this.ancMode === 8 ? '#4A7CFF' : '#2A2A5E'
                })
                .shadow({ radius: 6, color: this.ancMode === 8 ? '#4A7CFF' : '#00000000', offsetX: this.ancMode === 8 ? 4 : 0, offsetY: this.ancMode === 8 ? 4 : 0 })
                .onClick(() => {
                  this.manager.setAncMode(8);
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 4 })
        }
      } else {
        Text('--')
          .fontSize(14)
          .fontColor('#666688')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 20, bottom: 20 })
      }

      // 佩戴状态
      Row() {
        Text('👂')
          .fontSize(18)
        Text(' 佩戴状态')
          .fontSize(14)
          .fontColor('#AAAACC')
          .margin({ left: 6 })

        Blank()

        if (this.connectionStatus === 'subscribed') {
          Row() {
            Text(`L:${this.getWearText(this.leftWear)}`)
              .fontSize(12)
              .fontColor(this.getWearColor(this.leftWear))
            Text('  ')
            Text(`R:${this.getWearText(this.rightWear)}`)
              .fontSize(12)
              .fontColor(this.getWearColor(this.rightWear))
            Text('  ')
            Text(`C:${this.getWearText(this.caseWear)}`)
              .fontSize(12)
              .fontColor(this.getWearColor(this.caseWear))
          }
        } else {
          Text('--')
            .fontSize(14)
            .fontColor('#666688')
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })

      // 游戏模式
      Row() {
        Text('🎮')
          .fontSize(18)
        Text(' 游戏模式')
          .fontSize(14)
          .fontColor('#AAAACC')
          .margin({ left: 6 })

        Blank()

        if (this.connectionStatus === 'subscribed') {
          Button(this.gameModeEnabled ? '已开启' : '已关闭')
            .fontSize(13)
            .height(32)
            .backgroundColor(this.gameModeEnabled ? '#4CAF50' : '#666666')
            .borderRadius(16)
            .onClick(() => {
              // 切换游戏模式
              this.manager.setGameMode(!this.gameModeEnabled);
            })
        } else {
          Text('--')
            .fontSize(14)
            .fontColor('#666688')
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })

      // 空间音频
      Row() {
        Text('🎧')
          .fontSize(18)
        Text(' 空间音频')
          .fontSize(14)
          .fontColor('#AAAACC')
          .margin({ left: 6 })

        Blank()

        if (this.connectionStatus === 'subscribed') {
          Button(this.spatialAudioEnabled ? '已开启' : '已关闭')
            .fontSize(13)
            .height(32)
            .backgroundColor(this.spatialAudioEnabled ? '#4CAF50' : '#666666')
            .borderRadius(16)
            .onClick(() => {
              // 切换空间音频
              this.manager.setSpatialAudio(!this.spatialAudioEnabled);
            })
        } else {
          Text('--')
            .fontSize(14)
            .fontColor('#666688')
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    }
    .width('85%')
    .borderRadius(16)
    .backgroundColor('#12122E')
    .border({ width: 1, color: '#2A2A5E' })
    .margin({ top: 20 })
  }

  // ANC 单个按钮组件
  @Builder AncButton(label: string, isSelected: boolean, onClick: () => void) {
    Column() {
      // 按钮容器
      Button(label)
        .fontSize(15)
        .fontWeight(isSelected ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(isSelected ? '#FFFFFF' : '#AAAACC')
        .width('90%')
        .height(45)
        .backgroundColor(isSelected ? '#2A5CFF' : '#1E1E3E')
        .borderRadius(12)
        .border({
          width: 1,
          color: isSelected ? '#4A7CFF' : '#2A2A5E'
        })
        .shadow({ radius: 10, color: isSelected ? '#4A7CFF' : '#00000000', offsetX: isSelected ? 8 : 0, offsetY: isSelected ? 8 : 0 })
        .onClick(onClick)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  // ANC 子模式按钮组件（智能/轻度/中度/深度）
  @Builder AncSubButton(label: string, isSelected: boolean, onClick: () => void) {
    Column() {
      Button(label)
        .fontSize(13)
        .fontWeight(isSelected ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(isSelected ? '#FFFFFF' : '#8888AA')
        .width('90%')
        .height(36)
        .backgroundColor(isSelected ? '#2A5CFF' : '#1A1A3E')
        .borderRadius(10)
        .border({
          width: 1,
          color: isSelected ? '#4A7CFF' : '#2A2A5E'
        })
        .shadow({ radius: 6, color: isSelected ? '#4A7CFF' : '#00000000', offsetX: isSelected ? 4 : 0, offsetY: isSelected ? 4 : 0 })
        .onClick(onClick)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  // 判断是否为降噪模式（包含所有降噪子模式）
  isNoiseCancellationMode(): boolean {
    return this.ancMode === 2 || this.ancMode === 5 || 
           this.ancMode === 6 || this.ancMode === 7 || this.ancMode === 8;
  }

  // 佩戴状态文本
  getWearText(state: WearState): string {
    switch (state) {
      case WearState.WEARING: return '佩戴';
      case WearState.IN_CASE: return '在仓';
      case WearState.REMOVED: return '取出';
      default: return '断开';
    }
  }

  // 佩戴状态颜色
  getWearColor(state: WearState): string {
    switch (state) {
      case WearState.WEARING: return '#4CAF50';
      case WearState.IN_CASE: return '#FFD700';
      case WearState.REMOVED: return '#2196F3';
      default: return '#666688';
    }
  }

  // ============== 底部提示区域 ==============
  @Builder TipSection() {
    Column() {
      if (this.connectionStatus === 'disconnected' || this.connectionStatus === 'scanning') {
        Text('已开启自动监听,检测到耳机会自动连接')
          .fontSize(12)
          .fontColor('#6666AA')
          .textAlign(TextAlign.Center)
          .padding({ left: 30, right: 30 })
      }

      Blank()

      Text('Air5 Pro 耳机助手')
        .fontSize(11)
        .fontColor('#444466')
        .margin({ bottom: 30 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ bottom: 20 })
  }

  // ============== TabBar 按钮 ==============
  @Builder TabBarItem(icon: string, title: string, index: number) {
    Column() {
      Text(icon)
        .fontSize(22)
      Text(title)
        .fontSize(11)
        .fontColor(this.currentIndex === index ? '#FFFFFF' : '#666688')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ============== 设置页面 ==============
  @Builder SettingsPage() {
    Scroll() {
      Column() {
        // 标题
        Text('设置')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .margin({ top: 20 })

        // ====== 通知管理 ======
        Column() {
          Row() {
            Text('🔔')
              .fontSize(18)
            Text(' 通知管理')
              .fontSize(14)
              .fontColor('#AAAACC')
              .margin({ left: 6 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 8 })

          Row() {
            Text('常驻通知显示电量')
              .fontSize(14)
              .fontColor('#EEEEFF')
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.persistentNotifyEnabled })
              .selectedColor('#2A5CFF')
              .switchPointColor('#FFFFFF')
              .onChange((isOn: boolean) => {
                this.togglePersistentNotification(isOn);
              })
          }
          .width('85%')
          .height(44)
          .padding({ left: 12, right: 4 })

          Text('开启后在状态栏显示电量和ANC状态，并保持后台连接')
            .fontSize(11)
            .fontColor('#666688')
            .width('85%')
            .margin({ bottom: 12 })
        }
        .width('85%')
        .borderRadius(16)
        .backgroundColor('#12122E')
        .border({ width: 1, color: '#2A2A5E' })
        .margin({ top: 24 })
        .alignItems(HorizontalAlign.Center)

        // ====== 弹窗背景设置 ======
        Column() {
          Row() {
            Text('🖼️')
              .fontSize(18)
            Text(' 弹窗背景')
              .fontSize(14)
              .fontColor('#AAAACC')
              .margin({ left: 6 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 8 })

          Button() {
            Row() {
              Text('🖼️')
                .fontSize(16)
              Text(this.popupBgImage ? '  更换弹窗背景' : '  设置弹窗背景')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
            }
          }
          .width('85%')
          .height(44)
          .backgroundColor('#1E1E3E')
          .borderRadius(22)
          .border({ width: 1, color: '#2A2A5E' })
          .onClick(() => {
            this.selectPopupBackground();
          })

          Button('预览弹窗')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .width('85%')
            .height(40)
            .backgroundColor('#2A5CFF')
            .borderRadius(20)
            .margin({ top: 10 })
            .onClick(() => {
              this.previewPopup();
            })

          if (this.popupBgImage) {
            Button('恢复默认背景')
              .fontSize(13)
              .fontColor('#8888AA')
              .height(34)
              .backgroundColor('#00000000')
              .margin({ top: 8 })
              .onClick(() => {
                this.resetPopupBackground();
              })
          }

          if (this.popupBgMessage) {
            Text(this.popupBgMessage)
              .fontSize(12)
              .fontColor('#4CAF50')
              .margin({ top: 6 })
          }
        }
        .width('85%')
        .borderRadius(16)
        .backgroundColor('#12122E')
        .border({ width: 1, color: '#2A2A5E' })
        .margin({ top: 24 })
        .alignItems(HorizontalAlign.Center)
        .padding({ bottom: 16 })

        // ====== 使用帮助 ======
        Column() {
          Row() {
            Text('❓')
              .fontSize(18)
            Text(' 使用帮助')
              .fontSize(14)
              .fontColor('#AAAACC')
              .margin({ left: 6 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 8 })

          Text('查看各功能的使用说明和常见问题')
            .fontSize(12)
            .fontColor('#666688')
            .width('85%')
            .margin({ bottom: 12 })

          Button('打开使用帮助')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .width('85%')
            .height(40)
            .backgroundColor('#2A5CFF')
            .borderRadius(20)
            .onClick(() => {
              router.pushUrl({ url: 'pages/HelpPage' });
            })
        }
        .width('85%')
        .borderRadius(16)
        .backgroundColor('#12122E')
        .border({ width: 1, color: '#2A2A5E' })
        .margin({ top: 20 })
        .alignItems(HorizontalAlign.Center)
        .padding({ bottom: 16 })

        // ====== 桌面组件 ======
        Column() {
          Row() {
            Text('📱')
              .fontSize(18)
            Text(' 桌面组件')
              .fontSize(14)
              .fontColor('#AAAACC')
              .margin({ left: 6 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 8 })

          Text('将电量卡片添加到桌面或负一屏，随时查看耳机电量，数据刷新会有延迟')
            .fontSize(12)
            .fontColor('#666688')
            .width('85%')
            .margin({ bottom: 12 })

          Button('添加桌面卡片')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .width('85%')
            .height(40)
            .backgroundColor('#2A5CFF')
            .borderRadius(20)
            .onClick(() => {
              this.openWidgetPicker();
            })
        }
        .width('85%')
        .borderRadius(16)
        .backgroundColor('#12122E')
        .border({ width: 1, color: '#2A2A5E' })
        .margin({ top: 20 })
        .alignItems(HorizontalAlign.Center)
        .padding({ bottom: 16 })

        // ====== HEX 原始数据 ======
        Column() {
          // 标题行，可点击展开/收起
          Row() {
            Text('HEX 原始数据')
              .fontSize(14)
              .fontColor('#AAAACC')
              .fontWeight(FontWeight.Medium)

            Blank()

            Text(this.showRawData ? '收起 ▲' : '展开 ▼')
              .fontSize(12)
              .fontColor('#6666AA')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .onClick(() => {
            this.showRawData = !this.showRawData;
          })

          if (this.showRawData) {
            Scroll() {
              Text(this.rawHexLog || '等待数据...')
                .fontSize(11)
                .fontColor('#88AACC')
                .fontFamily('monospace')
                .width('100%')
                .copyOption(CopyOptions.LocalDevice)
            }
            .width('100%')
            .height(120)
            .padding({ left: 16, right: 16, top: 4, bottom: 8 })
          }
        }
        .width('85%')
        .borderRadius(16)
        .backgroundColor('#12122E')
        .border({ width: 1, color: '#2A2A5E' })
        .margin({ top: 20 })
        .clip(true)
      }
      .width('100%')
      .padding({ top: this.statusBarHeight, bottom: 20 })
      .alignItems(HorizontalAlign.Center)
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
