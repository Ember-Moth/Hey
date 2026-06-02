import { router } from '@kit.ArkUI';

@Component
export struct PageHeader {
  title: string = '';
  summary: string = '';
  showBack: boolean = true;
  statusLabel: string = '';
  statusColor: string = '#374151';
  statusBackground: string = '#F3F4F6';

  build() {
    Row({ space: 10 }) {
      if (this.showBack) {
        Button('<')
          .height(36)
          .width(42)
          .fontSize(18)
          .fontColor('#374151')
          .backgroundColor('#F3F4F6')
          .borderRadius(8)
          .onClick(() => {
            router.back();
          })
      }

      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.summary.length > 0) {
          Text(this.summary)
            .fontSize(12)
            .fontColor('#6B7280')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)

      if (this.statusLabel.length > 0) {
        Text(this.statusLabel)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.statusBackground)
          .borderRadius(6)
      }
    }
    .width('100%')
    .height(70)
    .padding({ left: 14, right: 14 })
    .backgroundColor('#FFFFFF')
  }
}
