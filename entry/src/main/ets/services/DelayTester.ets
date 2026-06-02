import { http, socket } from '@kit.NetworkKit';
import { DEFAULT_SOCKS_HOST, DELAY_TEST_SOCKS_PORT, buildDelayTestConfig } from '../core/XrayConfig';
import { NativePingResult, pingNativeOutbound } from '../native/HeyNative';

export interface DelayTestResult {
  ok: boolean;
  delayMs: number;
  status: string;
}

function isCoreUnavailable(message: string): boolean {
  const lower = message.toLowerCase();
  return lower.indexOf('unavailable') >= 0 || lower.indexOf('failed to load') >= 0 || lower.indexOf('symbol missing') >= 0;
}

export class DelayTester {
  static async measureTcp(address: string, port: number, timeoutMs: number = 8000): Promise<DelayTestResult> {
    const target = address.trim();
    if (target.length === 0 || port <= 0 || port > 65535) {
      return {
        ok: false,
        delayMs: -1,
        status: 'invalid-endpoint'
      };
    }

    const startedAt = Date.now();
    const tcp = socket.constructTCPSocketInstance();
    try {
      await tcp.connect({
        address: {
          address: target,
          port
        },
        timeout: timeoutMs
      });
      return {
        ok: true,
        delayMs: Math.max(0, Date.now() - startedAt),
        status: 'tcp'
      };
    } catch (error) {
      return {
        ok: false,
        delayMs: -1,
        status: JSON.stringify(error)
      };
    } finally {
      try {
        await tcp.close();
      } catch (_) {
      }
    }
  }

  static async measureNodeOutbound(outboundJson: string, datDir: string, url: string, timeoutMs: number = 8000): Promise<DelayTestResult> {
    let configJson = '';
    try {
      configJson = buildDelayTestConfig(outboundJson).configJson;
    } catch (error) {
      return {
        ok: false,
        delayMs: -1,
        status: 'invalid-config'
      };
    }

    const proxy = `socks5://${DEFAULT_SOCKS_HOST}:${DELAY_TEST_SOCKS_PORT}`;
    const timeoutSeconds = Math.max(1, Math.floor(timeoutMs / 1000));
    try {
      const result: NativePingResult = pingNativeOutbound(configJson, datDir, url, timeoutSeconds, proxy);
      if (result.ok && result.delayMs >= 0) {
        return {
          ok: true,
          delayMs: result.delayMs,
          status: 'ok'
        };
      }

      if (isCoreUnavailable(result.message)) {
        const fallback = await DelayTester.measure(url, timeoutMs);
        return {
          ok: fallback.ok,
          delayMs: fallback.delayMs,
          status: fallback.ok ? 'direct' : fallback.status
        };
      }

      return {
        ok: false,
        delayMs: -1,
        status: result.message.length > 0 ? result.message : 'ping-failed'
      };
    } catch (error) {
      return {
        ok: false,
        delayMs: -1,
        status: JSON.stringify(error)
      };
    }
  }


  static async measure(url: string, timeoutMs: number = 8000): Promise<DelayTestResult> {
    const target = url.trim();
    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      return {
        ok: false,
        delayMs: -1,
        status: 'invalid-url'
      };
    }

    const startedAt = Date.now();
    const request = http.createHttp();
    try {
      const response = await request.request(target, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        readTimeout: timeoutMs,
        connectTimeout: timeoutMs,
        header: {
          'User-Agent': 'Hey/0.1 HarmonyOS NEXT Xray Client',
          'Accept': '*/*',
          'Cache-Control': 'no-cache'
        }
      });
      const delayMs = Math.max(0, Date.now() - startedAt);
      const responseCode = Number(response.responseCode);
      return {
        ok: responseCode >= 200 && responseCode < 500,
        delayMs,
        status: `HTTP ${responseCode}`
      };
    } catch (error) {
      return {
        ok: false,
        delayMs: -1,
        status: JSON.stringify(error)
      };
    } finally {
      request.destroy();
    }
  }
}
