// 智慧农业 - 预警管理视图
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors, MetricNames } from '../common/Constants';
import { AlertRule, AlertLog, AlertLogListResponse, AlertRuleUpdateRequest } from '../model/DataModels';

@Component
export struct AlertView {
  @State rules: AlertRule[] = [];
  @State logs: AlertLog[] = [];
  @State showRules: boolean = true;
  @State loading: boolean = true;
  @State refreshAngle: number = 0;

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.loading = true;
    this.refreshAngle += 360;
    try {
      this.rules = await ApiService.get<AlertRule[]>(ApiConstants.ALERT_RULES);
      const logRes = await ApiService.get<AlertLogListResponse>(ApiConstants.ALERT_LOGS,
        { 'page': '1', 'page_size': '30' });
      this.logs = logRes.items;
    } catch (e) {
      const r1: AlertRule = { id: 1, metric_name: 'temperature', min_value: 15, max_value: 35, is_enabled: 1,
        created_at: '', updated_at: '' };
      const r2: AlertRule = { id: 2, metric_name: 'humidity', min_value: 40, max_value: 80, is_enabled: 1,
        created_at: '', updated_at: '' };
      const r3: AlertRule = { id: 3, metric_name: 'light_intensity', min_value: 2000, max_value: 80000, is_enabled: 1,
        created_at: '', updated_at: '' };
      const r4: AlertRule = { id: 4, metric_name: 'co2_level', min_value: 400, max_value: 1500, is_enabled: 1,
        created_at: '', updated_at: '' };
      const r5: AlertRule = { id: 5, metric_name: 'soil_moisture', min_value: 20, max_value: 70, is_enabled: 1,
        created_at: '', updated_at: '' };
      this.rules = [r1, r2, r3, r4, r5];
      const l1: AlertLog = { id: 1, rule_id: 1, metric_name: 'temperature', metric_value: 36.5,
        alert_type: 'high', is_read: 0, created_at: '2025-03-22T14:30:00' };
      const l2: AlertLog = { id: 2, rule_id: 5, metric_name: 'soil_moisture', metric_value: 18.2,
        alert_type: 'low', is_read: 0, created_at: '2025-03-22T12:15:00' };
      const l3: AlertLog = { id: 3, rule_id: 2, metric_name: 'humidity', metric_value: 82.1,
        alert_type: 'high', is_read: 1, created_at: '2025-03-22T09:45:00' };
      const l4: AlertLog = { id: 4, rule_id: 3, metric_name: 'light_intensity', metric_value: 1500.0,
        alert_type: 'low', is_read: 1, created_at: '2025-03-21T18:20:00' };
      const l5: AlertLog = { id: 5, rule_id: 4, metric_name: 'co2_level', metric_value: 1520.0,
        alert_type: 'high', is_read: 1, created_at: '2025-03-21T15:10:00' };
      this.logs = [l1, l2, l3, l4, l5];
    } finally {
      this.loading = false;
    }
  }

  async toggleRule(rule: AlertRule): Promise<void> {
    const newEnabled = rule.is_enabled === 1 ? 0 : 1;
    const body: AlertRuleUpdateRequest = { is_enabled: newEnabled };
    try {
      await ApiService.put<void>(`${ApiConstants.ALERT_RULES}/${rule.id}`, body);
    } catch (e) { /* offline */ }
    const idx = this.rules.findIndex((r: AlertRule) => r.id === rule.id);
    if (idx >= 0) {
      const old: AlertRule = this.rules[idx];
      const updated: AlertRule = {
        id: old.id, metric_name: old.metric_name, min_value: old.min_value,
        max_value: old.max_value, is_enabled: newEnabled,
        created_at: old.created_at, updated_at: old.updated_at
      };
      this.rules[idx] = updated;
      this.rules = this.rules.slice();
    }
  }

  getMetricLabel(name: string): string {
    return MetricNames.MAP[name] || name;
  }

  build() {
    Column() {
      Row() {
        Text('预警管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
        Blank()
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(22)
          .fontColor([AppColors.TEXT_SECONDARY])
          .padding(8)
          .rotate({ angle: this.refreshAngle })
          .animation({ duration: 800, curve: Curve.EaseInOut })
          .onClick(() => { this.loadData(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // Tab切换
      Row() {
        Text('预警规则')
          .fontSize(15)
          .fontWeight(this.showRules ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.showRules ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
          .padding({ left: 16, right: 16, bottom: 8 })
          .border({ width: { bottom: this.showRules ? 2 : 0 }, color: AppColors.PRIMARY })
          .onClick(() => { this.showRules = true; })
        Text('预警记录')
          .fontSize(15)
          .fontWeight(!this.showRules ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(!this.showRules ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
          .padding({ left: 16, right: 16, bottom: 8 })
          .border({ width: { bottom: !this.showRules ? 2 : 0 }, color: AppColors.PRIMARY })
          .onClick(() => { this.showRules = false; })
      }
      .margin({ bottom: 8 })

      if (this.showRules) {
        // 预警规则列表
        List({ space: 8 }) {
          ForEach(this.rules, (rule: AlertRule) => {
            ListItem() {
              Row() {
                Column() {
                  Text(this.getMetricLabel(rule.metric_name))
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TEXT_PRIMARY)
                  Text(`范围: ${rule.min_value} ~ ${rule.max_value} ${MetricNames.UNITS[rule.metric_name] || ''}`)
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: rule.is_enabled === 1 })
                  .selectedColor(AppColors.PRIMARY)
                  .onChange(() => { this.toggleRule(rule); })
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppColors.CARD_BG)
              .backdropBlur(20)
              .borderRadius(12)
              .shadow({ radius: 12, color: '#08000000', offsetX: 0, offsetY: 4 })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12 })
      } else {
        // 预警记录列表
        List({ space: 6 }) {
          ForEach(this.logs, (log: AlertLog) => {
            ListItem() {
              Row() {
                Text(log.alert_type === 'high' ? '⬆' : '⬇')
                  .fontSize(20)
                  .fontColor(AppColors.WARN)
                  .margin({ right: 10 })
                Column() {
                  Text(`${this.getMetricLabel(log.metric_name)} ${log.alert_type === 'high' ? '过高' : '过低'}`)
                    .fontSize(14)
                    .fontColor(AppColors.TEXT_PRIMARY)
                  Text(`当前值: ${log.metric_value.toFixed(1)} ${MetricNames.UNITS[log.metric_name] || ''}`)
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                    .margin({ top: 2 })
                  Text(log.created_at ? log.created_at.replace('T', ' ').substring(0, 16) : '')
                    .fontSize(11)
                    .fontColor(AppColors.TEXT_HINT)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (log.is_read === 0) {
                  Circle({ width: 8, height: 8 })
                    .fill(AppColors.WARN)
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(log.is_read === 0 ? '#1AEBEE' : AppColors.CARD_BG)
              .backdropBlur(15)
              .borderRadius(10)
              .shadow({ radius: 8, color: '#06000000', offsetX: 0, offsetY: 2 })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG)
  }
}
