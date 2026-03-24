// 智慧农业 - 联动规则页面
import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors, MetricNames, DeviceTypes } from '../common/Constants';
import { AutomationRule, DeviceInfo, AutomationCreateRequest, AutomationUpdateRequest } from '../model/DataModels';

@Entry
@Component
struct AutomationPage {
  @State rules: AutomationRule[] = [];
  @State devices: DeviceInfo[] = [];
  @State loading: boolean = true;
  @State showAdd: boolean = false;
  // 新增规则表单
  @State newMetric: string = 'soil_moisture';
  @State newCondition: string = 'lt';
  @State newValue: number = 30;
  @State newDeviceId: number = 2;
  @State newAction: string = 'on';

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.loading = true;
    try {
      this.rules = await ApiService.get<AutomationRule[]>(ApiConstants.AUTOMATION_LIST);
      this.devices = await ApiService.get<DeviceInfo[]>(ApiConstants.DEVICE_LIST);
    } catch (e) {
      const ap1: Record<string, number> = {};
      const ap2: Record<string, number> = { 'brightness': 80 };
      const r1: AutomationRule = { id: 1, trigger_metric: 'soil_moisture', trigger_condition: 'lt', trigger_value: 30,
        action_device_id: 2, action_type: 'on', action_params: ap1, is_enabled: 1,
        created_at: '', updated_at: '' };
      const r2: AutomationRule = { id: 2, trigger_metric: 'light_intensity', trigger_condition: 'lt', trigger_value: 5000,
        action_device_id: 3, action_type: 'on', action_params: ap2, is_enabled: 1,
        created_at: '', updated_at: '' };
      this.rules = [r1, r2];
    } finally {
      this.loading = false;
    }
  }

  async toggleRule(rule: AutomationRule): Promise<void> {
    const newEnabled = rule.is_enabled === 1 ? 0 : 1;
    try {
      const body: AutomationUpdateRequest = { is_enabled: newEnabled };
      await ApiService.put<object>(`${ApiConstants.AUTOMATION_LIST.replace('/list', '')}/${rule.id}`, body);
    } catch (e) { /* offline */ }
    const idx = this.rules.findIndex((r: AutomationRule) => r.id === rule.id);
    if (idx >= 0) {
      const old: AutomationRule = this.rules[idx];
      const updated: AutomationRule = {
        id: old.id, trigger_metric: old.trigger_metric, trigger_condition: old.trigger_condition,
        trigger_value: old.trigger_value, action_device_id: old.action_device_id,
        action_type: old.action_type, action_params: old.action_params,
        is_enabled: newEnabled, created_at: old.created_at, updated_at: old.updated_at
      };
      this.rules[idx] = updated;
    }
  }

  async addRule(): Promise<void> {
    try {
      const ap: Record<string, number> = {};
      const body: AutomationCreateRequest = {
        trigger_metric: this.newMetric,
        trigger_condition: this.newCondition,
        trigger_value: this.newValue,
        action_device_id: this.newDeviceId,
        action_type: this.newAction,
        action_params: ap,
        is_enabled: 1
      };
      await ApiService.post<object>(ApiConstants.AUTOMATION_LIST.replace('/list', ''), body);
      this.showAdd = false;
      this.loadData();
    } catch (e) { /* offline */ }
  }

  getConditionText(cond: string): string {
    const map: Record<string, string> = { 'lt': '<', 'gt': '>', 'eq': '=' };
    return map[cond] || cond;
  }

  getDeviceName(id: number): string {
    const d = this.devices.find((dev: DeviceInfo) => dev.id === id);
    return d ? d.device_name : `设备${id}`;
  }

  build() {
    Column() {
      Row() {
        Text('< 返回').fontSize(15).fontColor(AppColors.PRIMARY)
          .onClick(() => { router.back(); })
        Text('联动规则').fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY).margin({ left: 12 })
        Blank()
        Text('+ 新增').fontSize(14).fontColor(AppColors.PRIMARY)
          .onClick(() => { this.showAdd = !this.showAdd; })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      // 新增规则面板
      if (this.showAdd) {
        Column() {
          Text('新增联动规则').fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY).width('100%').margin({ bottom: 10 })
          Row() {
            Text('当').fontSize(13).margin({ right: 6 })
            Select([
              { value: 'temperature' }, { value: 'humidity' },
              { value: 'soil_moisture' }, { value: 'light_intensity' }, { value: 'co2_level' }
            ])
              .selected(2)
              .value(MetricNames.MAP[this.newMetric] || this.newMetric)
              .font({ size: 13 })
              .onSelect((idx: number, val: string) => { this.newMetric = val; })
          }.width('100%')
          Row() {
            Select([{ value: 'lt' }, { value: 'gt' }, { value: 'eq' }])
              .selected(0).value(this.getConditionText(this.newCondition))
              .font({ size: 13 })
              .onSelect((idx: number, val: string) => { this.newCondition = val; })
            TextInput({ text: this.newValue.toString() })
              .type(InputType.Number).width(80).height(36).fontSize(13)
              .margin({ left: 8 })
              .onChange((v: string) => { this.newValue = parseFloat(v) || 0; })
          }.width('100%').margin({ top: 8 })
          Row() {
            Text('则').fontSize(13).margin({ right: 6 })
            Select([{ value: 'on' }, { value: 'off' }])
              .selected(0).value(this.newAction === 'on' ? '开启' : '关闭')
              .font({ size: 13 })
              .onSelect((idx: number, val: string) => { this.newAction = val; })
            Text('设备ID:').fontSize(13).margin({ left: 8 })
            TextInput({ text: this.newDeviceId.toString() })
              .type(InputType.Number).width(50).height(36).fontSize(13)
              .margin({ left: 4 })
              .onChange((v: string) => { this.newDeviceId = parseInt(v) || 1; })
          }.width('100%').margin({ top: 8 })
          Button('添加规则')
            .width('100%').height(36).borderRadius(18)
            .backgroundColor(AppColors.PRIMARY).fontColor('#FFFFFF').fontSize(14)
            .margin({ top: 12 })
            .onClick(() => { this.addRule(); })
        }
        .width('100%').padding(14).margin({ left: 12, right: 12, bottom: 8 })
        .backgroundColor('#E8F5E9').borderRadius(12)
      }

      // 规则列表
      List({ space: 8 }) {
        ForEach(this.rules, (rule: AutomationRule) => {
          ListItem() {
            Row() {
              Column() {
                Text(`${MetricNames.MAP[rule.trigger_metric] || rule.trigger_metric} ${this.getConditionText(rule.trigger_condition)} ${rule.trigger_value}`)
                  .fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppColors.TEXT_PRIMARY)
                Text(`→ ${this.getDeviceName(rule.action_device_id)} ${rule.action_type === 'on' ? '开启' : '关闭'}`)
                  .fontSize(12).fontColor(AppColors.TEXT_SECONDARY).margin({ top: 4 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: rule.is_enabled === 1 })
                .selectedColor(AppColors.PRIMARY)
                .onChange(() => { this.toggleRule(rule); })
            }
            .width('100%').padding(14)
            .backgroundColor(AppColors.CARD_BG).borderRadius(12)
            .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
          }
        })
      }
      .width('100%').layoutWeight(1).padding({ left: 12, right: 12 })
    }
    .width('100%').height('100%').backgroundColor(AppColors.BG)
  }
}
