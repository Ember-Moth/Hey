import { decodeBase64ToUtf8 } from './Encoding';

export interface ShareLinkParseResult {
  success: boolean;
  message: string;
  protocol: string;
  name: string;
  outboundJson: string;
}

interface HostPort {
  host: string;
  port: number;
}

interface ParsedShareUrl {
  userInfo: string;
  host: string;
  port: number;
  query: Map<string, string>;
  fragment: string;
}

interface XrayTlsSettings {
  allowInsecure?: boolean;
  serverName?: string;
  alpn?: Array<string>;
  fingerprint?: string;
  publicKey?: string;
  shortId?: string;
  spiderX?: string;
  show?: boolean;
}

interface XrayTcpRequestHeaders {
  Host: Array<string>;
}

interface XrayTcpRequest {
  path: Array<string>;
  headers: XrayTcpRequestHeaders;
}

interface XrayTcpHeader {
  type: string;
  request?: XrayTcpRequest;
}

interface XrayTcpSettings {
  header: XrayTcpHeader;
}

interface XrayWsHeaders {
  Host: string;
}

interface XrayWsSettings {
  path: string;
  headers: XrayWsHeaders;
}

interface XrayHttpUpgradeSettings {
  path: string;
  host: string;
}

interface XrayXhttpSettings {
  path: string;
  host: string;
  mode?: string;
  extra?: Object;
}

interface XrayHttpSettings {
  host: Array<string>;
  path: string;
}

interface XrayGrpcSettings {
  serviceName: string;
  authority?: string;
  multiMode?: boolean;
  idle_timeout?: number;
  health_check_timeout?: number;
}

interface XrayStreamSettings {
  network: string;
  security?: string;
  tcpSettings?: XrayTcpSettings;
  wsSettings?: XrayWsSettings;
  httpupgradeSettings?: XrayHttpUpgradeSettings;
  xhttpSettings?: XrayXhttpSettings;
  httpSettings?: XrayHttpSettings;
  grpcSettings?: XrayGrpcSettings;
  tlsSettings?: XrayTlsSettings;
  realitySettings?: XrayTlsSettings;
}

interface XrayVlessUser {
  id: string;
  encryption: string;
  flow?: string;
}

interface XrayVlessServer {
  address: string;
  port: number;
  users: Array<XrayVlessUser>;
}

interface XrayVlessSettings {
  vnext: Array<XrayVlessServer>;
}

interface XrayVmessUser {
  id: string;
  alterId: number;
  security: string;
}

interface XrayVmessServer {
  address: string;
  port: number;
  users: Array<XrayVmessUser>;
}

interface XrayVmessSettings {
  vnext: Array<XrayVmessServer>;
}

interface XrayTrojanServer {
  address: string;
  port: number;
  password: string;
  flow?: string;
}

interface XrayTrojanSettings {
  servers: Array<XrayTrojanServer>;
}

interface XrayShadowsocksServer {
  address: string;
  port: number;
  method: string;
  password: string;
}

interface XrayShadowsocksSettings {
  servers: Array<XrayShadowsocksServer>;
}

interface XrayGenericUser {
  user: string;
  pass: string;
}

interface XrayGenericServer {
  address: string;
  port: number;
  users?: Array<XrayGenericUser>;
}

interface XrayServerSettings {
  servers: Array<XrayGenericServer>;
}

interface XrayWireguardPeer {
  publicKey: string;
  endpoint: string;
  preSharedKey?: string;
}

interface XrayWireguardSettings {
  secretKey: string;
  address: Array<string>;
  peers: Array<XrayWireguardPeer>;
  mtu?: number;
  reserved?: Array<number>;
}

interface XrayHysteria2Server {
  address: string;
  port: number;
  password: string;
  sni?: string;
  alpn?: string;
  insecure?: boolean;
  obfsPassword?: string;
  portHopping?: string;
  pinSHA256?: string;
}

interface XrayHysteria2Settings {
  servers: Array<XrayHysteria2Server>;
}

interface XrayOutbound {
  protocol: string;
  tag: string;
  settings: XrayVlessSettings | XrayVmessSettings | XrayTrojanSettings | XrayShadowsocksSettings | XrayServerSettings | XrayWireguardSettings | XrayHysteria2Settings;
  streamSettings?: XrayStreamSettings;
}

interface VmessQrCode {
  ps?: string;
  add?: string;
  port?: string;
  id?: string;
  scy?: string;
  net?: string;
  type?: string;
  host?: string;
  path?: string;
  tls?: string;
  sni?: string;
  fp?: string;
  alpn?: string;
}

function makeFailure(message: string, protocol: string = ''): ShareLinkParseResult {
  return {
    success: false,
    message,
    protocol,
    name: '',
    outboundJson: ''
  };
}

function makeSuccess(protocol: string, name: string, outbound: XrayOutbound): ShareLinkParseResult {
  return {
    success: true,
    message: `${protocol.toUpperCase()} 分享链接导入成功。`,
    protocol,
    name,
    outboundJson: JSON.stringify(outbound, null, 2)
  };
}

export function isSupportedShareLink(input: string): boolean {
  const lower = input.trim().toLowerCase();
  return lower.startsWith('vless://') ||
    lower.startsWith('vmess://') ||
    lower.startsWith('trojan://') ||
    lower.startsWith('ss://') ||
    lower.startsWith('socks://') ||
    lower.startsWith('http://') ||
    lower.startsWith('https://') ||
    lower.startsWith('wireguard://') ||
    lower.startsWith('hysteria2://') ||
    lower.startsWith('hy2://');
}

export function parseShareLinkToOutboundJson(input: string): ShareLinkParseResult {
  const trimmed = input.trim();
  const lower = trimmed.toLowerCase();

  try {
    if (lower.startsWith('vless://')) {
      return parseVlessLink(trimmed);
    }
    if (lower.startsWith('vmess://')) {
      return parseVmessLink(trimmed);
    }
    if (lower.startsWith('trojan://')) {
      return parseTrojanLink(trimmed);
    }
    if (lower.startsWith('ss://')) {
      return parseShadowsocksLink(trimmed);
    }
    if (lower.startsWith('socks://')) {
      return parseSocksLink(trimmed);
    }
    if (lower.startsWith('http://')) {
      return parseHttpProxyLink(trimmed, 'http');
    }
    if (lower.startsWith('https://')) {
      return parseHttpProxyLink(trimmed, 'https');
    }
    if (lower.startsWith('wireguard://')) {
      return parseWireguardLink(trimmed);
    }
    if (lower.startsWith('hysteria2://') || lower.startsWith('hy2://')) {
      return parseHysteria2Link(trimmed);
    }
    return makeFailure('暂只支持 vless://、vmess://、trojan://、ss://、socks://、http://、wireguard:// 和 hysteria2:// 分享链接。');
  } catch (error) {
    return makeFailure(`分享链接解析失败：${stringifyError(error)}`);
  }
}

function parseVlessLink(input: string): ShareLinkParseResult {
  const parsed = parseUrlStyleShareLink(input, 'vless');
  if (parsed.userInfo.length === 0) {
    return makeFailure('VLESS 链接缺少用户 ID。', 'vless');
  }

  const user: XrayVlessUser = {
    id: parsed.userInfo,
    encryption: queryValue(parsed.query, 'encryption', 'none')
  };
  const flow = queryValue(parsed.query, 'flow', '');
  if (flow.length > 0) {
    user.flow = flow;
  }

  const settings: XrayVlessSettings = {
    vnext: [{
      address: parsed.host,
      port: parsed.port,
      users: [user]
    }]
  };

  const outbound: XrayOutbound = {
    protocol: 'vless',
    tag: 'proxy',
    settings,
    streamSettings: buildStreamSettings(parsed.query, '')
  };
  return makeSuccess('vless', parsed.fragment, outbound);
}

function parseVmessLink(input: string): ShareLinkParseResult {
  const body = input.substring('vmess://'.length);
  if (body.indexOf('?') > 0 && body.indexOf('&') > 0) {
    return parseVmessAeadLink(input);
  }

  const decoded = decodeBase64ToUtf8(body);
  const vmess = JSON.parse(decoded) as VmessQrCode;
  if (empty(vmess.add) || empty(vmess.port) || empty(vmess.id)) {
    return makeFailure('VMess 链接缺少服务器、端口或用户 ID。', 'vmess');
  }

  const query = new Map<string, string>();
  query.set('type', valueOr(vmess.net, 'tcp'));
  query.set('headerType', valueOr(vmess.type, 'none'));
  query.set('host', valueOr(vmess.host, ''));
  query.set('path', valueOr(vmess.path, ''));
  query.set('security', valueOr(vmess.tls, ''));
  query.set('sni', valueOr(vmess.sni, ''));
  query.set('fp', valueOr(vmess.fp, ''));
  query.set('alpn', valueOr(vmess.alpn, ''));
  if (valueOr(vmess.net, '') === 'grpc') {
    query.set('mode', valueOr(vmess.type, ''));
    query.set('serviceName', valueOr(vmess.path, ''));
    query.set('authority', valueOr(vmess.host, ''));
  }

  const settings: XrayVmessSettings = {
    vnext: [{
      address: valueOr(vmess.add, ''),
      port: parsePort(valueOr(vmess.port, '0')),
      users: [{
        id: valueOr(vmess.id, ''),
        alterId: 0,
        security: valueOr(vmess.scy, 'auto')
      }]
    }]
  };
  const outbound: XrayOutbound = {
    protocol: 'vmess',
    tag: 'proxy',
    settings,
    streamSettings: buildStreamSettings(query, '')
  };
  return makeSuccess('vmess', valueOr(vmess.ps, ''), outbound);
}

function parseVmessAeadLink(input: string): ShareLinkParseResult {
  const parsed = parseUrlStyleShareLink(input, 'vmess');
  if (parsed.userInfo.length === 0) {
    return makeFailure('VMess 链接缺少用户 ID。', 'vmess');
  }
  const settings: XrayVmessSettings = {
    vnext: [{
      address: parsed.host,
      port: parsed.port,
      users: [{
        id: parsed.userInfo,
        alterId: 0,
        security: queryValue(parsed.query, 'encryption', queryValue(parsed.query, 'security', 'auto'))
      }]
    }]
  };
  const outbound: XrayOutbound = {
    protocol: 'vmess',
    tag: 'proxy',
    settings,
    streamSettings: buildStreamSettings(parsed.query, '')
  };
  return makeSuccess('vmess', parsed.fragment, outbound);
}

function parseTrojanLink(input: string): ShareLinkParseResult {
  const parsed = parseUrlStyleShareLink(input, 'trojan');
  if (parsed.userInfo.length === 0) {
    return makeFailure('Trojan 链接缺少密码。', 'trojan');
  }

  const server: XrayTrojanServer = {
    address: parsed.host,
    port: parsed.port,
    password: parsed.userInfo
  };
  const flow = queryValue(parsed.query, 'flow', '');
  if (flow.length > 0) {
    server.flow = flow;
  }

  const settings: XrayTrojanSettings = {
    servers: [server]
  };

  const outbound: XrayOutbound = {
    protocol: 'trojan',
    tag: 'proxy',
    settings,
    streamSettings: buildStreamSettings(parsed.query, 'tls')
  };
  return makeSuccess('trojan', parsed.fragment, outbound);
}

function parseShadowsocksLink(input: string): ShareLinkParseResult {
  return parseShadowsocksSip002(input) ?? parseShadowsocksLegacy(input);
}

function parseShadowsocksSip002(input: string): ShareLinkParseResult | null {
  const parsed = tryParseUrlStyleShareLink(input, 'ss');
  if (parsed === null) {
    return null;
  }

  let methodPassword = parsed.userInfo;
  if (methodPassword.indexOf(':') < 0) {
    methodPassword = decodeBase64ToUtf8(methodPassword);
  }
  const splitIndex = methodPassword.indexOf(':');
  if (splitIndex <= 0) {
    return makeFailure('Shadowsocks 链接缺少加密方法或密码。', 'shadowsocks');
  }

  return makeShadowsocksResult(
    methodPassword.substring(0, splitIndex).toLowerCase(),
    methodPassword.substring(splitIndex + 1),
    parsed.host,
    parsed.port,
    parsed.fragment,
    parsed.query,
    input
  );
}

function parseShadowsocksLegacy(input: string): ShareLinkParseResult {
  let body = input.substring('ss://'.length);
  let fragment = '';
  const fragmentIndex = body.indexOf('#');
  if (fragmentIndex >= 0) {
    fragment = safeDecodeURIComponent(body.substring(fragmentIndex + 1));
    body = body.substring(0, fragmentIndex);
  }
  const decoded = decodeBase64ToUtf8(body);
  const atIndex = decoded.lastIndexOf('@');
  const splitIndex = decoded.indexOf(':');
  const portIndex = decoded.lastIndexOf(':');
  if (splitIndex <= 0 || atIndex <= splitIndex || portIndex <= atIndex) {
    return makeFailure('Shadowsocks legacy 链接格式不正确。', 'shadowsocks');
  }

  return makeShadowsocksResult(
    decoded.substring(0, splitIndex).toLowerCase(),
    decoded.substring(splitIndex + 1, atIndex),
    decoded.substring(atIndex + 1, portIndex).replace('[', '').replace(']', ''),
    parsePort(decoded.substring(portIndex + 1)),
    fragment,
    new Map<string, string>(),
    input
  );
}

function makeShadowsocksResult(method: string, password: string, host: string, port: number, name: string, query: Map<string, string>, input: string): ShareLinkParseResult {
  const streamQuery = new Map<string, string>();
  const plugin = queryValue(query, 'plugin', '');
  if (plugin.indexOf('obfs=http') >= 0) {
    streamQuery.set('type', 'tcp');
    streamQuery.set('headerType', 'http');
    streamQuery.set('host', getPluginValue(plugin, 'obfs-host'));
    streamQuery.set('path', getPluginValue(plugin, 'path'));
  } else {
    streamQuery.set('type', queryValue(query, 'type', 'tcp'));
    streamQuery.set('host', queryValue(query, 'host', ''));
    streamQuery.set('path', queryValue(query, 'path', ''));
    streamQuery.set('security', queryValue(query, 'security', ''));
  }

  const settings: XrayShadowsocksSettings = {
    servers: [{
      address: host,
      port,
      method,
      password
    }]
  };
  const outbound: XrayOutbound = {
    protocol: 'shadowsocks',
    tag: 'proxy',
    settings,
    streamSettings: buildStreamSettings(streamQuery, '')
  };
  return makeSuccess('shadowsocks', name.length > 0 ? name : deriveNameFromRaw(input), outbound);
}

function parseSocksLink(input: string): ShareLinkParseResult {
  const parsed = parseOptionalUserShareLink(input, 'socks');
  const server: XrayGenericServer = {
    address: parsed.host,
    port: parsed.port
  };
  const user = parseGenericUser(parsed.userInfo);
  if (user !== null) {
    server.users = [user];
  }

  const outbound: XrayOutbound = {
    protocol: 'socks',
    tag: 'proxy',
    settings: {
      servers: [server]
    }
  };
  return makeSuccess('socks', parsed.fragment, outbound);
}

function parseHttpProxyLink(input: string, scheme: string): ShareLinkParseResult {
  const parsed = parseOptionalUserShareLink(input, scheme);
  const server: XrayGenericServer = {
    address: parsed.host,
    port: parsed.port
  };
  const user = parseGenericUser(parsed.userInfo);
  if (user !== null) {
    server.users = [user];
  }

  const outbound: XrayOutbound = {
    protocol: 'http',
    tag: 'proxy',
    settings: {
      servers: [server]
    }
  };
  return makeSuccess('http', parsed.fragment, outbound);
}

function parseWireguardLink(input: string): ShareLinkParseResult {
  const parsed = parseOptionalUserShareLink(input, 'wireguard');
  if (parsed.userInfo.length === 0) {
    return makeFailure('WireGuard 链接缺少私钥。', 'wireguard');
  }
  const publicKey = queryValue(parsed.query, 'publickey', queryValue(parsed.query, 'publicKey', ''));
  if (publicKey.length === 0) {
    return makeFailure('WireGuard 链接缺少 publickey。', 'wireguard');
  }

  const peer: XrayWireguardPeer = {
    publicKey,
    endpoint: formatEndpoint(parsed.host, parsed.port)
  };
  const preSharedKey = queryValue(parsed.query, 'presharedkey', queryValue(parsed.query, 'preSharedKey', ''));
  if (preSharedKey.length > 0) {
    peer.preSharedKey = preSharedKey;
  }

  const settings: XrayWireguardSettings = {
    secretKey: parsed.userInfo,
    address: splitCsvWithDefault(queryValue(parsed.query, 'address', ''), '172.16.0.2/32'),
    peers: [peer]
  };
  const mtu = parseOptionalPositiveInt(queryValue(parsed.query, 'mtu', ''));
  if (mtu > 0) {
    settings.mtu = mtu;
  }
  const reserved = parseNumberCsv(queryValue(parsed.query, 'reserved', ''));
  if (reserved.length > 0) {
    settings.reserved = reserved;
  }

  const outbound: XrayOutbound = {
    protocol: 'wireguard',
    tag: 'proxy',
    settings
  };
  return makeSuccess('wireguard', parsed.fragment, outbound);
}

function parseHysteria2Link(input: string): ShareLinkParseResult {
  const scheme = input.toLowerCase().startsWith('hy2://') ? 'hy2' : 'hysteria2';
  const parsed = parseOptionalUserShareLink(input, scheme);
  if (parsed.userInfo.length === 0) {
    return makeFailure('Hysteria2 链接缺少认证密码。', 'hysteria2');
  }

  const server: XrayHysteria2Server = {
    address: parsed.host,
    port: parsed.port,
    password: parsed.userInfo
  };
  const sni = queryValue(parsed.query, 'sni', '');
  if (sni.length > 0) {
    server.sni = sni;
  }
  const alpn = queryValue(parsed.query, 'alpn', '');
  if (alpn.length > 0) {
    server.alpn = alpn;
  }
  const obfsPassword = queryValue(parsed.query, 'obfs-password', '');
  if (obfsPassword.length > 0) {
    server.obfsPassword = obfsPassword;
  }
  const portHopping = queryValue(parsed.query, 'mport', '');
  if (portHopping.length > 0) {
    server.portHopping = portHopping;
  }
  const pinSHA256 = queryValue(parsed.query, 'pinSHA256', '');
  if (pinSHA256.length > 0) {
    server.pinSHA256 = pinSHA256;
  }
  const insecure = queryValue(parsed.query, 'insecure', '');
  if (insecure.length > 0) {
    server.insecure = insecure === '1' || insecure.toLowerCase() === 'true';
  }

  const outbound: XrayOutbound = {
    protocol: 'hysteria2',
    tag: 'proxy',
    settings: {
      servers: [server]
    }
  };
  return makeSuccess('hysteria2', parsed.fragment, outbound);
}

function tryParseUrlStyleShareLink(input: string, scheme: string): ParsedShareUrl | null {
  try {
    return parseUrlStyleShareLink(input, scheme);
  } catch (error) {
    return null;
  }
}

function parseOptionalUserShareLink(input: string, scheme: string): ParsedShareUrl {
  const prefix = `${scheme}://`;
  let body = input.substring(prefix.length);
  let fragment = '';
  const fragmentIndex = body.indexOf('#');
  if (fragmentIndex >= 0) {
    fragment = safeDecodeURIComponent(body.substring(fragmentIndex + 1));
    body = body.substring(0, fragmentIndex);
  }

  let rawQuery = '';
  const queryIndex = body.indexOf('?');
  if (queryIndex >= 0) {
    rawQuery = body.substring(queryIndex + 1);
    body = body.substring(0, queryIndex);
  }

  const atIndex = body.lastIndexOf('@');
  const userInfo = atIndex >= 0 ? safeDecodeURIComponent(body.substring(0, atIndex)) : '';
  const target = atIndex >= 0 ? body.substring(atIndex + 1) : body;
  const hostPort = parseHostPort(target);
  return {
    userInfo,
    host: hostPort.host,
    port: hostPort.port,
    query: parseQuery(rawQuery),
    fragment
  };
}

function parseUrlStyleShareLink(input: string, scheme: string): ParsedShareUrl {
  const prefix = `${scheme}://`;
  let body = input.substring(prefix.length);
  let fragment = '';
  const fragmentIndex = body.indexOf('#');
  if (fragmentIndex >= 0) {
    fragment = safeDecodeURIComponent(body.substring(fragmentIndex + 1));
    body = body.substring(0, fragmentIndex);
  }

  let rawQuery = '';
  const queryIndex = body.indexOf('?');
  if (queryIndex >= 0) {
    rawQuery = body.substring(queryIndex + 1);
    body = body.substring(0, queryIndex);
  }

  const atIndex = body.lastIndexOf('@');
  if (atIndex < 0) {
    throw new Error(`${scheme} 链接缺少用户信息或服务器地址。`);
  }

  const userInfo = safeDecodeURIComponent(body.substring(0, atIndex));
  const hostPort = parseHostPort(body.substring(atIndex + 1));
  return {
    userInfo,
    host: hostPort.host,
    port: hostPort.port,
    query: parseQuery(rawQuery),
    fragment
  };
}

function parseHostPort(value: string): HostPort {
  let target = value;
  const slashIndex = target.indexOf('/');
  if (slashIndex >= 0) {
    target = target.substring(0, slashIndex);
  }

  if (target.startsWith('[')) {
    const endIndex = target.indexOf(']');
    if (endIndex < 0) {
      throw new Error('IPv6 地址缺少右方括号。');
    }
    const portPrefix = target.substring(endIndex + 1, endIndex + 2);
    if (portPrefix !== ':') {
      throw new Error('服务器端口格式不正确。');
    }
    return {
      host: target.substring(1, endIndex),
      port: parsePort(target.substring(endIndex + 2))
    };
  }

  const portIndex = target.lastIndexOf(':');
  if (portIndex <= 0) {
    throw new Error('服务器地址缺少端口。');
  }
  return {
    host: safeDecodeURIComponent(target.substring(0, portIndex)),
    port: parsePort(target.substring(portIndex + 1))
  };
}

function parsePort(rawPort: string): number {
  const port = Number(rawPort);
  if (rawPort.length === 0 || port < 1 || port > 65535 || Math.floor(port) !== port) {
    throw new Error('服务器端口必须是 1-65535 的整数。');
  }
  return port;
}

function parseQuery(rawQuery: string): Map<string, string> {
  const result = new Map<string, string>();
  if (rawQuery.length === 0) {
    return result;
  }

  const pairs = rawQuery.split('&');
  for (let index = 0; index < pairs.length; index++) {
    const pair = pairs[index];
    if (pair.length === 0) {
      continue;
    }
    const equalIndex = pair.indexOf('=');
    const rawKey = equalIndex >= 0 ? pair.substring(0, equalIndex) : pair;
    const rawValue = equalIndex >= 0 ? pair.substring(equalIndex + 1) : '';
    const key = safeDecodeURIComponent(rawKey);
    if (key.length > 0) {
      result.set(key, safeDecodeURIComponent(rawValue));
    }
  }
  return result;
}

function buildStreamSettings(query: Map<string, string>, defaultSecurity: string): XrayStreamSettings {
  let network = queryValue(query, 'type', 'tcp').toLowerCase();
  if (network === 'http') {
    network = 'h2';
  }

  const host = queryValue(query, 'host', '');
  const path = queryValue(query, 'path', '');
  const headerType = queryValue(query, 'headerType', 'none');
  const stream: XrayStreamSettings = {
    network
  };
  let derivedSni = '';

  if (network === 'ws') {
    stream.wsSettings = {
      path: path.length > 0 ? path : '/',
      headers: {
        Host: host
      }
    };
    derivedSni = firstCsvValue(host);
  } else if (network === 'httpupgrade') {
    stream.httpupgradeSettings = {
      path: path.length > 0 ? path : '/',
      host
    };
    derivedSni = firstCsvValue(host);
  } else if (network === 'xhttp') {
    const xhttpSettings: XrayXhttpSettings = {
      path: path.length > 0 ? path : '/',
      host
    };
    const mode = queryValue(query, 'mode', '');
    if (mode.length > 0) {
      xhttpSettings.mode = mode;
    }
    const extra = parseOptionalJsonObject(queryValue(query, 'extra', ''));
    if (extra !== null) {
      xhttpSettings.extra = extra;
    }
    stream.xhttpSettings = xhttpSettings;
    derivedSni = firstCsvValue(host);
  } else if (network === 'h2') {
    stream.httpSettings = {
      host: splitCsv(host),
      path: path.length > 0 ? path : '/'
    };
    derivedSni = firstCsvValue(host);
  } else if (network === 'grpc') {
    const authority = queryValue(query, 'authority', '');
    const grpcSettings: XrayGrpcSettings = {
      serviceName: queryValue(query, 'serviceName', ''),
      multiMode: queryValue(query, 'mode', '') === 'multi',
      idle_timeout: 60,
      health_check_timeout: 20
    };
    if (authority.length > 0) {
      grpcSettings.authority = authority;
    }
    stream.grpcSettings = grpcSettings;
    derivedSni = authority;
  } else {
    stream.network = 'tcp';
    stream.tcpSettings = buildTcpSettings(headerType, host, path);
    derivedSni = headerType === 'http' ? firstCsvValue(host) : host;
  }

  applySecuritySettings(stream, query, defaultSecurity, derivedSni);
  return stream;
}

function buildTcpSettings(headerType: string, host: string, path: string): XrayTcpSettings {
  const header: XrayTcpHeader = {
    type: headerType === 'http' ? 'http' : 'none'
  };
  if (header.type === 'http') {
    header.request = {
      path: splitCsvWithDefault(path, '/'),
      headers: {
        Host: splitCsv(host)
      }
    };
  }
  return {
    header
  };
}

function applySecuritySettings(stream: XrayStreamSettings, query: Map<string, string>, defaultSecurity: string, derivedSni: string): void {
  const security = queryValue(query, 'security', defaultSecurity).toLowerCase();
  if (security !== 'tls' && security !== 'reality') {
    return;
  }

  const tlsSettings = buildTlsSettings(query, security, derivedSni);
  stream.security = security;
  if (security === 'tls') {
    stream.tlsSettings = tlsSettings;
  } else {
    stream.realitySettings = tlsSettings;
  }
}

function buildTlsSettings(query: Map<string, string>, security: string, derivedSni: string): XrayTlsSettings {
  const settings: XrayTlsSettings = {
    allowInsecure: queryValue(query, 'allowInsecure', '') === '1'
  };

  const sni = queryValue(query, 'sni', derivedSni);
  if (sni.length > 0) {
    settings.serverName = sni;
  }
  const fingerprint = queryValue(query, 'fp', '');
  if (fingerprint.length > 0) {
    settings.fingerprint = fingerprint;
  }
  const alpn = splitCsv(queryValue(query, 'alpn', ''));
  if (alpn.length > 0) {
    settings.alpn = alpn;
  }
  const publicKey = queryValue(query, 'pbk', '');
  if (publicKey.length > 0) {
    settings.publicKey = publicKey;
  }
  const shortId = queryValue(query, 'sid', '');
  if (shortId.length > 0) {
    settings.shortId = shortId;
  }
  const spiderX = queryValue(query, 'spx', '');
  if (spiderX.length > 0) {
    settings.spiderX = spiderX;
  }
  if (security === 'reality') {
    settings.show = false;
  }
  return settings;
}

function queryValue(query: Map<string, string>, key: string, fallback: string): string {
  const value = query.get(key);
  if (value === undefined || value.length === 0) {
    return fallback;
  }
  return value;
}

function splitCsv(value: string): Array<string> {
  const result: Array<string> = [];
  if (value.length === 0) {
    return result;
  }

  const values = value.split(',');
  for (let index = 0; index < values.length; index++) {
    const item = values[index].trim();
    if (item.length > 0) {
      result.push(item);
    }
  }
  return result;
}

function splitCsvWithDefault(value: string, fallback: string): Array<string> {
  const values = splitCsv(value);
  if (values.length > 0) {
    return values;
  }
  return [fallback];
}

function firstCsvValue(value: string): string {
  const values = splitCsv(value);
  return values.length > 0 ? values[0] : '';
}

function parseOptionalJsonObject(value: string): Object | null {
  if (value.length === 0) {
    return null;
  }
  try {
    return JSON.parse(value) as Object;
  } catch (error) {
    return null;
  }
}

function getPluginValue(plugin: string, key: string): string {
  const pairs = plugin.split(';');
  const prefix = `${key}=`;
  for (let index = 0; index < pairs.length; index++) {
    const pair = pairs[index];
    if (pair.startsWith(prefix)) {
      return pair.substring(prefix.length);
    }
  }
  return '';
}

function deriveNameFromRaw(input: string): string {
  const fragmentIndex = input.indexOf('#');
  if (fragmentIndex >= 0) {
    return safeDecodeURIComponent(input.substring(fragmentIndex + 1));
  }
  return '';
}

function parseGenericUser(userInfo: string): XrayGenericUser | null {
  if (userInfo.length === 0) {
    return null;
  }
  let value = userInfo;
  if (value.indexOf(':') < 0) {
    try {
      value = decodeBase64ToUtf8(value);
    } catch (error) {
      value = userInfo;
    }
  }
  const splitIndex = value.indexOf(':');
  if (splitIndex < 0) {
    return {
      user: value,
      pass: ''
    };
  }
  return {
    user: value.substring(0, splitIndex),
    pass: value.substring(splitIndex + 1)
  };
}

function formatEndpoint(host: string, port: number): string {
  if (host.indexOf(':') >= 0 && !host.startsWith('[')) {
    return `[${host}]:${port}`;
  }
  return `${host}:${port}`;
}

function parseOptionalPositiveInt(value: string): number {
  if (value.length === 0) {
    return 0;
  }
  const parsed = Number(value);
  if (Number.isNaN(parsed) || parsed <= 0 || Math.floor(parsed) !== parsed) {
    return 0;
  }
  return parsed;
}

function parseNumberCsv(value: string): Array<number> {
  const result: Array<number> = [];
  const parts = splitCsv(value);
  for (let index = 0; index < parts.length; index++) {
    const parsed = Number(parts[index]);
    if (!Number.isNaN(parsed) && Math.floor(parsed) === parsed) {
      result.push(parsed);
    }
  }
  return result;
}

function empty(value: string | undefined): boolean {
  return value === undefined || value.length === 0;
}

function valueOr(value: string | undefined, fallback: string): string {
  if (value === undefined || value.length === 0) {
    return fallback;
  }
  return value;
}

function safeDecodeURIComponent(value: string): string {
  try {
    return decodeURIComponent(value.split('+').join('%20'));
  } catch (error) {
    return value;
  }
}

function stringifyError(error: Error): string {
  if (error.message !== undefined && error.message.length > 0) {
    return error.message;
  }
  return JSON.stringify(error);
}
