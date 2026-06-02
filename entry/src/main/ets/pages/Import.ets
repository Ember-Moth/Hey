import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { SelectionButton } from '../components/SelectionButton';
import { DEFAULT_LANGUAGE, translate } from '../core/I18n';
import { AppLanguage } from '../core/Profile';
import { XrayConfigPanel } from '../features/import/ConfigPanel';
import { NODES_CONTROLLER, NodesControllerState, SaveProfileResult } from '../features/nodes/NodesController';
import { SETTINGS_CONTROLLER } from '../features/settings/SettingsController';
import { SHARED_RUNTIME_CONTROLLER } from '../features/runtime/RuntimeController';
import { SUBSCRIPTIONS_CONTROLLER } from '../features/subscriptions/SubscriptionsController';
import { AppRoute } from '../shell/AppRoute';
import { PageHeader } from '../shell/PageHeader';
import { formatOne } from '../utils/LocalizationPresenter';

@Entry
@Component
struct ImportPage {
  @State private language: AppLanguage = DEFAULT_LANGUAGE;
  @State private outboundJson: string = '';
  @State private validationMessage: string = translate(DEFAULT_LANGUAGE, 'validation.initial');
  @State private validationOk: boolean = false;
  @State private profileUpdatedAt: string = translate(DEFAULT_LANGUAGE, 'profile.notSaved');
  @State private importBuffer: string = '';
  @State private selectedImportProtocol: string = 'vless';
  @State private lastError: string = '';
  @State private isBusy: boolean = false;
  @State private selectedNodeId: string = '';

  aboutToAppear(): void {
    this.loadState();
  }

  build() {
    Column() {
      PageHeader({
        title: this.t('screen.import.title'),
        summary: this.validationMessage,
        showBack: true,
        statusLabel: SHARED_RUNTIME_CONTROLLER.statusLabel(this.language),
        statusColor: SHARED_RUNTIME_CONTROLLER.statusColor(),
        statusBackground: SHARED_RUNTIME_CONTROLLER.statusBackground()
      })
      Scroll() {
        Column({ space: 12 }) {
          Text(this.t('label.protocol'))
            .fontSize(13)
            .fontColor('#6B7280')
            .width('100%')
          Row({ space: 6 }) {
            this.ProtocolButton('vless')
            this.ProtocolButton('vmess')
            this.ProtocolButton('ss')
            this.ProtocolButton('trojan')
          }
          .width('100%')
          Row({ space: 6 }) {
            this.ProtocolButton('socks')
            this.ProtocolButton('http')
            this.ProtocolButton('wireguard')
            this.ProtocolButton('hy2')
          }
          .width('100%')

          TextArea({
            placeholder: this.t('placeholder.importPayload'),
            text: this.importBuffer
          })
            .height(220)
            .fontSize(13)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .padding(10)
            .onChange((value: string) => {
              this.importBuffer = value;
            })

          Row({ space: 8 }) {
            Button(this.t('action.import'))
              .height(40)
              .layoutWeight(1)
              .enabled(!this.isBusy)
              .backgroundColor('#166534')
              .fontColor('#FFFFFF')
              .borderRadius(8)
              .onClick(() => {
                this.importManualConfig();
              })
            Button(this.t('action.useCurrent'))
              .height(40)
              .width(116)
              .backgroundColor('#E5E7EB')
              .fontColor('#374151')
              .borderRadius(8)
              .onClick(() => {
                this.importBuffer = this.outboundJson;
              })
          }
          .width('100%')

          if (this.lastError.length > 0) {
            Text(this.lastError)
              .fontSize(12)
              .fontColor('#B42318')
              .width('100%')
              .padding(10)
              .backgroundColor('#FEF3F2')
              .borderRadius(6)
          }

          this.ConfigPanel()
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
  private ProtocolButton(protocol: string) {
    SelectionButton({
      label: protocol.toUpperCase(),
      itemValue: protocol,
      isSelected: this.selectedImportProtocol === protocol,
      labelSize: 11,
      onSelect: (value: string) => {
        this.selectedImportProtocol = value;
      }
    })
  }

  @Builder
  private ConfigPanel() {
    XrayConfigPanel({
      title: this.t('config.title'),
      updatedAt: this.profileUpdatedAt,
      placeholder: this.t('placeholder.outbound'),
      outboundJson: this.outboundJson,
      validLabel: this.t('config.valid'),
      invalidLabel: this.t('config.invalid'),
      validationOk: this.validationOk,
      validationMessage: this.validationMessage,
      importLabel: this.t('action.import'),
      isBusy: this.isBusy,
      onConfigChange: (value: string) => {
        this.outboundJson = value;
        this.validateConfig();
      },
      onImport: () => {
        this.normalizeConfigInput();
      }
    })
  }

  private async loadState(): Promise<void> {
    try {
      const context = getContext(this) as common.Context;
      this.language = (await SETTINGS_CONTROLLER.load(context)).language;
      this.applyNodesState(await NODES_CONTROLLER.load(context, this.language));
    } catch (error) {
      this.lastError = this.f1('error.loadProfile', 'error', JSON.stringify(error));
      SHARED_RUNTIME_CONTROLLER.appendLog(this.lastError);
    }
  }

  private validateConfig(): void {
    const validation = NODES_CONTROLLER.validateConfig(this.outboundJson, this.language);
    this.validationOk = validation.valid;
    this.validationMessage = validation.message;
  }

  private normalizeConfigInput(): void {
    const validation = NODES_CONTROLLER.validateConfig(this.outboundJson, this.language);
    this.validationOk = validation.valid;
    this.validationMessage = validation.message;
    if (!validation.valid) {
      this.lastError = this.validationMessage;
      SHARED_RUNTIME_CONTROLLER.appendLog(this.validationMessage);
      return;
    }
    this.outboundJson = validation.normalizedJson;
    this.lastError = '';
    SHARED_RUNTIME_CONTROLLER.appendLog(this.t('log.configImported'));
  }

  private async importManualConfig(): Promise<void> {
    const value = this.importBuffer.trim();
    if (value.length === 0) {
      this.lastError = this.t('error.emptyImport');
      SHARED_RUNTIME_CONTROLLER.appendLog(this.lastError);
      return;
    }

    this.isBusy = true;
    try {
      if (value.toLowerCase().startsWith('http://') || value.toLowerCase().startsWith('https://')) {
        const context = getContext(this) as common.Context;
        const state = await SUBSCRIPTIONS_CONTROLLER.update(context, value, this.selectedNodeId, this.language);
        SHARED_RUNTIME_CONTROLLER.appendLog(state.subscriptionMessage);
        router.pushUrl({ url: AppRoute.SUBSCRIPTIONS });
        return;
      }

      this.outboundJson = value;
      this.normalizeConfigInput();
      if (!this.validationOk) {
        return;
      }
      const context = getContext(this) as common.Context;
      const saved = await NODES_CONTROLLER.saveProfile(context, this.outboundJson, this.language);
      this.applySaveProfileResult(saved);
      if (saved.profile !== null) {
        this.importBuffer = this.outboundJson;
        SHARED_RUNTIME_CONTROLLER.appendLog(this.t('log.profileSaved'));
        router.back();
      }
    } finally {
      this.isBusy = false;
    }
  }

  private applyNodesState(state: NodesControllerState): void {
    this.outboundJson = state.outboundJson;
    this.validationOk = state.validationOk;
    this.validationMessage = state.validationMessage;
    this.profileUpdatedAt = state.profileUpdatedAt;
    this.selectedNodeId = state.selectedNodeId;
    this.lastError = state.lastError;
  }

  private applySaveProfileResult(result: SaveProfileResult): void {
    this.outboundJson = result.outboundJson;
    this.validationOk = result.validationOk;
    this.validationMessage = result.validationMessage;
    if (result.profile !== null) {
      this.profileUpdatedAt = result.profileUpdatedAt;
    }
    this.lastError = result.lastError;
  }

  private t(key: string): string {
    return translate(this.language, key);
  }

  private f1(key: string, name: string, value: string): string {
    return formatOne(this.language, key, name, value);
  }
}
