#!/usr/bin/env bash
# Packages the bundle `flutter build linux --release` leaves in
# build/linux/x64/release/bundle into the .deb, .rpm, AppImage and pacman
# archives the release workflow publishes. Run from anywhere, in the repo root.
#
# Needs dpkg-deb (dpkg), rpmbuild (rpm), bsdtar (libarchive-tools) and xz.
set -euo pipefail
export LC_ALL=C

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

version=$(sed -n 's/^version: \([^+]*\).*/\1/p' pubspec.yaml)
[[ -n $version ]] || { echo "error: pubspec.yaml declares no version" >&2; exit 1; }
bundle=build/linux/x64/release/bundle
[[ -f $bundle/yukari ]] || { echo "error: $bundle is missing; run flutter build linux --release" >&2; exit 1; }

work=$root/build/linux-package
out=$root/build/packages
rm -rf "$work" "$out"
mkdir -p "$out"

# Every format installs the same tree: the relocatable bundle under
# /usr/lib/yukari, reached through /usr/bin/yukari. The desktop entry is named
# after linux/CMakeLists.txt' APPLICATION_ID, which is the app_id a Wayland
# compositor matches a window against.
# The entry it replaced (yukari.desktop) is dropped by dpkg, rpm and pacman on
# upgrade, and by CMake from a bundle installed over an old one.
app_id=$(sed -n 's/^set(APPLICATION_ID "\(.*\)")/\1/p' linux/CMakeLists.txt)
[[ -n $app_id ]] || { echo "error: linux/CMakeLists.txt declares no APPLICATION_ID" >&2; exit 1; }
entry=$app_id.desktop
usr=$work/usr
mkdir -p "$usr/lib/yukari" "$usr/bin" "$usr/share"
cp -a "$bundle/." "$usr/lib/yukari/"
mv "$usr/lib/yukari/share/icons" "$usr/share/icons"
mkdir -p "$usr/share/applications"
mv "$usr/lib/yukari/share/applications/$entry" "$usr/share/applications/$entry"
rm -rf "$usr/lib/yukari/share"
# The bundle's entry points into the build tree, which does not survive installation.
sed -i 's|^Exec=.*|Exec=yukari|' "$usr/share/applications/$entry"
ln -s ../lib/yukari/yukari "$usr/bin/yukari"

mkdir -p "$work/deb/DEBIAN"
cp -a "$usr" "$work/deb/"
cat > "$work/deb/DEBIAN/control" <<EOF
Package: yukari
Version: $version
Architecture: amd64
Maintainer: top.simonshiki
Installed-Size: $(du -sk "$usr" | cut -f1)
Section: net
Priority: optional
Depends: libgtk-3-0 | libgtk-3-0t64, libx11-6, libxi6, libnotify4, libstdc++6
Description: Cross-platform decentralized networking tool
 Yukari is a GUI for EasyTier, a decentralized networking tool.
EOF
dpkg-deb --build --root-owner-group "$work/deb" "$out/yukari_${version}_amd64.deb"

cat > "$work/yukari.spec" <<EOF
%global debug_package %{nil}
Name: yukari
Version: $version
Release: 1
Summary: Cross-platform decentralized networking tool
License: Proprietary
BuildArch: x86_64
Requires: gtk3

%description
Yukari is a GUI for EasyTier, a decentralized networking tool.

%install
mkdir -p %{buildroot}
cp -a $usr %{buildroot}/

%files
/usr/bin/yukari
/usr/lib/yukari
/usr/share/applications/$entry
/usr/share/icons/hicolor
EOF
mkdir -p "$work/rpmbuild"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
rpmbuild -bb "$work/yukari.spec" --define "_topdir $work/rpmbuild"
mv "$work/rpmbuild/RPMS/x86_64/"*.rpm "$out/"

# A pacman package, as makepkg builds one: /usr plus .PKGINFO and .MTREE.
pac=$work/pacman
mkdir -p "$pac"
cp -a "$usr" "$pac/"
cat > "$pac/.PKGINFO" <<EOF
pkgname = yukari
pkgbase = yukari
pkgver = $version-1
pkgdesc = Cross-platform decentralized networking tool
url = https://github.com/SimonShiki/yukari
builddate = $(date +%s)
packager = top.simonshiki
size = $(du -sb "$usr" | cut -f1)
arch = x86_64
license = Proprietary
depend = gtk3
depend = libnotify
EOF
# Both the tarball and the .MTREE pacman verifies it against must say root.
owner=(--uid 0 --gid 0 --uname root --gname root)
(cd "$pac" && bsdtar -czf .MTREE --format=mtree "${owner[@]}" \
  --options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256,link' .PKGINFO usr)
(cd "$pac" && bsdtar -cf - "${owner[@]}" .PKGINFO .MTREE usr |
  xz -c > "$out/yukari-$version-1-x86_64.pkg.tar.xz")

appdir=$work/Yukari.AppDir
mkdir -p "$appdir"
cp -a "$usr" "$appdir/usr"
cp "$usr/share/icons/hicolor/512x512/apps/yukari.png" "$appdir/yukari.png"
cp "$usr/share/applications/$entry" "$appdir/$entry"
cat > "$appdir/AppRun" <<'EOF'
#!/bin/sh
exec "$APPDIR/usr/bin/yukari" "$@"
EOF
chmod 755 "$appdir/AppRun"

tools=$root/build/packaging-tools
mkdir -p "$tools"
curl -fsSL -o "$tools/appimagetool" \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x "$tools/appimagetool"
ARCH=x86_64 VERSION=$version APPIMAGE_EXTRACT_AND_RUN=1 \
  "$tools/appimagetool" --no-appstream "$appdir" "$out/yukari-$version-x86_64.AppImage"

ls -l "$out"
