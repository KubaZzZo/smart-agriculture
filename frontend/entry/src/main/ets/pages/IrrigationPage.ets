import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors } from '../common/Constants';
import { SensorData, DeviceInfo, ControlRequest, WaterTodayResponse } from '../model/DataModels';

@Entry
@Component
struct IrrigationPage {
  @State soilMoisture: number = 0;
  @State targetMoisture: number = 50;
  @State waterToday: number = 0;
  @State pumpStatus: number = 0;
  @State valveStatus: number = 0;
  @State pumpFlowRate: number = 2;
  @State irrigationAmount: number = 0;
  @State pumpId: number = 0;
  @State valveId: number = 0;

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      const sensor: SensorData = await ApiService.get<SensorData>(ApiConstants.SENSOR_LATEST);
      this.soilMoisture = sensor.soil_moisture;

      const devices: DeviceInfo[] = await ApiService.get<DeviceInfo[]>(ApiConstants.DEVICE_LIST);
      const pump: DeviceInfo | undefined = devices.find((item: DeviceInfo): boolean => item.device_type === 'pump');
      const valve: DeviceInfo | undefined = devices.find((item: DeviceInfo): boolean => item.device_type === 'valve');
      if (pump) {
        this.pumpId = pump.id;
        this.pumpStatus = pump.status;
        this.pumpFlowRate = pump.params?.flow_rate || 2;
      }
      if (valve) {
        this.valveId = valve.id;
        this.valveStatus = valve.status;
      }

      try {
        const water: WaterTodayResponse = await ApiService.get<WaterTodayResponse>(ApiConstants.WATER_TODAY);
        this.waterToday = water.total_liters;
      } catch (_e2) {
        this.waterToday = 12.5;
      }
    } catch (_e) {
      this.soilMoisture = 35.2;
      this.waterToday = 12.5;
    } finally {
      this.calculateIrrigation();
    }
  }

  calculateIrrigation(): void {
    if (this.soilMoisture < this.targetMoisture) {
      const deficit: number = this.targetMoisture - this.soilMoisture;
      this.irrigationAmount = Math.round(deficit * 0.5 * 10) / 10;
      return;
    }
    this.irrigationAmount = 0;
  }

  async controlPump(status: number): Promise<void> {
    if (this.pumpId <= 0) {
      return;
    }
    const body: ControlRequest = { status: status };
    try {
      await ApiService.post<void>(`${ApiConstants.DEVICE_CONTROL}/${this.pumpId}/control`, body);
    } catch (_e) {
      // Ignore offline errors.
    }
    this.pumpStatus = status;
  }

  async controlValve(status: number): Promise<void> {
    if (this.valveId <= 0) {
      return;
    }
    const body: ControlRequest = { status: status };
    try {
      await ApiService.post<void>(`${ApiConstants.DEVICE_CONTROL}/${this.valveId}/control`, body);
    } catch (_e) {
      // Ignore offline errors.
    }
    this.valveStatus = status;
  }

  moistureColor(): string {
    if (this.soilMoisture < 20) return AppColors.WARN;
    if (this.soilMoisture < 40) return AppColors.ACCENT;
    if (this.soilMoisture <= 70) return AppColors.PRIMARY;
    return AppColors.HUMIDITY_COLOR;
  }

  moistureStatus(): string {
    if (this.soilMoisture < 20) return '严重缺水';
    if (this.soilMoisture < 40) return '需要灌溉';
    if (this.soilMoisture <= 70) return '湿度适宜';
    return '湿度偏高';
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

        Text('智能灌溉')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .margin({ left: 12 });

        Blank();

        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(20)
          .fontColor([AppColors.TEXT_SECONDARY])
          .onClick((): void => {
            this.loadData();
          });
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 10 });

      Scroll() {
        Column() {
          Column() {
            Text('土壤湿度')
              .fontSize(14)
              .fontColor(AppColors.TEXT_SECONDARY);
            Text(`${this.soilMoisture.toFixed(1)}%`)
              .fontSize(40)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.moistureColor())
              .margin({ top: 4 });
            Text(this.moistureStatus())
              .fontSize(13)
              .fontColor(this.moistureColor())
              .margin({ top: 4 });
            Progress({ value: this.soilMoisture, total: 100, type: ProgressType.Linear })
              .width('80%')
              .color(this.moistureColor())
              .margin({ top: 10 });
          }
          .width('100%')
          .padding(18)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(14)
          .alignItems(HorizontalAlign.Center)
          .shadow({ radius: 6, color: '#12000000', offsetX: 0, offsetY: 3 })
          .margin({ left: 12, right: 12 });

          Column() {
            Text('灌溉建议')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width('100%');

            Row() {
              Text('目标湿度')
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY);
              Blank();
              Text(`${this.targetMoisture}%`)
                .fontSize(13)
                .fontColor(AppColors.PRIMARY);
            }
            .width('100%')
            .margin({ top: 10 });

            Slider({ value: this.targetMoisture, min: 20, max: 80, step: 5 })
              .blockColor(AppColors.PRIMARY)
              .selectedColor(AppColors.PRIMARY)
              .margin({ top: 8 })
              .onChange((value: number): void => {
                this.targetMoisture = value;
                this.calculateIrrigation();
              });

            Row() {
              Text('建议灌溉量')
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY);
              Blank();
              Text(`${this.irrigationAmount} L`)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.HUMIDITY_COLOR);
            }
            .width('100%')
            .margin({ top: 8 });
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(14)
          .shadow({ radius: 6, color: '#12000000', offsetX: 0, offsetY: 3 })
          .margin({ left: 12, right: 12, top: 12 });

          Column() {
            Text('设备控制')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width('100%');

            Row() {
              Text('水泵')
                .fontSize(15)
                .layoutWeight(1)
                .fontColor(AppColors.TEXT_PRIMARY);
              Text(this.pumpStatus === 1 ? '运行中' : '已关闭')
                .fontSize(12)
                .fontColor(this.pumpStatus === 1 ? AppColors.PRIMARY : AppColors.TEXT_HINT)
                .margin({ right: 8 });
              Toggle({ type: ToggleType.Switch, isOn: this.pumpStatus === 1 })
                .selectedColor(AppColors.PRIMARY)
                .onChange((isOn: boolean): void => {
                  this.controlPump(isOn ? 1 : 0);
                });
            }
            .width('100%')
            .margin({ top: 12 });

            Row() {
              Text('水阀')
                .fontSize(15)
                .layoutWeight(1)
                .fontColor(AppColors.TEXT_PRIMARY);
              Text(this.valveStatus === 1 ? '运行中' : '已关闭')
                .fontSize(12)
                .fontColor(this.valveStatus === 1 ? AppColors.PRIMARY : AppColors.TEXT_HINT)
                .margin({ right: 8 });
              Toggle({ type: ToggleType.Switch, isOn: this.valveStatus === 1 })
                .selectedColor(AppColors.PRIMARY)
                .onChange((isOn: boolean): void => {
                  this.controlValve(isOn ? 1 : 0);
                });
            }
            .width('100%')
            .margin({ top: 10 });
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(14)
          .shadow({ radius: 6, color: '#12000000', offsetX: 0, offsetY: 3 })
          .margin({ left: 12, right: 12, top: 12 });

          Row() {
            Column() {
              Text('今日用水')
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY);
              Text(`${this.waterToday.toFixed(1)} L`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.HUMIDITY_COLOR)
                .margin({ top: 4 });
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center);

            Column() {
              Text('瞬时流量')
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY);
              Text(`${this.pumpFlowRate} 升/分钟`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.PRIMARY)
                .margin({ top: 4 });
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center);
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(14)
          .shadow({ radius: 6, color: '#12000000', offsetX: 0, offsetY: 3 })
          .margin({ left: 12, right: 12, top: 12, bottom: 20 });
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG);
  }
}
