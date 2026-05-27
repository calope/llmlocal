#!/usr/bin/env bash
# Bench comparativo de N modelos. Ejecuta bench-extended.sh para cada uno y muestra
# tabla final. Uso: ./bench-compare.sh modelo1 modelo2 [modelo3 ...]
set -euo pipefail

[ $# -ge 2 ] || { echo "Uso: $0 modelo1 modelo2 [modelo3 ...]"; exit 1; }

DIR="$(dirname "$0")"
TMP=$(mktemp -d); trap 'rm -rf $TMP' EXIT

echo
echo "=== Bench comparativo (${#@} modelos, 3 iters cada uno) ==="
echo

declare -A AVG MIN MAX TTFT
for m in "$@"; do
  echo "--- $m ---"
  out=$("$DIR/bench-extended.sh" "$m" 3 2>&1 | tee "$TMP/$(echo "$m" | tr ':/' '_').log")
  AVG[$m]=$(echo "$out"   | awk '/Resumen eval/{f=1;next} f && /media=/{ match($0,/media=([0-9.]+)/,a); print a[1]; exit }')
  MIN[$m]=$(echo "$out"   | awk '/Resumen eval/{f=1;next} f && /min=/{ match($0,/min=([0-9.]+)/,a); print a[1]; exit }')
  MAX[$m]=$(echo "$out"   | awk '/Resumen eval/{f=1;next} f && /max=/{ match($0,/max=([0-9.]+)/,a); print a[1]; exit }')
  TTFT[$m]=$(echo "$out"  | awk '/Resumen TTFT/{f=1;next} f && /media=/{ match($0,/media=([0-9.]+)/,a); print a[1]; exit }')
  echo
done

echo
printf "%-55s %10s %10s %10s %10s\n" "MODELO" "AVG_TOKS" "MIN_TOKS" "MAX_TOKS" "TTFT_S"
printf "%-55s %10s %10s %10s %10s\n" "------" "--------" "--------" "--------" "------"
for m in "$@"; do
  printf "%-55s %10s %10s %10s %10s\n" "$m" "${AVG[$m]:-?}" "${MIN[$m]:-?}" "${MAX[$m]:-?}" "${TTFT[$m]:-?}"
done
