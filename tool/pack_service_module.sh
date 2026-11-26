#!/usr/bin/env bash
# Packs the background service into a KernelSU/Magisk module, which runs it as
# root on Android. The app downloads it from its GitHub release, which
# .github/workflows/release.yml publishes beside the APKs.
#
# Dart cannot build Android executables, so the module carries the Linux
# build of packages/yukari_core/bin/yukari_service.dart for arm64 and x64,
# with the glibc it needs.
# Dart 3.14's `dart build cli` outputs the runtime (`bin/yukari_service`) and
# AOT snapshot (`lib/libdartaotyukari_service.so`) separately; we stage them
# as `bin/dartaotruntime` and `bin/yukari-service.aot` so the bundled loader can
# pass the snapshot explicitly (the runtime cannot auto-locate it when started
# via `ld-linux`).
#
# Usage: tool/pack_service_module.sh [output.zip]
#
# Takes glibc from SYSROOT_ARM64 and SYSROOT_X64, or else from where Debian,
# Ubuntu and Arch install it, natively or for cross compiling (such as the
# libc6-arm64-cross and libgcc-s1-arm64-cross packages).
set -euo pipefail
export LC_ALL=C

root=$(cd "$(dirname "$0")/.." && pwd)
output=$(realpath -m "${1:-$root/build/service_module/yukari-service-module.zip}")
work="$root/build/service_module/work"

die() {
  echo "error: $*" >&2
  exit 1
}

# The directory holding glibc for the arch $1, whose loader is $2.
sysroot() {
  local override candidates dir
  case $1 in
    arm64)
      override=${SYSROOT_ARM64:-}
      candidates=(/usr/aarch64-linux-gnu/lib /lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu)
      ;;
    x64)
      override=${SYSROOT_X64:-}
      candidates=(/usr/x86_64-linux-gnu/lib /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu)
      ;;
  esac
  [[ $(uname -m) == "$([[ $1 == arm64 ]] && echo aarch64 || echo x86_64)" ]] &&
    candidates+=(/usr/lib)
  for dir in ${override:+"$override"} "${candidates[@]}"; do
    if [[ -e $dir/$2 && -e $dir/libc.so.6 ]]; then
      echo "$dir"
      return
    fi
  done
  die "no glibc for $1 found; set SYSROOT_${1^^}"
}

# Copies the libraries $1 needs from $2 into $3, transitively.
copy_needed() {
  local lib
  for lib in $(readelf -d "$1" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
    [[ -e $3/$lib ]] && continue
    [[ -e $2/$lib ]] || die "$lib, which $(basename "$1") needs, is missing from $2"
    cp -L "$2/$lib" "$3/$lib"
    copy_needed "$3/$lib" "$2" "$3"
  done
}

cd "$root"
rm -rf "$work"
mkdir -p "$work/module"
cp tool/service_module/* "$work/module/"

# The version the app compares to its own; see the core's service_version.dart.
version=$(sed -n 's/^const serviceVersion = \([0-9]*\);$/\1/p' \
  packages/yukari_core/lib/backend/service_version.dart)
[[ -n $version ]] || die "serviceVersion was not found"
sed -i -e "s/@VERSION@/v$version/" -e "s/@VERSION_CODE@/$version/" \
  "$work/module/module.prop"

for arch in arm64 x64; do
  echo "Building the service for linux-$arch"
  (cd packages/yukari_core && dart build cli --target bin/yukari_service.dart \
    --target-os linux --target-arch "$arch" --output "$work/$arch")
  bundle="$work/$arch/bundle"
  dest="$work/module/$arch"
  mkdir -p "$dest/bin" "$dest/lib"
  cp "$bundle/bin/yukari_service" "$dest/bin/dartaotruntime"
  chmod 755 "$dest/bin/dartaotruntime"
  cp "$bundle"/lib/* "$dest/lib/"
  [[ -f $dest/lib/libdartaotyukari_service.so ]] ||
    die "$bundle/lib/libdartaotyukari_service.so was not produced"
  mv "$dest/lib/libdartaotyukari_service.so" "$dest/bin/yukari-service.aot"

  loader=$(readelf -l "$dest/bin/dartaotruntime" |
    sed -n 's/.*interpreter: \(.*\)\]/\1/p')
  libs=$(sysroot "$arch" "$(basename "$loader")")
  cp -L "$libs/$(basename "$loader")" "$dest/lib/"
  for file in "$dest/bin/dartaotruntime" "$dest"/lib/*; do
    copy_needed "$file" "$libs" "$dest/lib"
  done
done

mkdir -p "$(dirname "$output")"
rm -f "$output"
(cd "$work/module" && zip -qr9X "$output" .)
echo "Packed $output"
