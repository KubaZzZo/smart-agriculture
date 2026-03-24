// 智慧农业 - 设备控制视图
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors, DeviceTypes } from '../common/Constants';
import { DeviceInfo, ControlRequest } from '../model/DataModels';
import { router } from '@kit.ArkUI';

@Component
export struct DeviceView {
  @State devices: DeviceInfo[] = [];
  @State loading: boolean = true;

  aboutToAppear(): void {
    this.loadDevices();
  }

  async loadDevices(): Promise<void> {
    this.loading = true;
    try {
      this.devices = await ApiService.get<DeviceInfo[]>(ApiConstants.DEVICE_LIST);
    } catch (e) {
      const fp: Record<string, number> = { 'flow_rate': 0 };
      const fp2: Record<string, number> = { 'flow_rate': 0 };
      const bp: Record<string, number> = { 'brightness': 0 };
      const ep: Record<string, number> = {};
      const sp: Record<string, number> = { 'speed': 0 };
      const d1: DeviceInfo = { id: 1, device_name: '水阀', device_type: 'valve', status: 0, params: fp, created_at: '', updated_at: '' };
      const d2: DeviceInfo = { id: 2, device_name: '水泵', device_type: 'pump', status: 0, params: fp2, created_at: '', updated_at: '' };
      const d3: DeviceInfo = { id: 3, device_name: 'LED补光灯', device_type: 'led', status: 0, params: bp, created_at: '', updated_at: '' };
      const d4: DeviceInfo = { id: 4, device_name: '监控摄像头', device_type: 'camera', status: 1, params: ep, created_at: '', updated_at: '' };
      const d5: DeviceInfo = { id: 5, device_name: '通风风扇', device_type: 'fan', status: 0, params: sp, created_at: '', updated_at: '' };
      this.devices = [d1, d2, d3, d4, d5];
    } finally {
      this.loading = false;
    }
  }

  async toggleDevice(device: DeviceInfo): Promise<void> {
    const newStatus = device.status === 1 ? 0 : 1;
    try {
      const body: ControlRequest = { status: newStatus };
      await ApiService.post<object>(`${ApiConstants.DEVICE_CONTROL}/${device.id}/control`, body);
    } catch (e) { /* offline mode */ }
    const idx = this.devices.findIndex((d: DeviceInfo) => d.id === device.id);
    if (idx >= 0) {
      const old: DeviceInfo = this.devices[idx];
      const updated: DeviceInfo = {
        id: old.id, device_name: old.device_name, device_type: old.device_type,
        status: newStatus, params: old.params, created_at: old.created_at, updated_at: old.updated_at
      };
      this.devices[idx] = updated;
      this.devices = this.devices.slice();
    }
  }

  getDeviceIcon(type: string): string {
    const icons: Record<string, string> = {
      'valve': '🚰', 'pump': '💧', 'led': '💡', 'camera': '📷', 'fan': '🌀'
    };
    return icons[type] || '⚙';
  }

  getParamLabel(type: string): string {
    const labels: Record<string, string> = {
      'valve': '流量', 'pump': '流量', 'led': '亮度', 'fan': '转速'
    };
    return labels[type] || '';
  }

  getParamValue(device: DeviceInfo): string {
    if (device.device_type === 'led') return `${device.params?.brightness || 0}%`;
    if (device.device_type === 'fan') return `${device.params?.speed || 0}%`;
    if (device.device_type === 'valve' || device.device_type === 'pump')
      return `${device.params?.flow_rate || 0} L/min`;
    return '';
  }

  build() {
    Column() {
      Row() {
        Text('设备控制')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
        Blank()
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(22)
          .fontColor([AppColors.TEXT_SECONDARY])
          .padding(8)
          .onClick(() => { this.loadDevices(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      List({ space: 10 }) {
        ForEach(this.devices, (device: DeviceInfo) => {
          ListItem() {
            Row() {
              Text(this.getDeviceIcon(device.device_type))
                .fontSize(32)
                .margin({ right: 12 })

              Column() {
                Text(device.device_name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.TEXT_PRIMARY)
                Row() {
                  Text(device.status === 1 ? '运行中' : '已关闭')
                    .fontSize(12)
                    .fontColor(device.status === 1 ? AppColors.PRIMARY_LIGHT : AppColors.TEXT_HINT)
                  if (this.getParamLabel(device.device_type) && device.status === 1) {
                    Text(` · ${this.getParamLabel(device.device_type)}: ${this.getParamValue(device)}`)
                      .fontSize(12)
                      .fontColor(AppColors.TEXT_SECONDARY)
                  }
                }
                .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: device.status === 1 })
                .selectedColor(AppColors.PRIMARY)
                .onChange((isOn: boolean) => { this.toggleDevice(device); })
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(12)
            .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/DeviceDetail',
                params: { deviceId: device.id, deviceName: device.device_name, deviceType: device.device_type }
              });
            })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 12, right: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG)
  }
}
