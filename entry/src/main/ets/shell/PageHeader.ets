import { router } from '@kit.ArkUI';
import { IconButton } from '../components/IconButton';

@Component
export struct PageHeader {
  title: string = '';
  summary: string = '';
  showBack: boolean = true;
  statusLabel: string = '';
  statusColor: string = '#374151';
  statusBackground: string = '#F3F4F6';
  @BuilderParam rightActions?: () => void;

  build() {
    Stack() {
      // 1. 中间绝对居中的标题文本区域
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C1B1F')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .width('100%')
        if (this.summary.length > 0) {
          Text(this.summary)
            .fontSize(12)
            .fontColor('#49454F')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
            .width('100%')
        }
      }
      .width('100%')
      // 设置左右安全避让外边距，防止长文本遮挡按钮，同时保证水平绝对居中
      .padding({ left: 72, right: 96 })

      // 2. 左侧靠边缘定位的返回键容器
      if (this.showBack) {
        Row() {
          IconButton({
            icon: $r('app.media.ic_arrow_back'),
            buttonSize: 48,
            iconSize: 28,
            iconColor: '#1C1B1F',
            onAction: () => {
              router.back();
            }
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ left: 8 })
      }

      // 3. 右侧靠边缘定位的操作图标容器
      Row() {
        if (this.rightActions) {
          this.rightActions()
        } else if (this.statusLabel.length > 0) {
          Text(this.statusLabel)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.statusColor)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.statusBackground)
            .borderRadius(12)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ right: 12 })
    }
    .width('100%')
    .height(82)
    .padding({ top: 10 })
    .backgroundColor('#FFFFFF')
  }
}
