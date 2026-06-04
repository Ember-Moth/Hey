/**
 * Hey VPN 设计令牌（暖橙主题 · 浅色/深色双主题）。
 *
 * 颜色统一走资源（app.color.*），在 resources/base 与 resources/dark 中
 * 各定义一份同名色板，系统会随明暗模式自动切换——所以 UI 代码只引用
 * 语义色（AppColor.brand 等），不再硬编码十六进制。
 *
 * 间距 / 圆角 / 字号 走 4 的倍数刻度，保持节奏统一。
 */

/** 语义化颜色。值由 resources/{base,dark}/element/color.json 提供，自动适配明暗。 */
export class AppColor {
  // 品牌
  static readonly brand: Resource = $r('app.color.brand');
  static readonly brandStrong: Resource = $r('app.color.brand_strong');
  static readonly brandPressed: Resource = $r('app.color.brand_pressed');
  static readonly brandTint: Resource = $r('app.color.brand_tint');
  static readonly onBrand: Resource = $r('app.color.on_brand');

  // 背景与表面
  static readonly bg: Resource = $r('app.color.bg');
  static readonly surface: Resource = $r('app.color.surface');
  static readonly surfaceAlt: Resource = $r('app.color.surface_alt');
  static readonly border: Resource = $r('app.color.border');
  static readonly divider: Resource = $r('app.color.divider');

  // 文字
  static readonly textPrimary: Resource = $r('app.color.text_primary');
  static readonly textSecondary: Resource = $r('app.color.text_secondary');
  static readonly textTertiary: Resource = $r('app.color.text_tertiary');

  // 状态
  static readonly success: Resource = $r('app.color.success');
  static readonly successTint: Resource = $r('app.color.success_tint');
  static readonly warning: Resource = $r('app.color.warning');
  static readonly danger: Resource = $r('app.color.danger');
  static readonly dangerTint: Resource = $r('app.color.danger_tint');
  static readonly info: Resource = $r('app.color.info');

  // 阴影 / 蒙层
  static readonly shadowCard: Resource = $r('app.color.shadow_card');
  static readonly shadowBrand: Resource = $r('app.color.shadow_brand');
  static readonly scrim: Resource = $r('app.color.scrim');
}

/** 间距刻度（4 / 8 栅格）。 */
export class Space {
  static readonly xs: number = 4;
  static readonly sm: number = 8;
  static readonly md: number = 12;
  static readonly lg: number = 16;
  static readonly xl: number = 20;
  static readonly xxl: number = 24;
  static readonly xxxl: number = 32;
}

/** 圆角刻度。 */
export class Radius {
  static readonly sm: number = 8;
  static readonly md: number = 12;
  static readonly lg: number = 16;
  static readonly xl: number = 20;
  static readonly pill: number = 999;
}

/** 字号刻度。 */
export class FontSz {
  static readonly caption: number = 11;
  static readonly footnote: number = 12;
  static readonly body: number = 14;
  static readonly callout: number = 15;
  static readonly headline: number = 17;
  static readonly title: number = 20;
  static readonly display: number = 26;
}

/** 阴影海拔（radius 用于内联 .shadow({...})，颜色取 AppColor.shadow*）。 */
export class Elevation {
  static readonly card: number = 16;
  static readonly raised: number = 24;
  static readonly glow: number = 28;
}
