export type SelectionHandler = (value: string) => void;

@Component
export struct SelectionButton {
  label: string = '';
  itemValue: string = '';
  isSelected: boolean = false;
  labelSize: number = 12;
  activeBackground: string = '#111827';
  inactiveBackground: string = '#E5E7EB';
  activeTextColor: string = '#FFFFFF';
  inactiveTextColor: string = '#374151';
  onSelect: SelectionHandler = (_value: string) => {};

  build() {
    Button(this.label)
      .height(34)
      .layoutWeight(1)
      .fontSize(this.labelSize)
      .backgroundColor(this.isSelected ? this.activeBackground : this.inactiveBackground)
      .fontColor(this.isSelected ? this.activeTextColor : this.inactiveTextColor)
      .borderRadius(17)
      .onClick(() => {
        this.onSelect(this.itemValue);
      })
  }
}
