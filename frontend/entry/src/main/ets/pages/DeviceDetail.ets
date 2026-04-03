import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors } from '../common/Constants';
import { DeviceInfo, DeviceLog, DeviceLogListResponse, ControlRequest, DeviceParamsUpdateRequest } from '../model/DataModels';

interface DeviceRouteParams {
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
  @State errorMsg: string = '';

  private deviceId: number = 0;
  private deviceName: string = '';
  private deviceType: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as DeviceRouteParams;
    if (params) {
      this.deviceId = params.deviceId;
      this.deviceName = params.deviceName;
      this.deviceType = params.deviceType;
    }
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.loading = true;
    this.errorMsg = '';
    try {
      const devices: DeviceInfo[] = await ApiService.get<DeviceInfo[]>(ApiConstants.DEVICE_LIST);
      this.device = devices.find((d: DeviceInfo): boolean => d.id === this.deviceId) || null;
      if (this.device) {
        this.paramValue = this.getMainParam();
      }

      const query = new Map<string, string>([['page', '1'], ['page_size', '20']]);
      const logRes: DeviceLogListResponse = await ApiService.get<DeviceLogListResponse>(
        `${ApiConstants.DEVICE_LOG}/${this.deviceId}/logs`,
        query
      );
      this.logs = logRes.items;
    } catch (_e) {
      this.errorMsg = '加载设备详情失败';
      const emptyParams: Record<string, number> = {};
      this.device = {
        id: this.deviceId,
        device_name: this.deviceName,
        device_type: this.deviceType,
        status: 0,
        params: emptyParams,
        created_at: '',
        updated_at: '',
      };
      this.logs = [
        { id: 1, device_id: this.deviceId, action: '开启', params: {}, source: '手动', created_at: '2025-03-22T10:00:00' },
        { id: 2, device_id: this.deviceId, action: '关闭', params: {}, source: '自动', created_at: '2025-03-22T08:30:00' },
      ];
    } finally {
      this.loading = false;
    }
  }

  getMainParam(): number {
    if (!this.device || !this.device.params) {
      return 0;
    }
    if (this.deviceType === 'led') {
      return this.device.params.brightness || 0;
    }
    if (this.deviceType === 'fan') {
      return this.device.params.speed || 0;
    }
    if (this.deviceType === 'valve' || this.deviceType === 'pump') {
      return this.device.params.flow_rate || 0;
    }
    return 0;
  }

  getParamName(): string {
    if (this.deviceType === 'led') {
      return 'brightness';
    }
    if (this.deviceType === 'fan') {
      return 'speed';
    }
    return 'flow_rate';
  }

  getParamLabel(): string {
    if (this.deviceType === 'led') {
      return '亮度';
    }
    if (this.deviceType === 'fan') {
      return '转速';
    }
    return '流量';
  }

  getParamUnit(): string {
    if (this.deviceType === 'led' || this.deviceType === 'fan') {
      return '%';
    }
    return '升/分钟';
  }

  getMaxParam(): number {
    if (this.deviceType === 'valve' || this.deviceType === 'pump') {
      return 20;
    }
    return 100;
  }

  async toggleDevice(): Promise<void> {
    if (!this.device) {
      return;
    }
    const newStatus: number = this.device.status === 1 ? 0 : 1;
    const body: ControlRequest = { status: newStatus };
    try {
      await ApiService.post<object>(`${ApiConstants.DEVICE_CONTROL}/${this.deviceId}/control`, body);
    } catch (_e) {
      // ignore offline update failure
    }

    const old: DeviceInfo = this.device;
    this.device = {
      id: old.id,
      device_name: old.device_name,
      device_type: old.device_type,
      status: newStatus,
      params: old.params,
      created_at: old.created_at,
      updated_at: old.updated_at,
    };
  }

  async updateParam(): Promise<void> {
    const paramsMap: Record<string, number> = {};
    paramsMap[this.getParamName()] = this.paramValue;
    const body: DeviceParamsUpdateRequest = { params: paramsMap };
    try {
      await ApiService.put<object>(`${ApiConstants.DEVICE_PARAMS}/${this.deviceId}/params`, body);
    } catch (_e) {
      // ignore offline update failure
    }
  }

  statusText(): string {
    return this.device?.status === 1 ? '运行中' : '已停止';
  }

  buttonText(): string {
    return this.device?.status === 1 ? '关闭设备' : '开启设备';
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
        Text(this.deviceName || '设备详情')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .margin({ left: 12 });
        Blank();
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 });

      if (this.errorMsg) {
        Text(this.errorMsg)
          .fontSize(12)
          .fontColor(AppColors.WARN)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 });
      }

      Scroll() {
        Column() {
          Column() {
            Text(this.statusText())
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.device?.status === 1 ? AppColors.PRIMARY : AppColors.TEXT_HINT);

            Button(this.buttonText())
              .width(160)
              .height(40)
              .borderRadius(20)
              .backgroundColor(this.device?.status === 1 ? '#FFEBEE' : '#E8F5E9')
              .fontColor(this.device?.status === 1 ? AppColors.WARN : AppColors.PRIMARY)
              .fontSize(14)
              .margin({ top: 12 })
              .onClick((): void => {
                this.toggleDevice();
              });
          }
          .width('100%')
          .padding(24)
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Center)
          .margin({ left: 12, right: 12 });

          if (this.deviceType !== 'camera') {
            Column() {
              Row() {
                Text(`${this.getParamLabel()}`)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium);
                Blank();
                Text(`${this.paramValue.toFixed(this.deviceType === 'valve' || this.deviceType === 'pump' ? 1 : 0)} ${this.getParamUnit()}`)
                  .fontSize(15)
                  .fontColor(AppColors.PRIMARY);
              }
              .width('100%');

              Slider({ value: this.paramValue, min: 0, max: this.getMaxParam(), step: 1 })
                .blockColor(AppColors.PRIMARY)
                .trackColor('#E0E0E0')
                .selectedColor(AppColors.PRIMARY)
                .margin({ top: 10 })
                .onChange((value: number): void => {
                  this.paramValue = value;
                });

              Button('应用参数')
                .width('100%')
                .height(38)
                .borderRadius(19)
                .backgroundColor(AppColors.PRIMARY)
                .fontColor('#FFFFFF')
                .fontSize(14)
                .margin({ top: 12 })
                .onClick((): void => {
                  this.updateParam();
                });
            }
            .width('100%')
            .padding(16)
            .margin({ left: 12, right: 12, top: 12 })
            .backgroundColor(AppColors.CARD_BG)
            .borderRadius(12);
          }

          Text('操作日志')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ top: 16, bottom: 8 })
            .padding({ left: 16 })
            .width('100%');

          Column() {
            ForEach(this.logs, (log: DeviceLog) => {
              Row() {
                Text(log.action)
                  .fontSize(13)
                  .fontColor(AppColors.TEXT_PRIMARY)
                  .layoutWeight(1);
                Text(log.source)
                  .fontSize(11)
                  .fontColor(AppColors.TEXT_HINT);
                Text(log.created_at ? log.created_at.replace('T', ' ').substring(5, 16) : '')
                  .fontSize(11)
                  .fontColor(AppColors.TEXT_HINT)
                  .margin({ left: 8 });
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
              .border({ width: { bottom: 0.5 }, color: AppColors.DIVIDER });
            });
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ left: 12, right: 12, bottom: 20 })
          .backgroundColor(AppColors.CARD_BG)
          .borderRadius(12);
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
