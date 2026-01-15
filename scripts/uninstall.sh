#!/usr/bin/env bash
set -euo pipefail

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

main() {
  local target
  target="$(command -v nosleep || true)"
  if [[ -z "$target" ]]; then
    target="$(get_install_dir)/nosleep"
  fi

  if [[ ! -e "$target" ]]; then
    echo "ℹ️  未找到已安装的 nosleep"
    exit 0
  fi

  if need_sudo "$target"; then
    sudo rm -f "$target"
  else
    rm -f "$target"
  fi

  echo "✅ 已卸载 nosleep"
}

main "$@"
