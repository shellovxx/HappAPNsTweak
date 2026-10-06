#ifndef HAPP_APNS_ENDPOINT_H
#define HAPP_APNS_ENDPOINT_H
static unsigned apns_lower(unsigned c) {
    return c >= 'A' && c <= 'Z' ? c + ('a' - 'A') : c;
}
/* Called only inside apsd. Port 443 additionally requires a push service name. */
static int apns_endpoint(unsigned port, const char *host) {
    if (port == 5223) return 1;
    if (port != 443 || !host) return 0;
    unsigned n = 0;
    while (host[n] && n < 253) n++;
    if (host[n]) return 0;
    if (n && host[n - 1] == '.') n--;
    const char suffix[] = "push.apple.com";
    unsigned m = sizeof(suffix) - 1;
    if (n < m || (n > m && host[n - m - 1] != '.')) return 0;
    for (unsigned i = 0; i < m; i++)
        if (apns_lower((unsigned char)host[n - m + i]) != (unsigned)suffix[i]) return 0;
    return 1;
}
#endif
