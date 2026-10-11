# Proxmox host metrics

The Proxmox host (`proxmox`, 192.168.1.200) is outside the k3s cluster, so its exporter is
set up by hand. Prometheus scrapes it via
`monitoring/configs/staging/scrape/proxmox.yaml`, and the "Proxmox Host" Grafana dashboard
(`monitoring/configs/staging/dashboards/proxmox.json`) is built on it.

- `prometheus-node-exporter` (Debian package) on :9100 provides RAM, CPU and coretemp (hwmon).
- node_exporter can't see LVM thin pool usage, so `lvm-thin-textfile.sh` runs every minute
  and writes `proxmox_lvm_thin_*` metrics for the textfile collector.

## Install (as root on the host)

The Debian package's node_exporter reads textfiles from `/var/lib/prometheus/node-exporter`
by default (compiled in; `ARGS` in `/etc/default/prometheus-node-exporter` stays empty). On
other distros, add `--collector.textfile.directory=/var/lib/prometheus/node-exporter`.

```bash
apt install -y prometheus-node-exporter
install -m 755 lvm-thin-textfile.sh /usr/local/bin/
install -m 644 lvm-thin-textfile.service lvm-thin-textfile.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now lvm-thin-textfile.timer
curl -s localhost:9100/metrics | grep -E '^proxmox_lvm_thin|coretemp'
```
