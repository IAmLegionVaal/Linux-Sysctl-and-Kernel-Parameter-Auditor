# Linux Sysctl and Kernel Parameter Auditor

A read-only Bash toolkit for comparing active kernel parameters with a practical security and networking baseline.

## Usage

```bash
chmod +x src/sysctl_kernel_auditor.sh
sudo ./src/sysctl_kernel_auditor.sh
```

## Checks performed

- IPv4 and IPv6 forwarding
- Redirect acceptance and sending
- Source-route and reverse-path filtering
- SYN cookie, ASLR, kernel pointer, dmesg, ptrace, and core-dump controls
- Active values, persistent configuration sources, and baseline differences
- Text, CSV, and JSON reports

## Safety

The script never applies sysctl values or edits persistent configuration.

## Author

Dewald Pretorius — L2 IT Support Engineer
