import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors } from '../common/Constants';
import { DeviceInfo, ControlRequest } from '../model/DataModels';

@Component
export struct DeviceView {
  @State devices: DeviceInfo[] = [];
  @State loading: boolean = true;
  @State errorMsg: string = '';

  aboutToAppear(): void {
    this.loadDevices();
  }

  async loadDevices(): Promise<void> {
    this.loading = true;
    this.errorMsg = '';
    try {
      this.devices = await ApiService.get<DeviceInfo[]>(ApiConstants.DEVICE_LIST);
    } catch (_e) {
      this.errorMsg = '加载设备列表失败';
      const pFlow1: Record<string, number> = { 'flow_rate': 0 };
      const pFlow2: Record<string, number> = { 'flow_rate': 0 };
      const pLed: Record<string, number> = { 'brightness': 0 };
      const pCam: Record<string, number> = {};
      const pFan: Record<string, number> = { 'speed': 0 };

      const d1: DeviceInfo = { id: 1, device_name: '水阀', device_type: 'valve', status: 0, params: pFlow1, created_at: '', updated_at: '' };
      const d2: DeviceInfo = { id: 2, device_name: '水泵', device_type: 'pump', status: 0, params: pFlow2, created_at: '', updated_at: '' };
      const d3: DeviceInfo = { id: 3, device_name: '补光灯', device_type: 'led', status: 0, params: pLed, created_at: '', updated_at: '' };
      const d4: DeviceInfo = { id: 4, device_name: '摄像头', device_type: 'camera', status: 1, params: pCam, created_at: '', updated_at: '' };
      const d5: DeviceInfo = { id: 5, device_name: '风机', device_type: 'fan', status: 0, params: pFan, created_at: '', updated_at: '' };

      this.devices = [d1, d2, d3, d4, d5];
    } finally {
      this.loading = false;
    }
  }

  async toggleDevice(device: DeviceInfo): Promise<void> {
    const newStatus: number = device.status === 1 ? 0 : 1;
    const body: ControlRequest = { status: newStatus };
    try {
      await ApiService.post<object>(`${ApiConstants.DEVICE_CONTROL}/${device.id}/control`, body);
    } catch (_e) {
      // Ignore offline errors.
    }

    const idx: number = this.devices.findIndex((d: DeviceInfo): boolean => d.id === device.id);
    if (idx >= 0) {
      const old: DeviceInfo = this.devices[idx];
      this.devices[idx] = {
        id: old.id,
        device_name: old.device_name,
        device_type: old.device_type,
        status: newStatus,
        params: old.params,
        created_at: old.created_at,
        updated_at: old.updated_at,
      };
      this.devices = this.devices.slice();
    }
  }

  getDeviceIcon(type: string): Resource {
    if (type === 'valve') return $r('sys.symbol.drop');
    if (type === 'pump') return $r('sys.symbol.drop');
    if (type === 'led') return $r('sys.symbol.sun_max');
    if (type === 'camera') return $r('sys.symbol.video');
    if (type === 'fan') return $r('sys.symbol.wind');
    return $r('sys.symbol.gearshape');
  }

  statusText(status: number): string {
    return status === 1 ? '运行中' : '已停止';
  }

  paramText(device: DeviceInfo): string {
    if (device.device_type === 'led') return `${device.params?.brightness || 0}%`;
    if (device.device_type === 'fan') return `${device.params?.speed || 0}%`;
    if (device.device_type === 'valve' || device.device_type === 'pump') return `${device.params?.flow_rate || 0} 升/分钟`;
    return '-';
  }

  build(): void {
    Column() {
      Row() {
        Column() {
          Text('设备列表')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY);
          Text('点击设备查看详细控制面板')
            .fontSize(11)
            .fontColor(AppColors.TEXT_HINT)
            .margin({ top: 2 });
        }
        .alignItems(HorizontalAlign.Start);

        Blank();

        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(22)
          .fontColor([AppColors.TEXT_SECONDARY])
          .padding(8)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(20)
          .onClick((): void => {
            this.loadDevices();
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

      List({ space: 10 }) {
        ForEach(this.devices, (device: DeviceInfo) => {
          ListItem() {
            Row() {
              Column() {
                SymbolGlyph(this.getDeviceIcon(device.device_type))
                  .fontSize(24)
                  .fontColor([AppColors.PRIMARY]);
              }
              .width(46)
              .height(46)
              .backgroundColor('#EAF6EE')
              .borderRadius(12)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .margin({ right: 12 });

              Column() {
                Text(device.device_name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.TEXT_PRIMARY);
                Row() {
                  Text(this.statusText(device.status))
                    .fontSize(12)
                    .fontColor(device.status === 1 ? AppColors.PRIMARY_LIGHT : AppColors.TEXT_HINT);
                  Text(`  ${this.paramText(device)}`)
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                    .margin({ left: 6 });
                }
                .margin({ top: 4 });
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1);

              Toggle({ type: ToggleType.Switch, isOn: device.status === 1 })
                .selectedColor(AppColors.PRIMARY)
                .onChange((_isOn: boolean): void => {
                  this.toggleDevice(device);
                });
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(14)
            .shadow({ radius: 6, color: '#14000000', offsetX: 0, offsetY: 3 })
            .onClick((): void => {
              router.pushUrl({
                url: 'pages/DeviceDetail',
                params: { deviceId: device.id, deviceName: device.device_name, deviceType: device.device_type },
              });
            });
          }
        });
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 12, right: 12 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG);
  }
}
