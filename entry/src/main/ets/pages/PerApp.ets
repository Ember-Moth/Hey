import { common } from '@kit.AbilityKit';
import { bundleManager } from '@kit.AbilityKit';
import { ActionListItem } from '../components/ActionListItem';
import { DEFAULT_LANGUAGE, translate } from '../core/I18n';
import { AppLanguage } from '../core/Profile';
import { SettingToggleRow } from '../features/settings/SettingsControls';
import { SETTINGS_CONTROLLER, SettingsDraft } from '../features/settings/SettingsController';
import { SHARED_RUNTIME_CONTROLLER } from '../features/runtime/RuntimeController';
import { PageHeader } from '../shell/PageHeader';
import { formatOne } from '../utils/LocalizationPresenter';
import { AppColor } from '../theme/Theme';

interface AppItem {
  bundleName: string;
  label: string;
  isSystem: boolean;
}

const SELF_BUNDLE_NAME: string = 'com.lmlm.hey';

const PRESET_MOCK_APPS: AppItem[] = [
  { bundleName: 'com.huawei.hbrowser', label: '华为浏览器', isSystem: true },
  { bundleName: 'com.tencent.mm', label: '微信', isSystem: false },
  { bundleName: 'com.eg.android.AlipayGphone', label: '支付宝', isSystem: false },
  { bundleName: 'com.ss.android.ugc.aweme', label: '抖音', isSystem: false },
  { bundleName: 'com.netease.cloudmusic', label: '网易云音乐', isSystem: false },
  { bundleName: 'com.sina.weibo', label: '微博', isSystem: false },
  { bundleName: 'com.sankuai.meituan', label: '美团', isSystem: false },
  { bundleName: 'com.xunmeng.pinduoduo', label: '拼多多', isSystem: false },
  { bundleName: 'com.huawei.music', label: '华为音乐', isSystem: true },
  { bundleName: 'com.huawei.photos', label: '图库', isSystem: true },
  { bundleName: 'com.huawei.appmarket', label: '应用市场', isSystem: true }
];

@Entry
@Component
struct PerAppPage {
  @State private language: AppLanguage = DEFAULT_LANGUAGE;
  @State private perAppProxyEnabled: boolean = false;
  @State private perAppProxyBypass: boolean = true; // true = 黑名单(绕过), false = 白名单(代理)
  @State private perAppProxyList: string[] = []; // 被选中的包名列表

  @State private allApps: AppItem[] = []; // 设备读取到的 + 预设应用列表
  @State private showSystemApps: boolean = true; // 是否显示系统应用
  @State private searchQuery: string = ''; // 搜索关键字
  @State private newCustomPackage: string = ''; // 自定义包名输入框内容
  @State private newCustomLabel: string = ''; // 自定义包名标签名输入框内容

  private draft: SettingsDraft | null = null;

  aboutToAppear(): void {
    this.loadState().then(() => {
      this.loadInstalledApps();
    });
  }

  // 加载设备上的应用列表，并合并预设与自定义的列表
  private async loadInstalledApps(): Promise<void> {
    let list: AppItem[] = [];

    // 由于 HarmonyOS NEXT 三方应用权限限制，且在最新 SDK 中禁用了已安装的全局应用枚举接口，
    // 我们在此配合预设应用和自定义录入包名，从而实现完整的黑白名单规则定制。
    SHARED_RUNTIME_CONTROLLER.appendLog("已载入分应用代理列表，可通过底部手动输入追加特定包名。");

    // 将预置大厂包名合并，并在此处显式排除掉当前应用自身，防止本应用出现在可选列表中
    PRESET_MOCK_APPS.forEach(preset => {
      if (preset.bundleName !== SELF_BUNDLE_NAME && !list.some(item => item.bundleName === preset.bundleName)) {
        list.push(preset);
      }
    });

    // 确保之前用户保存的已经在 list 中（万一有用户手动输入的，也把它加进去，并过滤剔除可能残留的自身包名）
    this.perAppProxyList.forEach(pkg => {
      if (pkg !== SELF_BUNDLE_NAME && !list.some(item => item.bundleName === pkg)) {
        list.push({
          bundleName: pkg,
          label: `自定义应用 (${pkg})`,
          isSystem: false
        });
      }
    });

    this.allApps = list;
  }

  // 过滤后的应用列表
  private getFilteredApps(): AppItem[] {
    return this.allApps.filter(app => {
      // 1. 系统应用显示控制
      if (!this.showSystemApps && app.isSystem) {
        return false;
      }
      // 2. 搜索过滤
      if (this.searchQuery.trim().length > 0) {
        const query = this.searchQuery.toLowerCase();
        const labelMatch = app.label.toLowerCase().includes(query);
        const pkgMatch = app.bundleName.toLowerCase().includes(query);
        return labelMatch || pkgMatch;
      }
      return true;
    });
  }

  build() {
    Column() {
      PageHeader({
        title: this.t('screen.perApp.title'),
        summary: this.t('settings.vpn.detail'),
        showBack: true
      })

      // 总开关与黑白名单模式选择
      Column({ space: 10 }) {
        // 分应用代理主开关
        SettingToggleRow({
          title: this.t('settings.perAppProxy'),
          settingKey: 'pref_per_app_proxy',
          isEnabled: this.perAppProxyEnabled,
          action: 'perApp',
          onLabel: this.t('action.on'),
          offLabel: this.t('action.off'),
          onToggle: (_action: string) => {
            this.perAppProxyEnabled = !this.perAppProxyEnabled;
            this.saveSettings();
          }
        })

        if (this.perAppProxyEnabled) {
          // 黑白名单模式选项 (Radio组合)
          Column() {
            Text("过滤策略模式")
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.textPrimary)
              .width('100%')
              .margin({ bottom: 8 })

            Row({ space: 24 }) {
              Row({ space: 6 }) {
                Radio({ value: 'bypass', group: 'proxy_mode' })
                  .checked(this.perAppProxyBypass)
                  .onChange((isChecked: boolean) => {
                    if (isChecked) {
                      this.perAppProxyBypass = true;
                      this.saveSettings();
                    }
                  })
                Text("仅绕过所选 (黑名单)")
                  .fontSize(14)
                  .fontColor(this.perAppProxyBypass ? AppColor.brand : AppColor.textSecondary)
                  .onClick(() => {
                    this.perAppProxyBypass = true;
                    this.saveSettings();
                  })
              }

              Row({ space: 6 }) {
                Radio({ value: 'proxy', group: 'proxy_mode' })
                  .checked(!this.perAppProxyBypass)
                  .onChange((isChecked: boolean) => {
                    if (isChecked) {
                      this.perAppProxyBypass = false;
                      this.saveSettings();
                    }
                  })
                Text("仅代理所选 (白名单)")
                  .fontSize(14)
                  .fontColor(!this.perAppProxyBypass ? AppColor.brand : AppColor.textSecondary)
                  .onClick(() => {
                    this.perAppProxyBypass = false;
                    this.saveSettings();
                  })
              }
            }
            .width('100%')
            .padding({ left: 4 })
          }
          .backgroundColor(AppColor.surface)
          .borderRadius(8)
          .padding(12)
          .width('100%')
        }
      }
      .padding({ left: 14, right: 14, top: 10, bottom: 4 })
      .width('100%')

      if (this.perAppProxyEnabled) {
        // 过滤区与快捷按钮
        Row() {
          // 搜索框
          Search({ placeholder: '搜索应用名称或包名...', value: this.searchQuery })
            .onChange((val: string) => {
              this.searchQuery = val;
            })
            .layoutWeight(1)
            .height(36)

          // 过滤系统应用开关
          Row({ space: 4 }) {
            Checkbox({ name: 'system_toggle', group: 'filter' })
              .select(this.showSystemApps)
              .width(18)
              .height(18)
              .onChange((selected: boolean) => {
                this.showSystemApps = selected;
              })
            Text("系统应用")
              .fontSize(12)
              .fontColor(AppColor.textSecondary)
          }
          .margin({ left: 10 })
        }
        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        .width('100%')

        // 快捷全选反选操作
        Row({ space: 16 }) {
          Button("全部全选", { type: ButtonType.Capsule })
            .backgroundColor(AppColor.surfaceAlt)
            .fontColor(AppColor.brand)
            .fontSize(12)
            .height(26)
            .onClick(() => {
              const filtered = this.getFilteredApps().map(app => app.bundleName);
              const merged = Array.from(new Set([...this.perAppProxyList, ...filtered]));
              this.perAppProxyList = merged;
              this.saveSettings();
            })

          Button("全部清除", { type: ButtonType.Capsule })
            .backgroundColor(AppColor.surfaceAlt)
            .fontColor(AppColor.danger)
            .fontSize(12)
            .height(26)
            .onClick(() => {
              const filtered = this.getFilteredApps().map(app => app.bundleName);
              this.perAppProxyList = this.perAppProxyList.filter(pkg => !filtered.includes(pkg));
              this.saveSettings();
            })

          Text(`已选: ${this.perAppProxyList.length} 个应用`)
            .fontSize(12)
            .fontColor(AppColor.textSecondary)
            .layoutWeight(1)
            .textAlign(TextAlign.End)
        }
        .padding({ left: 16, right: 16, top: 4, bottom: 6 })
        .width('100%')

        // 核心应用列表滚动区
        List({ space: 8 }) {
          ForEach(this.getFilteredApps(), (app: AppItem) => {
            ListItem() {
              Row() {
                // 圆形应用图标占位区
                Row() {
                  Text(app.label.charAt(0))
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppColor.onBrand)
                }
                .width(40)
                .height(40)
                .borderRadius(20)
                .backgroundColor(app.isSystem ? AppColor.textTertiary : AppColor.brand)
                .justifyContent(FlexAlign.Center)
                .alignItems(VerticalAlign.Center)
                .margin({ right: 12 })

                // 标签和包名信息
                Column() {
                  Text(app.label)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColor.textPrimary)
                    .margin({ bottom: 2 })
                  Text(app.bundleName)
                    .fontSize(11)
                    .fontColor(AppColor.textTertiary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                // 选中多选框
                Checkbox({ name: app.bundleName, group: 'apps' })
                  .select(this.perAppProxyList.includes(app.bundleName))
                  .onChange((selected: boolean) => {
                    if (selected) {
                      if (!this.perAppProxyList.includes(app.bundleName)) {
                        this.perAppProxyList.push(app.bundleName);
                      }
                    } else {
                      this.perAppProxyList = this.perAppProxyList.filter(pkg => pkg !== app.bundleName);
                    }
                    this.saveSettings();
                  })
              }
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor(AppColor.surface)
              .borderRadius(8)
              .width('100%')
            }
          }, (item: AppItem) => item.bundleName)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 14, right: 14 })

        // 底部手动录入追加区（解决包名枚举限制）
        Column() {
          Divider().color(AppColor.divider).margin({ bottom: 8 })
          Text("手动添加未列出的应用包名")
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textSecondary)
            .width('100%')
            .margin({ bottom: 6 })

          Row({ space: 8 }) {
            InputLabelPair({
              placeholder: '应用名称 (如: 百度地图)',
              text: this.newCustomLabel,
              onChange: (v: string) => { this.newCustomLabel = v; }
            }).layoutWeight(1)

            InputLabelPair({
              placeholder: '应用包名 (如: com.baidu.BaiduMap)',
              text: this.newCustomPackage,
              onChange: (v: string) => { this.newCustomPackage = v; }
            }).layoutWeight(1.5)

            Button("添加")
              .height(36)
              .fontSize(13)
              .backgroundColor(AppColor.brand)
              .onClick(() => {
                this.addCustomPackage();
              })
          }
          .width('100%')
        }
        .backgroundColor(AppColor.bg)
        .padding({ left: 14, right: 14, bottom: 12, top: 4 })
        .width('100%')
      } else {
        // 未开启分应用代理时的占位符
        Column({ space: 16 }) {
          Image($r('app.media.ic_apps')) // 使用已有的分应用代理大图标
            .width(64)
            .height(64)
            .opacity(0.3)
          Text("分应用代理已关闭")
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textTertiary)
          Text("当前所有应用的流量均会默认经过虚拟网卡代理，您可以在上方开启该功能进行按应用精准分流。")
            .fontSize(13)
            .fontColor(AppColor.textTertiary)
            .textAlign(TextAlign.Center)
            .width('80%')
            .lineHeight(18)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .height('100%')
    .width('100%')
    .backgroundColor(AppColor.bg)
  }

  // 手动新增包名逻辑
  private addCustomPackage(): void {
    const pkg = this.newCustomPackage.trim();
    const label = this.newCustomLabel.trim() || `自定义应用 (${pkg})`;
    if (pkg.length === 0) {
      SHARED_RUNTIME_CONTROLLER.appendLog("添加包名失败: 包名不能为空。");
      return;
    }
    if (!pkg.includes('.') || pkg.length < 5) {
      SHARED_RUNTIME_CONTROLLER.appendLog("添加包名失败: 输入的包名格式不合规。");
      return;
    }

    // 检查是否已经存在于所有应用中，如果不存在，则加入
    if (!this.allApps.some(app => app.bundleName === pkg)) {
      const updated = [...this.allApps];
      updated.push({
        bundleName: pkg,
        label,
        isSystem: false
      });
      this.allApps = updated;
    }

    // 自动勾选并保存
    if (!this.perAppProxyList.includes(pkg)) {
      this.perAppProxyList.push(pkg);
    }
    this.saveSettings();

    // 清空输入框
    this.newCustomPackage = '';
    this.newCustomLabel = '';
    SHARED_RUNTIME_CONTROLLER.appendLog(`已成功追加自定义代理应用: ${label}`);
  }

  private async loadState(): Promise<void> {
    const context = getContext(this) as common.Context;
    this.draft = SETTINGS_CONTROLLER.toDraft(await SETTINGS_CONTROLLER.load(context));
    this.language = this.draft.language;
    this.perAppProxyEnabled = this.draft.perAppProxyEnabled;
    this.perAppProxyList = this.draft.perAppProxyList ?? [];
    this.perAppProxyBypass = this.draft.perAppProxyBypass ?? true;
  }

  private async saveSettings(): Promise<void> {
    if (this.draft === null) {
      return;
    }
    this.draft.perAppProxyEnabled = this.perAppProxyEnabled;
    this.draft.perAppProxyList = this.perAppProxyList;
    this.draft.perAppProxyBypass = this.perAppProxyBypass;
    const context = getContext(this) as common.Context;
    this.draft = SETTINGS_CONTROLLER.toDraft(await SETTINGS_CONTROLLER.save(context, this.draft));
    SHARED_RUNTIME_CONTROLLER.appendLog(this.f1('log.settingsChanged', 'action', 'perApp'));
  }

  private t(key: string): string {
    return translate(this.language, key);
  }

  private f1(key: string, name: string, value: string): string {
    return formatOne(this.language, key, name, value);
  }
}

// 提取 of 辅助文本输入框组件，保证 UI 渲染效率和解耦
@Component
struct InputLabelPair {
  placeholder: string = '';
  @Link text: string;
  onChange: (v: string) => void = () => {};

  build() {
    TextInput({ placeholder: this.placeholder, text: this.text })
      .fontSize(12)
      .height(36)
      .placeholderColor(AppColor.textTertiary)
      .backgroundColor(AppColor.surface)
      .borderRadius(6)
      .onChange((v: string) => {
        this.text = v;
        this.onChange(v);
      })
  }
}
