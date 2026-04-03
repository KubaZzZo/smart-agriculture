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
  @State ledId: number = 0;

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      const sensor: SensorData = await ApiService.get<SensorData>(ApiConstants.SENSOR_LATEST);
      this.lightIntensity = sensor.light_intensity;

      const devices: DeviceInfo[] = await ApiService.get<DeviceInfo[]>(ApiConstants.DEVICE_LIST);
      const led: DeviceInfo | undefined = devices.find((item: DeviceInfo): boolean => item.device_type === 'led');
      if (led) {
        this.ledId = led.id;
        this.ledStatus = led.status;
        this.ledBrightness = led.params?.brightness || 0;
      }
    } catch (_e) {
      this.lightIntensity = 25000;
    }
  }

  async toggleLed(isOn: boolean): Promise<void> {
    if (this.ledId <= 0) {
      return;
    }
    const status: number = isOn ? 1 : 0;
    const body: ControlRequest = { status: status };
    try {
      await ApiService.post<void>(`${ApiConstants.DEVICE_CONTROL}/${this.ledId}/control`, body);
    } catch (_e) {
      // Ignore offline errors.
    }
    this.ledStatus = status;
  }

  async updateBrightness(): Promise<void> {
    if (this.ledId <= 0) {
      return;
    }
    try {
      const params: Record<string, number> = {};
      params['brightness'] = this.ledBrightness;
      const body: DeviceParamsUpdateRequest = { params: params };
      await ApiService.put<void>(`${ApiConstants.DEVICE_PARAMS}/${this.ledId}/params`, body);
    } catch (_e) {
      // Ignore offline errors.
    }
  }

  lightStatus(): string {
    if (this.lightIntensity < 5000) return '光照不足';
    if (this.lightIntensity < 20000) return '光照偏弱';
    if (this.lightIntensity <= 60000) return '光照适宜';
    return '光照过强';
  }

  lightColor(): string {
    if (this.lightIntensity < 5000) return AppColors.WARN;
    if (this.lightIntensity < 20000) return AppColors.ACCENT;
    if (this.lightIntensity <= 60000) return AppColors.PRIMARY;
    return AppColors.WARN;
  }

  lightPercent(): number {
    return Math.min((this.lightIntensity / 80000) * 100, 100);
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

        Text('智能光照')
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
            Text('当前光照强度')
              .fontSize(14)
              .fontColor(AppColors.TEXT_SECONDARY);
            Text(this.lightIntensity.toFixed(0))
              .fontSize(40)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.LIGHT_COLOR)
              .margin({ top: 4 });
            Text('勒克斯')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY);
            Text(this.lightStatus())
              .fontSize(13)
              .fontColor(this.lightColor())
              .margin({ top: 4 });
            Progress({ value: this.lightPercent(), total: 100, type: ProgressType.Linear })
              .width('80%')
              .color(AppColors.LIGHT_COLOR)
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
            Row() {
              Text('补光灯控制')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_PRIMARY)
                .layoutWeight(1);

              Text(this.ledStatus === 1 ? '已开启' : '已关闭')
                .fontSize(12)
                .fontColor(this.ledStatus === 1 ? AppColors.PRIMARY : AppColors.TEXT_HINT)
                .margin({ right: 8 });

              Toggle({ type: ToggleType.Switch, isOn: this.ledStatus === 1 })
                .selectedColor(AppColors.PRIMARY)
                .onChange((isOn: boolean): void => {
                  this.toggleLed(isOn);
                });
            }
            .width('100%');

            Row() {
              Text('亮度')
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY);
              Blank();
              Text(`${this.ledBrightness.toFixed(0)}%`)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.LIGHT_COLOR);
            }
            .width('100%')
            .margin({ top: 14 });

            Slider({ value: this.ledBrightness, min: 0, max: 100, step: 5 })
              .blockColor(AppColors.LIGHT_COLOR)
              .selectedColor(AppColors.LIGHT_COLOR)
              .margin({ top: 8 })
              .onChange((value: number): void => {
                this.ledBrightness = value;
              });

            Row() {
              ForEach([25, 50, 75, 100], (item: number) => {
                Button(`${item}%`)
                  .width(65)
                  .height(32)
                  .borderRadius(16)
                  .backgroundColor(this.ledBrightness === item ? AppColors.LIGHT_COLOR : '#F3F7F4')
                  .fontColor(this.ledBrightness === item ? '#FFFFFF' : AppColors.TEXT_SECONDARY)
                  .fontSize(13)
                  .onClick((): void => {
                    this.ledBrightness = item;
                  });
              });
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceEvenly)
            .margin({ top: 10 });

            Button('应用亮度')
              .width('100%')
              .height(40)
              .borderRadius(20)
              .backgroundColor(AppColors.LIGHT_COLOR)
              .fontColor('#FFFFFF')
              .fontSize(14)
              .margin({ top: 12 })
              .onClick((): void => {
                this.updateBrightness();
              });
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(14)
          .shadow({ radius: 6, color: '#12000000', offsetX: 0, offsetY: 3 })
          .margin({ left: 12, right: 12, top: 12 });

          Column() {
            Text('光照建议')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .width('100%');

            Row() {
              Text('目标光照')
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY);
              Blank();
              Text(`${this.targetLight.toFixed(0)} 勒克斯`)
                .fontSize(13)
                .fontColor(AppColors.PRIMARY);
            }
            .width('100%')
            .margin({ top: 10 });

            Slider({ value: this.targetLight, min: 5000, max: 80000, step: 5000 })
              .blockColor(AppColors.PRIMARY)
              .selectedColor(AppColors.PRIMARY)
              .margin({ top: 8 })
              .onChange((value: number): void => {
                this.targetLight = value;
              });

            if (this.lightIntensity < this.targetLight) {
              Text(`当前光照不足，建议开启补光，参考亮度 ${Math.min(Math.round((this.targetLight - this.lightIntensity) / 800), 100)}%`)
                .fontSize(13)
                .fontColor(AppColors.ACCENT)
                .margin({ top: 8 });
            } else {
              Text('当前光照充足，无需额外补光')
                .fontSize(13)
                .fontColor(AppColors.PRIMARY)
                .margin({ top: 8 });
            }
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
