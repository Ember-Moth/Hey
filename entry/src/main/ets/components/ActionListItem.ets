import { IconButton } from './IconButton';

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
      Row({ space: 14 }) {
        if (this.showLeadingIcon) {
          Image(this.icon)
            .width(24)
            .height(24)
            .fillColor('#1C1B1F')
        }
        Column({ space: 4 }) {
          Text(this.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1C1B1F')
          Text(this.detail)
            .fontSize(13)
            .fontColor('#49454F')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        IconButton({
          icon: $r('app.media.ic_chevron_right'),
          buttonSize: 42,
          iconSize: 26,
          iconColor: '#1C1B1F',
          onAction: () => {
            this.onAction(this.title);
          }
        })
      }
      .width('100%')
      .padding({ left: 24, right: 10, top: 14, bottom: 14 })
      Divider()
        .strokeWidth(1)
        .color('#E0E0E0')
        .margin({ left: this.showLeadingIcon ? 62 : 24 })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
  }
}
