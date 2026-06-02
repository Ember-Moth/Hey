import { ProxyNode, SubscriptionGroup } from '../../core/Profile';
import { IconButton } from '../../components/IconButton';
import { ProxyNodeHandler } from '../servers/ServerCard';

export type SubscriptionGroupHandler = (group: SubscriptionGroup) => void;

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

const EMPTY_GROUP: SubscriptionGroup = {
  id: '',
  name: '',
  url: '',
  enabled: false,
  selectedNodeId: '',
  nodes: [],
  updatedAt: 0
};

@Component
export struct SubscriptionGroupListRow {
  group: SubscriptionGroup = EMPTY_GROUP;
  @Prop isSelected: boolean = false;
  @Prop summary: string = '';
  @Prop currentLabel: string = '';
  @Prop openLabel: string = '';
  @Prop onLabel: string = '';
  @Prop offLabel: string = '';
  @Prop deleteLabel: string = '';
  onSelect: SubscriptionGroupHandler = (_group: SubscriptionGroup) => {};
  onToggle: SubscriptionGroupHandler = (_group: SubscriptionGroup) => {};
  onDelete: SubscriptionGroupHandler = (_group: SubscriptionGroup) => {};

  build() {
    Column() {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(this.group.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1C1B1F')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.summary)
            .fontSize(13)
            .fontColor('#49454F')
        }
        .layoutWeight(1)

        IconButton({
          icon: this.isSelected ? $r('app.media.ic_check') : $r('app.media.ic_chevron_right'),
          buttonSize: 42,
          iconSize: this.isSelected ? 22 : 28,
          iconColor: this.isSelected ? '#FFFFFF' : '#1C1B1F',
          buttonBackground: this.isSelected ? '#F97910' : '#00000000',
          onAction: () => {
            this.onSelect(this.group);
          }
        })
        Toggle({ type: ToggleType.Switch, isOn: this.group.enabled })
          .selectedColor('#F97910')
          .switchPointColor('#FFFFFF')
          .onChange((_isOn: boolean) => {
            this.onToggle(this.group);
          })
        IconButton({
          icon: $r('app.media.ic_delete'),
          buttonSize: 42,
          iconSize: 24,
          iconColor: '#1C1B1F',
          onAction: () => {
            this.onDelete(this.group);
          }
        })
      }
      .width('100%')
      .padding({ left: 24, right: 12, top: 14, bottom: 14 })
      Divider()
        .strokeWidth(1)
        .color('#E0E0E0')
        .margin({ left: 24 })
    }
    .width('100%')
    .backgroundColor(this.isSelected ? '#FFF7ED' : '#FFFFFF')
  }
}

@Component
export struct SubscriptionNodeListRow {
  node: ProxyNode = EMPTY_NODE;
  @Prop isSelected: boolean = false;
  @Prop isBusy: boolean = false;
  @Prop delayText: string = '';
  @Prop delayColor: string = '#6B7280';
  @Prop selectedLabel: string = '';
  @Prop useLabel: string = '';
  onSelect: ProxyNodeHandler = (_node: ProxyNode) => {};

  build() {
    Column() {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(this.node.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1C1B1F')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.node.protocol.toUpperCase())
            .fontSize(13)
            .fontColor('#F97910')
        }
        .layoutWeight(1)

        Text(this.delayText)
          .fontSize(13)
          .fontColor(this.delayColor)
          .width(82)
          .textAlign(TextAlign.Center)

        IconButton({
          icon: $r('app.media.ic_check'),
          buttonSize: 42,
          iconSize: 22,
          iconColor: this.isSelected ? '#FFFFFF' : '#1C1B1F',
          buttonBackground: this.isSelected ? '#F97910' : '#00000000',
          isEnabled: !this.isBusy,
          onAction: () => {
            this.onSelect(this.node);
          }
        })
      }
      .width('100%')
      .padding({ left: 24, right: 12, top: 14, bottom: 14 })
      Divider()
        .strokeWidth(1)
        .color('#E0E0E0')
        .margin({ left: 24 })
    }
    .width('100%')
    .backgroundColor(this.isSelected ? '#FFF7ED' : '#FFFFFF')
  }
}
