export type IconButtonHandler = () => void;

@Component
export struct IconButton {
  icon: Resource = $r('app.media.ic_more_vert');
  iconSize: number = 24;
  buttonSize: number = 44;
  iconColor: string = '#1C1B1F';
  buttonBackground: string = '#00000000';
  radius: number = 22;
  isEnabled: boolean = true;
  onAction: IconButtonHandler = () => {};

  build() {
    Button() {
      Image(this.icon)
        .width(this.iconSize)
        .height(this.iconSize)
        .fillColor(this.iconColor)
    }
    .width(this.buttonSize)
    .height(this.buttonSize)
    .enabled(this.isEnabled)
    .backgroundColor(this.buttonBackground)
    .borderRadius(this.radius)
    .opacity(this.isEnabled ? 1 : 0.45)
    .onClick(() => {
      this.onAction();
    })
  }
}
