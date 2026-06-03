import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export interface CustomAssetUrl {
  id: string;
  name: string;
  url: string;
}

const PREFERENCES_NAME: string = 'hey_vpn_assets';
const CUSTOM_ASSETS_KEY: string = 'custom_assets';

export class AssetStore {
  static async load(context: common.Context): Promise<Array<CustomAssetUrl>> {
    const store = await preferences.getPreferences(context, PREFERENCES_NAME);
    const rawValue = await store.get(CUSTOM_ASSETS_KEY, '');
    const raw = rawValue.toString();
    if (raw.length === 0) {
      return [];
    }
    try {
      return JSON.parse(raw) as Array<CustomAssetUrl>;
    } catch (error) {
      return [];
    }
  }

  static async save(context: common.Context, assets: Array<CustomAssetUrl>): Promise<void> {
    const store = await preferences.getPreferences(context, PREFERENCES_NAME);
    await store.put(CUSTOM_ASSETS_KEY, JSON.stringify(assets));
    await store.flush();
  }
}
