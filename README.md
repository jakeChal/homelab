# Homelab Stack

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
        - `/source/homelab/immich/postgres`
    - Backup schedule: Use following cron expression to backup everyday at 3 a.m.
        ```shell
        0 3 * * *
        ```
- To verify this setup works:
    - Go to `immich-live` plan, and `Backup now` (this will take some time)
    - After it's done, you can select the backup, go to Snapshot Browser, select a file or directory, and on the `...` select "Restore to path". Pick a path, and check that the file/directory was restored fine at the desired location.
    - Follow-up backups should be fast and small, since only changed chunks are stored.