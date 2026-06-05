import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { picker } from '@kit.CoreFileKit';
import { DEFAULT_LANGUAGE, translate } from '../core/I18n';
import { AppLanguage } from '../core/Profile';
import { SETTINGS_CONTROLLER } from '../features/settings/SettingsController';
import { PageHeader } from '../shell/PageHeader';
import { AssetStore, CustomAssetUrl } from '../storage/AssetStore';
import { ASSETS_CONTROLLER, GEO_SOURCES } from '../features/assets/AssetsController';
import { BuiltinGeoCard } from './assets/BuiltinGeoCard';
import { CustomAssetList } from './assets/CustomAssetList';
import { AppColor } from '../theme/Theme';

@Entry
@Component
struct AssetsPage {
  @State private language: AppLanguage = DEFAULT_LANGUAGE;

  // 文件状态信息
  @State private geositeStatus: string = '';
  @State private geoipStatus: string = '';

  // 自定义 URL 管理视图控制
  @State private showCustomUrls: boolean = false;
  @State private customAssets: Array<CustomAssetUrl> = [];

  // 下载状态
  @State private downloadingFile: string = '';

  // 下载源管理
  @State private currentSourceUrl: string = GEO_SOURCES[0].url;
  @State private currentSourceName: string = GEO_SOURCES[0].name;

  // 暂存本地导入的 URI，双向绑定传递给 CustomAssetList 
  @State private tempImportUri: string = '';

  aboutToAppear(): void {
    this.loadState();
    this.loadCustomAssets();
  }

  build() {
    Stack() {
      if (!this.showCustomUrls) {
        // 主视图
        Column() {
          PageHeader({
            title: this.t('screen.assets.title'),
            summary: this.t('assets.section.detail'),
            showBack: true
          })
          
          Scroll() {
            Column({ space: 16 }) {
              // 顶层全局快捷控制卡片
              Row({ space: 12 }) {
                Button() {
                  Row({ space: 8 }) {
                    Image($r('app.media.ic_refresh'))
                      .width(18)
                      .height(18)
                      .fillColor(AppColor.brand)
                    Text(this.t('assets.action.updateAll'))
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColor.brand)
                  }
                  .padding({ left: 16, right: 16 })
                }
                .layoutWeight(1)
                .height(44)
                .backgroundColor(AppColor.brandTint)
                .borderRadius(10)
                .onClick(() => {
                  this.downloadAllAssets();
                })

                Button() {
                  Row({ space: 8 }) {
                    Image($r('app.media.ic_folder'))
                      .width(18)
                      .height(18)
                      .fillColor(AppColor.textSecondary)
                    Text(this.t('assets.action.importLocal'))
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColor.textSecondary)
                  }
                  .padding({ left: 16, right: 16 })
                }
                .layoutWeight(1)
                .height(44)
                .backgroundColor(AppColor.bg)
                .borderRadius(10)
                .onClick(() => {
                  this.importLocalFile();
                })
              }
              .width('100%')

              // 卡片一：内置 Geo 规则库管理
              BuiltinGeoCard({
                language: this.language,
                geositeStatus: this.geositeStatus,
                geoipStatus: this.geoipStatus,
                currentSourceName: this.currentSourceName,
                currentSourceUrl: this.currentSourceUrl,
                downloadingFile: this.downloadingFile,
                onDownload: (fileName) => this.downloadAsset(fileName),
                onChangeSource: () => this.changeSource(),
                onDeleteAsset: (fileName) => this.deleteAsset(fileName)
              })

              // 卡片二：自定义规则 URL 入口
              Column() {
                Row({ space: 12 }) {
                  Row() {
                    Image($r('app.media.ic_link'))
                      .width(20)
                      .height(20)
                      .fillColor(AppColor.success)
                  }
                  .width(36)
                  .height(36)
                  .borderRadius(8)
                  .backgroundColor(AppColor.successTint)
                  .justifyContent(FlexAlign.Center)

                  Column() {
                    Text(this.t('assets.userUrls.title'))
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppColor.textPrimary)
                    Text(`${this.t('assets.userUrls.detail')} (已配置 ${this.customAssets.length} 个)`)
                      .fontSize(12)
                      .fontColor(AppColor.textSecondary)
                      .margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Start)

                  Blank()

                  Image($r('app.media.ic_chevron_right'))
                    .width(18)
                    .height(18)
                    .fillColor(AppColor.textTertiary)
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor(AppColor.surface)
              .borderRadius(16)
              .shadow({ radius: 8, color: AppColor.shadowCard, offsetX: 0, offsetY: 2 })
              .onClick(() => {
                this.showCustomUrls = true;
              })

              // 卡片三：配置备份与还原
              Column() {
                Row({ space: 8 }) {
                  Image($r('app.media.ic_settings'))
                    .width(18)
                    .height(18)
                    .fillColor(AppColor.textSecondary)
                  Text('配置备份与恢复')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppColor.textPrimary)
                }
                .width('100%')
                .margin({ bottom: 12 })

                Row({ space: 12 }) {
                  // 备份按钮
                  Column({ space: 4 }) {
                    Image($r('app.media.ic_share'))
                      .width(20)
                      .height(20)
                      .fillColor(AppColor.brand)
                    Text('备份配置')
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppColor.brand)
                    Text('导出配置至剪贴板')
                      .fontSize(10)
                      .fontColor(AppColor.textSecondary)
                  }
                  .layoutWeight(1)
                  .height(80)
                  .backgroundColor(AppColor.brandTint)
                  .borderRadius(12)
                  .justifyContent(FlexAlign.Center)
                  .onClick(() => {
                    this.backupConfig();
                  })

                  // 还原按钮
                  Column({ space: 4 }) {
                    Image($r('app.media.ic_refresh'))
                      .width(20)
                      .height(20)
                      .fillColor(AppColor.textSecondary)
                    Text('还原配置')
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppColor.textSecondary)
                    Text('从剪贴板读取覆盖')
                      .fontSize(10)
                      .fontColor(AppColor.textSecondary)
                  }
                  .layoutWeight(1)
                  .height(80)
                  .backgroundColor(AppColor.bg)
                  .borderRadius(12)
                  .justifyContent(FlexAlign.Center)
                  .onClick(() => {
                    this.restoreConfig();
                  })
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor(AppColor.surface)
              .borderRadius(16)
              .shadow({ radius: 8, color: AppColor.shadowCard, offsetX: 0, offsetY: 2 })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 14, bottom: 24 })
          }
          .layoutWeight(1)
          .width('100%')
        }
        .height('100%')
        .width('100%')
        .backgroundColor(AppColor.bg)
      } else {
        // 自定义 URL 管理视图
        CustomAssetList({
          language: this.language,
          customAssets: $customAssets,
          tempImportUri: $tempImportUri,
          onBack: () => {
            this.showCustomUrls = false;
            this.updateFileStatus();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  // 执行资源网络更新下载
  private async downloadAsset(fileName: string): Promise<void> {
    if (this.downloadingFile.length > 0) {
      promptAction.showToast({ message: '已有文件在下载中，请稍后' });
      return;
    }
    const context = getContext(this) as common.Context;
    await ASSETS_CONTROLLER.downloadAsset(
      context,
      fileName,
      `${this.currentSourceUrl}${fileName}`,
      this.language,
      () => {
        this.downloadingFile = fileName;
        this.updateFileStatus();
      },
      () => {},
      () => {},
      () => {
        this.downloadingFile = '';
        this.updateFileStatus();
      }
    );
  }

  // 顺序一键更新全部 Geo 资源
  private async downloadAllAssets(): Promise<void> {
    if (this.downloadingFile.length > 0) {
      promptAction.showToast({ message: '已有文件在下载中，请稍后' });
      return;
    }
    const context = getContext(this) as common.Context;
    this.downloadingFile = 'geosite.dat';
    this.updateFileStatus();
    await ASSETS_CONTROLLER.downloadAllAssets(
      context,
      this.currentSourceUrl,
      this.language,
      (fileName) => {
        this.downloadingFile = fileName;
        this.updateFileStatus();
      },
      (successGeosite, successGeoip) => {
        this.downloadingFile = '';
        this.updateFileStatus();
      }
    );
  }

  // 调起系统 Picker 导入本地 .dat 文件
  private async importLocalFile(): Promise<void> {
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.fileSuffixFilters = ['.dat'];
      documentSelectOptions.maxSelectNumber = 1;
      const documentPicker = new picker.DocumentViewPicker();
      const uris = await documentPicker.select(documentSelectOptions);
      if (!uris || uris.length === 0) {
        return;
      }
      const fileUri = uris[0];

      const menu: [promptAction.Button, promptAction.Button, promptAction.Button] = [
        { text: this.t('assets.importType.geosite'), color: AppColor.brand } as promptAction.Button,
        { text: this.t('assets.importType.geoip'), color: AppColor.brand } as promptAction.Button,
        { text: this.t('assets.importType.custom'), color: AppColor.brand } as promptAction.Button
      ];

      promptAction.showActionMenu({
        title: this.t('assets.selectImportType'),
        buttons: menu
      }).then(async (result) => {
        const context = getContext(this) as common.Context;
        if (result.index === 0) {
          await ASSETS_CONTROLLER.copyLocalFileToAssets(context, fileUri, 'geosite.dat', this.language, () => this.updateFileStatus(), () => {});
        } else if (result.index === 1) {
          await ASSETS_CONTROLLER.copyLocalFileToAssets(context, fileUri, 'geoip.dat', this.language, () => this.updateFileStatus(), () => {});
        } else if (result.index === 2) {
          // 自定义本地规则导入：记录临时 URI，并跳转到自定义列表以触发弹窗输入
          this.tempImportUri = fileUri;
          this.showCustomUrls = true;
        }
      });
    } catch (error) {
      promptAction.showToast({ message: `打开文件选择器失败: ${JSON.stringify(error)}` });
    }
  }

  // 切换下载源
  private changeSource(): void {
    const buttons: [promptAction.Button, promptAction.Button] = [
      { text: GEO_SOURCES[0].name, color: AppColor.brand } as promptAction.Button,
      { text: GEO_SOURCES[1].name, color: AppColor.brand } as promptAction.Button
    ];

    promptAction.showActionMenu({
      title: this.t('assets.source.title'),
      buttons: buttons
    }).then(async (result) => {
      if (result.index >= 0 && result.index < GEO_SOURCES.length) {
        const selected = GEO_SOURCES[result.index];
        this.currentSourceUrl = selected.url;
        this.currentSourceName = selected.name;

        const context = getContext(this) as common.Context;
        const assetStore = await preferences.getPreferences(context, 'hey_vpn_assets');
        await assetStore.put('geo_source_url', this.currentSourceUrl);
        await assetStore.flush();
        promptAction.showToast({ message: `下载源已切换为 ${selected.name}` });
      }
    });
  }

  // 删除 Geo 资源
  private deleteAsset(fileName: string): void {
    const context = getContext(this) as common.Context;
    ASSETS_CONTROLLER.deleteAsset(context, fileName, this.language, () => this.updateFileStatus());
  }

  private updateFileStatus(): void {
    const context = getContext(this) as common.Context;
    this.geositeStatus = ASSETS_CONTROLLER.getFileStatus(context, 'geosite.dat', this.language);
    this.geoipStatus = ASSETS_CONTROLLER.getFileStatus(context, 'geoip.dat', this.language);
  }

  // 加载自定义 Geo 链接
  private async loadCustomAssets(): Promise<void> {
    const context = getContext(this) as common.Context;
    this.customAssets = await AssetStore.load(context);
  }

  // 配置一键备份到剪贴板
  private async backupConfig(): Promise<void> {
    const context = getContext(this) as common.Context;
    await ASSETS_CONTROLLER.backupConfig(context, this.language);
  }

  // 配置从剪贴板一键还原
  private async restoreConfig(): Promise<void> {
    const context = getContext(this) as common.Context;
    await ASSETS_CONTROLLER.restoreConfig(
      context,
      this.language,
      () => {
        this.loadState();
        this.loadCustomAssets();
      },
      () => {}
    );
  }

  private async loadState(): Promise<void> {
    const context = getContext(this) as common.Context;
    this.language = (await SETTINGS_CONTROLLER.load(context)).language;

    // 从 preferences 加载下载源
    const assetStore = await preferences.getPreferences(context, 'hey_vpn_assets');
    const sourceUrl = await assetStore.get('geo_source_url', GEO_SOURCES[0].url);
    this.currentSourceUrl = sourceUrl.toString();
    const found = GEO_SOURCES.find(s => s.url === this.currentSourceUrl);
    this.currentSourceName = found ? found.name : GEO_SOURCES[0].name;

    this.updateFileStatus();
  }

  private t(key: string): string {
    return translate(this.language, key);
  }
}
