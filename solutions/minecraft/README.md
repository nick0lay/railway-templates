# Minecraft Java 26.3 (Paper)

A Minecraft: Java Edition server on Railway, running [Paper](https://papermc.io/) on Minecraft 26.3 with the [itzg/minecraft-server](https://github.com/itzg/docker-minecraft-server) image. Players connect through a Railway TCP proxy, the world lives on a volume, and the image and Minecraft version are pinned and tested. No custom code: one official image, configured with variables.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/minecraft-java-263-paper?referralCode=CG2P3Y&utm_medium=integration&utm_source=template&utm_campaign=generic)

## Architecture

```
            Minecraft clients (Java Edition)
                        │ TCP, xxxx.proxy.rlwy.net:<port>
                        ▼
┌───────────────────────────────────────────────────┐
│ Railway project                                   │
│                                                   │
│  TCP proxy ──▶ Minecraft :25565 (Paper server)    │
│                  RCON :25575 (private only)       │
│                  volume /data: world, plugins,    │
│                  mods, configs                    │
└───────────────────────────────────────────────────┘
```

Only the game port is public, through the TCP proxy. RCON (the admin console) listens on the private network only. There is no web domain.

## Services

| Service | Source | Role |
|---------|--------|------|
| Minecraft | `itzg/minecraft-server:2026.10.1-java25` | Minecraft server (public game port through a TCP proxy, volume at `/data`) |

## Setup

1. Click **Deploy on Railway**. The defaults work as they are.
2. Wait until the deploy log shows `Done (...)! For help, type "help"`. The first start downloads Minecraft and Paper and takes about a minute.
3. Open the **Minecraft** service, go to **Settings > Networking**, and copy the TCP proxy address, for example `yamabiko.proxy.rlwy.net:31893`.
4. In Minecraft, choose **Multiplayer > Add Server** and paste the address.
5. Lock the server down: set `WHITELIST` to your players' names and `OPS` to the admins (both comma-separated), then redeploy.

Without a whitelist, anyone with a Minecraft account who finds the address can join. Server scanners do find public Minecraft ports, so set `WHITELIST` unless you want a public server.

## Variables

### User-Configurable

| Variable | Default | Description |
|----------|---------|-------------|
| `TYPE` | `PAPER` | Server type: `PAPER`, `VANILLA`, `FABRIC`, `FORGE`, `NEOFORGE`, `PURPUR`. Changing it on an existing world is at your own risk; back up first. |
| `VERSION` | `26.3` | Minecraft version. `LATEST` follows the newest release. |
| `MAX_MEMORY` | `2G` | Maximum Java heap. 2G suits about 5-10 players on Paper. |
| `INIT_MEMORY` | `512M` | Starting Java heap. Kept low so an idle server uses less RAM. |
| `WHITELIST` | empty | Players allowed to join. Setting it turns the whitelist on. |
| `OPS` | empty | Players with operator (admin) rights. |
| `MOTD` | `A Minecraft server on Railway` | Text shown in the server list. |
| `DIFFICULTY` | `normal` | `peaceful`, `easy`, `normal`, `hard`. |
| `MODE` | `survival` | Default game mode. |
| `MAX_PLAYERS` | `10` | Players online at once. |
| `TZ` | `UTC` | Time zone for logs. |
| `ONLINE_MODE` | `TRUE` | Checks every player against Microsoft/Mojang accounts. Keep `TRUE` on a public address. |

The image supports many more settings (seed, view distance, PvP, modpacks from Modrinth or CurseForge, plugin downloads). Add them as variables; see the [image documentation](https://docker-minecraft-server.readthedocs.io/en/latest/variables/).

### Auto-Configured (Do Not Change)

| Variable | Value | Why |
|----------|-------|-----|
| `EULA` | `TRUE` | Accepts the [Minecraft EULA](https://aka.ms/MinecraftEULA). The server refuses to start without it. |
| `ENABLE_RCON` | `true` | The image uses RCON to save the world and stop cleanly, and for `rcon-cli`. |
| `RCON_PASSWORD` | generated | RCON password. RCON is not exposed publicly. |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `60` | Gives the server time to save the world when Railway stops or replaces it. |

### Older Minecraft versions

The image tag uses Java 25, which Minecraft 26.x needs. Minecraft 1.20.5 to 1.21.x runs on Java 21, and older versions (and many older Forge versions) need Java 17 or 8. To run one, change the service's image to the matching tag, for example `itzg/minecraft-server:2026.10.1-java21` or `2026.10.1-java17`, and set `VERSION`.

## Connecting

- Players: use the TCP proxy address from **Settings > Networking**. The port is assigned by Railway and is not 25565.
- Custom domain: create a DNS `SRV` record `_minecraft._tcp.play.example.com` pointing to the proxy host and port. Players can then type `play.example.com` with no port.
- Admin console: open a shell in the service (Railway CLI: `railway ssh`) and run `rcon-cli`, for example `rcon-cli whitelist add Steve` or `rcon-cli op Steve`. In-game, operators can use the same commands.

## Plugins and mods

- Paper plugins: put `.jar` files in `/data/plugins`, or let the image download them with the `PLUGINS` or `MODRINTH_PROJECTS` variables.
- Fabric or Forge: set `TYPE`, then add mods with `MODRINTH_PROJECTS` or a modpack with `MODRINTH_MODPACK`. Modpacks usually need `MAX_MEMORY` of 4G or more.

## Backups

The world is in the volume at `/data`. There is no backup sidecar: Railway volumes attach to one service only, so a separate backup container (such as `itzg/mc-backup`) cannot read the world.

- Railway volume backups: on the Minecraft service, open the **Backups** tab and create a backup or set a daily, weekly or monthly schedule, if your plan includes volume backups. Restore from the same tab.
- Manual copy: open a shell with `railway ssh` and run:
  ```sh
  rcon-cli save-off
  rcon-cli save-all flush
  cd /data && tar czf /tmp/world-backup.tgz world*
  rcon-cli save-on
  ```
  Then copy `/tmp/world-backup.tgz` out of the container (for example `railway ssh -- cat /tmp/world-backup.tgz > world-backup.tgz` from your computer). The archive is in `/tmp`, so it does not use volume space and disappears on the next restart.

## Cost and plan

In our tests the server used about 1.5 GB of RAM when idle and up to about 2.7 GB with `MAX_MEMORY=2G`. Railway bills by usage, so a server running all day costs roughly $15-30 a month, more than the usage included in the Hobby plan. CPU is low when nobody plays and rises with players and loaded chunks. To save money, lower `MAX_MEMORY` for 1-3 players, or stop the service when nobody plays (your world stays on the volume). Modpacks and many players need more memory.

## Troubleshooting

- **Players can't connect.** Use the TCP proxy host and port from Settings > Networking, not port 25565. Check the logs for `Done (...)!`.
- **"You are not white-listed on this server".** Add the player to `WHITELIST` and redeploy, or run `rcon-cli whitelist add <name>`. Names must be exact Java Edition names.
- **Bedrock (phone, console) players can't join.** This is a Java Edition server. Bedrock bridges such as Geyser need UDP, which Railway's TCP proxy does not carry.
- **Out of memory or crashes under load.** Raise `MAX_MEMORY` (and expect a higher bill), or lower `view-distance` with the `VIEW_DISTANCE` variable.
- **Server fails after changing `VERSION`.** Older versions need an older Java tag; see "Older Minecraft versions". Downgrading a world to an older version is not supported by Minecraft.
- **No healthcheck.** Railway healthchecks are HTTP only, and a Minecraft server has no HTTP endpoint, so the template uses the restart-on-failure policy instead.

## Tested

Tested on 2026-11-09: clean deploys from the template, Paper 26.3 build 245 reached `Done` in about 8 seconds, a Minecraft status ping through the TCP proxy returned `Paper 26.3`, the world was reused after a redeploy, and `WHITELIST`/`OPS` turned on the whitelist. Idle memory was about 1.5 GB.
