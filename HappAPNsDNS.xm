#import <NetworkExtension/NetworkExtension.h>
#include <dlfcn.h>

%config(generator=MobileSubstrate);
%group HappDNS
%hook NETunnelProvider
- (void)setTunnelNetworkSettings:(NETunnelNetworkSettings *)settings
              completionHandler:(void (^)(NSError *))completion {
    NEDNSSettings *dns = settings.DNSSettings;
    if ([dns isKindOfClass:[NEDNSOverHTTPSSettings class]] && dns.servers.count) {
        NEDNSSettings *plain = [[NEDNSSettings alloc] initWithServers:dns.servers];
        plain.matchDomains = dns.matchDomains;
        plain.searchDomains = dns.searchDomains;
        plain.matchDomainsNoSearch = dns.matchDomainsNoSearch;
        settings.DNSSettings = plain;
    }
    %orig(settings, completion);
}
%end
%end

%ctor {
    dlopen("/System/Library/Frameworks/NetworkExtension.framework/NetworkExtension", RTLD_NOW);
    Class provider = objc_getClass("NETunnelProvider");
    if (provider && [provider instancesRespondToSelector:@selector(setTunnelNetworkSettings:completionHandler:)]) {
        %init(HappDNS);
    }
}
