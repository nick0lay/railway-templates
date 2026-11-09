# Deploy and Host Minecraft Java 26.3 (Paper) on Railway

A Minecraft Java Edition server for you and your friends, running Paper (a fast, plugin-friendly server) on Minecraft 26.3. It uses the widely used `itzg/minecraft-server` image, pinned to a tested release. Players join through a public Railway address, and the world is saved on a volume, so it survives restarts and redeploys.

## About Hosting Minecraft Java 26.3 (Paper)

A Minecraft server is one Java process that needs a public TCP port, enough memory and persistent disk for the world. This template sets all of that up: a Railway TCP proxy forwards players to port 25565, a volume at `/data` keeps the world, plugins and settings, and the memory defaults are tuned so an idle server stays cheap. Online mode is on, so only real Minecraft accounts can join, and you can limit the server to your friends with a whitelist. The RCON admin console is enabled with a generated password and stays on Railway's private network. Switch to Vanilla, Fabric, Forge, NeoForge or Purpur by changing one variable.

## Common Use Cases

- A private survival server for friends or family, limited to a whitelist
- A Paper server with plugins (EssentialsX, LuckPerms, WorldEdit and more)
- A modded Fabric or Forge server for a small group
- A creative or test server for builds, redstone or plugin development

## Dependencies for Minecraft Java 26.3 (Paper) Hosting

- A Minecraft: Java Edition account for each player (online mode checks accounts)
- Nothing else: the server downloads Paper and Minecraft on first start

### Deployment Dependencies

- Server image: https://github.com/itzg/docker-minecraft-server
- Image documentation: https://docker-minecraft-server.readthedocs.io/
- Paper: https://papermc.io/
- Minecraft EULA: https://aka.ms/MinecraftEULA

### Implementation Details

After deploy:

1. Open the **Minecraft** service, go to **Settings > Networking**, and copy the TCP proxy address, for example `xxxx.proxy.rlwy.net:12345`.
2. In Minecraft, open **Multiplayer > Add Server** and paste that address.
3. Set `WHITELIST` to your players' names (comma-separated) and `OPS` to the admins, then redeploy. Without a whitelist, anyone who has the address can join.

Main variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `TYPE` | `PAPER` | `PAPER`, `VANILLA`, `FABRIC`, `FORGE`, `NEOFORGE`, `PURPUR` |
| `VERSION` | `26.3` | Minecraft version, or `LATEST` |
| `MAX_MEMORY` | `2G` | Maximum Java heap |
| `INIT_MEMORY` | `512M` | Starting heap, kept low so idle costs less |
| `WHITELIST` | empty | Players allowed to join (turns the whitelist on) |
| `OPS` | empty | Players with operator rights |
| `ONLINE_MODE` | `TRUE` | Only real Minecraft accounts can join |
| `RCON_PASSWORD` | generated | Admin console password (private network only) |

Cost: in our tests the server used about 1.5 GB of RAM when idle and up to about 2.7 GB with `MAX_MEMORY=2G`. Railway bills by usage, so expect roughly $15-30 a month when it runs all day, more than the usage included in the Hobby plan. Raise `MAX_MEMORY` for modpacks or many players.

Backups: Railway volumes can be backed up from the service's **Backups** tab (manual or on a daily, weekly or monthly schedule, where your plan supports it). You can also copy the world out yourself; see the template's GitHub README.

## Why Deploy Minecraft Java 26.3 (Paper) on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Minecraft Java 26.3 (Paper) on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
