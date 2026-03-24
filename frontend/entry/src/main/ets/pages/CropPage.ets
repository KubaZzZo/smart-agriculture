// 智慧农业 - 作物管理页面
import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors } from '../common/Constants';
import { CropInfo, CropCreateRequest } from '../model/DataModels';

@Entry
@Component
struct CropPage {
  @State crops: CropInfo[] = [];
  @State loading: boolean = true;
  @State showAdd: boolean = false;
  @State newName: string = '';
  @State newVariety: string = '';

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.loading = true;
    try {
      this.crops = await ApiService.get<CropInfo[]>(ApiConstants.CROP_LIST);
    } catch (e) {
      const c1: CropInfo = {
        id: 1, crop_name: '番茄', variety: '圣女果', plant_date: '2025-03-01',
        growth_stage: 'growing', zone_id: 1, target_temperature: 25, target_humidity: 65,
        target_soil_moisture: 55, target_light: 35000, notes: '长势良好，注意通风防病',
        created_at: '', updated_at: ''
      };
      const c2: CropInfo = {
        id: 2, crop_name: '黄瓜', variety: '水果黄瓜', plant_date: '2025-02-20',
        growth_stage: 'flowering', zone_id: 1, target_temperature: 28, target_humidity: 70,
        target_soil_moisture: 60, target_light: 40000, notes: '已进入开花期，需增加灌溉',
        created_at: '', updated_at: ''
      };
      const c3: CropInfo = {
        id: 3, crop_name: '生菜', variety: '罗马生菜', plant_date: '2025-03-10',
        growth_stage: 'seedling', zone_id: 2, target_temperature: 20, target_humidity: 60,
        target_soil_moisture: 50, target_light: 25000, notes: '幼苗期，控制温度',
        created_at: '', updated_at: ''
      };
      const c4: CropInfo = {
        id: 4, crop_name: '草莓', variety: '红颜', plant_date: '2025-01-15',
        growth_stage: 'fruiting', zone_id: 1, target_temperature: 22, target_humidity: 55,
        target_soil_moisture: 45, target_light: 30000, notes: '结果期，注意采摘',
        created_at: '', updated_at: ''
      };
      this.crops = [c1, c2, c3, c4];
    } finally {
      this.loading = false;
    }
  }

  async addCrop(): Promise<void> {
    if (!this.newName) return;
    try {
      const body: CropCreateRequest = {
        crop_name: this.newName,
        variety: this.newVariety,
        plant_date: new Date().toISOString()
      };
      await ApiService.post<void>(ApiConstants.CROP_LIST.replace('/list', ''), body);
      this.showAdd = false;
      this.newName = '';
      this.newVariety = '';
      this.loadData();
    } catch (e) { /* offline */ }
  }

  getStageLabel(stage: string): string {
    const map: Record<string, string> = {
      'seedling': '幼苗期', 'growing': '生长期', 'flowering': '开花期',
      'fruiting': '结果期', 'harvest': '收获期'
    };
    return map[stage] || stage;
  }

  getStageColor(stage: string): string {
    const map: Record<string, string> = {
      'seedling': '#8BC34A', 'growing': '#4CAF50', 'flowering': '#FF9800',
      'fruiting': '#F44336', 'harvest': '#9C27B0'
    };
    return map[stage] || AppColors.PRIMARY;
  }

  build() {
    Column() {
      Row() {
        Text('< 返回').fontSize(15).fontColor(AppColors.PRIMARY)
          .onClick(() => { router.back(); })
        Text('作物管理').fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY).margin({ left: 12 })
        Blank()
        Text('+ 新增').fontSize(14).fontColor(AppColors.PRIMARY)
          .onClick(() => { this.showAdd = !this.showAdd; })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      if (this.showAdd) {
        Column() {
          Text('新增作物').fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY).width('100%').margin({ bottom: 10 })
          TextInput({ placeholder: '作物名称', text: this.newName })
            .width('100%').height(40).fontSize(14).borderRadius(8)
            .backgroundColor('#F5F5F5').padding({ left: 12, right: 12 })
            .onChange((v: string) => { this.newName = v; })
          TextInput({ placeholder: '品种（选填）', text: this.newVariety })
            .width('100%').height(40).fontSize(14).borderRadius(8)
            .backgroundColor('#F5F5F5').padding({ left: 12, right: 12 }).margin({ top: 8 })
            .onChange((v: string) => { this.newVariety = v; })
          Button('添加作物')
            .width('100%').height(36).borderRadius(18)
            .backgroundColor(AppColors.PRIMARY).fontColor('#FFFFFF').fontSize(14)
            .margin({ top: 12 })
            .onClick(() => { this.addCrop(); })
        }
        .width('100%').padding(14).margin({ left: 12, right: 12, bottom: 8 })
        .backgroundColor('#E8F5E9').borderRadius(12)
      }

      if (this.crops.length === 0 && !this.loading) {
        Column() {
          Text('🌱').fontSize(48)
          Text('暂无作物记录').fontSize(14).fontColor(AppColors.TEXT_HINT).margin({ top: 8 })
          Text('点击右上角 + 添加作物').fontSize(12).fontColor(AppColors.TEXT_HINT).margin({ top: 4 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.crops, (crop: CropInfo) => {
            ListItem() {
              Column() {
                Row() {
                  Text('🌱').fontSize(24).margin({ right: 10 })
                  Column() {
                    Text(crop.crop_name)
                      .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppColors.TEXT_PRIMARY)
                    if (crop.variety) {
                      Text(`品种: ${crop.variety}`)
                        .fontSize(12).fontColor(AppColors.TEXT_SECONDARY).margin({ top: 2 })
                    }
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Text(this.getStageLabel(crop.growth_stage))
                    .fontSize(12).fontColor('#FFFFFF')
                    .backgroundColor(this.getStageColor(crop.growth_stage))
                    .borderRadius(10).padding({ left: 8, right: 8, top: 3, bottom: 3 })
                }.width('100%')

                // 目标参数
                Row() {
                  Text(`🌡${crop.target_temperature}°C`).fontSize(11).fontColor(AppColors.TEMP_COLOR)
                  Text(`💧${crop.target_humidity}%`).fontSize(11).fontColor(AppColors.HUMIDITY_COLOR)
                    .margin({ left: 10 })
                  Text(`🌿${crop.target_soil_moisture}%`).fontSize(11).fontColor(AppColors.SOIL_COLOR)
                    .margin({ left: 10 })
                  Text(`☀${crop.target_light}`).fontSize(11).fontColor(AppColors.LIGHT_COLOR)
                    .margin({ left: 10 })
                }
                .width('100%').margin({ top: 8 })

                if (crop.notes) {
                  Text(crop.notes)
                    .fontSize(12).fontColor(AppColors.TEXT_HINT).margin({ top: 4 })
                    .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .width('100%').padding(14)
              .backgroundColor(AppColors.CARD_BG).borderRadius(12)
              .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
            }
          })
        }
        .width('100%').layoutWeight(1).padding({ left: 12, right: 12 })
      }
    }
    .width('100%').height('100%').backgroundColor(AppColors.BG)
  }
}
