#!/usr/bin/env bash

# ---------------------------------------------------------------------------------------------
#   Copyright (c) Microsoft Corporation. All rights reserved.
#   Licensed under the MIT License. See License.txt in the project root for license information.
# ---------------------------------------------------------------------------------------------

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
recipe_dir="$repo_root/scripts/local-vscode-package"
package_dir="$repo_root/.build/local-vscode-package"
artifact=$(realpath -m "$repo_root/../VSCode-linux-x64")
install_package=true

if [[ ${1:-} == '--no-install' ]]; then
	install_package=false
elif [[ $# -gt 0 ]]; then
	printf 'Usage: %s [--no-install]\n' "$0" >&2
	exit 2
fi

if [[ $EUID -eq 0 ]]; then
	printf 'Run this script as your normal user. It invokes sudo only for pacman at the end.\n' >&2
	exit 1
fi

for required_command in node npm cargo curl makepkg sha256sum bsdtar; do
	if ! command -v "$required_command" >/dev/null 2>&1; then
		printf 'Missing required command: %s\n' "$required_command" >&2
		exit 1
	fi
done
if $install_package && ! command -v sudo >/dev/null 2>&1; then
	printf 'Missing required command: sudo\n' >&2
	exit 1
fi

cd "$repo_root"

printf '\n==> Installing source dependencies\n'
npm install

printf '\n==> Compiling test output\n'
npm run transpile-client
node -e "require('fs').writeFileSync('out/date', new Date().toISOString())"

printf '\n==> Running snippet tests\n'
./scripts/test.sh \
	--run src/vs/workbench/contrib/snippets/test/browser/tabCompletion.test.ts \
	--run src/vs/workbench/contrib/snippets/test/browser/snippetFile.test.ts

printf '\n==> Building Linux x64 desktop artifact\n'
npm run gulp vscode-linux-x64

artifact_product="$artifact/resources/app/product.json"
artifact_package="$artifact/resources/app/package.json"
if [[ ! -x $artifact/code || ! -f $artifact_product || ! -f $artifact_package ]]; then
	printf 'Incomplete desktop artifact: %s\n' "$artifact" >&2
	exit 1
fi

version=$(node -p "require('$artifact_product').version")
commit=$(node -p "require('$artifact_product').commit")
if [[ -z $version || -z $commit || $commit == undefined ]]; then
	printf 'Desktop artifact is missing version or commit metadata.\n' >&2
	exit 1
fi

printf 'Source build: %s (%s)\n' "$version" "$commit"

printf '\n==> Building tunnel CLI\n'
cargo clean --release -p code-cli --manifest-path "$repo_root/cli/Cargo.toml"
	VSCODE_CLI_COMMIT="$commit" \
	cargo build --release --bin code --manifest-path "$repo_root/cli/Cargo.toml"

tunnel_cli="$repo_root/cli/target/release/code"
if [[ ! -x $tunnel_cli ]]; then
	printf 'Tunnel CLI was not produced: %s\n' "$tunnel_cli" >&2
	exit 1
fi

printf '\n==> Creating local Arch package\n'
install -d "$package_dir"
install -m644 "$recipe_dir/PKGBUILD.sh" "$package_dir/PKGBUILD"
curl -fL --retry 3 --retry-delay 2 \
	-o "$package_dir/vscode.png" \
	'https://code.visualstudio.com/assets/branding/code-stable.png'
export LOCAL_VSCODE_ARTIFACT="$artifact"
export LOCAL_VSCODE_TUNNEL_CLI="$tunnel_cli"
export LOCAL_VSCODE_LINUX_RESOURCES="$repo_root/resources/linux"
export LOCAL_VSCODE_ICON="$package_dir/vscode.png"
export LOCAL_VSCODE_PKGVER="$version"
export LOCAL_VSCODE_PKGREL=$(date +%Y%m%d%H%M%S)
cd "$package_dir"
makepkg --force --cleanbuild
package_path=$(makepkg --packagelist)

printf '\n==> Validating package\n'
window_icon_hash=$(bsdtar -xOf "$package_path" usr/share/code/resources/app/resources/linux/code.png | sha256sum | awk '{print $1}')
desktop_icon_hash=$(bsdtar -xOf "$package_path" usr/share/pixmaps/vscode.png | sha256sum | awk '{print $1}')
if [[ $window_icon_hash != "$desktop_icon_hash" ]]; then
	printf 'Packaged icon validation failed.\n' >&2
	exit 1
fi
packaged_desktop_name=$(bsdtar -xOf "$package_path" usr/share/code/resources/app/package.json | node -p 'JSON.parse(require("fs").readFileSync(0, "utf8")).desktopName')
if [[ $packaged_desktop_name != 'code.desktop' ]]; then
	printf 'Packaged desktop identity is %s instead of code.desktop.\n' "$packaged_desktop_name" >&2
	exit 1
fi
if ! bsdtar -tvf "$package_path" | awk '$1 == "-rwsr-xr-x" && $NF == "usr/share/code/chrome-sandbox" { found=1 } END { exit !found }'; then
	printf 'Packaged chrome-sandbox is missing mode 4755.\n' >&2
	exit 1
fi

package_hash=$(sha256sum "$package_path" | awk '{print $1}')
printf 'Package: %s\n' "$package_path"
printf 'SHA-256: %s\n' "$package_hash"

if ! $install_package; then
	printf '\nPackage created without installation.\n'
	exit 0
fi

printf '\n==> Installing with pacman\n'
printf 'Close all running Visual Studio Code windows before continuing.\n'
read -r -p 'Press Enter to install, or Ctrl+C to cancel: '
sudo pacman -U "$package_path"

printf '\nInstalled version:\n'
code --version
