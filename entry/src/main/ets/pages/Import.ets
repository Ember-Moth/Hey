import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { DEFAULT_LANGUAGE, translate } from '../core/I18n';
import { AppLanguage } from '../core/Profile';
import { NODES_CONTROLLER } from '../features/nodes/NodesController';
import { SETTINGS_CONTROLLER } from '../features/settings/SettingsController';
import { AppRoute } from '../shell/AppRoute';
import { PageHeader } from '../shell/PageHeader';
import { SubscriptionStore } from '../storage/SubscriptionStore';

@Entry
@Component
struct ImportPage {
  @State private language: AppLanguage = DEFAULT_LANGUAGE;
  @State private importBuffer: string = '';
  @State private lastError: string = '';
  @State private isBusy: boolean = false;
  @State private isPressed: boolean = false;

  aboutToAppear(): void {
    this.loadState();
  }

  build() {
    Column() {
      PageHeader({
        title: this.t('screen.import.title'),
        showBack: true
      })
      Scroll() {
        Column({ space: 18 }) {
          // 模块一：解析协议链接 / 扫码
          this.LinkImportSection()
          
          // 模块二：手动协议配置
          this.ManualGridSection()
          
          // 模块三：自定义 JSON 配置
          this.JsonImportSection()
          
          if (this.lastError.length > 0) {
            Text(this.lastError)
              .fontSize(12)
              .fontColor('#B42318')
              .width('100%')
              .padding(10)
              .backgroundColor('#FEF3F2')
              .borderRadius(6)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 32 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#F3F4F6')
  }

  // 1. 扫码与链接导入区
  @Builder
  private LinkImportSection() {
    Column({ space: 12 }) {
      this.CardSectionTitle('扫码与链接导入')
      
      Text('粘贴分享链接（如 vless://, vmess://, ss://, trojan:// 等）或点击右侧扫码解析。')
        .fontSize(12)
        .fontColor('#9CA3AF')
        .width('100%')
        .lineHeight(16)

      Row() {
        Image($r('app.media.ic_link'))
          .width(20)
          .height(20)
          .fillColor('#6B7280')
          .margin({ left: 12, right: 8 })

        TextInput({
          placeholder: '输入或粘贴节点连接 URL',
          text: this.importBuffer
        })
          .layoutWeight(1)
          .height(46)
          .fontSize(14)
          .fontColor('#111827')
          .placeholderColor('#9CA3AF')
          .backgroundColor('#00000000')
          .onChange((value: string) => {
            this.importBuffer = value;
          })

        if (this.importBuffer.length > 0) {
          Button() {
            Text('✕')
              .fontSize(12)
              .fontColor('#4B5563')
              .fontWeight(FontWeight.Bold)
          }
          .backgroundColor('#E5E7EB')
          .width(28)
          .height(28)
          .borderRadius(14)
          .margin({ right: 8 })
          .onClick(() => {
            this.importBuffer = '';
          })
        }
      }
      .width('100%')
      .height(48)
      .backgroundColor('#F3F4F6')
      .borderRadius(10)
      .alignItems(VerticalAlign.Center)

      Row({ space: 10 }) {
        Button() {
          Row() {
            if (this.isBusy) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color('#FFFFFF')
                .margin({ right: 6 })
            }
            Text('解析并导入')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
        }
        .height(40)
        .layoutWeight(1)
        .enabled(!this.isBusy && this.importBuffer.trim().length > 0)
        .opacity(this.importBuffer.trim().length > 0 ? 1.0 : 0.6)
        .linearGradient({
          angle: 90,
          colors: [['#FF8F3D', 0.0], ['#F97910', 1.0]]
        })
        .borderRadius(8)
        .onClick(() => {
          this.importLink();
        })

        Button() {
          Row({ space: 6 }) {
            Image($r('app.media.ic_qr_code'))
              .width(16)
              .height(16)
              .fillColor('#374151')
            Text('扫描二维码')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#374151')
          }
        }
        .height(40)
        .padding({ left: 16, right: 16 })
        .backgroundColor('#FFFFFF')
        .borderWidth(1)
        .borderColor('#D1D5DB')
        .borderRadius(8)
        .onClick(() => {
          router.pushUrl({ url: AppRoute.SCANNER });
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 2 })
  }

  // 2. 手动协议配置列表项
  @Builder
  private ManualGridSection() {
    Column({ space: 12 }) {
      this.CardSectionTitle('手动配置节点')
      
      Column({ space: 10 }) {
        Row({ space: 10 }) {
          this.ProtocolCard('vless')
          this.ProtocolCard('vmess')
        }
        .width('100%')

        Row({ space: 10 }) {
          this.ProtocolCard('trojan')
          this.ProtocolCard('ss')
        }
        .width('100%')

        Row({ space: 10 }) {
          this.ProtocolCard('socks')
          this.ProtocolCard('http')
        }
        .width('100%')

        Row({ space: 10 }) {
          this.ProtocolCard('wireguard')
          this.ProtocolCard('hysteria2')
        }
        .width('100%')
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 2 })
  }

  @Builder
  private ProtocolCard(protocol: string) {
    Row() {
      Column() {
        Text(protocol === 'hysteria2' ? 'HY2' : protocol.toUpperCase())
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        Text(`${protocol === 'ss' ? 'Shadowsocks' : (protocol === 'wireguard' ? 'WireGuard' : (protocol === 'hysteria2' ? 'Hysteria 2' : protocol.toUpperCase()))} 协议`)
          .fontSize(10)
          .fontColor('#9CA3AF')
          .margin({ top: 1 })
      }
      .alignItems(HorizontalAlign.Start)
      
      Blank()
      
      Image($r('app.media.ic_chevron_right'))
        .width(14)
        .height(14)
        .fillColor('#9CA3AF')
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .padding({ left: 12, right: 10, top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Top)
    .backgroundColor('#F9FAFB')
    .borderRadius(10)
    .borderWidth(1)
    .borderColor('#F3F4F6')
    .onClick(() => {
      router.pushUrl({
        url: AppRoute.NODE_EDIT,
        params: { protocol: protocol }
      })
    })
  }

  // 3. 自定义 JSON 导入入口
  @Builder
  private JsonImportSection() {
    Row() {
      Column({ space: 4 }) {
        Text('导入 JSON 配置')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')
        
        Text('支持直接粘贴标准的 Xray outbound JSON 配置大文本。')
          .fontSize(11)
          .fontColor('#9CA3AF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      
      Image($r('app.media.ic_chevron_right'))
        .width(16)
        .height(16)
        .fillColor('#9CA3AF')
        .margin({ left: 8 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 2 })
    .scale({ x: this.isPressed ? 0.98 : 1.0, y: this.isPressed ? 0.98 : 1.0 })
    .animation({ duration: 150, curve: Curve.EaseOut })
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .onClick(() => {
      router.pushUrl({ url: AppRoute.JSON_IMPORT });
    })
  }

  @Builder
  private CardSectionTitle(title: string) {
    Row({ space: 8 }) {
      Column()
        .width(4)
        .height(16)
        .backgroundColor('#F97910')
        .borderRadius(2)
      
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ bottom: 4 })
  }

  private async loadState(): Promise<void> {
    try {
      const context = getContext(this) as common.Context;
      this.language = (await SETTINGS_CONTROLLER.load(context)).language;
    } catch (error) {
      this.lastError = '加载页面配置失败：' + JSON.stringify(error);
    }
  }

  private async importLink(): Promise<void> {
    const value = this.importBuffer.trim();
    if (value.length === 0) {
      this.lastError = this.t('error.emptyImport');
      return;
    }

    this.isBusy = true;
    try {
      const context = getContext(this) as common.Context;
      if (value.toLowerCase().startsWith('http://') || value.toLowerCase().startsWith('https://')) {
        this.lastError = this.t('error.importSubscriptionNotAllowed');
        return;
      }

      const saved = await NODES_CONTROLLER.saveProfile(context, value, this.language);
      if (saved.profile === null) {
        this.lastError = saved.lastError;
        return;
      }

      let nodeName = '链接导入';
      try {
        const obj = JSON.parse(saved.profile.outboundJson) as Record<string, Object>;
        if (obj.tag && typeof obj.tag === 'string' && obj.tag.trim().length > 0) {
          nodeName = obj.tag.trim();
        }
      } catch (err) {
        // ignore
      }

      await SubscriptionStore.addManualNode(context, nodeName, saved.profile.outboundJson);
      promptAction.showToast({ message: '节点解析成功' });
      router.back();
    } catch (error) {
      this.lastError = '解析失败：' + JSON.stringify(error);
    } finally {
      this.isBusy = false;
    }
  }

  private t(key: string): string {
    return translate(this.language, key);
  }
}
