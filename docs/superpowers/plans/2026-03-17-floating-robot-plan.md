# 悬浮AI助手机器人 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 HarmonyOS NEXT 手机端实现全局悬浮AI助手机器人，支持拖拽、边缘吸附、消息弹出、长按删除、点击进入App。

**Architecture:** 三层架构（UI层/业务层/基础层），单UIAbility + router页面路由。悬浮窗使用 `window.createWindow()` + `TYPE_FLOAT`，动画通过 AnimationManager 与业务解耦。

**Tech Stack:** HarmonyOS NEXT API 12+, ArkTS, ArkUI, @kit.ArkUI (window), @kit.AbilityKit (permissions)

---

## File Map

### 新建文件

| 文件 | 职责 |
|------|------|
| `entry/src/main/ets/constants/AppConstants.ets` | 尺寸、时间等全局常量 |
| `entry/src/main/ets/models/RobotState.ets` | RobotState 枚举 + FloatWindowState 枚举 + Message 模型 + FeedbackType 枚举 |
| `entry/src/main/ets/utils/ScreenUtils.ets` | vp↔px 转换、屏幕尺寸获取 |
| `entry/src/main/ets/utils/PermissionHelper.ets` | SYSTEM_FLOAT_WINDOW 权限申请 |
| `entry/src/main/ets/managers/FloatWindowManager.ets` | 悬浮窗生命周期管理（创建/显示/隐藏/销毁/移动） |
| `entry/src/main/ets/managers/AnimationManager.ets` | 动画状态管理，与业务解耦 |
| `entry/src/main/ets/managers/DragManager.ets` | 拖拽逻辑、边缘吸附计算 |
| `entry/src/main/ets/services/MessageService.ets` | 消息打桩服务（定时模拟 + 队列） |
| `entry/src/main/ets/services/FeedbackService.ets` | 反馈打桩服务 |
| `entry/src/main/ets/components/RobotView.ets` | 机器人动画组件 |
| `entry/src/main/ets/components/MessageBubble.ets` | 消息气泡组件 |
| `entry/src/main/ets/components/DeleteZone.ets` | 顶部删除栏组件 |
| `entry/src/main/ets/pages/FloatWindowPage.ets` | 悬浮窗页面（组装所有组件 + 手势处理） |
| `entry/src/main/ets/pages/MainPage.ets` | App主页面（空白占位） |

**设计偏差说明：**
- `components/ConfirmDialog.ets`（设计文档中列出）→ 使用 ArkUI 内置 `AlertDialog.show()` 代替，无需单独组件文件。
- `models/Message.ets`（设计文档中单独文件）→ 合并到 `models/RobotState.ets` 中，避免碎片文件。
- 边缘吸附动画：设计文档要求 `curves.springMotion()`，但 `moveWindowTo` 是窗口级 API，无法被 ArkUI 的 `animateTo` 驱动。改用手动插值循环（15帧 cubic ease-out）模拟弹性吸附效果。
- `components/BubblePositionHelper.ets`（设计文档未要求）→ 气泡方向计算逻辑内联于 `FloatWindowPage.getBubbleOffset()`，无需单独文件。

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `entry/src/main/ets/entryability/EntryAbility.ets` | 添加权限申请、创建悬浮窗、onBackground 恢复悬浮窗 |
| `entry/src/main/module.json5` | 添加 `requestPermissions` 声明 |
| `entry/src/main/resources/base/element/string.json` | 添加权限描述字符串、App文案 |
| `entry/src/main/resources/base/profile/main_pages.json` | 添加 FloatWindowPage 和 MainPage 路由 |
| `AppScope/resources/base/element/string.json` | 修改 app_name |

---

## Task 1: 基础层 — 常量、模型、工具

**Files:**
- Create: `entry/src/main/ets/constants/AppConstants.ets`
- Create: `entry/src/main/ets/models/RobotState.ets`
- Create: `entry/src/main/ets/utils/ScreenUtils.ets`

- [ ] **Step 1: 创建常量文件**

```typescript
// entry/src/main/ets/constants/AppConstants.ets

export class AppConstants {
  // 悬浮窗
  static readonly FLOAT_WINDOW_NAME: string = 'floatingRobot';
  static readonly FLOAT_WINDOW_SIZE: number = 300; // vp
  static readonly ROBOT_ICON_SIZE: number = 56; // vp
  // 消息气泡
  static readonly BUBBLE_MAX_WIDTH: number = 200; // vp
  static readonly BUBBLE_MAX_HEIGHT: number = 80; // vp
  static readonly BUBBLE_DISMISS_TIME: number = 10000; // ms
  static readonly MESSAGE_QUEUE_MAX: number = 20;
  // 边缘吸附
  static readonly EDGE_SNAP_MARGIN: number = 8; // vp
  // 删除栏
  static readonly DELETE_ZONE_HEIGHT: number = 64; // vp
  static readonly DELETE_ZONE_ANIM_DURATION: number = 300; // ms
  // 手势
  static readonly LONG_PRESS_DURATION: number = 500; // ms
  static readonly PAN_DISTANCE_THRESHOLD: number = 5; // vp
  static readonly TAP_DEBOUNCE: number = 300; // ms
  // 打桩
  static readonly MOCK_MESSAGE_INTERVAL: number = 30000; // ms
}
```

- [ ] **Step 2: 创建模型与枚举文件**

```typescript
// entry/src/main/ets/models/RobotState.ets

export enum RobotState {
  IDLE = 'idle',
  MESSAGE = 'message',
  DRAGGING = 'dragging',
  DELETE = 'delete'
}

export enum FloatWindowState {
  HIDDEN = 'hidden',
  VISIBLE = 'visible',
  CREATING = 'creating',
  DESTROYING = 'destroying'
}

export enum FeedbackType {
  CONFIRM = 'confirm'
  // 预留: LIKE = 'like', DISLIKE = 'dislike', OPEN_APP = 'open_app'
}

export enum EdgePosition {
  LEFT = 'left',
  RIGHT = 'right',
  TOP = 'top',
  BOTTOM = 'bottom'
}

export interface Message {
  id: string;
  content: string;
  timestamp: number;
  isRead: boolean;
}

export interface Position {
  x: number;
  y: number;
}
```

- [ ] **Step 3: 创建屏幕工具类**

```typescript
// entry/src/main/ets/utils/ScreenUtils.ets

import { display } from '@kit.ArkUI';

export class ScreenUtils {
  private static densityDPI: number = 0;
  private static screenWidthPx: number = 0;
  private static screenHeightPx: number = 0;

  static init(): void {
    const defaultDisplay = display.getDefaultDisplaySync();
    ScreenUtils.densityDPI = defaultDisplay.densityPixels;
    ScreenUtils.screenWidthPx = defaultDisplay.width;
    ScreenUtils.screenHeightPx = defaultDisplay.height;
  }

  static vpToPx(vp: number): number {
    return vp * ScreenUtils.densityDPI;
  }

  static pxToVp(px: number): number {
    return px / ScreenUtils.densityDPI;
  }

  static getScreenWidthPx(): number {
    return ScreenUtils.screenWidthPx;
  }

  static getScreenHeightPx(): number {
    return ScreenUtils.screenHeightPx;
  }

  static getScreenWidthVp(): number {
    return ScreenUtils.pxToVp(ScreenUtils.screenWidthPx);
  }

  static getScreenHeightVp(): number {
    return ScreenUtils.pxToVp(ScreenUtils.screenHeightPx);
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add entry/src/main/ets/constants/AppConstants.ets entry/src/main/ets/models/RobotState.ets entry/src/main/ets/utils/ScreenUtils.ets
git commit -m "feat: add constants, models, and screen utils foundation"
```

---

## Task 2: 权限工具 + 配置文件修改

**Files:**
- Create: `entry/src/main/ets/utils/PermissionHelper.ets`
- Modify: `entry/src/main/module.json5`
- Modify: `entry/src/main/resources/base/element/string.json`
- Modify: `AppScope/resources/base/element/string.json`

- [ ] **Step 1: 创建权限工具**

```typescript
// entry/src/main/ets/utils/PermissionHelper.ets

import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'PermissionHelper';

export class PermissionHelper {
  static async checkPermission(permission: Permissions): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const bundleInfo = await bundleManager.getBundleInfoForSelf(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
    );
    const tokenId = bundleInfo.appInfo.accessTokenId;
    const grantStatus = atManager.checkAccessTokenSync(tokenId, permission);
    return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  }

  static async requestFloatWindowPermission(context: Context): Promise<boolean> {
    const permission: Permissions = 'ohos.permission.SYSTEM_FLOAT_WINDOW';

    const granted = await PermissionHelper.checkPermission(permission);
    if (granted) {
      hilog.info(DOMAIN, TAG, 'SYSTEM_FLOAT_WINDOW already granted');
      return true;
    }

    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(context, [permission]);
      const isGranted = result.authResults[0] === 0;
      hilog.info(DOMAIN, TAG, 'Permission request result: %{public}s', isGranted.toString());
      return isGranted;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Request permission failed: %{public}s', JSON.stringify(err));
      return false;
    }
  }
}
```

- [ ] **Step 2: 修改 module.json5**

在 `entry/src/main/module.json5` 的 `module` 对象中：

1. 在 `abilities[0]`（EntryAbility）中添加 `"launchType": "singleton"`（支持 onNewWant 回调）
2. 添加 `requestPermissions` 字段：

```json5
// 在 abilities 的 EntryAbility 中添加：
"launchType": "singleton"

// 在 module 对象中添加：
"requestPermissions": [
  {
    "name": "ohos.permission.SYSTEM_FLOAT_WINDOW",
    "reason": "$string:float_window_reason",
    "usedScene": {
      "abilities": ["EntryAbility"],
      "when": "always"
    }
  }
]
```

- [ ] **Step 3: 替换 entry string.json 为完整版**

替换 `entry/src/main/resources/base/element/string.json` 的全部内容为：

```json
{
  "string": [
    { "name": "module_desc", "value": "悬浮AI助手模块" },
    { "name": "EntryAbility_desc", "value": "悬浮AI助手机器人" },
    { "name": "EntryAbility_label", "value": "AI助手" },
    { "name": "float_window_reason", "value": "需要悬浮窗权限以显示AI助手机器人" },
    { "name": "main_page_title", "value": "AI助手（开发中）" },
    { "name": "delete_confirm_title", "value": "确定退出？" },
    { "name": "delete_confirm_message", "value": "退出后悬浮助手将关闭" },
    { "name": "confirm_button", "value": "确定" },
    { "name": "cancel_button", "value": "取消" },
    { "name": "message_confirm_bar", "value": "已读" }
  ]
}
```

- [ ] **Step 4: 替换 AppScope string.json**

替换 `AppScope/resources/base/element/string.json` 全部内容为：

```json
{
  "string": [
    { "name": "app_name", "value": "悬浮AI助手" }
  ]
}
```

- [ ] **Step 5: 更新 main_pages.json 添加新页面路由**

替换 `entry/src/main/resources/base/profile/main_pages.json`：

```json
{
  "src": [
    "pages/Index",
    "pages/FloatWindowPage",
    "pages/MainPage"
  ]
}
```

- [ ] **Step 6: Commit**

```bash
git add entry/src/main/ets/utils/PermissionHelper.ets entry/src/main/module.json5 entry/src/main/resources/base/element/string.json AppScope/resources/base/element/string.json entry/src/main/resources/base/profile/main_pages.json
git commit -m "feat: add permission helper and update all config files"
```

---

## Task 3: FloatWindowManager — 悬浮窗生命周期

**Files:**
- Create: `entry/src/main/ets/managers/FloatWindowManager.ets`

- [ ] **Step 1: 实现 FloatWindowManager**

```typescript
// entry/src/main/ets/managers/FloatWindowManager.ets

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

  // 监听窗口被系统回收，尝试重建
  private appContext: Context | null = null;

  private setupWindowEventListener(): void {
    if (!this.windowInstance) return;
    this.windowInstance.on('windowEvent', async (eventType: number) => {
      hilog.info(DOMAIN, TAG, 'Window event: %{public}d', eventType);
      // 如果窗口被系统销毁，尝试重建
      if (eventType === 1 && this.appContext) { // WINDOW_DESTROYED
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
```

- [ ] **Step 2: Commit**

```bash
git add entry/src/main/ets/managers/FloatWindowManager.ets
git commit -m "feat: add FloatWindowManager with state machine protection"
```

---

## Task 4: AnimationManager — 动画管理

**Files:**
- Create: `entry/src/main/ets/managers/AnimationManager.ets`

- [ ] **Step 1: 实现 AnimationManager**

AnimationManager 暴露响应式状态供 RobotView 观察，内部根据状态返回动画参数。不直接操作 UI，仅提供动画配置数据。

```typescript
// entry/src/main/ets/managers/AnimationManager.ets

import { RobotState } from '../models/RobotState';

export interface AnimationParams {
  scaleX: number;
  scaleY: number;
  rotate: number;
  translateY: number;
  duration: number;
  curve: Curve;
}

export class AnimationManager {
  private currentState: RobotState = RobotState.IDLE;
  private animationPhase: boolean = false; // 用于循环动画的相位切换

  setState(state: RobotState): void {
    this.currentState = state;
    this.animationPhase = false;
  }

  getCurrentState(): RobotState {
    return this.currentState;
  }

  // 返回当前状态下的动画目标参数，由 RobotView 在 animateTo 中使用
  getAnimationParams(): AnimationParams {
    this.animationPhase = !this.animationPhase;

    switch (this.currentState) {
      case RobotState.IDLE:
        return {
          scaleX: this.animationPhase ? 1.05 : 0.95,
          scaleY: this.animationPhase ? 1.05 : 0.95,
          rotate: 0,
          translateY: 0,
          duration: 1500,
          curve: Curve.EaseInOut
        };

      case RobotState.MESSAGE:
        return {
          scaleX: 1.0,
          scaleY: 1.0,
          rotate: this.animationPhase ? 15 : -15,
          translateY: this.animationPhase ? -5 : 0,
          duration: 300,
          curve: Curve.EaseInOut
        };

      case RobotState.DRAGGING:
        return {
          scaleX: 1.1,
          scaleY: 1.1,
          rotate: 0,
          translateY: 0,
          duration: 200,
          curve: Curve.EaseOut
        };

      case RobotState.DELETE:
        return {
          scaleX: 0.9,
          scaleY: 0.9,
          rotate: this.animationPhase ? 10 : -10,
          translateY: 0,
          duration: 100,
          curve: Curve.Linear
        };

      default:
        return {
          scaleX: 1.0,
          scaleY: 1.0,
          rotate: 0,
          translateY: 0,
          duration: 300,
          curve: Curve.EaseInOut
        };
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add entry/src/main/ets/managers/AnimationManager.ets
git commit -m "feat: add AnimationManager with decoupled animation params"
```

---

## Task 5: DragManager — 拖拽与吸附

**Files:**
- Create: `entry/src/main/ets/managers/DragManager.ets`

- [ ] **Step 1: 实现 DragManager**

```typescript
// entry/src/main/ets/managers/DragManager.ets

import { AppConstants } from '../constants/AppConstants';
import { EdgePosition, Position } from '../models/RobotState';
import { ScreenUtils } from '../utils/ScreenUtils';
import { FloatWindowManager } from './FloatWindowManager';

export class DragManager {
  private floatWindowManager: FloatWindowManager;
  private dragStartPositionPx: Position = { x: 0, y: 0 };
  private isAnimating: boolean = false;

  constructor() {
    this.floatWindowManager = FloatWindowManager.getInstance();
  }

  onDragStart(): void {
    this.isAnimating = false; // 取消正在进行的吸附动画
    this.dragStartPositionPx = this.floatWindowManager.getWindowPosition();
  }

  onDragUpdate(offsetXVp: number, offsetYVp: number): void {
    const offsetXPx = ScreenUtils.vpToPx(offsetXVp);
    const offsetYPx = ScreenUtils.vpToPx(offsetYVp);
    const newX = this.dragStartPositionPx.x + offsetXPx;
    const newY = this.dragStartPositionPx.y + offsetYPx;
    this.floatWindowManager.moveWindow(newX, newY);
  }

  // 计算吸附目标位置并返回（由 UI 层调用 animateTo 执行动画）
  calcSnapPosition(): Position {
    const currentPos = this.floatWindowManager.getWindowPosition();
    const windowSizePx = ScreenUtils.vpToPx(AppConstants.FLOAT_WINDOW_SIZE);
    const robotSizePx = ScreenUtils.vpToPx(AppConstants.ROBOT_ICON_SIZE);
    const marginPx = ScreenUtils.vpToPx(AppConstants.EDGE_SNAP_MARGIN);
    const screenW = ScreenUtils.getScreenWidthPx();
    const screenH = ScreenUtils.getScreenHeightPx();

    // 机器人中心点（在悬浮窗内的位置取决于吸附边，此处用窗口中心近似）
    const centerX = currentPos.x + windowSizePx / 2;
    const centerY = currentPos.y + windowSizePx / 2;

    const edge = this.calcNearestEdge(centerX, centerY, screenW, screenH);

    let targetX = currentPos.x;
    let targetY = currentPos.y;

    switch (edge) {
      case EdgePosition.LEFT:
        targetX = marginPx - (windowSizePx - robotSizePx) / 2;
        break;
      case EdgePosition.RIGHT:
        targetX = screenW - marginPx - (windowSizePx + robotSizePx) / 2;
        break;
      case EdgePosition.TOP:
        targetY = marginPx - (windowSizePx - robotSizePx) / 2;
        break;
      case EdgePosition.BOTTOM:
        targetY = screenH - marginPx - (windowSizePx + robotSizePx) / 2;
        break;
    }

    return { x: targetX, y: targetY };
  }

  calcNearestEdge(cx: number, cy: number, screenW: number, screenH: number): EdgePosition {
    const dLeft = cx;
    const dRight = screenW - cx;
    const dTop = cy;
    const dBottom = screenH - cy;

    // 水平边优先于垂直边（角落处理）
    const minHorizontal = Math.min(dLeft, dRight);
    const minVertical = Math.min(dTop, dBottom);

    if (minHorizontal <= minVertical) {
      return dLeft <= dRight ? EdgePosition.LEFT : EdgePosition.RIGHT;
    } else {
      return dTop <= dBottom ? EdgePosition.TOP : EdgePosition.BOTTOM;
    }
  }

  isInDeleteZone(touchYPx: number): boolean {
    const deleteZoneHeightPx = ScreenUtils.vpToPx(AppConstants.DELETE_ZONE_HEIGHT);
    return touchYPx <= deleteZoneHeightPx;
  }

  getDragStartPosition(): Position {
    return { ...this.dragStartPositionPx };
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add entry/src/main/ets/managers/DragManager.ets
git commit -m "feat: add DragManager with edge snapping and delete zone detection"
```

---

## Task 6: 打桩服务 — MessageService + FeedbackService

**Files:**
- Create: `entry/src/main/ets/services/MessageService.ets`
- Create: `entry/src/main/ets/services/FeedbackService.ets`

- [ ] **Step 1: 实现 MessageService**

```typescript
// entry/src/main/ets/services/MessageService.ets

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConstants } from '../constants/AppConstants';
import { Message } from '../models/RobotState';

const DOMAIN = 0x0001;
const TAG = 'MessageService';

const MOCK_MESSAGES: string[] = [
  '你好！我是你的AI助手',
  '今天天气不错，适合写代码',
  '有新的日程提醒',
  '你有一条未读消息',
  '系统更新可用'
];

export class MessageService {
  private messageQueue: Message[] = [];
  private timerId: number = -1;
  private mockIndex: number = 0;
  onNewMessage: ((msg: Message) => void) | null = null;

  startMockMessages(): void {
    if (this.timerId !== -1) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'Mock messages started');
    this.timerId = setInterval(() => {
      this.generateMockMessage();
    }, AppConstants.MOCK_MESSAGE_INTERVAL);
    // 启动后5s发送第一条，方便测试
    setTimeout(() => {
      this.generateMockMessage();
    }, 5000);
  }

  stopMockMessages(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
      hilog.info(DOMAIN, TAG, 'Mock messages stopped');
    }
  }

  private generateMockMessage(): void {
    const msg: Message = {
      id: `msg_${Date.now()}`,
      content: MOCK_MESSAGES[this.mockIndex % MOCK_MESSAGES.length],
      timestamp: Date.now(),
      isRead: false
    };
    this.mockIndex++;

    if (this.messageQueue.length >= AppConstants.MESSAGE_QUEUE_MAX) {
      this.messageQueue.shift(); // 丢弃最早的
    }
    this.messageQueue.push(msg);

    hilog.info(DOMAIN, TAG, 'New mock message: %{public}s', msg.content);
    if (this.onNewMessage) {
      this.onNewMessage(msg);
    }
  }

  getMessageQueue(): Message[] {
    return this.messageQueue.filter(m => !m.isRead);
  }

  markAsRead(messageId: string): void {
    const msg = this.messageQueue.find(m => m.id === messageId);
    if (msg) {
      msg.isRead = true;
      hilog.info(DOMAIN, TAG, '[STUB] markAsRead: %{public}s', messageId);
    }
  }

  popNextUnread(): Message | null {
    const unread = this.messageQueue.find(m => !m.isRead);
    return unread ?? null;
  }
}
```

- [ ] **Step 2: 实现 FeedbackService**

```typescript
// entry/src/main/ets/services/FeedbackService.ets

import { hilog } from '@kit.PerformanceAnalysisKit';
import { FeedbackType } from '../models/RobotState';

const DOMAIN = 0x0001;
const TAG = 'FeedbackService';

export class FeedbackService {
  onAction(type: FeedbackType, messageId: string): void {
    hilog.info(DOMAIN, TAG, '[STUB] Feedback action: type=%{public}s, messageId=%{public}s',
      type, messageId);
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add entry/src/main/ets/services/MessageService.ets entry/src/main/ets/services/FeedbackService.ets
git commit -m "feat: add stubbed MessageService and FeedbackService"
```

---

## Task 7: UI组件 — RobotView

**Files:**
- Create: `entry/src/main/ets/components/RobotView.ets`

- [ ] **Step 1: 实现 RobotView 组件**

机器人图标组件，接收动画状态参数，通过属性动画呈现不同状态效果。

```typescript
// entry/src/main/ets/components/RobotView.ets

import { AppConstants } from '../constants/AppConstants';
import { RobotState } from '../models/RobotState';
import { AnimationManager, AnimationParams } from '../managers/AnimationManager';

@Component
export struct RobotView {
  @Prop robotState: RobotState = RobotState.IDLE;
  private animationManager: AnimationManager = new AnimationManager();
  @State private scaleVal: number = 1.0;
  @State private rotateVal: number = 0;
  @State private translateYVal: number = 0;
  private animTimerId: number = -1;

  aboutToAppear(): void {
    this.startAnimation();
  }

  aboutToDisappear(): void {
    this.stopAnimation();
  }

  private startAnimation(): void {
    this.animationManager.setState(this.robotState);
    this.runAnimationCycle();
  }

  private stopAnimation(): void {
    if (this.animTimerId !== -1) {
      clearTimeout(this.animTimerId);
      this.animTimerId = -1;
    }
  }

  private runAnimationCycle(): void {
    if (this.robotState !== this.animationManager.getCurrentState()) {
      this.animationManager.setState(this.robotState);
    }
    const params: AnimationParams = this.animationManager.getAnimationParams();

    animateTo({
      duration: params.duration,
      curve: params.curve,
      onFinish: () => {
        // 循环动画：IDLE 和 MESSAGE 持续播放, DELETE 持续抖动
        if (this.robotState === RobotState.IDLE ||
            this.robotState === RobotState.MESSAGE ||
            this.robotState === RobotState.DELETE) {
          this.animTimerId = setTimeout(() => {
            this.runAnimationCycle();
          }, 0);
        }
      }
    }, () => {
      this.scaleVal = params.scaleX;
      this.rotateVal = params.rotate;
      this.translateYVal = params.translateY;
    });
  }

  build() {
    Image($r('app.media.robot_icon'))
      .width(AppConstants.ROBOT_ICON_SIZE)
      .height(AppConstants.ROBOT_ICON_SIZE)
      .borderRadius(AppConstants.ROBOT_ICON_SIZE / 2)
      .scale({ x: this.scaleVal, y: this.scaleVal })
      .rotate({ angle: this.rotateVal })
      .translate({ y: this.translateYVal })
      .shadow({
        radius: 8,
        color: '#40000000',
        offsetX: 2,
        offsetY: 2
      })
  }
}
```

- [ ] **Step 2: 添加一个简单的机器人占位图标**

在 `entry/src/main/resources/base/media/` 目录下需要一个 `robot_icon.png`。暂时复制 `startIcon.png` 作为占位：

```bash
cp entry/src/main/resources/base/media/startIcon.png entry/src/main/resources/base/media/robot_icon.png
```

- [ ] **Step 3: Commit**

```bash
git add entry/src/main/ets/components/RobotView.ets entry/src/main/resources/base/media/robot_icon.png
git commit -m "feat: add RobotView component with property animations"
```

---

## Task 8: UI组件 — MessageBubble + DeleteZone

**Files:**
- Create: `entry/src/main/ets/components/MessageBubble.ets`
- Create: `entry/src/main/ets/components/DeleteZone.ets`

- [ ] **Step 1: 实现 MessageBubble 组件**

```typescript
// entry/src/main/ets/components/MessageBubble.ets

import { AppConstants } from '../constants/AppConstants';
import { Message } from '../models/RobotState';

@Component
export struct MessageBubble {
  @Prop message: Message | null = null;
  @Prop isVisible: boolean = false;
  onConfirm: (() => void) | null = null;
  @State private opacity: number = 0;

  aboutToAppear(): void {
    if (this.isVisible) {
      this.fadeIn();
    }
  }

  private fadeIn(): void {
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.opacity = 1;
    });
  }

  private fadeOut(): void {
    animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
      this.opacity = 0;
    });
  }

  build() {
    if (this.isVisible && this.message) {
      Column() {
        // 消息内容
        Text(this.message.content)
          .fontSize(14)
          .fontColor('#333333')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })

        // 底部确认栏
        Row() {
          Text($r('app.string.message_confirm_bar'))
            .fontSize(12)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .height(28)
        .backgroundColor('#4CAF50')
        .borderRadius({ bottomLeft: 12, bottomRight: 12 })
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.onConfirm) {
            this.onConfirm();
          }
        })
      }
      .constraintSize({
        maxWidth: AppConstants.BUBBLE_MAX_WIDTH,
        maxHeight: AppConstants.BUBBLE_MAX_HEIGHT
      })
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .shadow({
        radius: 6,
        color: '#30000000',
        offsetX: 0,
        offsetY: 2
      })
      .opacity(this.opacity)
    }
  }
}
```

- [ ] **Step 2: 实现 DeleteZone 组件**

```typescript
// entry/src/main/ets/components/DeleteZone.ets

import { AppConstants } from '../constants/AppConstants';

@Component
export struct DeleteZone {
  @Prop isVisible: boolean = false;
  @Prop isHighlighted: boolean = false;
  @State private translateY: number = -AppConstants.DELETE_ZONE_HEIGHT;

  onVisibilityChange(): void {
    animateTo({
      duration: AppConstants.DELETE_ZONE_ANIM_DURATION,
      curve: Curve.EaseOut
    }, () => {
      this.translateY = this.isVisible ? 0 : -AppConstants.DELETE_ZONE_HEIGHT;
    });
  }

  build() {
    Row() {
      Image($r('sys.media.ohos_ic_public_remove_filled'))
        .width(24)
        .height(24)
        .fillColor(this.isHighlighted ? '#FFFFFF' : '#FFCCCC')

      Text('拖到此处删除')
        .fontSize(14)
        .fontColor(this.isHighlighted ? '#FFFFFF' : '#FFCCCC')
        .margin({ left: 8 })
    }
    .width('100%')
    .height(AppConstants.DELETE_ZONE_HEIGHT)
    .backgroundColor(this.isHighlighted ? '#FF1744' : '#EF5350')
    .justifyContent(FlexAlign.Center)
    .translate({ y: this.translateY })
    .position({ x: 0, y: 0 })
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add entry/src/main/ets/components/MessageBubble.ets entry/src/main/ets/components/DeleteZone.ets
git commit -m "feat: add MessageBubble and DeleteZone UI components"
```

---

## Task 9: FloatWindowPage — 悬浮窗主页面（组装 + 手势）

**Files:**
- Create: `entry/src/main/ets/pages/FloatWindowPage.ets`
- Modify: `entry/src/main/resources/base/profile/main_pages.json`

这是最核心的页面，组装所有组件并处理手势逻辑。

- [ ] **Step 1: 实现 FloatWindowPage**

```typescript
// entry/src/main/ets/pages/FloatWindowPage.ets

import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { AppConstants } from '../constants/AppConstants';
import { RobotState, Message, FeedbackType, Position, EdgePosition } from '../models/RobotState';
import { FloatWindowManager } from '../managers/FloatWindowManager';
import { DragManager } from '../managers/DragManager';
import { MessageService } from '../services/MessageService';
import { FeedbackService } from '../services/FeedbackService';
import { RobotView } from '../components/RobotView';
import { MessageBubble } from '../components/MessageBubble';
import { DeleteZone } from '../components/DeleteZone';
import { ScreenUtils } from '../utils/ScreenUtils';

const DOMAIN = 0x0001;
const TAG = 'FloatWindowPage';

@Entry
@Component
struct FloatWindowPage {
  // Managers & Services
  private floatWindowManager: FloatWindowManager = FloatWindowManager.getInstance();
  private dragManager: DragManager = new DragManager();
  private messageService: MessageService = new MessageService();
  private feedbackService: FeedbackService = new FeedbackService();

  // 状态
  @State robotState: RobotState = RobotState.IDLE;
  @State isDeleteMode: boolean = false;
  @State isDeleteZoneVisible: boolean = false;
  @State isDeleteZoneHighlighted: boolean = false;
  @State currentMessage: Message | null = null;
  @State isBubbleVisible: boolean = false;

  // 内部控制
  private bubbleTimerId: number = -1;
  private bubbleStartTime: number = 0; // 气泡显示开始时间
  private lastTapTime: number = 0;
  private deleteModeDragStartPos: Position = { x: 0, y: 0 };
  @State currentEdge: EdgePosition = EdgePosition.RIGHT; // 当前吸附边，用于气泡方向

  aboutToAppear(): void {
    // 设置消息回调
    this.messageService.onNewMessage = (msg: Message) => {
      this.handleNewMessage(msg);
    };
    this.messageService.startMockMessages();
  }

  aboutToDisappear(): void {
    this.messageService.stopMockMessages();
    this.clearBubbleTimer();
  }

  // ===== 消息处理 =====

  private handleNewMessage(msg: Message): void {
    if (this.isDeleteMode) {
      return; // 删除流程中抑制消息弹出
    }
    if (this.isBubbleVisible) {
      return; // 当前有消息显示，排队等待
    }
    this.showBubble(msg);
  }

  private showBubble(msg: Message): void {
    this.currentMessage = msg;
    this.isBubbleVisible = true;
    this.robotState = RobotState.MESSAGE;
    this.startBubbleTimer();
  }

  private dismissBubble(): void {
    this.clearBubbleTimer();
    this.isBubbleVisible = false;
    this.currentMessage = null;
    this.robotState = RobotState.IDLE;

    // 检查队列中是否有下一条未读消息
    setTimeout(() => {
      const next = this.messageService.popNextUnread();
      if (next && !this.isDeleteMode) {
        this.showBubble(next);
      }
    }, 500);
  }

  private showBubbleWithRemaining(msg: Message, remainingMs: number): void {
    this.currentMessage = msg;
    this.isBubbleVisible = true;
    this.robotState = RobotState.MESSAGE;
    this.startBubbleTimerWithDuration(remainingMs > 0 ? remainingMs : AppConstants.BUBBLE_DISMISS_TIME);
  }

  private startBubbleTimerWithDuration(durationMs: number): void {
    this.clearBubbleTimer();
    this.bubbleStartTime = Date.now();
    this.bubbleTimerId = setTimeout(() => {
      this.dismissBubble();
    }, durationMs);
  }

  private startBubbleTimer(): void {
    this.startBubbleTimerWithDuration(AppConstants.BUBBLE_DISMISS_TIME);
  }

  private getBubbleRemainingTime(): number {
    if (this.bubbleStartTime === 0) return AppConstants.BUBBLE_DISMISS_TIME;
    const elapsed = Date.now() - this.bubbleStartTime;
    return Math.max(0, AppConstants.BUBBLE_DISMISS_TIME - elapsed);
  }

  private updateCurrentEdge(): void {
    const pos = this.floatWindowManager.getWindowPosition();
    const windowSizePx = ScreenUtils.vpToPx(AppConstants.FLOAT_WINDOW_SIZE);
    const cx = pos.x + windowSizePx / 2;
    const cy = pos.y + windowSizePx / 2;
    this.currentEdge = this.dragManager.calcNearestEdge(
      cx, cy, ScreenUtils.getScreenWidthPx(), ScreenUtils.getScreenHeightPx()
    );
  }

  private clearBubbleTimer(): void {
    if (this.bubbleTimerId !== -1) {
      clearTimeout(this.bubbleTimerId);
      this.bubbleTimerId = -1;
    }
  }

  private onBubbleConfirm(): void {
    if (this.currentMessage) {
      this.messageService.markAsRead(this.currentMessage.id);
      this.feedbackService.onAction(FeedbackType.CONFIRM, this.currentMessage.id);
    }
    this.dismissBubble();
  }

  // ===== 点击 =====

  private onTap(): void {
    const now = Date.now();
    if (now - this.lastTapTime < AppConstants.TAP_DEBOUNCE) {
      return;
    }
    this.lastTapTime = now;

    hilog.info(DOMAIN, TAG, 'Robot tapped, opening app');
    // 隐藏悬浮窗，通过 startAbility 拉起主窗口（触发 onForeground/onBackground 生命周期）
    this.floatWindowManager.hideFloatWindow();
    const context = getContext(this) as common.UIAbilityContext;
    context.startAbility({
      bundleName: 'com.example.myapplication',
      abilityName: 'EntryAbility',
      parameters: { 'showMainPage': true }
    });
  }

  // ===== 拖拽 =====

  private onDragStart(): void {
    this.robotState = RobotState.DRAGGING;
    this.dragManager.onDragStart();
    // 拖拽中隐藏气泡，保存当前消息和剩余时间
    if (this.isBubbleVisible && this.currentMessage) {
      this.draggedMessage = this.currentMessage;
      this.draggedBubbleRemainingMs = this.getBubbleRemainingTime();
      this.clearBubbleTimer();
      this.isBubbleVisible = false;
    } else {
      this.draggedMessage = null;
    }
  }

  private onDragUpdate(offsetX: number, offsetY: number): void {
    this.dragManager.onDragUpdate(offsetX, offsetY);
  }

  private draggedMessage: Message | null = null; // 拖拽前正在显示的消息
  private draggedBubbleRemainingMs: number = 0; // 拖拽前气泡剩余时间

  private onDragEnd(): void {
    const snapPos = this.dragManager.calcSnapPosition();
    const currentPos = this.floatWindowManager.getWindowPosition();
    // 使用 spring 动画吸附到边缘
    const stepCount = 15;
    const dx = (snapPos.x - currentPos.x) / stepCount;
    const dy = (snapPos.y - currentPos.y) / stepCount;
    let step = 0;
    const animInterval = setInterval(() => {
      step++;
      // 简单的 ease-out 缓动
      const progress = 1 - Math.pow(1 - step / stepCount, 3);
      const x = currentPos.x + (snapPos.x - currentPos.x) * progress;
      const y = currentPos.y + (snapPos.y - currentPos.y) * progress;
      this.floatWindowManager.moveWindow(x, y);
      if (step >= stepCount) {
        clearInterval(animInterval);
        this.floatWindowManager.moveWindow(snapPos.x, snapPos.y);
        this.robotState = RobotState.IDLE;
        // 更新当前吸附边（用于气泡方向计算）
        this.updateCurrentEdge();
        // 恢复拖拽前的消息气泡（同一条消息，恢复剩余倒计时）
        if (this.draggedMessage && !this.draggedMessage.isRead) {
          this.showBubbleWithRemaining(this.draggedMessage, this.draggedBubbleRemainingMs);
          this.draggedMessage = null;
        }
      }
    }, 16); // ~60fps
  }

  // ===== 长按删除 =====

  private onLongPress(): void {
    this.isDeleteMode = true;
    this.isDeleteZoneVisible = true;
    this.robotState = RobotState.DELETE;
    this.deleteModeDragStartPos = this.floatWindowManager.getWindowPosition();
    hilog.info(DOMAIN, TAG, 'Delete mode activated');
  }

  private onDeleteModeTouchMove(touchX: number, touchY: number): void {
    if (!this.isDeleteMode) {
      return;
    }
    // 判断是否在删除栏区域
    this.isDeleteZoneHighlighted = this.dragManager.isInDeleteZone(
      ScreenUtils.vpToPx(touchY)
    );
  }

  private onDeleteModeTouchEnd(touchY: number): void {
    if (!this.isDeleteMode) {
      return;
    }
    const inDeleteZone = this.dragManager.isInDeleteZone(ScreenUtils.vpToPx(touchY));

    if (inDeleteZone) {
      this.showDeleteConfirmDialog();
    } else {
      this.exitDeleteMode();
    }
  }

  private showDeleteConfirmDialog(): void {
    AlertDialog.show({
      title: $r('app.string.delete_confirm_title'),
      message: $r('app.string.delete_confirm_message'),
      primaryButton: {
        value: $r('app.string.cancel_button'),
        action: () => {
          this.exitDeleteMode();
        }
      },
      secondaryButton: {
        value: $r('app.string.confirm_button'),
        fontColor: '#FF1744',
        action: () => {
          this.floatWindowManager.destroyFloatWindow();
          // 退出进程
          const context = getContext(this) as common.UIAbilityContext;
          context.terminateSelf();
        }
      },
      cancel: () => {
        this.exitDeleteMode(); // 返回键关闭等同取消
      }
    });
  }

  private exitDeleteMode(): void {
    this.isDeleteMode = false;
    this.isDeleteZoneVisible = false;
    this.isDeleteZoneHighlighted = false;
    this.robotState = RobotState.IDLE;
    // 回到原位
    this.floatWindowManager.moveWindow(
      this.deleteModeDragStartPos.x,
      this.deleteModeDragStartPos.y
    );
  }

  // 根据吸附边计算气泡在 Stack 内的偏移位置
  private getBubbleOffset(): Position {
    const robotSize = AppConstants.ROBOT_ICON_SIZE;
    const windowSize = AppConstants.FLOAT_WINDOW_SIZE;
    const center = windowSize / 2;
    switch (this.currentEdge) {
      case EdgePosition.RIGHT:
        // 机器人在右侧，气泡在左侧
        return { x: center - AppConstants.BUBBLE_MAX_WIDTH - robotSize / 2, y: center - AppConstants.BUBBLE_MAX_HEIGHT / 2 };
      case EdgePosition.LEFT:
        // 机器人在左侧，气泡在右侧
        return { x: center + robotSize / 2, y: center - AppConstants.BUBBLE_MAX_HEIGHT / 2 };
      case EdgePosition.TOP:
        return { x: center - AppConstants.BUBBLE_MAX_WIDTH / 2, y: center + robotSize / 2 };
      case EdgePosition.BOTTOM:
        return { x: center - AppConstants.BUBBLE_MAX_WIDTH / 2, y: center - AppConstants.BUBBLE_MAX_HEIGHT - robotSize / 2 };
      default:
        return { x: center - AppConstants.BUBBLE_MAX_WIDTH - robotSize / 2, y: center - AppConstants.BUBBLE_MAX_HEIGHT / 2 };
    }
  }

  build() {
    Stack() {
      // 删除栏（覆盖在最顶层，但由于悬浮窗只有300x300，这里是窗口内的相对位置）
      // 注意：删除栏实际应该通过另一个窗口或全局UI显示，此处简化为窗口内部
      if (this.isDeleteZoneVisible) {
        DeleteZone({
          isVisible: this.isDeleteZoneVisible,
          isHighlighted: this.isDeleteZoneHighlighted
        })
      }

      // 消息气泡（根据吸附边定位）
      if (this.isBubbleVisible) {
        MessageBubble({
          message: this.currentMessage,
          isVisible: this.isBubbleVisible,
          onConfirm: () => this.onBubbleConfirm()
        })
        .position({
          x: this.getBubbleOffset().x,
          y: this.getBubbleOffset().y
        })
      }

      // 机器人（始终居中显示）
      RobotView({ robotState: this.robotState })
        .position({
          x: (AppConstants.FLOAT_WINDOW_SIZE - AppConstants.ROBOT_ICON_SIZE) / 2,
          y: (AppConstants.FLOAT_WINDOW_SIZE - AppConstants.ROBOT_ICON_SIZE) / 2
        })
    }
    .width(AppConstants.FLOAT_WINDOW_SIZE)
    .height(AppConstants.FLOAT_WINDOW_SIZE)
    .backgroundColor('#00000000')
    // 手势处理（仅在非删除模式下生效，删除模式通过 onTouch 处理）
    .gesture(
      this.isDeleteMode ? undefined :
      GestureGroup(GestureMode.Exclusive,
        // 长按 → 删除模式
        LongPressGesture({ repeat: false, duration: AppConstants.LONG_PRESS_DURATION })
          .onAction(() => {
            this.onLongPress();
          }),
        // 拖拽
        PanGesture({ distance: AppConstants.PAN_DISTANCE_THRESHOLD })
          .onActionStart(() => {
            this.onDragStart();
          })
          .onActionUpdate((event: GestureEvent) => {
            this.onDragUpdate(event.offsetX, event.offsetY);
          })
          .onActionEnd(() => {
            this.onDragEnd();
          }),
        // 点击
        TapGesture()
          .onAction(() => {
            this.onTap();
          })
      )
    )
    // 删除模式下的触摸跟踪
    .onTouch((event: TouchEvent) => {
      if (!this.isDeleteMode) {
        return;
      }
      const touch = event.touches[0];
      if (event.type === TouchType.Move) {
        this.onDeleteModeTouchMove(touch.screenX, touch.screenY);
        // 删除模式下跟随手指移动（窗口中心对准手指位置）
        const halfWindowPx = ScreenUtils.vpToPx(AppConstants.FLOAT_WINDOW_SIZE) / 2;
        this.floatWindowManager.moveWindow(
          ScreenUtils.vpToPx(touch.screenX) - halfWindowPx,
          ScreenUtils.vpToPx(touch.screenY) - halfWindowPx
        );
      } else if (event.type === TouchType.Up) {
        this.onDeleteModeTouchEnd(touch.screenY);
      }
    })
  }
}
```

- [ ] **Step 2: 更新页面路由配置**

修改 `entry/src/main/resources/base/profile/main_pages.json`：

```json
{
  "src": [
    "pages/Index",
    "pages/FloatWindowPage",
    "pages/MainPage"
  ]
}
```

- [ ] **Step 3: Commit**

```bash
git add entry/src/main/ets/pages/FloatWindowPage.ets entry/src/main/resources/base/profile/main_pages.json
git commit -m "feat: add FloatWindowPage with gesture handling and message flow"
```

---

## Task 10: MainPage — 占位主页面

**Files:**
- Create: `entry/src/main/ets/pages/MainPage.ets`

- [ ] **Step 1: 创建占位主页面**

```typescript
// entry/src/main/ets/pages/MainPage.ets

import { router } from '@kit.ArkUI';

@Entry
@Component
struct MainPage {
  build() {
    Column() {
      Text($r('app.string.main_page_title'))
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')

      Text('点击返回键退出，悬浮机器人将重新出现')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ top: 16 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F5F5F5')
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add entry/src/main/ets/pages/MainPage.ets
git commit -m "feat: add placeholder MainPage"
```

---

## Task 11: EntryAbility 集成 — 权限申请 + 悬浮窗启动

**Files:**
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`

- [ ] **Step 1: 修改 EntryAbility**

在 `onWindowStageCreate` 中申请权限并创建悬浮窗，在 `onBackground` 中恢复悬浮窗，在 `onForeground` 中隐藏悬浮窗。

```typescript
// entry/src/main/ets/entryability/EntryAbility.ets
// 完整替换内容

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
  private hasUserTappedRobot: boolean = false; // 防止首次启动时 onForeground 隐藏悬浮窗

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

    // 加载主页
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Content loaded');
    });

    // 申请悬浮窗权限并创建悬浮窗
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

  // 处理从悬浮窗点击机器人后 startAbility 带来的 want
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', 'Ability onNewWant');
    if (want.parameters && want.parameters['showMainPage'] === true) {
      this.hasUserTappedRobot = true;
      // 导航到 MainPage
      router.pushUrl({ url: 'pages/MainPage' });
    }
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', 'Ability onForeground');
    // 仅在用户主动点击机器人进入App后，才在回到前台时隐藏悬浮窗
    // 首次启动时不隐藏，否则悬浮窗刚创建就被隐藏
    if (this.hasUserTappedRobot) {
      this.floatWindowManager.hideFloatWindow();
    }
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', 'Ability onBackground');
    // App 退到后台时显示悬浮窗
    this.floatWindowManager.showFloatWindow();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add entry/src/main/ets/entryability/EntryAbility.ets
git commit -m "feat: integrate permission request and float window lifecycle in EntryAbility"
```

---

## Task 12: 验证与整体检查

> **注意：** 资源文件（module.json5、string.json、main_pages.json）已在 Task 2 中一次性完成更新，无需重复修改。

- [ ] **Step 1: 检查所有文件导入路径是否正确**

确认每个文件的 `import` 路径与实际项目结构一致。

- [ ] **Step 2: 在 DevEco Studio 中打开项目**

打开 `D:/proj/floating-robot`，检查：
- 无红色报错
- Previewer 可以加载 FloatWindowPage
- module.json5 权限声明无语法错误

- [ ] **Step 3: 连接设备/模拟器运行测试**

验证：
1. 应用启动 → 弹出权限申请 → 授权后右下角出现机器人
2. 机器人有呼吸动画
3. 拖拽机器人 → 松手后吸附到最近边缘
4. 5s 后弹出模拟消息气泡 → 10s 后自动消失
5. 点击气泡 bar → 气泡消失并打印日志
6. 长按机器人 → 顶部出现删除栏 → 拖入删除栏 → 弹出确认框
7. 点击机器人 → 进入空白主页
8. 主页返回/退到后台 → 机器人重新出现

- [ ] **Step 4: 修复发现的问题**

根据测试结果修复 bug。

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "fix: address issues found during integration testing"
```

- [ ] **Step 6: Push to remote**

```bash
git push -u origin master
```
