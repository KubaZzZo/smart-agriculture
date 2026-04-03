import { AppColors } from '../common/Constants';
import { DashboardView } from '../views/DashboardView';
import { MonitorView } from '../views/MonitorView';
import { DeviceView } from '../views/DeviceView';
import { AlertView } from '../views/AlertView';
import { ProfileView } from '../views/ProfileView';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  @Builder
  tabBarItem(title: string, icon: Resource, index: number): void {
    Column() {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([this.currentIndex === index ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY]);
      Text(title)
        .fontSize(11)
        .fontColor(this.currentIndex === index ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
        .margin({ top: 2 });
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  build(): void {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        DashboardView();
      }
      .tabBar(this.tabBarItem('首页', $r('sys.symbol.house'), 0));

      TabContent() {
        MonitorView();
      }
      .tabBar(this.tabBarItem('监控', $r('sys.symbol.eye'), 1));

      TabContent() {
        DeviceView();
      }
      .tabBar(this.tabBarItem('设备', $r('sys.symbol.gearshape'), 2));

      TabContent() {
        AlertView();
      }
      .tabBar(this.tabBarItem('告警', $r('sys.symbol.bell'), 3));

      TabContent() {
        ProfileView();
      }
      .tabBar(this.tabBarItem('我的', $r('sys.symbol.person'), 4));
    }
    .scrollable(false)
    .barHeight(56)
    .barMode(BarMode.Fixed)
    .onChange((index: number): void => {
      this.currentIndex = index;
    })
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG);
  }
}
