#!/usr/bin/env bash
# 把 android/release.jks 与 android/key.properties 转成 GitHub Actions Secrets 需要的 base64，
# 并在仓库外留一份备份。
#
# 用法： bash tool/make_signing_secrets.sh
#
# 生成后需要你在 GitHub 网页上新建两个 secret（路径：仓库 → Settings → Secrets and variables → Actions）：
#   ANDROID_KEYSTORE_BASE64         ← secret-ANDROID_KEYSTORE_BASE64.txt 的内容
#   ANDROID_KEY_PROPERTIES_BASE64   ← secret-ANDROID_KEY_PROPERTIES_BASE64.txt 的内容
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYSTORE="$ROOT/android/release.jks"
PROPS="$ROOT/android/key.properties"

if [[ ! -f "$KEYSTORE" || ! -f "$PROPS" ]]; then
  echo "✗ 还没生成密钥库。先执行： bash tool/gen_release_keystore.sh"
  exit 1
fi

# 仓库外备份落点：文稿/Yuki/signing-2615（放这里方便随个人文档一起备份）
OUT="${HOME}/Documents/Yuki/signing-2615"
mkdir -p "$OUT"

# 仓库外备份：密钥库丢了就再也无法覆盖升级，务必另存到网盘/U 盘
cp -f "$KEYSTORE" "$OUT/release.jks"
cp -f "$PROPS" "$OUT/key.properties"

base64 < "$KEYSTORE" | tr -d '\n' > "$OUT/secret-ANDROID_KEYSTORE_BASE64.txt"
base64 < "$PROPS" | tr -d '\n' > "$OUT/secret-ANDROID_KEY_PROPERTIES_BASE64.txt"

echo "✓ 已写出以下文件："
echo "   $OUT/release.jks                                ← 密钥库备份（务必另存一份）"
echo "   $OUT/key.properties                             ← 口令备份"
echo "   $OUT/secret-ANDROID_KEYSTORE_BASE64.txt          → GitHub secret：ANDROID_KEYSTORE_BASE64"
echo "   $OUT/secret-ANDROID_KEY_PROPERTIES_BASE64.txt    → GitHub secret：ANDROID_KEY_PROPERTIES_BASE64"
echo
echo "把两个 txt 的内容整段复制到 GitHub 仓库的 Actions secrets 里即可。"
echo "未配置前，CI 构建会回退为 debug 签名（每个 runner 签名都不同，用户无法覆盖安装）。"
