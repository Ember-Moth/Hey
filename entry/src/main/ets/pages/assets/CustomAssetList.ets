import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import { AppLanguage } from '../../core/Profile';
import { translate } from '../../core/I18n';
import { ASSETS_CONTROLLER } from '../../features/assets/AssetsController';
import { AssetStore, CustomAssetUrl } from '../../storage/AssetStore';
import { AssetAddEditDialog } from './AssetAddEditDialog';
import { AppColor } from '../../theme/Theme';

@Component
export struct CustomAssetList {
  @Prop language: AppLanguage;
  @Link customAssets: Array<CustomAssetUrl>;
  @Link tempImportUri: string; // 用于从主页面传递过来本地导入的 URI
  onBack: () => void = () => {};

  @State private downloadingFile: string = '';

  // 弹窗状态管理
  @State private showAddEditDialog: boolean = false;
  @State private editId: string = '';
  @State private dialogTitle: string = '';
  @State private initialName: string = '';
  @State private initialUrl: string = '';

  private t(key: string): string {
    return translate(this.language, key);
  }

  aboutToAppear() {
    this.checkAutoImport();
  }

  // 监听 tempImportUri 的变化，如果主页面传入了临时 URI，则自动弹出添加弹窗
  private checkAutoImport() {
    if (this.tempImportUri && this.tempImportUri.length > 0) {
      this.editId = '';
      this.initialName = '';
      this.initialUrl = 'local://import';
      this.dialogTitle = this.t('assets.addUrlTitle');
      this.showAddEditDialog = true;
    }
  }

  build() {
    Stack() {
      // 列表主视图
      Column() {
        // 自定义 Header 栏
        Row() {
          Button() {
            Image($r('app.media.ic_arrow_back'))
              .width(24)
              .height(24)
              .fillColor(AppColor.textPrimary)
          }
          .width(40)
          .height(40)
          .backgroundColor('transparent')
          .onClick(() => {
            this.onBack();
          })

          Text(this.t('assets.userUrls.title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textPrimary)
            .margin({ left: 8 })

          Blank()
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor(AppColor.surface)
        .alignItems(VerticalAlign.Center)

        List({ space: 12 }) {
          ForEach(this.customAssets, (item: CustomAssetUrl) => {
            ListItem() {
              Column({ space: 8 }) {
                Row({ space: 10 }) {
                  Row() {
                    Image($r('app.media.ic_article'))
                      .width(16)
                      .height(16)
                      .fillColor(AppColor.success)
                  }
                  .width(28)
                  .height(28)
                  .borderRadius(6)
                  .backgroundColor(AppColor.successTint)
                  .justifyContent(FlexAlign.Center)

                  Column() {
                    Text(item.name)
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(AppColor.textPrimary)
                    Text(item.url.startsWith('local://') ? '本地导入规则库' : item.url)
                      .fontSize(11)
                      .fontColor(AppColor.textSecondary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width(200)
                  }
                  .alignItems(HorizontalAlign.Start)

                  Blank()

                  Text(this.getCustomFileStatus(item.name))
                    .fontSize(12)
                    .fontColor(AppColor.textTertiary)
                    .fontWeight(FontWeight.Medium)
                }
                .width('100%')

                Divider().color(AppColor.divider).strokeWidth(1).margin({ top: 4, bottom: 4 })

                Row() {
                  Blank()

                  Row({ space: 16 }) {
                    if (!item.url.startsWith('local://')) {
                      Button() {
                        Row({ space: 4 }) {
                          if (this.downloadingFile === item.name) {
                            LoadingProgress().width(12).height(12).color(AppColor.brand)
                          } else {
                            Image($r('app.media.ic_refresh'))
                              .width(12)
                              .height(12)
                              .fillColor(AppColor.brand)
                          }
                          Text(this.downloadingFile === item.name ? '下载中' : '更新')
                            .fontSize(12)
                            .fontColor(AppColor.brand)
                            .fontWeight(FontWeight.Medium)
                        }
                      }
                      .backgroundColor('transparent')
                      .onClick(() => {
                        this.downloadCustomAsset(item.name, item.url);
                      })
                    } else {
                      // 本地规则，可点击“重新导入”
                      Button() {
                        Row({ space: 4 }) {
                          Image($r('app.media.ic_folder'))
                            .width(12)
                            .height(12)
                            .fillColor(AppColor.brand)
                          Text('覆盖导入')
                            .fontSize(12)
                            .fontColor(AppColor.brand)
                            .fontWeight(FontWeight.Medium)
                        }
                      }
                      .backgroundColor('transparent')
                      .onClick(() => {
                        this.reimportLocalCustomAsset(item);
                      })
                    }

                    Button() {
                      Row({ space: 4 }) {
                        Image($r('app.media.ic_edit'))
                          .width(12)
                          .height(12)
                          .fillColor(AppColor.textSecondary)
                        Text('编辑')
                          .fontSize(12)
                          .fontColor(AppColor.textSecondary)
                          .fontWeight(FontWeight.Medium)
                      }
                    }
                    .backgroundColor('transparent')
                    .onClick(() => {
                      this.editId = item.id;
                      this.initialName = item.name;
                      this.initialUrl = item.url;
                      this.dialogTitle = this.t('assets.editUrlTitle');
                      this.showAddEditDialog = true;
                    })

                    Button() {
                      Row({ space: 4 }) {
                        Image($r('app.media.ic_delete'))
                          .width(12)
                          .height(12)
                          .fillColor(AppColor.danger)
                        Text('删除')
                          .fontSize(12)
                          .fontColor(AppColor.danger)
                          .fontWeight(FontWeight.Medium)
                      }
                    }
                    .backgroundColor('transparent')
                    .onClick(() => {
                      this.deleteCustomAsset(item);
                    })
                  }
                }
                .width('100%')
              }
              .padding(12)
              .backgroundColor(AppColor.surface)
              .borderRadius(12)
              .shadow({ radius: 4, color: AppColor.shadowCard, offsetX: 0, offsetY: 1 })
            }
          }, (item: CustomAssetUrl) => item.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 14, right: 14, top: 12 })

        // 底部控制面板
        Column() {
          Button() {
            Row({ space: 8 }) {
              Image($r('app.media.ic_add'))
                .width(18)
                .height(18)
                .fillColor(AppColor.onBrand)
              Text('添加资源 URL')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColor.onBrand)
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
          }
          .width('90%')
          .height(46)
          .margin({ bottom: 20, top: 12 })
          .backgroundColor(AppColor.brand)
          .borderRadius(12)
          .shadow({ radius: 8, color: 'rgba(0, 125, 255, 0.2)', offsetX: 0, offsetY: 4 })
          .onClick(() => {
            this.editId = '';
            this.initialName = '';
            this.initialUrl = '';
            this.dialogTitle = this.t('assets.addUrlTitle');
            this.showAddEditDialog = true;
          })
        }
        .width('100%')
        .backgroundColor(AppColor.surface)
        .border({ width: { top: 1 }, color: AppColor.divider })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColor.bg)

      // 添加/编辑弹窗 Overlay
      if (this.showAddEditDialog) {
        AssetAddEditDialog({
          language: this.language,
          title: this.dialogTitle,
          initialName: this.initialName,
          initialUrl: this.initialUrl,
          onCancel: () => {
            this.showAddEditDialog = false;
            this.tempImportUri = ''; // 清除主页面传递的临时 URI
          },
          onConfirm: (name, url) => {
            this.saveCustomAsset(name, url);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  // 获取自定义文件大小
  private getCustomFileStatus(name: string): string {
    const context = getContext(this) as common.Context;
    return ASSETS_CONTROLLER.getCustomFileStatus(context, name, this.language);
  }

  // 网络下载更新
  private async downloadCustomAsset(name: string, url: string): Promise<void> {
    if (this.downloadingFile.length > 0) {
      promptAction.showToast({ message: '已有文件在下载中，请稍后' });
      return;
    }
    const context = getContext(this) as common.Context;
    await ASSETS_CONTROLLER.downloadAsset(
      context,
      name,
      url,
      this.language,
      () => { this.downloadingFile = name; },
      () => {},
      () => {},
      () => { this.downloadingFile = ''; }
    );
  }

  // 本地文件覆盖导入
  private async reimportLocalCustomAsset(item: CustomAssetUrl): Promise<void> {
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
      const context = getContext(this) as common.Context;
      await ASSETS_CONTROLLER.copyLocalFileToAssets(
        context,
        fileUri,
        `${item.name}.dat`,
        this.language,
        () => {},
        () => {}
      );
    } catch (error) {
      promptAction.showToast({ message: `覆盖导入失败: ${JSON.stringify(error)}` });
    }
  }

  // 保存（新增/编辑）自定义 URL 
  private async saveCustomAsset(name: string, url: string): Promise<void> {
    const trimmedName = name.trim();
    const trimmedUrl = url.trim();

    if (trimmedName.length === 0) {
      promptAction.showToast({ message: this.t('assets.urlNameEmpty') });
      return;
    }

    const isLocalImport = trimmedUrl.startsWith('local://');
    if (!isLocalImport && !trimmedUrl.startsWith('http://') && !trimmedUrl.startsWith('https://')) {
      promptAction.showToast({ message: this.t('assets.urlAddressInvalid') });
      return;
    }

    const context = getContext(this) as common.Context;

    // 如果是本地导入且有临时导入的 URI，先执行文件拷贝
    if (isLocalImport && this.tempImportUri.length > 0) {
      const copySuccess = await ASSETS_CONTROLLER.copyLocalFileToAssets(
        context,
        this.tempImportUri,
        `${trimmedName}.dat`,
        this.language,
        () => {},
        () => {}
      );
      if (!copySuccess) {
        return; // 拷贝失败，不保存
      }
      this.tempImportUri = '';
    }

    if (this.editId.length > 0) {
      this.customAssets = this.customAssets.map(item => {
        if (item.id === this.editId) {
          return { id: item.id, name: trimmedName, url: trimmedUrl };
        }
        return item;
      });
    } else {
      const newItem: CustomAssetUrl = {
        id: Date.now().toString(),
        name: trimmedName,
        url: trimmedUrl
      };
      this.customAssets.push(newItem);
    }

    await AssetStore.save(context, this.customAssets);
    this.showAddEditDialog = false;
    promptAction.showToast({ message: '保存成功' });
  }

  // 删除自定义 URL
  private async deleteCustomAsset(item: CustomAssetUrl): Promise<void> {
    const context = getContext(this) as common.Context;
    this.customAssets = await ASSETS_CONTROLLER.deleteCustomAsset(context, item, this.customAssets);
  }
}
