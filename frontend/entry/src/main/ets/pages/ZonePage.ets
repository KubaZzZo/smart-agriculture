import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors } from '../common/Constants';
import { ZoneInfo, ZoneCreateRequest } from '../model/DataModels';

@Entry
@Component
struct ZonePage {
  @State zones: ZoneInfo[] = [];
  @State loading: boolean = true;
  @State showAdd: boolean = false;
  @State newName: string = '';
  @State newType: string = 'greenhouse';
  @State newDesc: string = '';

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.loading = true;
    try {
      this.zones = await ApiService.get<ZoneInfo[]>(ApiConstants.ZONE_LIST);
    } catch (_e) {
      const z1: ZoneInfo = {
        id: 1,
        zone_name: '1号温室大棚',
        zone_type: 'greenhouse',
        description: '主要种植区',
        device_count: 3,
        is_active: 1,
        created_at: '',
      };
      const z2: ZoneInfo = {
        id: 2,
        zone_name: '露天试验田',
        zone_type: 'field',
        description: '露天试验区域',
        device_count: 2,
        is_active: 1,
        created_at: '',
      };
      this.zones = [z1, z2];
    } finally {
      this.loading = false;
    }
  }

  async addZone(): Promise<void> {
    if (!this.newName) {
      return;
    }

    try {
      const body: ZoneCreateRequest = {
        zone_name: this.newName,
        zone_type: this.newType,
        description: this.newDesc,
      };
      await ApiService.post<void>(ApiConstants.ZONE_LIST, body);
      this.showAdd = false;
      this.newName = '';
      this.newDesc = '';
      this.loadData();
    } catch (_e) {
      // Ignore offline errors.
    }
  }

  typeLabel(type: string): string {
    return type === 'greenhouse' ? '温室' : '露天';
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

        Text('区域管理')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .margin({ left: 12 });

        Blank();

        Text(this.showAdd ? '取消' : '+ 新增')
          .fontSize(14)
          .fontColor(AppColors.PRIMARY)
          .onClick((): void => {
            this.showAdd = !this.showAdd;
          });
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 10 });

      if (this.showAdd) {
        Column() {
          Text('新增区域')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .width('100%');

          TextInput({ placeholder: '区域名称', text: this.newName })
            .width('100%')
            .height(42)
            .fontSize(14)
            .backgroundColor('#F3F7F4')
            .borderRadius(10)
            .padding({ left: 12, right: 12 })
            .margin({ top: 10 })
            .onChange((value: string): void => {
              this.newName = value;
            });

          Row() {
            Text('区域类型')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ right: 10 });

            Select([{ value: 'greenhouse' }, { value: 'field' }])
              .selected(this.newType === 'greenhouse' ? 0 : 1)
              .value(this.typeLabel(this.newType))
              .font({ size: 13 })
              .onSelect((index: number): void => {
                this.newType = index === 0 ? 'greenhouse' : 'field';
              });
          }
          .width('100%')
          .margin({ top: 10 });

          TextInput({ placeholder: '区域说明（可选）', text: this.newDesc })
            .width('100%')
            .height(42)
            .fontSize(14)
            .backgroundColor('#F3F7F4')
            .borderRadius(10)
            .padding({ left: 12, right: 12 })
            .margin({ top: 10 })
            .onChange((value: string): void => {
              this.newDesc = value;
            });

          Button('保存区域')
            .width('100%')
            .height(40)
            .borderRadius(20)
            .backgroundColor(AppColors.PRIMARY)
            .fontColor('#FFFFFF')
            .fontSize(14)
            .margin({ top: 12 })
            .onClick((): void => {
              this.addZone();
            });
        }
        .width('100%')
        .padding(14)
        .margin({ left: 12, right: 12, bottom: 10 })
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(14)
        .shadow({ radius: 6, color: '#12000000', offsetX: 0, offsetY: 3 });
      }

      if (!this.loading && this.zones.length === 0) {
        Column() {
          Text('暂无区域数据')
            .fontSize(14)
            .fontColor(AppColors.TEXT_HINT);
          Text('点击右上角新增区域')
            .fontSize(12)
            .fontColor(AppColors.TEXT_HINT)
            .margin({ top: 6 });
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else {
        List({ space: 10 }) {
          ForEach(this.zones, (zone: ZoneInfo) => {
            ListItem() {
              Row() {
                Column() {
                  Text(zone.zone_name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TEXT_PRIMARY);

                  Text(this.typeLabel(zone.zone_type))
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_SECONDARY)
                    .margin({ top: 2 });

                  if (zone.description) {
                    Text(zone.description)
                      .fontSize(12)
                      .fontColor(AppColors.TEXT_HINT)
                      .margin({ top: 2 })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis });
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1);

                Column() {
                  Text(zone.device_count.toString())
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppColors.PRIMARY);
                  Text('设备数')
                    .fontSize(11)
                    .fontColor(AppColors.TEXT_SECONDARY)
                    .margin({ top: 2 });
                }
                .alignItems(HorizontalAlign.Center);
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppColors.CARD_BG)
              .borderRadius(14)
              .shadow({ radius: 6, color: '#12000000', offsetX: 0, offsetY: 3 });
            }
          });
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12, bottom: 10 });
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG);
  }
}
