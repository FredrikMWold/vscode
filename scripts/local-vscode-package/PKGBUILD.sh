# ---------------------------------------------------------------------------------------------
#   Copyright (c) Microsoft Corporation. All rights reserved.
#   Licensed under the MIT License. See License.txt in the project root for license information.
# ---------------------------------------------------------------------------------------------

_artifact=${LOCAL_VSCODE_ARTIFACT:?LOCAL_VSCODE_ARTIFACT must be set}
_tunnel_cli=${LOCAL_VSCODE_TUNNEL_CLI:?LOCAL_VSCODE_TUNNEL_CLI must be set}
_linux_resources=${LOCAL_VSCODE_LINUX_RESOURCES:?LOCAL_VSCODE_LINUX_RESOURCES must be set}
_icon=${LOCAL_VSCODE_ICON:?LOCAL_VSCODE_ICON must be set}

pkgname=visual-studio-code-local
pkgver=${LOCAL_VSCODE_PKGVER:?LOCAL_VSCODE_PKGVER must be set}
pkgrel=${LOCAL_VSCODE_PKGREL:?LOCAL_VSCODE_PKGREL must be set}
pkgdesc='Locally built Visual Studio Code with custom snippet auto-expansion'
arch=('x86_64')
url='https://github.com/microsoft/vscode'
license=('MIT')
depends=(
	'alsa-lib'
	'gcc-libs'
	'glibc'
	'gnupg'
	'gtk3'
	'libnotify'
	'libsecret'
	'libxkbfile'
	'libxss'
	'lsof'
	'nss'
	'shared-mime-info'
	'xdg-utils'
)
optdepends=(
	'glib2: Needed for move to trash functionality'
	'libdbusmenu-glib: Needed for KDE global menu'
	'org.freedesktop.secrets: Needed for settings sync'
)
provides=('code' 'vscode')
conflicts=('code' 'visual-studio-code-bin')
options=('!strip' '!debug')

package() {
	install -d "$pkgdir/usr/share/code"
	cp -a "$_artifact/." "$pkgdir/usr/share/code/"

	install -Dm755 "$_tunnel_cli" "$pkgdir/usr/share/code/bin/code-tunnel"

	install -d "$pkgdir/usr/bin"
	ln -s /usr/share/code/bin/code "$pkgdir/usr/bin/code"
	install -Dm644 "$_linux_resources/code.desktop" "$pkgdir/usr/share/applications/code.desktop"
	install -Dm644 "$_linux_resources/code-url-handler.desktop" "$pkgdir/usr/share/applications/code-url-handler.desktop"
	sed -i \
		-e 's/@@NAME_LONG@@/Visual Studio Code/g' \
		-e 's/@@NAME_SHORT@@/Code/g' \
		-e 's/@@NAME@@/code/g' \
		-e 's#@@EXEC@@#/usr/share/code/code#g' \
		-e 's/@@ICON@@/vscode/g' \
		-e 's/@@URLPROTOCOL@@/vscode/g' \
		"$pkgdir/usr/share/applications/code.desktop" \
		"$pkgdir/usr/share/applications/code-url-handler.desktop"
	install -Dm644 "$_linux_resources/code.appdata.xml" "$pkgdir/usr/share/appdata/code.appdata.xml"
	sed -i \
		-e 's/@@NAME_LONG@@/Visual Studio Code/g' \
		-e 's/@@NAME@@/code/g' \
		-e 's/@@LICENSE@@/MIT/g' \
		"$pkgdir/usr/share/appdata/code.appdata.xml"
	install -Dm644 "$_linux_resources/code-workspace.xml" "$pkgdir/usr/share/mime/packages/code-workspace.xml"
	sed -i \
		-e 's/@@NAME_LONG@@/Visual Studio Code/g' \
		-e 's/@@NAME@@/code/g' \
		"$pkgdir/usr/share/mime/packages/code-workspace.xml"
	install -Dm644 "$_icon" "$pkgdir/usr/share/code/resources/app/resources/linux/code.png"
	install -Dm644 "$_icon" "$pkgdir/usr/share/pixmaps/vscode.png"
	install -Dm644 "$pkgdir/usr/share/code/resources/completions/bash/code" "$pkgdir/usr/share/bash-completion/completions/code"
	install -Dm644 "$pkgdir/usr/share/code/resources/completions/zsh/_code" "$pkgdir/usr/share/zsh/vendor-completions/_code"
	install -Dm644 "$pkgdir/usr/share/code/resources/app/LICENSE.txt" "$pkgdir/usr/share/licenses/$pkgname/LICENSE.txt"

	chmod 4755 "$pkgdir/usr/share/code/chrome-sandbox"
}
