#!/usr/bin/env bash
set -euo pipefail

REPO="ThinkPeace/NoSleep"

get_install_dir() {
  if [[ -d "/opt/homebrew/bin" ]]; then
    echo "/opt/homebrew/bin"
  else
    echo "/usr/local/bin"
  fi
}

need_sudo() {
  local target="$1"
  [[ ! -w "$(dirname "$target")" ]]
}

latest_release_json() {
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest"
}

extract_asset_url() {
  local json="$1"
  local name="$2"
  echo "$json" | grep -Eo 'https://[^\"]+' | grep "/${name}$" | head -n1
}

get_latest_version() {
  local json="$1"
  echo "$json" | grep -m1 '"tag_name"' | sed -E 's/.*"v?([^\"]+)".*/\1/'
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

main() {
  echo "⬇️  正在下载 nosleep..."

  local json
  json="$(latest_release_json)"
  local version
  version="$(get_latest_version "$json")"
  if [[ -z "$version" ]]; then
    echo "❌ 无法解析最新版本"
    exit 2
  fi

  local asset_name="nosleep-${version}"
  local sha_name="nosleep-${version}.sha256"
  local asset_url
  local sha_url
  asset_url="$(extract_asset_url "$json" "$asset_name")"
  sha_url="$(extract_asset_url "$json" "$sha_name")"
  if [[ -z "$asset_url" || -z "$sha_url" ]]; then
    echo "❌ 未找到发布资产，请检查 Release"
    exit 2
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  curl -fsSL -o "$tmpdir/$asset_name" "$asset_url"
  curl -fsSL -o "$tmpdir/$sha_name" "$sha_url"

  local expected
  expected="$(awk '{print $1}' "$tmpdir/$sha_name")"
  local actual
  actual="$(sha256_file "$tmpdir/$asset_name")"
  if [[ "$expected" != "$actual" ]]; then
    echo "❌ 校验失败，已中止安装"
    exit 3
  fi

  local target
  target="$(get_install_dir)/nosleep"

  if need_sudo "$target"; then
    sudo install -m 755 "$tmpdir/$asset_name" "$target"
  else
    install -m 755 "$tmpdir/$asset_name" "$target"
  fi

  echo "✅ 安装成功！输入 'nosleep --help' 查看用法。"
}

main "$@"
