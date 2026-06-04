import { ProxyNode } from '../../core/Profile';
import { IconButton } from '../../components/IconButton';
import { AppColor, FontSz, Radius, Space } from '../../theme/Theme';

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
  @Prop delayColor: ResourceColor = AppColor.textTertiary;
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
      Row({ space: Space.md }) {
        // 左侧选中态指示条
        Column()
          .width(4)
          .height(48)
          .backgroundColor(this.isSelected ? AppColor.brand : Color.Transparent)
          .borderRadius(2)

        // 根据节点名推断的国旗
        Text(this.getFlagEmoji(this.node.name))
          .fontSize(28)
          .margin({ left: Space.xs })

        Column({ space: 5 }) {
          Text(this.node.name)
            .fontSize(FontSz.headline)
            .fontWeight(this.isSelected ? FontWeight.Bold : FontWeight.Medium)
            .fontColor(AppColor.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.sourceLabel)
            .fontSize(FontSz.body)
            .fontColor(AppColor.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: Space.sm }) {
            Text(this.node.protocol.toUpperCase())
              .fontSize(FontSz.footnote)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.brand)
              .padding({ left: Space.sm, right: Space.sm, top: 2, bottom: 2 })
              .backgroundColor(AppColor.brandTint)
              .borderRadius(Radius.sm)

            if (this.delayText.length > 0) {
              Text(this.delayText)
                .fontSize(FontSz.footnote)
                .fontColor(this.delayColor)
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row({ space: Space.xs }) {
          IconButton({
            icon: $r('app.media.ic_share'),
            buttonSize: 36,
            iconSize: 20,
            radius: 18,
            iconColor: AppColor.textSecondary,
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
              iconColor: AppColor.textSecondary,
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
            iconColor: AppColor.textSecondary,
            isEnabled: !this.isBusy,
            onAction: () => {
              this.onDelete(this.node);
            }
          })
        }
        .margin({ right: Space.xs })
      }
      .width('100%')
      .padding({ left: 0, right: Space.md, top: Space.lg, bottom: Space.lg })
      Divider()
        .strokeWidth(1)
        .color(AppColor.divider)
        .margin({ left: Space.xxl })
    }
    .width('100%')
    .backgroundColor(this.isSelected ? AppColor.brandTint : AppColor.surface)
    .onClick(() => {
      this.onSelect(this.node);
    })
  }
}
