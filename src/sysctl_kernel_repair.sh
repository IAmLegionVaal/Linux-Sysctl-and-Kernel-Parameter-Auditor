#!/usr/bin/env bash
set -u

SET_KEY=""
SET_VALUE=""
APPLY_BASELINE=false
RELOAD=false
DRY_RUN=false
ASSUME_YES=false
OUTPUT_DIR=""
FAILURES=0
ACTIONS=0

usage(){ cat <<'EOF'
Usage: sysctl_kernel_repair.sh [options]

  --set KEY VALUE         Persist and apply one selected sysctl value.
  --apply-safe-baseline   Write a practical hardened baseline drop-in.
  --reload                Reload all persistent sysctl configuration.
  --dry-run               Show commands without changing the host.
  --yes                   Skip confirmation prompts.
  --output DIR            Save logs, backups and verification output in DIR.
EOF
}
while [ "$#" -gt 0 ]; do case "$1" in
  --set) SET_KEY="${2:-}"; SET_VALUE="${3:-}"; shift 3;;
  --apply-safe-baseline) APPLY_BASELINE=true; shift;; --reload) RELOAD=true; shift;;
  --dry-run) DRY_RUN=true; shift;; --yes) ASSUME_YES=true; shift;;
  --output) OUTPUT_DIR="${2:-}"; shift 2;; -h|--help) usage; exit 0;;
  *) echo "Unknown argument: $1" >&2; usage; exit 2;; esac; done
if [ -z "$SET_KEY" ] && ! $APPLY_BASELINE && ! $RELOAD; then echo "Choose at least one repair action." >&2; exit 2; fi
if [ -n "$SET_KEY" ]; then case "$SET_KEY" in *[!A-Za-z0-9._-]*|'') echo "Invalid sysctl key." >&2; exit 2;; esac; [ -n "$SET_VALUE" ] || { echo "A value is required." >&2; exit 2; }; sysctl "$SET_KEY" >/dev/null 2>&1 || { echo "Unknown sysctl key: $SET_KEY" >&2; exit 2; }; fi
STAMP=$(date +%Y%m%d_%H%M%S); OUTPUT_DIR="${OUTPUT_DIR:-./sysctl-repair-$STAMP}"; BACKUP_DIR="$OUTPUT_DIR/backup"; mkdir -p "$BACKUP_DIR"; LOG="$OUTPUT_DIR/repair.log"; BEFORE="$OUTPUT_DIR/before.txt"; AFTER="$OUTPUT_DIR/after.txt"; : >"$LOG"
DROPIN=/etc/sysctl.d/99-support-baseline.conf
CUSTOM=/etc/sysctl.d/98-support-custom.conf
log(){ printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }
confirm(){ $ASSUME_YES && return 0; read -r -p "$1 [y/N]: " a; case "$a" in y|Y|yes|YES) return 0;; *) return 1;; esac; }
run(){ local d="$1"; shift; ACTIONS=$((ACTIONS+1)); log "$d"; if $DRY_RUN; then printf 'DRY-RUN:' >>"$LOG"; printf ' %q' "$@" >>"$LOG"; printf '\n' >>"$LOG"; return 0; fi; if "$@" >>"$LOG" 2>&1; then log "SUCCESS: $d"; else FAILURES=$((FAILURES+1)); log "WARNING: $d failed"; return 1; fi; }
root(){ local d="$1"; shift; if [ "$(id -u)" -eq 0 ]; then run "$d" "$@"; else run "$d" sudo "$@"; fi; }
collect(){ local f="$1"; { echo "Collected: $(date -Is)"; for k in net.ipv4.ip_forward net.ipv4.conf.all.accept_redirects net.ipv4.conf.default.accept_redirects net.ipv4.conf.all.send_redirects net.ipv4.conf.all.accept_source_route net.ipv4.conf.all.rp_filter net.ipv4.tcp_syncookies kernel.randomize_va_space kernel.kptr_restrict kernel.dmesg_restrict kernel.yama.ptrace_scope fs.suid_dumpable; do sysctl "$k" 2>/dev/null || true; done; [ -n "$SET_KEY" ] && sysctl "$SET_KEY" 2>/dev/null || true; echo; grep -Rhv '^[[:space:]]*#' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null || true; } >"$f"; }
collect "$BEFORE"; [ -f "$DROPIN" ] && cp -a "$DROPIN" "$BACKUP_DIR/" || true; [ -f "$CUSTOM" ] && cp -a "$CUSTOM" "$BACKUP_DIR/" || true
confirm "Apply the selected kernel-parameter repairs? Networking and security behaviour may change immediately." || { log "Repair cancelled."; exit 10; }
if $APPLY_BASELINE; then TMP=$(mktemp); cat >"$TMP" <<'EOF'
# Managed by Linux Sysctl and Kernel Parameter Auditor
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
fs.suid_dumpable = 0
EOF
  root "Installing managed sysctl baseline" install -o root -g root -m 644 "$TMP" "$DROPIN" || true; rm -f "$TMP"; fi
if [ -n "$SET_KEY" ]; then TMP=$(mktemp); [ -f "$CUSTOM" ] && grep -Ev "^[[:space:]]*${SET_KEY//./\.}[[:space:]]*=" "$CUSTOM" >"$TMP" || true; printf '%s = %s\n' "$SET_KEY" "$SET_VALUE" >>"$TMP"; root "Persisting $SET_KEY" install -o root -g root -m 644 "$TMP" "$CUSTOM" || true; rm -f "$TMP"; root "Applying $SET_KEY" sysctl -w "$SET_KEY=$SET_VALUE" || true; fi
if $APPLY_BASELINE || $RELOAD; then root "Reloading persistent sysctl configuration" sysctl --system || true; fi
$DRY_RUN || sleep 1; collect "$AFTER"; [ "$FAILURES" -eq 0 ] || exit 20; log "Repair completed successfully. Actions performed: $ACTIONS"
