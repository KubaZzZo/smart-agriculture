import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors } from '../common/Constants';
import { DailyReport } from '../model/DataModels';

@Entry
@Component
struct ReportPage {
  @State reports: DailyReport[] = [];
  @State selectedReport: DailyReport | null = null;

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      this.reports = await ApiService.get<DailyReport[]>(ApiConstants.REPORT_LIST);
    } catch (_e) {
      const r1: DailyReport = {
        id: 1,
        report_date: '2025-03-22',
        avg_temperature: 24.5,
        avg_humidity: 58.3,
        avg_light: 35000,
        avg_co2: 480,
        avg_soil_moisture: 48.2,
        alert_count: 3,
        irrigation_count: 5,
        water_usage: 45.6,
        summary: '今日环境整体稳定，土壤湿度偏低时已自动触发灌溉。',
        created_at: '',
      };
      const r2: DailyReport = {
        id: 2,
        report_date: '2025-03-21',
        avg_temperature: 23.8,
        avg_humidity: 61.2,
        avg_light: 28000,
        avg_co2: 510,
        avg_soil_moisture: 52.1,
        alert_count: 1,
        irrigation_count: 3,
        water_usage: 28.3,
        summary: '光照偏弱，系统已自动开启补光灯并恢复到目标范围。',
        created_at: '',
      };
      this.reports = [r1, r2];
    }
  }

  build(): void {
    Column() {
      Row() {
        Text('< 返回')
          .fontSize(15)
          .fontColor(AppColors.PRIMARY)
          .onClick((): void => {
            if (this.selectedReport) {
              this.selectedReport = null;
              return;
            }
            router.back();
          });

        Text(this.selectedReport ? '报告详情' : '数据报告')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .margin({ left: 12 });

        Blank();

        if (!this.selectedReport) {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(20)
            .fontColor([AppColors.TEXT_SECONDARY])
            .onClick((): void => {
              this.loadData();
            });
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 10 });

      if (this.selectedReport) {
        Scroll() {
          Column() {
            Column() {
              this.statRow('平均温度', `${this.selectedReport.avg_temperature.toFixed(1)} C`, AppColors.TEMP_COLOR);
              this.statRow('平均湿度', `${this.selectedReport.avg_humidity.toFixed(1)} %`, AppColors.HUMIDITY_COLOR);
              this.statRow('平均光照', `${this.selectedReport.avg_light.toFixed(0)} 勒克斯`, AppColors.LIGHT_COLOR);
              this.statRow('平均二氧化碳', `${this.selectedReport.avg_co2.toFixed(0)} 百万分率`, AppColors.CO2_COLOR);
              this.statRow('平均土壤湿度', `${this.selectedReport.avg_soil_moisture.toFixed(1)} %`, AppColors.SOIL_COLOR);
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(14)
            .shadow({ radius: 6, color: '#12000000', offsetX: 0, offsetY: 3 })
            .margin({ left: 12, right: 12 });

            Row() {
              this.metricBox('预警次数', this.selectedReport.alert_count.toString(), AppColors.WARN);
              this.metricBox('灌溉次数', this.selectedReport.irrigation_count.toString(), AppColors.HUMIDITY_COLOR);
              this.metricBox('用水量(L)', this.selectedReport.water_usage.toFixed(1), AppColors.PRIMARY);
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceEvenly)
            .margin({ top: 12 });

            Column() {
              Text('日报总结')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_SECONDARY)
                .width('100%');

              Text(this.selectedReport.summary || '-')
                .fontSize(14)
                .lineHeight(22)
                .fontColor(AppColors.TEXT_PRIMARY)
                .margin({ top: 8 });
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(14)
            .shadow({ radius: 6, color: '#12000000', offsetX: 0, offsetY: 3 })
            .margin({ left: 12, right: 12, top: 12, bottom: 18 });
          }
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off);
      } else {
        List({ space: 8 }) {
          ForEach(this.reports, (report: DailyReport) => {
            ListItem() {
              Row() {
                Column() {
                  Text(report.report_date)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TEXT_PRIMARY);

                  Text(`温度 ${report.avg_temperature.toFixed(1)}C · 湿度 ${report.avg_humidity.toFixed(0)}% · 预警 ${report.alert_count}次`)
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                    .margin({ top: 4 });
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1);

                Text('>')
                  .fontSize(16)
                  .fontColor(AppColors.TEXT_HINT);
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(14)
              .shadow({ radius: 6, color: '#12000000', offsetX: 0, offsetY: 3 })
              .onClick((): void => {
                this.selectedReport = report;
              });
            }
          });
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12, bottom: 10 });
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG);
  }

  @Builder
  statRow(label: string, value: string, color: string): void {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(AppColors.TEXT_PRIMARY)
        .layoutWeight(1);
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(color);
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .border({ width: { bottom: 0.5 }, color: AppColors.DIVIDER });
  }

  @Builder
  metricBox(label: string, value: string, color: string): void {
    Column() {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(color);
      Text(label)
        .fontSize(11)
        .fontColor(AppColors.TEXT_SECONDARY)
        .margin({ top: 2 });
    }
    .width(110)
    .padding({ top: 14, bottom: 14 })
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(14)
    .alignItems(HorizontalAlign.Center)
    .shadow({ radius: 6, color: '#12000000', offsetX: 0, offsetY: 3 });
  }
}
