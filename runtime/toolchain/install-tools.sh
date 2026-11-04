#!/bin/sh
# 可选逆向工具包：JDK、jadx、apktool、radare2、binutils。
#
# 由 App 的「设置 → 手机操控 → 进阶 → 逆向工具」通过 PRoot 调用：
#
#     /bin/sh /opt/dsh-app/install-tools.sh
#
# 为什么最终产物放在 /root/opt：/usr 属于运行时镜像，App 一更新就回到出厂；/root
# 会被带到新运行时。/opt/dsh-app/install-tools.sh 本身随镜像更新，所以这里保持
# “工具落在 /root，脚本随 App 升级”的分工。
#
# 脚本不读任何调用方输入，只按下面的固定清单安装；重复执行是安全的。
# 详细日志在 /root/toolchain-install.log。
set -u

LOG=/root/toolchain-install.log
OPT=/root/opt
TOOLS=/root/tools
CACHE=/root/.cache/dsh-tools

JADX_VERSION=1.5.6
JADX_SHA256=545ea2be9c242511bc145755cf4bda2485ade42966e096f8b4d3da2a230e8974
APKTOOL_VERSION=3.0.3
APKTOOL_SHA256=dbf930b076c6b9be08d57c449cacefc3bdd6b71ebd59b3066fc0e1f5b14f9423

log() { echo "[$(date +%H:%M:%S)] $*" >>"$LOG"; }
say() { log "$*"; echo "$*"; }
die() { say "失败：$*"; exit 1; }

: >"$LOG"
say "开始检查逆向工具…"
mkdir -p "$OPT/bin" "$OPT/lib" "$TOOLS" "$CACHE" /usr/share/man/man1 || die "创建目录失败"

export DEBIAN_FRONTEND=noninteractive

# ── 1. 系统包（JDK、binutils、radare2 及下载/解压工具）──────────────────
say "安装系统包（apt，需要联网；已装过会很快）…"
apt-get update -qq >>"$LOG" 2>&1 || say "apt-get update 失败，继续尝试用现有索引"
apt-get install -y -qq --no-install-recommends \
    openjdk-17-jre-headless binutils radare2 patchelf file xxd unzip zip curl ca-certificates \
    >>"$LOG" 2>&1 || die "apt 安装失败，详见 $LOG"

for c in java objdump r2 curl unzip; do
    command -v "$c" >/dev/null 2>&1 || die "缺少 $c（apt 没有装上），详见 $LOG"
done

# ── 2. JDK：复制到 /root/opt/jdk，App 更新后仍然可用 ────────────────────
if [ ! -x "$OPT/jdk/bin/java" ]; then
    JDK_DIR=$(ls -d /usr/lib/jvm/java-17-openjdk-* 2>/dev/null | head -1)
    [ -n "$JDK_DIR" ] || die "找不到 java-17-openjdk 目录"
    say "复制 JDK（约 190 MB，只需一次）…"
    cp -a "$JDK_DIR" "$OPT/jdk" >>"$LOG" 2>&1 || die "复制 JDK 失败"
fi
[ -x "$OPT/jdk/bin/java" ] || die "JDK 复制后仍不可执行"

# ── 3. 下载并校验 jadx / apktool（完整包，不依赖 /sdcard）───────────────
fetch() {  # $1=url $2=dest $3=sha256
    curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 -sS -o "$2.part" "$1" >>"$LOG" 2>&1 \
        || { say "下载失败：$1"; return 1; }
    echo "$3  $2.part" | sha256sum -c - >>"$LOG" 2>&1 \
        || { rm -f "$2.part"; say "校验失败：$1"; return 1; }
    mv "$2.part" "$2"
}

JADX_ZIP="$CACHE/jadx-$JADX_VERSION.zip"
if [ ! -x "$TOOLS/jadx/bin/jadx" ]; then
    say "下载 jadx $JADX_VERSION…"
    fetch "https://github.com/skylot/jadx/releases/download/v$JADX_VERSION/jadx-$JADX_VERSION.zip" \
        "$JADX_ZIP" "$JADX_SHA256" || die "jadx 下载失败"
    rm -rf "$TOOLS/jadx"
    mkdir -p "$TOOLS/jadx"
    unzip -q -o "$JADX_ZIP" -d "$TOOLS/jadx" >>"$LOG" 2>&1 || die "jadx 解压失败"
fi
[ -f "$TOOLS/jadx/lib/jadx-$JADX_VERSION-all.jar" ] || die "jadx 解压后缺少 jadx-$JADX_VERSION-all.jar"

APKTOOL_JAR="$TOOLS/apktool.jar"
if [ ! -f "$APKTOOL_JAR" ]; then
    say "下载 apktool $APKTOOL_VERSION…"
    fetch "https://github.com/iBotPeaches/Apktool/releases/download/v$APKTOOL_VERSION/apktool_$APKTOOL_VERSION.jar" \
        "$APKTOOL_JAR" "$APKTOOL_SHA256" || die "apktool 下载失败"
fi

# ── 4. 命令包装（都用 /root/opt/jdk，不碰系统 Java）────────────────────
cat >"$OPT/bin/jadx" <<EOF
#!/bin/sh
exec "$OPT/jdk/bin/java" -cp "$TOOLS/jadx/lib/jadx-$JADX_VERSION-all.jar" jadx.cli.JadxCLI "\$@"
EOF
cat >"$OPT/bin/apktool" <<EOF
#!/bin/sh
exec "$OPT/jdk/bin/java" -jar "$APKTOOL_JAR" "\$@"
EOF
chmod +x "$OPT/bin/jadx" "$OPT/bin/apktool" || die "写入包装脚本失败"

# ── 5. radare2 / binutils：连同依赖库复制到 /root/opt ───────────────────
say "复制 radare2 / binutils…"
for b in r2 rabin2 rax2 ras2 rasm2 ragg2 objdump readelf nm strings objcopy ar size addr2line c++filt patchelf file xxd; do
    [ -x "/usr/bin/$b" ] && cp -f "/usr/bin/$b" "$OPT/bin/$b" >>"$LOG" 2>&1
done

# 依赖库：glibc 永远在镜像里，其余复制一份（升级后系统库版本可能变）。
for b in "$OPT"/bin/*; do ldd "$b" 2>/dev/null; done | awk '{print $3}' | grep '^/' | sort -u \
    | grep -vE '/(libc|libm|libpthread|libdl|librt|libresolv|libutil)\.so|ld-linux' \
    | while read -r lib; do
        [ -f "$OPT/lib/$(basename "$lib")" ] || cp -f "$lib" "$OPT/lib/" >>"$LOG" 2>&1
    done

R2PLUG=$(ls -d /usr/lib/*/radare2/* 2>/dev/null | head -1)
if [ -n "${R2PLUG:-}" ] && [ -d "$R2PLUG" ]; then
    mkdir -p "$OPT/r2/$(basename "$R2PLUG")"
    cp -a "$R2PLUG/." "$OPT/r2/$(basename "$R2PLUG")/" >>"$LOG" 2>&1
fi

# ── 6. 环境与自检 ───────────────────────────────────────────────────
cat >/root/env.sh <<'EOF'
# 逆向工具链（装在 /root，App 更新不会被清）
export JAVA_HOME=/root/opt/jdk
export R2_PREFIX=/root/opt
export PATH=/root/opt/bin:/root/tools/jadx/bin:$PATH
export LD_LIBRARY_PATH=/root/opt/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
EOF
grep -q 'env.sh' /root/.bashrc 2>/dev/null || echo '[ -f /root/env.sh ] && . /root/env.sh' >>/root/.bashrc

ok=1
for t in "$OPT/jdk/bin/java" "$OPT/bin/jadx" "$OPT/bin/apktool" "$OPT/bin/r2" "$OPT/bin/objdump"; do
    [ -x "$t" ] || { say "缺失：$t"; ok=0; }
done
if [ "$ok" = 1 ]; then
    touch "$OPT/.installed"
    say "完成：java / jadx / apktool / r2 / binutils 已就绪，source /root/env.sh 即可使用"
else
    die "部分工具没有装好，详见 $LOG"
fi
