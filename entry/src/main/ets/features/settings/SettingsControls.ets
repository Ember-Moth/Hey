import { DEFAULT_LANGUAGE } from '../../core/I18n';
import { AppLanguage } from '../../core/Profile';

export type ToggleSettingHandler = (action: string) => void;
export type TextSettingHandler = (action: string, value: string) => void;
export type LanguageSelectHandler = (language: AppLanguage) => void;

@Component
export struct SettingToggleRow {
  title: string = '';
  settingKey: string = '';
  isEnabled: boolean = false;
  action: string = '';
  onLabel: string = '';
  offLabel: string = '';
  onToggle: ToggleSettingHandler = (_action: string) => {};

  build() {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
        Text(this.settingKey)
          .fontSize(12)
          .fontColor('#6B7280')
      }
      .layoutWeight(1)
      Button(this.isEnabled ? this.onLabel : this.offLabel)
        .height(32)
        .width(62)
        .fontSize(12)
        .backgroundColor(this.isEnabled ? '#166534' : '#E5E7EB')
        .fontColor(this.isEnabled ? '#FFFFFF' : '#374151')
        .borderRadius(6)
        .onClick(() => {
          this.onToggle(this.action);
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }
}

@Component
export struct LanguageToggleRow {
  title: string = '';
  settingKey: string = '';
  zhLabel: string = '';
  enLabel: string = '';
  language: AppLanguage = DEFAULT_LANGUAGE;
  onChange: LanguageSelectHandler = (_language: AppLanguage) => {};

  build() {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
        Text(this.settingKey)
          .fontSize(12)
          .fontColor('#6B7280')
      }
      .layoutWeight(1)

      Button(this.zhLabel)
        .height(32)
        .width(96)
        .fontSize(12)
        .backgroundColor(this.language === 'zh' ? '#111827' : '#E5E7EB')
        .fontColor(this.language === 'zh' ? '#FFFFFF' : '#374151')
        .borderRadius(6)
        .onClick(() => {
          this.onChange('zh');
        })
      Button(this.enLabel)
        .height(32)
        .width(96)
        .fontSize(12)
        .backgroundColor(this.language === 'en' ? '#111827' : '#E5E7EB')
        .fontColor(this.language === 'en' ? '#FFFFFF' : '#374151')
        .borderRadius(6)
        .onClick(() => {
          this.onChange('en');
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }
}

@Component
export struct SettingInputRow {
  title: string = '';
  settingKey: string = '';
  value: string = '';
  action: string = '';
  onChange: TextSettingHandler = (_action: string, _value: string) => {};

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
          .layoutWeight(1)
        Text(this.settingKey)
          .fontSize(12)
          .fontColor('#6B7280')
      }
      .width('100%')
      TextInput({ text: this.value, placeholder: this.title })
        .height(36)
        .width('100%')
        .fontSize(13)
        .backgroundColor('#F9FAFB')
        .borderRadius(6)
        .onChange((next: string) => {
          this.onChange(this.action, next);
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }
}
