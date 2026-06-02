import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { SelectionButton } from '../components/SelectionButton';
import { DEFAULT_LANGUAGE, translate } from '../core/I18n';
import { AppLanguage, AppSettings, ConnectionStatus, ProxyNode, RuntimeStats, SubscriptionGroup } from '../core/Profile';
import { DelayTester, DelayTestResult } from '../services/DelayTester';
import { SubscriptionStore } from '../storage/SubscriptionStore';
import { DEFAULT_APP_SETTINGS } from '../storage/SettingsStore';
import { NodeSortKey, filterAndSortNodes, findInvalidNodes } from '../features/nodes/NodeOperations';
import { NODES_CONTROLLER, NodesControllerState, SaveProfileResult } from '../features/nodes/NodesController';
import { ServerNodeCard } from '../features/servers/ServerCard';
import { SETTINGS_CONTROLLER } from '../features/settings/SettingsController';
import { RuntimeViewState, SHARED_RUNTIME_CONTROLLER } from '../features/runtime/RuntimeController';
import { SUBSCRIPTIONS_CONTROLLER, SubscriptionsControllerState } from '../features/subscriptions/SubscriptionsController';
import { AppRoute, HOME_ROUTE_ENTRIES, RouteEntry } from '../shell/AppRoute';
import { PageHeader } from '../shell/PageHeader';
import { formatBytes } from '../utils/Formatters';
import { formatOne, formatTwo, localizeCoreMessage } from '../utils/LocalizationPresenter';

const EMPTY_STATS: RuntimeStats = {
  uploadBytes: 0,
  downloadBytes: 0,
  xrayRunning: false,
  tun2SocksRunning: false,
  lastMessage: translate(DEFAULT_LANGUAGE, 'runtime.nativeBridgeNotQueried')
};

@Entry
@Component
struct Index {
  private timerId: number = -1;
  private currentSettings: AppSettings = DEFAULT_APP_SETTINGS;

  @State private language: AppLanguage = DEFAULT_LANGUAGE;
  @State private outboundJson: string = '';
  @State private validationMessage: string = translate(DEFAULT_LANGUAGE, 'validation.initial');
  @State private validationOk: boolean = false;
  @State private lastError: string = '';
  @State private profileUpdatedAt: string = translate(DEFAULT_LANGUAGE, 'profile.notSaved');
  @State private profileUpdatedAtValue: number = 0;
  @State private subscriptionUrl: string = '';
  @State private nodes: Array<ProxyNode> = [];
  @State private selectedNodeId: string = '';
  @State private subscriptionMessage: string = translate(DEFAULT_LANGUAGE, 'subscription.none');
  @State private subscriptionUpdatedAt: number = 0;
  @State private subscriptionGroups: Array<SubscriptionGroup> = [];
  @State private selectedGroupId: string = '';
  @State private searchQuery: string = '';
  @State private sortKey: NodeSortKey = 'delay';
  @State private subscriptionUpdating: boolean = false;
  @State private delayTesting: boolean = false;
  @State private status: ConnectionStatus = ConnectionStatus.IDLE;
  @State private elapsedText: string = '00:00';
  @State private stats: RuntimeStats = EMPTY_STATS;

  aboutToAppear(): void {
    this.loadInitialState();
    if (this.timerId < 0) {
      this.timerId = setInterval(() => {
        this.refreshRuntime();
      }, 1000);
    }
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  build() {
    Column() {
      PageHeader({
        title: this.t('screen.servers.title'),
        summary: this.f2('topbar.summary', 'nodes', this.nodes.length.toString(), 'status', this.statusLabel()),
        showBack: false,
        statusLabel: this.statusLabel(),
        statusColor: SHARED_RUNTIME_CONTROLLER.statusColor(),
        statusBackground: SHARED_RUNTIME_CONTROLLER.statusBackground()
      })

      Scroll() {
        Column({ space: 14 }) {
          this.ConnectionControls()
          this.NodeToolbar()

          if (this.lastError.length > 0) {
            Text(this.lastError)
              .fontSize(12)
              .fontColor('#B42318')
              .width('100%')
              .padding(10)
              .backgroundColor('#FEF3F2')
              .borderRadius(6)
          }

          this.NodeList()
          this.RouteList()
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
  private ConnectionControls() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Button(this.isRunning() ? this.t('action.stop') : this.t('action.start'))
          .height(42)
          .layoutWeight(1)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .enabled(!this.isBusy())
          .backgroundColor(this.isRunning() ? '#B42318' : '#166534')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .onClick(() => {
            if (this.isRunning()) {
              this.stopConnection();
            } else {
              this.startConnection();
            }
          })
        Button(this.t('action.restart'))
          .height(42)
          .width(92)
          .fontSize(13)
          .enabled(!this.isBusy())
          .backgroundColor('#1D4ED8')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .onClick(async () => {
            await this.stopConnection();
            await this.startConnection();
          })
      }
      .width('100%')

      Row({ space: 8 }) {
        Text(`${this.elapsedText}  ${formatBytes(this.stats.uploadBytes)} / ${formatBytes(this.stats.downloadBytes)}`)
          .fontSize(12)
          .fontColor('#6B7280')
          .layoutWeight(1)
        Text(this.localizeCoreMessage(this.stats.lastMessage))
          .fontSize(12)
          .fontColor('#374151')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private NodeToolbar() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        TextInput({ placeholder: this.t('action.search'), text: this.searchQuery })
          .height(38)
          .layoutWeight(1)
          .fontSize(13)
          .backgroundColor('#FFFFFF')
          .borderRadius(6)
          .onChange((value: string) => {
            this.searchQuery = value;
          })
        Button(this.t('action.add'))
          .height(38)
          .width(68)
          .fontSize(13)
          .backgroundColor('#E5E7EB')
          .fontColor('#374151')
          .borderRadius(6)
          .onClick(() => {
            this.openRoute(AppRoute.IMPORT);
          })
        Button(this.t('action.export'))
          .height(38)
          .width(76)
          .fontSize(13)
          .backgroundColor('#E5E7EB')
          .fontColor('#374151')
          .borderRadius(6)
          .onClick(() => {
            this.openRoute(AppRoute.EXPORT);
          })
      }
      .width('100%')

      Row({ space: 8 }) {
        this.SortButton('delay', this.t('sort.delay'))
        this.SortButton('name', this.t('sort.name'))
        this.SortButton('protocol', this.t('sort.protocol'))
      }
      .width('100%')

      Row({ space: 8 }) {
        Button(this.t('action.subUpdate'))
          .height(34)
          .layoutWeight(1)
          .fontSize(12)
          .enabled(!this.subscriptionUpdating && !this.isBusy())
          .backgroundColor('#EEF2FF')
          .fontColor('#3730A3')
          .borderRadius(6)
          .onClick(() => {
            this.updateSubscription();
          })
        Button(this.delayTesting ? this.t('node.delay.testing') : this.t('action.pingAll'))
          .height(34)
          .layoutWeight(1)
          .fontSize(12)
          .enabled(!this.delayTesting && !this.isBusy())
          .backgroundColor('#F3F4F6')
          .fontColor('#374151')
          .borderRadius(6)
          .onClick(() => {
            this.testVisibleNodeDelay();
          })
      }
      .width('100%')

      Row({ space: 8 }) {
        Button(this.t('action.dedupe'))
          .height(34)
          .layoutWeight(1)
          .fontSize(12)
          .backgroundColor('#F3F4F6')
          .fontColor('#374151')
          .borderRadius(6)
          .onClick(() => {
            this.dedupeNodes();
          })
        Button(this.t('action.removeInvalid'))
          .height(34)
          .layoutWeight(1)
          .fontSize(12)
          .backgroundColor('#F3F4F6')
          .fontColor('#374151')
          .borderRadius(6)
          .onClick(() => {
            this.removeInvalidNodes();
          })
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private SortButton(value: NodeSortKey, label: string) {
    SelectionButton({
      label,
      itemValue: value,
      isSelected: this.sortKey === value,
      labelSize: 12,
      onSelect: (nextValue: string) => {
        this.sortKey = nextValue as NodeSortKey;
      }
    })
  }

  @Builder
  private NodeList() {
    Column({ space: 8 }) {
      ForEach(this.visibleNodes(), (node: ProxyNode) => {
        ServerNodeCard({
          node,
          isSelected: node.id === this.selectedNodeId,
          isBusy: this.isBusy(),
          sourceLabel: node.sourceUrl.length > 0 ? this.t('node.source.subscription') : this.t('node.source.manual'),
          delayText: this.nodeDelayText(node),
          delayColor: this.nodeDelayColor(node),
          currentLabel: this.t('action.current'),
          useLabel: this.t('action.use'),
          openLabel: this.t('action.detail'),
          onSelect: (selectedNode: ProxyNode) => {
            this.selectNode(selectedNode);
          },
          onOpen: (openedNode: ProxyNode) => {
            this.openNodeDetail(openedNode);
          }
        })
      }, (node: ProxyNode) => node.id)
    }
    .width('100%')
  }

  @Builder
  private RouteList() {
    Column({ space: 8 }) {
      ForEach(HOME_ROUTE_ENTRIES, (entry: RouteEntry) => {
        Row({ space: 10 }) {
          Column({ space: 4 }) {
            Text(this.t(entry.titleKey))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#111827')
            Text(this.t(entry.labelKey))
              .fontSize(12)
              .fontColor('#6B7280')
          }
          .layoutWeight(1)
          Button(this.t('action.open'))
            .height(32)
            .width(68)
            .fontSize(12)
            .backgroundColor('#E5E7EB')
            .fontColor('#374151')
            .borderRadius(6)
            .onClick(() => {
              this.openRoute(entry.route);
            })
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
      }, (entry: RouteEntry) => entry.route)
    }
    .width('100%')
  }

  private async loadInitialState(): Promise<void> {
    await this.loadSettings();
    await this.loadNodes();
    await this.refreshRuntime();
  }

  private async loadSettings(): Promise<void> {
    try {
      const context = getContext(this) as common.Context;
      this.currentSettings = await SETTINGS_CONTROLLER.load(context);
      this.language = this.currentSettings.language;
    } catch (error) {
      this.lastError = this.f1('error.loadSettings', 'error', JSON.stringify(error));
      SHARED_RUNTIME_CONTROLLER.appendLog(this.lastError);
    }
  }

  private async loadNodes(): Promise<void> {
    try {
      const context = getContext(this) as common.Context;
      this.applyNodesState(await NODES_CONTROLLER.load(context, this.language));
    } catch (error) {
      this.lastError = this.f1('error.loadSubscription', 'error', JSON.stringify(error));
      SHARED_RUNTIME_CONTROLLER.appendLog(this.lastError);
    }
  }

  private async startConnection(): Promise<void> {
    const context = getContext(this) as common.Context;
    const saved = await NODES_CONTROLLER.saveProfile(context, this.outboundJson, this.language);
    this.applySaveProfileResult(saved);
    if (saved.profile === null) {
      SHARED_RUNTIME_CONTROLLER.appendLog(saved.lastError);
      return;
    }

    try {
      this.applyRuntimeState(await SHARED_RUNTIME_CONTROLLER.start(context, saved.profile, this.currentSettings, this.language));
    } catch (error) {
      this.lastError = this.f1('vpn.startFailed', 'error', JSON.stringify(error));
      SHARED_RUNTIME_CONTROLLER.appendLog(this.lastError);
    }
  }

  private async stopConnection(): Promise<void> {
    try {
      const context = getContext(this) as common.Context;
      this.applyRuntimeState(await SHARED_RUNTIME_CONTROLLER.stop(context, this.language));
    } catch (error) {
      this.lastError = this.f1('vpn.stopFailed', 'error', JSON.stringify(error));
      SHARED_RUNTIME_CONTROLLER.appendLog(this.lastError);
    }
  }

  private async updateSubscription(): Promise<void> {
    if (this.subscriptionUpdating) {
      return;
    }
    this.subscriptionUpdating = true;
    this.subscriptionMessage = this.t('log.updatingSubscription');
    SHARED_RUNTIME_CONTROLLER.appendLog(this.subscriptionMessage);
    try {
      const context = getContext(this) as common.Context;
      const state = await SUBSCRIPTIONS_CONTROLLER.update(context, this.subscriptionUrl, this.selectedNodeId, this.language);
      this.applySubscriptionsState(state);
      SHARED_RUNTIME_CONTROLLER.appendLog(state.subscriptionMessage);
      this.applyNodesState(await NODES_CONTROLLER.load(context, this.language));
    } finally {
      this.subscriptionUpdating = false;
    }
  }

  private async selectNode(node: ProxyNode): Promise<void> {
    const context = getContext(this) as common.Context;
    const state = await NODES_CONTROLLER.selectNode(context, node, this.language);
    this.applyNodesState(state);
    const message = state.lastError.length > 0 ? state.lastError : this.f1('log.selectedNode', 'name', node.name);
    SHARED_RUNTIME_CONTROLLER.appendLog(message);
  }

  private async dedupeNodes(): Promise<void> {
    const before = this.nodes.length;
    const context = getContext(this) as common.Context;
    this.applyNodesState(await NODES_CONTROLLER.dedupeActiveGroupNodes(context, this.language));
    const removed = Math.max(0, before - this.nodes.length);
    SHARED_RUNTIME_CONTROLLER.appendLog(this.f1('log.nodesDeduped', 'count', removed.toString()));
  }

  private async removeInvalidNodes(): Promise<void> {
    const invalid = findInvalidNodes(this.nodes).length;
    const context = getContext(this) as common.Context;
    this.applyNodesState(await NODES_CONTROLLER.removeInvalidNodes(context, this.language));
    SHARED_RUNTIME_CONTROLLER.appendLog(this.f1('log.invalidNodesRemoved', 'count', invalid.toString()));
  }

  private async testVisibleNodeDelay(): Promise<void> {
    if (this.delayTesting) {
      return;
    }
    const targets = this.visibleNodes();
    if (targets.length === 0) {
      return;
    }

    this.delayTesting = true;
    SHARED_RUNTIME_CONTROLLER.appendLog(this.t('log.delayQueued'));
    try {
      const context = getContext(this) as common.Context;
      for (let index = 0; index < targets.length; index++) {
        const node = targets[index];
        const startedAt = Date.now();
        this.markNodeDelay(node.id, -1, 'testing', startedAt);
        SHARED_RUNTIME_CONTROLLER.appendLog(this.f1('log.delayTestingNode', 'name', node.name));
        const result: DelayTestResult = await DelayTester.measure(this.currentSettings.delayTestUrl, 8000);
        const delayMs = result.ok ? result.delayMs : -1;
        const status = result.ok ? 'ok' : result.status;
        const subscription = await SubscriptionStore.saveNodeDelay(context, node.id, delayMs, status, Date.now());
        this.applySubscriptionsState({
          subscriptionUrl: subscription.url,
          nodes: subscription.nodes,
          selectedNodeId: subscription.selectedNodeId,
          subscriptionMessage: this.subscriptionMessage,
          subscriptionUpdatedAt: subscription.updatedAt,
          subscriptionGroups: subscription.groups,
          selectedGroupId: subscription.selectedGroupId
        });
        SHARED_RUNTIME_CONTROLLER.appendLog(this.f2('log.delayResult', 'name', node.name, 'result', this.delayResultText(result)));
      }
    } catch (error) {
      this.lastError = this.f1('error.delayTest', 'error', JSON.stringify(error));
      SHARED_RUNTIME_CONTROLLER.appendLog(this.lastError);
    } finally {
      this.delayTesting = false;
    }
  }

  private markNodeDelay(nodeId: string, delayMs: number, delayStatus: string, delayTestAt: number): void {
    const next = new Array<ProxyNode>();
    for (let index = 0; index < this.nodes.length; index++) {
      const node = this.nodes[index];
      if (node.id === nodeId) {
        next.push({
          id: node.id,
          name: node.name,
          protocol: node.protocol,
          outboundJson: node.outboundJson,
          sourceUrl: node.sourceUrl,
          rawLink: node.rawLink,
          updatedAt: node.updatedAt,
          delayMs,
          delayTestAt,
          delayStatus
        });
      } else {
        next.push(node);
      }
    }
    this.nodes = next;
  }

  private async refreshRuntime(): Promise<void> {
    try {
      const context = getContext(this) as common.Context;
      this.applyRuntimeState(await SHARED_RUNTIME_CONTROLLER.refresh(context, this.language));
    } catch (error) {
      this.lastError = JSON.stringify(error);
    }
  }

  private applyNodesState(state: NodesControllerState): void {
    this.outboundJson = state.outboundJson;
    this.validationOk = state.validationOk;
    this.validationMessage = state.validationMessage;
    this.profileUpdatedAt = state.profileUpdatedAt;
    this.profileUpdatedAtValue = state.profileUpdatedAtValue;
    this.subscriptionUrl = state.subscriptionUrl;
    this.nodes = state.nodes;
    this.selectedNodeId = state.selectedNodeId;
    this.subscriptionMessage = state.subscriptionMessage;
    this.subscriptionUpdatedAt = state.subscriptionUpdatedAt;
    this.subscriptionGroups = state.subscriptionGroups;
    this.selectedGroupId = state.selectedGroupId;
    this.lastError = state.lastError;
  }

  private applySaveProfileResult(result: SaveProfileResult): void {
    this.outboundJson = result.outboundJson;
    this.validationOk = result.validationOk;
    this.validationMessage = result.validationMessage;
    if (result.profile !== null) {
      this.profileUpdatedAt = result.profileUpdatedAt;
      this.profileUpdatedAtValue = result.profileUpdatedAtValue;
    }
    this.lastError = result.lastError;
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

  private applyRuntimeState(state: RuntimeViewState): void {
    this.status = state.status;
    this.elapsedText = state.elapsedText;
    this.stats = state.stats;
    this.lastError = state.lastError;
  }

  private visibleNodes(): Array<ProxyNode> {
    return filterAndSortNodes(this.nodes, this.searchQuery, this.sortKey);
  }

  private openRoute(route: AppRoute): void {
    router.pushUrl({ url: route });
  }

  private openNodeDetail(node: ProxyNode): void {
    router.pushUrl({
      url: AppRoute.NODE_DETAIL,
      params: {
        nodeId: node.id
      }
    });
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

  private delayResultText(result: DelayTestResult): string {
    if (result.ok) {
      return this.f1('node.delay.ms', 'value', result.delayMs.toString());
    }
    return `${this.t('node.delay.failed')} ${result.status}`;
  }

  private statusLabel(): string {
    return SHARED_RUNTIME_CONTROLLER.statusLabel(this.language);
  }

  private localizeCoreMessage(message: string): string {
    return localizeCoreMessage(this.language, message);
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

  private isRunning(): boolean {
    return this.status === ConnectionStatus.RUNNING;
  }

  private isBusy(): boolean {
    return this.status === ConnectionStatus.STARTING || this.status === ConnectionStatus.STOPPING;
  }
}
