import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors, MetricNames, AppConfig } from '../common/Constants';
import { AlertRule, AlertLog, AlertLogListResponse, AlertRuleUpdateRequest } from '../model/DataModels';
import { realtimeService } from '../common/RealtimeService';

@Component
export struct AlertView {
  @State rules: AlertRule[] = [];
  @State logs: AlertLog[] = [];
  @State showRules: boolean = true;
  @State loading: boolean = true;
  @State errorMsg: string = '';
  private unsubscribeAlerts: (() => void) | null = null;

  aboutToAppear(): void {
    this.loadData();
    this.bindRealtimeAlerts();
  }

  aboutToDisappear(): void {
    if (this.unsubscribeAlerts) {
      this.unsubscribeAlerts();
      this.unsubscribeAlerts = null;
    }
  }

  async loadData(): Promise<void> {
    this.loading = true;
    this.errorMsg = '';
    try {
      this.rules = await ApiService.get<AlertRule[]>(ApiConstants.ALERT_RULES);
      const query = new Map<string, string>([['page', '1'], ['page_size', '30']]);
      const logRes: AlertLogListResponse = await ApiService.get<AlertLogListResponse>(ApiConstants.ALERT_LOGS, query);
      this.logs = logRes.items;
    } catch (_e) {
      this.errorMsg = '加载告警数据失败';
      if (AppConfig.ENABLE_OFFLINE_MOCK) {
        const r1: AlertRule = { id: 1, metric_name: 'temperature', min_value: 15, max_value: 35, is_enabled: 1, created_at: '', updated_at: '' };
        const r2: AlertRule = { id: 2, metric_name: 'humidity', min_value: 40, max_value: 80, is_enabled: 1, created_at: '', updated_at: '' };
        const r3: AlertRule = { id: 3, metric_name: 'co2_level', min_value: 400, max_value: 1500, is_enabled: 1, created_at: '', updated_at: '' };
        this.rules = [r1, r2, r3];

        const l1: AlertLog = { id: 1, rule_id: 1, metric_name: 'temperature', metric_value: 36.5, alert_type: 'high', is_read: 0, created_at: '2025-03-22T14:30:00' };
        const l2: AlertLog = { id: 2, rule_id: 2, metric_name: 'humidity', metric_value: 82.1, alert_type: 'high', is_read: 1, created_at: '2025-03-22T09:45:00' };
        this.logs = [l1, l2];
      }
    } finally {
      this.loading = false;
    }
  }

  async toggleRule(rule: AlertRule): Promise<void> {
    const newEnabled: number = rule.is_enabled === 1 ? 0 : 1;
    const body: AlertRuleUpdateRequest = { is_enabled: newEnabled };
    try {
      await ApiService.put<void>(`${ApiConstants.ALERT_RULES}/${rule.id}`, body);
    } catch (_e) {
      // noop
    }

    const idx: number = this.rules.findIndex((r: AlertRule): boolean => r.id === rule.id);
    if (idx >= 0) {
      const oldRule: AlertRule = this.rules[idx];
      this.rules[idx] = {
        id: oldRule.id,
        metric_name: oldRule.metric_name,
        min_value: oldRule.min_value,
        max_value: oldRule.max_value,
        is_enabled: newEnabled,
        created_at: oldRule.created_at,
        updated_at: oldRule.updated_at,
      };
      this.rules = this.rules.slice();
    }
  }

  getMetricLabel(name: string): string {
    return MetricNames.MAP[name] || name;
  }

  bindRealtimeAlerts(): void {
    if (this.unsubscribeAlerts) {
      this.unsubscribeAlerts();
    }
    this.unsubscribeAlerts = realtimeService.subscribeAlerts((items: AlertLog[]): void => {
      this.logs = [...items, ...this.logs].slice(0, 100);
    });
  }

  build(): void {
    Column() {
      Row() {
        Column() {
          Text('告警中心')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY);
          Text('规则、触发记录与处理历史')
            .fontSize(11)
            .fontColor(AppColors.TEXT_HINT)
            .margin({ top: 2 });
        }
        .alignItems(HorizontalAlign.Start);

        Blank();

        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(20)
          .fontColor([AppColors.TEXT_SECONDARY])
          .padding(8)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(20)
          .onClick((): void => {
            this.loadData();
          });
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 });

      if (this.errorMsg) {
        Text(this.errorMsg)
          .fontSize(12)
          .fontColor(AppColors.WARN)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 });
      }

      Row() {
        this.segmentTab('规则', this.showRules, (): void => {
          this.showRules = true;
        });
        this.segmentTab('日志', !this.showRules, (): void => {
          this.showRules = false;
        });
      }
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 8 })
      .justifyContent(FlexAlign.SpaceBetween);

      if (this.showRules) {
        List({ space: 8 }) {
          ForEach(this.rules, (rule: AlertRule) => {
            ListItem() {
              Row() {
                Column() {
                  Text(this.getMetricLabel(rule.metric_name))
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TEXT_PRIMARY);
                  Text(`范围 ${rule.min_value} - ${rule.max_value} ${MetricNames.UNITS[rule.metric_name] || ''}`)
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
              .borderRadius(12)
              .shadow({ radius: 5, color: '#12000000', offsetX: 0, offsetY: 2 });
            }
          });
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12 });
      } else {
        List({ space: 8 }) {
          ForEach(this.logs, (log: AlertLog) => {
            ListItem() {
              Row() {
                Text(log.alert_type === 'high' ? '高' : '低')
                  .fontSize(10)
                  .fontColor('#FFFFFF')
                  .padding({ left: 7, right: 7, top: 4, bottom: 4 })
                  .backgroundColor(log.alert_type === 'high' ? AppColors.WARN : AppColors.ACCENT)
                  .borderRadius(8)
                  .width(52);

                Column() {
                  Text(this.getMetricLabel(log.metric_name))
                    .fontSize(14)
                    .fontColor(AppColors.TEXT_PRIMARY);
                  Text(`数值 ${log.metric_value.toFixed(1)} ${MetricNames.UNITS[log.metric_name] || ''}`)
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                    .margin({ top: 2 });
                  Text(log.created_at ? log.created_at.replace('T', ' ').substring(0, 16) : '')
                    .fontSize(11)
                    .fontColor(AppColors.TEXT_HINT)
                    .margin({ top: 2 });
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 10 });
              }
              .width('100%')
              .padding(12)
              .backgroundColor(log.is_read === 0 ? AppColors.WARN_LIGHT : AppColors.CARD_BG)
              .borderRadius(12);
            }
          });
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12 });
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG);
  }

  @Builder
  segmentTab(title: string, active: boolean, onTap: () => void): void {
    Text(title)
      .fontSize(13)
      .fontWeight(active ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(active ? '#FFFFFF' : AppColors.TEXT_SECONDARY)
      .padding({ left: 20, right: 20, top: 10, bottom: 10 })
      .backgroundColor(active ? AppColors.PRIMARY : AppColors.CARD_BG)
      .borderRadius(12)
      .onClick((): void => {
        onTap();
      });
  }
}
