# kubevirt01: Proxmox VM as a k3s node for KubeVirt runner VMs

`kubevirt01` is Proxmox VM 300 (192.168.1.234), joined to k3s as an agent. It exists only to
host KubeVirt VirtualMachineInstances (ephemeral GitHub Actions runner VMs), so it is tainted
to keep ordinary workloads off it. KubeVirt needs `/dev/kvm` on the node; this VM gets it via
nested virtualisation (`kvm_intel nested=Y` on the Proxmox host + `cpu: host` on the VM).

Built 2026-10-16. Steps below are what was actually run.

## 1. Create the VM (as root on Proxmox)

```bash
wget -O /var/lib/vz/import/noble-server-cloudimg-amd64.qcow2 \
  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

qm create 300 --name kubevirt01 --ostype l26 --machine q35 \
  --cpu host --cores 4 --memory 12288 --balloon 0 \
  --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single \
  --agent enabled=1 --onboot 1 --serial0 socket --vga serial0

qm set 300 --scsi0 local-lvm:0,import-from=/var/lib/vz/import/noble-server-cloudimg-amd64.qcow2,discard=on,ssd=1,iothread=1
qm resize 300 scsi0 100G
qm set 300 --boot order=scsi0

# cloud-init (Proxmox renders it to a NoCloud CD-ROM; inspect with `qm cloudinit dump 300 user|network`)
qm set 300 --ide2 local-lvm:cloudinit
qm set 300 --ciuser milan --sshkeys /root/kubevirt01.pub \
  --ipconfig0 ip=192.168.1.234/24,gw=192.168.1.1 \
  --nameserver "192.168.1.232 8.8.4.4"
qm start 300
```

- `--cpu host` is what exposes VT-x (`vmx`) to the guest; the default CPU type hides it and
  there is no `/dev/kvm`.
- `--balloon 0`: fixed RAM, so Proxmox never reclaims memory from under the nested VMs.
- `discard=on`: freed blocks go back to the `local-lvm` thin pool.
- RAM budget: with this VM (12 GB) running, don't also start VM 102 win2022 (8 GB).
- The cloud image has no passwords; SSH key login is the only way in. `qm terminal 300` shows
  the serial console only (no login without a password).

## 2. OS prep (on kubevirt01, `ssh kubevirt01`)

```bash
# Guest agent: clean shutdown, fs-freeze for backups, IP in the UI, `qm guest exec`
sudo apt-get update && sudo apt-get install -y qemu-guest-agent
sudo systemctl start qemu-guest-agent

# Unique iSCSI initiator name (cloud image ships GenerateName=yes; first iscsid start creates it).
# Never clone this VM without resetting /etc/iscsi/initiatorname.iscsi back to GenerateName=yes.
sudo systemctl start iscsid
sudo grep -v '^#' /etc/iscsi/initiatorname.iscsi

# Static resolv.conf: bypass the systemd-resolved stub that pi-hole's klipper-lb hijacks
sudo rm /etc/resolv.conf
printf '# Static on purpose: bypasses the systemd-resolved stub (127.0.0.53), which\n# pi-hole klipper-lb iptables rules hijack; see homelab-cluster memory/pihole trap.\nnameserver 1.1.1.1\nnameserver 1.0.0.1\nsearch milanoid.net\n' | sudo tee /etc/resolv.conf
getent hosts github.com

ls /var/run/reboot-required && sudo reboot
```

Checks: `ls -l /dev/kvm`, `grep -c -w vmx /proc/cpuinfo`, `cloud-init status --long`, and on
Proxmox `qm agent 300 ping`.

## 3. Join k3s

Use a short-lived **bootstrap token** (agents only, expires) rather than the server
`node-token` (can join servers, i.e. datastore + CA access):

```bash
ssh -t hpmini01 'sudo k3s token create --ttl 1h --description kubevirt01-join'
```

On kubevirt01, `/etc/rancher/k3s/config.yaml` (mode 600):

```yaml
server: https://192.168.1.231:6443
token: <bootstrap token>
node-label:
  - homelab.milanoid.net/kubevirt-runners=true
node-taint:
  - homelab.milanoid.net/kubevirt-runners=true:NoSchedule
```

```bash
# Same version as the cluster (infrastructure/k3s-upgrade-plans/plans.yaml)
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.37.1+k3s1 INSTALL_K3S_EXEC=agent sh -
```

From an admin kubectl (NodeRestriction stops the kubelet setting `node-role.kubernetes.io/*`
itself):

```bash
kubectl label node kubevirt01 node-role.kubernetes.io/worker=worker
```

- The taint is set at registration so nothing is scheduled in the gap before tainting.
- The label/taint use our own `homelab.milanoid.net/` prefix; KubeVirt manages its own
  `kubevirt.io/*` node labels.
- The bootstrap token in `config.yaml` is dead after its TTL; the agent authenticates with its
  own client cert from then on.

## What runs on the tainted node

| Component | Runs? | Why |
|---|---|---|
| node-exporter | yes | tolerates every `NoSchedule` |
| system-upgrade `agent-plan` jobs | yes | explicit toleration in `infrastructure/k3s-upgrade-plans/plans.yaml` |
| svclb-traefik / svclb-pihole-dns | no | good: no ingress endpoint and no pi-hole DNS trap rules here |
| synology-csi-node | no | no iSCSI PVCs are meant to land here |
| KubeVirt virt-handler + runner VMIs | yes | toleration via the KubeVirt CR `workloads.nodePlacement` |

## Rebuild / remove

```bash
kubectl drain kubevirt01 --ignore-daemonsets --delete-emptydir-data
kubectl delete node kubevirt01
ssh kubevirt01 'sudo /usr/local/bin/k3s-agent-uninstall.sh'
# on Proxmox: qm stop 300 && qm destroy 300 --purge
```
