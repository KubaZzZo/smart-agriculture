// 智慧农业 - 区域管理页面
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
    } catch (e) {
      const z1: ZoneInfo = { id: 1, zone_name: '1号温室大棚', zone_type: 'greenhouse', description: '主要种植区',
        device_count: 3, is_active: 1, created_at: '' };
      const z2: ZoneInfo = { id: 2, zone_name: '露天试验田', zone_type: 'field', description: '露天种植试验区',
        device_count: 2, is_active: 1, created_at: '' };
      this.zones = [z1, z2];
    } finally {
      this.loading = false;
    }
  }

  async addZone(): Promise<void> {
    if (!this.newName) return;
    try {
      const body: ZoneCreateRequest = {
        zone_name: this.newName,
        zone_type: this.newType,
        description: this.newDesc
      };
      await ApiService.post<void>(ApiConstants.ZONE_LIST.replace('/list', ''), body);
      this.showAdd = false;
      this.newName = '';
      this.newDesc = '';
      this.loadData();
    } catch (e) { /* offline */ }
  }

  getTypeIcon(type: string): string {
    return type === 'greenhouse' ? '🏡' : '🌾';
  }

  getTypeLabel(type: string): string {
    return type === 'greenhouse' ? '温室大棚' : '露天田地';
  }

  build() {
    Column() {
      Row() {
        Text('< 返回').fontSize(15).fontColor(AppColors.PRIMARY)
          .onClick(() => { this.getUIContext().getRouter().back(); })
        Text('区域管理').fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY).margin({ left: 12 })
        Blank()
        Text('+ 新增').fontSize(14).fontColor(AppColors.PRIMARY)
          .onClick(() => { this.showAdd = !this.showAdd; })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      if (this.showAdd) {
        Column() {
          Text('新增区域').fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY).width('100%').margin({ bottom: 10 })
          TextInput({ placeholder: '区域名称', text: this.newName })
            .width('100%').height(40).fontSize(14).borderRadius(8)
            .backgroundColor('#F5F5F5').padding({ left: 12, right: 12 })
            .onChange((v: string) => { this.newName = v; })
          Row() {
            Text('类型:').fontSize(13).margin({ right: 8 })
            Select([{ value: 'greenhouse' }, { value: 'field' }])
              .selected(0).value(this.getTypeLabel(this.newType))
              .font({ size: 13 })
              .onSelect((idx: number, val: string) => { this.newType = val; })
          }.width('100%').margin({ top: 8 })
          TextInput({ placeholder: '描述（选填）', text: this.newDesc })
            .width('100%').height(40).fontSize(14).borderRadius(8)
            .backgroundColor('#F5F5F5').padding({ left: 12, right: 12 }).margin({ top: 8 })
            .onChange((v: string) => { this.newDesc = v; })
          Button('添加区域')
            .width('100%').height(36).borderRadius(18)
            .backgroundColor(AppColors.PRIMARY).fontColor('#FFFFFF').fontSize(14)
            .margin({ top: 12 })
            .onClick(() => { this.addZone(); })
        }
        .width('100%').padding(14).margin({ left: 12, right: 12, bottom: 8 })
        .backgroundColor('#E8F5E9').borderRadius(12)
      }

      List({ space: 10 }) {
        ForEach(this.zones, (zone: ZoneInfo) => {
          ListItem() {
            Row() {
              Text(this.getTypeIcon(zone.zone_type))
                .fontSize(36).margin({ right: 12 })
              Column() {
                Text(zone.zone_name)
                  .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppColors.TEXT_PRIMARY)
                Text(this.getTypeLabel(zone.zone_type))
                  .fontSize(12).fontColor(AppColors.TEXT_SECONDARY).margin({ top: 2 })
                if (zone.description) {
                  Text(zone.description)
                    .fontSize(12).fontColor(AppColors.TEXT_HINT).margin({ top: 2 })
                }
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Column() {
                Text(zone.device_count.toString())
                  .fontSize(20).fontWeight(FontWeight.Bold).fontColor(AppColors.PRIMARY)
                Text('设备').fontSize(11).fontColor(AppColors.TEXT_SECONDARY)
              }.alignItems(HorizontalAlign.Center)
            }
            .width('100%').padding(14)
            .backgroundColor(AppColors.CARD_BG).borderRadius(12)
            .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
          }
        })
      }
      .width('100%').layoutWeight(1).padding({ left: 12, right: 12 })
    }
    .width('100%').height('100%').backgroundColor(AppColors.BG)
  }
}
