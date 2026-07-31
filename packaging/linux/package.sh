#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <version>" >&2
  exit 2
fi

version="$1"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bundle_dir="$root_dir/build/linux/x64/release/bundle"
work_dir="$root_dir/build/package/linux"
dist_dir="$root_dir/dist"
appimagetool="${APPIMAGETOOL:-}"

if [[ ! -x "$bundle_dir/terminal_master" ]]; then
  echo "Linux release bundle not found at $bundle_dir" >&2
  exit 1
fi
if [[ -z "$appimagetool" || ! -x "$appimagetool" ]]; then
  echo "APPIMAGETOOL must point to an executable appimagetool" >&2
  exit 1
fi

rm -rf "$work_dir"
mkdir -p "$work_dir/terminal-master" "$dist_dir"
cp -a "$bundle_dir/." "$work_dir/terminal-master/"

tar -C "$work_dir" -czf \
  "$dist_dir/terminal-master-$version-linux-x86_64.tar.gz" terminal-master

deb_root="$work_dir/deb"
mkdir -p \
  "$deb_root/DEBIAN" \
  "$deb_root/opt/terminal-master" \
  "$deb_root/usr/bin" \
  "$deb_root/usr/share/applications" \
  "$deb_root/usr/share/icons/hicolor/512x512/apps"
cp -a "$bundle_dir/." "$deb_root/opt/terminal-master/"
ln -s /opt/terminal-master/terminal_master "$deb_root/usr/bin/terminal_master"
install -m 0644 \
  "$root_dir/packaging/linux/io.github.duffbeer.terminalmaster.desktop" \
  "$deb_root/usr/share/applications/io.github.duffbeer.terminalmaster.desktop"
install -m 0644 "$root_dir/packaging/linux/terminal_master.png" \
  "$deb_root/usr/share/icons/hicolor/512x512/apps/terminal_master.png"
installed_size="$(du -sk "$deb_root/opt/terminal-master" | cut -f1)"
cat > "$deb_root/DEBIAN/control" <<EOF
Package: terminal-master
Version: $version
Section: devel
Priority: optional
Architecture: amd64
Installed-Size: $installed_size
Depends: libgtk-3-0, libstdc++6
Maintainer: Terminal Master project <noreply@github.com>
Homepage: https://github.com/Duff-Beer/terminal_master
Description: Validated terminal command builder
 Build terminal commands from reusable YAML definitions with validation and
 explicit confirmation for risky operations.
EOF
dpkg-deb --root-owner-group --build "$deb_root" \
  "$dist_dir/terminal-master_${version}_amd64.deb"

app_dir="$work_dir/TerminalMaster.AppDir"
mkdir -p \
  "$app_dir/usr/bin" \
  "$app_dir/usr/share/applications" \
  "$app_dir/usr/share/icons/hicolor/512x512/apps"
cp -a "$bundle_dir/." "$app_dir/usr/bin/"
install -m 0755 "$root_dir/packaging/linux/AppRun" "$app_dir/AppRun"
install -m 0644 \
  "$root_dir/packaging/linux/io.github.duffbeer.terminalmaster.desktop" \
  "$app_dir/io.github.duffbeer.terminalmaster.desktop"
install -m 0644 \
  "$root_dir/packaging/linux/io.github.duffbeer.terminalmaster.desktop" \
  "$app_dir/usr/share/applications/io.github.duffbeer.terminalmaster.desktop"
install -m 0644 "$root_dir/packaging/linux/terminal_master.png" \
  "$app_dir/terminal_master.png"
install -m 0644 "$root_dir/packaging/linux/terminal_master.png" \
  "$app_dir/usr/share/icons/hicolor/512x512/apps/terminal_master.png"

ARCH=x86_64 "$appimagetool" --appimage-extract-and-run "$app_dir" \
  "$dist_dir/terminal-master-$version-linux-x86_64.AppImage"
