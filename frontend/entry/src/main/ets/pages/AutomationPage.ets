import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors, MetricNames } from '../common/Constants';
import { AutomationRule, DeviceInfo, AutomationCreateRequest, AutomationUpdateRequest } from '../model/DataModels';

@Entry
@Component
struct AutomationPage {
  @State rules: AutomationRule[] = [];
  @State devices: DeviceInfo[] = [];
  @State showAdd: boolean = false;

  @State newMetric: string = 'soil_moisture';
  @State newCondition: string = 'lt';
  @State newValue: number = 30;
  @State newDeviceId: number = 2;
  @State newAction: string = 'on';

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      this.rules = await ApiService.get<AutomationRule[]>(ApiConstants.AUTOMATION_LIST);
      this.devices = await ApiService.get<DeviceInfo[]>(ApiConstants.DEVICE_LIST);
    } catch (_e) {
      const p1: Record<string, number> = {};
      const p2: Record<string, number> = {};
      p2['brightness'] = 80;

      const r1: AutomationRule = {
        id: 1,
        trigger_metric: 'soil_moisture',
        trigger_condition: 'lt',
        trigger_value: 30,
        action_device_id: 2,
        action_type: 'on',
        action_params: p1,
        is_enabled: 1,
        created_at: '',
        updated_at: '',
      };
      const r2: AutomationRule = {
        id: 2,
        trigger_metric: 'light_intensity',
        trigger_condition: 'lt',
        trigger_value: 5000,
        action_device_id: 3,
        action_type: 'on',
        action_params: p2,
        is_enabled: 1,
        created_at: '',
        updated_at: '',
      };
      this.rules = [r1, r2];
    }
  }

  async toggleRule(rule: AutomationRule): Promise<void> {
    const nextEnabled: number = rule.is_enabled === 1 ? 0 : 1;
    try {
      const body: AutomationUpdateRequest = { is_enabled: nextEnabled };
      await ApiService.put<object>(`${ApiConstants.AUTOMATION_LIST}/${rule.id}`, body);
    } catch (_e) {
      // Ignore offline errors.
    }

    const index: number = this.rules.findIndex((item: AutomationRule): boolean => item.id === rule.id);
    if (index >= 0) {
      const old: AutomationRule = this.rules[index];
      this.rules[index] = {
        id: old.id,
        trigger_metric: old.trigger_metric,
        trigger_condition: old.trigger_condition,
        trigger_value: old.trigger_value,
        action_device_id: old.action_device_id,
        action_type: old.action_type,
        action_params: old.action_params,
        is_enabled: nextEnabled,
        created_at: old.created_at,
        updated_at: old.updated_at,
      };
      this.rules = this.rules.slice();
    }
  }

  async addRule(): Promise<void> {
    try {
      const params: Record<string, number> = {};
      const body: AutomationCreateRequest = {
        trigger_metric: this.newMetric,
        trigger_condition: this.newCondition,
        trigger_value: this.newValue,
        action_device_id: this.newDeviceId,
        action_type: this.newAction,
        action_params: params,
        is_enabled: 1,
      };
      await ApiService.post<object>(ApiConstants.AUTOMATION_LIST, body);
      this.showAdd = false;
      this.loadData();
    } catch (_e) {
      // Ignore offline errors.
    }
  }

  conditionText(condition: string): string {
    if (condition === 'lt') return '<';
    if (condition === 'gt') return '>';
    if (condition === 'eq') return '=';
    return condition;
  }

  actionText(action: string): string {
    return action === 'on' ? '开启' : '关闭';
  }

  deviceName(id: number): string {
    const device: DeviceInfo | undefined = this.devices.find((item: DeviceInfo): boolean => item.id === id);
    return device ? device.device_name : `设备${id}`;
  }

  build(): void {
    Column() {
      Row() {
        Text('< 返回')
          .fontSize(15)
          .fontColor(AppColors.PRIMARY)
          .onClick((): void => {
            router.back();
          });

        Text('联动规则')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .margin({ left: 12 });

        Blank();

        Text(this.showAdd ? '取消' : '+ 新增')
          .fontSize(14)
          .fontColor(AppColors.PRIMARY)
          .onClick((): void => {
            this.showAdd = !this.showAdd;
          });
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 10 });

      if (this.showAdd) {
        Column() {
          Text('新增联动规则')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .width('100%');

          Row() {
            Text('当')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ right: 8 });
            Select([
              { value: 'temperature' },
              { value: 'humidity' },
              { value: 'soil_moisture' },
              { value: 'light_intensity' },
              { value: 'co2_level' },
            ])
              .selected(2)
              .value(MetricNames.MAP[this.newMetric] || this.newMetric)
              .font({ size: 13 })
              .onSelect((_i: number, val: string): void => {
                this.newMetric = val;
              });
          }
          .width('100%')
          .margin({ top: 10 });

          Row() {
            Select([{ value: 'lt' }, { value: 'gt' }, { value: 'eq' }])
              .selected(0)
              .value(this.conditionText(this.newCondition))
              .font({ size: 13 })
              .onSelect((_i: number, val: string): void => {
                this.newCondition = val;
              });

            TextInput({ text: this.newValue.toString() })
              .type(InputType.Number)
              .width(90)
              .height(36)
              .fontSize(13)
              .margin({ left: 8 })
              .onChange((value: string): void => {
                this.newValue = parseFloat(value) || 0;
              });
          }
          .width('100%')
          .margin({ top: 8 });

          Row() {
            Text('则')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ right: 8 });

            Select([{ value: 'on' }, { value: 'off' }])
              .selected(0)
              .value(this.actionText(this.newAction))
              .font({ size: 13 })
              .onSelect((_i: number, val: string): void => {
                this.newAction = val;
              });

            Text('设备编号')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ left: 10, right: 6 });

            TextInput({ text: this.newDeviceId.toString() })
              .type(InputType.Number)
              .width(60)
              .height(36)
              .fontSize(13)
              .onChange((value: string): void => {
                this.newDeviceId = parseInt(value) || 1;
              });
          }
          .width('100%')
          .margin({ top: 8 });

          Button('保存规则')
            .width('100%')
            .height(40)
            .borderRadius(20)
            .backgroundColor(AppColors.PRIMARY)
            .fontColor('#FFFFFF')
            .fontSize(14)
            .margin({ top: 12 })
            .onClick((): void => {
              this.addRule();
            });
        }
        .width('100%')
        .padding(14)
        .margin({ left: 12, right: 12, bottom: 10 })
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(14)
        .shadow({ radius: 6, color: '#12000000', offsetX: 0, offsetY: 3 });
      }

      List({ space: 8 }) {
        ForEach(this.rules, (rule: AutomationRule) => {
          ListItem() {
            Row() {
              Column() {
                Text(`${MetricNames.MAP[rule.trigger_metric] || rule.trigger_metric} ${this.conditionText(rule.trigger_condition)} ${rule.trigger_value}`)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.TEXT_PRIMARY);

                Text(`动作：${this.deviceName(rule.action_device_id)} ${this.actionText(rule.action_type)}`)
                  .fontSize(12)
                  .fontColor(AppColors.TEXT_SECONDARY)
                  .margin({ top: 4 });
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1);

              Toggle({ type: ToggleType.Switch, isOn: rule.is_enabled === 1 })
                .selectedColor(AppColors.PRIMARY)
                .onChange((): void => {
                  this.toggleRule(rule);
                });
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(14)
            .shadow({ radius: 6, color: '#12000000', offsetX: 0, offsetY: 3 });
          }
        });
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 12, right: 12, bottom: 10 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG);
  }
}
