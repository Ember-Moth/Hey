export enum AppScreen {
  SERVERS = 'servers',
  IMPORT = 'import',
  SUBSCRIPTIONS = 'subscriptions',
  ROUTING = 'routing',
  SETTINGS = 'settings',
  PER_APP = 'perApp',
  ASSETS = 'assets',
  LOGS = 'logs',
  SCANNER = 'scanner',
  ABOUT = 'about'
}

export interface ScreenEntry {
  id: AppScreen;
  labelKey: string;
  titleKey: string;
}

export const SCREEN_ENTRIES: Array<ScreenEntry> = [
  { id: AppScreen.SERVERS, labelKey: 'screen.servers.label', titleKey: 'screen.servers.title' },
  { id: AppScreen.IMPORT, labelKey: 'screen.import.label', titleKey: 'screen.import.title' },
  { id: AppScreen.SUBSCRIPTIONS, labelKey: 'screen.subscriptions.label', titleKey: 'screen.subscriptions.title' },
  { id: AppScreen.ROUTING, labelKey: 'screen.routing.label', titleKey: 'screen.routing.title' },
  { id: AppScreen.SETTINGS, labelKey: 'screen.settings.label', titleKey: 'screen.settings.title' },
  { id: AppScreen.PER_APP, labelKey: 'screen.perApp.label', titleKey: 'screen.perApp.title' },
  { id: AppScreen.ASSETS, labelKey: 'screen.assets.label', titleKey: 'screen.assets.title' },
  { id: AppScreen.LOGS, labelKey: 'screen.logs.label', titleKey: 'screen.logs.title' },
  { id: AppScreen.SCANNER, labelKey: 'screen.scanner.label', titleKey: 'screen.scanner.title' },
  { id: AppScreen.ABOUT, labelKey: 'screen.about.label', titleKey: 'screen.about.title' }
];
