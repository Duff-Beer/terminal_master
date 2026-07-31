#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <version> <owner/repository> <asset-directory>" >&2
  exit 2
fi

version="$1"
repository="$2"
asset_dir="$3"
appimage_name="terminal-master-$version-linux-x86_64.AppImage"
appimage_path="$asset_dir/$appimage_name"

if [[ ! -f "$appimage_path" ]]; then
  echo "AppImage not found at $appimage_path" >&2
  exit 1
fi

sha256="$(sha256sum "$appimage_path" | cut -d ' ' -f1)"
sri="sha256-$(openssl dgst -sha256 -binary "$appimage_path" | base64 | tr -d '\n')"
release_url="https://github.com/$repository/releases/download/v$version/$appimage_name"

cat > "$asset_dir/PKGBUILD" <<EOF
pkgname=terminal-master-bin
pkgver=$version
pkgrel=1
pkgdesc='Validated terminal command builder'
arch=('x86_64')
url='https://github.com/$repository'
license=('custom')
depends=('gtk3')
options=('!strip')
source_x86_64=('$appimage_name::$release_url')
sha256sums_x86_64=('$sha256')

package() {
  chmod +x "\$srcdir/$appimage_name"
  install -Dm755 "\$srcdir/$appimage_name" \
    "\$pkgdir/opt/terminal-master/$appimage_name"
  mkdir -p "\$pkgdir/usr/bin"
  ln -s "/opt/terminal-master/$appimage_name" \
    "\$pkgdir/usr/bin/terminal_master"

  cd "\$srcdir"
  "./$appimage_name" --appimage-extract >/dev/null
  install -Dm644 squashfs-root/io.github.duffbeer.terminalmaster.desktop \
    "\$pkgdir/usr/share/applications/io.github.duffbeer.terminalmaster.desktop"
  install -Dm644 squashfs-root/terminal_master.png \
    "\$pkgdir/usr/share/icons/hicolor/512x512/apps/terminal_master.png"
}
EOF

cat > "$asset_dir/flake.nix" <<EOF
{
  description = "Terminal Master $version";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      pname = "terminal-master";
      version = "$version";
      src = pkgs.fetchurl {
        url = "$release_url";
        hash = "$sri";
      };
      contents = pkgs.appimageTools.extractType2 {
        inherit pname version src;
      };
      package = pkgs.appimageTools.wrapType2 {
        inherit pname version src;
        extraInstallCommands = ''
          install -m 444 -D \
            \${contents}/io.github.duffbeer.terminalmaster.desktop \
            \$out/share/applications/io.github.duffbeer.terminalmaster.desktop
          install -m 444 -D \
            \${contents}/terminal_master.png \
            \$out/share/icons/hicolor/512x512/apps/terminal_master.png
          substituteInPlace \
            \$out/share/applications/io.github.duffbeer.terminalmaster.desktop \
            --replace-fail "Exec=terminal_master" \
              "Exec=\$out/bin/terminal-master"
        '';
      };
    in {
      packages.\${system}.default = package;
      apps.\${system}.default = {
        type = "app";
        program = "\${package}/bin/terminal-master";
      };
    };
}
EOF
