import { common } from '@kit.AbilityKit';
import { DEFAULT_LANGUAGE, translate } from '../core/I18n';
import { AppLanguage } from '../core/Profile';
import { SETTINGS_CONTROLLER, SettingsDraft } from '../features/settings/SettingsController';
import { SHARED_RUNTIME_CONTROLLER } from '../features/runtime/RuntimeController';
import { PageHeader } from '../shell/PageHeader';
import { formatOne } from '../utils/LocalizationPresenter';
import { AppColor } from '../theme/Theme';

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
        Column({ space: 16 }) {
          
          // 卡片 1: 流量模式设置
          Column() {
            Row() {
              Text(this.t('routing.trafficMode'))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColor.brand)
              Blank()
              Text(this.t(`routing.mode.${this.trafficMode}`))
                .fontSize(12)
                .fontColor(AppColor.brand)
                .fontWeight(FontWeight.Medium)
                .backgroundColor(AppColor.brandTint)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .borderRadius(8)
            }
            .width('100%')
            .margin({ bottom: 14 })

            Row({ space: 8 }) {
              this.TrafficModeTab('global', this.t('routing.mode.global'), $r('app.media.ic_route'), '所有流量代理')
              this.TrafficModeTab('rules', this.t('routing.mode.rules'), $r('app.media.ic_settings'), '按规则智能分流')
              this.TrafficModeTab('direct', this.t('routing.mode.direct'), $r('app.media.ic_share'), '所有流量直连')
            }
            .width('100%')
            .margin({ bottom: 10 })

            // 当前流量模式的说明文案
            Text(this.getTrafficModeDescription())
              .fontSize(12)
              .fontColor(AppColor.textSecondary)
              .lineHeight(16)
              .width('100%')
              .margin({ bottom: 4 })

            // 智能联动：规则模式下的“绕过局域网与大陆”开关
            if (this.trafficMode === 'rules') {
              Row({ space: 14 }) {
                Column({ space: 4 }) {
                  Text(this.t('settings.routeOnly'))
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColor.textPrimary)
                  Text('启用后，局域网和中国境内流量将直接连接。')
                    .fontSize(12)
                    .fontColor(AppColor.textTertiary)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Toggle({ type: ToggleType.Switch, isOn: this.routeOnlyEnabled })
                  .selectedColor(AppColor.brand)
                  .switchPointColor(AppColor.onBrand)
                  .onChange((isOn: boolean) => {
                    this.routeOnlyEnabled = isOn;
                    this.persistSettings(this.t('settings.routeOnly') + ': ' + (isOn ? this.t('action.on') : this.t('action.off')));
                  })
              }
              .width('100%')
              .padding({ top: 12, bottom: 4 })
              .border({ width: { top: 1 }, color: AppColor.divider })
              .margin({ top: 8 })
            }
          }
          .padding(16)
          .backgroundColor(AppColor.surface)
          .borderRadius(16)
          .shadow({ radius: 8, color: AppColor.shadowCard, offsetX: 0, offsetY: 2 })
          .width('100%')

          // 卡片 2: 域名策略设置
          Column() {
            Row() {
              Text(this.t('routing.domainStrategy'))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColor.brand)
              Blank()
              Text(this.routingStrategy)
                .fontSize(12)
                .fontColor(AppColor.textSecondary)
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')
            .margin({ bottom: 14 })

            Column({ space: 10 }) {
              this.StrategyOption('AsIs', '仅用域名 (AsIs)', '直接使用域名进行匹配分流，解析效率最高，但不匹配 IP 类规则。')
              this.StrategyOption('IPIfNonMatch', '未匹配时解析 (IPIfNonMatch)', '域名未命中任何规则时，解析为 IP 再次匹配。推荐配置，兼顾速度与准确性。')
              this.StrategyOption('IPOnDemand', '按需解析 (IPOnDemand)', '在规则匹配到 IP 规则时才发起 DNS 解析，适用于较严格的分流场景。')
            }
            .width('100%')
          }
          .padding(16)
          .backgroundColor(AppColor.surface)
          .borderRadius(16)
          .shadow({ radius: 8, color: AppColor.shadowCard, offsetX: 0, offsetY: 2 })
          .width('100%')

          // 卡片 3: 路由预设详情参考
          Column() {
            Row() {
              Text('预置规则集详情')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColor.brand)
              Blank()
              Text('点击查看详情')
                .fontSize(12)
                .fontColor(AppColor.textTertiary)
            }
            .width('100%')
            .margin({ bottom: 14 })

            Column({ space: 10 }) {
              this.RoutingPresetCard(
                this.t('routing.global.title'), 
                this.t('routing.global.detail'), 
                $r('app.media.ic_route'),
                "• 匹配规则：所有入站请求均被路由到代理出站(proxy)\n• 场景应用：不需要区分内外网，完全通过代理节点访问网络"
              )
              this.RoutingPresetCard(
                this.t('routing.bypassLanCn.title'), 
                this.t('routing.bypassLanCn.detail'), 
                $r('app.media.ic_link'),
                "• 匹配规则：\n  - 局域网私有IP (geoip:private) -> 直连(direct)\n  - 境内IP网段 (geoip:cn) -> 直连(direct)\n  - 境内常见域名 (geosite:cn) -> 直连(direct)\n• 其它未匹配流量自动通过代理出站"
              )
              this.RoutingPresetCard(
                this.t('routing.blockAds.title'), 
                this.t('routing.blockAds.detail'), 
                $r('app.media.ic_delete'),
                "• 匹配规则：常见广告和追踪域名 (geosite:category-ads-all) -> 拦截阻断(block/blackhole)\n• 场景应用：屏蔽应用内广告和网页统计追踪，节省流量并提升页面加载效率"
              )
              this.RoutingPresetCard(
                this.t('routing.customRulesets.title'), 
                this.t('routing.customRulesets.detail'), 
                $r('app.media.ic_settings'),
                "• 匹配规则：允许通过 GeoIP 和 GeoSite 数据库配置自定义域名和 IP 分流\n• 场景应用：支持分应用代理设置（白名单/黑名单），可根据业务需要精细控制分流行为"
              )
            }
            .width('100%')
          }
          .padding(16)
          .backgroundColor(AppColor.surface)
          .borderRadius(16)
          .shadow({ radius: 8, color: AppColor.shadowCard, offsetX: 0, offsetY: 2 })
          .width('100%')

        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 14, bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColor.bg)
  }

  @Builder
  private TrafficModeTab(value: string, label: string, icon: Resource, helper: string) {
    Column({ space: 4 }) {
      Image(icon)
        .width(24)
        .height(24)
        .fillColor(this.trafficMode === value ? AppColor.brand : AppColor.textSecondary)
      Text(label)
        .fontSize(14)
        .fontWeight(this.trafficMode === value ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.trafficMode === value ? AppColor.brand : AppColor.textPrimary)
    }
    .layoutWeight(1)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(this.trafficMode === value ? AppColor.brandTint : AppColor.surfaceAlt)
    .borderRadius(12)
    .border({
      width: 1.5,
      color: this.trafficMode === value ? AppColor.brand : 'transparent'
    })
    .onClick(() => {
      this.trafficMode = value;
      this.persistSettings(this.f1('log.routingStrategy', 'value', label));
    })
  }

  @Builder
  private StrategyOption(value: string, title: string, description: string) {
    Row({ space: 12 }) {
      // 自定义单选指示器圆圈
      Column() {
        if (this.routingStrategy === value) {
          Column()
            .width(10)
            .height(10)
            .borderRadius(5)
            .backgroundColor(AppColor.brand)
        }
      }
      .width(18)
      .height(18)
      .borderRadius(9)
      .border({ width: 2, color: this.routingStrategy === value ? AppColor.brand : AppColor.textTertiary })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 4 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(this.routingStrategy === value ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.routingStrategy === value ? AppColor.brand : AppColor.textPrimary)
        Text(description)
          .fontSize(11)
          .fontColor(AppColor.textSecondary)
          .lineHeight(15)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.routingStrategy === value ? AppColor.brandTint : AppColor.surfaceAlt)
    .borderRadius(12)
    .border({
      width: 1,
      color: this.routingStrategy === value ? AppColor.brand : 'transparent'
    })
    .onClick(() => {
      this.routingStrategy = value;
      this.persistSettings(this.f1('log.routingStrategy', 'value', value));
    })
  }

  @Builder
  private RoutingPresetCard(title: string, detail: string, icon: Resource, rulesInfo: string) {
    Row({ space: 12 }) {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor(AppColor.brand)
      Column({ space: 4 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textPrimary)
        Text(detail)
          .fontSize(11)
          .fontColor(AppColor.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('规则详情')
        .fontSize(11)
        .height(26)
        .backgroundColor(AppColor.bg)
        .fontColor(AppColor.textSecondary)
        .borderRadius(13)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          this.showPresetDetails(title, detail, rulesInfo);
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColor.surfaceAlt)
    .borderRadius(12)
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
