import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo } from '@kit.CoreFileKit';

const PREF_NAME = 'battery_widget_data';
const FORM_IDS_FILE = 'form_ids.json';

/**
 * 卡片电量数据结构
 */
class BatteryWidgetData {
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
 * 桌面电量卡片 FormExtensionAbility
 * 负责卡片生命周期管理和数据推送
 */
export default class BatteryFormAbility extends FormExtensionAbility {

  /**
   * 卡片首次添加到桌面时调用
   * 同步返回初始数据
   */
  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(0x0000, 'BatteryForm', 'onAddForm');
    let formId = want.parameters?.['ohos.extra.param.key.form_identity'] as string ?? '';
    hilog.info(0x0000, 'BatteryForm', 'formId: %{public}s', formId);

    // 保存 formId 到 Preferences
    this.saveFormId(formId);

    // 从 Preferences 读取缓存的电量数据
    let batteryData = this.readBatteryData();
    return formBindingData.createFormBindingData(batteryData);
  }

  /**
   * 卡片定时刷新或主动刷新时调用
   */
  onUpdateForm(formId: string): void {
    hilog.info(0x0000, 'BatteryForm', 'onUpdateForm, formId: %{public}s', formId);

    let batteryData = this.readBatteryData();
    let bindingData = formBindingData.createFormBindingData(batteryData);
    formProvider.updateForm(formId, bindingData).catch((err: Error) => {
      hilog.error(0x0000, 'BatteryForm', 'updateForm failed: %{public}s', err.message);
    });
  }

  /**
   * 卡片被移除时调用
   */
  onRemoveForm(formId: string): void {
    hilog.info(0x0000, 'BatteryForm', 'onRemoveForm: %{public}s', formId);
    // 从 Preferences 删除 formId
    this.removeFormId(formId);
  }

  /**
   * 从 Preferences 同步读取电量数据
   */
  private readBatteryData(): BatteryWidgetData {
    try {
      let pref = preferences.getPreferencesSync(this.context, { name: PREF_NAME });
      let leftBattery: number = pref.getSync('leftBattery', -1) as number;
      let leftCharging: boolean = pref.getSync('leftCharging', false) as boolean;
      let rightBattery: number = pref.getSync('rightBattery', -1) as number;
      let rightCharging: boolean = pref.getSync('rightCharging', false) as boolean;
      let caseBattery: number = pref.getSync('caseBattery', -1) as number;
      let caseCharging: boolean = pref.getSync('caseCharging', false) as boolean;
      let lastUpdated: string = pref.getSync('lastUpdated', '--:--') as string;
      let connected: boolean = pref.getSync('connected', false) as boolean;

      hilog.info(0x0000, 'BatteryForm',
        '读取电量: L=%{public}d R=%{public}d C=%{public}d connected=%{public}s',
        leftBattery, rightBattery, caseBattery, String(connected));

      let data = new BatteryWidgetData();
      data.leftBattery = leftBattery;
      data.leftCharging = leftCharging;
      data.rightBattery = rightBattery;
      data.rightCharging = rightCharging;
      data.caseBattery = caseBattery;
      data.caseCharging = caseCharging;
      data.lastUpdated = lastUpdated;
      data.connected = connected;
      return data;
    } catch (err) {
      hilog.error(0x0000, 'BatteryForm', '读取电量数据失败: %{public}s', JSON.stringify(err));
      let fallback = new BatteryWidgetData();
      return fallback;
    }
  }

  /**
   * 获取 formIds 文件路径
   */
  private getFormIdsFilePath(): string {
    return `${this.context.filesDir}/${FORM_IDS_FILE}`;
  }

  /**
   * 读取已保存的 formId 列表
   */
  private readFormIds(): string[] {
    try {
      let filePath = this.getFormIdsFilePath();
      if (fileIo.accessSync(filePath)) {
        let content: string = fileIo.readTextSync(filePath);
        if (content && content.length > 0) {
          let parsed: string[] = JSON.parse(content) as string[];
          return parsed;
        }
      }
    } catch (err) {
      hilog.error(0x0000, 'BatteryForm', '读取formIds文件失败: %{public}s', JSON.stringify(err));
    }
    return [];
  }

  /**
   * 写入 formId 列表到文件
   */
  private writeFormIds(idList: string[]): void {
    try {
      let filePath = this.getFormIdsFilePath();
      let file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, JSON.stringify(idList));
      fileIo.closeSync(file.fd);
      hilog.info(0x0000, 'BatteryForm', 'formIds已写入文件: %{public}s, 数量: %{public}d', JSON.stringify(idList), idList.length);
    } catch (err) {
      hilog.error(0x0000, 'BatteryForm', '写入formIds文件失败: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 保存卡片ID到文件
   */
  private saveFormId(formId: string): void {
    if (!formId) return;
    let idList = this.readFormIds();
    if (!idList.includes(formId)) {
      idList.push(formId);
      this.writeFormIds(idList);
    }
  }

  /**
   * 从文件删除卡片ID
   */
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
