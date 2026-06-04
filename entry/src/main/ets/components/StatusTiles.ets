import { AppColor, FontSz, Radius, Space } from '../theme/Theme';

@Component
export struct MetricTile {
  label: string = '';
  value: string = '';

  build() {
    Column({ space: Space.xs }) {
      Text(this.label)
        .fontSize(FontSz.footnote)
        .fontColor(AppColor.textSecondary)
      Text(this.value)
        .fontSize(FontSz.callout)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textPrimary)
    }
    .layoutWeight(1)
    .height(64)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppColor.surfaceAlt)
    .borderRadius(Radius.sm)
  }
}

@Component
export struct FlagTile {
  label: string = '';
  active: boolean = false;

  build() {
    Row({ space: Space.sm }) {
      Circle()
        .width(8)
        .height(8)
        .fill(this.active ? AppColor.success : AppColor.textTertiary)
      Text(this.label)
        .fontSize(FontSz.footnote)
        .fontColor(AppColor.textSecondary)
    }
    .height(34)
    .padding({ left: Space.md, right: Space.md })
    .backgroundColor(AppColor.surfaceAlt)
    .borderRadius(Radius.sm)
  }
}
