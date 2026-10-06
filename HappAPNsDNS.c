typedef void *Object;
typedef void *Selector;
typedef void *Method;
typedef void (*Implementation)(void);
typedef signed char Boolean;

extern Object objc_getClass(const char *);
extern Selector sel_registerName(const char *);
extern Method class_getInstanceMethod(Object, Selector);
extern Implementation method_setImplementation(Method, Implementation);
extern void objc_msgSend(void);
extern void *dlopen(const char *, int);

static void (*original)(Object, Selector, Object, Object);

static Object get(Object object, const char *selector) {
    return ((Object (*)(Object, Selector))objc_msgSend)(
        object, sel_registerName(selector));
}

static void apply(Object self, Selector selector, Object settings, Object completion) {
    Object dns = get(settings, "DNSSettings");
    Object dohClass = objc_getClass("NEDNSOverHTTPSSettings");

    if (dns && dohClass && ((Boolean (*)(Object, Selector, Object))objc_msgSend)(
            dns, sel_registerName("isKindOfClass:"), dohClass)) {
        Object servers = get(dns, "servers");
        Object plain = ((Object (*)(Object, Selector, Object))objc_msgSend)(
            get(objc_getClass("NEDNSSettings"), "alloc"),
            sel_registerName("initWithServers:"), servers);
        Object match = get(dns, "matchDomains");
        Object search = get(dns, "searchDomains");

        if (match)
            ((void (*)(Object, Selector, Object))objc_msgSend)(
                plain, sel_registerName("setMatchDomains:"), match);
        if (search)
            ((void (*)(Object, Selector, Object))objc_msgSend)(
                plain, sel_registerName("setSearchDomains:"), search);

        ((void (*)(Object, Selector, Object))objc_msgSend)(
            settings, sel_registerName("setDNSSettings:"), plain);
        get(plain, "release");
    }

    original(self, selector, settings, completion);
}

__attribute__((constructor)) static void install(void) {
    dlopen("/System/Library/Frameworks/NetworkExtension.framework/NetworkExtension", 2);

    Method method = class_getInstanceMethod(
        objc_getClass("NETunnelProvider"),
        sel_registerName("setTunnelNetworkSettings:completionHandler:"));

    if (method)
        original = (void (*)(Object, Selector, Object, Object))
            method_setImplementation(method, (Implementation)apply);
}
