#import <NetworkExtension/NetworkExtension.h>
#include <dlfcn.h>

%config(generator=MobileSubstrate);
%group HappProfile
%hook NEVPNProtocol
- (void)setIncludeAllNetworks:(BOOL)value {
    %orig(NO);
}
- (void)setEnforceRoutes:(BOOL)value {
    %orig(NO);
}
- (void)setExcludeAPNs:(BOOL)value {
    %orig(NO);
}
- (void)setExcludeLocalNetworks:(BOOL)value {
    %orig(YES);
}
%end

%hook NEVPNManager
- (void)saveToPreferencesWithCompletionHandler:(void (^)(NSError *))completion {
    NEVPNProtocol *protocol = self.protocolConfiguration;
    if (protocol) {
        protocol.includeAllNetworks = NO;
        protocol.enforceRoutes = NO;
        protocol.excludeAPNs = NO;
        protocol.excludeLocalNetworks = YES;
    }
    %orig(completion);
}
%end
%end

%ctor {
    dlopen("/System/Library/Frameworks/NetworkExtension.framework/NetworkExtension", RTLD_NOW);
    Class protocol = objc_getClass("NEVPNProtocol");
    Class manager = objc_getClass("NEVPNManager");
    if (protocol && manager &&
        [protocol instancesRespondToSelector:@selector(setIncludeAllNetworks:)] &&
        [protocol instancesRespondToSelector:@selector(setEnforceRoutes:)] &&
        [protocol instancesRespondToSelector:@selector(setExcludeAPNs:)] &&
        [protocol instancesRespondToSelector:@selector(setExcludeLocalNetworks:)] &&
        [manager instancesRespondToSelector:@selector(saveToPreferencesWithCompletionHandler:)]) {
        %init(HappProfile);
    }
}
