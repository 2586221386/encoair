import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo } from '@kit.CoreFileKit';
import { connection } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';

const PREF_NAME = 'battery_widget_data';
const FORM_IDS_FILE = 'form_ids_1x2.json';

/**
 * 1×2 卡片数据模型
 */
class WidgetData1x2 {
  batteryLevel: number = -1;
  isConnected: boolean = false;
  lastUpdated: string = '--:--';
}

/**
 * 1×2 电量卡片 FormExtensionAbility
 * 通过系统 HFP 蓝牙 API 获取通用电量，无需唤醒主应用
 */
export default class BatteryFormAbility1x2 extends FormExtensionAbility {

  /**
   * 卡片首次添加到桌面
   */
  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(0x0000, 'BattForm1x2', 'onAddForm');
    let formId = want.parameters?.['ohos.extra.param.key.form_identity'] as string ?? '';
    this.saveFormId(formId);

    // 异步获取系统电量并刷新卡片
    this.fetchAndUpdate(formId);

    // 同步返回缓存数据（不含 -1）
    let cached = this.readCachedData();
    return formBindingData.createFormBindingData(cached);
  }

  /**
   * 定时更新或主动刷新
   */
  onUpdateForm(formId: string): void {
    hilog.info(0x0000, 'BattForm1x2', 'onUpdateForm: %{public}s', formId);
    this.fetchAndUpdate(formId);
  }

  /**
   * 卡片移除
   */
  onRemoveForm(formId: string): void {
    hilog.info(0x0000, 'BattForm1x2', 'onRemoveForm: %{public}s', formId);
    this.removeFormId(formId);
  }

  /**
   * 通过系统蓝牙 API 获取电量并刷新卡片
   */
  private async fetchAndUpdate(formId: string): Promise<void> {
    try {
      let pref = preferences.getPreferencesSync(this.context, { name: PREF_NAME });
      let mac: string = pref.getSync('savedMac', '') as string;
      if (!mac) {
        hilog.warn(0x0000, 'BattForm1x2', '无已保存MAC，跳过获取');
        return;
      }

      let info = await connection.getRemoteDeviceBatteryInfo(mac);
      let batteryLevel = info.batteryLevel;
      let connected = batteryLevel >= 0;

      hilog.info(0x0000, 'BattForm1x2',
        '系统电量: batteryLevel=%{public}d, L=%{public}d, R=%{public}d, Box=%{public}d',
        batteryLevel, info.leftEarBatteryLevel, info.rightEarBatteryLevel, info.boxBatteryLevel);

      let now = new Date();
      let timeStr = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;

      let data = new WidgetData1x2();
      data.batteryLevel = batteryLevel;
      data.isConnected = connected;
      data.lastUpdated = timeStr;

      // 缓存到 Preferences 供其他进程读取
      pref.putSync('batteryLevel_1x2', batteryLevel);
      pref.putSync('isConnected_1x2', connected);
      pref.putSync('lastUpdated_1x2', timeStr);
      await pref.flush();

      // 刷新卡片 UI
      let bindingData = formBindingData.createFormBindingData(data);
      await formProvider.updateForm(formId, bindingData);
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(0x0000, 'BattForm1x2',
        '获取系统电量失败: code=%{public}d, msg=%{public}s',
        Number(error.code), error.message);
    }
  }

  /**
   * 读取缓存的电量数据（同步返回，避免返回全 -1）
   */
  private readCachedData(): WidgetData1x2 {
    try {
      let pref = preferences.getPreferencesSync(this.context, { name: PREF_NAME });
      let data = new WidgetData1x2();
      data.batteryLevel = pref.getSync('batteryLevel_1x2', -1) as number;
      data.isConnected = pref.getSync('isConnected_1x2', false) as boolean;
      data.lastUpdated = pref.getSync('lastUpdated_1x2', '--:--') as string;
      return data;
    } catch (err) {
      return new WidgetData1x2();
    }
  }

  // ============== formId 持久化（文件共享） ==============

  private getFormIdsFilePath(): string {
    return `${this.context.filesDir}/${FORM_IDS_FILE}`;
  }

  private readFormIds(): string[] {
    try {
      let filePath = this.getFormIdsFilePath();
      if (fileIo.accessSync(filePath)) {
        let content: string = fileIo.readTextSync(filePath);
        if (content && content.length > 0) {
          return JSON.parse(content) as string[];
        }
      }
    } catch (err) {
      hilog.error(0x0000, 'BattForm1x2', '读取formIds失败');
    }
    return [];
  }

  private writeFormIds(idList: string[]): void {
    try {
      let filePath = this.getFormIdsFilePath();
      let file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, JSON.stringify(idList));
      fileIo.closeSync(file.fd);
    } catch (err) {
      hilog.error(0x0000, 'BattForm1x2', '写入formIds失败');
    }
  }

  private saveFormId(formId: string): void {
    if (!formId) return;
    let idList = this.readFormIds();
    if (!idList.includes(formId)) {
      idList.push(formId);
      this.writeFormIds(idList);
    }
  }

  private removeFormId(formId: string): void {
    if (!formId) return;
    let idList = this.readFormIds();
    let index = idList.indexOf(formId);
    if (index > -1) {
      idList.splice(index, 1);
      this.writeFormIds(idList);
    }
  }
}
