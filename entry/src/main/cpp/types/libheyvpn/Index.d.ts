export interface NativeResult {
  ok: boolean;
  message: string;
}

export interface NativePingResult {
  ok: boolean;
  delayMs: number;
  message: string;
}

export interface RuntimeStats {
  uploadBytes: number;
  downloadBytes: number;
  xrayRunning: boolean;
  tun2SocksRunning: boolean;
  lastMessage: string;
}

export const validateConfig: (configJson: string) => NativeResult;
export const startXray: (configJson: string, workDir: string) => NativeResult;
export const stopXray: () => NativeResult;
export const startTun2Socks: (tunFd: number, host: string, port: number, mtu: number) => NativeResult;
export const stopTun2Socks: () => NativeResult;
export const getStats: () => RuntimeStats;
export const pingOutbound: (configJson: string, datDir: string, url: string, timeoutSeconds: number, proxy: string) => NativePingResult;
