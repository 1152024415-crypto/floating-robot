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
  private bubbleStartTime: number = 0;
  private lastTapTime: number = 0;
  private deleteModeDragStartPos: Position = { x: 0, y: 0 };
  @State currentEdge: EdgePosition = EdgePosition.RIGHT;

  aboutToAppear(): void {
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
      return;
    }
    if (this.isBubbleVisible) {
      return;
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
    this.floatWindowManager.hideFloatWindow();
    const context = getContext(this) as common.UIAbilityContext;
    context.startAbility({
      bundleName: 'com.example.myapplication',
      abilityName: 'EntryAbility',
      parameters: { 'showMainPage': true }
    });
  }

  // ===== 拖拽 =====

  private draggedMessage: Message | null = null;
  private draggedBubbleRemainingMs: number = 0;

  private onDragStart(): void {
    this.robotState = RobotState.DRAGGING;
    this.dragManager.onDragStart();
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

  private onDragEnd(): void {
    const snapPos = this.dragManager.calcSnapPosition();
    const currentPos = this.floatWindowManager.getWindowPosition();
    const stepCount = 15;
    let step = 0;
    const animInterval = setInterval(() => {
      step++;
      const progress = 1 - Math.pow(1 - step / stepCount, 3);
      const x = currentPos.x + (snapPos.x - currentPos.x) * progress;
      const y = currentPos.y + (snapPos.y - currentPos.y) * progress;
      this.floatWindowManager.moveWindow(x, y);
      if (step >= stepCount) {
        clearInterval(animInterval);
        this.floatWindowManager.moveWindow(snapPos.x, snapPos.y);
        this.robotState = RobotState.IDLE;
        this.updateCurrentEdge();
        if (this.draggedMessage && !this.draggedMessage.isRead) {
          this.showBubbleWithRemaining(this.draggedMessage, this.draggedBubbleRemainingMs);
          this.draggedMessage = null;
        }
      }
    }, 16);
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
          const context = getContext(this) as common.UIAbilityContext;
          context.terminateSelf();
        }
      },
      cancel: () => {
        this.exitDeleteMode();
      }
    });
  }

  private exitDeleteMode(): void {
    this.isDeleteMode = false;
    this.isDeleteZoneVisible = false;
    this.isDeleteZoneHighlighted = false;
    this.robotState = RobotState.IDLE;
    this.floatWindowManager.moveWindow(
      this.deleteModeDragStartPos.x,
      this.deleteModeDragStartPos.y
    );
  }

  private getBubbleOffset(): Position {
    const robotSize = AppConstants.ROBOT_ICON_SIZE;
    const windowSize = AppConstants.FLOAT_WINDOW_SIZE;
    const center = windowSize / 2;
    switch (this.currentEdge) {
      case EdgePosition.RIGHT:
        return { x: center - AppConstants.BUBBLE_MAX_WIDTH - robotSize / 2, y: center - AppConstants.BUBBLE_MAX_HEIGHT / 2 };
      case EdgePosition.LEFT:
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
      if (this.isDeleteZoneVisible) {
        DeleteZone({
          isVisible: this.isDeleteZoneVisible,
          isHighlighted: this.isDeleteZoneHighlighted
        })
      }

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

      RobotView({ robotState: this.robotState })
        .position({
          x: (AppConstants.FLOAT_WINDOW_SIZE - AppConstants.ROBOT_ICON_SIZE) / 2,
          y: (AppConstants.FLOAT_WINDOW_SIZE - AppConstants.ROBOT_ICON_SIZE) / 2
        })
    }
    .width(AppConstants.FLOAT_WINDOW_SIZE)
    .height(AppConstants.FLOAT_WINDOW_SIZE)
    .backgroundColor('#00000000')
    .gesture(
      this.isDeleteMode ? undefined :
      GestureGroup(GestureMode.Exclusive,
        LongPressGesture({ repeat: false, duration: AppConstants.LONG_PRESS_DURATION })
          .onAction(() => {
            this.onLongPress();
          }),
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
        TapGesture()
          .onAction(() => {
            this.onTap();
          })
      )
    )
    .onTouch((event: TouchEvent) => {
      if (!this.isDeleteMode) {
        return;
      }
      const touch = event.touches[0];
      if (event.type === TouchType.Move) {
        this.onDeleteModeTouchMove(touch.screenX, touch.screenY);
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
