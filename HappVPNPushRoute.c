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

static void (*originalInclude)(Object, Selector, Boolean);
static void (*originalExclude)(Object, Selector, Boolean);
static void (*originalLocal)(Object, Selector, Boolean);
static void (*originalEnforce)(Object, Selector, Boolean);
static void (*originalSave)(Object, Selector, Object);

static void setInclude(Object self, Selector selector, Boolean requested) {
    (void)requested;
    originalInclude(self, selector, 0);
}

static void setExclude(Object self, Selector selector, Boolean requested) {
    (void)requested;
    originalExclude(self, selector, 0);
}

static void setLocal(Object self, Selector selector, Boolean requested) {
    (void)requested;
    originalLocal(self, selector, 1);
}

static void setEnforce(Object self, Selector selector, Boolean requested) {
    (void)requested;
    originalEnforce(self, selector, 0);
}

static void savePreferences(Object self, Selector selector, Object completion) {
    Object protocol = ((Object (*)(Object, Selector))objc_msgSend)(
        self, sel_registerName("protocolConfiguration"));

    if (protocol) {
        ((void (*)(Object, Selector, Boolean))objc_msgSend)(
            protocol, sel_registerName("setIncludeAllNetworks:"), 0);
        ((void (*)(Object, Selector, Boolean))objc_msgSend)(
            protocol, sel_registerName("setEnforceRoutes:"), 0);
        ((void (*)(Object, Selector, Boolean))objc_msgSend)(
            protocol, sel_registerName("setExcludeAPNs:"), 0);
        ((void (*)(Object, Selector, Boolean))objc_msgSend)(
            protocol, sel_registerName("setExcludeLocalNetworks:"), 1);
    }

    originalSave(self, selector, completion);
}

__attribute__((constructor)) static void installHooks(void) {
    dlopen("/System/Library/Frameworks/NetworkExtension.framework/NetworkExtension", 2);

    Object protocolClass = objc_getClass("NEVPNProtocol");
    Object managerClass = objc_getClass("NEVPNManager");
    Method include = class_getInstanceMethod(
        protocolClass, sel_registerName("setIncludeAllNetworks:"));
    Method exclude = class_getInstanceMethod(
        protocolClass, sel_registerName("setExcludeAPNs:"));
    Method local = class_getInstanceMethod(
        protocolClass, sel_registerName("setExcludeLocalNetworks:"));
    Method save = class_getInstanceMethod(
        managerClass, sel_registerName("saveToPreferencesWithCompletionHandler:"));
    Method enforce = class_getInstanceMethod(
        protocolClass, sel_registerName("setEnforceRoutes:"));

    if (!include || !exclude || !local || !save || !enforce)
        return;

    originalInclude = (void (*)(Object, Selector, Boolean))
        method_setImplementation(include, (Implementation)setInclude);
    originalExclude = (void (*)(Object, Selector, Boolean))
        method_setImplementation(exclude, (Implementation)setExclude);
    originalLocal = (void (*)(Object, Selector, Boolean))
        method_setImplementation(local, (Implementation)setLocal);
    originalEnforce = (void (*)(Object, Selector, Boolean))
        method_setImplementation(enforce, (Implementation)setEnforce);
    originalSave = (void (*)(Object, Selector, Object))
        method_setImplementation(save, (Implementation)savePreferences);
}
