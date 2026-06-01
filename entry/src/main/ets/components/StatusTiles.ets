@Component
export struct MetricTile {
  label: string = '';
  value: string = '';

  build() {
    Column({ space: 4 }) {
      Text(this.label)
        .fontSize(12)
        .fontColor('#6B7280')
      Text(this.value)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#111827')
    }
    .layoutWeight(1)
    .height(64)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F9FAFB')
    .borderRadius(6)
  }
}

@Component
export struct FlagTile {
  label: string = '';
  active: boolean = false;

  build() {
    Row({ space: 8 }) {
      Circle()
        .width(8)
        .height(8)
        .fill(this.active ? '#16A34A' : '#9CA3AF')
      Text(this.label)
        .fontSize(13)
        .fontColor('#374151')
    }
    .height(34)
    .padding({ left: 10, right: 10 })
    .backgroundColor('#F9FAFB')
    .borderRadius(6)
  }
}
