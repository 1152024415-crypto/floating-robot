import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { PermissionHelper } from '../utils/PermissionHelper';
import { FloatWindowManager } from '../managers/FloatWindowManager';
import { ScreenUtils } from '../utils/ScreenUtils';

const TAG = 'FloatingBot';

export default class EntryAbility extends UIAbility {
  private floatWindowManager: FloatWindowManager = FloatWindowManager.getInstance();
  private windowStage: window.WindowStage | null = null;
  private hasUserTappedRobot: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, '>>> onCreate start');
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(0x0000, TAG, 'setColorMode failed: %{public}s', JSON.stringify(err));
    }
    ScreenUtils.init();
    hilog.info(0x0000, TAG, '>>> onCreate done, screen: %{public}d x %{public}d',
      ScreenUtils.getScreenWidthPx(), ScreenUtils.getScreenHeightPx());
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, '>>> onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, TAG, '>>> onWindowStageCreate start');
    this.windowStage = windowStage;

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, TAG, '>>> loadContent FAILED: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(0x0000, TAG, '>>> loadContent OK, now requesting permission...');
      this.initFloatWindow();
    });
  }

  private initFloatWindow(): void {
    hilog.info(0x0000, TAG, '>>> initFloatWindow: requesting permission');
    const context = this.context;
    PermissionHelper.requestFloatWindowPermission(context).then((granted: boolean) => {
      hilog.info(0x0000, TAG, '>>> permission result: %{public}s', granted.toString());
      if (granted) {
        hilog.info(0x0000, TAG, '>>> calling createFloatWindow...');
        this.floatWindowManager.createFloatWindow(context).then(() => {
          hilog.info(0x0000, TAG, '>>> createFloatWindow resolved OK');
        }).catch((err: Error) => {
          hilog.error(0x0000, TAG, '>>> createFloatWindow REJECTED: %{public}s', err.message);
        });
      } else {
        hilog.warn(0x0000, TAG, '>>> permission DENIED');
      }
    }).catch((err: Error) => {
      hilog.error(0x0000, TAG, '>>> requestPermission FAILED: %{public}s', err.message);
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, TAG, '>>> onWindowStageDestroy');
    this.windowStage = null;
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, '>>> onNewWant');
    if (want.parameters && want.parameters['showMainPage'] === true) {
      this.hasUserTappedRobot = true;
      router.pushUrl({ url: 'pages/MainPage' });
    }
  }

  onForeground(): void {
    hilog.info(0x0000, TAG, '>>> onForeground, tapped=%{public}s', this.hasUserTappedRobot.toString());
    if (this.hasUserTappedRobot) {
      this.floatWindowManager.hideFloatWindow();
    }
  }

  onBackground(): void {
    hilog.info(0x0000, TAG, '>>> onBackground, floatWindow state=%{public}s',
      this.floatWindowManager.getState());
    this.floatWindowManager.showFloatWindow();
  }
}
