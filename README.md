# 🦙 Local AI Setup — Ollama + Open WebUI

Run a local AI chatbot on your own computer. Everything stays on your machine — no cloud, no subscriptions, no data leaving your network.

**Supports:** Bazzite Linux (with legacy NVIDIA GPUs) and Ubuntu/Debian.

## Quick Start

Open a terminal and run:

```bash
git clone <this-repo-url>
cd ollama-bazzite
./setup.sh
```

The script will:
- Detect your OS and GPU automatically
- Install Docker if needed
- Set up NVIDIA GPU acceleration (if you have an NVIDIA card)
- Let you pick a model that fits your GPU
- Start everything up

When it's done, open **http://localhost:8080** in your browser.

## What Gets Installed

| Component | What it does |
|-----------|-------------|
| **Docker** | Runs containers (like lightweight virtual machines) |
| **NVIDIA Container Toolkit** | Lets containers use your GPU |
| **Ollama** | Runs AI models locally |
| **Open WebUI** | ChatGPT-like interface in your browser |

## After Setup

### Chatting

1. Go to http://localhost:8080
2. Create an account (this is 100% local — it never leaves your computer)
3. Pick a model from the dropdown at the top
4. Type a message and hit Enter

### Starting and Stopping

```bash
# Stop everything
docker compose down

# Start it back up
docker compose up -d
```

The services are set to restart automatically when your computer boots.
If you don't want that, stop them with `docker compose down`.

### Trying Different Models

You can download more models any time:

```bash
# Small and fast
docker exec ollama ollama pull tinyllama

# Good all-rounder
docker exec ollama ollama pull llama3.2:3b

# Higher quality (needs 6+ GB VRAM)
docker exec ollama ollama pull mistral:7b

# See what you have
docker exec ollama ollama list

# Delete one you don't want
docker exec ollama ollama rm tinyllama
```

Or just use the model selector in Open WebUI — it can download models too.

### How Much VRAM Do I Need?

Run `nvidia-smi` to check your VRAM, then pick accordingly:

| Your VRAM | Models that fit |
|-----------|----------------|
| 2 GB | `tinyllama`, `phi3:mini` (q4) |
| 4 GB | `llama3.2:3b`, `gemma2:2b`, `phi3:mini` |
| 6 GB | `llama3.2:3b`, `mistral:7b` (q4), `qwen2.5:7b` (q4) |
| 8 GB+ | `llama3.1:8b`, `mistral:7b`, `gemma2:9b` (q4) |

Smaller quantized versions (q4) use less VRAM but are slightly less accurate.

## Troubleshooting

### "I can't connect to http://localhost:8080"

Make sure the containers are running:

```bash
docker compose ps
```

If they're not, start them:

```bash
docker compose up -d
```

Check for errors:

```bash
docker compose logs
```

### "Models are really slow"

If your GPU isn't being used, models run on CPU which is much slower. Check:

```bash
docker compose logs ollama | grep -i gpu
```

If it says "no GPU detected", re-run `./setup.sh` — it will reconfigure the GPU access.

### "I'm on Bazzite and the script says I need to reboot"

That's normal! Bazzite is an immutable OS, so installing new system packages
needs a reboot to take effect. Just reboot and run `./setup.sh` again — it
picks up where it left off.

### "I want to delete everything and start fresh"

```bash
# Stop containers and delete all data (models, chat history, everything)
docker compose down -v
```

## Files in This Repo

| File | Purpose |
|------|---------|
| `setup.sh` | Interactive setup script — run this first |
| `docker-compose.yml` | Defines the Ollama + Open WebUI services |
| `README.md` | You're reading it |
| `MANUAL.md` | Step-by-step instructions without the script |
