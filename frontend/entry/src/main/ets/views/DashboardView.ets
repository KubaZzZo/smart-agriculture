import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors, AppConfig } from '../common/Constants';
import { SystemOverview, SensorData } from '../model/DataModels';
import { realtimeService } from '../common/RealtimeService';

@Component
export struct DashboardView {
  @State overview: SystemOverview | null = null;
  @State latestSensor: SensorData | null = null;
  @State loading: boolean = true;
  @State errorMsg: string = '';
  private unsubscribeRealtime: (() => void) | null = null;

  aboutToAppear(): void {
    this.loadData();
    this.bindRealtime();
  }

  aboutToDisappear(): void {
    if (this.unsubscribeRealtime) {
      this.unsubscribeRealtime();
      this.unsubscribeRealtime = null;
    }
  }

  private applyMockData(): void {
    const mockSensor: SensorData = {
      id: 0,
      temperature: 25.6,
      humidity: 62.3,
      light_intensity: 32000,
      co2_level: 520,
      soil_moisture: 45.8,
      created_at: new Date().toISOString(),
    };
    this.latestSensor = mockSensor;
    this.overview = {
      device_total: 5,
      device_online: 3,
      alert_today: 1,
      latest_sensor: mockSensor,
    };
  }

  async loadData(): Promise<void> {
    this.loading = true;
    this.errorMsg = '';

    try {
      const ov: SystemOverview = await ApiService.get<SystemOverview>(ApiConstants.SYSTEM_OVERVIEW);
      this.overview = ov;
      if (ov.latest_sensor) {
        this.latestSensor = ov.latest_sensor;
      }
    } catch (_e) {
      this.errorMsg = '加载首页数据失败';
      if (AppConfig.ENABLE_OFFLINE_MOCK) {
        this.applyMockData();
      }
    } finally {
      this.loading = false;
    }
  }

  bindRealtime(): void {
    if (this.unsubscribeRealtime) {
      this.unsubscribeRealtime();
    }
    this.unsubscribeRealtime = realtimeService.subscribeSensorData((sensor: SensorData): void => {
      this.latestSensor = sensor;
      if (this.overview) {
        this.overview = {
          device_total: this.overview.device_total,
          device_online: this.overview.device_online,
          alert_today: this.overview.alert_today,
          latest_sensor: sensor,
        };
      }
    });
  }

  build(): void {
    Scroll() {
      Column() {
        Column() {
          Row() {
            Column() {
              Text('温室控制台')
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF');
              Text('环境与设备实时协同')
                .fontSize(12)
                .fontColor('#D6EBDD')
                .margin({ top: 4 });
            }
            .alignItems(HorizontalAlign.Start);

            Blank();

            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(22)
              .fontColor(['#FFFFFF'])
              .padding(8)
              .backgroundColor('#1FFFFFFF')
              .borderRadius(20)
              .onClick((): void => {
                this.loadData();
              });
          }
          .width('100%');

          Row() {
            this.headChip('在线设备', `${this.overview?.device_online || 0}/${this.overview?.device_total || 0}`);
            this.headChip('今日告警', `${this.overview?.alert_today || 0}`);
            this.headChip('同步状态', this.loading ? '更新中' : '实时');
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ top: 14 });
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 22 })
        .backgroundColor(AppColors.PRIMARY_DARK)
        .borderRadius({ bottomLeft: 24, bottomRight: 24 });

        if (this.errorMsg) {
          Text(this.errorMsg)
            .fontSize(12)
            .fontColor(AppColors.WARN)
            .width('100%')
            .padding({ left: 16, right: 16, top: 10 });
        }

        Column() {
          Text('环境概览')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .width('100%')
            .margin({ bottom: 10 });

          this.metricCard('温度', this.latestSensor ? this.latestSensor.temperature.toFixed(1) : '--', '℃', AppColors.TEMP_COLOR);
          this.metricCard('湿度', this.latestSensor ? this.latestSensor.humidity.toFixed(1) : '--', '%', AppColors.HUMIDITY_COLOR);
          this.metricCard('光照强度', this.latestSensor ? this.latestSensor.light_intensity.toFixed(0) : '--', '勒克斯', AppColors.LIGHT_COLOR);
          this.metricCard('二氧化碳', this.latestSensor ? this.latestSensor.co2_level.toFixed(0) : '--', '百万分率', AppColors.CO2_COLOR);
          this.metricCard('土壤湿度', this.latestSensor ? this.latestSensor.soil_moisture.toFixed(1) : '--', '%', AppColors.SOIL_COLOR);
        }
        .width('100%')
        .padding(14)
        .margin({ left: 12, right: 12, top: 12 })
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(16)
        .shadow({ radius: 8, color: '#12000000', offsetX: 0, offsetY: 4 });

        Text('快捷操作')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
          .padding({ left: 16 })
          .margin({ top: 18, bottom: 10 });

        Row() {
          this.actionCard('灌溉', $r('sys.symbol.drop'), 'pages/IrrigationPage');
          this.actionCard('光照', $r('sys.symbol.sun_max'), 'pages/LightingPage');
          this.actionCard('联动', $r('sys.symbol.link'), 'pages/AutomationPage');
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceEvenly)
        .padding({ bottom: 20 });
      }
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG)
    .scrollBar(BarState.Off);
  }

  @Builder
  headChip(label: string, value: string): void {
    Column() {
      Text(label)
        .fontSize(10)
        .fontColor('#C9E7D4');
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ top: 2 });
    }
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor('#1AFFFFFF')
    .borderRadius(12)
    .width(104)
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  metricCard(label: string, value: string, unit: string, color: string): void {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(AppColors.TEXT_SECONDARY)
        .layoutWeight(1);
      Text(value)
        .fontSize(22)
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

  @Builder
  actionCard(label: string, icon: Resource, page: string): void {
    Column() {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([AppColors.PRIMARY]);
      Text(label)
        .fontSize(12)
        .fontColor(AppColors.TEXT_PRIMARY)
        .margin({ top: 8 });
    }
    .width(104)
    .height(86)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(14)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .shadow({ radius: 6, color: '#14000000', offsetX: 0, offsetY: 3 })
    .onClick((): void => {
      router.pushUrl({ url: page });
    });
  }
}
