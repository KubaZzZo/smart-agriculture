// 智慧农业 - 智能光照页面
import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors } from '../common/Constants';
import { SensorData, DeviceInfo, ControlRequest, DeviceParamsUpdateRequest } from '../model/DataModels';

@Entry
@Component
struct LightingPage {
  @State lightIntensity: number = 0;
  @State ledStatus: number = 0;
  @State ledBrightness: number = 0;
  @State targetLight: number = 30000;
  @State loading: boolean = true;

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.loading = true;
    try {
      const sensor = await ApiService.get<SensorData>(ApiConstants.SENSOR_LATEST);
      this.lightIntensity = sensor.light_intensity;
      const devices = await ApiService.get<DeviceInfo[]>(ApiConstants.DEVICE_LIST);
      const led = devices.find(d => d.device_type === 'led');
      if (led) {
        this.ledStatus = led.status;
        this.ledBrightness = led.params?.brightness || 0;
      }
    } catch (e) {
      this.lightIntensity = 25000;
    } finally {
      this.loading = false;
    }
  }

  async toggleLed(isOn: boolean): Promise<void> {
    const status = isOn ? 1 : 0;
    const body: ControlRequest = { status: status };
    try { await ApiService.post<void>('/api/device/3/control', body); } catch (e) { /* offline */ }
    this.ledStatus = status;
  }

  async updateBrightness(): Promise<void> {
    try {
      const params: Record<string, number> = {};
      params['brightness'] = this.ledBrightness;
      const body: DeviceParamsUpdateRequest = { params: params };
      await ApiService.put<void>('/api/device/3/params', body);
    } catch (e) { /* offline */ }
  }

  getLightStatus(): string {
    if (this.lightIntensity < 5000) return '光照不足';
    if (this.lightIntensity < 20000) return '光照偏弱';
    if (this.lightIntensity <= 60000) return '光照适宜';
    return '光照过强';
  }

  getLightColor(): string {
    if (this.lightIntensity < 5000) return AppColors.WARN;
    if (this.lightIntensity < 20000) return AppColors.ACCENT;
    if (this.lightIntensity <= 60000) return AppColors.PRIMARY;
    return AppColors.WARN;
  }

  getLightPercent(): number {
    return Math.min(this.lightIntensity / 80000 * 100, 100);
  }

  build() {
    Column() {
      Row() {
        Text('< 返回').fontSize(15).fontColor(AppColors.PRIMARY)
          .onClick(() => { router.back(); })
        Text('智能光照').fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY).margin({ left: 12 })
        Blank()
        Text('🔄').fontSize(20).onClick(() => { this.loadData(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column() {
          // 光照强度卡片
          Column() {
            Text('当前光照强度').fontSize(14).fontColor(AppColors.TEXT_SECONDARY)
            Text(`${this.lightIntensity.toFixed(0)}`)
              .fontSize(42).fontWeight(FontWeight.Bold).fontColor(AppColors.LIGHT_COLOR)
              .margin({ top: 4 })
            Text('Lux').fontSize(14).fontColor(AppColors.TEXT_SECONDARY)
            Text(this.getLightStatus())
              .fontSize(14).fontColor(this.getLightColor()).margin({ top: 8 })
            Progress({ value: this.getLightPercent(), total: 100, type: ProgressType.Linear })
              .width('80%').margin({ top: 12 })
              .color(AppColors.LIGHT_COLOR)
          }
          .width('100%').padding(24).margin({ left: 12, right: 12 })
          .backgroundColor(AppColors.CARD_BG).borderRadius(12).alignItems(HorizontalAlign.Center)
          .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })

          // LED控制卡片
          Column() {
            Row() {
              Text('💡 LED补光灯').fontSize(16).fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_PRIMARY).layoutWeight(1)
              Text(this.ledStatus === 1 ? '已开启' : '已关闭')
                .fontSize(13).fontColor(this.ledStatus === 1 ? AppColors.PRIMARY : AppColors.TEXT_HINT)
                .margin({ right: 8 })
              Toggle({ type: ToggleType.Switch, isOn: this.ledStatus === 1 })
                .selectedColor(AppColors.PRIMARY)
                .onChange((isOn: boolean) => { this.toggleLed(isOn); })
            }.width('100%')

            // 亮度调节
            Column() {
              Row() {
                Text('亮度调节').fontSize(14).fontColor(AppColors.TEXT_SECONDARY)
                Blank()
                Text(`${this.ledBrightness.toFixed(0)}%`).fontSize(16)
                  .fontWeight(FontWeight.Bold).fontColor(AppColors.LIGHT_COLOR)
              }.width('100%').margin({ top: 16 })

              Slider({ value: this.ledBrightness, min: 0, max: 100, step: 5 })
                .blockColor(AppColors.LIGHT_COLOR)
                .trackColor('#E0E0E0')
                .selectedColor(AppColors.LIGHT_COLOR)
                .margin({ top: 8 })
                .onChange((value: number) => { this.ledBrightness = value; })

              // 快捷亮度按钮
              Row() {
                ForEach([25, 50, 75, 100], (val: number) => {
                  Button(`${val}%`)
                    .width(65).height(32).borderRadius(16)
                    .backgroundColor(this.ledBrightness === val ? AppColors.LIGHT_COLOR : '#F5F5F5')
                    .fontColor(this.ledBrightness === val ? '#FFFFFF' : AppColors.TEXT_SECONDARY)
                    .fontSize(13)
                    .onClick(() => { this.ledBrightness = val; })
                })
              }
              .width('100%').justifyContent(FlexAlign.SpaceEvenly).margin({ top: 10 })

              Button('应用亮度')
                .width('100%').height(40).borderRadius(20)
                .backgroundColor(AppColors.LIGHT_COLOR).fontColor('#FFFFFF').fontSize(14)
                .margin({ top: 14 })
                .onClick(() => { this.updateBrightness(); })
            }
          }
          .width('100%').padding(16).margin({ left: 12, right: 12, top: 12 })
          .backgroundColor(AppColors.CARD_BG).borderRadius(12)
          .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })

          // 光照建议
          Column() {
            Text('光照建议').fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY).width('100%')
            Row() {
              Text('目标光照').fontSize(13).fontColor(AppColors.TEXT_SECONDARY)
              Blank()
              Text(`${this.targetLight.toFixed(0)} Lux`).fontSize(13).fontColor(AppColors.PRIMARY)
            }.width('100%').margin({ top: 10 })
            Slider({ value: this.targetLight, min: 5000, max: 80000, step: 5000 })
              .blockColor(AppColors.PRIMARY).selectedColor(AppColors.PRIMARY)
              .onChange((v: number) => { this.targetLight = v; })

            if (this.lightIntensity < this.targetLight) {
              Text(`当前光照不足，建议开启补光灯，亮度设为 ${Math.min(Math.round((this.targetLight - this.lightIntensity) / 800), 100)}%`)
                .fontSize(13).fontColor(AppColors.ACCENT).margin({ top: 8 })
            } else {
              Text('当前光照充足，无需补光')
                .fontSize(13).fontColor(AppColors.PRIMARY).margin({ top: 8 })
            }
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
