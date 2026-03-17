import { AppConstants } from '../constants/AppConstants';
import { Message } from '../models/RobotState';

@Component
export struct MessageBubble {
  @Prop message: Message | null = null;
  @Prop isVisible: boolean = false;
  onConfirm: (() => void) | null = null;
  @State private bubbleOpacity: number = 0;

  aboutToAppear(): void {
    if (this.isVisible) {
      this.fadeIn();
    }
  }

  private fadeIn(): void {
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.bubbleOpacity = 1;
    });
  }

  private fadeOut(): void {
    animateTo({ duration: 200, curve: Curve.EaseIn }, () => {
      this.bubbleOpacity = 0;
    });
  }

  build() {
    if (this.isVisible && this.message) {
      Column() {
        Text(this.message.content)
          .fontSize(14)
          .fontColor('#333333')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })

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
      .opacity(this.bubbleOpacity)
    }
  }
}
