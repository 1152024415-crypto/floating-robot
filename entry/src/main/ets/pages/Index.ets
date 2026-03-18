@Entry
@Component
struct Index {
  build() {
    Column({ space: 16 }) {
      Image($r('app.media.robot_icon'))
        .width(80)
        .height(80)
        .borderRadius(40)
        .shadow({
          radius: 12,
          color: '#30000000',
          offsetX: 0,
          offsetY: 4
        })

      Text($r('app.string.app_name'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')

      Text('退到后台即可使用悬浮助手')
        .fontSize(14)
        .fontColor('#999999')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F5F5F5')
  }
}
