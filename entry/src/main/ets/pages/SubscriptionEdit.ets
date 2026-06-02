import { common } from '@kit.AbilityKit';
import { IconButton } from '../components/IconButton';
import { DEFAULT_LANGUAGE, translate } from '../core/I18n';
import { AppLanguage, SubscriptionGroup } from '../core/Profile';
import { SUBSCRIPTIONS_CONTROLLER, SubscriptionsControllerState } from '../features/subscriptions/SubscriptionsController';
import { SETTINGS_CONTROLLER } from '../features/settings/SettingsController';
import { AppRoute } from '../shell/AppRoute';
import { PageHeader } from '../shell/PageHeader';
import { router, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';

@Entry
@Component
struct SubscriptionEditPage {
  @State private language: AppLanguage = DEFAULT_LANGUAGE;
  @State private groupId: string = '';
  @State private pageTitle: string = '新建订阅分组';
  @State private groupName: string = '';
  @State private subscriptionUrl: string = '';
  @State private isBusy: boolean = false;
  
  // 按压微动画状态
  @State private isPressed: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    this.groupId = (params?.groupId as string) ?? '';
    if (this.groupId.length > 0) {
      this.pageTitle = '编辑订阅分组';
    } else {
      this.pageTitle = '新建订阅分组';
    }
    this.loadState();
  }

  build() {
    Column() {
      PageHeader({
        title: this.pageTitle,
        showBack: true
      })

      // 整体采用 Stack 布局，使保存按钮能够置底悬浮
      Stack({ alignContent: Alignment.Bottom }) {
        Scroll() {
          Column({ space: 16 }) {
            
            // 卡片一：分组名称
            Column({ space: 14 }) {
              Row({ space: 8 }) {
                // 橙色前缀指示条
                Column()
                  .width(4)
                  .height(16)
                  .backgroundColor('#F97910')
                  .borderRadius(2)
                
                Text('分组名称')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#111827')
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              TextInput({ text: this.groupName, placeholder: '请输入分组名称' })
                .height(48)
                .fontSize(15)
                .fontColor('#111827')
                .placeholderColor('#9CA3AF')
                .backgroundColor('#F3F4F6')
                .borderRadius(10)
                .onChange((val) => {
                  this.groupName = val;
                })

              Text('为您的配置订阅起一个好记的名字，例如“极速专线”或“主力订阅”。')
                .fontSize(12)
                .fontColor('#9CA3AF')
                .width('100%')
                .lineHeight(16)
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 2 })

            // 卡片二：订阅链接
            Column({ space: 14 }) {
              Row({ space: 8 }) {
                // 橙色前缀指示条
                Column()
                  .width(4)
                  .height(16)
                  .backgroundColor('#F97910')
                  .borderRadius(2)
                
                Text('订阅链接 (URL)')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#111827')
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Row() {
                Image($r('app.media.ic_link'))
                  .width(20)
                  .height(20)
                  .fillColor('#6B7280')
                  .margin({ left: 12, right: 8 })

                TextInput({
                  placeholder: '请输入 http:// 或 https:// 链接',
                  text: this.subscriptionUrl
                })
                  .layoutWeight(1)
                  .height(46)
                  .fontSize(14)
                  .fontColor('#111827')
                  .placeholderColor('#9CA3AF')
                  .backgroundColor('#00000000')
                  .onChange((value: string) => {
                    this.subscriptionUrl = value;
                  })

                // 右侧微背景独立小操作按钮
                Row({ space: 6 }) {
                  if (this.subscriptionUrl.length > 0) {
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
                    .onClick(() => {
                      this.subscriptionUrl = '';
                    })
                  }

                  Button() {
                    Image($r('app.media.ic_article'))
                      .width(15)
                      .height(15)
                      .fillColor('#4B5563')
                  }
                  .backgroundColor('#E5E7EB')
                  .width(28)
                  .height(28)
                  .borderRadius(14)
                  .onClick(() => {
                    this.pasteFromClipboard();
                  })

                  Button() {
                    Image($r('app.media.ic_qr_code'))
                      .width(15)
                      .height(15)
                      .fillColor('#4B5563')
                  }
                  .backgroundColor('#E5E7EB')
                  .width(28)
                  .height(28)
                  .borderRadius(14)
                  .onClick(() => {
                    router.pushUrl({ url: AppRoute.SCANNER });
                  })
                }
                .margin({ right: 8 })
              }
              .width('100%')
              .height(48)
              .backgroundColor('#F3F4F6')
              .borderRadius(10)
              .alignItems(VerticalAlign.Center)

              Text('目前支持导入解析标准的 Shadowsocks、VMess、VLESS 和 Trojan 等格式的链接内容。')
                .fontSize(12)
                .fontColor('#9CA3AF')
                .width('100%')
                .lineHeight(16)
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 2 })

          }
          .width('100%')
          // 底部 padding 为 100 避开底置悬浮大按钮
          .padding({ left: 16, right: 16, top: 16, bottom: 100 })
        }
        .width('100%')
        .height('100%')
        .align(Alignment.Top)

        // 底部悬浮操作栏（带磨砂玻璃模糊背景）
        Column() {
          Button() {
            Row() {
              if (this.isBusy) {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color('#FFFFFF')
                  .margin({ right: 8 })
              }
              Text('保存配置分组')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.isSaveEnabled() ? '#FFFFFF' : '#9CA3AF')
            }
          }
          .width('100%')
          .height(50)
          .borderRadius(12)
          .enabled(this.isSaveEnabled())
          .opacity(this.isSaveEnabled() ? 1.0 : 0.65)
          .linearGradient(this.isSaveEnabled() ? {
            angle: 90,
            colors: [['#FF8F3D', 0.0], ['#F97910', 1.0]]
          } : {
            angle: 90,
            colors: [['#E5E7EB', 0.0], ['#E5E7EB', 1.0]]
          })
          .shadow(this.isSaveEnabled() ? { radius: 10, color: '#30F97910', offsetX: 0, offsetY: 4 } : undefined)
          // 微缩按压弹性效果
          .scale({ x: this.isPressed ? 0.96 : 1.0, y: this.isPressed ? 0.96 : 1.0 })
          .animation({ duration: 150, curve: Curve.EaseOut })
          .onTouch((event) => {
            if (event.type === TouchType.Down) {
              this.isPressed = true;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.isPressed = false;
            }
          })
          .onClick(() => {
            this.saveGroup();
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
        .backgroundColor('#C0F3F4F6')
        .backgroundBlurStyle(BlurStyle.Thin)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#F3F4F6')
  }

  private isSaveEnabled(): boolean {
    return this.groupName.trim().length > 0 && !this.isBusy;
  }

  private async loadState(): Promise<void> {
    const context = getContext(this) as common.Context;
    this.language = (await SETTINGS_CONTROLLER.load(context)).language;
    
    if (this.groupId.length > 0) {
      this.pageTitle = '编辑订阅分组';
      const state = await SUBSCRIPTIONS_CONTROLLER.load(context, this.language);
      for (let i = 0; i < state.subscriptionGroups.length; i++) {
        if (state.subscriptionGroups[i].id === this.groupId) {
          const group = state.subscriptionGroups[i];
          this.groupName = group.name;
          this.subscriptionUrl = group.url;
          break;
        }
      }
    } else {
      this.pageTitle = '新建订阅分组';
    }
  }

  private async saveGroup(): Promise<void> {
    const name = this.groupName.trim();
    const url = this.subscriptionUrl.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '分组名称不能为空' });
      return;
    }
    
    this.isBusy = true;
    try {
      const context = getContext(this) as common.Context;
      let state: SubscriptionsControllerState;
      if (this.groupId.length === 0) {
        state = await SUBSCRIPTIONS_CONTROLLER.addGroup(context, name, url, this.language);
      } else {
        state = await SUBSCRIPTIONS_CONTROLLER.updateGroup(context, this.groupId, name, url, this.language);
      }
      promptAction.showToast({ message: state.subscriptionMessage });
      router.back();
    } catch (err) {
      promptAction.showToast({ message: '保存失败' });
    } finally {
      this.isBusy = false;
    }
  }

  private async pasteFromClipboard() {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      if (systemPasteboard.hasDataSync()) {
        const pasteData = await systemPasteboard.getData();
        const text = pasteData.getPrimaryText();
        if (text && text.trim().length > 0) {
          this.subscriptionUrl = text.trim();
          promptAction.showToast({ message: '已粘贴订阅链接' });
        } else {
          promptAction.showToast({ message: '剪贴板未发现有效链接' });
        }
      } else {
        promptAction.showToast({ message: '剪贴板为空' });
      }
    } catch (error) {
      promptAction.showToast({ message: '无法读取剪贴板' });
    }
  }
}
