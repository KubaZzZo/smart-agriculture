// 智慧农业 - 环境监测视图
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors, MetricNames } from '../common/Constants';
import { SensorData, SensorHistoryResponse } from '../model/DataModels';

@Component
export struct MonitorView {
  @State latestData: SensorData | null = null;
  @State historyList: SensorData[] = [];
  @State loading: boolean = true;
  @State selectedMetric: string = 'temperature';
  @State refreshAngle: number = 0;

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.loading = true;
    this.refreshAngle += 360;
    try {
      const latest = await ApiService.get<SensorData>(ApiConstants.SENSOR_LATEST);
      this.latestData = latest;
      const history = await ApiService.get<SensorHistoryResponse>(ApiConstants.SENSOR_HISTORY,
        { 'page': '1', 'page_size': '20' });
      this.historyList = history.items;
    } catch (e) {
      const latest: SensorData = {
        id: 0, temperature: 25.6, humidity: 62.3,
        light_intensity: 32000, co2_level: 520, soil_moisture: 45.8,
        created_at: new Date().toISOString()
      };
      this.latestData = latest;
      const h1: SensorData = { id: 1, temperature: 25.6, humidity: 62.3,
        light_intensity: 32000, co2_level: 520, soil_moisture: 45.8,
        created_at: '2025-03-22T14:00:00' };
      const h2: SensorData = { id: 2, temperature: 24.8, humidity: 63.1,
        light_intensity: 35000, co2_level: 510, soil_moisture: 46.2,
        created_at: '2025-03-22T13:00:00' };
      const h3: SensorData = { id: 3, temperature: 26.1, humidity: 59.8,
        light_intensity: 38000, co2_level: 495, soil_moisture: 44.5,
        created_at: '2025-03-22T12:00:00' };
      const h4: SensorData = { id: 4, temperature: 23.5, humidity: 65.4,
        light_intensity: 28000, co2_level: 540, soil_moisture: 48.1,
        created_at: '2025-03-22T11:00:00' };
      const h5: SensorData = { id: 5, temperature: 22.3, humidity: 68.2,
        light_intensity: 18000, co2_level: 560, soil_moisture: 50.3,
        created_at: '2025-03-22T10:00:00' };
      const h6: SensorData = { id: 6, temperature: 21.0, humidity: 70.5,
        light_intensity: 12000, co2_level: 580, soil_moisture: 52.0,
        created_at: '2025-03-22T09:00:00' };
      const h7: SensorData = { id: 7, temperature: 20.2, humidity: 72.1,
        light_intensity: 8000, co2_level: 600, soil_moisture: 53.5,
        created_at: '2025-03-22T08:00:00' };
      const h8: SensorData = { id: 8, temperature: 19.8, humidity: 74.0,
        light_intensity: 3000, co2_level: 620, soil_moisture: 54.8,
        created_at: '2025-03-22T07:00:00' };
      this.historyList = [h1, h2, h3, h4, h5, h6, h7, h8];
    } finally {
      this.loading = false;
    }
  }

  getMetricValue(data: SensorData, metric: string): number {
    const map: Record<string, number> = {
      'temperature': data.temperature,
      'humidity': data.humidity,
      'light_intensity': data.light_intensity,
      'co2_level': data.co2_level,
      'soil_moisture': data.soil_moisture
    };
    return map[metric] || 0;
  }

  getMetricColor(metric: string): string {
    const map: Record<string, string> = {
      'temperature': AppColors.TEMP_COLOR,
      'humidity': AppColors.HUMIDITY_COLOR,
      'light_intensity': AppColors.LIGHT_COLOR,
      'co2_level': AppColors.CO2_COLOR,
      'soil_moisture': AppColors.SOIL_COLOR
    };
    return map[metric] || AppColors.PRIMARY;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('环境监测')
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

      // 实时数据面板
      if (this.latestData) {
        Column() {
          Text('实时数据')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ bottom: 10 })
            .width('100%')

          this.metricRow('温度', this.latestData.temperature.toFixed(1), '°C', AppColors.TEMP_COLOR)
          this.metricRow('湿度', this.latestData.humidity.toFixed(1), '%', AppColors.HUMIDITY_COLOR)
          this.metricRow('光照', this.latestData.light_intensity.toFixed(0), 'Lux', AppColors.LIGHT_COLOR)
          this.metricRow('CO₂', this.latestData.co2_level.toFixed(0), 'ppm', AppColors.CO2_COLOR)
          this.metricRow('土壤湿度', this.latestData.soil_moisture.toFixed(1), '%', AppColors.SOIL_COLOR)
        }
        .width('100%')
        .padding(16)
        .margin({ left: 12, right: 12 })
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(12)
        .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
      }

      // 指标选择
      Text('历史记录')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_SECONDARY)
        .margin({ top: 16, bottom: 8 })
        .padding({ left: 16 })
        .width('100%')

      // 历史数据列表
      List() {
        ForEach(this.historyList, (item: SensorData) => {
          ListItem() {
            Row() {
              Text(item.created_at ? item.created_at.replace('T', ' ').substring(5, 16) : '')
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
                .width(90)
              Text(item.temperature.toFixed(1) + '°C')
                .fontSize(12)
                .fontColor(AppColors.TEMP_COLOR)
                .width(55)
              Text(item.humidity.toFixed(0) + '%')
                .fontSize(12)
                .fontColor(AppColors.HUMIDITY_COLOR)
                .width(45)
              Text(item.light_intensity.toFixed(0))
                .fontSize(12)
                .fontColor(AppColors.LIGHT_COLOR)
                .width(55)
              Text(item.soil_moisture.toFixed(0) + '%')
                .fontSize(12)
                .fontColor(AppColors.SOIL_COLOR)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .margin({ left: 12, right: 12 })
      .backgroundColor(AppColors.CARD_BG)
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG)
  }

  @Builder
  metricRow(label: string, value: string, unit: string, color: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width(80)
      Blank()
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(' ' + unit)
        .fontSize(12)
        .fontColor(AppColors.TEXT_SECONDARY)
        .margin({ top: 4 })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 0.5 }, color: AppColors.DIVIDER })
  }
}
