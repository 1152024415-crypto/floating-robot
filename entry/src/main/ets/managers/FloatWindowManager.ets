import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConstants } from '../constants/AppConstants';
import { FloatWindowState, Position } from '../models/RobotState';
import { ScreenUtils } from '../utils/ScreenUtils';

const DOMAIN = 0x0000;
const TAG = 'FloatingBot';

export class FloatWindowManager {
  private static instance: FloatWindowManager | null = null;
  private windowInstance: window.Window | null = null;
  private state: FloatWindowState = FloatWindowState.HIDDEN;
  private currentPositionPx: Position = { x: 0, y: 0 };
  private lastValidPositionPx: Position = { x: 0, y: 0 };
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
    return { x: this.currentPositionPx.x, y: this.currentPositionPx.y };
  }

  async createFloatWindow(context: Context): Promise<void> {
    if (this.state !== FloatWindowState.HIDDEN) {
      hilog.warn(DOMAIN, TAG, 'Cannot create: state is %{public}s', this.state);
      return;
    }
    this.state = FloatWindowState.CREATING;
    hilog.info(DOMAIN, TAG, '[create] START');

    try {
      this.windowInstance = await window.createWindow({
        name: AppConstants.FLOAT_WINDOW_NAME,
        windowType: window.WindowType.TYPE_FLOAT,
        ctx: context
      });
      hilog.info(DOMAIN, TAG, '[create] window created');

      // 用 px 值，屏幕密度 3.5，300vp = 1050px
      const sizePx = ScreenUtils.vpToPx(AppConstants.FLOAT_WINDOW_SIZE);
      await this.windowInstance.resize(sizePx, sizePx);
      hilog.info(DOMAIN, TAG, '[create] resized to %{public}d', sizePx);

      // 初始位置：右下角
      const initX = ScreenUtils.getScreenWidthPx() - sizePx;
      const initY = ScreenUtils.getScreenHeightPx() - sizePx;
      await this.windowInstance.moveWindowTo(initX, initY);
      this.currentPositionPx = { x: initX, y: initY };
      hilog.info(DOMAIN, TAG, '[create] moved to (%{public}d,%{public}d)', initX, initY);

      // 注意：不调用 setWindowBackgroundColor，由页面自身控制背景
      this.windowInstance.setUIContent('pages/FloatWindowPage', (err) => {
        if (err && err.code) {
          hilog.error(DOMAIN, TAG, '[create] setUIContent ERROR: %{public}d %{public}s', err.code, err.message);
        } else {
          hilog.info(DOMAIN, TAG, '[create] setUIContent OK');
        }
      });
      hilog.info(DOMAIN, TAG, '[create] setUIContent called');

      await this.windowInstance.showWindow();
      hilog.info(DOMAIN, TAG, '[create] showWindow done');

      this.appContext = context;
      this.lastValidPositionPx = { x: initX, y: initY };
      this.setupWindowEventListener();
      this.state = FloatWindowState.VISIBLE;
      hilog.info(DOMAIN, TAG, '[create] DONE');
    } catch (err) {
      this.state = FloatWindowState.HIDDEN;
      hilog.error(DOMAIN, TAG, '[create] FAILED: %{public}s', JSON.stringify(err));
    }
  }

  async showFloatWindow(): Promise<void> {
    if (this.state !== FloatWindowState.HIDDEN || !this.windowInstance) {
      return;
    }
    try {
      // 恢复到隐藏前的位置
      await this.windowInstance.moveWindowTo(this.lastValidPositionPx.x, this.lastValidPositionPx.y);
      this.currentPositionPx = { x: this.lastValidPositionPx.x, y: this.lastValidPositionPx.y };
      await this.windowInstance.showWindow();
      this.state = FloatWindowState.VISIBLE;
      hilog.info(DOMAIN, TAG, 'Float window shown at (%{public}d, %{public}d)', this.lastValidPositionPx.x, this.lastValidPositionPx.y);
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
      // 保存当前位置，移到屏幕外隐藏
      this.lastValidPositionPx = { x: this.currentPositionPx.x, y: this.currentPositionPx.y };
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
