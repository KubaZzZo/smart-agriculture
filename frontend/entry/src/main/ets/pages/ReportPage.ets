// 智慧农业 - 数据报告页面
import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors } from '../common/Constants';
import { DailyReport } from '../model/DataModels';

@Entry
@Component
struct ReportPage {
  @State reports: DailyReport[] = [];
  @State loading: boolean = true;
  @State selectedReport: DailyReport | null = null;

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.loading = true;
    try {
      this.reports = await ApiService.get<DailyReport[]>(ApiConstants.REPORT_LIST);
    } catch (e) {
      this.reports = [
        {
          id: 1, report_date: '2025-03-22', avg_temperature: 24.5, avg_humidity: 58.3,
          avg_light: 35000, avg_co2: 480, avg_soil_moisture: 48.2,
          alert_count: 3, irrigation_count: 5, water_usage: 45.6,
          summary: '今日环境整体稳定，土壤湿度略低触发自动灌溉5次，共用水45.6L。',
          created_at: ''
        },
        {
          id: 2, report_date: '2025-03-21', avg_temperature: 23.8, avg_humidity: 61.2,
          avg_light: 28000, avg_co2: 510, avg_soil_moisture: 52.1,
          alert_count: 1, irrigation_count: 3, water_usage: 28.3,
          summary: '光照偏弱，LED补光灯自动开启。灌溉3次，用水28.3L。',
          created_at: ''
        }
      ];
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      Row() {
        Text('< 返回').fontSize(15).fontColor(AppColors.PRIMARY)
          .onClick(() => { this.getUIContext().getRouter().back(); })
        Text('数据报告').fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY).margin({ left: 12 })
        Blank()
        Text('🔄').fontSize(20).onClick(() => { this.loadData(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      if (this.selectedReport) {
        // 报告详情
        Scroll() {
          Column() {
            Row() {
              Text('< 返回列表').fontSize(13).fontColor(AppColors.PRIMARY)
                .onClick(() => { this.selectedReport = null; })
            }.width('100%').margin({ bottom: 8 })

            Text(`${this.selectedReport.report_date} 日报`)
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColors.TEXT_PRIMARY)
              .width('100%')

            // 环境均值
            Column() {
              Text('环境数据均值').fontSize(14).fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_SECONDARY).width('100%').margin({ bottom: 8 })
              this.statRow('平均温度', `${this.selectedReport.avg_temperature.toFixed(1)}°C`, AppColors.TEMP_COLOR)
              this.statRow('平均湿度', `${this.selectedReport.avg_humidity.toFixed(1)}%`, AppColors.HUMIDITY_COLOR)
              this.statRow('平均光照', `${this.selectedReport.avg_light.toFixed(0)} Lux`, AppColors.LIGHT_COLOR)
              this.statRow('平均CO₂', `${this.selectedReport.avg_co2.toFixed(0)} ppm`, AppColors.CO2_COLOR)
              this.statRow('平均土壤湿度', `${this.selectedReport.avg_soil_moisture.toFixed(1)}%`, AppColors.SOIL_COLOR)
            }
            .width('100%').padding(14).margin({ top: 12 })
            .backgroundColor(AppColors.CARD_BG).borderRadius(12)
            .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })

            // 运行统计
            Row() {
              Column() {
                Text(this.selectedReport.alert_count.toString())
                  .fontSize(24).fontWeight(FontWeight.Bold).fontColor(AppColors.WARN)
                Text('预警次数').fontSize(11).fontColor(AppColors.TEXT_SECONDARY).margin({ top: 2 })
              }.layoutWeight(1).alignItems(HorizontalAlign.Center)
              Column() {
                Text(this.selectedReport.irrigation_count.toString())
                  .fontSize(24).fontWeight(FontWeight.Bold).fontColor(AppColors.HUMIDITY_COLOR)
                Text('灌溉次数').fontSize(11).fontColor(AppColors.TEXT_SECONDARY).margin({ top: 2 })
              }.layoutWeight(1).alignItems(HorizontalAlign.Center)
              Column() {
                Text(`${this.selectedReport.water_usage.toFixed(1)}`)
                  .fontSize(24).fontWeight(FontWeight.Bold).fontColor(AppColors.PRIMARY)
                Text('用水量(L)').fontSize(11).fontColor(AppColors.TEXT_SECONDARY).margin({ top: 2 })
              }.layoutWeight(1).alignItems(HorizontalAlign.Center)
            }
            .width('100%').padding(16).margin({ top: 12 })
            .backgroundColor(AppColors.CARD_BG).borderRadius(12)
            .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })

            // 总结
            if (this.selectedReport.summary) {
              Column() {
                Text('日报总结').fontSize(14).fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.TEXT_SECONDARY).width('100%').margin({ bottom: 6 })
                Text(this.selectedReport.summary)
                  .fontSize(14).fontColor(AppColors.TEXT_PRIMARY).lineHeight(22)
              }
              .width('100%').padding(14).margin({ top: 12, bottom: 20 })
              .backgroundColor(AppColors.CARD_BG).borderRadius(12)
              .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
            }
          }
          .padding({ left: 12, right: 12 })
        }
        .layoutWeight(1).scrollBar(BarState.Off)
      } else {
        // 报告列表
        if (this.reports.length === 0 && !this.loading) {
          Column() {
            Text('📋').fontSize(48)
            Text('暂无报告数据').fontSize(14).fontColor(AppColors.TEXT_HINT).margin({ top: 8 })
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        } else {
          List({ space: 8 }) {
            ForEach(this.reports, (report: DailyReport) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(report.report_date)
                      .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppColors.TEXT_PRIMARY)
                    Text(`温度${report.avg_temperature.toFixed(1)}°C · 湿度${report.avg_humidity.toFixed(0)}% · 预警${report.alert_count}次`)
                      .fontSize(12).fontColor(AppColors.TEXT_SECONDARY).margin({ top: 4 })
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text('>').fontSize(16).fontColor(AppColors.TEXT_HINT)
                }
                .width('100%').padding(14)
                .backgroundColor(AppColors.CARD_BG).borderRadius(12)
                .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
                .onClick(() => { this.selectedReport = report; })
              }
            })
          }
          .width('100%').layoutWeight(1).padding({ left: 12, right: 12 })
        }
      }
    }
    .width('100%').height('100%').backgroundColor(AppColors.BG)
  }

  @Builder
  statRow(label: string, value: string, color: string) {
    Row() {
      Text(label).fontSize(13).fontColor(AppColors.TEXT_PRIMARY).layoutWeight(1)
      Text(value).fontSize(14).fontWeight(FontWeight.Medium).fontColor(color)
    }
    .width('100%').padding({ top: 6, bottom: 6 })
    .border({ width: { bottom: 0.5 }, color: AppColors.DIVIDER })
  }
}
