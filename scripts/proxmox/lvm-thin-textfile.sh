#!/bin/sh
# Exports LVM thin pool usage (e.g. pve/data = local-lvm) for node_exporter's textfile collector.
set -eu
export LC_ALL=C
OUT=/var/lib/prometheus/node-exporter/lvm_thin.prom
TMP=$(mktemp "$OUT.XXXXXX")
lvs --noheadings --units b --nosuffix -o vg_name,lv_name,lv_size,data_percent,metadata_percent \
    --select 'segtype=thin-pool' | awk '
  { l = sprintf("vg=\"%s\",lv=\"%s\"", $1, $2)
    size[l] = $3; data[l] = $4 / 100; meta[l] = $5 / 100 }
  END {
    print "# HELP proxmox_lvm_thin_size_bytes LVM thin pool size."
    print "# TYPE proxmox_lvm_thin_size_bytes gauge"
    for (l in size) printf "proxmox_lvm_thin_size_bytes{%s} %s\n", l, size[l]
    print "# HELP proxmox_lvm_thin_data_used_ratio LVM thin pool data usage (0-1)."
    print "# TYPE proxmox_lvm_thin_data_used_ratio gauge"
    for (l in data) printf "proxmox_lvm_thin_data_used_ratio{%s} %s\n", l, data[l]
    print "# HELP proxmox_lvm_thin_metadata_used_ratio LVM thin pool metadata usage (0-1)."
    print "# TYPE proxmox_lvm_thin_metadata_used_ratio gauge"
    for (l in meta) printf "proxmox_lvm_thin_metadata_used_ratio{%s} %s\n", l, meta[l]
  }' > "$TMP"
chmod 644 "$TMP"
mv "$TMP" "$OUT"
