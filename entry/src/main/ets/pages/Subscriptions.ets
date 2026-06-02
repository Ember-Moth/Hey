import { common } from '@kit.AbilityKit';
import { DEFAULT_LANGUAGE, translate } from '../core/I18n';
import { AppLanguage, ProxyNode, SubscriptionGroup } from '../core/Profile';
import { NODES_CONTROLLER, NodesControllerState } from '../features/nodes/NodesController';
import {
  SubscriptionGroupRowModel,
  SubscriptionManagerPanel,
  SubscriptionNodeRowModel
} from '../features/subscriptions/SubscriptionPanel';
import { SUBSCRIPTIONS_CONTROLLER, SubscriptionsControllerState } from '../features/subscriptions/SubscriptionsController';
import { SETTINGS_CONTROLLER } from '../features/settings/SettingsController';
import { SHARED_RUNTIME_CONTROLLER } from '../features/runtime/RuntimeController';
import { AppRoute } from '../shell/AppRoute';
import { PageHeader } from '../shell/PageHeader';
import { formatOne, formatTwo } from '../utils/LocalizationPresenter';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct SubscriptionsPage {
  @State private language: AppLanguage = DEFAULT_LANGUAGE;
  @State private subscriptionUrl: string = '';
  @State private nodes: Array<ProxyNode> = [];
  @State private selectedNodeId: string = '';
  @State private subscriptionMessage: string = translate(DEFAULT_LANGUAGE, 'subscription.none');
  @State private subscriptionUpdatedAt: number = 0;
  @State private subscriptionGroups: Array<SubscriptionGroup> = [];
  @State private selectedGroupId: string = '';
  @State private isUpdating: boolean = false;

  aboutToAppear(): void {
    this.loadState();
  }

  build() {
    Column() {
      PageHeader({
        title: this.t('screen.subscriptions.title'),
        summary: this.f2('subscription.summary', 'groups', this.subscriptionGroups.length.toString(), 'nodes', this.nodes.length.toString()),
        showBack: true,
        statusLabel: SHARED_RUNTIME_CONTROLLER.statusLabel(this.language),
        statusColor: SHARED_RUNTIME_CONTROLLER.statusColor(),
        statusBackground: SHARED_RUNTIME_CONTROLLER.statusBackground()
      })
      Scroll() {
        Column({ space: 12 }) {
          this.SubscriptionPanel()

          Row({ space: 8 }) {
            Button(this.t('action.updateAll'))
              .height(38)
              .layoutWeight(1)
              .enabled(!this.isUpdating && !SHARED_RUNTIME_CONTROLLER.isBusy())
              .backgroundColor('#1D4ED8')
              .fontColor('#FFFFFF')
              .borderRadius(8)
              .onClick(() => {
                this.updateSubscription();
              })
            Button(this.t('action.scanUrl'))
              .height(38)
              .width(100)
              .backgroundColor('#E5E7EB')
              .fontColor('#374151')
              .borderRadius(8)
              .onClick(() => {
                router.pushUrl({ url: AppRoute.SCANNER });
              })
          }
          .width('100%')
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
  }

  @Builder
  private SubscriptionPanel() {
    SubscriptionManagerPanel({
      title: this.t('subscription.panelTitle'),
      summary: this.f2('subscription.summary', 'groups', this.subscriptionGroups.length.toString(), 'nodes', this.nodes.length.toString()),
      urlPlaceholder: this.t('placeholder.subscriptionUrl'),
      urlValue: this.subscriptionUrl,
      saveGroupLabel: this.t('action.saveGroup'),
      updateLabel: this.isUpdating ? this.t('action.updating') : this.t('action.update'),
      message: this.subscriptionMessage,
      isBusy: SHARED_RUNTIME_CONTROLLER.isBusy(),
      isUpdating: this.isUpdating,
      groupRows: this.subscriptionGroupRows(),
      nodeRows: this.subscriptionNodeRows(),
      currentLabel: this.t('action.current'),
      openLabel: this.t('action.open'),
      onLabel: this.t('action.on'),
      offLabel: this.t('action.off'),
      deleteLabel: this.t('action.del'),
      selectedLabel: this.t('action.selected'),
      useLabel: this.t('action.use'),
      onUrlChange: (value: string) => {
        this.subscriptionUrl = value;
      },
      onSaveGroup: () => {
        this.saveSubscriptionGroup();
      },
      onUpdate: () => {
        this.updateSubscription();
      },
      onSelectGroup: (group: SubscriptionGroup) => {
        this.selectSubscriptionGroup(group);
      },
      onToggleGroup: (group: SubscriptionGroup) => {
        this.toggleSubscriptionGroup(group);
      },
      onDeleteGroup: (group: SubscriptionGroup) => {
        this.removeSubscriptionGroup(group);
      },
      onSelectNode: (node: ProxyNode) => {
        this.selectNode(node);
      }
    })
  }

  private async loadState(): Promise<void> {
    const context = getContext(this) as common.Context;
    this.language = (await SETTINGS_CONTROLLER.load(context)).language;
    this.applySubscriptionsState(await SUBSCRIPTIONS_CONTROLLER.load(context, this.language));
  }

  private async saveSubscriptionGroup(): Promise<void> {
    const context = getContext(this) as common.Context;
    const state = await SUBSCRIPTIONS_CONTROLLER.saveGroup(context, this.subscriptionUrl, this.language);
    this.applySubscriptionsState(state);
    SHARED_RUNTIME_CONTROLLER.appendLog(state.subscriptionMessage);
  }

  private async updateSubscription(): Promise<void> {
    if (this.isUpdating) {
      return;
    }
    this.isUpdating = true;
    this.subscriptionMessage = this.t('log.updatingSubscription');
    SHARED_RUNTIME_CONTROLLER.appendLog(this.subscriptionMessage);
    try {
      const context = getContext(this) as common.Context;
      const state = await SUBSCRIPTIONS_CONTROLLER.update(context, this.subscriptionUrl, this.selectedNodeId, this.language);
      this.applySubscriptionsState(state);
      SHARED_RUNTIME_CONTROLLER.appendLog(state.subscriptionMessage);
    } finally {
      this.isUpdating = false;
    }
  }

  private async selectSubscriptionGroup(group: SubscriptionGroup): Promise<void> {
    const context = getContext(this) as common.Context;
    const state = await SUBSCRIPTIONS_CONTROLLER.selectGroup(context, group, this.language);
    this.applySubscriptionsState(state);
    SHARED_RUNTIME_CONTROLLER.appendLog(state.subscriptionMessage);
  }

  private async toggleSubscriptionGroup(group: SubscriptionGroup): Promise<void> {
    const context = getContext(this) as common.Context;
    const state = await SUBSCRIPTIONS_CONTROLLER.toggleGroup(context, group, this.language);
    this.applySubscriptionsState(state);
    SHARED_RUNTIME_CONTROLLER.appendLog(state.subscriptionMessage);
  }

  private async removeSubscriptionGroup(group: SubscriptionGroup): Promise<void> {
    const context = getContext(this) as common.Context;
    const state = await SUBSCRIPTIONS_CONTROLLER.removeGroup(context, group, this.language);
    this.applySubscriptionsState(state);
    SHARED_RUNTIME_CONTROLLER.appendLog(state.subscriptionMessage);
  }

  private async selectNode(node: ProxyNode): Promise<void> {
    const context = getContext(this) as common.Context;
    const state: NodesControllerState = await NODES_CONTROLLER.selectNode(context, node, this.language);
    this.nodes = state.nodes;
    this.selectedNodeId = state.selectedNodeId;
    this.subscriptionGroups = state.subscriptionGroups;
    this.selectedGroupId = state.selectedGroupId;
    SHARED_RUNTIME_CONTROLLER.appendLog(state.lastError.length > 0 ? state.lastError : this.f1('log.selectedNode', 'name', node.name));
  }

  private applySubscriptionsState(state: SubscriptionsControllerState): void {
    this.subscriptionUrl = state.subscriptionUrl;
    this.nodes = state.nodes;
    this.selectedNodeId = state.selectedNodeId;
    this.subscriptionMessage = state.subscriptionMessage;
    this.subscriptionUpdatedAt = state.subscriptionUpdatedAt;
    this.subscriptionGroups = state.subscriptionGroups;
    this.selectedGroupId = state.selectedGroupId;
  }

  private subscriptionGroupRows(): Array<SubscriptionGroupRowModel> {
    const rows: Array<SubscriptionGroupRowModel> = [];
    for (let index = 0; index < this.subscriptionGroups.length; index++) {
      const group = this.subscriptionGroups[index];
      rows.push({
        group,
        isSelected: group.id === this.selectedGroupId,
        summary: this.f2('group.enabledSummary', 'status', group.enabled ? this.t('common.enabled') : this.t('common.disabled'), 'count', group.nodes.length.toString())
      });
    }
    return rows;
  }

  private subscriptionNodeRows(): Array<SubscriptionNodeRowModel> {
    const rows: Array<SubscriptionNodeRowModel> = [];
    for (let index = 0; index < this.nodes.length; index++) {
      const node = this.nodes[index];
      rows.push({
        node,
        isSelected: node.id === this.selectedNodeId,
        delayText: this.nodeDelayText(node),
        delayColor: this.nodeDelayColor(node)
      });
    }
    return rows;
  }

  private nodeDelayText(node: ProxyNode): string {
    if (node.delayStatus === 'testing') {
      return this.t('node.delay.testing');
    }
    if (node.delayMs >= 0) {
      return this.f1('node.delay.ms', 'value', node.delayMs.toString());
    }
    if (node.delayStatus.length > 0) {
      return this.t('node.delay.failed');
    }
    return this.t('node.delay.pending');
  }

  private nodeDelayColor(node: ProxyNode): string {
    if (node.delayStatus === 'testing') {
      return '#1D4ED8';
    }
    if (node.delayMs >= 0) {
      if (node.delayMs <= 300) {
        return '#166534';
      }
      if (node.delayMs <= 900) {
        return '#92400E';
      }
    }
    if (node.delayStatus.length > 0) {
      return '#B42318';
    }
    return '#6B7280';
  }

  private t(key: string): string {
    return translate(this.language, key);
  }

  private f1(key: string, name: string, value: string): string {
    return formatOne(this.language, key, name, value);
  }

  private f2(key: string, name1: string, value1: string, name2: string, value2: string): string {
    return formatTwo(this.language, key, name1, value1, name2, value2);
  }
}
