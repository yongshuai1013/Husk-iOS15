#!/bin/bash
# extract_apex_for_java_runtime.sh <vda.qcow2|vda.raw> <output-apex-dir>
# 從 Lineage 鏡像提取 APEX，供 build_java_runtime.sh 使用
#
# 流程：
# 1. qcow2 -> raw（如果需要）
# 2. 解析 GPT，找到 super 分區，提取 system 分區 -> system.img
# 3. 用 debugfs 從 system.img 提取 /system/apex/*.capex
# 4. 解壓每個 .capex（ZIP -> apex_payload.img -> ext4）
# 5. 用 debugfs 從每個 apex_payload.img 提取文件到 output-apex-dir/<apex-name>/
#
# 需要：qemu-img, e2fsprogs (debugfs), python3
set -euo pipefail

IMG="${1:?usage: extract_apex_for_java_runtime.sh <vda.qcow2|vda.raw> <output-dir>}"
OUT="${2:?usage: extract_apex_for_java_runtime.sh <vda.qcow2|vda.raw> <output-dir>}"
DEBUGFS="$(command -v debugfs || echo /opt/homebrew/opt/e2fsprogs/sbin/debugfs)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> 準備工作目錄: $WORK"

# 1. 轉 raw
RAW="$IMG"
case "$IMG" in
  *.qcow2)
    echo "==> 轉換 qcow2 -> raw..."
    qemu-img convert -p -O raw "$IMG" "$WORK/vda.raw"
    RAW="$WORK/vda.raw"
    ;;
esac

# 2. 提取 system 分區
echo "==> 提取 system 分區..."
python3 - "$RAW" "$WORK" <<'EOF'
import struct, subprocess, sys
raw, work = sys.argv[1], sys.argv[2]
out = subprocess.run(['gpt', '-r', 'show', raw], capture_output=True, text=True).stdout
# 找 super 分區（通常是第 2 個 GPT 分區）
lines = [l for l in out.splitlines() if len(l.split()) >= 4]
start = None
for l in lines:
    parts = l.split()
    # GPT 分區表格式：start size index contents
    if len(parts) >= 4 and parts[2] == '2':
        start = int(parts[0])
        break
if start is None:
    # 備用：找第二個分區
    for l in lines:
        parts = l.split()
        if len(parts) >= 4 and parts[2].isdigit() and int(parts[2]) == 2:
            start = int(parts[0])
            break
if start is None:
    print("找不到 super 分區", file=sys.stderr)
    sys.exit(1)
base = start * 512
f = open(raw, 'rb')
f.seek(base + 12288); h = f.read(256)
magic, _, _, hsize = struct.unpack_from('<IHHI', h, 0)
assert magic == 0x414C5030, 'no logical partition metadata'
o = 12 + 32; tsize = struct.unpack_from('<I', h, o)[0]; o += 4 + 32
descs = [struct.unpack_from('<III', h, o + 12 * i) for i in range(4)]
f.seek(base + 12288 + hsize); T = f.read(tsize)
(po, pn, ps), (eo, en, es) = descs[0], descs[1]
ext = [struct.unpack_from('<QIQI', T, eo + es * i) for i in range(en)]
found = False
for i in range(pn):
    e = T[po + ps * i:po + ps * (i + 1)]
    name = e[:36].split(b'\0')[0].decode(); _, fi, ne, _ = struct.unpack_from('<IIII', e, 36)
    if name != 'system': continue
    found = True
    print(f"找到 system 分區: {ne} 個 extent", file=sys.stderr)
    with open(work + '/system.img', 'wb') as w:
        for j in range(fi, fi + ne):
            nsec, _, data, _ = ext[j]
            f.seek(base + data * 512); left = nsec * 512
            while left:
                b = f.read(min(left, 64 << 20)); w.write(b); left -= len(b)
    break
if not found:
    print("未找到 system 分區", file=sys.stderr)
    sys.exit(1)
print("system.img 提取完成", file=sys.stderr)
EOF

# 3. 從 system.img 提取 apex capex 文件
echo "==> 提取 APEX capex 文件..."
mkdir -p "$WORK/capex"
# 注意：i18n 是 .apex 不是 .capex，兩種都試
for apex in com.android.art com.android.i18n com.android.tzdata com.android.conscrypt; do
  for ext in capex apex; do
    echo "  - $apex.$ext"
    if "$DEBUGFS" -R "dump /system/apex/$apex.$ext $WORK/capex/$apex.$ext" "$WORK/system.img" 2>&1 | head -3; then
      if [ -f "$WORK/capex/$apex.$ext" ]; then
        echo "    (成功提取 $apex.$ext)"
        break
      fi
    fi
  done
  ls -lh "$WORK/capex/$apex".* 2>&1 | head -2 || echo "    (未找到 $apex)"
done

# 4. 解壓每個 capex/apex 並提取文件
echo "==> 解壓 APEX..."
mkdir -p "$OUT"
for capex in "$WORK"/capex/*.capex "$WORK"/capex/*.apex; do
  [ -f "$capex" ] || continue
  # 去掉 .capex 或 .apex 後綴
  name=$(basename "$capex" | sed 's/\.\(capex\|apex\)$//')
  echo "  - $name ($(basename "$capex"))"
  # capex 是 ZIP，內有 apex_payload.img（ext4）
  echo "    [debug] 檢查 capex 內容..."
  python3 - "$capex" "$WORK/$name.img" <<'EOF'
import sys, zipfile
capex, out = sys.argv[1], sys.argv[2]
z = zipfile.ZipFile(capex)
print(f"    [debug] capex 內文件: {z.namelist()[:5]}", file=sys.stderr)
# 有些 capex 嵌套了一層 original_apex
if 'original_apex' in z.namelist():
    print(f"    [debug] 發現嵌套 original_apex", file=sys.stderr)
    z = zipfile.ZipFile(z.open('original_apex'))
    print(f"    [debug] 內層文件: {z.namelist()[:5]}", file=sys.stderr)
if 'apex_payload.img' not in z.namelist():
    print(f"    [debug] ERROR: 找不到 apex_payload.img!", file=sys.stderr)
    sys.exit(1)
data = z.read('apex_payload.img')
print(f"    [debug] apex_payload.img 大小: {len(data)} bytes", file=sys.stderr)
open(out, 'wb').write(data)
EOF
  if [ $? -ne 0 ]; then
    echo "    [debug] Python 解壓失敗，跳過 $name"
    continue
  fi
  # 用 debugfs 提取整個 img 到 OUT/<name>/
  mkdir -p "$OUT/$name"
  echo "    [debug] 執行 debugfs rdump..."
  "$DEBUGFS" -R "rdump / $OUT/$name" "$WORK/$name.img" 2>&1 | head -5 || echo "    (rdump 失敗)"
  echo "    [debug] rdump 完成，檢查輸出:"
  ls "$OUT/$name" 2>&1 | head -5 || echo "    (輸出為空)"
done

# 5. 還需要 system/framework/org.apache.http.legacy.jar 和 framework-res.apk
echo "==> 提取 framework 文件..."
mkdir -p "$OUT/framework"
"$DEBUGFS" -R "dump /system/framework/org.apache.http.legacy.jar $OUT/framework/org.apache.http.legacy.jar" "$WORK/system.img" 2>/dev/null || echo "  (未找到 org.apache.http.legacy.jar)"
"$DEBUGFS" -R "dump /system/framework/framework-res.apk $OUT/framework/framework-res.apk" "$WORK/system.img" 2>/dev/null || echo "  (未找到 framework-res.apk)"

echo "==> 完成: $OUT"
ls -la "$OUT" || true
du -sh "$OUT" || true
