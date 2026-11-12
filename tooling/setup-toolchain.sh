#!/usr/bin/env bash
# Installs the Android build toolchain for dsh-app into $DEV_ROOT (user-level, no sudo):
# Temurin JDK 17, Flutter stable, Android SDK (cmdline-tools, platform, build-tools, NDK,
# emulator + x86_64 system image). Re-runnable: finished steps are skipped.
set -Eeuo pipefail

DEV_ROOT="${DEV_ROOT:-$HOME/dev}"
[[ $DEV_ROOT == /* ]] || DEV_ROOT="$PWD/$DEV_ROOT"
FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.7}"
FLUTTER_SHA256="${FLUTTER_SHA256:-af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230}"
CMDLINE_TOOLS_BUILD="${CMDLINE_TOOLS_BUILD:-13114758}"
SYSTEM_IMAGE="${SYSTEM_IMAGE:-system-images;android-35;google_apis;x86_64}"
# The emulator and its system image are for local device testing, not for building an APK:
# a CI runner that only packages one needs ~2 GB less disk. Set INSTALL_EMULATOR=1 to keep them.
INSTALL_EMULATOR="${INSTALL_EMULATOR:-1}"

JDK_DIR="$DEV_ROOT/jdk-17"
FLUTTER_DIR="$DEV_ROOT/flutter"
SDK_DIR="$DEV_ROOT/android-sdk"
DL="$DEV_ROOT/.downloads"
mkdir -p "$DEV_ROOT" "$DL"

log() { printf '[toolchain %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf '[toolchain %s] error: %s\n' "$(date +%H:%M:%S)" "$*" >&2; exit 1; }
# Any failure names itself, even when the command that failed says nothing (a bare exit 1
# from a subshell in the background left the CI logs with no clue at all).
trap 'rc=$?; printf "[toolchain %s] error: exit %s at %s:%s: %s\n" "$(date +%H:%M:%S)" "$rc" "${BASH_SOURCE[0]}" "$LINENO" "$BASH_COMMAND" >&2' ERR

download_cached() (
  local destination="$1" url="$2" pending_download
  if [ -f "$destination" ]; then return; fi
  pending_download=$(mktemp "$destination.part.XXXXXX")
  trap 'rm -f -- "$pending_download"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  curl -fL --retry 3 -o "$pending_download" "$url"
  mv -T -- "$pending_download" "$destination"
)

install_jdk() {
  if [ -x "$JDK_DIR/bin/java" ] && [ ! -f "$JDK_DIR/.dsh-toolchain-incomplete" ]; then log "JDK present"; return; fi
  local base="https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/linux/"
  local name
  name=$(curl -fsSL "$base" | grep -oE 'OpenJDK17U-jdk_x64_linux_hotspot_[0-9._]+\.tar\.gz' | sort -uV | tail -1)
  [ -n "$name" ] || { log "could not find JDK tarball"; return 1; }
  log "JDK: $name"
  curl -fL --retry 3 -o "$DL/$name" "$base$name"
  mkdir -p "$JDK_DIR"
  touch "$JDK_DIR/.dsh-toolchain-incomplete"
  tar -xzf "$DL/$name" -C "$JDK_DIR" --strip-components=1
  "$JDK_DIR/bin/java" -version
  rm -f "$JDK_DIR/.dsh-toolchain-incomplete"
}

install_flutter() {
  if [ -x "$FLUTTER_DIR/bin/flutter" ] && [ ! -f "$FLUTTER_DIR/.dsh-toolchain-incomplete" ]; then log "Flutter present"; return; fi
  local name="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  # The official host first (the CN mirror drops large transfers from time to time), then
  # the mirror. A failed attempt writes .part, so a half file never looks downloaded.
  local -a mirrors=(
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/$name"
    "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/linux/$name"
  )
  log "Flutter: $name"
  if [ ! -f "$DL/$name" ]; then
    local got=0 url
    for url in "${mirrors[@]}"; do
      if curl -fL --retry 5 --retry-all-errors --retry-delay 3 --connect-timeout 20 \
          -o "$DL/$name.part" "$url"; then
        mv "$DL/$name.part" "$DL/$name"; got=1; break
      fi
      rm -f "$DL/$name.part"
      log "Flutter download failed from one host; trying the next"
    done
    [ "$got" = 1 ] || die "could not download $name"
  fi
  echo "$FLUTTER_SHA256  $DL/$name" | sha256sum -c - || die "Flutter archive failed its checksum"
  df -h "$DEV_ROOT" | tail -1
  free -m | head -2
  mkdir -p "$FLUTTER_DIR"
  touch "$FLUTTER_DIR/.dsh-toolchain-incomplete"
  tar -xJf "$DL/$name" -C "$DEV_ROOT" || die "could not extract $name"
  [ -x "$FLUTTER_DIR/bin/flutter" ] || die "$name extracted without bin/flutter"
  rm -f "$FLUTTER_DIR/.dsh-toolchain-incomplete"
}

install_cmdline_tools() {
  if [ -x "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then log "cmdline-tools present"; return; fi
  local name="commandlinetools-linux-${CMDLINE_TOOLS_BUILD}_latest.zip"
  log "cmdline-tools: $name"
  download_cached "$DL/$name" "https://dl.google.com/android/repository/$name"
  rm -rf "$DL/cmdline-tools" && mkdir -p "$SDK_DIR/cmdline-tools"
  (cd "$DL" && unzip -q -o "$name")
  rm -rf "$SDK_DIR/cmdline-tools/latest"
  mv "$DL/cmdline-tools" "$SDK_DIR/cmdline-tools/latest"
}

install_jdk & p1=$!
install_flutter & p2=$!
install_cmdline_tools & p3=$!
install_status=0
for installer_pid in "$p1" "$p2" "$p3"; do
  wait "$installer_pid" || install_status=$?
done
((install_status == 0)) || exit "$install_status"

export JAVA_HOME="$JDK_DIR"
export ANDROID_HOME="$SDK_DIR" ANDROID_SDK_ROOT="$SDK_DIR"
export PATH="$JDK_DIR/bin:$FLUTTER_DIR/bin:$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools:$SDK_DIR/emulator:$PATH"
export PUB_HOSTED_URL="https://pub.flutter-io.cn" FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

# Versions Flutter's Gradle plugin defaults to (compileSdk / NDK). Where the source no
# longer spells them out, fall back to the pair this Flutter release is known to use; the
# Android Gradle plugin downloads whatever else the project asks for, once licensed.
GRADLE_DIR="$FLUTTER_DIR/packages/flutter_tools/gradle"
NDK_VERSION=$(grep -rhoE 'ndkVersion[^"]*"[0-9.]+"' "$GRADLE_DIR" 2>/dev/null \
  | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
COMPILE_SDK=$(grep -rhoE 'compileSdkVersion[^0-9]*[0-9]+' "$GRADLE_DIR" 2>/dev/null \
  | grep -oE '[0-9]+$' | head -1 || true)
NDK_VERSION="${NDK_VERSION:-28.2.13676358}"
COMPILE_SDK="${COMPILE_SDK:-36}"
log "Flutter defaults: compileSdk=$COMPILE_SDK ndk=$NDK_VERSION"

# Building the app requires accepting the Android SDK licenses.
yes | sdkmanager --sdk_root="$SDK_DIR" --licenses >/dev/null || true
SDK_PACKAGES=(
  "platform-tools" "platforms;android-${COMPILE_SDK}" "build-tools;${COMPILE_SDK}.0.0"
  "ndk;${NDK_VERSION}" "cmake;3.22.1"
)
if [[ "$INSTALL_EMULATOR" == 1 ]]; then
  SDK_PACKAGES+=("emulator" "$SYSTEM_IMAGE")
fi
sdkmanager --sdk_root="$SDK_DIR" "${SDK_PACKAGES[@]}"

flutter config --no-analytics --android-sdk "$SDK_DIR" --jdk-dir "$JDK_DIR" >/dev/null
flutter precache --android
yes | flutter doctor --android-licenses >/dev/null || true
flutter doctor -v || true

cat > "$(dirname "$0")/env.sh" <<EOF
# Source this to get the dsh-app toolchain on PATH.
export JAVA_HOME="$JDK_DIR"
export ANDROID_HOME="$SDK_DIR"
export ANDROID_SDK_ROOT="$SDK_DIR"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PATH="$JDK_DIR/bin:$FLUTTER_DIR/bin:$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools:$SDK_DIR/emulator:\$PATH"
EOF
log "done; source tooling/env.sh"
