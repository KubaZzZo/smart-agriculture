import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors, AppConfig } from '../common/Constants';
import { CameraSnapshotResponse, PestDetectFromPathRequest, PestRealtimeItem, PestRealtimeListResponse, SensorData, SensorHistoryResponse } from '../model/DataModels';
import { realtimeService } from '../common/RealtimeService';

@Component
export struct MonitorView {
  @State latestData: SensorData | null = null;
  @State historyList: SensorData[] = [];
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State latestPest: PestRealtimeItem | null = null;
  @State pestRecentItems: PestRealtimeItem[] = [];
  @State triggeringPest: boolean = false;
  @State continuousDetecting: boolean = false;
  @State pestHint: string = 'auto';
  private unsubscribeRealtime: (() => void) | null = null;
  private unsubscribePestRealtime: (() => void) | null = null;
  private continuousTimer: number = -1;

  aboutToAppear(): void {
    this.loadData();
    this.bindRealtime();
    this.loadRecentPestRecords();
  }

  aboutToDisappear(): void {
    if (this.unsubscribeRealtime) {
      this.unsubscribeRealtime();
      this.unsubscribeRealtime = null;
    }
    if (this.unsubscribePestRealtime) {
      this.unsubscribePestRealtime();
      this.unsubscribePestRealtime = null;
    }
    this.stopContinuousDetect();
  }

  private mockHistory(): SensorData[] {
    const i1: SensorData = { id: 1, temperature: 25.6, humidity: 62.3, light_intensity: 32000, co2_level: 520, soil_moisture: 45.8, created_at: '2025-03-22T14:00:00' };
    const i2: SensorData = { id: 2, temperature: 24.8, humidity: 63.1, light_intensity: 35000, co2_level: 510, soil_moisture: 46.2, created_at: '2025-03-22T13:00:00' };
    const i3: SensorData = { id: 3, temperature: 26.1, humidity: 59.8, light_intensity: 38000, co2_level: 495, soil_moisture: 44.5, created_at: '2025-03-22T12:00:00' };
    return [i1, i2, i3];
  }

  async loadData(): Promise<void> {
    this.loading = true;
    this.errorMsg = '';
    try {
      const latest: SensorData = await ApiService.get<SensorData>(ApiConstants.SENSOR_LATEST);
      this.latestData = latest;
      const query = new Map<string, string>([['page', '1'], ['page_size', '20']]);
      const history: SensorHistoryResponse = await ApiService.get<SensorHistoryResponse>(ApiConstants.SENSOR_HISTORY, query);
      this.historyList = history.items;
    } catch (_e) {
      this.errorMsg = '加载监控数据失败';
      if (AppConfig.ENABLE_OFFLINE_MOCK) {
        this.latestData = {
          id: 0,
          temperature: 25.6,
          humidity: 62.3,
          light_intensity: 32000,
          co2_level: 520,
          soil_moisture: 45.8,
          created_at: new Date().toISOString(),
        };
        this.historyList = this.mockHistory();
      }
    } finally {
      this.loading = false;
    }
  }

  async loadRecentPestRecords(): Promise<void> {
    try {
      const query = new Map<string, string>([['limit', '8'], ['source', 'mobile']]);
      const recent: PestRealtimeListResponse = await ApiService.get<PestRealtimeListResponse>(ApiConstants.AI_PEST_RECENT, query);
      this.pestRecentItems = recent.items || [];
      if (!this.latestPest && this.pestRecentItems.length > 0) {
        this.latestPest = this.pestRecentItems[0];
      }
    } catch (_e) {
      // ignore when no data yet
    }
  }

  bindRealtime(): void {
    if (this.unsubscribeRealtime) {
      this.unsubscribeRealtime();
    }
    if (this.unsubscribePestRealtime) {
      this.unsubscribePestRealtime();
    }
    this.unsubscribeRealtime = realtimeService.subscribeSensorData((sensor: SensorData): void => {
      this.latestData = sensor;
      this.historyList = [sensor, ...this.historyList].slice(0, 20);
    });
    this.unsubscribePestRealtime = realtimeService.subscribePestRealtime((item: PestRealtimeItem): void => {
      this.latestPest = item;
      this.pestRecentItems = [item, ...this.pestRecentItems].slice(0, 8);
    });
  }

  build(): void {
    Column() {
      Row() {
        Column() {
          Text('环境监控')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY);
          Text('实时数据与历史趋势')
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
            this.loadRecentPestRecords();
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

      if (this.latestData) {
        Column() {
          this.metricRow('温度', this.latestData.temperature.toFixed(1), '℃', AppColors.TEMP_COLOR);
          this.metricRow('湿度', this.latestData.humidity.toFixed(1), '%', AppColors.HUMIDITY_COLOR);
          this.metricRow('光照', this.latestData.light_intensity.toFixed(0), '勒克斯', AppColors.LIGHT_COLOR);
          this.metricRow('二氧化碳', this.latestData.co2_level.toFixed(0), '百万分率', AppColors.CO2_COLOR);
          this.metricRow('土壤湿度', this.latestData.soil_moisture.toFixed(1), '%', AppColors.SOIL_COLOR);
        }
        .width('100%')
        .padding(14)
        .margin({ left: 12, right: 12 })
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(16)
        .shadow({ radius: 8, color: '#14000000', offsetX: 0, offsetY: 4 });
      }

      Column() {
        Text('叶片害虫实时识别（手机端）')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_SECONDARY)
          .width('100%');

        Row() {
          Select([
            { value: '自动' },
            { value: '高风险样本' },
            { value: '中风险样本' },
            { value: '低风险样本' },
          ])
            .value(this.pestSelectValue())
            .onSelect((index: number): void => {
              if (index === 1) {
                this.pestHint = 'high';
              } else if (index === 2) {
                this.pestHint = 'medium';
              } else if (index === 3) {
                this.pestHint = 'low';
              } else {
                this.pestHint = 'auto';
              }
            })
            .layoutWeight(1);

          Button(this.triggeringPest ? '上报中...' : '上传识别帧')
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor(this.triggeringPest ? AppColors.TEXT_HINT : AppColors.PRIMARY)
            .height(36)
            .margin({ left: 8 })
            .enabled(!this.triggeringPest)
            .onClick((): void => {
              this.triggerMobilePestDetect();
            });
        }
        .width('100%')
        .margin({ top: 8, bottom: 8 });

        Button(this.continuousDetecting ? '停止连续采集' : '开启连续采集')
          .fontSize(12)
          .fontColor('#FFFFFF')
          .backgroundColor(this.continuousDetecting ? AppColors.WARN : AppColors.ACCENT)
          .height(34)
          .onClick((): void => {
            this.toggleContinuousDetect();
          });

        if (this.latestPest) {
          this.metricRow('风险等级', this.riskText(this.latestPest.risk_level), '', this.riskColor(this.latestPest.risk_level));
          this.metricRow('置信度', (this.latestPest.confidence * 100).toFixed(0), '%', AppColors.PRIMARY);
          this.metricRow('图像质量', (this.latestPest.quality_score * 100).toFixed(0), '%', AppColors.ACCENT);
          this.metricRow('识别类型', this.latestPest.pest_type, '', AppColors.TEXT_PRIMARY);
          Text(`更新时间：${this.latestPest.created_at.replace('T', ' ').substring(5, 19)}`)
            .fontSize(11)
            .fontColor(AppColors.TEXT_HINT)
            .width('100%')
            .margin({ top: 8 });
        } else {
          Text('暂无实时识别数据，手机端上传识别帧后会自动刷新。')
            .fontSize(12)
            .fontColor(AppColors.TEXT_HINT)
            .width('100%')
            .margin({ top: 8 });
        }

        if (this.pestRecentItems.length > 0) {
          Text('最近识别记录')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_SECONDARY)
            .width('100%')
            .margin({ top: 10, bottom: 6 });

          ForEach(this.pestRecentItems, (item: PestRealtimeItem) => {
            Row() {
              Text(item.created_at.replace('T', ' ').substring(11, 19))
                .fontSize(11)
                .fontColor(AppColors.TEXT_HINT)
                .width(68);
              Text(this.riskText(item.risk_level))
                .fontSize(12)
                .fontColor(this.riskColor(item.risk_level))
                .layoutWeight(1);
              Text((item.confidence * 100).toFixed(0) + '%')
                .fontSize(12)
                .fontColor(AppColors.PRIMARY)
                .width(54)
                .textAlign(TextAlign.End);
            }
            .width('100%')
            .padding({ top: 6, bottom: 6 })
            .border({ width: { bottom: 0.5 }, color: AppColors.DIVIDER });
          });
        }
      }
      .width('100%')
      .padding(14)
      .margin({ left: 12, right: 12, top: 12 })
      .backgroundColor(AppColors.CARD_BG)
      .borderRadius(16)
      .shadow({ radius: 8, color: '#14000000', offsetX: 0, offsetY: 4 });

      Text('最新记录')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_SECONDARY)
        .width('100%')
        .padding({ left: 16 })
        .margin({ top: 14, bottom: 8 });

      List({ space: 8 }) {
        ForEach(this.historyList, (item: SensorData) => {
          ListItem() {
            Row() {
              Text(item.created_at ? item.created_at.replace('T', ' ').substring(5, 16) : '')
                .fontSize(11)
                .fontColor(AppColors.TEXT_HINT)
                .width(92);
              Text(item.temperature.toFixed(1) + '℃')
                .fontSize(12)
                .fontColor(AppColors.TEMP_COLOR)
                .layoutWeight(1);
              Text(item.humidity.toFixed(0) + '%')
                .fontSize(12)
                .fontColor(AppColors.HUMIDITY_COLOR)
                .layoutWeight(1);
              Text(item.soil_moisture.toFixed(0) + '%')
                .fontSize(12)
                .fontColor(AppColors.SOIL_COLOR)
                .layoutWeight(1);
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(10);
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

  @Builder
  metricRow(label: string, value: string, unit: string, color: string): void {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(AppColors.TEXT_SECONDARY)
        .layoutWeight(1);
      Text(value)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor(color);
      Text(` ${unit}`)
        .fontSize(12)
        .fontColor(AppColors.TEXT_SECONDARY)
        .margin({ top: 5 });
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 0.5 }, color: AppColors.DIVIDER });
  }

  private riskColor(level: string): string {
    if (level === 'high') {
      return AppColors.WARN;
    }
    if (level === 'medium') {
      return AppColors.ACCENT;
    }
    return AppColors.PRIMARY;
  }

  private riskText(level: string): string {
    if (level === 'high') {
      return '高风险';
    }
    if (level === 'medium') {
      return '中风险';
    }
    if (level === 'low') {
      return '低风险';
    }
    return '未知';
  }

  private pestSelectValue(): string {
    if (this.pestHint === 'high') {
      return '高风险样本';
    }
    if (this.pestHint === 'medium') {
      return '中风险样本';
    }
    if (this.pestHint === 'low') {
      return '低风险样本';
    }
    return '自动';
  }

  private toggleContinuousDetect(): void {
    if (this.continuousDetecting) {
      this.stopContinuousDetect();
      return;
    }
    this.continuousDetecting = true;
    this.triggerMobilePestDetect();
    this.continuousTimer = setInterval((): void => {
      this.triggerMobilePestDetect();
    }, 10000) as number;
  }

  private stopContinuousDetect(): void {
    if (this.continuousTimer !== -1) {
      clearInterval(this.continuousTimer);
      this.continuousTimer = -1;
    }
    this.continuousDetecting = false;
  }

  private async triggerMobilePestDetect(): Promise<void> {
    if (this.triggeringPest) {
      return;
    }
    this.triggeringPest = true;
    try {
      const snapshot: CameraSnapshotResponse = await ApiService.get<CameraSnapshotResponse>(ApiConstants.CAMERA_SNAPSHOT);
      const req: PestDetectFromPathRequest = {
        image_url: snapshot.image_url,
        camera_id: 'camera-1',
        zone_id: 'zone-1',
        source: 'mobile',
        risk_hint_fallback: this.pestHint,
      };
      await ApiService.post<object>(ApiConstants.AI_PEST_DETECT_FROM_PATH, req);
      await this.loadRecentPestRecords();
    } catch (_e) {
      this.errorMsg = '手机端识别帧上传失败';
    } finally {
      this.triggeringPest = false;
    }
  }
}
