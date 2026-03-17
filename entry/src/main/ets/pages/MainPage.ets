@Entry
@Component
struct MainPage {
  build() {
    Column() {
      Text($r('app.string.main_page_title'))
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')

      Text('点击返回键退出，悬浮机器人将重新出现')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ top: 16 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F5F5F5')
  }
}
