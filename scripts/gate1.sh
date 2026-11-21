#!/bin/bash
# Gate 1, the file: the configure line has no --enable-chromaprint, --enable-libzvbi, --enable-gpl or --enable-nonfree
# (and has --disable-chromaprint, --disable-libzvbi, --enable-version3); outside the configure line the binary has no
# "fftw", "chromaprint" or "zvbi" anywhere (any case); FFmpeg's embedded licence string is the LGPL. Records the SHA-256.
#   gate1.sh <ffmpeg.exe> <out folder>
set -euo pipefail
EXE="$1"; OUT="$2"; mkdir -p "$OUT"
sha256sum "$EXE" | tee "$OUT/ffmpeg.exe.sha256"
CONF=$(strings -n 20 "$EXE" | grep -m1 -- '--prefix=/ffbuild/prefix' || true)
echo "$CONF" > "$OUT/configure.txt"
echo "configure: $CONF"
test -n "$CONF"
for bad in --enable-chromaprint --enable-libzvbi --enable-gpl --enable-nonfree; do
  if echo " $CONF " | grep -q -- " $bad "; then echo "GATE 1 FAILED: the configure line has $bad"; exit 1; fi
done
for good in --disable-chromaprint --disable-libzvbi --enable-version3; do
  echo " $CONF " | grep -q -- " $good " || { echo "GATE 1 FAILED: the configure line lacks $good"; exit 1; }
done
HITS=$(strings -n 4 "$EXE" | grep -v -- '--prefix=/ffbuild/prefix' | grep -i -E 'fftw|chromaprint|zvbi' || true)
if [ -n "$HITS" ]; then echo "GATE 1 FAILED: the binary still contains:"; echo "$HITS" | head -40; exit 1; fi
strings -n 8 "$EXE" | grep -m1 -i 'lesser general public license' | tee "$OUT/license.txt" || true
grep -qi 'lesser general public license' "$OUT/license.txt" || { echo "GATE 1 FAILED: no LGPL licence string"; exit 1; }
if strings -n 8 "$EXE" | grep -qi 'This version of ffmpeg has nonfree\|libavcodec license: GPL\|GNU General Public License version 3 or later\b'; then
  echo "GATE 1 FAILED: a GPL or nonfree licence string"; exit 1
fi
echo "GATE 1 PASSED" | tee "$OUT/gate1.txt"
