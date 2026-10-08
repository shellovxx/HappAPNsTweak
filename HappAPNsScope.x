#include "apns_endpoint.h"

typedef void *Object;
typedef unsigned int UInt;
typedef unsigned long TypeID;
typedef long Index;
typedef unsigned char Boolean;
extern void *dlopen(const char *, int);
extern void *dlsym(void *, const char *);
extern const char *getprogname(void);
extern int strcmp(const char *, const char *);
extern unsigned if_nametoindex(const char *);

static unsigned short (*endpointPort)(Object);
static const char *(*endpointHost)(Object);
static Object (*interfaceCreate)(UInt);
static Object (*parametersCopy)(Object);
static void (*requireInterface)(Object, Object);
static void (*requireType)(Object, UInt);
static void (*setLocalEndpoint)(Object, Object);
static void (*networkRelease)(Object);
static Object (*copyKeys)(Object, Object);
static Object (*copyValue)(Object, Object);
static Object (*stringCreate)(Object, const char *, UInt);
static Boolean (*stringCString)(Object, char *, Index, UInt);
static Object (*arrayValue)(Object, Index);
static Index (*arrayCount)(Object);
static Object (*dictionaryValue)(Object, Object);
static Boolean (*numberValue)(Object, Index, void *);
static TypeID (*getType)(Object);
static TypeID (*dictionaryType)(void), (*arrayType)(void), (*stringType)(void), (*numberType)(void);
static void (*cfRelease)(Object);

#define UTF8 0x08000100u
static Object string(const char *s) { return stringCreate(0, s, UTF8); }
static Object key(Object dict, const char *name) {
    if (!dict || getType(dict) != dictionaryType()) return 0;
    Object k = string(name);
    if (!k) return 0;
    Object v = dictionaryValue(dict, k);
    cfRelease(k);
    return v;
}
static int tunnelName(const char *name) {
    if (name[0] != 'u' || name[1] != 't' || name[2] != 'u' || name[3] != 'n') return 0;
    unsigned n = 4;
    if (!name[n]) return 0;
    for (; name[n]; n++) if (name[n] < '0' || name[n] > '9') return 0;
    return 1;
}

/* Resolve a connected packet VPN from live system state, never a fixed utun number.
 * Ambiguous/missing state leaves the original connection parameters untouched. */
static UInt activeTunnel(void) {
    Object pattern = string("State:/Network/Service/[^/]+/IPv4");
    if (!pattern) return 0;
    Object keys = copyKeys(0, pattern);
    cfRelease(pattern);
    if (!keys) return 0;
    if (getType(keys) != arrayType()) { cfRelease(keys); return 0; }
    UInt selected = 0, matches = 0;
    Index count = arrayCount(keys);
    if (count > 64) { cfRelease(keys); return 0; }
    for (Index i = 0; i < count; i++) {
        Object stateKey = arrayValue(keys, i);
        if (!stateKey || getType(stateKey) != stringType()) continue;
        Object state = copyValue(0, stateKey);
        char name[32] = {0}, vpnKey[160] = {0};
        Object value = key(state, "InterfaceName");
        int eligible = value && getType(value) == stringType() &&
            stringCString(value, name, sizeof(name), UTF8) && tunnelName(name) &&
            stringCString(stateKey, vpnKey, sizeof(vpnKey), UTF8);
        if (state) cfRelease(state);
        if (!eligible) continue;
        unsigned n = 0;
        while (vpnKey[n]) n++;
        if (n < 5 || strcmp(vpnKey + n - 5, "/IPv4")) continue;
        vpnKey[n - 4] = 'V'; vpnKey[n - 3] = 'P'; vpnKey[n - 2] = 'N'; vpnKey[n - 1] = 0;
        Object k = string(vpnKey);
        if (!k) continue;
        Object vpn = copyValue(0, k);
        cfRelease(k);
        int status = -1;
        value = key(vpn, "Status");
        int connected = value && getType(value) == numberType() &&
            numberValue(value, 3 /* kCFNumberSInt32Type */, &status) &&
            /* Dynamic-store VPN state on the tested iOS 16.6.1 device.
             * This is not SCNetworkConnectionGetStatus's enum. */
            status == 7;
        if (vpn) cfRelease(vpn);
        if (!connected) continue;
        UInt index = if_nametoindex(name);
        if (index) { selected = index; matches++; }
    }
    cfRelease(keys);
    return matches == 1 ? selected : 0;
}

%config(generator=MobileSubstrate);
%group APNsScope
%hookf(Object, nw_connection_create, Object endpoint, Object parameters) {
    if (!endpoint || !parameters || !apns_endpoint(endpointPort(endpoint), endpointHost(endpoint)))
        return %orig(endpoint, parameters);
    UInt index = activeTunnel();
    if (!index) return %orig(endpoint, parameters);
    Object interface = interfaceCreate(index);
    Object copy = interface ? parametersCopy(parameters) : 0;
    if (!copy) {
        if (interface) networkRelease(interface);
        return %orig(endpoint, parameters);
    }
    /* Remove apsd's physical-interface/source restriction on this copy only. */
    requireType(copy, 0);
    setLocalEndpoint(copy, 0);
    requireInterface(copy, interface);
    Object connection = %orig(endpoint, copy);
    networkRelease(copy);
    networkRelease(interface);
    return connection;
}

%end

%ctor {
    const char *name = getprogname();
    if (!name || strcmp(name, "apsd")) return;
    dlopen("/System/Library/Frameworks/Network.framework/Network", 2);
    dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration", 2);
#define LOAD(variable, symbol) do { variable = dlsym((Object)-2, symbol); if (!variable) return; } while (0)
    LOAD(endpointPort, "nw_endpoint_get_port"); LOAD(endpointHost, "nw_endpoint_get_hostname");
    LOAD(interfaceCreate, "nw_interface_create_with_index"); LOAD(parametersCopy, "nw_parameters_copy");
    LOAD(requireInterface, "nw_parameters_require_interface"); LOAD(requireType, "nw_parameters_set_required_interface_type");
    LOAD(setLocalEndpoint, "nw_parameters_set_local_endpoint"); LOAD(networkRelease, "nw_release");
    LOAD(copyKeys, "SCDynamicStoreCopyKeyList"); LOAD(copyValue, "SCDynamicStoreCopyValue");
    LOAD(stringCreate, "CFStringCreateWithCString"); LOAD(stringCString, "CFStringGetCString");
    LOAD(arrayValue, "CFArrayGetValueAtIndex"); LOAD(arrayCount, "CFArrayGetCount");
    LOAD(dictionaryValue, "CFDictionaryGetValue"); LOAD(numberValue, "CFNumberGetValue");
    LOAD(getType, "CFGetTypeID"); LOAD(dictionaryType, "CFDictionaryGetTypeID");
    LOAD(arrayType, "CFArrayGetTypeID"); LOAD(stringType, "CFStringGetTypeID");
    LOAD(numberType, "CFNumberGetTypeID"); LOAD(cfRelease, "CFRelease");
#undef LOAD
    Object target = dlsym((Object)-2, "nw_connection_create");
    if (target) {
        %init(APNsScope, nw_connection_create=target);
    }
}
