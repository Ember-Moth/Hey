import { IconButton } from './IconButton';
import { AppColor, FontSz, Space } from '../theme/Theme';

export type ActionListItemHandler = (title: string) => void;

@Component
export struct ActionListItem {
  title: string = '';
  detail: string = '';
  actionLabel: string = '';
  icon: Resource = $r('app.media.ic_chevron_right');
  showLeadingIcon: boolean = false;
  onAction: ActionListItemHandler = (_title: string) => {};

  build() {
    Column() {
      Row({ space: Space.lg }) {
        if (this.showLeadingIcon) {
          Image(this.icon)
            .width(24)
            .height(24)
            .fillColor(AppColor.textPrimary)
        }
        Column({ space: Space.xs }) {
          Text(this.title)
            .fontSize(FontSz.headline)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textPrimary)
          Text(this.detail)
            .fontSize(FontSz.footnote)
            .fontColor(AppColor.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        IconButton({
          icon: $r('app.media.ic_chevron_right'),
          buttonSize: 42,
          iconSize: 26,
          iconColor: AppColor.textTertiary,
          onAction: () => {
            this.onAction(this.title);
          }
        })
      }
      .width('100%')
      .padding({ left: Space.xxl, right: Space.md, top: Space.lg, bottom: Space.lg })
      Divider()
        .strokeWidth(1)
        .color(AppColor.divider)
        .margin({ left: this.showLeadingIcon ? 62 : Space.xxl })
    }
    .width('100%')
    .backgroundColor(AppColor.surface)
  }
}
