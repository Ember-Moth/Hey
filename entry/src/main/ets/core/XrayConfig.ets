import { GeneratedXrayConfig, ValidationResult } from './Profile';
import { isSupportedShareLink, parseShareLinkToOutboundJson } from './ShareLinkParser';

interface XrayOutbound {
  protocol?: string;
  tag?: string;
  settings?: Object;
  streamSettings?: Object;
  mux?: Object;
}

interface XrayLogConfig {
  loglevel: string;
}

interface XrayInboundConfig {
  tag: string;
  listen: string;
  port: number;
  protocol: string;
  settings: Object;
}

interface XrayRoutingConfig {
  domainStrategy: string;
  rules: Array<Object>;
}

interface XrayFullConfig {
  log: XrayLogConfig;
  inbounds: Array<XrayInboundConfig>;
  outbounds: Array<XrayOutbound>;
  routing: XrayRoutingConfig;
}

class SocksInboundSettings {
  auth: string = 'noauth';
  udp: boolean = true;
  userLevel: number = 0;
}

class EmptySettings {
}

const SUPPORTED_PROTOCOLS: Array<string> = ['vless', 'vmess', 'trojan', 'shadowsocks', 'socks', 'http', 'wireguard', 'hysteria2'];

export const DEFAULT_SOCKS_HOST: string = '127.0.0.1';
export const DEFAULT_SOCKS_PORT: number = 10808;

function isSupportedProtocol(protocol: string): boolean {
  return SUPPORTED_PROTOCOLS.indexOf(protocol.toLowerCase()) >= 0;
}

function parseOutbound(outboundJson: string): XrayOutbound {
  return JSON.parse(outboundJson) as XrayOutbound;
}

export function validateOutboundJson(outboundJson: string): ValidationResult {
  const trimmed = outboundJson.trim();
  if (trimmed.length === 0) {
    return {
      valid: false,
      message: '请先粘贴 Xray outbound JSON。',
      protocol: '',
      normalizedJson: ''
    };
  }

  try {
    const outbound = parseOutbound(trimmed);
    if (outbound.protocol === undefined || outbound.protocol.trim().length === 0) {
      return {
        valid: false,
        message: 'outbound 缺少 protocol 字段。',
        protocol: '',
        normalizedJson: ''
      };
    }

    if (!isSupportedProtocol(outbound.protocol)) {
      return {
        valid: false,
        message: `暂不支持 ${outbound.protocol}，当前支持 VLESS、VMess、Trojan、Shadowsocks、SOCKS、HTTP、WireGuard 和 Hysteria2。`,
        protocol: outbound.protocol,
        normalizedJson: ''
      };
    }

    if (outbound.settings === undefined) {
      return {
        valid: false,
        message: 'outbound 缺少 settings 字段。',
        protocol: outbound.protocol,
        normalizedJson: ''
      };
    }

    return {
      valid: true,
      message: `${outbound.protocol.toUpperCase()} outbound 校验通过。`,
      protocol: outbound.protocol,
      normalizedJson: JSON.stringify(outbound, null, 2)
    };
  } catch (error) {
    return {
      valid: false,
      message: `JSON 解析失败：${JSON.stringify(error)}`,
      protocol: '',
      normalizedJson: ''
    };
  }
}

export function normalizeOutboundInput(input: string): ValidationResult {
  const trimmed = input.trim();
  if (!isSupportedShareLink(trimmed)) {
    return validateOutboundJson(trimmed);
  }

  const imported = parseShareLinkToOutboundJson(trimmed);
  if (!imported.success) {
    return {
      valid: false,
      message: imported.message,
      protocol: imported.protocol,
      normalizedJson: ''
    };
  }

  const validation = validateOutboundJson(imported.outboundJson);
  if (!validation.valid) {
    return validation;
  }

  return {
    valid: true,
    message: imported.message,
    protocol: validation.protocol,
    normalizedJson: validation.normalizedJson
  };
}

export function buildXrayConfig(outboundJson: string, socksPort: number = DEFAULT_SOCKS_PORT): GeneratedXrayConfig {
  const validation = validateOutboundJson(outboundJson);
  if (!validation.valid) {
    throw new Error(validation.message);
  }

  const outbound = parseOutbound(validation.normalizedJson);
  if (outbound.tag === undefined || outbound.tag.length === 0) {
    outbound.tag = 'proxy';
  }

  const socksInbound: XrayInboundConfig = {
    tag: 'socks-in',
    listen: DEFAULT_SOCKS_HOST,
    port: socksPort,
    protocol: 'socks',
    settings: new SocksInboundSettings()
  };
  const directOutbound: XrayOutbound = {
    tag: 'direct',
    protocol: 'freedom',
    settings: new EmptySettings()
  };
  const blockOutbound: XrayOutbound = {
    tag: 'block',
    protocol: 'blackhole',
    settings: new EmptySettings()
  };

  const config: XrayFullConfig = {
    log: {
      loglevel: 'warning'
    },
    inbounds: [socksInbound],
    outbounds: [outbound, directOutbound, blockOutbound],
    routing: {
      domainStrategy: 'AsIs',
      rules: new Array<Object>()
    }
  };

  return {
    configJson: JSON.stringify(config, null, 2),
    socksHost: DEFAULT_SOCKS_HOST,
    socksPort
  };
}
