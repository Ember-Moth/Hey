import { FlagTile, MetricTile } from '../../components/StatusTiles';
import { AppColor } from '../../theme/Theme';

@Component
export struct RuntimeStatusPanel {
  title: string = '';
  durationLabel: string = '';
  durationValue: string = '';
  uploadLabel: string = '';
  uploadValue: string = '';
  downloadLabel: string = '';
  downloadValue: string = '';
  xrayActive: boolean = false;
  tunActive: boolean = false;
  lastMessage: string = '';

  build() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textPrimary)
        .width('100%')

      Row({ space: 10 }) {
        MetricTile({ label: this.durationLabel, value: this.durationValue })
        MetricTile({ label: this.uploadLabel, value: this.uploadValue })
        MetricTile({ label: this.downloadLabel, value: this.downloadValue })
      }
      .width('100%')

      Row({ space: 8 }) {
        FlagTile({ label: 'Xray', active: this.xrayActive })
        FlagTile({ label: 'TUN', active: this.tunActive })
      }
      .width('100%')

      Text(this.lastMessage)
        .fontSize(12)
        .fontColor(AppColor.textSecondary)
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColor.surface)
    .borderRadius(8)
  }
}
