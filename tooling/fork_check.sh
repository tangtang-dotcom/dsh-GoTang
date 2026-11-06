#!/usr/bin/env bash
# 检查 fork 与上游的差异是否仍落在登记的边界内。
#
# 用法：tooling/fork_check.sh [upstream-ref]，默认 upstream/main。
# 退出码：0 = 只改了 fork 目录和登记过的钩子；1 = 出现未登记的路径（需要更新
# docs/maintenance/fork-layer.md，或把实现挪进 fork/）。
set -euo pipefail
cd "$(dirname "$0")/.."

upstream="${1:-upstream/main}"
git rev-parse --verify --quiet "$upstream" >/dev/null || {
  echo "找不到 $upstream，先 git fetch upstream" >&2
  exit 2
}

allowed_prefixes=(
  app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/fork/
  app/android/app/src/test/kotlin/io/github/ccch1mneyyy/dsh_app/fork/
  app/lib/fork/
  app/lib/l10n/
  app/test/
  docs/maintenance/fork-layer.md
  .github/workflows/build-apk.yml
  runtime/build-runtime.sh
  runtime/lib/rtbuild.py
  tooling/setup-toolchain.sh
  tooling/fork_check.sh
  THIRD_PARTY_NOTICES.md
)

allowed_files=(
  app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhoneCore.kt
  app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/runtime/RuntimeController.kt
  app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/runtime/RuntimePlugin.kt
  app/android/app/src/test/kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhoneToolSchemaTest.kt
  app/lib/ui/agents/header_agents.dart
  app/lib/ui/phone/phone_control_screen.dart
  app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhoneControl.kt
  app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhonePlugin.kt
  app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/phone/PhoneToolCatalog.kt
  app/android/app/src/test/kotlin/io/github/ccch1mneyyy/dsh_app/runtime/ProcessLaunchGuardTest.kt
  app/lib/ui/chat/chat_screen.dart
  app/lib/ui/chat/widgets/plus_panel.dart
  app/lib/ui/chat/widgets/assistant_message.dart
  app/lib/ui/chat/widgets/user_bubble.dart
  app/lib/ui/chat/secret_mask.dart
  app/lib/ui/chat/widgets/activity_strip.dart
  app/lib/ui/plugins/native/composer_capsules.dart
  app/lib/ui/plugins/native/native_composer_bar.dart
  app/lib/phone/phone_channel.dart
  app/lib/state/phone_state.dart
  app/lib/runtime/runtime_bridge.dart
  app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/notify/LiveActivity.kt
  app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/notify/LiveContent.kt
  app/android/app/src/main/kotlin/io/github/ccch1mneyyy/dsh_app/notify/XiaomiFocus.kt
  app/android/app/src/test/kotlin/io/github/ccch1mneyyy/dsh_app/notify/LiveContentTest.kt
)

unknown=()
while IFS= read -r file; do
  case "$file" in
    *.png|*.jpg|*.jpeg|*.webp) continue ;;
  esac
  ok=false
  for p in "${allowed_prefixes[@]}"; do
    [[ "$file" == "$p"* ]] && { ok=true; break; }
  done
  if [[ "$ok" == false ]]; then
    for f in "${allowed_files[@]}"; do
      [[ "$file" == "$f" ]] && { ok=true; break; }
    done
  fi
  [[ "$ok" == false ]] && unknown+=("$file")
done < <(git diff --name-only "$upstream"...HEAD)

if (( ${#unknown[@]} )); then
  printf '未登记的 fork 差异：\n' >&2
  printf '  %s\n' "${unknown[@]}" >&2
  exit 1
fi
echo "fork 边界检查通过：$(git diff --name-only "$upstream"...HEAD | wc -l) 个文件"
