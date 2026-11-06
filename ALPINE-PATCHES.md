# PortSentry 2.0.7 — Alpine Linux Patch Notes

> **Upstream:** [portsentry/portsentry](https://github.com/portsentry/portsentry)  
> **Patched for:** Alpine Linux 3.x · musl libc · OpenRC · Yggdrasil mesh (IPv6 200::/7)  
> **Patch date:** 2026-11-06  
> **Status:** ✅ Builds clean · ✅ Tested on Alpine 3.21 (musl 1.2.5)

---

## Why This Fork Exists

Upstream PortSentry 2.0.7 fails to compile on Alpine Linux out of the box due to two issues:

1. **musl libc `strerror_r` ABI** — Alpine uses musl, which implements the POSIX-standard `strerror_r` (returns `int`). Upstream's `ErrnoString()` in `src/util.c` only guards for the GNU extension variant (returns `char*`) on glibc and BSD. musl falls through to the wrong branch, causing a type error: `assignment to 'char *' from 'int'`.

2. **systemd build requirement** — The cmake build attempts to find `SYSTEMD_SYSTEM_UNIT_DIR` with no fallback. Alpine uses OpenRC; `cmake` aborts if systemd is absent and `USE_SYSTEMD` is not explicitly disabled.

Both issues are fixed with minimal, non-invasive patches.

---

## Patches Applied

### 1 · `src/util.c` — musl `strerror_r` fix

**File:** `src/util.c`  
**Line:** 272  
**Change:** Added `|| !defined(__GLIBC__)` to the `#if` guard

```diff
- #if ((_POSIX_C_SOURCE >= 200112L) && !_GNU_SOURCE) || defined(BSD)
+ #if ((_POSIX_C_SOURCE >= 200112L) && !_GNU_SOURCE) || defined(BSD) || !defined(__GLIBC__)
```

**Why:** musl defines `_POSIX_C_SOURCE` and does NOT define `_GNU_SOURCE` or `__GLIBC__`. On musl, `strerror_r` is the POSIX variant (returns `int`, fills the caller's buffer). The GNU variant (returns `char*`, may return a static string) is glibc-specific. Without this patch, the compiler selects the glibc branch on musl, assigning an `int` return value to a `char*`, which is a hard error on `-Wall`.

The fix routes any non-glibc system (musl, uClibc, dietlibc, etc.) to the POSIX-safe branch.

---

### 2 · Build flags — systemd disabled

**File:** `CMakeLists.txt` (not patched — passed at configure time)  
**Flag:** `-D USE_SYSTEMD=OFF`

```sh
cmake -B release \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_INSTALL_PREFIX=/ \
  -D USE_SYSTEMD=OFF \
  -D USE_PCAP=OFF
```

**Why:** Alpine Linux uses OpenRC, not systemd. Without `USE_SYSTEMD=OFF`, cmake searches for `SYSTEMD_SYSTEM_UNIT_DIR` and fails to configure. `USE_PCAP=OFF` avoids a libpcap dependency for environments where only raw socket mode is needed.

> **Note:** An OpenRC init script is provided in `nexus/portsentry-openrc`.

---

## Build Instructions (Alpine Linux)

### Prerequisites

```sh
doas apk add cmake make gcc musl-dev linux-headers libpcap-dev
```

> `libpcap-dev` is required at **compile time** even with `USE_PCAP=OFF` because  
> `kernelmsg_linux.c` includes `pcap_listener.h` unconditionally. The runtime  
> binary does not link against libpcap.

### Build

```sh
git clone https://github.com/hackenstacks/portsentry-patched-alpine-linux.git
cd portsentry-patched-alpine-linux

cmake -B release \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_INSTALL_PREFIX=/ \
  -D USE_SYSTEMD=OFF \
  -D USE_PCAP=OFF

cmake --build release
```

Expected output:

```
[100%] Built target portcon
=== Build result: 0 ===
-rwxr-xr-x 1 user user 83440 ... release/portsentry
```

### Install

```sh
doas cp release/portsentry /usr/sbin/portsentry
doas mkdir -p /etc/portsentry
doas cp nexus/portsentry.conf   /etc/portsentry/portsentry.conf
doas cp nexus/portsentry.ignore /etc/portsentry/portsentry.ignore
doas touch /var/log/portsentry.log
doas chmod 640 /var/log/portsentry.log
```

### OpenRC Service

```sh
doas cp nexus/portsentry-openrc /etc/init.d/portsentry
doas chmod 755 /etc/init.d/portsentry
doas rc-update add portsentry default
doas rc-service portsentry start
```

### fail2ban Integration (Recommended)

PortSentry is configured with `BLOCK_TCP="0"` / `BLOCK_UDP="0"` — it **logs only**. fail2ban handles banning, which persists across reboots and provides rate-based logic.

```sh
doas cp nexus/portsentry-fail2ban-filter.conf /etc/fail2ban/filter.d/portsentry.conf
doas cp nexus/portsentry-fail2ban-jail.conf   /etc/fail2ban/jail.d/portsentry.conf
doas rc-service fail2ban reload
```

Jail config: `maxretry=1`, `bantime=86400` (24h), `action=iptables-allports`.

---

## Yggdrasil Mesh Compatibility

This fork is deployed on a node running [Yggdrasil](https://yggdrasil-network.github.io/), an end-to-end encrypted IPv6 mesh network. Yggdrasil assigns addresses in the `200::/7` range.

The provided `portsentry.ignore` file excludes Yggdrasil mesh peers from auto-banning:

```
127.0.0.1/32
::1/128
200::/7
```

**Without this exclusion**, PortSentry would ban legitimate Yggdrasil mesh peers that probe ports during routing discovery. Add any additional trusted prefixes to `/etc/portsentry/portsentry.ignore`.

---

## Files in `nexus/`

| File | Purpose |
|------|---------|
| `portsentry.conf` | Production config: aggressive port list, log-only mode, fail2ban handoff |
| `portsentry.ignore` | Ignore list: loopback + Yggdrasil 200::/7 |
| `portsentry-openrc` | OpenRC init script for Alpine/OpenRC systems |
| `portsentry-fail2ban-filter.conf` | fail2ban regex filter for PortSentry log format |
| `portsentry-fail2ban-jail.conf` | fail2ban jail: maxretry=1, bantime=24h, all-ports block |
| `build.sh` | Convenience build script (handles cmake flags for fish/POSIX shells) |

---

## NeXuS Integration

This patched build is part of the **NeXuS security stack** — a self-hosted, privacy-first infrastructure layer built on Alpine Linux.

### NeXuS Security Stack (what PortSentry works alongside)

| Tool | Role |
|------|------|
| **PortSentry 2.0.7** | Port scan detection → fail2ban handoff |
| **fail2ban** | Ban orchestrator — persists blocks across reboots |
| **OSSEC HIDS** | Host intrusion detection, file integrity, log analysis |
| **fwsnort** | Snort rules → nftables kernel rules (zero runtime cost) |
| **fwknopd** | Single Packet Authorization (SPA) — stealth SSH port |
| **AppArmor** | Mandatory access control (requires kernel `lsm=` boot param) |
| **Yggdrasil** | End-to-end encrypted IPv6 mesh — all inter-node traffic |

### Automated Install via nexus-security-wire.sh

If you are running a NeXuS node, the security stack can be wired in one shot:

```sh
# Clone the NeXuS scripts repo
git clone https://github.com/hackenstacks/nexus-scripts ~/NeXuS/scripts

# Wire the full security stack
sh ~/NeXuS/scripts/nexus-security-wire.sh
```

`nexus-security-wire.sh` handles: OSSEC startup + CPU cap, fwsnort persistence,
fail2ban + PortSentry jail, fwknopd, AppArmor boot param, and Nuzzle IDS wiring.

### Manual NeXuS-style install

```sh
# 1. Build PortSentry (see Build Instructions above)
# 2. Install
doas cp release/portsentry /usr/sbin/portsentry
doas mkdir -p /etc/portsentry
doas cp nexus/portsentry.conf   /etc/portsentry/portsentry.conf
doas cp nexus/portsentry.ignore /etc/portsentry/portsentry.ignore

# 3. OpenRC service
doas cp nexus/portsentry-openrc /etc/init.d/portsentry
doas chmod 755 /etc/init.d/portsentry
doas rc-update add portsentry default
doas rc-service portsentry start

# 4. fail2ban jail
doas cp nexus/portsentry-fail2ban-filter.conf /etc/fail2ban/filter.d/portsentry.conf
doas cp nexus/portsentry-fail2ban-jail.conf   /etc/fail2ban/jail.d/portsentry.conf
doas rc-service fail2ban reload

# 5. Verify
rc-service portsentry status
tail -f /var/log/portsentry.log
```

### NeXuS Project Links

- GitHub: https://github.com/hackenstacks
- Security scripts: https://github.com/hackenstacks/nexus-scripts
- NeXuS docs: https://hackenstacks.github.io/nexus/

---

## Upstream

- Source: https://github.com/portsentry/portsentry
- Docs: https://portsentry.xyz
- License: BSD-2-Clause (see `LICENSES/`)

---

## Credits

Patches by **hackenstacks** · Assisted by **Claude Sonnet 4.6** (Anthropic)  
Part of the [NeXuS](https://github.com/hackenstacks) security stack.
