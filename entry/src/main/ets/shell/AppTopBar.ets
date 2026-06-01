@Component
export struct AppTopBar {
  title: string = '';
  summary: string = '';
  statusLabel: string = '';
  statusColor: string = '#374151';
  statusBackground: string = '#F3F4F6';

  build() {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        Text(this.summary)
          .fontSize(12)
          .fontColor('#6B7280')
      }
      .layoutWeight(1)

      Text(this.statusLabel)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.statusColor)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor(this.statusBackground)
        .borderRadius(6)
    }
    .width('100%')
    .height(70)
    .padding({ left: 14, right: 14 })
    .backgroundColor('#FFFFFF')
  }
}
