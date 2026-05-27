#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Why Awake"
PROJECT_FILE="Why Awake.xcodeproj"
SCHEME="Why Awake"
DERIVED_DATA="/private/tmp/whyawake-run-dd"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
}

case "$MODE" in
  run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify)
    ;;
  *)
    usage
    exit 2
    ;;
esac

xcodebuild \
  -project "$ROOT_DIR/$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

is_built_app_pid() {
  local pid="$1"
  local command
  command="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
  case "$command" in
    "$APP_BINARY"*) return 0 ;;
    *) return 1 ;;
  esac
}

stop_built_app() {
  local pid
  local stopped=0
  while read -r pid; do
    if is_built_app_pid "$pid"; then
      /bin/kill "$pid" >/dev/null 2>&1 || true
      stopped=1
    fi
  done < <(/usr/bin/pgrep -x "$APP_NAME" 2>/dev/null || true)

  if [[ "$stopped" == "1" ]]; then
    for _ in {1..30}; do
      if ! built_app_is_running; then
        return 0
      fi
      sleep 0.1
    done
  fi
}

built_app_is_running() {
  local pid
  while read -r pid; do
    if is_built_app_pid "$pid"; then
      return 0
    fi
  done < <(/usr/bin/pgrep -x "$APP_NAME" 2>/dev/null || true)
  return 1
}

wait_for_built_app_running() {
  for _ in {1..50}; do
    if built_app_is_running; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

open_app() {
  stop_built_app
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    stop_built_app
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --verify|verify)
    open_app
    wait_for_built_app_running
    ;;
  *)
    usage
    exit 2
    ;;
esac
