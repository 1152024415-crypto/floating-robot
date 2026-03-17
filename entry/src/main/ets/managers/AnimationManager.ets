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
  private animationPhase: boolean = false;

  setState(state: RobotState): void {
    this.currentState = state;
    this.animationPhase = false;
  }

  getCurrentState(): RobotState {
    return this.currentState;
  }

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
