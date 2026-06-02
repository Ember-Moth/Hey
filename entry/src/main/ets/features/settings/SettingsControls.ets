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
    Row({ space: 14 }) {
      Column({ space: 3 }) {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1B1F')
        Text(this.settingKey)
          .fontSize(13)
          .fontColor('#49454F')
      }
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.isEnabled })
        .selectedColor('#F97910')
        .switchPointColor('#FFFFFF')
        .onChange((_isOn: boolean) => {
          this.onToggle(this.action);
        })
    }
    .width('100%')
    .height(72)
    .padding({ left: 24, right: 24, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
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
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1B1F')
        Text(this.settingKey)
          .fontSize(13)
          .fontColor('#49454F')
      }
      .layoutWeight(1)

      Button(this.zhLabel)
        .height(32)
        .width(96)
        .fontSize(12)
        .backgroundColor(this.language === 'zh' ? '#1C1B1F' : '#F2F2F2')
        .fontColor(this.language === 'zh' ? '#FFFFFF' : '#374151')
        .borderRadius(16)
        .onClick(() => {
          this.onChange('zh');
        })
      Button(this.enLabel)
        .height(32)
        .width(96)
        .fontSize(12)
        .backgroundColor(this.language === 'en' ? '#1C1B1F' : '#F2F2F2')
        .fontColor(this.language === 'en' ? '#FFFFFF' : '#374151')
        .borderRadius(16)
        .onClick(() => {
          this.onChange('en');
        })
    }
    .width('100%')
    .height(72)
    .padding({ left: 24, right: 24, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
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
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1B1F')
          .layoutWeight(1)
        Text(this.settingKey)
          .fontSize(13)
          .fontColor('#49454F')
      }
      .width('100%')
      TextInput({ text: this.value, placeholder: this.title })
        .height(42)
        .width('100%')
        .fontSize(16)
        .fontColor('#1C1B1F')
        .backgroundColor('#FFFFFF')
        .border({ width: { bottom: 1 }, color: '#6B7280' })
        .onChange((next: string) => {
          this.onChange(this.action, next);
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 14, bottom: 14 })
    .backgroundColor('#FFFFFF')
  }
}
