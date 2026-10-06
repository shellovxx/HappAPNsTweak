#include "../apns_endpoint.h"
#include <stdio.h>
int main(void) {
    struct { unsigned port; const char *host; int expected; } cases[] = {
        {5223, "17-courier.push.apple.com", 1}, {5223, "17.57.146.25", 1},
        {5223, 0, 1}, {443, "17-courier.push.apple.com", 1},
        {443, "push.apple.com", 1}, {443, "PUSH.APPLE.COM.", 1},
        {443, "setup.icloud.com", 0}, {443, "17.57.146.25", 0},
        {443, "push.apple.com.evil.test", 0}, {443, "evilpush.apple.com", 0},
        {443, "example.com", 0}, {443, "", 0}, {443, 0, 0},
        {80, "push.apple.com", 0}, {5224, "push.apple.com", 0},
        {67, "push.apple.com", 0}, {68, "push.apple.com", 0}
    };
    for (unsigned i = 0; i < sizeof(cases) / sizeof(cases[0]); i++)
        if (apns_endpoint(cases[i].port, cases[i].host) != cases[i].expected) {
            fprintf(stderr, "failed case %u\n", i); return 1;
        }
    puts("17 endpoint cases passed");
    return 0;
}
