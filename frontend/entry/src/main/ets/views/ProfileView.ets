import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { AppColors } from '../common/Constants';

@Component
export struct ProfileView {
  @StorageProp('username') username: string = '游客';
  @StorageProp('userRole') userRole: string = '';

  @Builder
  menuItem(icon: Resource, title: string, page: string): void {
    Row() {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor([AppColors.PRIMARY])
        .margin({ right: 12 });
      Text(title)
        .fontSize(15)
        .fontColor(AppColors.TEXT_PRIMARY)
        .layoutWeight(1);
      Text('>')
        .fontSize(16)
        .fontColor(AppColors.TEXT_HINT);
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(AppColors.CARD_BG)
    .onClick((): void => {
      router.pushUrl({ url: page });
    });
  }

  roleText(): string {
    return this.userRole === 'admin' ? '管理员' : '操作员';
  }

  build(): void {
    Scroll() {
      Column() {
        Column() {
          Row() {
            Column() {
              SymbolGlyph($r('sys.symbol.person'))
                .fontSize(34)
                .fontColor([AppColors.PRIMARY]);
            }
            .width(64)
            .height(64)
            .backgroundColor('#EAF6EE')
            .borderRadius(32)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .margin({ right: 14 });

            Column() {
              Text(this.username || '游客')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.TEXT_PRIMARY);
              Text(this.roleText())
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY)
                .margin({ top: 4 });
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1);
          }
          .width('100%');

          Text('系统配置与运维快捷入口')
            .fontSize(12)
            .fontColor(AppColors.TEXT_HINT)
            .width('100%')
            .margin({ top: 12 });
        }
        .width('100%')
        .padding(18)
        .margin({ left: 12, right: 12, top: 12 })
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(16)
        .shadow({ radius: 7, color: '#14000000', offsetX: 0, offsetY: 3 });

        Text('业务功能')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_SECONDARY)
          .margin({ top: 18, bottom: 6 })
          .padding({ left: 16 })
          .width('100%');

        Column() {
          this.menuItem($r('sys.symbol.leaf'), '作物管理', 'pages/CropPage');
          Divider().color(AppColors.DIVIDER).margin({ left: 50 });
          this.menuItem($r('sys.symbol.house'), '区域管理', 'pages/ZonePage');
          Divider().color(AppColors.DIVIDER).margin({ left: 50 });
          this.menuItem($r('sys.symbol.drop'), '智能灌溉', 'pages/IrrigationPage');
          Divider().color(AppColors.DIVIDER).margin({ left: 50 });
          this.menuItem($r('sys.symbol.sun_max'), '智能光照', 'pages/LightingPage');
        }
        .margin({ left: 12, right: 12 })
        .borderRadius(12)
        .clip(true);

        Text('系统功能')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_SECONDARY)
          .margin({ top: 18, bottom: 6 })
          .padding({ left: 16 })
          .width('100%');

        Column() {
          this.menuItem($r('sys.symbol.link'), '联动规则', 'pages/AutomationPage');
          Divider().color(AppColors.DIVIDER).margin({ left: 50 });
          this.menuItem($r('sys.symbol.doc_text'), '数据报告', 'pages/ReportPage');
        }
        .margin({ left: 12, right: 12 })
        .borderRadius(12)
        .clip(true);

        Button('退出登录')
          .width('90%')
          .height(44)
          .borderRadius(22)
          .backgroundColor('#FDECEC')
          .fontColor(AppColors.WARN)
          .fontSize(15)
          .margin({ top: 28, bottom: 30 })
          .onClick((): void => {
            ApiService.clearToken();
            router.pushUrl({ url: 'pages/Login' });
          });
      }
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(AppColors.BG);
  }
}
