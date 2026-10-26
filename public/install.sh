#!/bin/sh
#
# ServerDeck bootstrap installer.
#
# Fetches the latest stable Linux x86_64 release, verifies its SHA-256
# checksum, and hands off to the signed-release installer inside the archive.
#
# Usage:
#   curl -fsSL https://serverdeck.black.ax/install.sh | sh
#   curl -fsSL https://serverdeck.black.ax/install.sh | sh -s -- --workloads docker
#
set -eu

REPO="onjoakimsmind/serverdeck"
RELEASES_URL="https://github.com/${REPO}/releases"
LATEST_URL="${RELEASES_URL}/latest"
SUDO=""
TMP_DIR=""
ARCHIVE=""
RELEASE_DIR=""
INSTALLER=""

if [ -t 1 ]; then
	CYAN=$(printf '\033[36m')
	GREEN=$(printf '\033[32m')
	YELLOW=$(printf '\033[33m')
	RED=$(printf '\033[31m')
	DIM=$(printf '\033[2m')
	BOLD=$(printf '\033[1m')
	RESET=$(printf '\033[0m')
else
	CYAN=""
	GREEN=""
	YELLOW=""
	RED=""
	DIM=""
	BOLD=""
	RESET=""
fi

info() {
	printf '%s==>%s %s\n' "$CYAN" "$RESET" "$*"
}

ok() {
	printf '%s  ok%s %s\n' "$GREEN" "$RESET" "$*"
}

warn() {
	printf '%s  !%s  %s\n' "$YELLOW" "$RESET" "$*" >&2
}

fail() {
	printf '\n%sError:%s %s\n' "$RED" "$RESET" "$*" >&2
	exit 1
}

cleanup() {
	if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
		rm -rf "$TMP_DIR"
	fi
}

trap cleanup EXIT HUP INT TERM

# [ -r /dev/tty ] can be true even when the process has no controlling
# terminal (for example under `incus exec`, some CI runners, or detached
# automation), so actually try to open it rather than trusting the stat bit.
has_tty() {
	(exec 3<"/dev/tty") 2>/dev/null
}

printf '\n%sServerDeck installer%s\n' "$BOLD" "$RESET"
printf '%sA control deck for the Linux host you already have.%s\n\n' "$DIM" "$RESET"

case "$(uname -s 2>/dev/null):$(uname -m 2>/dev/null)" in
	Linux:x86_64) ;;
	Linux:*)
		fail "ServerDeck currently supports x86_64 Linux only. This host reports $(uname -m 2>/dev/null)."
		;;
	*)
		fail "ServerDeck requires Linux with systemd. This host reports $(uname -s 2>/dev/null)."
		;;
esac

for command in curl tar sha256sum mktemp; do
	if ! command -v "$command" >/dev/null 2>&1; then
		fail "Required command not found: $command"
	fi
done

# Check privilege before the long download, and never let sudo consume the
# remainder of a script that is being piped into sh.
if [ "$(id -u)" -ne 0 ]; then
	if ! command -v sudo >/dev/null 2>&1; then
		fail "Root access is required. Install sudo or run this installer as root."
	fi

	if has_tty; then
		sudo -v </dev/tty || fail "Root access is required to install ServerDeck."
	else
		sudo -n true 2>/dev/null || fail "Root access is required. Run with sudo or from a root shell."
	fi

	SUDO="sudo"
fi

info "Resolving the latest release"
LATEST_EFFECTIVE=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$LATEST_URL" 2>/dev/null) ||
	fail "Could not reach GitHub to resolve the latest ServerDeck release."

TAG=${LATEST_EFFECTIVE##*/}
TAG=${TAG%%\?*}
case "$TAG" in
	v[0-9]*)
		;;
	*)
		fail "Could not determine the latest release tag (got '${TAG:-nothing}')."
		;;
esac

case "$TAG" in
	*[!A-Za-z0-9._-]*)
		fail "The latest release tag contains unsupported characters: $TAG"
		;;
esac

VERSION=${TAG#v}
case "$VERSION" in
	""|*[!A-Za-z0-9._-]*)
		fail "The latest release version is invalid: ${VERSION:-empty}"
		;;
esac

ASSET="serverdeck-${VERSION}-linux-x86_64.tar.gz"
ARCHIVE_URL="${RELEASES_URL}/download/${TAG}/${ASSET}"
CHECKSUM_URL="${ARCHIVE_URL}.sha256"
ok "Latest release: ${TAG}"

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/serverdeck-install.XXXXXX")
ARCHIVE="${TMP_DIR}/${ASSET}"

info "Downloading ${ASSET}"
curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 --progress-bar \
	-o "$ARCHIVE" "$ARCHIVE_URL" ||
	fail "Could not download ${ARCHIVE_URL}"

info "Verifying the release checksum"
curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 \
	-o "${ARCHIVE}.sha256" "$CHECKSUM_URL" ||
	fail "Could not download the release checksum."

(
	cd "$TMP_DIR"
	sha256sum -c "${ASSET}.sha256" >/dev/null
) || fail "Release checksum verification failed. Nothing was installed."
ok "SHA-256 verified"

info "Extracting the release"
tar -xzf "$ARCHIVE" -C "$TMP_DIR" ||
	fail "Could not extract the release archive."

RELEASE_DIR="${TMP_DIR}/serverdeck-${VERSION}-linux-x86_64"
INSTALLER="${RELEASE_DIR}/install.sh"

if [ ! -f "$INSTALLER" ]; then
	fail "The release archive does not contain the expected installer."
fi

info "Starting the ServerDeck installer"
printf '%sThe installer may ask for your sudo password and host package manager confirmation.%s\n\n' "$DIM" "$RESET"

# $SUDO is either empty (already root) or the literal string "sudo"; leaving
# it unquoted is intentional so an empty value contributes no argument at
# all, instead of being passed as a literal empty command name.
if has_tty; then
	$SUDO sh "$INSTALLER" "$@" </dev/tty
else
	$SUDO sh "$INSTALLER" "$@"
fi

printf '\n%sServerDeck is installed.%s\n' "$GREEN$BOLD" "$RESET"
printf 'Check it with %ssudo serverdeck status%s, or open the URL printed above.\n' "$BOLD" "$RESET"
