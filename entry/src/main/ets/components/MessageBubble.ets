import { AppConstants } from '../constants/AppConstants';
import { Message } from '../models/RobotState';

@Component
export struct MessageBubble {
  @Prop message: Message | null = null;
  @Prop isVisible: boolean = false;
  onConfirm: (() => void) | null = null;
  @State private bubbleOpacity: number = 0;
  @State private bubbleScale: number = 0.8;

  aboutToAppear(): void {
    if (this.isVisible) {
      // 延迟一帧再执行动画，确保组件已渲染
      setTimeout(() => {
        animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
          this.bubbleOpacity = 1;
          this.bubbleScale = 1.0;
        });
      }, 16);
    }
  }

  build() {
    if (this.isVisible && this.message) {
      Column() {
        // 消息内容
        Text(this.message.content)
          .fontSize(13)
          .fontColor('#333333')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 10, right: 10, top: 6, bottom: 4 })

        // 已读确认条
        Text($r('app.string.message_confirm_bar'))
          .fontSize(11)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(22)
          .backgroundColor('#4CAF50')
          .borderRadius({ bottomLeft: 10, bottomRight: 10 })
          .onClick(() => {
            if (this.onConfirm) {
              this.onConfirm();
            }
          })
      }
      .constraintSize({
        maxWidth: AppConstants.BUBBLE_MAX_WIDTH
      })
      .backgroundColor('#FFFFFF')
      .borderRadius(10)
      .shadow({
        radius: 4,
        color: '#20000000',
        offsetX: 0,
        offsetY: 2
      })
      .opacity(this.bubbleOpacity)
      .scale({ x: this.bubbleScale, y: this.bubbleScale })
    }
  }
}
