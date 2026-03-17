import { AppConstants } from '../constants/AppConstants';

@Component
export struct DeleteZone {
  @Prop @Watch('onVisibilityChange') isVisible: boolean = false;
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
