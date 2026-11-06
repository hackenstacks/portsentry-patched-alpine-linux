<div align="center">
  <img src="https://portsentry.xyz/img/portsentry.png" width="180" />

  <h1>🛡️ PortSentry 2.0.7 — Alpine Linux Patch</h1>

  <p>
    <strong>Upstream:</strong> <a href="https://github.com/portsentry/portsentry">portsentry/portsentry</a> &nbsp;·&nbsp;
    <strong>License:</strong> BSD-2-Clause &nbsp;·&nbsp;
    <strong>Patch notes:</strong> <a href="ALPINE-PATCHES.md">ALPINE-PATCHES.md</a>
  </p>
</div>

---

## 🔍 What This Is

This is a **minimal patch fork** of [PortSentry 2.0.7](https://github.com/portsentry/portsentry) that fixes two compilation failures specific to **Alpine Linux** (musl libc + OpenRC). No upstream logic was changed.

> 💡 **Not on Alpine?** Use the [upstream package](https://github.com/portsentry/portsentry#quickstart) — it supports Debian, Ubuntu, Fedora, Arch, openSUSE, Docker, and BSD out of the box.

---

## 🩹 The Patches (Alpine Only)

Upstream PortSentry 2.0.7 fails to build on Alpine for two reasons:

**1. musl `strerror_r` ABI mismatch** — Alpine uses musl libc, which implements the POSIX-standard `strerror_r` returning `int`. The upstream `ErrnoString()` function in `src/util.c` only handles the GNU glibc variant (returns `char*`). On musl this causes a hard compile error: *assignment to `char*` from `int`*.

Fix — one line added to `src/util.c:272`:
```diff
- #if ((_POSIX_C_SOURCE >= 200112L) && !_GNU_SOURCE) || defined(BSD)
+ #if ((_POSIX_C_SOURCE >= 200112L) && !_GNU_SOURCE) || defined(BSD) || !defined(__GLIBC__)
```

**2. ⚙️ Systemd hard requirement** — cmake searches for `SYSTEMD_SYSTEM_UNIT_DIR` with no fallback. Alpine uses OpenRC; cmake aborts without an explicit opt-out.

Fix — cmake flags at configure time:
```
-D USE_SYSTEMD=OFF -D USE_PCAP=OFF
```

> 📄 Full technical breakdown of both patches: [ALPINE-PATCHES.md](ALPINE-PATCHES.md)

---

## 🚀 Install on Alpine Linux

### 📦 Dependencies

```sh
doas apk add cmake make gcc musl-dev linux-headers libpcap-dev git
```

> `libpcap-dev` is needed at **compile time only** — the binary does not link libpcap at runtime.

### 🔨 Build

```sh
git clone https://github.com/hackenstacks/portsentry-patched-alpine-linux.git
cd portsentry-patched-alpine-linux
sh nexus/build.sh
```

### 📥 Install binary + config

```sh
doas cp release/portsentry /usr/sbin/portsentry

doas mkdir -p /etc/portsentry
doas cp nexus/portsentry.conf   /etc/portsentry/portsentry.conf
doas cp nexus/portsentry.ignore /etc/portsentry/portsentry.ignore

doas touch /var/log/portsentry.log
doas chmod 640 /var/log/portsentry.log
```

### 🔁 OpenRC service

```sh
doas cp nexus/portsentry-openrc /etc/init.d/portsentry
doas chmod 755 /etc/init.d/portsentry
doas rc-update add portsentry default
doas rc-service portsentry start
```

### 🚫 fail2ban jail (recommended)

PortSentry is configured in **log-only mode** — it detects scans and writes to `/var/log/portsentry.log`. fail2ban reads that log and handles the actual IP banning, which persists across reboots.

```sh
doas cp nexus/portsentry-fail2ban-filter.conf /etc/fail2ban/filter.d/portsentry.conf
doas cp nexus/portsentry-fail2ban-jail.conf   /etc/fail2ban/jail.d/portsentry.conf
doas rc-service fail2ban reload
```

Defaults: first hit bans · 24-hour ban · all-ports block.

### ✅ Verify

```sh
rc-service portsentry status
tail -f /var/log/portsentry.log
doas fail2ban-client status portsentry
```

---

## 🌐 NeXuS

> *Sane · Simple · Secure · Stealthy · Beautiful*  
> → [hackenstacks.github.io/nexus](https://hackenstacks.github.io/nexus/#sane-simple-secure-stealthy-beautiful)

This fork is maintained as part of **[NeXuS](https://github.com/hackenstacks)** — a self-hosted, privacy-first infrastructure stack built on Alpine Linux. NeXuS is designed around the principle of maximum security for minimum resource cost, running on bare metal and mesh-networked nodes.

PortSentry's role in the stack is **perimeter sensing** 🔭 — it watches for port scans and probes on closed ports, and hands detected attackers off to fail2ban for banning. It sits alongside:

| Tool | Role |
|------|------|
| 🛡️ **PortSentry** | Port scan detection → fail2ban handoff |
| 🚫 **fail2ban** | Ban enforcement, reboot-persistent |
| 🔍 **OSSEC HIDS** | Host intrusion detection + file integrity |
| 🔥 **fwsnort** | Snort rules compiled into nftables kernel rules |
| 🔑 **fwknopd** | Single Packet Authorization — stealth SSH |
| 🔒 **AppArmor** | Mandatory access control |
| 🕸️ **Yggdrasil** | End-to-end encrypted IPv6 mesh between nodes |

The included `nexus/portsentry.ignore` excludes Yggdrasil mesh addresses (`200::/7`) so PortSentry never bans legitimate mesh peers.

**🔗 NeXuS links:**  
→ [github.com/hackenstacks](https://github.com/hackenstacks)  
→ [hackenstacks/nexus-scripts](https://github.com/hackenstacks/nexus-scripts)  
→ [hackenstacks.github.io/nexus](https://hackenstacks.github.io/nexus/#sane-simple-secure-stealthy-beautiful)

---

## 📡 Upstream Project

This fork tracks [portsentry/portsentry](https://github.com/portsentry/portsentry).  
Website: https://portsentry.xyz · Docker Hub: https://hub.docker.com/r/portsentry/portsentry
