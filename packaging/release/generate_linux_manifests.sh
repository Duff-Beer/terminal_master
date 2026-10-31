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
tarball_name="terminal-master-$version-linux-x86_64.tar.gz"
tarball_path="$asset_dir/$tarball_name"

if [[ ! -f "$appimage_path" ]]; then
  echo "AppImage not found at $appimage_path" >&2
  exit 1
fi
if [[ ! -f "$tarball_path" ]]; then
  echo "Linux tarball not found at $tarball_path" >&2
  exit 1
fi

sha256="$(sha256sum "$appimage_path" | cut -d ' ' -f1)"
release_url="https://github.com/$repository/releases/download/v$version/$appimage_name"
tarball_sri="sha256-$(openssl dgst -sha256 -binary "$tarball_path" | base64 | tr -d '\n')"
tarball_release_url="https://github.com/$repository/releases/download/v$version/$tarball_name"

cat > "$asset_dir/PKGBUILD" <<EOF
pkgname=terminal-master-bin
pkgver=$version
pkgrel=1
pkgdesc='Validated terminal command builder'
arch=('x86_64')
url='https://github.com/$repository'
license=('custom')
depends=('gtk3' 'libsecret')
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
        url = "$tarball_release_url";
        hash = "$tarball_sri";
      };

      package = pkgs.stdenv.mkDerivation {
        inherit pname version src;

        nativeBuildInputs = with pkgs; [
          autoPatchelfHook
          makeWrapper
          wrapGAppsHook3
        ];

        buildInputs = with pkgs; [
          atk
          cairo
          gdk-pixbuf
          glib
          gtk3
          harfbuzz
          libepoxy
          libsecret
          pango
          stdenv.cc.cc.lib
        ];

        sourceRoot = "terminal-master";
        dontBuild = true;

        # flutter_pty loads libflutter_pty.so via dlopen by bare name
        preFixup = ''
          gappsWrapperArgs+=(
            --prefix LD_LIBRARY_PATH : "\$out/lib/terminal-master/lib"
          )
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p \$out/lib/terminal-master \$out/bin
          cp -a . \$out/lib/terminal-master/

          install -Dm444 \
            share/applications/io.github.duffbeer.terminalmaster.desktop \
            \$out/share/applications/io.github.duffbeer.terminalmaster.desktop
          install -Dm444 \
            share/icons/hicolor/512x512/apps/terminal_master.png \
            \$out/share/icons/hicolor/512x512/apps/terminal_master.png
          rm -rf \$out/lib/terminal-master/share

          substituteInPlace \
            \$out/share/applications/io.github.duffbeer.terminalmaster.desktop \
            --replace-fail "Exec=terminal_master" \
              "Exec=terminal-master"

          makeWrapper \
            \$out/lib/terminal-master/terminal_master \
            \$out/bin/terminal-master

          runHook postInstall
        '';

        meta = {
          description = "Validated terminal command builder";
          homepage = "https://github.com/$repository";
          mainProgram = "terminal-master";
          platforms = [ "x86_64-linux" ];
        };
      };
    in {
      packages.\${system} = {
        terminal-master = package;
        default = package;
      };
      apps.\${system}.default = {
        type = "app";
        program = "\${package}/bin/terminal-master";
      };
    };
}
EOF
