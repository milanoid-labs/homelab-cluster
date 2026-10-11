#!/bin/sh
# Exports LVM thin pool usage (e.g. pve/data = local-lvm) for node_exporter's textfile collector.
set -eu
export LC_ALL=C
OUT=/var/lib/prometheus/node-exporter/lvm_thin.prom
# Run lvs outside the pipeline: in sh, set -e only sees awk's exit status, so a failing
# lvs would replace the last good file with headers only. On failure (or no pools) exit
# non-zero and keep the previous file.
LVS=$(lvs --noheadings --units b --nosuffix -o vg_name,lv_name,lv_size,data_percent,metadata_percent \
    --select 'segtype=thin-pool')
[ -n "$LVS" ] || { echo "lvs returned no thin pools" >&2; exit 1; }
TMP=$(mktemp "$OUT.XXXXXX")
trap 'rm -f "$TMP"' EXIT
printf '%s\n' "$LVS" | awk '
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
