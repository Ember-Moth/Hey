import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import fs from '@ohos.file.fs';
import { AppLanguage } from '../../core/Profile';
import { translate } from '../../core/I18n';
import { ASSETS_CONTROLLER } from '../../features/assets/AssetsController';
import { AppColor } from '../../theme/Theme';

@Component
export struct BuiltinGeoCard {
  @Prop language: AppLanguage;
  @Prop geositeStatus: string;
  @Prop geoipStatus: string;
  @Prop currentSourceName: string;
  @Prop currentSourceUrl: string;
  @Prop downloadingFile: string;

  // 交互回调
  onDownload: (fileName: string) => void = () => {};
  onChangeSource: () => void = () => {};
  onDeleteAsset: (fileName: string) => void = () => {};

  private t(key: string): string {
    return translate(this.language, key);
  }

  build() {
    Column() {
      // 模块小标题
      Row({ space: 8 }) {
        Image($r('app.media.ic_folder'))
          .width(18)
          .height(18)
          .fillColor(AppColor.brand)
        Text('内置 Geo 规则资源库')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColor.textPrimary)
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 下载源选择配置项
      Row() {
        Column() {
          Text(this.t('assets.source.title'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textSecondary)
          Text(this.t('assets.source.detail'))
            .fontSize(11)
            .fontColor(AppColor.textTertiary)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Row({ space: 4 }) {
          Text(this.currentSourceName)
            .fontSize(13)
            .fontColor(AppColor.brand)
            .fontWeight(FontWeight.Medium)
          Image($r('app.media.ic_arrow_downward'))
            .width(14)
            .height(14)
            .fillColor(AppColor.brand)
        }
        .backgroundColor(AppColor.bg)
        .borderRadius(8)
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })
        .onClick(() => {
          this.onChangeSource();
        })
      }
      .width('100%')
      .padding({ top: 8, bottom: 12 })

      Divider()
        .color(AppColor.bg)
        .strokeWidth(1)
        .margin({ bottom: 12 })

      // geosite.dat 项
      this.GeoItemRow('geosite.dat', this.geositeStatus)

      Divider()
        .color(AppColor.bg)
        .strokeWidth(1)
        .margin({ top: 12, bottom: 12 })

      // geoip.dat 项
      this.GeoItemRow('geoip.dat', this.geoipStatus)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColor.surface)
    .borderRadius(16)
    .shadow({ radius: 8, color: AppColor.shadowCard, offsetX: 0, offsetY: 2 })
  }

  @Builder
  private GeoItemRow(fileName: string, status: string) {
    Row() {
      // 左边文件大图标与文字描述
      Row({ space: 12 }) {
        Row() {
          Image($r('app.media.ic_article'))
            .width(18)
            .height(18)
            .fillColor(AppColor.brand)
        }
        .width(36)
        .height(36)
        .borderRadius(8)
        .backgroundColor(AppColor.brandTint)
        .justifyContent(FlexAlign.Center)

        Column() {
          Text(fileName)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textPrimary)
          Text(status)
            .fontSize(11)
            .fontColor(AppColor.textSecondary)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
      }

      Blank()

      // 右侧操作
      Row({ space: 12 }) {
        if (this.downloadingFile === fileName) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(AppColor.brand)
        } else {
          // 快捷下载更新
          Button() {
            Image($r('app.media.ic_cloud_download'))
              .width(18)
              .height(18)
              .fillColor(AppColor.brand)
          }
          .width(32)
          .height(32)
          .backgroundColor('transparent')
          .onClick(() => {
            this.onDownload(fileName);
          })

          // 更多菜单
          Button() {
            Image($r('app.media.ic_more_vert'))
              .width(18)
              .height(18)
              .fillColor(AppColor.textSecondary)
          }
          .width(32)
          .height(32)
          .backgroundColor('transparent')
          .onClick(() => {
            this.handleAssetMoreClick(fileName);
          })
        }
      }
    }
    .width('100%')
  }

  private handleAssetMoreClick(fileName: string): void {
    const context = getContext(this) as common.Context;
    const exists = this.checkFileExists(context, fileName);

    const menu: [promptAction.Button, promptAction.Button] = [
      { text: this.t('action.update'), color: AppColor.brand } as promptAction.Button,
      { text: this.t('action.del'), color: exists ? '#EF4444' : '#9CA3AF' } as promptAction.Button
    ];

    promptAction.showActionMenu({
      title: fileName,
      buttons: menu
    }).then((result) => {
      if (result.index === 0) {
        this.onDownload(fileName);
      } else if (result.index === 1 && exists) {
        this.onDeleteAsset(fileName);
      }
    });
  }

  private checkFileExists(context: common.Context, fileName: string): boolean {
    const path = `${context.filesDir}/${fileName}`;
    try {
      return fs.accessSync(path);
    } catch (e) {
      return false;
    }
  }
}
