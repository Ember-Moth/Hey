#include "napi/native_api.h"

#include <atomic>
#include <cctype>
#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <fcntl.h>
#include <hilog/log.h>
#include <sstream>
#include <string>
#include <unistd.h>
#include <vector>

namespace {

constexpr unsigned int LOG_DOMAIN_ID = 0x0001;
constexpr const char* LOG_TAG_NAME = "HeyNative";
constexpr const char* XRAY_CONFIG_FILE = "hey-xray-config.json";
constexpr const char* XRAY_CORE_LIB = "libxray.so";
constexpr const char* PING_CONFIG_FILE = "hey-ping-config.json";

using CGoPingFunc = char* (*)(char*);
using CGoStringFunc = char* (*)(char*);
using CGoStopFunc = char* (*)();
using Tun2SocksStartFunc = int (*)(int, char*, int, int);
using Tun2SocksStopFunc = void (*)();
using Tun2SocksStatsFunc = int64_t (*)();
using Tun2SocksLastErrorFunc = char* (*)();

std::atomic_bool g_xrayRunning(false);
std::atomic_bool g_tunRunning(false);
std::atomic<int64_t> g_uploadBytes(0);
std::atomic<int64_t> g_downloadBytes(0);
std::string g_lastMessage = "Native bridge ready. Waiting for Xray shared library.";
void* g_xrayHandle = nullptr;
CGoStringFunc g_runXrayFromJson = nullptr;
CGoStopFunc g_stopXray = nullptr;
CGoPingFunc g_pingXray = nullptr;
Tun2SocksStartFunc g_startTun2Socks = nullptr;
Tun2SocksStopFunc g_stopTun2Socks = nullptr;
Tun2SocksStatsFunc g_tun2SocksUploadBytes = nullptr;
Tun2SocksStatsFunc g_tun2SocksDownloadBytes = nullptr;
Tun2SocksLastErrorFunc g_tun2SocksLastError = nullptr;

const char* BASE64_TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

void LogInfo(const std::string& message)
{
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN_ID, LOG_TAG_NAME, "%{public}s", message.c_str());
}

void LogWarn(const std::string& message)
{
    OH_LOG_Print(LOG_APP, LOG_WARN, LOG_DOMAIN_ID, LOG_TAG_NAME, "%{public}s", message.c_str());
}

void LogError(const std::string& message)
{
    OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN_ID, LOG_TAG_NAME, "%{public}s", message.c_str());
}

std::string ErrnoMessage(const std::string& prefix, int errorCode = errno)
{
    return prefix + ": " + std::strerror(errorCode);
}

std::string DirName(const std::string& path)
{
    size_t slash = path.find_last_of('/');
    if (slash == std::string::npos || slash == 0) {
        return ".";
    }
    return path.substr(0, slash);
}

std::string NativeLibDir()
{
    Dl_info info;
    if (dladdr(reinterpret_cast<void*>(&LogInfo), &info) != 0 && info.dli_fname != nullptr) {
        return DirName(info.dli_fname);
    }
    return ".";
}

std::string ExecPath(const std::string& name)
{
    return NativeLibDir() + "/" + name;
}

bool WriteTextFile(const std::string& path, const std::string& content, std::string& message)
{
    FILE* file = std::fopen(path.c_str(), "wb");
    if (file == nullptr) {
        message = ErrnoMessage("Failed to open file for writing: " + path);
        return false;
    }

    size_t written = std::fwrite(content.data(), 1, content.size(), file);
    std::fclose(file);
    if (written != content.size()) {
        message = ErrnoMessage("Failed to write complete file: " + path);
        return false;
    }
    return true;
}

bool MakeFdInheritable(int fd, std::string& message)
{
    int flags = fcntl(fd, F_GETFD);
    if (flags < 0) {
        message = ErrnoMessage("fcntl(F_GETFD) failed for TUN fd");
        return false;
    }
    if (fcntl(fd, F_SETFD, flags & ~FD_CLOEXEC) < 0) {
        message = ErrnoMessage("fcntl(F_SETFD) failed for TUN fd");
        return false;
    }
    return true;
}

std::string GetStringArg(napi_env env, napi_value value)
{
    size_t length = 0;
    napi_get_value_string_utf8(env, value, nullptr, 0, &length);
    std::string result(length + 1, '\0');
    napi_get_value_string_utf8(env, value, &result[0], result.size(), &length);
    result.resize(length);
    return result;
}

int32_t GetIntArg(napi_env env, napi_value value)
{
    int32_t result = 0;
    napi_get_value_int32(env, value, &result);
    return result;
}

napi_value CreateString(napi_env env, const std::string& value)
{
    napi_value result = nullptr;
    napi_create_string_utf8(env, value.c_str(), value.length(), &result);
    return result;
}

napi_value CreateBool(napi_env env, bool value)
{
    napi_value result = nullptr;
    napi_get_boolean(env, value, &result);
    return result;
}

napi_value CreateInt64(napi_env env, int64_t value)
{
    napi_value result = nullptr;
    napi_create_int64(env, value, &result);
    return result;
}

napi_value CreateResult(napi_env env, bool ok, const std::string& message)
{
    napi_value result = nullptr;
    napi_create_object(env, &result);
    napi_set_named_property(env, result, "ok", CreateBool(env, ok));
    napi_set_named_property(env, result, "message", CreateString(env, message));
    g_lastMessage = message;
    if (ok) {
        LogInfo(message);
    } else {
        LogError(message);
    }
    return result;
}

std::string Base64Encode(const std::string& input)
{
    std::string output;
    int value = 0;
    int bits = -6;
    for (uint8_t ch : input) {
        value = (value << 8) + ch;
        bits += 8;
        while (bits >= 0) {
            output.push_back(BASE64_TABLE[(value >> bits) & 0x3F]);
            bits -= 6;
        }
    }
    if (bits > -6) {
        output.push_back(BASE64_TABLE[((value << 8) >> (bits + 8)) & 0x3F]);
    }
    while (output.size() % 4 != 0) {
        output.push_back('=');
    }
    return output;
}

std::string Base64Decode(const std::string& input)
{
    std::string output;
    std::vector<int> values(256, -1);
    for (int index = 0; index < 64; index++) {
        values[static_cast<uint8_t>(BASE64_TABLE[index])] = index;
    }

    int value = 0;
    int bits = -8;
    for (char ch : input) {
        if (ch == '=') {
            break;
        }
        int decoded = values[static_cast<uint8_t>(ch)];
        if (decoded < 0) {
            continue;
        }
        value = (value << 6) + decoded;
        bits += 6;
        if (bits >= 0) {
            output.push_back(static_cast<char>((value >> bits) & 0xFF));
            bits -= 8;
        }
    }
    return output;
}

std::string JsonEscape(const std::string& input)
{
    std::ostringstream output;
    for (char ch : input) {
        switch (ch) {
            case '\\':
                output << "\\\\";
                break;
            case '"':
                output << "\\\"";
                break;
            case '\n':
                output << "\\n";
                break;
            case '\r':
                output << "\\r";
                break;
            case '\t':
                output << "\\t";
                break;
            default:
                output << ch;
                break;
        }
    }
    return output.str();
}

bool ResponseOk(const std::string& base64Response, std::string& message)
{
    std::string decoded = Base64Decode(base64Response);
    if (decoded.empty()) {
        message = "Empty libXray response.";
        return false;
    }
    if (decoded.find("\"success\":true") != std::string::npos) {
        message = "libXray response: " + decoded;
        return true;
    }

    size_t errorKey = decoded.find("\"error\":\"");
    if (errorKey != std::string::npos) {
        size_t start = errorKey + 9;
        size_t end = decoded.find('"', start);
        message = decoded.substr(start, end == std::string::npos ? std::string::npos : end - start);
    } else {
        message = decoded;
    }
    return false;
}

bool LoadXrayCore(std::string& message);
bool LoadTun2SocksCore(std::string& message);

bool LoadXray()
{
    std::string message;
    bool ok = LoadXrayCore(message);
    if (!ok) {
        g_lastMessage = message;
        LogError(message);
    }
    return ok;
}

bool LoadTun2Socks()
{
    std::string message;
    bool ok = LoadTun2SocksCore(message);
    if (!ok) {
        g_lastMessage = message;
        LogError(message);
    }
    return ok;
}

bool LoadXrayCore(std::string& message)
{
    if (g_xrayHandle != nullptr && g_runXrayFromJson != nullptr && g_stopXray != nullptr && g_pingXray != nullptr) {
        return true;
    }

    void* handle = dlopen(ExecPath(XRAY_CORE_LIB).c_str(), RTLD_LAZY | RTLD_LOCAL);
    if (handle == nullptr) {
        handle = dlopen(XRAY_CORE_LIB, RTLD_LAZY | RTLD_LOCAL);
    }
    if (handle == nullptr) {
        const char* error = dlerror();
        message = std::string("libXray unavailable: failed to load ") + XRAY_CORE_LIB + ": " +
            (error != nullptr ? error : "unknown error");
        return false;
    }

    dlerror();
    g_runXrayFromJson = reinterpret_cast<CGoStringFunc>(dlsym(handle, "CGoRunXrayFromJSON"));
    g_stopXray = reinterpret_cast<CGoStopFunc>(dlsym(handle, "CGoStopXray"));
    g_pingXray = reinterpret_cast<CGoPingFunc>(dlsym(handle, "CGoPing"));
    if (g_runXrayFromJson == nullptr || g_stopXray == nullptr || g_pingXray == nullptr) {
        message = "libXray unavailable: required CGo symbols missing.";
        return false;
    }
    g_xrayHandle = handle;
    return true;
}

CGoPingFunc LoadCGoPing(std::string& message)
{
    if (!LoadXrayCore(message)) {
        message = "libXray ping unavailable: " + message;
        return nullptr;
    }
    return g_pingXray;
}

bool LoadTun2SocksCore(std::string& message)
{
    if (g_startTun2Socks != nullptr && g_stopTun2Socks != nullptr) {
        return true;
    }

    if (!LoadXrayCore(message)) {
        message = "tun2socks unavailable: " + message;
        return false;
    }

    dlerror();
    g_startTun2Socks = reinterpret_cast<Tun2SocksStartFunc>(dlsym(g_xrayHandle, "HeyTun2SocksStart"));
    g_stopTun2Socks = reinterpret_cast<Tun2SocksStopFunc>(dlsym(g_xrayHandle, "HeyTun2SocksStop"));
    g_tun2SocksUploadBytes = reinterpret_cast<Tun2SocksStatsFunc>(dlsym(g_xrayHandle, "HeyTun2SocksUploadBytes"));
    g_tun2SocksDownloadBytes = reinterpret_cast<Tun2SocksStatsFunc>(dlsym(g_xrayHandle, "HeyTun2SocksDownloadBytes"));
    g_tun2SocksLastError = reinterpret_cast<Tun2SocksLastErrorFunc>(dlsym(g_xrayHandle, "HeyTun2SocksLastError"));
    if (g_startTun2Socks == nullptr || g_stopTun2Socks == nullptr) {
        message = "tun2socks unavailable: combined libxray.so symbols missing.";
        return false;
    }
    return true;
}

bool ParsePingResponse(const std::string& json, int64_t& delay, std::string& message)
{
    delay = -1;
    bool success = json.find("\"success\":true") != std::string::npos;

    size_t dataKey = json.find("\"data\":");
    if (dataKey != std::string::npos) {
        size_t start = dataKey + 7;
        while (start < json.size() && (json[start] == ' ' || json[start] == '"')) {
            start++;
        }
        size_t end = start;
        while (end < json.size() && (std::isdigit(static_cast<unsigned char>(json[end])) != 0 || json[end] == '-')) {
            end++;
        }
        if (end > start) {
            delay = std::strtoll(json.substr(start, end - start).c_str(), nullptr, 10);
        }
    }

    if (success && delay >= 0) {
        message = "libXray ping ok.";
        return true;
    }

    size_t errorKey = json.find("\"err\":\"");
    if (errorKey != std::string::npos) {
        size_t start = errorKey + 7;
        size_t end = json.find('"', start);
        std::string error = json.substr(start, end == std::string::npos ? std::string::npos : end - start);
        message = error.empty() ? "libXray ping failed." : error;
    } else {
        message = success ? "libXray ping returned no delay." : "libXray ping failed.";
    }
    return false;
}

napi_value CreatePingResult(napi_env env, bool ok, int64_t delayMs, const std::string& message)
{
    napi_value result = nullptr;
    napi_create_object(env, &result);
    napi_set_named_property(env, result, "ok", CreateBool(env, ok));
    napi_set_named_property(env, result, "delayMs", CreateInt64(env, delayMs));
    napi_set_named_property(env, result, "message", CreateString(env, message));
    if (ok) {
        LogInfo(message);
    } else {
        LogWarn(message);
    }
    return result;
}

napi_value PingOutbound(napi_env env, napi_callback_info info)
{
    size_t argc = 5;
    napi_value args[5] = { nullptr };
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 4) {
        return CreatePingResult(env, false, -1, "Missing ping arguments.");
    }

    std::string config = GetStringArg(env, args[0]);
    std::string datDir = GetStringArg(env, args[1]);
    std::string url = GetStringArg(env, args[2]);
    int32_t timeoutSeconds = GetIntArg(env, args[3]);
    std::string proxy = argc >= 5 ? GetStringArg(env, args[4]) : "socks5://127.0.0.1:10825";

    if (config.empty()) {
        return CreatePingResult(env, false, -1, "Ping config JSON is empty.");
    }
    if (datDir.empty()) {
        return CreatePingResult(env, false, -1, "Ping requires a data directory.");
    }
    if (url.empty()) {
        return CreatePingResult(env, false, -1, "Ping requires a test URL.");
    }
    if (timeoutSeconds <= 0) {
        timeoutSeconds = 10;
    }

    std::string message;
    CGoPingFunc ping = LoadCGoPing(message);
    if (ping == nullptr) {
        return CreatePingResult(env, false, -1, message);
    }

    std::string configPath = datDir + "/" + PING_CONFIG_FILE;
    if (!WriteTextFile(configPath, config, message)) {
        return CreatePingResult(env, false, -1, message);
    }

    std::ostringstream request;
    request << "{\"datDir\":\"" << JsonEscape(datDir) << "\","
            << "\"configPath\":\"" << JsonEscape(configPath) << "\","
            << "\"timeout\":" << timeoutSeconds << ","
            << "\"url\":\"" << JsonEscape(url) << "\","
            << "\"proxy\":\"" << JsonEscape(proxy) << "\"}";

    std::string encoded = Base64Encode(request.str());
    std::vector<char> buffer(encoded.begin(), encoded.end());
    buffer.push_back('\0');

    char* raw = ping(buffer.data());
    if (raw == nullptr) {
        return CreatePingResult(env, false, -1, "libXray ping returned null.");
    }

    std::string response(raw);
    std::string decoded = Base64Decode(response);
    if (decoded.find('{') == std::string::npos) {
        decoded = response;
    }

    int64_t delay = -1;
    bool ok = ParsePingResponse(decoded, delay, message);
    return CreatePingResult(env, ok, delay, message);
}

napi_value ValidateConfig(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1] = { nullptr };
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 1) {
        return CreateResult(env, false, "Missing Xray config JSON.");
    }

    std::string config = GetStringArg(env, args[0]);
    if (config.empty()) {
        return CreateResult(env, false, "Xray config JSON is empty.");
    }
    if (config.find("\"inbounds\"") == std::string::npos || config.find("\"outbounds\"") == std::string::npos) {
        return CreateResult(env, false, "Generated Xray config must contain inbounds and outbounds.");
    }
    if (LoadXray()) {
        return CreateResult(env, true, "Native config preflight passed. libXray is available.");
    }
    return CreateResult(env, false, g_lastMessage);
}

napi_value StartXray(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2] = { nullptr, nullptr };
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 1) {
        return CreateResult(env, false, "Missing Xray config JSON.");
    }

    std::string config = GetStringArg(env, args[0]);
    if (config.empty()) {
        return CreateResult(env, false, "Xray config JSON is empty.");
    }
    if (g_xrayRunning.load()) {
        return CreateResult(env, true, "Xray already running.");
    }

    if (!LoadXray()) {
        g_xrayRunning.store(false);
        return CreateResult(env, false, g_lastMessage);
    }

    std::string workDir = argc >= 2 ? GetStringArg(env, args[1]) : "";
    if (workDir.empty()) {
        return CreateResult(env, false, "Missing native work directory for Xray config.");
    }

    std::string message;
    if (!LoadXrayCore(message)) {
        g_xrayRunning.store(false);
        return CreateResult(env, false, message);
    }

    std::ostringstream request;
    request << "{\"datDir\":\"" << JsonEscape(workDir) << "\","
            << "\"configJSON\":\"" << JsonEscape(config) << "\"}";
    std::string encoded = Base64Encode(request.str());
    std::vector<char> buffer(encoded.begin(), encoded.end());
    buffer.push_back('\0');

    char* raw = g_runXrayFromJson(buffer.data());
    if (raw == nullptr) {
        g_xrayRunning.store(false);
        return CreateResult(env, false, "libXray run returned null.");
    }

    std::string response(raw);
    std::free(raw);
    if (!ResponseOk(response, message)) {
        g_xrayRunning.store(false);
        return CreateResult(env, false, message);
    }

    g_xrayRunning.store(true);
    return CreateResult(env, true, "Xray core started.");
}

napi_value StopXray(napi_env env, napi_callback_info info)
{
    (void)info;
    if (!g_xrayRunning.load()) {
        return CreateResult(env, true, "Xray already stopped.");
    }

    std::string message;
    if (!LoadXrayCore(message)) {
        return CreateResult(env, false, message);
    }

    char* raw = g_stopXray();
    if (raw == nullptr) {
        return CreateResult(env, false, "libXray stop returned null.");
    }
    std::string response(raw);
    std::free(raw);
    if (!ResponseOk(response, message)) {
        return CreateResult(env, false, message);
    }

    g_xrayRunning.store(false);
    return CreateResult(env, true, "Xray core stopped.");
}

napi_value StartTun2Socks(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value args[4] = { nullptr };
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 4) {
        return CreateResult(env, false, "Missing tun2socks arguments.");
    }

    int32_t tunFd = GetIntArg(env, args[0]);
    std::string host = GetStringArg(env, args[1]);
    int32_t port = GetIntArg(env, args[2]);
    int32_t mtu = GetIntArg(env, args[3]);

    if (tunFd < 0) {
        return CreateResult(env, false, "Invalid TUN fd.");
    }
    if (host.empty() || port <= 0 || port > 65535 || mtu < 576 || mtu > 1500) {
        return CreateResult(env, false, "Invalid tun2socks host, port, or MTU.");
    }
    if (g_tunRunning.load()) {
        return CreateResult(env, true, "tun2socks already running.");
    }

    g_uploadBytes.store(0);
    g_downloadBytes.store(0);
    if (!LoadTun2Socks()) {
        g_tunRunning.store(false);
        return CreateResult(env, false, g_lastMessage);
    }

    std::string message;
    if (!MakeFdInheritable(tunFd, message)) {
        g_tunRunning.store(false);
        return CreateResult(env, false, message);
    }

    int result = g_startTun2Socks(tunFd, const_cast<char*>(host.c_str()), port, mtu);
    if (result != 0) {
        g_tunRunning.store(false);
        std::string detail;
        if (g_tun2SocksLastError != nullptr) {
            char* raw = g_tun2SocksLastError();
            if (raw != nullptr) {
                detail = raw;
                std::free(raw);
            }
        }
        if (detail.empty()) {
            detail = "unknown error";
        }
        return CreateResult(env, false, "tun2socks adapter start failed: " + detail);
    }

    g_tunRunning.store(true);
    return CreateResult(env, true, "tun2socks adapter started.");
}

napi_value StopTun2Socks(napi_env env, napi_callback_info info)
{
    (void)info;
    if (!g_tunRunning.load()) {
        return CreateResult(env, true, "tun2socks already stopped.");
    }
    std::string message;
    if (!LoadTun2SocksCore(message)) {
        return CreateResult(env, false, message);
    }
    g_stopTun2Socks();
    g_tunRunning.store(false);
    return CreateResult(env, true, "tun2socks stopped.");
}

napi_value GetStats(napi_env env, napi_callback_info info)
{
    (void)info;
    if (g_tunRunning.load()) {
        if (g_tun2SocksUploadBytes != nullptr) {
            g_uploadBytes.store(g_tun2SocksUploadBytes());
        }
        if (g_tun2SocksDownloadBytes != nullptr) {
            g_downloadBytes.store(g_tun2SocksDownloadBytes());
        }
    }

    napi_value result = nullptr;
    napi_create_object(env, &result);
    napi_set_named_property(env, result, "uploadBytes", CreateInt64(env, g_uploadBytes.load()));
    napi_set_named_property(env, result, "downloadBytes", CreateInt64(env, g_downloadBytes.load()));
    napi_set_named_property(env, result, "xrayRunning", CreateBool(env, g_xrayRunning.load()));
    napi_set_named_property(env, result, "tun2SocksRunning", CreateBool(env, g_tunRunning.load()));
    napi_set_named_property(env, result, "lastMessage", CreateString(env, g_lastMessage));
    return result;
}

} // namespace

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        { "validateConfig", nullptr, ValidateConfig, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "startXray", nullptr, StartXray, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "stopXray", nullptr, StopXray, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "startTun2Socks", nullptr, StartTun2Socks, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "stopTun2Socks", nullptr, StopTun2Socks, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getStats", nullptr, GetStats, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "pingOutbound", nullptr, PingOutbound, nullptr, nullptr, nullptr, napi_default, nullptr },
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module heyVpnModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "heyvpn",
    .nm_priv = nullptr,
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterHeyVpnModule(void)
{
    napi_module_register(&heyVpnModule);
}
