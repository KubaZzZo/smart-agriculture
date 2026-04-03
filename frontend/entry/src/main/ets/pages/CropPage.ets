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
    } catch (_e) {
      const c1: CropInfo = {
        id: 1,
        crop_name: '番茄',
        variety: '圣女果',
        plant_date: '2025-03-01',
        growth_stage: 'growing',
        zone_id: 1,
        target_temperature: 25,
        target_humidity: 65,
        target_soil_moisture: 55,
        target_light: 35000,
        notes: '长势良好，保持通风。',
        created_at: '',
        updated_at: '',
      };
      const c2: CropInfo = {
        id: 2,
        crop_name: '黄瓜',
        variety: '水果黄瓜',
        plant_date: '2025-02-20',
        growth_stage: 'flowering',
        zone_id: 1,
        target_temperature: 28,
        target_humidity: 70,
        target_soil_moisture: 60,
        target_light: 40000,
        notes: '开花期，建议适当增加灌溉。',
        created_at: '',
        updated_at: '',
      };
      const c3: CropInfo = {
        id: 3,
        crop_name: '生菜',
        variety: '罗马生菜',
        plant_date: '2025-03-10',
        growth_stage: 'seedling',
        zone_id: 2,
        target_temperature: 20,
        target_humidity: 60,
        target_soil_moisture: 50,
        target_light: 25000,
        notes: '幼苗期，避免温度波动。',
        created_at: '',
        updated_at: '',
      };
      this.crops = [c1, c2, c3];
    } finally {
      this.loading = false;
    }
  }

  async addCrop(): Promise<void> {
    if (!this.newName) {
      return;
    }

    try {
      const body: CropCreateRequest = {
        crop_name: this.newName,
        variety: this.newVariety,
        plant_date: new Date().toISOString(),
      };
      await ApiService.post<void>(ApiConstants.CROP_LIST, body);
      this.newName = '';
      this.newVariety = '';
      this.showAdd = false;
      this.loadData();
    } catch (_e) {
      // Ignore offline errors.
    }
  }

  stageLabel(stage: string): string {
    if (stage === 'seedling') return '幼苗期';
    if (stage === 'growing') return '生长期';
    if (stage === 'flowering') return '开花期';
    if (stage === 'fruiting') return '结果期';
    if (stage === 'harvest') return '收获期';
    return stage;
  }

  stageColor(stage: string): string {
    if (stage === 'seedling') return '#7CB342';
    if (stage === 'growing') return '#43A047';
    if (stage === 'flowering') return '#FB8C00';
    if (stage === 'fruiting') return '#E53935';
    if (stage === 'harvest') return '#6D4C41';
    return AppColors.PRIMARY;
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

        Text('作物管理')
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
          Text('新增作物')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .width('100%');

          TextInput({ placeholder: '作物名称', text: this.newName })
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

          TextInput({ placeholder: '品种（可选）', text: this.newVariety })
            .width('100%')
            .height(42)
            .fontSize(14)
            .backgroundColor('#F3F7F4')
            .borderRadius(10)
            .padding({ left: 12, right: 12 })
            .margin({ top: 8 })
            .onChange((value: string): void => {
              this.newVariety = value;
            });

          Button('保存作物')
            .width('100%')
            .height(40)
            .borderRadius(20)
            .backgroundColor(AppColors.PRIMARY)
            .fontColor('#FFFFFF')
            .fontSize(14)
            .margin({ top: 12 })
            .onClick((): void => {
              this.addCrop();
            });
        }
        .width('100%')
        .padding(14)
        .margin({ left: 12, right: 12, bottom: 10 })
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(14)
        .shadow({ radius: 6, color: '#12000000', offsetX: 0, offsetY: 3 });
      }

      if (!this.loading && this.crops.length === 0) {
        Column() {
          Text('暂无作物记录')
            .fontSize(14)
            .fontColor(AppColors.TEXT_HINT);
          Text('点击右上角新增第一条作物')
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
          ForEach(this.crops, (crop: CropInfo) => {
            ListItem() {
              Column() {
                Row() {
                  Column() {
                    Text(crop.crop_name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColors.TEXT_PRIMARY);

                    if (crop.variety) {
                      Text(`品种：${crop.variety}`)
                        .fontSize(12)
                        .fontColor(AppColors.TEXT_SECONDARY)
                        .margin({ top: 2 });
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1);

                  Text(this.stageLabel(crop.growth_stage))
                    .fontSize(11)
                    .fontColor('#FFFFFF')
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor(this.stageColor(crop.growth_stage))
                    .borderRadius(10);
                }
                .width('100%');

                Row() {
                  Text(`温度 ${crop.target_temperature}C`)
                    .fontSize(11)
                    .fontColor(AppColors.TEMP_COLOR);
                  Text(`湿度 ${crop.target_humidity}%`)
                    .fontSize(11)
                    .fontColor(AppColors.HUMIDITY_COLOR)
                    .margin({ left: 10 });
                  Text(`土壤 ${crop.target_soil_moisture}%`)
                    .fontSize(11)
                    .fontColor(AppColors.SOIL_COLOR)
                    .margin({ left: 10 });
                }
                .width('100%')
                .margin({ top: 8 });

                if (crop.notes) {
                  Text(crop.notes)
                    .fontSize(12)
                    .fontColor(AppColors.TEXT_HINT)
                    .margin({ top: 6 })
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis });
                }
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
