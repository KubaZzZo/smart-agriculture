import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'SmartAgri', 'Ability onCreate');
    // 初始化全局存储
    AppStorage.setOrCreate('token', '');
    AppStorage.setOrCreate('username', '');
    AppStorage.setOrCreate('userRole', '');
    AppStorage.setOrCreate('isLoggedIn', false);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'SmartAgri', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'SmartAgri', 'Ability onWindowStageCreate');
    windowStage.loadContent('pages/Login', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'SmartAgri', 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'SmartAgri', 'Content loaded successfully');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'SmartAgri', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'SmartAgri', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'SmartAgri', 'Ability onBackground');
  }
}
