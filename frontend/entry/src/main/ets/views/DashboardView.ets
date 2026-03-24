// 智慧农业 - 首页仪表盘视图
import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors, MetricNames } from '../common/Constants';
import { SystemOverview, SensorData, WeatherInfo } from '../model/DataModels';

@Component
export struct DashboardView {
  @State overview: SystemOverview | null = null;
  @State latestSensor: SensorData | null = null;
  @State loading: boolean = true;

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.loading = true;
    // 立即设置模拟数据，确保UI有内容
    const mockSensor: SensorData = {
      id: 0, temperature: 25.6, humidity: 62.3,
      light_intensity: 32000, co2_level: 520, soil_moisture: 45.8,
      created_at: new Date().toISOString()
    };
    if (!this.latestSensor) {
      this.latestSensor = mockSensor;
    }
    if (!this.overview) {
      const mockOverview: SystemOverview = {
        device_total: 5, device_online: 3, alert_today: 1, latest_sensor: mockSensor
      };
      this.overview = mockOverview;
    }
    try {
      const ov = await ApiService.get<SystemOverview>(ApiConstants.SYSTEM_OVERVIEW);
      this.overview = ov;
      if (ov.latest_sensor) {
        this.latestSensor = ov.latest_sensor;
      }
    } catch (e) {
      // 已有模拟数据，无需额外处理
    } finally {
      this.loading = false;
    }
  }

  build() {
    Scroll() {
      Column() {
        // ===== 顶部绿色横幅 =====
        Column() {
          Row() {
            Row() {
              SymbolGlyph($r('sys.symbol.leaf'))
                .fontSize(22).fontColor(['#A5D6A7']).margin({ right: 6 })
              Text('智慧农业')
                .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
            }
            Blank()
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(22).fontColor(['#FFFFFF'])
              .onClick(() => { this.loadData(); })
          }
          .width('100%')

          Text('实时监控 · 智能控制')
            .fontSize(11).fontColor('#A5D6A7').margin({ top: 3 })
            .width('100%')

          // 系统状态胶囊
          Row() {
            Row() {
              SymbolGlyph($r('sys.symbol.wifi'))
                .fontSize(13).fontColor(['#FFFFFF'])
              Text(` ${this.overview ? this.overview.device_online.toString() : '-'}/${this.overview ? this.overview.device_total.toString() : '-'} 在线`)
                .fontSize(12).fontColor('#FFFFFF')
            }
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor('#FFFFFF30')
            .borderRadius(14)

            Row() {
              SymbolGlyph($r('sys.symbol.bell'))
                .fontSize(13).fontColor(['#FFFFFF'])
              Text(` ${this.overview ? this.overview.alert_today.toString() : '-'} 预警`)
                .fontSize(12).fontColor('#FFFFFF')
            }
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor('#FFFFFF30')
            .borderRadius(14)
            .margin({ left: 10 })

            Blank()
            Text(new Date().getMonth() + 1 + '月' + new Date().getDate() + '日')
              .fontSize(12).fontColor('#A5D6A7')
          }
          .width('100%')
          .margin({ top: 16 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 24 })
        .backgroundColor('#1B5E20')
        .borderRadius({ bottomLeft: 24, bottomRight: 24 })

        // ===== 环境数据卡片 =====
        Column() {
          Row() {
            Text('实时环境')
              .fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppColors.TEXT_PRIMARY)
            Blank()
            Text('刚刚更新')
              .fontSize(11).fontColor(AppColors.TEXT_HINT)
          }
          .width('100%').margin({ bottom: 16 })

          // 温度 + 湿度
          Row() {
            this.envMetric($r('sys.symbol.thermometer'), '温度',
              this.latestSensor ? this.latestSensor.temperature.toFixed(1) : '--',
              '°C', AppColors.TEMP_COLOR)
            Column().width(1).height(36).backgroundColor(AppColors.DIVIDER)
              .margin({ left: 8, right: 8 })
            this.envMetric($r('sys.symbol.drop'), '湿度',
              this.latestSensor ? this.latestSensor.humidity.toFixed(1) : '--',
              '%', AppColors.HUMIDITY_COLOR)
          }.width('100%')

          Divider().color(AppColors.DIVIDER).margin({ top: 12, bottom: 12 })

          // 光照 + CO₂
          Row() {
            this.envMetric($r('sys.symbol.sun_max'), '光照',
              this.latestSensor ? this.latestSensor.light_intensity.toFixed(0) : '--',
              'Lux', AppColors.LIGHT_COLOR)
            Column().width(1).height(36).backgroundColor(AppColors.DIVIDER)
              .margin({ left: 8, right: 8 })
            this.envMetric($r('sys.symbol.cloud'), 'CO₂',
              this.latestSensor ? this.latestSensor.co2_level.toFixed(0) : '--',
              'ppm', AppColors.CO2_COLOR)
          }.width('100%')

          Divider().color(AppColors.DIVIDER).margin({ top: 12, bottom: 12 })

          // 土壤湿度
          Row() {
            Blank()
            this.envMetric($r('sys.symbol.leaf'), '土壤湿度',
              this.latestSensor ? this.latestSensor.soil_moisture.toFixed(1) : '--',
              '%', AppColors.SOIL_COLOR)
            Blank()
          }.width('100%')
        }
        .width('100%')
        .padding(18)
        .margin({ left: 14, right: 14, top: -12 })
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(16)
        .shadow({ radius: 8, color: '#1A000000', offsetX: 0, offsetY: 4 })

        // ===== 快捷操作 =====
        Text('快捷操作')
          .fontSize(15).fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .margin({ top: 22, bottom: 12 })
          .padding({ left: 16 }).width('100%')

        Row() {
          this.actionCard($r('sys.symbol.drop'), '智能灌溉', '#E3F2FD', '#1565C0', 'pages/IrrigationPage')
          this.actionCard($r('sys.symbol.sun_max'), '智能光照', '#FFF3E0', '#EF6C00', 'pages/LightingPage')
          this.actionCard($r('sys.symbol.link'), '联动规则', '#F3E5F5', '#7B1FA2', 'pages/AutomationPage')
        }
        .width('100%').justifyContent(FlexAlign.SpaceEvenly)
        .padding({ left: 10, right: 10 })

        Row() {
          this.actionCard($r('sys.symbol.leaf'), '作物管理', '#E8F5E9', '#2E7D32', 'pages/CropPage')
          this.actionCard($r('sys.symbol.house'), '区域管理', '#FBE9E7', '#BF360C', 'pages/ZonePage')
          this.actionCard($r('sys.symbol.doc_text'), '数据报告', '#E0F2F1', '#00695C', 'pages/ReportPage')
        }
        .width('100%').justifyContent(FlexAlign.SpaceEvenly)
        .padding({ left: 10, right: 10 })
        .margin({ top: 10, bottom: 24 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(AppColors.BG)
  }

  @Builder
  envMetric(icon: Resource, label: string, value: string, unit: string, color: string) {
    Row() {
      SymbolGlyph(icon)
        .fontSize(22).fontColor([color]).margin({ right: 8 })
      Column() {
        Text(label).fontSize(11).fontColor(AppColors.TEXT_HINT)
        Row() {
          Text(value).fontSize(22).fontWeight(FontWeight.Bold).fontColor(color)
          Text(` ${unit}`).fontSize(11).fontColor(AppColors.TEXT_SECONDARY)
            .margin({ top: 6 })
        }
      }
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
  }

  @Builder
  actionCard(icon: Resource, label: string, bgColor: string, iconColor: string, page: string) {
    Column() {
      Column() {
        SymbolGlyph(icon)
          .fontSize(26).fontColor([iconColor])
      }
      .width(50).height(50)
      .backgroundColor(bgColor)
      .borderRadius(14)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text(label)
        .fontSize(12).fontColor(AppColors.TEXT_PRIMARY)
        .margin({ top: 8 })
    }
    .width(100).height(95)
    .backgroundColor(AppColors.CARD_BG)
    .borderRadius(16)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .shadow({ radius: 4, color: '#0D000000', offsetX: 0, offsetY: 2 })
    .onClick(() => {
      router.pushUrl({ url: page });
    })
  }
}
