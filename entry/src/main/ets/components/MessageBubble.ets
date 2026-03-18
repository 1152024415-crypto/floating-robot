import { Message } from '../models/RobotState';

@Component
export struct MessageBubble {
  @Prop message: Message | null = null;
  @Prop isVisible: boolean = false;
  onLike: (() => void) | null = null;
  onDislike: (() => void) | null = null;
  onClose: (() => void) | null = null;
  @State private bubbleOpacity: number = 0;
  @State private bubbleScale: number = 0.8;

  aboutToAppear(): void {
    if (this.isVisible) {
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
        // 顶部：关闭按钮
        Row() {
          Blank()
          Text('x')
            .fontSize(14)
            .fontColor('#999999')
            .onClick(() => {
              if (this.onClose) {
                this.onClose();
              }
            })
        }
        .width('100%')
        .padding({ right: 8, top: 4 })

        // 消息内容
        Text(this.message.content)
          .fontSize(13)
          .fontColor('#333333')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 10, right: 10, bottom: 6 })

        // 反馈栏
        Row({ space: 16 }) {
          Text('👍')
            .fontSize(16)
            .onClick(() => {
              if (this.onLike) {
                this.onLike();
              }
            })
          Text('👎')
            .fontSize(16)
            .onClick(() => {
              if (this.onDislike) {
                this.onDislike();
              }
            })
        }
        .width('100%')
        .height(28)
        .justifyContent(FlexAlign.Center)
        .borderWidth({ top: 0.5 })
        .borderColor('#E0E0E0')
      }
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
