# Deploy and Host SillyTavern on Railway

SillyTavern is a popular open-source chat and roleplay frontend for large language models. It connects to OpenAI, Claude, Gemini, OpenRouter, KoboldCpp, Ollama, text-generation-webui and many other backends, and adds character cards, group chats, lorebooks (world info), prompt presets, extensions, image generation and text-to-speech on top.

## About Hosting SillyTavern

SillyTavern is a single Node.js server that keeps everything in files: its config, characters, chats, settings, API keys and installed extensions. A hosted instance needs a login on every page, because anyone who reaches it can read your chats and use your API keys. It also needs all of those files on persistent storage and a pinned version, so an update never surprises you.

This template runs the official image at the stable 1.19.1 release. A generated password protects every page and API call, and config, data, server plugins and global extensions all live on one volume.

## Common Use Cases

- Your SillyTavern characters, chats and presets on every device, from any browser
- A private frontend for OpenAI, Claude, Gemini, OpenRouter or DeepSeek API keys
- A shared instance for a few friends with SillyTavern's user accounts
- Connecting to your own model server (Ollama, KoboldCpp, vLLM) from anywhere
- Trying extensions and presets without a local install

## Dependencies for SillyTavern Hosting

- A Railway volume for config, chats, characters and extensions
- An API key for at least one model provider, or your own model server

### Deployment Dependencies

- SillyTavern: https://github.com/SillyTavern/SillyTavern
- Docs: https://docs.sillytavern.app/
- Image: https://github.com/SillyTavern/SillyTavern/pkgs/container/sillytavern

### Implementation Details

**What you set:** nothing is required. The username is `user` and the password is generated.

**After deploy:**

1. Open the SillyTavern URL. Your browser asks for a login: use `user` and the generated `SILLYTAVERN_BASICAUTHUSER_PASSWORD` (Variables tab).
2. Open API Connections (the plug icon), pick a provider, paste your API key and connect.
3. Pick or import a character and start chatting.

**This template:**

- Turns on basic authentication with a generated password. Every page, API call and static file needs it, and failed logins are rate-limited per visitor IP
- Turns off the IP whitelist, which can't work behind Railway's proxy, and listens on all interfaces
- Keeps `config/`, `data/`, `plugins/` and global extensions on one volume at `/data`, so settings, chats, characters, API keys and installed extensions survive redeploys
- Pins SillyTavern 1.19.1, the current stable release, instead of `latest`
- Uses the official image, with no custom build, and restarts the service if it crashes

**Notes:** there is no healthcheck, because SillyTavern has no page that works without the password. Anyone with the password can read your chats and use your API keys, so keep it secret and use keys with spending limits. To give each person their own space, turn on user accounts (see the README). Upgrade by changing the image tag. SillyTavern is AGPL-3.0 licensed. This template is not affiliated with the SillyTavern team.

## Why Deploy SillyTavern on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying SillyTavern on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
