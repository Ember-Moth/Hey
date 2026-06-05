import { ProxyNode, SubscriptionGroup } from '../../core/Profile';
import { IconButton } from '../../components/IconButton';
import { SubscriptionGroupListRow, SubscriptionNodeListRow } from './SubscriptionRows';
import { AppColor } from '../../theme/Theme';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';

export interface SubscriptionGroupRowModel {
  group: SubscriptionGroup;
  isSelected: boolean;
  summary: string;
}

export interface SubscriptionNodeRowModel {
  node: ProxyNode;
  isSelected: boolean;
  delayText: string;
  delayColor: string;
}

export type SubscriptionUrlHandler = (value: string) => void;
export type SubscriptionActionHandler = () => void;
export type SubscriptionGroupActionHandler = (group: SubscriptionGroup) => void;
export type SubscriptionNodeActionHandler = (node: ProxyNode) => void;

@Component
export struct SubscriptionManagerPanel {
  title: string = '';
  summary: string = '';
  urlPlaceholder: string = '';
  @Prop urlValue: string = '';
  saveGroupLabel: string = '';
  updateLabel: string = '';
  @Prop @Watch('onMessageChange') message: string = '';
  isBusy: boolean = false;
  isUpdating: boolean = false;
  groupRows: Array<SubscriptionGroupRowModel> = [];
  nodeRows: Array<SubscriptionNodeRowModel> = [];
  currentLabel: string = '';
  openLabel: string = '';
  onLabel: string = '';
  offLabel: string = '';
  deleteLabel: string = '';
  selectedLabel: string = '';
  useLabel: string = '';
  onUrlChange: SubscriptionUrlHandler = (_value: string) => {};
  onSaveGroup: SubscriptionActionHandler = () => {};
  onUpdate: SubscriptionActionHandler = () => {};
  onSelectGroup: SubscriptionGroupActionHandler = (_group: SubscriptionGroup) => {};
  onToggleGroup: SubscriptionGroupActionHandler = (_group: SubscriptionGroup) => {};
  onDeleteGroup: SubscriptionGroupActionHandler = (_group: SubscriptionGroup) => {};
  onSelectNode: SubscriptionNodeActionHandler = (_node: ProxyNode) => {};
  onScanQr: SubscriptionActionHandler = () => {};

  @State private showCard: boolean = false;
  @State private cardType: 'success' | 'error' | 'info' = 'info';
  private timerId: number = -1;

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
    }
  }

  onMessageChange() {
    if (!this.message || this.message.trim().length === 0) {
      this.showCard = false;
      return;
    }
    
    // 如果是正在更新的过渡提示，不以卡片形式打扰用户
    if (this.message.includes('正在') || this.message.includes('Updating') || this.message.includes('updating')) {
      this.showCard = false;
      return;
    }

    this.showCard = true;
    if (this.message.includes('失败') || this.message.includes('Failed') || this.message.includes('错误') || this.message.includes('error')) {
      this.cardType = 'error';
    } else if (this.message.includes('成功') || this.message.includes('Success') || this.message.includes('完成') || this.message.includes('Complete') || this.message.includes('保存')) {
      this.cardType = 'success';
    } else {
      this.cardType = 'info';
    }

    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
    }
    this.timerId = setTimeout(() => {
      this.showCard = false;
      this.timerId = -1;
    }, 4000);
  }

  private isButtonEnabled(): boolean {
    return this.urlValue.trim().length > 0 && !this.isUpdating && !this.isBusy;
  }

  private async pasteFromClipboard() {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      if (systemPasteboard.hasDataSync()) {
        const pasteData = await systemPasteboard.getData();
        const text = pasteData.getPrimaryText();
        if (text && text.trim().length > 0) {
          this.onUrlChange(text.trim());
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

  build() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textPrimary)
          Text(this.summary)
            .fontSize(12)
            .fontColor(AppColor.textSecondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      // 精美输入框设计，集成一键粘贴、一键清除、扫码
      Row() {
        Image($r('app.media.ic_link'))
          .width(20)
          .height(20)
          .fillColor(AppColor.textSecondary)
          .margin({ left: 12, right: 8 })

        TextInput({
          placeholder: this.urlPlaceholder,
          text: this.urlValue
        })
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor(AppColor.textPrimary)
          .placeholderColor(AppColor.textTertiary)
          .backgroundColor('#00000000')
          .onChange((value: string) => {
            this.onUrlChange(value);
          })

        if (this.urlValue.length > 0) {
          Button() {
            Text('✕')
              .fontSize(14)
              .fontColor(AppColor.textTertiary)
              .fontWeight(FontWeight.Bold)
          }
          .backgroundColor('#00000000')
          .width(36)
          .height(36)
          .onClick(() => {
            this.onUrlChange('');
          })
        }

        Button() {
          Image($r('app.media.ic_article'))
            .width(20)
            .height(20)
            .fillColor(AppColor.textSecondary)
        }
        .backgroundColor('#00000000')
        .width(36)
        .height(36)
        .onClick(() => {
          this.pasteFromClipboard();
        })

        Button() {
          Image($r('app.media.ic_qr_code'))
            .width(20)
            .height(20)
            .fillColor(AppColor.textSecondary)
        }
        .backgroundColor('#00000000')
        .width(36)
        .height(36)
        .margin({ right: 6 })
        .onClick(() => {
          this.onScanQr();
        })
      }
      .width('100%')
      .height(48)
      .backgroundColor(AppColor.surfaceAlt)
      .borderRadius(12)
      .border({ width: 1, color: AppColor.border })
      .alignItems(VerticalAlign.Center)

      // 合并为一键获取并更新按钮，具有加载状态
      Button() {
        Row({ space: 8 }) {
          if (this.isUpdating) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color(AppColor.onBrand)
          }
          Text(this.isUpdating ? '正在获取并更新节点...' : '获取并更新节点')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isButtonEnabled() ? AppColor.onBrand : AppColor.textTertiary)
        }
      }
      .width('100%')
      .height(44)
      .borderRadius(12)
      .enabled(this.isButtonEnabled())
      .opacity(this.isButtonEnabled() ? 1.0 : 0.65)
      .linearGradient(this.isButtonEnabled() ? {
        angle: 90,
        colors: [[AppColor.brandStrong, 0.0], [AppColor.brand, 1.0]]
      } : {
        angle: 90,
        colors: [[AppColor.border, 0.0], [AppColor.border, 1.0]]
      })
      .shadow(this.isButtonEnabled() ? { radius: 8, color: AppColor.shadowBrand, offsetX: 0, offsetY: 4 } : undefined)
      .onClick(() => {
        this.onUpdate();
      })

      // 成功/失败状态反馈卡片
      if (this.showCard) {
        Row({ space: 10 }) {
          Image(this.cardType === 'success' ? $r('app.media.ic_check') : $r('app.media.ic_info'))
            .width(18)
            .height(18)
            .fillColor(this.cardType === 'success' ? AppColor.success : this.cardType === 'error' ? AppColor.danger : AppColor.brand)

          Text(this.message)
            .fontSize(13)
            .fontColor(this.cardType === 'success' ? AppColor.success : this.cardType === 'error' ? AppColor.danger : AppColor.brand)
            .layoutWeight(1)

          Button() {
            Text('✕')
              .fontSize(12)
              .fontColor(this.cardType === 'success' ? AppColor.success : this.cardType === 'error' ? AppColor.danger : AppColor.brand)
              .fontWeight(FontWeight.Bold)
          }
          .backgroundColor('#00000000')
          .width(28)
          .height(28)
          .onClick(() => {
            this.showCard = false;
          })
        }
        .width('100%')
        .padding({ left: 12, right: 8, top: 10, bottom: 10 })
        .borderRadius(10)
        .backgroundColor(this.cardType === 'success' ? AppColor.successTint : this.cardType === 'error' ? AppColor.dangerTint : AppColor.brandTint)
        .border({
          width: 1,
          color: this.cardType === 'success' ? AppColor.success : this.cardType === 'error' ? AppColor.danger : AppColor.brand
        })
      }

      if (this.groupRows.length > 0) {
        Column({ space: 8 }) {
          ForEach(this.groupRows, (row: SubscriptionGroupRowModel) => {
            SubscriptionGroupListRow({
              group: row.group,
              isSelected: row.isSelected,
              summary: row.summary,
              currentLabel: this.currentLabel,
              openLabel: this.openLabel,
              onLabel: this.onLabel,
              offLabel: this.offLabel,
              deleteLabel: this.deleteLabel,
              onSelect: this.onSelectGroup,
              onToggle: this.onToggleGroup,
              onDelete: this.onDeleteGroup
            })
          }, (row: SubscriptionGroupRowModel, index: number) => `${index}-${row.group.id}`)
        }
        .width('100%')
      }

      if (this.nodeRows.length > 0) {
        Column({ space: 8 }) {
          ForEach(this.nodeRows, (row: SubscriptionNodeRowModel) => {
            SubscriptionNodeListRow({
              node: row.node,
              isSelected: row.isSelected,
              isBusy: this.isBusy,
              delayText: row.delayText,
              delayColor: row.delayColor,
              selectedLabel: this.selectedLabel,
              useLabel: this.useLabel,
              onSelect: this.onSelectNode
            })
          }, (row: SubscriptionNodeRowModel, index: number) => `${index}-${row.node.id}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColor.surface)
    .borderRadius(12)
    .shadow({ radius: 10, color: AppColor.shadowCard, offsetX: 0, offsetY: 2 })
  }
}
