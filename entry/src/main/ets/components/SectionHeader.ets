@Component
export struct SectionHeader {
  title: string = '';
  detail: string = '';

  build() {
    Row() {
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F97910')
        .layoutWeight(1)
      if (this.detail.length > 0) {
        Text(this.detail)
          .fontSize(12)
          .fontColor('#49454F')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 22, bottom: 8 })
  }
}
