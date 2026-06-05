import { ProxyNode } from '../../core/Profile';
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
  @Prop sourceLabel: string = '';
  @Prop delayText: string = '';
  @Prop delayColor: ResourceColor = AppColor.textTertiary;
  onSelect: ProxyNodeHandler = (_node: ProxyNode) => {};

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
    Row({ space: Space.md }) {
      // 国旗
      Text(this.getFlagEmoji(this.node.name))
        .fontSize(26)
        .width(30)
        .textAlign(TextAlign.Center)

      // 名称 + 协议/地址
      Column({ space: 4 }) {
        Text(this.node.name)
          .fontSize(FontSz.callout)
          .fontWeight(this.isSelected ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.isSelected ? AppColor.brand : AppColor.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: Space.sm }) {
          Text(this.node.protocol.toUpperCase())
            .fontSize(FontSz.caption)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textSecondary)
            .padding({ left: 6, right: 6, top: 1, bottom: 1 })
            .backgroundColor(AppColor.surfaceAlt)
            .borderRadius(Radius.sm)

          Text(this.sourceLabel)
            .fontSize(FontSz.footnote)
            .fontColor(AppColor.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 延迟 + 选中态
      Row({ space: Space.sm }) {
        if (this.delayText.length > 0) {
          Text(this.delayText)
            .fontSize(FontSz.footnote)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.delayColor)
        }
        if (this.isSelected) {
          Column() {
            Image($r('app.media.ic_check'))
              .width(14)
              .height(14)
              .fillColor(AppColor.onBrand)
          }
          .width(20)
          .height(20)
          .borderRadius(10)
          .backgroundColor(AppColor.brand)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      }
    }
    .width('100%')
    .padding({ left: Space.lg, right: Space.lg, top: Space.md, bottom: Space.md })
    .backgroundColor(this.isSelected ? AppColor.brandTint : AppColor.surface)
    .onClick(() => {
      this.onSelect(this.node);
    })
  }
}
