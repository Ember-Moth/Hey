import { AppColor, FontSz, Space } from '../theme/Theme';

@Component
export struct SectionHeader {
  title: string = '';
  detail: string = '';

  build() {
    Row() {
      Text(this.title)
        .fontSize(FontSz.headline)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.brand)
        .layoutWeight(1)
      if (this.detail.length > 0) {
        Text(this.detail)
          .fontSize(FontSz.footnote)
          .fontColor(AppColor.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .padding({ left: Space.xxl, right: Space.xxl, top: Space.xxl, bottom: Space.sm })
  }
}
