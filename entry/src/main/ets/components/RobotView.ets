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
