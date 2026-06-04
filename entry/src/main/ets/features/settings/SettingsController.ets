import { common } from '@kit.AbilityKit';
import { AppLanguage, AppSettings } from '../../core/Profile';
import { DEFAULT_APP_SETTINGS, SettingsStore } from '../../storage/SettingsStore';

export interface SettingsDraft {
  language: AppLanguage;
  sniffingEnabled: boolean;
  routeOnlyEnabled: boolean;
  perAppProxyEnabled: boolean;
  perAppProxyList: string[];
  perAppProxyBypass: boolean;
  localDnsEnabled: boolean;
  fakeDnsEnabled: boolean;
  muxEnabled: boolean;
  fragmentEnabled: boolean;
  proxySharingEnabled: boolean;
  allowInsecure: boolean;
  remoteDns: string;
  domesticDns: string;
  vpnDns: string;
  logLevel: string;
  delayTestUrl: string;
  trafficMode: string;
  routingDomainStrategy: string;
}

export class SettingsController {
  async load(context: common.Context): Promise<AppSettings> {
    return SettingsStore.load(context);
  }

  async save(context: common.Context, draft: SettingsDraft): Promise<AppSettings> {
    return SettingsStore.save(context, this.buildSettings(draft));
  }

  toDraft(settings: AppSettings): SettingsDraft {
    return {
      language: settings.language,
      sniffingEnabled: settings.sniffingEnabled,
      routeOnlyEnabled: settings.routeOnlyEnabled,
      perAppProxyEnabled: settings.perAppProxyEnabled,
      perAppProxyList: settings.perAppProxyList ?? [],
      perAppProxyBypass: settings.perAppProxyBypass ?? true,
      localDnsEnabled: settings.localDnsEnabled,
      fakeDnsEnabled: settings.fakeDnsEnabled,
      muxEnabled: settings.muxEnabled,
      fragmentEnabled: settings.fragmentEnabled,
      proxySharingEnabled: settings.proxySharingEnabled,
      allowInsecure: settings.allowInsecure,
      remoteDns: settings.remoteDns,
      domesticDns: settings.domesticDns,
      vpnDns: settings.vpnDns,
      logLevel: settings.logLevel,
      delayTestUrl: settings.delayTestUrl,
      trafficMode: settings.trafficMode,
      routingDomainStrategy: settings.routingDomainStrategy
    };
  }

  buildSettings(draft: SettingsDraft): AppSettings {
    return {
      language: draft.language,
      sniffingEnabled: draft.sniffingEnabled,
      routeOnlyEnabled: draft.routeOnlyEnabled,
      perAppProxyEnabled: draft.perAppProxyEnabled,
      perAppProxyList: draft.perAppProxyList,
      perAppProxyBypass: draft.perAppProxyBypass,
      localDnsEnabled: draft.localDnsEnabled,
      fakeDnsEnabled: draft.fakeDnsEnabled,
      appendHttpProxy: DEFAULT_APP_SETTINGS.appendHttpProxy,
      muxEnabled: draft.muxEnabled,
      muxConcurrency: DEFAULT_APP_SETTINGS.muxConcurrency,
      muxXudpConcurrency: DEFAULT_APP_SETTINGS.muxXudpConcurrency,
      muxXudpQuic: DEFAULT_APP_SETTINGS.muxXudpQuic,
      fragmentEnabled: draft.fragmentEnabled,
      fragmentPackets: DEFAULT_APP_SETTINGS.fragmentPackets,
      fragmentLength: DEFAULT_APP_SETTINGS.fragmentLength,
      fragmentInterval: DEFAULT_APP_SETTINGS.fragmentInterval,
      preferIpv6: DEFAULT_APP_SETTINGS.preferIpv6,
      proxySharingEnabled: draft.proxySharingEnabled,
      allowInsecure: draft.allowInsecure,
      localDnsPort: DEFAULT_APP_SETTINGS.localDnsPort,
      vpnDns: draft.vpnDns.trim(),
      remoteDns: draft.remoteDns.trim(),
      domesticDns: draft.domesticDns.trim(),
      dnsHosts: DEFAULT_APP_SETTINGS.dnsHosts,
      delayTestUrl: draft.delayTestUrl.trim(),
      logLevel: draft.logLevel.trim().length > 0 ? draft.logLevel.trim() : DEFAULT_APP_SETTINGS.logLevel,
      mode: DEFAULT_APP_SETTINGS.mode,
      trafficMode: draft.trafficMode,
      routingDomainStrategy: draft.routingDomainStrategy
    };
  }

}

export const SETTINGS_CONTROLLER: SettingsController = new SettingsController();
