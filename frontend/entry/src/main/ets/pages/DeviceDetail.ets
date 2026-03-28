// 智慧农业 - 设备详情页
import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors } from '../common/Constants';
import { DeviceInfo, DeviceLog, DeviceLogListResponse, ControlRequest, DeviceParamsUpdateRequest } from '../model/DataModels';

interface DeviceParams {
  deviceId: number;
  deviceName: string;
  deviceType: string;
}

@Entry
@Component
struct DeviceDetail {
  @State device: DeviceInfo | null = null;
  @State logs: DeviceLog[] = [];
  @State loading: boolean = true;
  @State paramValue: number = 0;
  private deviceId: number = 0;
  private deviceName: string = '';
  private deviceType: string = '';

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as DeviceParams;
    if (params) {
      this.deviceId = params.deviceId;
      this.deviceName = params.deviceName;
      this.deviceType = params.deviceType;
    }
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.loading = true;
    try {
      const devices = await ApiService.get<DeviceInfo[]>(ApiConstants.DEVICE_LIST);
      this.device = devices.find((d: DeviceInfo) => d.id === this.deviceId) || null;
      if (this.device) {
        this.paramValue = this.getMainParam();
      }
      const logRes = await ApiService.get<DeviceLogListResponse>(ApiConstants.DEVICE_LOG,
        { 'device_id': this.deviceId.toString(), 'page': '1', 'page_size': '20' });
      this.logs = logRes.items;
    } catch (e) {
      const ep: Record<string, number> = {};
      const mockDevice: DeviceInfo = {
        id: this.deviceId, device_name: this.deviceName, device_type: this.deviceType,
        status: 0, params: ep, created_at: '', updated_at: ''
      };
      this.device = mockDevice;
      const p1: Record<string, number> = {};
      const p2: Record<string, number> = {};
      const p3: Record<string, number> = {};
      const log1: DeviceLog = { id: 1, device_id: this.deviceId, action: 'on',
        params: p1, source: 'manual', created_at: '2025-03-22T10:00:00' };
      const log2: DeviceLog = { id: 2, device_id: this.deviceId, action: 'off',
        params: p2, source: 'auto', created_at: '2025-03-22T08:30:00' };
      const log3: DeviceLog = { id: 3, device_id: this.deviceId, action: 'on',
        params: p3, source: 'auto', created_at: '2025-03-21T16:45:00' };
      this.logs = [log1, log2, log3];
    } finally {
      this.loading = false;
    }
  }

  getMainParam(): number {
    if (!this.device || !this.device.params) return 0;
    if (this.deviceType === 'led') return this.device.params.brightness || 0;
    if (this.deviceType === 'fan') return this.device.params.speed || 0;
    if (this.deviceType === 'valve' || this.deviceType === 'pump') return this.device.params.flow_rate || 0;
    return 0;
  }

  getParamName(): string {
    if (this.deviceType === 'led') return 'brightness';
    if (this.deviceType === 'fan') return 'speed';
    return 'flow_rate';
  }

  getParamLabel(): string {
    if (this.deviceType === 'led') return '亮度';
    if (this.deviceType === 'fan') return '转速';
    return '流量';
  }

  getParamUnit(): string {
    if (this.deviceType === 'led' || this.deviceType === 'fan') return '%';
    return 'L/min';
  }

  getMaxParam(): number {
    if (this.deviceType === 'valve' || this.deviceType === 'pump') return 20;
    return 100;
  }

  async toggleDevice(): Promise<void> {
    if (!this.device) return;
    const newStatus = this.device.status === 1 ? 0 : 1;
    try {
      const body: ControlRequest = { status: newStatus };
      await ApiService.post<object>(`${ApiConstants.DEVICE_CONTROL}/${this.deviceId}/control`, body);
    } catch (e) { /* offline */ }
    const old: DeviceInfo = this.device;
    this.device = {
      id: old.id, device_name: old.device_name, device_type: old.device_type,
      status: newStatus, params: old.params, created_at: old.created_at, updated_at: old.updated_at
    } as DeviceInfo;
  }

  async updateParam(): Promise<void> {
    const paramName = this.getParamName();
    const paramsMap: Record<string, number> = {};
    paramsMap[paramName] = this.paramValue;
    try {
      const body: DeviceParamsUpdateRequest = { params: paramsMap };
      await ApiService.put<object>(`${ApiConstants.DEVICE_PARAMS}/${this.deviceId}/params`, body);
    } catch (e) { /* offline */ }
  }

  getDeviceIcon(): string {
    const icons: Record<string, string> = {
      'valve': '🚰', 'pump': '💧', 'led': '💡', 'camera': '📷', 'fan': '🌀'
    };
    return icons[this.deviceType] || '⚙';
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('< 返回')
          .fontSize(15)
          .fontColor(AppColors.PRIMARY)
          .onClick(() => { this.getUIContext().getRouter().back(); })
        Text(this.deviceName)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .margin({ left: 12 })
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column() {
          // 设备状态卡片
          Column() {
            Text(this.getDeviceIcon()).fontSize(48)
            Text(this.device?.status === 1 ? '运行中' : '已关闭')
              .fontSize(16)
              .fontColor(this.device?.status === 1 ? AppColors.PRIMARY : AppColors.TEXT_HINT)
              .margin({ top: 8 })
            Button(this.device?.status === 1 ? '关闭设备' : '开启设备')
              .width(140)
              .height(40)
              .borderRadius(20)
              .backgroundColor(this.device?.status === 1 ? '#FFEBEE' : '#E8F5E9')
              .fontColor(this.device?.status === 1 ? AppColors.WARN : AppColors.PRIMARY)
              .fontSize(14)
              .margin({ top: 14 })
              .onClick(() => { this.toggleDevice(); })
          }
          .width('100%')
          .padding(24)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Center)
          .margin({ left: 12, right: 12 })
          .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })

          // 参数调节（非摄像头）
          if (this.deviceType !== 'camera') {
            Column() {
              Row() {
                Text(`${this.getParamLabel()}调节`)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                Blank()
                Text(`${this.paramValue.toFixed(this.deviceType === 'led' || this.deviceType === 'fan' ? 0 : 1)} ${this.getParamUnit()}`)
                  .fontSize(15)
                  .fontColor(AppColors.PRIMARY)
              }.width('100%')

              Slider({ value: this.paramValue, min: 0, max: this.getMaxParam(), step: 1 })
                .blockColor(AppColors.PRIMARY)
                .trackColor('#E0E0E0')
                .selectedColor(AppColors.PRIMARY)
                .margin({ top: 10 })
                .onChange((value: number) => { this.paramValue = value; })

              Button('应用参数')
                .width('100%')
                .height(38)
                .borderRadius(19)
                .backgroundColor(AppColors.PRIMARY)
                .fontColor('#FFFFFF')
                .fontSize(14)
                .margin({ top: 12 })
                .onClick(() => { this.updateParam(); })
            }
            .width('100%')
            .padding(16)
            .margin({ left: 12, right: 12, top: 12 })
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(12)
            .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
          }

          // 操作日志
          Text('操作记录')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ top: 16, bottom: 8 })
            .padding({ left: 16 })
            .width('100%')

          Column() {
            ForEach(this.logs, (log: DeviceLog) => {
              Row() {
                Text(log.action === 'on' ? '🟢' : (log.action === 'off' ? '🔴' : '🔧'))
                  .fontSize(14).margin({ right: 8 })
                Text(log.action === 'on' ? '开启' : (log.action === 'off' ? '关闭' : '参数调整'))
                  .fontSize(13).fontColor(AppColors.TEXT_PRIMARY).layoutWeight(1)
                Text(log.source === 'manual' ? '手动' : '自动')
                  .fontSize(11).fontColor(AppColors.TEXT_HINT)
                Text(log.created_at ? log.created_at.replace('T', ' ').substring(5, 16) : '')
                  .fontSize(11).fontColor(AppColors.TEXT_HINT).margin({ left: 8 })
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
              .border({ width: { bottom: 0.5 }, color: AppColors.DIVIDER })
            })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ left: 12, right: 12, bottom: 20 })
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(12)
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG)
  }
}
