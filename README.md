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

5. Set your router's primary DNS server to `SERVER_LAN_IP` and secondary to `1.1.1.1`.

### Known DNS issues

- **Tailscale devices**: Tailscale overrides DNS via `100.100.100.100`. Add your server's Tailscale IP (`tailscale ip`) as a nameserver in the Tailscale admin console under **DNS → Nameservers**.
- **Android phones**: Android may prefer IPv6 DNS servers advertised by the router via Router Advertisement, bypassing AdGuard. Workaround: set Private DNS to **Off** on each phone, or disable IPv6 on the router.
- **VPN clients**: Third-party VPNs (e.g. ProtonVPN) own DNS while active. `.home` domains won't resolve through them — disable the VPN when on the home network.