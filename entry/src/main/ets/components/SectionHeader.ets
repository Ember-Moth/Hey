@Component
export struct SectionHeader {
  title: string = '';
  detail: string = '';

  build() {
    Row() {
      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .layoutWeight(1)
      Text(this.detail)
        .fontSize(12)
        .fontColor('#6B7280')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }
}
