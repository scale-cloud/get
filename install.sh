#!/bin/sh
# Install the Scale CLI.
#   curl -fsSL https://raw.githubusercontent.com/scale-cloud/get/main/install.sh | sh
set -eu

release_base="https://github.com/scale-cloud/get/releases/latest/download"

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

command -v curl >/dev/null 2>&1 || die "curl is required to run this installer."

missing=""
command -v docker >/dev/null 2>&1 || missing="Docker"
command -v terraform >/dev/null 2>&1 || missing="${missing:+$missing and }Terraform"
if [ -n "$missing" ]; then
    die "$missing is required but was not found on PATH."
fi

printf "Docker and Terraform are in path ✅\n"

# /releases/latest/download redirects to /releases/download/<version>/...
location=$(curl -s -o /dev/null -w '%{redirect_url}' "${release_base}/scale-lib-linux-amd64.tar.gz")
version=$(printf '%s\n' "$location" | sed -n 's|.*/releases/download/\([^/]*\)/.*|\1|p')
if [ -z "$version" ]; then
    die "could not determine the latest Scale release"
fi
printf 'Installing Scale %s...\n\n' "$version"

os=$(uname -s)
machine=$(uname -m)
case "$machine" in
    x86_64 | amd64) arch="x86_64" ;;
    aarch64 | arm64) arch="aarch64" ;;
    *) die "unsupported architecture: $machine" ;;
esac

case "$os" in
    Linux)
        libc="gnu"
        if [ -f /etc/alpine-release ] || ldd --version 2>&1 | grep -qi musl; then
            libc="musl"
        fi
        triple="${arch}-unknown-linux-${libc}"
        ;;
    Darwin)
        triple="${arch}-apple-darwin"
        ;;
    *)
        die "unsupported operating system: $os. If you are on Windows, run install.pwsh instead."
        ;;
esac

bindir="${HOME}/.local/bin"
mkdir -p "$bindir"
tmp="${bindir}/scale.tmp.$$"
trap 'rm -f "$tmp"' EXIT
curl -fL --retry 3 -o "$tmp" "${release_base}/scale-${triple}"
mv "$tmp" "${bindir}/scale"
chmod +x "${bindir}/scale"
trap - EXIT

lib_dir="${HOME}/.scale/lib"
mkdir -p "$lib_dir"
gz="${lib_dir}/scale-lib-linux-amd64.tar.gz"
tar_path="${lib_dir}/scale-lib-linux-amd64.tar"
curl -fL --retry 3 -o "$gz" "${release_base}/scale-lib-linux-amd64.tar.gz"
gzip -dc "$gz" >"$tar_path"
rm -f "$gz"

printf "\n"
case ":${PATH}:" in
    *":${bindir}:"*) ;;
    *)
        path_line='export PATH="$HOME/.local/bin:$PATH"'
        shell_name=$(basename "${SHELL:-sh}")
        case "$shell_name" in
            zsh) rc="${HOME}/.zshrc" ;;
            bash) rc="${HOME}/.bashrc" ;;
            *) rc="${HOME}/.profile" ;;
        esac
        if [ ! -f "$rc" ] || ! grep -q 'HOME/.local/bin' "$rc"; then
            printf '\n# Added by the Scale installer\n%s\n' "$path_line" >>"$rc"
        fi
        printf 'Added %s to PATH in %s. Open a new terminal to use Scale.\n' "$bindir" "$rc"
        ;;
esac

printf 'Scale %s installed successfully! ✅\n' "$version"
