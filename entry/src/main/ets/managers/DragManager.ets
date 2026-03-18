import { AppConstants } from '../constants/AppConstants';
import { EdgePosition, Position } from '../models/RobotState';
import { ScreenUtils } from '../utils/ScreenUtils';
import { FloatWindowManager } from './FloatWindowManager';

export class DragManager {
  private floatWindowManager: FloatWindowManager;
  private dragStartPositionPx: Position = { x: 0, y: 0 };
  private isAnimating: boolean = false;
  private lastMoveTime: number = 0;
  private pendingX: number = 0;
  private pendingY: number = 0;
  private throttleTimer: number = -1;

  constructor() {
    this.floatWindowManager = FloatWindowManager.getInstance();
  }

  onDragStart(): void {
    this.isAnimating = false;
    this.lastMoveTime = 0;
    this.dragStartPositionPx = this.floatWindowManager.getWindowPosition();
  }

  onDragUpdate(offsetXVp: number, offsetYVp: number): void {
    const offsetXPx = ScreenUtils.vpToPx(offsetXVp);
    const offsetYPx = ScreenUtils.vpToPx(offsetYVp);
    this.pendingX = this.dragStartPositionPx.x + offsetXPx;
    this.pendingY = this.dragStartPositionPx.y + offsetYPx;

    const now = Date.now();
    if (now - this.lastMoveTime >= 30) {
      // 直接执行
      this.lastMoveTime = now;
      this.floatWindowManager.moveWindow(this.pendingX, this.pendingY);
    } else if (this.throttleTimer === -1) {
      // 延迟到下一个时间窗口执行
      this.throttleTimer = setTimeout(() => {
        this.throttleTimer = -1;
        this.lastMoveTime = Date.now();
        this.floatWindowManager.moveWindow(this.pendingX, this.pendingY);
      }, 30 - (now - this.lastMoveTime));
    }
  }

  calcSnapPosition(): Position {
    const currentPos = this.floatWindowManager.getWindowPosition();
    const windowSizePx = ScreenUtils.vpToPx(AppConstants.FLOAT_WINDOW_SIZE);
    const robotSizePx = ScreenUtils.vpToPx(AppConstants.ROBOT_ICON_SIZE);
    const marginPx = ScreenUtils.vpToPx(AppConstants.EDGE_SNAP_MARGIN);
    const screenW = ScreenUtils.getScreenWidthPx();
    const screenH = ScreenUtils.getScreenHeightPx();

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
    return { x: this.dragStartPositionPx.x, y: this.dragStartPositionPx.y };
  }
}
