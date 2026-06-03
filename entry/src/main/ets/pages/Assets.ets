import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { pasteboard } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import fs from '@ohos.file.fs';
import { ActionListItem } from '../components/ActionListItem';
import { SectionHeader } from '../components/SectionHeader';
import { DEFAULT_LANGUAGE, translate } from '../core/I18n';
import { AppLanguage } from '../core/Profile';
import { SETTINGS_CONTROLLER } from '../features/settings/SettingsController';
import { SHARED_RUNTIME_CONTROLLER } from '../features/runtime/RuntimeController';
import { PageHeader } from '../shell/PageHeader';
import { formatOne, formatTwo } from '../utils/LocalizationPresenter';
import { AssetStore, CustomAssetUrl } from '../storage/AssetStore';

@Entry
@Component
struct AssetsPage {
  @State private language: AppLanguage = DEFAULT_LANGUAGE;

  // 文件状态信息
  @State private geositeStatus: string = '';
  @State private geoipStatus: string = '';

  // 自定义 URL 管理
  @State private showCustomUrls: boolean = false;
  @State private customAssets: Array<CustomAssetUrl> = [];

  // 添加/编辑自定义 URL 的输入框控制
  @State private showAddEditDialog: boolean = false;
  @State private editId: string = ''; // 若为空表示新增，不为空表示编辑
  @State private inputName: string = '';
  @State private inputUrl: string = '';

  // 下载状态
  @State private downloadingFile: string = '';

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
            Column({ space: 12 }) {
              SectionHeader({ title: this.t('assets.section'), detail: this.t('assets.section.detail') })
              this.RowItem('geosite.dat', this.geositeStatus, 'geosite.dat')
              this.RowItem('geoip.dat', this.geoipStatus, 'geoip.dat')
              this.RowItem(this.t('assets.userUrls.title'), this.t('assets.userUrls.detail'), 'userUrls')
              this.RowItem(this.t('assets.backupRestore.title'), this.t('assets.backupRestore.detail'), 'backupRestore')
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 14, bottom: 24 })
          }
          .layoutWeight(1)
          .width('100%')
        }
        .height('100%')
        .width('100%')
        .backgroundColor('#F6F8FA')
      } else {
        // 自定义 URL 管理视图
        Column() {
          // 自定义 Header 栏以支持返回到上一级视图
          Row() {
            Button() {
              Image($r('app.media.ic_arrow_back'))
                .width(24)
                .height(24)
                .fillColor('#1C1B1F')
            }
            .width(48)
            .height(48)
            .backgroundColor('transparent')
            .onClick(() => {
              this.showCustomUrls = false;
            })

            Text(this.t('assets.userUrls.title'))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1C1B1F')
              .margin({ left: 12 })
          }
          .width('100%')
          .height(60)
          .padding({ left: 8, right: 16 })
          .backgroundColor('#FFFFFF')
          .alignItems(VerticalAlign.Center)

          List({ space: 12 }) {
            ForEach(this.customAssets, (item: CustomAssetUrl) => {
              ListItem() {
                Column({ space: 8 }) {
                  Row() {
                    Text(item.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#111827')
                    Blank()
                    Text(this.getCustomFileStatus(item.name))
                      .fontSize(12)
                      .fontColor('#9CA3AF')
                  }
                  .width('100%')

                  Text(item.url)
                    .fontSize(12)
                    .fontColor('#6B7280')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')

                  Row({ space: 16 }) {
                    Blank()

                    Button() {
                      Row({ space: 4 }) {
                        if (this.downloadingFile === item.name) {
                          LoadingProgress().width(14).height(14).color('#007DFF')
                        }
                        Text(this.downloadingFile === item.name ? '下载中' : '更新')
                          .fontSize(12)
                          .fontColor('#007DFF')
                      }
                    }
                    .backgroundColor('transparent')
                    .onClick(() => {
                      this.downloadAsset(item.name, item.url);
                    })

                    Button('编辑')
                      .fontSize(12)
                      .fontColor('#4B5563')
                      .backgroundColor('transparent')
                      .onClick(() => {
                        this.editId = item.id;
                        this.inputName = item.name;
                        this.inputUrl = item.url;
                        this.showAddEditDialog = true;
                      })

                    Button('删除')
                      .fontSize(12)
                      .fontColor('#EF4444')
                      .backgroundColor('transparent')
                      .onClick(() => {
                        this.deleteCustomAsset(item);
                      })
                  }
                  .width('100%')
                }
                .padding(14)
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
              }
            }, (item: CustomAssetUrl) => item.id)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 14, right: 14, top: 12 })

          Button('添加资源 URL')
            .width('90%')
            .height(44)
            .margin({ bottom: 20 })
            .backgroundColor('#007DFF')
            .borderRadius(10)
            .onClick(() => {
              this.editId = '';
              this.inputName = '';
              this.inputUrl = '';
              this.showAddEditDialog = true;
            })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#F6F8FA')
      }

      // 添加/编辑自定义 URL 弹窗 Overlay
      if (this.showAddEditDialog) {
        Stack() {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('#80000000')
            .onClick(() => {
              this.showAddEditDialog = false;
            })

          Column({ space: 16 }) {
            Text(this.editId.length > 0 ? this.t('assets.editUrlTitle') : this.t('assets.addUrlTitle'))
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#111827')

            Column({ space: 8 }) {
              Text(this.t('assets.urlName'))
                .fontSize(12)
                .fontColor('#6B7280')
                .alignSelf(ItemAlign.Start)
              TextInput({ text: this.inputName, placeholder: 'e.g. custom_geo' })
                .height(40)
                .backgroundColor('#F3F4F6')
                .onChange((val) => this.inputName = val)

              Text(this.t('assets.urlAddress'))
                .fontSize(12)
                .fontColor('#6B7280')
                .alignSelf(ItemAlign.Start)
                .margin({ top: 8 })
              TextInput({ text: this.inputUrl, placeholder: 'https://...' })
                .height(40)
                .backgroundColor('#F3F4F6')
                .onChange((val) => this.inputUrl = val)
            }

            Row({ space: 12 }) {
              Button('取消')
                .layoutWeight(1)
                .backgroundColor('#E5E7EB')
                .fontColor('#374151')
                .height(36)
                .onClick(() => {
                  this.showAddEditDialog = false;
                })

              Button('确认')
                .layoutWeight(1)
                .backgroundColor('#007DFF')
                .fontColor('#FFFFFF')
                .height(36)
                .onClick(() => {
                  this.saveCustomAsset();
                })
            }
          }
          .width('85%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private RowItem(title: string, detail: string, tag: string) {
    ActionListItem({
      title,
      detail,
      onAction: () => {
        this.handleRowClick(tag);
      }
    })
  }

  private handleRowClick(tag: string): void {
    if (tag === 'geosite.dat' || tag === 'geoip.dat') {
      this.handleAssetRowClick(tag);
    } else if (tag === 'userUrls') {
      this.showCustomUrls = true;
    } else if (tag === 'backupRestore') {
      const menu: [promptAction.Button, promptAction.Button] = [
        { text: '备份配置至剪贴板', color: '#007DFF' } as promptAction.Button,
        { text: '从剪贴板还原配置', color: '#007DFF' } as promptAction.Button
      ];
      promptAction.showActionMenu({
        title: this.t('assets.backupRestore.title'),
        buttons: menu
      }).then((result) => {
        if (result.index === 0) {
          this.backupConfig();
        } else if (result.index === 1) {
          this.restoreConfig();
        }
      });
    }
  }

  private handleAssetRowClick(fileName: string): void {
    const context = getContext(this) as common.Context;
    const path = `${context.filesDir}/${fileName}`;
    let exists = false;
    try {
      exists = fs.accessSync(path);
    } catch (e) {}

    if (!exists) {
      this.downloadAsset(fileName);
    } else {
      const menu: [promptAction.Button, promptAction.Button] = [
        { text: this.t('action.update'), color: '#007DFF' } as promptAction.Button,
        { text: this.t('action.del'), color: '#007DFF' } as promptAction.Button
      ];
      promptAction.showActionMenu({
        title: fileName,
        buttons: menu
      }).then((result) => {
        if (result.index === 0) {
          this.downloadAsset(fileName);
        } else if (result.index === 1) {
          this.deleteAsset(fileName);
        }
      });
    }
  }

  // 获取本地 dat 文件大小和修改日期
  private getFileStatus(fileName: string): string {
    const context = getContext(this) as common.Context;
    const path = `${context.filesDir}/${fileName}`;
    try {
      if (fs.accessSync(path)) {
        const stat = fs.statSync(path);
        const sizeMb = (stat.size / (1024 * 1024)).toFixed(2);
        const date = new Date(stat.mtime * 1000);
        const timeStr = `${date.getFullYear()}/${this.pad(date.getMonth() + 1)}/${this.pad(date.getDate())} ${this.pad(date.getHours())}:${this.pad(date.getMinutes())}:${this.pad(date.getSeconds())}`;
        return formatTwo(this.language, 'assets.fileStatus', 'size', sizeMb, 'time', timeStr);
      }
    } catch (e) {}
    return this.t('assets.notDownloaded');
  }

  // 获取自定义资源的大小
  private getCustomFileStatus(name: string): string {
    const context = getContext(this) as common.Context;
    const path = `${context.filesDir}/${name}.dat`;
    try {
      if (fs.accessSync(path)) {
        const stat = fs.statSync(path);
        const sizeMb = (stat.size / (1024 * 1024)).toFixed(2);
        return `${sizeMb} MB`;
      }
    } catch (e) {}
    return this.t('assets.notDownloaded');
  }

  private pad(val: number): string {
    return val < 10 ? `0${val}` : `${val}`;
  }

  // 执行资源网络更新下载
  private async downloadAsset(fileName: string, customUrl?: string): Promise<void> {
    if (this.downloadingFile.length > 0) {
      promptAction.showToast({ message: '已有文件在下载中，请稍后' });
      return;
    }

    let url = '';
    if (customUrl && customUrl.length > 0) {
      url = customUrl;
    } else {
      if (fileName === 'geoip.dat') {
        url = 'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat';
      } else if (fileName === 'geosite.dat') {
        url = 'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat';
      }
    }

    if (url.length === 0) {
      return;
    }

    this.downloadingFile = fileName;
    this.updateFileStatus();

    const context = getContext(this) as common.Context;
    const tempPath = `${context.filesDir}/${fileName}.tmp`;
    const targetPath = `${context.filesDir}/${fileName.endsWith('.dat') ? fileName : fileName + '.dat'}`;

    const request = http.createHttp();
    try {
      promptAction.showToast({ message: this.t('assets.downloading').replace('{title}', fileName) });
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        readTimeout: 60000,
        connectTimeout: 15000,
        usingCache: false
      });

      if (response.responseCode === 200) {
        const file = fs.openSync(tempPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
        fs.writeSync(file.fd, response.result as ArrayBuffer);
        fs.closeSync(file);

        try {
          if (fs.accessSync(targetPath)) {
            fs.unlinkSync(targetPath);
          }
        } catch (e) {}

        fs.renameSync(tempPath, targetPath);
        promptAction.showToast({ message: this.t('assets.downloadSuccess').replace('{title}', fileName) });
      } else {
        throw new Error(`HTTP ${response.responseCode}`);
      }
    } catch (error) {
      try {
        if (fs.accessSync(tempPath)) {
          fs.unlinkSync(tempPath);
        }
      } catch (e) {}

      const errMsg = error instanceof Error ? error.message : JSON.stringify(error);
      promptAction.showToast({
        message: this.t('assets.downloadFailed')
          .replace('{title}', fileName)
          .replace('{error}', errMsg)
      });
    } finally {
      request.destroy();
      this.downloadingFile = '';
      this.updateFileStatus();
    }
  }

  // 删除 Geo 资源
  private deleteAsset(fileName: string): void {
    const context = getContext(this) as common.Context;
    const targetPath = `${context.filesDir}/${fileName}`;
    try {
      if (fs.accessSync(targetPath)) {
        fs.unlinkSync(targetPath);
        promptAction.showToast({ message: this.t('assets.deleteSuccess').replace('{title}', fileName) });
      }
    } catch (error) {
      promptAction.showToast({ message: `删除失败: ${JSON.stringify(error)}` });
    } finally {
      this.updateFileStatus();
    }
  }

  private updateFileStatus(): void {
    this.geositeStatus = this.getFileStatus('geosite.dat');
    this.geoipStatus = this.getFileStatus('geoip.dat');
  }

  // 加载自定义 Geo 链接
  private async loadCustomAssets(): Promise<void> {
    const context = getContext(this) as common.Context;
    this.customAssets = await AssetStore.load(context);
  }

  // 保存自定义 URL
  private async saveCustomAsset(): Promise<void> {
    const name = this.inputName.trim();
    const url = this.inputUrl.trim();

    if (name.length === 0) {
      promptAction.showToast({ message: this.t('assets.urlNameEmpty') });
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      promptAction.showToast({ message: this.t('assets.urlAddressInvalid') });
      return;
    }

    const context = getContext(this) as common.Context;
    if (this.editId.length > 0) {
      this.customAssets = this.customAssets.map(item => {
        if (item.id === this.editId) {
          return { id: item.id, name, url };
        }
        return item;
      });
    } else {
      const newItem: CustomAssetUrl = {
        id: Date.now().toString(),
        name,
        url
      };
      this.customAssets.push(newItem);
    }

    await AssetStore.save(context, this.customAssets);
    this.showAddEditDialog = false;
    promptAction.showToast({ message: '保存成功' });
  }

  // 删除自定义 URL 链接及本地 dat 文件
  private async deleteCustomAsset(item: CustomAssetUrl): Promise<void> {
    const context = getContext(this) as common.Context;
    const path = `${context.filesDir}/${item.name}.dat`;
    try {
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (e) {}

    this.customAssets = this.customAssets.filter(asset => asset.id !== item.id);
    await AssetStore.save(context, this.customAssets);
    promptAction.showToast({ message: '已删除自定义链接及本地缓存' });
  }

  // 配置一键备份到剪贴板
  private async backupConfig(): Promise<void> {
    const context = getContext(this) as common.Context;
    try {
      const profileStore = await preferences.getPreferences(context, 'hey_vpn_profile');
      const settingsStore = await preferences.getPreferences(context, 'hey_vpn_settings');
      const subStore = await preferences.getPreferences(context, 'hey_vpn_subscription');
      const assetStore = await preferences.getPreferences(context, 'hey_vpn_assets');

      const profileVal = await profileStore.get('default_profile', '');
      const settingsVal = await settingsStore.get('app_settings', '');
      const subVal = await subStore.get('subscription_profile', '');
      const assetVal = await assetStore.get('custom_assets', '');

      const backupObj: Record<string, string | boolean> = {
        'hey_backup': true,
        'profile': profileVal.toString(),
        'settings': settingsVal.toString(),
        'subscription': subVal.toString(),
        'assets': assetVal.toString()
      };

      const backupStr = JSON.stringify(backupObj);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, backupStr);
      await systemPasteboard.setData(pasteData);
      promptAction.showToast({ message: this.t('assets.backupSuccess') });
      SHARED_RUNTIME_CONTROLLER.appendLog('已完成应用配置备份并复制到剪贴板。');
    } catch (error) {
      promptAction.showToast({ message: this.t('assets.backupFailed').replace('{error}', JSON.stringify(error)) });
    }
  }

  // 配置从剪贴板一键还原
  private async restoreConfig(): Promise<void> {
    const context = getContext(this) as common.Context;
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      if (!systemPasteboard.hasDataSync()) {
        promptAction.showToast({ message: this.t('prompt.clipboardEmpty') });
        return;
      }
      const pasteData = await systemPasteboard.getData();
      const text = pasteData.getPrimaryText();
      if (!text || text.trim().length === 0) {
        promptAction.showToast({ message: this.t('prompt.clipboardEmpty') });
        return;
      }

      const backupObj = JSON.parse(text.trim()) as Record<string, Object>;
      if (backupObj['hey_backup'] !== true) {
        promptAction.showToast({ message: this.t('assets.invalidBackupData') });
        return;
      }

      const profileStore = await preferences.getPreferences(context, 'hey_vpn_profile');
      const settingsStore = await preferences.getPreferences(context, 'hey_vpn_settings');
      const subStore = await preferences.getPreferences(context, 'hey_vpn_subscription');
      const assetStore = await preferences.getPreferences(context, 'hey_vpn_assets');

      if (backupObj['profile'] !== undefined) {
        await profileStore.put('default_profile', backupObj['profile'].toString());
        await profileStore.flush();
      }
      if (backupObj['settings'] !== undefined) {
        await settingsStore.put('app_settings', backupObj['settings'].toString());
        await settingsStore.flush();
      }
      if (backupObj['subscription'] !== undefined) {
        await subStore.put('subscription_profile', backupObj['subscription'].toString());
        await subStore.flush();
      }
      if (backupObj['assets'] !== undefined) {
        await assetStore.put('custom_assets', backupObj['assets'].toString());
        await assetStore.flush();
      }

      promptAction.showToast({ message: this.t('assets.restoreSuccess') });
      SHARED_RUNTIME_CONTROLLER.appendLog('应用配置已成功还原。');

      this.loadState();
      this.loadCustomAssets();
    } catch (error) {
      promptAction.showToast({ message: this.t('assets.restoreFailed').replace('{error}', JSON.stringify(error)) });
    }
  }

  private async loadState(): Promise<void> {
    const context = getContext(this) as common.Context;
    this.language = (await SETTINGS_CONTROLLER.load(context)).language;
    this.updateFileStatus();
  }

  private t(key: string): string {
    return translate(this.language, key);
  }
}
