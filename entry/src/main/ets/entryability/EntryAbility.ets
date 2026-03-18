import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
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
    // 保存 UIAbilityContext 供悬浮窗页面使用
    FloatWindowManager.setAbilityContext(this.context);
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
          hilog.info(0x0000, TAG, '>>> createFloatWindow resolved OK, hiding (app in foreground)');
          // 创建后立即隐藏，等 app 退到后台时 onBackground 会显示
          this.floatWindowManager.hideFloatWindow();
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
      // 用 windowStage.loadContent 明确在主窗口加载，避免 router 误操作悬浮窗页面栈
      if (this.windowStage) {
        this.windowStage.loadContent('pages/MainPage', (err) => {
          if (err && err.code) {
            hilog.error(0x0000, TAG, '>>> loadContent MainPage FAILED: %{public}s', JSON.stringify(err));
          } else {
            hilog.info(0x0000, TAG, '>>> loadContent MainPage OK');
          }
        });
      }
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
