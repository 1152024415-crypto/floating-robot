import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { PermissionHelper } from '../utils/PermissionHelper';
import { FloatWindowManager } from '../managers/FloatWindowManager';
import { ScreenUtils } from '../utils/ScreenUtils';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private floatWindowManager: FloatWindowManager = FloatWindowManager.getInstance();
  private windowStage: window.WindowStage | null = null;
  private hasUserTappedRobot: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', 'Ability onCreate');
    ScreenUtils.init();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', 'Ability onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, 'testTag', 'Ability onWindowStageCreate');
    this.windowStage = windowStage;

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Content loaded');
    });

    const granted = await PermissionHelper.requestFloatWindowPermission(this.context);
    if (granted) {
      await this.floatWindowManager.createFloatWindow(this.context);
    } else {
      hilog.warn(DOMAIN, 'testTag', 'Float window permission denied');
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', 'Ability onWindowStageDestroy');
    this.windowStage = null;
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', 'Ability onNewWant');
    if (want.parameters && want.parameters['showMainPage'] === true) {
      this.hasUserTappedRobot = true;
      router.pushUrl({ url: 'pages/MainPage' });
    }
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', 'Ability onForeground');
    if (this.hasUserTappedRobot) {
      this.floatWindowManager.hideFloatWindow();
    }
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', 'Ability onBackground');
    this.floatWindowManager.showFloatWindow();
  }
}
