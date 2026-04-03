import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { FrontendDeploy } from '../common/Constants';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private ensureDefaultConfig(key: string, value: string): void {
    const current = AppStorage.get<string>(key);
    if (!current) {
      AppStorage.setOrCreate(key, value);
    }
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'SmartAgri', 'Ability onCreate');

    AppStorage.setOrCreate('token', '');
    AppStorage.setOrCreate('username', '');
    AppStorage.setOrCreate('userRole', '');
    AppStorage.setOrCreate('isLoggedIn', false);

    this.ensureDefaultConfig('APP_ENV', FrontendDeploy.DEFAULT_ENV);
    this.ensureDefaultConfig('API_BASE_URL', '');
    this.ensureDefaultConfig('WS_BASE_URL', '');
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
