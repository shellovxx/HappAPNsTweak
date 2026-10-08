#!/bin/sh
# Use an Apple-compatible toolchain with the iOS 14+ arm64e ABI.
set -eu
happ_project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
happ_build=${HAPP_BUILD_DIR:-$happ_project/work/ios-build}
happ_sdk=${HAPP_SDK:?Set HAPP_SDK to an iOS 16.5 SDK}
happ_theos=${THEOS:?Set THEOS to roothide/theos}
happ_cc=${HAPP_CLANG:-clang}
happ_ld=${HAPP_LD:-ld}
happ_sign=${HAPP_LDID:-ldid}
happ_lipo=${HAPP_LIPO:-lipo}
mkdir -p "$happ_build"
for happ_name in HappVPNPushRoute HappAPNsDNS HappAPNsScope; do
    happ_flags=''
    happ_frameworks='-framework Foundation'
    happ_extension=xm
    case "$happ_name" in
        HappVPNPushRoute|HappAPNsDNS)
            happ_flags=-fobjc-arc
            happ_frameworks="$happ_frameworks -framework NetworkExtension";;
        HappAPNsScope)
            happ_extension=x
            happ_frameworks="$happ_frameworks -framework Network -framework SystemConfiguration";;
    esac
    perl "$happ_theos/vendor/logos/bin/logos.pl" "$happ_project/$happ_name.$happ_extension" > "$happ_build/$happ_name.m"
    for happ_arch in arm64 arm64e; do
    "$happ_cc" -target "$happ_arch-apple-ios16.4" -isysroot "$happ_sdk" -I"$happ_project" -I"$happ_theos/vendor/include" -F"$happ_theos/vendor/lib/iphone/roothide" -DTHEOS_PACKAGE_SCHEME_ROOTHIDE -O2 -DNDEBUG -fvisibility=hidden -Wall -Wextra -Werror -Wno-unused-parameter $happ_flags -c "$happ_build/$happ_name.m" -o "$happ_build/$happ_name.$happ_arch.o"
    "$happ_ld" -dylib -arch "$happ_arch" -platform_version ios 16.4 16.5 -syslibroot "$happ_sdk" -L"$happ_theos/vendor/lib/iphone/roothide" -F"$happ_theos/vendor/lib/iphone/roothide" -lSystem -lobjc -framework CydiaSubstrate $happ_frameworks -install_name "@rpath/$happ_name.dylib" -headerpad 0x1000 -x -o "$happ_build/$happ_name.$happ_arch.dylib" "$happ_build/$happ_name.$happ_arch.o"
    "$happ_sign" -S "$happ_build/$happ_name.$happ_arch.dylib"
    done
    "$happ_lipo" -create "$happ_build/$happ_name.arm64.dylib" "$happ_build/$happ_name.arm64e.dylib" -output "$happ_build/$happ_name.dylib"
done
python3 "$happ_project/scripts/package.py" --binaries "$happ_build" --output "$happ_project/packages/local.happvpnpushroute_1.5.0_iphoneos-arm64e.deb"
