import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { workScheduler } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { OppoEarphoneManager } from '../manager/OppoEarphoneManager';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private privateLaunchWant: Want | null = null;
  
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    hilog.info(DOMAIN, 'testTag', 'Want参数: %{public}s', JSON.stringify(want));
    
    // 保存want参数,供onWindowStageCreate使用
    this.privateLaunchWant = want;
    
    // 调度桌面卡片后台刷新任务
    this.scheduleWidgetBackgroundWork();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 判断启动来源:如果是被外部应用(如"智慧生活")唤醒,显示弹窗;否则显示主界面
    let isExternalWake = this.checkIfExternalWake();
    
    if (isExternalWake) {
      hilog.info(DOMAIN, 'testTag', '检测到外部唤醒,加载弹窗页面');
      // 加载弹窗页面
      windowStage.loadContent('pages/PopupWindow', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load popup content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading popup content.');
        
        // 设置窗口为弹窗样式
        this.setupPopupWindow(windowStage);
      });
    } else {
      hilog.info(DOMAIN, 'testTag', '用户手动启动,加载主界面');
      // 加载主界面
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');

        // 设置主窗口全屏沉浸式，背景延伸到状态栏和导航栏
        this.setupMainWindowFullScreen(windowStage);
      });
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    OppoEarphoneManager.isAppForeground = true;
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    OppoEarphoneManager.isAppForeground = false;
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', 'onNewWant: %{public}s', JSON.stringify(want));
    // 更新want并重新判断是否显示弹窗
    this.privateLaunchWant = want;
  }

  /**
   * 检查是否为外部应用唤醒
   */
  private checkIfExternalWake(): boolean {
    if (!this.privateLaunchWant) {
      return false;
    }
    
    let want = this.privateLaunchWant;
    let action = want.action;
    let uri = want.uri;
    
    hilog.info(DOMAIN, 'testTag', '检查唤醒来源 - action: %{public}s, uri: %{public}s', 
      action ? action : 'null', uri ? uri : 'null');
    
    // 方式1: 通过自定义action触发
    if (action === 'action.oppopods.SHOW_POPUP') {
      return true;
    }
    
    // 方式2: 通过URI触发 (oppopods://popup)
    if (uri && uri.startsWith('oppopods://popup')) {
      return true;
    }
    
    // 方式3: 通过parameters中的标志触发
    if (want.parameters) {
      let params = want.parameters as Record<string, Object>;
      if (params['show_popup'] === true || params['action'] === 'show_popup') {
        return true;
      }
      // 方式3b: postCardAction 'router' 动作将params嵌套在formRouterParams中
      let formRouterParams = params['formRouterParams'] as Record<string, Object> | undefined;
      if (formRouterParams && formRouterParams['show_popup'] === true) {
        return true;
      }
    }
    
    // 方式4: 检查callerBundleName,如果是系统应用或其他应用启动的,视为外部唤醒
    if (want.parameters) {
      let params = want.parameters as Record<string, Object>;
      let callerBundleName = params['ohos.aafwk.param.callerBundleName'] as string;
      
      if (callerBundleName && callerBundleName !== 'com.hzx.encoair') {
        hilog.info(DOMAIN, 'testTag', '检测到外部应用唤醒: %{public}s', callerBundleName);
        return true;
      }
    }
    
    return false;
  }

  /**
   * 设置主窗口全屏沉浸式
   * 背景延伸到状态栏和导航栏区域，状态栏/导航栏透明
   */
  private setupMainWindowFullScreen(windowStage: window.WindowStage): void {
    try {
      let windowClass = windowStage.getMainWindowSync();
      // 全屏布局，内容延伸到状态栏和导航栏
      windowClass.setWindowLayoutFullScreen(true);
      // 状态栏和导航栏透明
      let sysBarProps: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: '#FFFFFF',
        navigationBarContentColor: '#FFFFFF'
      };
      windowClass.setWindowSystemBarProperties(sysBarProps);
      // 获取状态栏高度，存入AppStorage供UI使用
      let avoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      let topHeight = px2vp(avoidArea.topRect.height);
      AppStorage.setOrCreate<number>('statusBarHeight', topHeight);
      hilog.info(DOMAIN, 'testTag', '主窗口全屏沉浸式设置成功, 状态栏高度: %{public}s', String(topHeight));
    } catch (error) {
      hilog.error(DOMAIN, 'testTag', '主窗口全屏设置失败: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 设置弹窗窗口样式
   */
  private setupPopupWindow(windowStage: window.WindowStage): void {
    try {
      let windowClass = windowStage.getMainWindowSync();
      
      // 设置透明背景
      windowClass.setWindowBackgroundColor('#00000000');
      
      // 设置窗口布局为全屏,但内容只在底部
      windowClass.setWindowLayoutFullScreen(true);
      
      hilog.info(DOMAIN, 'testTag', '弹窗窗口样式设置成功');
    } catch (error) {
      hilog.error(DOMAIN, 'testTag', '设置弹窗窗口样式失败: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 调度桌面卡片后台刷新延迟任务
   * 系统每20分钟唤醒应用，连接耳机获取电量并刷新桌面卡片
   */
  private scheduleWidgetBackgroundWork(): void {
    let workInfo: workScheduler.WorkInfo = {
      workId: 1001,
      bundleName: 'com.hzx.encoair',
      abilityName: 'WorkSchedulerExtension',
      isRepeat: true,
      repeatCycleTime: 1200000,
      isPersisted: true
    };

    try {
      workScheduler.startWork(workInfo);
      hilog.info(DOMAIN, 'testTag', '桌面卡片后台刷新任务已调度（每20分钟）');
    } catch (error) {
      let err = error as BusinessError;
      hilog.error(DOMAIN, 'testTag', '调度后台任务失败: code=%{public}s, msg=%{public}s',
        String(err.code), err.message);
    }
  }
}