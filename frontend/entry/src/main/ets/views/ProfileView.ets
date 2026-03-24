// 智慧农业 - 个人中心视图
import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { AppColors } from '../common/Constants';

@Component
export struct ProfileView {
  @StorageProp('username') username: string = '未登录';
  @StorageProp('userRole') userRole: string = '';

  @Builder
  menuItem(icon: string, title: string, page: string) {
    Row() {
      Text(icon)
        .fontSize(22)
        .margin({ right: 12 })
      Text(title)
        .fontSize(15)
        .fontColor(AppColors.TEXT_PRIMARY)
        .layoutWeight(1)
      Text('>')
        .fontSize(16)
        .fontColor(AppColors.TEXT_HINT)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(AppColors.CARD_BG)
    .onClick(() => {
      router.pushUrl({ url: page });
    })
  }

  build() {
    Scroll() {
      Column() {
        // 用户信息卡片
        Row() {
          Column() {
            Text('👤')
              .fontSize(40)
          }
          .width(60)
          .height(60)
          .backgroundColor('#E8F5E9')
          .borderRadius(30)
          .justifyContent(FlexAlign.Center)
          .margin({ right: 14 })

          Column() {
            Text(this.username || '未登录')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)
            Text(this.userRole === 'admin' ? '管理员' : '普通用户')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(20)
        .margin({ left: 12, right: 12, top: 12 })
        .backgroundColor(AppColors.CARD_BG)
        .borderRadius(12)
        .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })

        // 功能菜单
        Text('农业管理')
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)
          .margin({ top: 20, bottom: 6 })
          .padding({ left: 16 })
          .width('100%')

        Column() {
          this.menuItem('🌱', '作物管理', 'pages/CropPage')
          Divider().color(AppColors.DIVIDER).margin({ left: 50 })
          this.menuItem('🏡', '区域管理', 'pages/ZonePage')
          Divider().color(AppColors.DIVIDER).margin({ left: 50 })
          this.menuItem('💧', '智能灌溉', 'pages/IrrigationPage')
          Divider().color(AppColors.DIVIDER).margin({ left: 50 })
          this.menuItem('💡', '智能光照', 'pages/LightingPage')
        }
        .margin({ left: 12, right: 12 })
        .borderRadius(12)
        .clip(true)

        Text('系统设置')
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)
          .margin({ top: 20, bottom: 6 })
          .padding({ left: 16 })
          .width('100%')

        Column() {
          this.menuItem('🔗', '联动规则', 'pages/AutomationPage')
          Divider().color(AppColors.DIVIDER).margin({ left: 50 })
          this.menuItem('📋', '数据报告', 'pages/ReportPage')
        }
        .margin({ left: 12, right: 12 })
        .borderRadius(12)
        .clip(true)

        // 退出登录
        Button('退出登录')
          .width('90%')
          .height(44)
          .borderRadius(22)
          .backgroundColor('#FFEBEE')
          .fontColor(AppColors.WARN)
          .fontSize(15)
          .margin({ top: 30, bottom: 30 })
          .onClick(() => {
            ApiService.clearToken();
            router.pushUrl({ url: 'pages/Login' });
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(AppColors.BG)
  }
}
