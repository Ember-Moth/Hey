import { ProxyNode } from '../../core/Profile';

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
  isSelected: boolean = false;
  isBusy: boolean = false;
  sourceLabel: string = '';
  delayText: string = '';
  delayColor: string = '#6B7280';
  currentLabel: string = '';
  useLabel: string = '';
  openLabel: string = '';
  onSelect: ProxyNodeHandler = (_node: ProxyNode) => {};
  onOpen: ProxyNodeHandler = (_node: ProxyNode) => {};

  build() {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Text(this.node.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.node.protocol.toUpperCase()}  ${this.sourceLabel}`)
          .fontSize(12)
          .fontColor('#6B7280')
      }
      .layoutWeight(1)

      Text(this.delayText)
        .fontSize(12)
        .fontColor(this.delayColor)
        .width(84)
        .textAlign(TextAlign.Center)

      if (this.openLabel.length > 0) {
        Button(this.openLabel)
          .height(34)
          .width(68)
          .fontSize(12)
          .backgroundColor('#F3F4F6')
          .fontColor('#374151')
          .borderRadius(6)
          .onClick(() => {
            this.onOpen(this.node);
          })
      }

      Button(this.isSelected ? this.currentLabel : this.useLabel)
        .height(34)
        .width(86)
        .fontSize(12)
        .enabled(!this.isBusy)
        .backgroundColor(this.isSelected ? '#166534' : '#E5E7EB')
        .fontColor(this.isSelected ? '#FFFFFF' : '#374151')
        .borderRadius(6)
        .onClick(() => {
          this.onSelect(this.node);
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.isSelected ? '#F0FDF4' : '#FFFFFF')
    .borderRadius(8)
  }
}
