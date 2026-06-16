import { WorkSchedulerExtensionAbility, workScheduler } from '@kit.BackgroundTasksKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { OppoEarphoneManager } from '../manager/OppoEarphoneManager';

/**
 * 延迟任务回调扩展能力
 * 系统定时唤醒应用时调用，用于后台获取耳机电量并刷新桌面卡片
 */
export default class WorkSchedulerExtension extends WorkSchedulerExtensionAbility {

  /**
   * 延迟任务开始回调
   * 在后台被系统唤醒，执行耳机电量查询和卡片刷新
   */
  onWorkStart(workInfo: workScheduler.WorkInfo): void {
    hilog.info(0x0000, 'WorkScheduler', 'onWorkStart - 后台电量刷新任务开始');

    // 如果主应用在前台运行，跳过后台刷新避免冲突
    if (OppoEarphoneManager.isAppForeground) {
      hilog.info(0x0000, 'WorkScheduler', '应用在前台，跳过后台刷新');
      return;
    }

    let manager = OppoEarphoneManager.getInstance();
    manager.setContext(this.context.getApplicationContext());
    manager.refreshWidgetInBackground();
  }

  /**
   * 延迟任务结束回调
   */
  onWorkStop(workInfo: workScheduler.WorkInfo): void {
    hilog.info(0x0000, 'WorkScheduler', 'onWorkStop - 后台电量刷新任务结束');
  }
}
