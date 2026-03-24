// 智慧农业 - 智能灌溉页面
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
  @State autoIrrigation: boolean = true;
  @State irrigationAmount: number = 0;
  @State loading: boolean = true;

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.loading = true;
    try {
      const sensor = await ApiService.get<SensorData>(ApiConstants.SENSOR_LATEST);
      this.soilMoisture = sensor.soil_moisture;
      const devices = await ApiService.get<DeviceInfo[]>(ApiConstants.DEVICE_LIST);
      const pump = devices.find(d => d.device_type === 'pump');
      const valve = devices.find(d => d.device_type === 'valve');
      if (pump) { this.pumpStatus = pump.status; this.pumpFlowRate = pump.params?.flow_rate || 2; }
      if (valve) { this.valveStatus = valve.status; }
      try {
        const water = await ApiService.get<WaterTodayResponse>(ApiConstants.WATER_TODAY);
        this.waterToday = water.total_liters;
      } catch (e) { this.waterToday = 12.5; }
    } catch (e) {
      this.soilMoisture = 35.2;
      this.waterToday = 12.5;
    } finally {
      this.loading = false;
      this.calculateIrrigation();
    }
  }

  calculateIrrigation(): void {
    if (this.soilMoisture < this.targetMoisture) {
      const deficit = this.targetMoisture - this.soilMoisture;
      this.irrigationAmount = Math.round(deficit * 0.5 * 10) / 10;
    } else {
      this.irrigationAmount = 0;
    }
  }

  async controlPump(status: number): Promise<void> {
    const body: ControlRequest = { status: status };
    try { await ApiService.post<void>('/api/device/2/control', body); } catch (e) { /* offline */ }
    this.pumpStatus = status;
  }

  async controlValve(status: number): Promise<void> {
    const body: ControlRequest = { status: status };
    try { await ApiService.post<void>('/api/device/1/control', body); } catch (e) { /* offline */ }
    this.valveStatus = status;
  }

  getMoistureColor(): string {
    if (this.soilMoisture < 20) return AppColors.WARN;
    if (this.soilMoisture < 40) return AppColors.ACCENT;
    if (this.soilMoisture <= 70) return AppColors.PRIMARY;
    return AppColors.HUMIDITY_COLOR;
  }

  getMoistureStatus(): string {
    if (this.soilMoisture < 20) return '严重缺水';
    if (this.soilMoisture < 40) return '需要灌溉';
    if (this.soilMoisture <= 70) return '湿度适宜';
    return '湿度偏高';
  }

  build() {
    Column() {
      Row() {
        Text('< 返回').fontSize(15).fontColor(AppColors.PRIMARY)
          .onClick(() => { router.back(); })
        Text('智能灌溉').fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY).margin({ left: 12 })
        Blank()
        Text('🔄').fontSize(20).onClick(() => { this.loadData(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column() {
          // 土壤湿度卡片
          Column() {
            Text('土壤湿度').fontSize(14).fontColor(AppColors.TEXT_SECONDARY)
            Text(`${this.soilMoisture.toFixed(1)}%`)
              .fontSize(42).fontWeight(FontWeight.Bold).fontColor(this.getMoistureColor())
              .margin({ top: 4 })
            Text(this.getMoistureStatus())
              .fontSize(14).fontColor(this.getMoistureColor()).margin({ top: 4 })
            // 进度条
            Progress({ value: this.soilMoisture, total: 100, type: ProgressType.Linear })
              .width('80%').margin({ top: 12 })
              .color(this.getMoistureColor())
          }
          .width('100%').padding(20).margin({ left: 12, right: 12 })
          .backgroundColor(AppColors.CARD_BG).borderRadius(12).alignItems(HorizontalAlign.Center)
          .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })

          // 灌溉计算
          Column() {
            Text('灌溉建议').fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY).width('100%')
            Row() {
              Text('目标湿度').fontSize(13).fontColor(AppColors.TEXT_SECONDARY)
              Blank()
              Text(`${this.targetMoisture}%`).fontSize(13).fontColor(AppColors.PRIMARY)
            }.width('100%').margin({ top: 10 })
            Slider({ value: this.targetMoisture, min: 20, max: 80, step: 5 })
              .blockColor(AppColors.PRIMARY).selectedColor(AppColors.PRIMARY)
              .onChange((v: number) => { this.targetMoisture = v; this.calculateIrrigation(); })
            Row() {
              Text('建议灌溉量').fontSize(13).fontColor(AppColors.TEXT_SECONDARY)
              Blank()
              Text(`${this.irrigationAmount} L`).fontSize(16)
                .fontWeight(FontWeight.Bold).fontColor(AppColors.HUMIDITY_COLOR)
            }.width('100%').margin({ top: 6 })
          }
          .width('100%').padding(16).margin({ left: 12, right: 12, top: 12 })
          .backgroundColor(AppColors.CARD_BG).borderRadius(12)
          .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })

          // 设备控制
          Column() {
            Text('灌溉控制').fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY).width('100%')
            Row() {
              Text('💧 水泵').fontSize(15).layoutWeight(1)
              Text(this.pumpStatus === 1 ? '运行中' : '已关闭')
                .fontSize(12).fontColor(this.pumpStatus === 1 ? AppColors.PRIMARY : AppColors.TEXT_HINT)
                .margin({ right: 8 })
              Toggle({ type: ToggleType.Switch, isOn: this.pumpStatus === 1 })
                .selectedColor(AppColors.PRIMARY)
                .onChange((isOn: boolean) => { this.controlPump(isOn ? 1 : 0); })
            }.width('100%').margin({ top: 12 })
            Row() {
              Text('🚰 水阀').fontSize(15).layoutWeight(1)
              Text(this.valveStatus === 1 ? '运行中' : '已关闭')
                .fontSize(12).fontColor(this.valveStatus === 1 ? AppColors.PRIMARY : AppColors.TEXT_HINT)
                .margin({ right: 8 })
              Toggle({ type: ToggleType.Switch, isOn: this.valveStatus === 1 })
                .selectedColor(AppColors.PRIMARY)
                .onChange((isOn: boolean) => { this.controlValve(isOn ? 1 : 0); })
            }.width('100%').margin({ top: 10 })
          }
          .width('100%').padding(16).margin({ left: 12, right: 12, top: 12 })
          .backgroundColor(AppColors.CARD_BG).borderRadius(12)
          .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })

          // 今日用水
          Row() {
            Column() {
              Text('今日用水').fontSize(12).fontColor(AppColors.TEXT_SECONDARY)
              Text(`${this.waterToday.toFixed(1)} L`).fontSize(20)
                .fontWeight(FontWeight.Bold).fontColor(AppColors.HUMIDITY_COLOR).margin({ top: 4 })
            }.layoutWeight(1).alignItems(HorizontalAlign.Center)
            Column() {
              Text('流量').fontSize(12).fontColor(AppColors.TEXT_SECONDARY)
              Text(`${this.pumpFlowRate} L/min`).fontSize(20)
                .fontWeight(FontWeight.Bold).fontColor(AppColors.PRIMARY).margin({ top: 4 })
            }.layoutWeight(1).alignItems(HorizontalAlign.Center)
          }
          .width('100%').padding(16).margin({ left: 12, right: 12, top: 12, bottom: 20 })
          .backgroundColor(AppColors.CARD_BG).borderRadius(12)
          .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
        }
      }
      .layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor(AppColors.BG)
  }
}
