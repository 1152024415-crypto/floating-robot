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
  @State private eyeBlink: boolean = false;
  private animTimerId: number = -1;
  private blinkTimerId: number = -1;

  aboutToAppear(): void {
    this.startAnimation();
    this.startBlinking();
  }

  aboutToDisappear(): void {
    this.stopAnimation();
    if (this.blinkTimerId !== -1) {
      clearTimeout(this.blinkTimerId);
    }
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

  private startBlinking(): void {
    // 随机间隔眨眼
    const nextBlink = 2000 + Math.random() * 3000;
    this.blinkTimerId = setTimeout(() => {
      this.eyeBlink = true;
      setTimeout(() => {
        this.eyeBlink = false;
        this.startBlinking();
      }, 150);
    }, nextBlink);
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
    // 纯组件绘制的卡通机器人
    Stack({ alignContent: Alignment.Center }) {
      // 身体/头部 - 圆角矩形
      Column() {
        // 天线
        Row() {
          Column()
            .width(3)
            .height(8)
            .backgroundColor('#5B9BD5')
            .borderRadius(1.5)
          Circle()
            .width(6)
            .height(6)
            .fill('#FF6B6B')
            .offset({ y: -2 })
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Bottom)
        .margin({ bottom: -2 })

        // 脸部
        Stack({ alignContent: Alignment.Center }) {
          // 脸背景
          Column()
            .width(38)
            .height(30)
            .borderRadius(12)
            .backgroundColor('#5B9BD5')

          // 眼睛区域
          Row({ space: 8 }) {
            // 左眼
            Column()
              .width(this.eyeBlink ? 8 : 8)
              .height(this.eyeBlink ? 2 : 8)
              .borderRadius(this.eyeBlink ? 1 : 4)
              .backgroundColor('#FFFFFF')

            // 右眼
            Column()
              .width(this.eyeBlink ? 8 : 8)
              .height(this.eyeBlink ? 2 : 8)
              .borderRadius(this.eyeBlink ? 1 : 4)
              .backgroundColor('#FFFFFF')
          }
          .offset({ y: -2 })

          // 嘴巴
          Column()
            .width(this.robotState === RobotState.MESSAGE ? 10 : 14)
            .height(this.robotState === RobotState.MESSAGE ? 6 : 3)
            .borderRadius(this.robotState === RobotState.MESSAGE ? 5 : 1.5)
            .backgroundColor(this.robotState === RobotState.MESSAGE ? '#FF6B6B' : '#FFFFFF')
            .offset({ y: 8 })
        }
      }
    }
    .width(AppConstants.ROBOT_ICON_SIZE)
    .height(AppConstants.ROBOT_ICON_SIZE)
    .borderRadius(AppConstants.ROBOT_ICON_SIZE / 2)
    .backgroundColor('#E8F4FD')
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
