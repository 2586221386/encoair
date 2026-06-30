import { OppoEarphoneManager } from '../manager/OppoEarphoneManager';
import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { preferences } from '@kit.ArkData';
import { image } from '@kit.ImageKit';
import { formProvider } from '@kit.FormKit';
import { notificationManager } from '@kit.NotificationKit';
import router from '@ohos.router';
import { cardBg, borderColor, textPrimary, textSecondary, textTertiary, textMuted, descTextColor, tipTextColor, btnInactiveBg, accentPrimary, accentGreen } from '../common/AppTheme';
import { CapabilityOverrides, CAP_OVERRIDE_AUTO, CAP_OVERRIDE_FORCE_ENABLED, CAP_OVERRIDE_FORCE_DISABLED } from '../common/DeviceCapabilities';

/**
 * 设置页面子组件
 * 从 Index.ets 分离，管理所有设置相关状态和交互
 */
@Component
export struct SettingsPage {
  /** 来自主页的 HEX 原始数据（只读） */
  @Prop rawHexLog: string = '';
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('isDarkMode') isDarkMode: boolean = true;

  // 弹窗背景图片
  @State popupBgImage: string = '';
  @State popupBgMessage: string = '';
  // 通知管理
  @State persistentNotifyEnabled: boolean = false;
  // HEX 数据展开/收起（设置页独立控制）
  @State showRawHex: boolean = false;
  // 设备能力覆写
  @State spatialSoundOverride: number = CAP_OVERRIDE_AUTO;
  @State legacyAncOverride: number = CAP_OVERRIDE_AUTO;

  // 操作提示消息
  @State capabilityMessage: string = '';

  private manager: OppoEarphoneManager = OppoEarphoneManager.getInstance();

  aboutToAppear(): void {
    // 加载已保存的弹窗背景图片
    this.loadPopupBackground();
    // 加载通知设置
    this.loadNotificationSettings();
    // 加载能力覆写设置
    this.loadOverrideSettings();
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
      console.warn('[Settings] 加载弹窗背景失败');
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
      console.warn('[Settings] 加载通知设置失败');
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
        console.error(`[Settings] 检查通知权限失败: ${error.message}`);
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
      console.warn('[Settings] 保存通知设置失败');
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
        console.error(`[Settings] 请求通知权限失败: ${error.code} ${error.message}`);
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
        let isGif = srcUri.toLowerCase().endsWith('.gif');
        let destPath: string;
        if (isGif) {
          // GIF 格式：直接复制原始文件，保留动画帧
          destPath = context.filesDir + '/popup_bg.gif';
          let srcFile = fileIo.openSync(srcUri, fileIo.OpenMode.READ_ONLY);
          let destFile = fileIo.openSync(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY |
          fileIo.OpenMode.TRUNC);
          fileIo.copyFileSync(srcFile.fd, destFile.fd);
          fileIo.closeSync(destFile.fd);
          fileIo.closeSync(srcFile.fd);
        } else {
          // 非 GIF：通过 ImageKit 转 JPEG（兼容 HEIC 等格式）
          destPath = context.filesDir + '/popup_bg.jpg';
          let srcFile = fileIo.openSync(srcUri, fileIo.OpenMode.READ_ONLY);
          let imgSource = image.createImageSource(srcFile.fd);
          let packer = image.createImagePacker();
          let destFile = fileIo.openSync(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY |
          fileIo.OpenMode.TRUNC);
          await packer.packToFile(imgSource, destFile.fd, { format: 'image/jpeg', quality: 90 });
          packer.release();
          imgSource.release();
          fileIo.closeSync(destFile.fd);
          fileIo.closeSync(srcFile.fd);
        }
        // 保存到 Preferences
        let pref = preferences.getPreferencesSync(context, { name: 'popup_settings' });
        pref.putSync('popupBgImage', destPath);
        pref.flush();
        this.popupBgImage = destPath;
        this.popupBgMessage = '弹窗背景已设置';
        setTimeout(() => {
          this.popupBgMessage = '';
        }, 3000);
      }
    } catch (err) {
      let error = err as BusinessError;
      console.error(`[Settings] 选择图片失败: ${error.message}`);
      this.popupBgMessage = '选择失败，请重试';
      setTimeout(() => {
        this.popupBgMessage = '';
      }, 3000);
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
      console.error(`[Settings] 预览弹窗失败: ${error.message}`);
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
      console.error(`[Settings] 打开卡片管理器失败: ${error.message}`);
    }
  }

  /**
   * 重置弹窗背景为默认
   */
  private resetPopupBackground(): void {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      // 删除沙箱中的图片文件（JPEG 或 GIF）
      let jpgPath = context.filesDir + '/popup_bg.jpg';
      let gifPath = context.filesDir + '/popup_bg.gif';
      if (fileIo.accessSync(jpgPath)) {
        fileIo.unlinkSync(jpgPath);
      }
      if (fileIo.accessSync(gifPath)) {
        fileIo.unlinkSync(gifPath);
      }
      let pref = preferences.getPreferencesSync(context, { name: 'popup_settings' });
      pref.deleteSync('popupBgImage');
      pref.flush();
      this.popupBgImage = '';
      this.popupBgMessage = '已恢复默认背景';
      setTimeout(() => {
        this.popupBgMessage = '';
      }, 3000);
    } catch (e) {
      console.warn('[Settings] 重置弹窗背景失败');
    }
  }

  build() {
    Scroll() {
      Column() {
        // 标题
        Text('设置')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(textPrimary(this.isDarkMode))
          .margin({ top: 20 })

        // ====== 通知管理 ======
        Column() {
          Row() {
            Text('🔔')
              .fontSize(18)
            Text(' 通知管理')
              .fontSize(14)
              .fontColor(textSecondary(this.isDarkMode))
              .margin({ left: 6 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 8 })

          Row() {
            Text('常驻通知显示电量')
              .fontSize(14)
              .fontColor(textPrimary(this.isDarkMode))
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
            .fontColor(descTextColor(this.isDarkMode))
            .width('85%')
            .margin({ bottom: 12 })
        }
        .width('85%')
        .borderRadius(16)
        .backgroundColor(cardBg(this.isDarkMode))
        .border({ width: 1, color: borderColor(this.isDarkMode) })
        .margin({ top: 24 })
        .alignItems(HorizontalAlign.Center)

        // ====== 弹窗背景设置 ======
        Column() {
          Row() {
            Text('🖼️')
              .fontSize(18)
            Text(' 弹窗背景')
              .fontSize(14)
              .fontColor(textSecondary(this.isDarkMode))
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
                .fontColor(textPrimary(this.isDarkMode))
            }
          }
          .width('85%')
          .height(44)
          .backgroundColor(btnInactiveBg(this.isDarkMode))
          .borderRadius(22)
          .border({ width: 1, color: borderColor(this.isDarkMode) })
          .onClick(() => {
            this.selectPopupBackground();
          })

          Button('预览弹窗')
            .fontSize(14)
            .fontColor(textPrimary(this.isDarkMode))
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
              .fontColor(textTertiary(this.isDarkMode))
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
              .fontColor(accentGreen)
              .margin({ top: 6 })
          }
        }
        .width('85%')
        .borderRadius(16)
        .backgroundColor(cardBg(this.isDarkMode))
        .border({ width: 1, color: borderColor(this.isDarkMode) })
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
              .fontColor(textSecondary(this.isDarkMode))
              .margin({ left: 6 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 8 })

          Text('查看各功能的使用说明和常见问题')
            .fontSize(12)
            .fontColor(descTextColor(this.isDarkMode))
            .width('85%')
            .margin({ bottom: 12 })

          Button('打开使用帮助')
            .fontSize(14)
            .fontColor(textPrimary(this.isDarkMode))
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
        .backgroundColor(cardBg(this.isDarkMode))
        .border({ width: 1, color: borderColor(this.isDarkMode) })
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
              .fontColor(textSecondary(this.isDarkMode))
              .margin({ left: 6 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 8 })

          Text('将电量卡片添加到桌面或负一屏，随时查看耳机电量，数据刷新会有延迟')
            .fontSize(12)
            .fontColor(descTextColor(this.isDarkMode))
            .width('85%')
            .margin({ bottom: 12 })

          Button('添加桌面卡片')
            .fontSize(14)
            .fontColor(textPrimary(this.isDarkMode))
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
        .backgroundColor(cardBg(this.isDarkMode))
        .border({ width: 1, color: borderColor(this.isDarkMode) })
        .margin({ top: 20 })
        .alignItems(HorizontalAlign.Center)
        .padding({ bottom: 16 })

        // ====== HEX 原始数据 ======
        Column() {
          // 标题行，可点击展开/收起
          Row() {
            Text('HEX 原始数据')
              .fontSize(14)
              .fontColor(textSecondary(this.isDarkMode))
              .fontWeight(FontWeight.Medium)

            Blank()

            Text(this.showRawHex ? '收起 ▲' : '展开 ▼')
              .fontSize(12)
              .fontColor('#6666AA')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .onClick(() => {
            this.showRawHex = !this.showRawHex;
          })

          if (this.showRawHex) {
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
        .backgroundColor(cardBg(this.isDarkMode))
        .border({ width: 1, color: borderColor(this.isDarkMode) })
        .margin({ top: 20 })
        .clip(true)

        // ====== 高级设置：设备能力覆写 ======
        Column() {
          Row() {
            Text('🔧')
              .fontSize(18)
            Text(' 高级设置')
              .fontSize(14)
              .fontColor(textSecondary(this.isDarkMode))
              .margin({ left: 6 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 4 })

          Text('设备能力覆写（支持非标准/未知型号时手动调整）')
            .fontSize(11)
            .fontColor(tipTextColor(this.isDarkMode))
            .width('85%')
            .margin({ bottom: 8 })

          // 空间音效协议覆写
          Row() {
            Text('空间音效协议')
              .fontSize(13)
              .fontColor(textSecondary(this.isDarkMode))
              .layoutWeight(1)
            Text(this.getOverrideLabel(this.spatialSoundOverride))
              .fontSize(12)
              .fontColor(textTertiary(this.isDarkMode))
              .onClick(() => {
                this.spatialSoundOverride = this.cycleOverride(this.spatialSoundOverride);
                this.applyOverrides();
              })
          }
          .width('85%')
          .height(36)

          // 旧版 ANC 指令覆写
          Row() {
            Text('旧版 ANC 兼容')
              .fontSize(13)
              .fontColor(textSecondary(this.isDarkMode))
              .layoutWeight(1)
            Text(this.getOverrideLabel(this.legacyAncOverride))
              .fontSize(12)
              .fontColor(textTertiary(this.isDarkMode))
              .onClick(() => {
                this.legacyAncOverride = this.cycleOverride(this.legacyAncOverride);
                this.applyOverrides();
              })
          }
          .width('85%')
          .height(36)
          .margin({ bottom: 12 })

          if (this.capabilityMessage) {
            Text(this.capabilityMessage)
              .fontSize(11)
              .fontColor(accentGreen)
              .width('85%')
              .margin({ bottom: 8 })
          }
        }
        .width('85%')
        .borderRadius(16)
        .backgroundColor(cardBg(this.isDarkMode))
        .border({ width: 1, color: borderColor(this.isDarkMode) })
        .margin({ top: 20 })
      }
      .width('100%')
      .padding({ top: this.statusBarHeight, bottom: 100 })
      .alignItems(HorizontalAlign.Center)
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  /** 三态覆写循环 */
  private cycleOverride(current: number): number {
    if (current === CAP_OVERRIDE_AUTO) return CAP_OVERRIDE_FORCE_ENABLED;
    if (current === CAP_OVERRIDE_FORCE_ENABLED) return CAP_OVERRIDE_FORCE_DISABLED;
    return CAP_OVERRIDE_AUTO;
  }

  /** 三态覆写标签 */
  private getOverrideLabel(value: number): string {
    if (value === CAP_OVERRIDE_AUTO) return '自动';
    if (value === CAP_OVERRIDE_FORCE_ENABLED) return '强制开启';
    return '强制关闭';
  }

  /** 加载能力覆写持久化值 */
  private loadOverrideSettings(): void {
    try {
      let context = getContext(this) as common.UIAbilityContext;
      let pref = preferences.getPreferencesSync(context, { name: 'capability_overrides' });
      this.spatialSoundOverride = pref.getSync('spatialSoundSwitch', CAP_OVERRIDE_AUTO) as number;
      this.legacyAncOverride = pref.getSync('ancLegacy', CAP_OVERRIDE_AUTO) as number;
    } catch (e) {
      console.warn('[Settings] 加载能力覆写失败');
    }
  }

  /** 应用覆写到 Manager，已连接时自动重连生效 */
  private applyOverrides(): void {
    let overrides = new CapabilityOverrides();
    overrides.spatialSoundSwitch = this.spatialSoundOverride;
    overrides.ancLegacy = this.legacyAncOverride;
    this.manager.applyCapabilityOverrides(overrides);
    // 已连接时自动断开重连，使新能力立即生效
    if (this.manager.getIsConnected()) {
      this.capabilityMessage = '能力覆写已保存，正在重连应用...';
      this.manager.disconnect();
      setTimeout(() => {
        this.capabilityMessage = '';
        this.manager.startAutoConnect();
      }, 800);
    } else {
      this.capabilityMessage = '能力覆写已保存';
      setTimeout(() => { this.capabilityMessage = ''; }, 2500);
    }
  }
}
