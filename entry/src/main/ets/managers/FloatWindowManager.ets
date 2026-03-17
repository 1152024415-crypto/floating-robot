import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConstants } from '../constants/AppConstants';
import { FloatWindowState, Position } from '../models/RobotState';
import { ScreenUtils } from '../utils/ScreenUtils';

const DOMAIN = 0x0001;
const TAG = 'FloatWindowManager';

export class FloatWindowManager {
  private static instance: FloatWindowManager | null = null;
  private windowInstance: window.Window | null = null;
  private state: FloatWindowState = FloatWindowState.HIDDEN;
  private currentPositionPx: Position = { x: 0, y: 0 };
  private appContext: Context | null = null;

  static getInstance(): FloatWindowManager {
    if (!FloatWindowManager.instance) {
      FloatWindowManager.instance = new FloatWindowManager();
    }
    return FloatWindowManager.instance;
  }

  getState(): FloatWindowState {
    return this.state;
  }

  getWindowPosition(): Position {
    return { ...this.currentPositionPx };
  }

  async createFloatWindow(context: Context): Promise<void> {
    if (this.state !== FloatWindowState.HIDDEN) {
      hilog.warn(DOMAIN, TAG, 'Cannot create: state is %{public}s', this.state);
      return;
    }
    this.state = FloatWindowState.CREATING;

    try {
      const config: window.Configuration = {
        name: AppConstants.FLOAT_WINDOW_NAME,
        windowType: window.WindowType.TYPE_FLOAT,
        ctx: context
      };
      this.windowInstance = await window.createWindow(config);

      const sizePx = ScreenUtils.vpToPx(AppConstants.FLOAT_WINDOW_SIZE);
      await this.windowInstance.resize(sizePx, sizePx);

      // 初始位置：右下角
      const initX = ScreenUtils.getScreenWidthPx() - sizePx;
      const initY = ScreenUtils.getScreenHeightPx() - sizePx;
      await this.windowInstance.moveWindowTo(initX, initY);
      this.currentPositionPx = { x: initX, y: initY };

      await this.windowInstance.setWindowBackgroundColor('#00000000');
      // 锁定竖屏
      await this.windowInstance.setPreferredOrientation(window.Orientation.PORTRAIT);
      await this.windowInstance.setUIContent('pages/FloatWindowPage');
      // 设置触摸穿透（窗口中非机器人/气泡区域的触摸事件穿透到下层）
      await this.windowInstance.setWindowTouchable(true);
      await this.windowInstance.showWindow();

      this.appContext = context;
      this.setupWindowEventListener();
      this.state = FloatWindowState.VISIBLE;
      hilog.info(DOMAIN, TAG, 'Float window created at (%{public}d, %{public}d)', initX, initY);
    } catch (err) {
      this.state = FloatWindowState.HIDDEN;
      hilog.error(DOMAIN, TAG, 'Create float window failed: %{public}s', JSON.stringify(err));
    }
  }

  async showFloatWindow(): Promise<void> {
    if (this.state !== FloatWindowState.HIDDEN || !this.windowInstance) {
      return;
    }
    try {
      await this.windowInstance.showWindow();
      this.state = FloatWindowState.VISIBLE;
      hilog.info(DOMAIN, TAG, 'Float window shown');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Show float window failed: %{public}s', JSON.stringify(err));
    }
  }

  async hideFloatWindow(): Promise<void> {
    if (this.state !== FloatWindowState.VISIBLE || !this.windowInstance) {
      return;
    }
    try {
      // TYPE_FLOAT 窗口使用 showWindow/destroyWindow 控制可见性
      // 通过移动到屏幕外隐藏，保留窗口实例
      await this.windowInstance.moveWindowTo(-99999, -99999);
      this.state = FloatWindowState.HIDDEN;
      hilog.info(DOMAIN, TAG, 'Float window hidden');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Hide float window failed: %{public}s', JSON.stringify(err));
    }
  }

  async destroyFloatWindow(): Promise<void> {
    if (this.state === FloatWindowState.DESTROYING || !this.windowInstance) {
      return;
    }
    this.state = FloatWindowState.DESTROYING;
    try {
      await this.windowInstance.destroyWindow();
      this.windowInstance = null;
      this.state = FloatWindowState.HIDDEN;
      hilog.info(DOMAIN, TAG, 'Float window destroyed');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Destroy float window failed: %{public}s', JSON.stringify(err));
    }
  }

  private setupWindowEventListener(): void {
    if (!this.windowInstance) return;
    this.windowInstance.on('windowEvent', async (eventType: number) => {
      hilog.info(DOMAIN, TAG, 'Window event: %{public}d', eventType);
      if (eventType === 1 && this.appContext) {
        this.windowInstance = null;
        this.state = FloatWindowState.HIDDEN;
        hilog.warn(DOMAIN, TAG, 'Window reclaimed by system, recreating...');
        await this.createFloatWindow(this.appContext);
      }
    });
  }

  async moveWindow(xPx: number, yPx: number): Promise<void> {
    if (!this.windowInstance || this.state !== FloatWindowState.VISIBLE) {
      return;
    }
    try {
      await this.windowInstance.moveWindowTo(xPx, yPx);
      this.currentPositionPx = { x: xPx, y: yPx };
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Move window failed: %{public}s', JSON.stringify(err));
    }
  }
}
