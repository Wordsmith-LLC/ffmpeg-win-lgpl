#!/bin/bash
# Changes FFmpeg-Builds (checked out at FFB_COMMIT in the current folder) in exactly these ways, and checks each one:
#   1. the stages 25-fftw3, 50-chromaprint and 50-zvbi report "not enabled", so their own unconfigure flags give
#      FFmpeg --disable-chromaprint and --disable-libzvbi (FFTW came in only through Chromaprint);
#   2. FFmpeg is checked out at FFMPEG_COMMIT (build.sh clones master) with the extra version 20260824;
#   3. no builder cache is written (the default writes every intermediate layer to .cache/, tens of GB) and only the
#      final image is exported to Docker (the cross compiler image is not), see makeimage-lgpl.sh.
set -euo pipefail
test "$(git rev-parse HEAD)" = "$FFB_COMMIT"
for s in scripts.d/25-fftw3.sh scripts.d/50-chromaprint.sh scripts.d/50-zvbi.sh; do
  sed -i 's/^ffbuild_enabled() {$/ffbuild_enabled() {\n    return -1 # LGPL-only build: left out (GPL parts)/' "$s"
  grep -n -A1 '^ffbuild_enabled() {' "$s"
  grep -q 'return -1 # LGPL-only build' "$s"
done
sed -i "s|^    cd ffmpeg\$|    cd ffmpeg\n    git checkout $FFMPEG_COMMIT|" build.sh
sed -i 's|--extra-version="\\$(date +%Y%m%d)"|--extra-version="20260824"|' build.sh
grep -n "git checkout $FFMPEG_COMMIT" build.sh
grep -n -- '--extra-version="20260824"' build.sh
python3 - <<'PY'
s = open('makeimage.sh').read()
n = 0
for line in ['cache-from = ["type=local,src=.cache/%s"]', 'cache-to   = ["type=local,mode=max,dest=.cache/%s"]']:
    count = s.count(line)
    assert count == 3, (line, count)
    out = []
    for l in s.split('\n'):
        if line in l:
            n += 1
            continue
        out.append(l)
    s = '\n'.join(out)
tail = './download.sh\n./generate.sh "$TARGET" "$VARIANT" "${ADDINS[@]}"\n\nbake_images "${BAKE_TARGETS[@]}"'
assert tail in s, 'makeimage.sh tail not found'
s = s.replace(tail, './download.sh\n./generate.sh "$TARGET" "$VARIANT" "${ADDINS[@]}"\n\nbake_images image')
open('makeimage-lgpl.sh', 'w').write(s)
print('makeimage-lgpl.sh: %d cache lines removed; only the image target is exported' % n)
PY
chmod +x makeimage-lgpl.sh
if grep -n 'cache-' makeimage-lgpl.sh; then echo "builder cache lines are left"; exit 1; fi
grep -n '^bake_images' makeimage-lgpl.sh
