import { common } from '@kit.AbilityKit';
import { ActionListItem } from '../components/ActionListItem';
import { SectionHeader } from '../components/SectionHeader';
import { DEFAULT_LANGUAGE, translate } from '../core/I18n';
import { AppLanguage } from '../core/Profile';
import { SETTINGS_CONTROLLER } from '../features/settings/SettingsController';
import { SHARED_RUNTIME_CONTROLLER } from '../features/runtime/RuntimeController';
import { PageHeader } from '../shell/PageHeader';
import { formatOne } from '../utils/LocalizationPresenter';

@Entry
@Component
struct AboutPage {
  @State private language: AppLanguage = DEFAULT_LANGUAGE;

  aboutToAppear(): void {
    this.loadState();
  }

  build() {
    Column() {
      PageHeader({
        title: this.t('screen.about.title'),
        summary: this.t('about.section.detail'),
        showBack: true,
        statusLabel: SHARED_RUNTIME_CONTROLLER.statusLabel(this.language),
        statusColor: SHARED_RUNTIME_CONTROLLER.statusColor(),
        statusBackground: SHARED_RUNTIME_CONTROLLER.statusBackground()
      })
      Scroll() {
        Column({ space: 10 }) {
          SectionHeader({ title: 'Hey', detail: this.t('about.section.detail') })
          this.RowItem(this.t('about.source.title'), this.t('about.source.detail'))
          this.RowItem(this.t('about.core.title'), this.t('about.core.detail'))
          this.RowItem(this.t('about.license.title'), this.t('about.license.detail'))
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
  private RowItem(title: string, detail: string) {
    ActionListItem({
      title,
      detail,
      actionLabel: this.t('action.open'),
      onAction: (openedTitle: string) => {
        SHARED_RUNTIME_CONTROLLER.appendLog(this.f1('log.presetOpened', 'title', openedTitle));
      }
    })
  }

  private async loadState(): Promise<void> {
    const context = getContext(this) as common.Context;
    this.language = (await SETTINGS_CONTROLLER.load(context)).language;
  }

  private t(key: string): string {
    return translate(this.language, key);
  }

  private f1(key: string, name: string, value: string): string {
    return formatOne(this.language, key, name, value);
  }
}
