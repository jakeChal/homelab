# Homelab Stack

## Tailscale

Tailscale is a zero-config VPN (built on WireGuard) that lets you securely access your homelab services from anywhere — phone, laptop, work PC — without opening ports on your router.

### Setup

1. Create a free account at [tailscale.com](https://tailscale.com)
2. Install Tailscale on your server:
    ```shell
    curl -fsSL https://tailscale.com/install.sh | sh
    sudo tailscale up
    ```
3. Install the Tailscale app on each client device (Android, iOS, Windows, Mac) and sign in with the same account.

All your devices are now on a private network. Your server gets a stable Tailscale IP (`100.x.x.x`) that works from anywhere.

### Accessing services remotely

Use the server's Tailscale IP with the port directly (e.g. `http://100.x.x.x:2283` for Immich), or set up AdGuard as the DNS nameserver in the Tailscale admin console so `.home` domains also resolve remotely:

1. Run `tailscale ip` on the server to get its Tailscale IP
2. In the [Tailscale admin console](https://login.tailscale.com) → **DNS → Nameservers → Add nameserver → Custom**, add the server's Tailscale IP
3. `.home` DNS rewrites from AdGuard will now work on all Tailscale-connected devices

### Notes

- Tailscale overrides system DNS via `100.100.100.100` — this is why router-level DNS changes don't affect Tailscale devices without the step above
- The free plan supports up to 100 devices, which is more than enough for a homelab
- No ports need to be forwarded on your router

### Caddy + Tailscale MagicDNS (experimental)

> **Experimental.** This setup works but may be slightly slower than direct access. For best performance use `http://TAILSCALE_IP:PORT` directly (e.g. `http://100.x.x.x:2283` for Immich).

Caddy can join your Tailscale network and serve services over HTTPS with valid certs at `*.yourtailnet.ts.net` — no browser warnings, works from anywhere on Tailscale.

**Prerequisites (Tailscale admin console):**
1. Enable **MagicDNS** (DNS tab)
2. Enable **HTTPS Certificates** (DNS tab)
3. Generate a reusable **auth key** (Settings → Keys) and put it in `caddy/.env`:
    ```
    TS_AUTHKEY=tskey-auth-xxxxxxxxxxxx
    ```

**Caddyfile entries** (already configured, replace `yourtailnet` with your actual tailnet name):
- `https://immich.yourtailnet.ts.net`
- `https://backrest.yourtailnet.ts.net`
- `https://adguard.yourtailnet.ts.net`
- `https://uptime-kuma.yourtailnet.ts.net`
- `https://netdata.yourtailnet.ts.net`

Caddy uses a custom image with the `caddy-tailscale` plugin — it builds automatically on `docker compose up -d --build`. First boot is slow as it joins Tailscale and fetches certs.


## Immich
Immich is the FOSS equivalent of Google Photos. To set it up:

1. Get a `.env` file - [default one](https://docs.immich.app/install/docker-compose) from Immich is fine. Put it in the `immich` directory.

2. Bring Immich up:
    ```shell
    cd immich
    docker compose up -d
    ```

Then it should be up and running on port 2283. First steps:
- Create an admin user on the web UI
- Create a user for your friends/partner etc (Top right: Administration -> Users -> Create user)
- Download the Immich app on your phone, setup the Immich service `IP:PORT` and tap the "Backup" button. Select the directory you wanna backup (usually "Camera") and "Enable Backup" (this will take some time to finish...). Other users should do the same.

## Backrest

Backrest is a web UI backup solution built on top of [restic](https://restic.net/). We'll use it to back-up our users' phone media (for now).

1. Create an `.env` file and populate it properly (using the `example.env` as a base)
2. Bring it up:
    ```shell
    cd backrest
    docker compose up -d
    ```

Then it should be up and running on port 9898. First steps:
- Create an instance ID (e.g. `homelab-main`) and a user (e.g. `admin`) with a password
- Go to `Repositories -> Add Repo`: 
    - Repo name: `immich-local`
    - Repository URI: `/backup/restic-repo`
    - Pick a strong password
    - Leave the rest as default

- Go to `Plans -> Add Plan`:
    - Plan name: `immich-live`
    - Repository: Select `immich-local`
    - Paths:
        - `/source/homelab/immich/library`
    - Backup schedule: Use following cron expression to backup everyday at 3 a.m.
        ```shell
        0 3 * * *
        ```
- To verify this setup works:
    - Go to `immich-live` plan, and `Backup now` (this will take some time)
    - After it's done, you can select the backup, go to Snapshot Browser, select a file or directory, and on the `...` select "Restore to path". Pick a path, and check that the file/directory was restored fine at the desired location.
    - Follow-up backups should be fast and small, since only changed chunks are stored.

## Netdata

Netdata is a real-time server monitoring tool — CPU, memory, disk, network, and Docker container stats out of the box.

1. Bring it up:
    ```shell
    cd netdata
    docker compose up -d
    ```

Then it should be up and running at `http://netdata.home` (or `TAILSCALE_IP:19999` remotely). No initial setup required — the dashboard is live immediately with CPU, memory, disk, network, and per-container stats.

The compose file mounts `/proc`, `/sys`, and other host paths read-only so Netdata can see real host metrics rather than just the container's view. The `docker.sock` mount gives it per-container CPU/memory/network breakdown.

### Alerts and notifications

Netdata ships with hundreds of pre-built alert rules (high CPU, low disk, OOM, etc.) that fire automatically. To receive them somewhere useful:

1. Open a shell in the container:
    ```shell
    docker exec -it netdata bash
    ```
2. Edit the notification config:
    ```shell
    cd /etc/netdata && ./edit-config health_alarm_notify.conf
    ```
3. Find your provider (Telegram, email, Slack, etc.) and fill in the credentials — each has a clearly labelled block in the file.
4. Test it:
    ```shell
    sudo -u netdata /usr/libexec/netdata/plugins.d/alarm-notify.sh test
    ```

Config changes are persisted via the `./config` volume mount.

## Uptime Kuma

Uptime Kuma is a self-hosted monitoring tool that tracks whether your services are up and alerts you when they go down.

1. Bring it up:
    ```shell
    cd uptime-kuma
    docker compose up -d
    ```

Then it should be up and running at `http://uptime-kuma.home`. First steps:
- Create an admin account on first visit
- Add a monitor per service — use **HTTP(s)** type with the following URLs:
    - `http://host.docker.internal:2283` (Immich)
    - `http://host.docker.internal:9898` (Backrest)
    - `http://host.docker.internal:8080` (AdGuard)

> **Why `host.docker.internal`?** Uptime Kuma runs inside a container, so `localhost` refers to the container itself — not the host. `host.docker.internal` is a hostname that Docker resolves to the host machine's IP, letting the container reach services bound to the host. On Linux this requires the `extra_hosts: host.docker.internal:host-gateway` line in the compose file (already set).

- Configure notifications under **Settings → Notifications** — see the [ntfy](#ntfy) section below for the recommended setup.

## ntfy

[ntfy](https://ntfy.sh) is a simple, open-source push notification service. You publish a message to a topic (a URL like `https://ntfy.sh/your-topic`) and any subscribed device gets a push notification instantly. No account required when using the public instance.

### Setup with the public instance

1. **Install the app** on your phone: [Android (Play Store / F-Droid)](https://ntfy.sh/docs/subscribe/phone/) or [iOS (App Store)](https://ntfy.sh/docs/subscribe/phone/).
2. **Pick a topic name.** Topics are public by default on `ntfy.sh`, so use something unguessable:
    ```
    abc123-homelab-xyz789
    ```
3. **Subscribe to the topic** in the app: tap **+** → enter `https://ntfy.sh/abc123-homelab-xyz789`.
4. **Hook up Uptime Kuma:**
    - Go to **Settings → Notifications → Add Notification**
    - Type: **ntfy**
    - Server URL: `https://ntfy.sh`
    - Topic: `abc123-homelab-xyz789`
    - Save and use **Test** to verify a notification arrives on your phone.
5. **Assign the notification to monitors**: edit each monitor and add the ntfy notification under the **Notifications** field.

> **Note:** The public `ntfy.sh` instance is free and reliable for low-volume personal use. Messages are not end-to-end encrypted, so avoid sending sensitive data in alert bodies.

### TODO

- [ ] Self-host ntfy as a Docker service in this stack so alerts don't rely on an external service.
- [ ] Lock the topic down with [access control](https://docs.ntfy.sh/config/#access-control) so only the server can publish to it.
- [ ] Point Netdata alert notifications at the same ntfy topic.

## Caddy

Caddy is a reverse proxy that routes `*.home` domains to the appropriate services, so you don't need to remember ports.

1. Bring it up:
    ```shell
    cd caddy
    docker compose up -d
    ```

Services are available at:
- `http://immich.home`
- `http://backrest.home`
- `http://adguard.home`
- `http://uptime-kuma.home`
- `http://netdata.home`

Direct IP:PORT access still works in parallel as a fallback.

> **Note:** Caddy joins the Docker networks of each service (`immich_default`, `backrest_default`, `adguard_default`) and proxies by container name — no IP addresses needed in the config.

## AdGuard Home

AdGuard Home is a network-wide DNS server. It resolves `.home` domains to your server's LAN IP and blocks ads/trackers for all devices on the network.

1. Bring it up:
    ```shell
    cd adguard
    docker compose up -d
    ```

2. Complete the one-time setup wizard at `http://SERVER_IP:3000`. After setup the UI moves to `http://SERVER_IP:8080` (or `http://adguard.home` once DNS is working).

3. In the AdGuard UI, add upstream DNS servers (**Settings → DNS settings**):
    - `https://1.1.1.1/dns-query`
    - `https://8.8.8.8/dns-query`

4. Add DNS rewrites (**Filters → DNS rewrites**) for each service:
    - `immich.home` → `SERVER_LAN_IP`
    - `backrest.home` → `SERVER_LAN_IP`
    - `adguard.home` → `SERVER_LAN_IP`
    - `uptime-kuma.home` → `SERVER_LAN_IP`
    - `netdata.home` → `SERVER_LAN_IP`

5. Set your router's primary DNS server to `SERVER_LAN_IP` and secondary to `1.1.1.1`.

### Known DNS issues

- **Tailscale devices**: Tailscale overrides DNS via `100.100.100.100`. Add your server's Tailscale IP (`tailscale ip`) as a nameserver in the Tailscale admin console under **DNS → Nameservers**.
- **Android phones**: Android may prefer IPv6 DNS servers advertised by the router via Router Advertisement, bypassing AdGuard. Workaround: set Private DNS to **Off** on each phone, or disable IPv6 on the router.
- **VPN clients**: Third-party VPNs (e.g. ProtonVPN) own DNS while active. `.home` domains won't resolve through them — disable the VPN when on the home network.