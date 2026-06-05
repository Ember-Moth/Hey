import { common } from '@kit.AbilityKit';
import { DEFAULT_LANGUAGE, translate } from '../core/I18n';
import { AppLanguage } from '../core/Profile';
import { SETTINGS_CONTROLLER, SettingsDraft } from '../features/settings/SettingsController';
import { SHARED_RUNTIME_CONTROLLER } from '../features/runtime/RuntimeController';
import { SectionHeader } from '../components/SectionHeader';
import { PageHeader } from '../shell/PageHeader';
import { formatOne } from '../utils/LocalizationPresenter';
import { AppColor, FontSz, Radius, Space } from '../theme/Theme';

@Entry
@Component
struct RoutingPage {
  @State private language: AppLanguage = DEFAULT_LANGUAGE;
  @State private trafficMode: string = 'rules';
  @State private routingStrategy: string = 'AsIs';
  @State private routeOnlyEnabled: boolean = false;
  private draft: SettingsDraft | null = null;

  aboutToAppear(): void {
    this.loadState();
  }

  build() {
    Column() {
      PageHeader({
        title: this.t('screen.routing.title'),
        summary: this.t(`routing.mode.${this.trafficMode}`),
        showBack: true
      })

      Scroll() {
        Column({ space: Space.lg }) {

          // 流量模式
          SectionHeader({ title: this.t('routing.trafficMode') })
          Column() {
            this.TrafficModeRow('global', this.t('routing.mode.global'), '所有流量代理', $r('app.media.ic_route'))
            this.RowDivider()
            this.TrafficModeRow('rules', this.t('routing.mode.rules'), '按规则智能分流', $r('app.media.ic_settings'))
            this.RowDivider()
            this.TrafficModeRow('direct', this.t('routing.mode.direct'), '所有流量直连', $r('app.media.ic_share'))

            if (this.trafficMode === 'rules') {
              this.RowDivider()
              this.RouteOnlyRow()
            }
          }
          .width('100%')
          .backgroundColor(AppColor.surface)
          .borderRadius(Radius.lg)
          .clip(true)
          .margin({ left: Space.lg, right: Space.lg })

          this.GroupFooter(this.getTrafficModeDescription())

          // 域名策略
          SectionHeader({ title: this.t('routing.domainStrategy') })
          Column() {
            this.StrategyRow('AsIs', '仅用域名 (AsIs)', '直接使用域名进行匹配分流，解析效率最高，但不匹配 IP 类规则。')
            this.RowDivider()
            this.StrategyRow('IPIfNonMatch', '未匹配时解析 (IPIfNonMatch)', '域名未命中任何规则时，解析为 IP 再次匹配。推荐配置，兼顾速度与准确性。')
            this.RowDivider()
            this.StrategyRow('IPOnDemand', '按需解析 (IPOnDemand)', '在规则匹配到 IP 规则时才发起 DNS 解析，适用于较严格的分流场景。')
          }
          .width('100%')
          .backgroundColor(AppColor.surface)
          .borderRadius(Radius.lg)
          .clip(true)
          .margin({ left: Space.lg, right: Space.lg })

          // 预置规则集
          SectionHeader({ title: '预置规则集' })
          Column() {
            this.PresetRow(
              this.t('routing.global.title'),
              this.t('routing.global.detail'),
              $r('app.media.ic_route'),
              '• 匹配规则：所有入站请求均被路由到代理出站(proxy)\n• 场景应用：不需要区分内外网，完全通过代理节点访问网络'
            )
            this.RowDivider()
            this.PresetRow(
              this.t('routing.bypassLanCn.title'),
              this.t('routing.bypassLanCn.detail'),
              $r('app.media.ic_link'),
              '• 匹配规则：\n  - 局域网私有IP (geoip:private) -> 直连(direct)\n  - 境内IP网段 (geoip:cn) -> 直连(direct)\n  - 境内常见域名 (geosite:cn) -> 直连(direct)\n• 其它未匹配流量自动通过代理出站'
            )
            this.RowDivider()
            this.PresetRow(
              this.t('routing.blockAds.title'),
              this.t('routing.blockAds.detail'),
              $r('app.media.ic_delete'),
              '• 匹配规则：常见广告和追踪域名 (geosite:category-ads-all) -> 拦截阻断(block/blackhole)\n• 场景应用：屏蔽应用内广告和网页统计追踪，节省流量并提升页面加载效率'
            )
            this.RowDivider()
            this.PresetRow(
              this.t('routing.customRulesets.title'),
              this.t('routing.customRulesets.detail'),
              $r('app.media.ic_settings'),
              '• 匹配规则：允许通过 GeoIP 和 GeoSite 数据库配置自定义域名和 IP 分流\n• 场景应用：支持分应用代理设置（白名单/黑名单），可根据业务需要精细控制分流行为'
            )
          }
          .width('100%')
          .backgroundColor(AppColor.surface)
          .borderRadius(Radius.lg)
          .clip(true)
          .margin({ left: Space.lg, right: Space.lg })

        }
        .width('100%')
        .padding({ top: Space.sm, bottom: Space.xxl })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColor.bg)
  }

  @Builder
  private RowDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(AppColor.divider)
      .margin({ left: Space.lg })
  }

  @Builder
  private GroupFooter(text: string) {
    Text(text)
      .fontSize(FontSz.footnote)
      .fontColor(AppColor.textTertiary)
      .lineHeight(16)
      .width('100%')
      .padding({ left: Space.lg + Space.xs, right: Space.lg + Space.xs, top: Space.xs })
  }

  @Builder
  private TrafficModeRow(value: string, title: string, subtitle: string, icon: Resource) {
    Row({ space: Space.md }) {
      Column() {
        Image(icon)
          .width(20)
          .height(20)
          .fillColor(this.trafficMode === value ? AppColor.brand : AppColor.textTertiary)
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(this.trafficMode === value ? AppColor.brandTint : AppColor.surfaceAlt)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 3 }) {
        Text(title)
          .fontSize(FontSz.callout)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textPrimary)
        Text(subtitle)
          .fontSize(FontSz.footnote)
          .fontColor(AppColor.textTertiary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.trafficMode === value) {
        Image($r('app.media.ic_check'))
          .width(20)
          .height(20)
          .fillColor(AppColor.brand)
      }
    }
    .width('100%')
    .padding(Space.lg)
    .onClick(() => {
      this.trafficMode = value;
      this.persistSettings(this.f1('log.routingStrategy', 'value', title));
    })
  }

  @Builder
  private RouteOnlyRow() {
    Row({ space: Space.md }) {
      Column({ space: 3 }) {
        Text(this.t('settings.routeOnly'))
          .fontSize(FontSz.callout)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textPrimary)
        Text('局域网和中国境内流量将直接连接。')
          .fontSize(FontSz.footnote)
          .fontColor(AppColor.textTertiary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.routeOnlyEnabled })
        .selectedColor(AppColor.brand)
        .switchPointColor(AppColor.onBrand)
        .onChange((isOn: boolean) => {
          this.routeOnlyEnabled = isOn;
          this.persistSettings(this.t('settings.routeOnly') + ': ' + (isOn ? this.t('action.on') : this.t('action.off')));
        })
    }
    .width('100%')
    .padding(Space.lg)
  }

  @Builder
  private StrategyRow(value: string, title: string, description: string) {
    Row({ space: Space.md }) {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(FontSz.callout)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.routingStrategy === value ? AppColor.brand : AppColor.textPrimary)
        Text(description)
          .fontSize(FontSz.footnote)
          .fontColor(AppColor.textTertiary)
          .lineHeight(16)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.routingStrategy === value) {
        Image($r('app.media.ic_check'))
          .width(20)
          .height(20)
          .fillColor(AppColor.brand)
      }
    }
    .width('100%')
    .padding(Space.lg)
    .onClick(() => {
      this.routingStrategy = value;
      this.persistSettings(this.f1('log.routingStrategy', 'value', value));
    })
  }

  @Builder
  private PresetRow(title: string, detail: string, icon: Resource, rulesInfo: string) {
    Row({ space: Space.md }) {
      Column() {
        Image(icon)
          .width(20)
          .height(20)
          .fillColor(AppColor.brand)
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(AppColor.brandTint)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 3 }) {
        Text(title)
          .fontSize(FontSz.callout)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textPrimary)
        Text(detail)
          .fontSize(FontSz.footnote)
          .fontColor(AppColor.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image($r('app.media.ic_chevron_right'))
        .width(20)
        .height(20)
        .fillColor(AppColor.textTertiary)
    }
    .width('100%')
    .padding(Space.lg)
    .onClick(() => {
      this.showPresetDetails(title, detail, rulesInfo);
    })
  }

  private getTrafficModeDescription(): string {
    if (this.trafficMode === 'global') {
      return '全局代理模式下，客户端接管的所有网络请求均强行导向您的代理节点，不经过任何分流规则过滤。';
    } else if (this.trafficMode === 'rules') {
      return '规则分流模式下，客户端会解析域名和 IP，并对照路由规则集，符合绕过条件的直连，其余流量通过代理出站。';
    } else {
      return '全局直连模式下，所有网络流量均绕过代理服务器直接出站。此时代理服务不会对您的流量进行中转。';
    }
  }

  private showPresetDetails(title: string, detail: string, rules: string): void {
    AlertDialog.show({
      title: title,
      message: detail + "\n\n【核心规则配置】\n" + rules,
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 },
      primaryButton: {
        value: this.t('action.use') + ' / ' + '启用预设',
        fontColor: AppColor.onBrand,
        backgroundColor: AppColor.brand,
        action: () => {
          SHARED_RUNTIME_CONTROLLER.appendLog(this.f1('log.presetOpened', 'title', title));
        }
      },
      secondaryButton: {
        value: '关闭',
        fontColor: AppColor.textSecondary,
        backgroundColor: AppColor.bg,
        action: () => {}
      }
    })
  }

  private async loadState(): Promise<void> {
    const context = getContext(this) as common.Context;
    const settings = await SETTINGS_CONTROLLER.load(context);
    this.draft = SETTINGS_CONTROLLER.toDraft(settings);
    this.language = this.draft.language;
    this.trafficMode = this.draft.trafficMode;
    this.routingStrategy = this.draft.routingDomainStrategy;
    this.routeOnlyEnabled = this.draft.routeOnlyEnabled;
  }

  private async persistSettings(logMessage: string): Promise<void> {
    if (this.draft === null) {
      return;
    }
    this.draft.trafficMode = this.trafficMode;
    this.draft.routingDomainStrategy = this.routingStrategy;
    this.draft.routeOnlyEnabled = this.routeOnlyEnabled;
    const context = getContext(this) as common.Context;
    const saved = await SETTINGS_CONTROLLER.save(context, this.draft);
    this.draft = SETTINGS_CONTROLLER.toDraft(saved);
    this.language = this.draft.language;
    SHARED_RUNTIME_CONTROLLER.appendLog(logMessage);
  }

  private t(key: string): string {
    return translate(this.language, key);
  }

  private f1(key: string, name: string, value: string): string {
    return formatOne(this.language, key, name, value);
  }
}
