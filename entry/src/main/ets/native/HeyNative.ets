import heyNative from 'libheyvpn.so';
import { RuntimeStats } from '../core/Profile';

export interface NativeResult {
  ok: boolean;
  message: string;
}

interface NativeBridge {
  validateConfig(configJson: string): NativeResult;
  startXray(configJson: string, workDir: string): NativeResult;
  stopXray(): NativeResult;
  startTun2Socks(tunFd: number, host: string, port: number, mtu: number): NativeResult;
  stopTun2Socks(): NativeResult;
  getStats(): RuntimeStats;
}

const bridge = heyNative as NativeBridge;

export function validateNativeConfig(configJson: string): NativeResult {
  return bridge.validateConfig(configJson);
}

export function startNativeXray(configJson: string, workDir: string): NativeResult {
  return bridge.startXray(configJson, workDir);
}

export function stopNativeXray(): NativeResult {
  return bridge.stopXray();
}

export function startNativeTun2Socks(tunFd: number, host: string, port: number, mtu: number): NativeResult {
  return bridge.startTun2Socks(tunFd, host, port, mtu);
}

export function stopNativeTun2Socks(): NativeResult {
  return bridge.stopTun2Socks();
}

export function getNativeStats(): RuntimeStats {
  return bridge.getStats();
}
