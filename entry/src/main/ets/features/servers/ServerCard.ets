import { ProxyNode } from '../../core/Profile';
import { IconButton } from '../../components/IconButton';

export type ProxyNodeHandler = (node: ProxyNode) => void;

const EMPTY_NODE: ProxyNode = {
  id: '',
  name: '',
  protocol: '',
  outboundJson: '',
  sourceUrl: '',
  rawLink: '',
  updatedAt: 0,
  delayMs: 0,
  delayTestAt: 0,
  delayStatus: ''
};

@Component
export struct ServerNodeCard {
  node: ProxyNode = EMPTY_NODE;
  @Prop isSelected: boolean = false;
  @Prop isBusy: boolean = false;
  @Prop sourceLabel: string = '';
  @Prop delayText: string = '';
  @Prop delayColor: string = '#6B7280';
  @Prop currentLabel: string = '';
  @Prop useLabel: string = '';
  @Prop openLabel: string = '';
  onSelect: ProxyNodeHandler = (_node: ProxyNode) => {};
  onShare: ProxyNodeHandler = (_node: ProxyNode) => {};
  onOpen: ProxyNodeHandler = (_node: ProxyNode) => {};
  onDelete: ProxyNodeHandler = (_node: ProxyNode) => {};

  private getFlagEmoji(name: string): string {
    const upperName = name.toUpperCase();
    if (upperName.includes('香港') || upperName.includes('HONG KONG') || upperName.includes('HK') || upperName.includes('🇭🇰')) {
      return '🇭🇰';
    }
    if (upperName.includes('台北') || upperName.includes('TAIPEI') || upperName.includes('TW') || upperName.includes('台湾') || upperName.includes('TAIWAN') || upperName.includes('🇨🇳') || upperName.includes('🇹🇼')) {
      return '🇨🇳';
    }
    if (upperName.includes('日本') || upperName.includes('JAPAN') || upperName.includes('JP') || upperName.includes('🇯🇵')) {
      return '🇯🇵';
    }
    if (upperName.includes('美国') || upperName.includes('UNITED STATES') || upperName.includes('US') || upperName.includes('🇺🇸')) {
      return '🇺🇸';
    }
    if (upperName.includes('新加坡') || upperName.includes('SINGAPORE') || upperName.includes('SG') || upperName.includes('🇸🇬')) {
      return '🇸🇬';
    }
    if (upperName.includes('韩国') || upperName.includes('KOREA') || upperName.includes('KR') || upperName.includes('🇰🇷')) {
      return '🇰🇷';
    }
    if (upperName.includes('英国') || upperName.includes('UNITED KINGDOM') || upperName.includes('UK') || upperName.includes('GB') || upperName.includes('🇬🇧')) {
      return '🇬🇧';
    }
    if (upperName.includes('德国') || upperName.includes('GERMANY') || upperName.includes('DE') || upperName.includes('🇩🇪')) {
      return '🇩🇪';
    }
    if (upperName.includes('CN') || upperName.includes('CHINA') || upperName.includes('中国')) {
      return '🇨🇳';
    }
    return '🌐';
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        // Selected indicator bar on the left edge
        Column()
          .width(4)
          .height(48)
          .backgroundColor(this.isSelected ? '#F97910' : '#00000000')
          .borderRadius(2)

        // Flag Emoji based on name
        Text(this.getFlagEmoji(this.node.name))
          .fontSize(28)
          .margin({ left: 4 })

        Column({ space: 5 }) {
          Text(this.node.name)
            .fontSize(17)
            .fontWeight(this.isSelected ? FontWeight.Bold : FontWeight.Medium)
            .fontColor('#1C1B1F')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.sourceLabel)
            .fontSize(14)
            .fontColor('#49454F')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          
          Row({ space: 8 }) {
            Text(this.node.protocol.toUpperCase())
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F97910')
            
            if (this.delayText.length > 0) {
              Text(this.delayText)
                .fontSize(13)
                .fontColor(this.delayColor)
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row({ space: 4 }) {
          IconButton({
            icon: $r('app.media.ic_share'),
            buttonSize: 36,
            iconSize: 20,
            radius: 18,
            iconColor: '#000000',
            onAction: () => {
              this.onShare(this.node);
            }
          })

          if (this.openLabel.length > 0) {
            IconButton({
              icon: $r('app.media.ic_edit'),
              buttonSize: 36,
              iconSize: 20,
              radius: 18,
              iconColor: '#000000',
              onAction: () => {
                this.onOpen(this.node);
              }
            })
          }

          IconButton({
            icon: $r('app.media.ic_delete'),
            buttonSize: 36,
            iconSize: 20,
            radius: 18,
            iconColor: '#000000',
            isEnabled: !this.isBusy,
            onAction: () => {
              this.onDelete(this.node);
            }
          })
        }
        .margin({ right: 4 })
      }
      .width('100%')
      .padding({ left: 0, right: 10, top: 14, bottom: 14 })
      Divider()
        .strokeWidth(1)
        .color('#E0E0E0')
        .margin({ left: 24 })
    }
    .width('100%')
    .backgroundColor(this.isSelected ? '#FFF5EC' : '#FFFFFF')
    .onClick(() => {
      this.onSelect(this.node);
    })
  }
}
