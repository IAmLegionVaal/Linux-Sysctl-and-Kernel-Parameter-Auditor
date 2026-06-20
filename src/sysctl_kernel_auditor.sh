#!/usr/bin/env bash
set -u
OUTPUT_DIR=""
usage(){ echo "Usage: sysctl_kernel_auditor.sh [--output DIR]"; }
while [[ $# -gt 0 ]]; do case "$1" in --output) OUTPUT_DIR="${2:-}"; shift 2;; -h|--help) usage; exit 0;; *) echo "Unknown argument: $1" >&2; exit 2;; esac; done
STAMP=$(date +%Y%m%d_%H%M%S); OUTPUT_DIR="${OUTPUT_DIR:-./sysctl-audit-$STAMP}"; mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/sysctl-audit.txt"; CSV="$OUTPUT_DIR/findings.csv"; JSON="$OUTPUT_DIR/summary.json"; ERRORS="$OUTPUT_DIR/command-errors.log"; :>"$REPORT"; :>"$ERRORS"
echo 'parameter,expected,actual,status' > "$CSV"
declare -A BASELINE=(
 [net.ipv4.ip_forward]=0 [net.ipv4.conf.all.send_redirects]=0 [net.ipv4.conf.default.send_redirects]=0
 [net.ipv4.conf.all.accept_source_route]=0 [net.ipv4.conf.default.accept_source_route]=0
 [net.ipv4.conf.all.accept_redirects]=0 [net.ipv4.conf.default.accept_redirects]=0
 [net.ipv6.conf.all.accept_redirects]=0 [net.ipv6.conf.default.accept_redirects]=0
 [net.ipv4.tcp_syncookies]=1 [kernel.randomize_va_space]=2 [kernel.kptr_restrict]=2
 [kernel.dmesg_restrict]=1 [fs.suid_dumpable]=0 [kernel.yama.ptrace_scope]=1
)
printf 'Collected: %s\nHost: %s\n\n' "$(date -Is)" "$(hostname -f 2>/dev/null || hostname)" > "$REPORT"
PASS=0; FAIL=0; UNKNOWN=0
for param in "${!BASELINE[@]}"; do
  expected=${BASELINE[$param]}; actual=$(sysctl -n "$param" 2>>"$ERRORS" || true)
  status=PASS
  if [[ -z "$actual" ]]; then status=UNKNOWN; UNKNOWN=$((UNKNOWN+1)); elif [[ "$actual" != "$expected" ]]; then status=REVIEW; FAIL=$((FAIL+1)); else PASS=$((PASS+1)); fi
  printf '"%s","%s","%s","%s"\n' "$param" "$expected" "$actual" "$status" >> "$CSV"
  printf '%-55s expected=%-4s actual=%-8s %s\n' "$param" "$expected" "${actual:-unknown}" "$status" >> "$REPORT"
done
{
  echo; echo '===== Persistent configuration ====='
  grep -RhvE '^[[:space:]]*(#|$)' /etc/sysctl.conf /etc/sysctl.d/*.conf /usr/lib/sysctl.d/*.conf 2>/dev/null || true
} >> "$REPORT"
OVERALL="Compliant"; [[ "$FAIL" -gt 0 ]] && OVERALL="Attention required"
cat > "$JSON" <<EOF
{"collected_at":"$(date -Is)","hostname":"$(hostname -f 2>/dev/null || hostname)","passed":$PASS,"findings_for_review":$FAIL,"unavailable_parameters":$UNKNOWN,"overall_status":"$OVERALL"}
EOF
printf 'Sysctl audit completed: %s\n' "$OUTPUT_DIR"
