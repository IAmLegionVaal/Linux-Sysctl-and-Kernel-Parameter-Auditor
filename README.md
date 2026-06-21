# Linux Sysctl and Kernel Parameter Auditor

A Linux support toolkit for comparing active kernel parameters with a baseline and applying selected guarded sysctl repairs.

## Audit script

```bash
chmod +x src/sysctl_kernel_auditor.sh
sudo ./src/sysctl_kernel_auditor.sh
```

## Repair script

```bash
chmod +x src/sysctl_kernel_repair.sh
sudo ./src/sysctl_kernel_repair.sh --apply-safe-baseline --dry-run
```

Examples:

```bash
sudo ./src/sysctl_kernel_repair.sh --set net.ipv4.ip_forward 0
sudo ./src/sysctl_kernel_repair.sh --apply-safe-baseline
sudo ./src/sysctl_kernel_repair.sh --reload
```

## What the repair does

- Persists and applies one explicitly selected sysctl key and value.
- Can install a practical managed baseline covering forwarding, redirects, source routing, reverse-path filtering, SYN cookies, ASLR, kernel pointer exposure, dmesg access, ptrace and core dumps.
- Backs up existing managed drop-in files before replacement.
- Reloads persistent sysctl configuration with `sysctl --system`.
- Captures active and persistent values before and after repair.
- Supports dry-run, confirmation prompts, logs and clear exit codes.

## Safety

Kernel and network parameters change immediately and can affect routing, containers and applications. Review environment requirements before applying the full baseline. The tool does not edit arbitrary existing distribution files.

## Author

Dewald Pretorius — L2 IT Support Engineer
