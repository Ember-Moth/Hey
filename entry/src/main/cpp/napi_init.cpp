#include "napi/native_api.h"

#include <atomic>
#include <cerrno>
#include <csignal>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <fcntl.h>
#include <hilog/log.h>
#include <spawn.h>
#include <sstream>
#include <string>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

extern "C" char** environ;

namespace {

constexpr unsigned int LOG_DOMAIN_ID = 0x0001;
constexpr const char* LOG_TAG_NAME = "HeyNative";
constexpr const char* XRAY_EXEC_NAME = "libheyxrayexec.so";
constexpr const char* TUN2SOCKS_EXEC_NAME = "libheytun2socksexec.so";
constexpr const char* XRAY_CONFIG_FILE = "hey-xray-config.json";

std::atomic_bool g_xrayRunning(false);
std::atomic_bool g_tunRunning(false);
std::atomic<int> g_xrayPid(-1);
std::atomic<int> g_tunPid(-1);
std::atomic<int64_t> g_uploadBytes(0);
std::atomic<int64_t> g_downloadBytes(0);
std::string g_lastMessage = "Native bridge ready. Waiting for executable Xray and tun2socks.";

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

bool EnsureExecutable(const std::string& path, std::string& message)
{
    chmod(path.c_str(), 0755);
    if (access(path.c_str(), X_OK) == 0) {
        return true;
    }
    message = ErrnoMessage("Executable is not accessible: " + path);
    return false;
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

bool SpawnProcess(const std::vector<std::string>& args, int& pid, std::string& message)
{
    if (args.empty()) {
        message = "Missing executable path.";
        return false;
    }

    std::vector<char*> argv;
    argv.reserve(args.size() + 1);
    for (const std::string& arg : args) {
        argv.push_back(const_cast<char*>(arg.c_str()));
    }
    argv.push_back(nullptr);

    pid_t childPid = -1;
    int result = posix_spawn(&childPid, args[0].c_str(), nullptr, nullptr, argv.data(), environ);
    if (result != 0) {
        message = ErrnoMessage("posix_spawn failed for " + args[0], result);
        return false;
    }

    pid = static_cast<int>(childPid);
    return true;
}

bool ChildSurvivedStartup(int pid, const std::string& name, std::string& message)
{
    usleep(250 * 1000);
    int status = 0;
    pid_t result = waitpid(static_cast<pid_t>(pid), &status, WNOHANG);
    if (result == 0) {
        return true;
    }
    if (result == static_cast<pid_t>(pid)) {
        std::ostringstream output;
        output << name << " exited during startup, status=" << status;
        message = output.str();
        return false;
    }
    message = ErrnoMessage("waitpid failed for " + name);
    return false;
}

void StopChild(std::atomic<int>& pidStore)
{
    int pid = pidStore.exchange(-1);
    if (pid <= 0) {
        return;
    }

    kill(static_cast<pid_t>(pid), SIGTERM);
    for (int index = 0; index < 20; index++) {
        int status = 0;
        pid_t result = waitpid(static_cast<pid_t>(pid), &status, WNOHANG);
        if (result == static_cast<pid_t>(pid) || (result < 0 && errno == ECHILD)) {
            return;
        }
        usleep(100 * 1000);
    }
    kill(static_cast<pid_t>(pid), SIGKILL);
    waitpid(static_cast<pid_t>(pid), nullptr, 0);
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

bool LoadXray()
{
    std::string message;
    bool ok = EnsureExecutable(ExecPath(XRAY_EXEC_NAME), message);
    if (!ok) {
        g_lastMessage = message;
        LogError(message);
    }
    return ok;
}

bool LoadTun2Socks()
{
    std::string message;
    bool ok = EnsureExecutable(ExecPath(TUN2SOCKS_EXEC_NAME), message);
    if (!ok) {
        g_lastMessage = message;
        LogError(message);
    }
    return ok;
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
    std::string configPath = workDir + "/" + XRAY_CONFIG_FILE;
    if (!WriteTextFile(configPath, config, message)) {
        g_xrayRunning.store(false);
        return CreateResult(env, false, message);
    }

    int pid = -1;
    std::vector<std::string> argsList = {
        ExecPath(XRAY_EXEC_NAME),
        "run",
        "-config",
        configPath,
    };
    if (!SpawnProcess(argsList, pid, message)) {
        g_xrayRunning.store(false);
        return CreateResult(env, false, message);
    }
    if (!ChildSurvivedStartup(pid, "Xray", message)) {
        g_xrayRunning.store(false);
        g_xrayPid.store(-1);
        return CreateResult(env, false, message);
    }
    g_xrayPid.store(pid);
    g_xrayRunning.store(true);
    return CreateResult(env, true, "Xray executable started.");
}

napi_value StopXray(napi_env env, napi_callback_info info)
{
    (void)info;
    if (!g_xrayRunning.load()) {
        return CreateResult(env, true, "Xray already stopped.");
    }

    StopChild(g_xrayPid);
    g_xrayRunning.store(false);
    return CreateResult(env, true, "Xray stopped.");
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

    int pid = -1;
    std::vector<std::string> argsList = {
        ExecPath(TUN2SOCKS_EXEC_NAME),
        "-tun-fd",
        std::to_string(tunFd),
        "-socks-host",
        host,
        "-socks-port",
        std::to_string(port),
        "-mtu",
        std::to_string(mtu),
    };
    if (!SpawnProcess(argsList, pid, message)) {
        g_tunRunning.store(false);
        return CreateResult(env, false, message);
    }
    if (!ChildSurvivedStartup(pid, "tun2socks", message)) {
        g_tunRunning.store(false);
        g_tunPid.store(-1);
        return CreateResult(env, false, message);
    }
    g_tunPid.store(pid);
    g_tunRunning.store(true);
    return CreateResult(env, true, "tun2socks executable started.");
}

napi_value StopTun2Socks(napi_env env, napi_callback_info info)
{
    (void)info;
    if (!g_tunRunning.load()) {
        return CreateResult(env, true, "tun2socks already stopped.");
    }
    StopChild(g_tunPid);
    g_tunRunning.store(false);
    return CreateResult(env, true, "tun2socks stopped.");
}

napi_value GetStats(napi_env env, napi_callback_info info)
{
    (void)info;
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
