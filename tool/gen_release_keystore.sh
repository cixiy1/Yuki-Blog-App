#!/usr/bin/env bash
# 依据 android/key.properties 生成固定签名密钥库（默认 android/release.jks）。
#
# 用法：
#   cp android/key.properties.example android/key.properties   # 先把参数填好
#   bash tool/gen_release_keystore.sh
#
# 已存在密钥库时不覆盖；只有显式加 --force 才重新生成。
# 注意：重新生成等于换签名，所有已安装的用户都必须卸载重装。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROPS="$ROOT/android/key.properties"

if [[ ! -f "$PROPS" ]]; then
  echo "✗ 缺少 android/key.properties"
  echo "  先执行： cp android/key.properties.example android/key.properties   然后填好参数"
  exit 1
fi

read_prop() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$PROPS" | tail -1; }

STORE_PASSWORD="$(read_prop storePassword)"
KEY_PASSWORD="$(read_prop keyPassword)"
KEY_ALIAS="$(read_prop keyAlias)"
STORE_FILE="$(read_prop storeFile)"
DNAME="$(read_prop dname)"
VALIDITY_DAYS="$(read_prop validityDays)"

missing=0
for pair in \
  "storePassword:$STORE_PASSWORD" \
  "keyPassword:$KEY_PASSWORD" \
  "keyAlias:$KEY_ALIAS" \
  "storeFile:$STORE_FILE" \
  "dname:$DNAME" \
  "validityDays:$VALIDITY_DAYS"; do
  name="${pair%%:*}"
  val="${pair#*:}"
  if [[ -z "$val" || "$val" == *"<"* ]]; then
    echo "✗ $name 还没填（当前：${val:-空}）"
    missing=1
  fi
done
if [[ $missing -ne 0 ]]; then
  echo "→ 请先把 android/key.properties 里的每一项都填好"
  exit 1
fi

KEYSTORE="$ROOT/android/$STORE_FILE"

if [[ -f "$KEYSTORE" && "${1:-}" != "--force" ]]; then
  echo "• 已存在 $KEYSTORE，未覆盖（确实要重新生成再加 --force）"
else
  rm -f "$KEYSTORE"
  keytool -genkeypair -v \
    -keystore "$KEYSTORE" \
    -storetype PKCS12 \
    -keyalg RSA -keysize 2048 \
    -validity "$VALIDITY_DAYS" \
    -alias "$KEY_ALIAS" \
    -storepass "$STORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -dname "$DNAME"
  echo "✓ 已生成 $KEYSTORE"
fi

echo
echo "── 签名证书指纹（以后核对发版包用这个）──"
keytool -list -v -keystore "$KEYSTORE" -storepass "$STORE_PASSWORD" -alias "$KEY_ALIAS" \
  | grep -iE "alias name|别名|SHA256:|SHA-256:" || true
echo
echo "下一步： bash tool/make_signing_secrets.sh  （生成 GitHub Secrets 需要的 base64）"
