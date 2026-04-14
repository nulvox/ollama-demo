# Manual Setup Guide

If you'd rather do it step by step instead of running the script.

## Bazzite (Fedora Atomic)

### 1. Make sure you're on the NVIDIA image

```bash
rpm-ostree status | grep bazzite
```

If it doesn't say `bazzite-nvidia`:

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-nvidia:stable
systemctl reboot
```

Verify: `nvidia-smi` should show your GPU.

### 2. Enable Docker

```bash
sudo systemctl enable --now docker.socket
sudo usermod -aG docker $USER
# Log out and back in
```

### 3. Install NVIDIA Container Toolkit

```bash
curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
    | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo

sudo rpm-ostree install nvidia-container-toolkit
systemctl reboot
```

### 4. Configure GPU access

```bash
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### 5. Start the stack

From the `ollama-demo` directory:

```bash
echo "COMPOSE_PROFILES=gpu" > .env
docker compose up -d
```

---

## Ubuntu / Debian

### 1. Install Docker

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
# Log out and back in
```

### 2. Install NVIDIA Container Toolkit

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install nvidia-container-toolkit
```

### 3. Configure GPU access

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### 4. Start the stack

From the `ollama-demo` directory:

```bash
echo "COMPOSE_PROFILES=gpu" > .env
docker compose up -d
```

If you don't have an NVIDIA GPU, use `cpu` instead of `gpu`.

---

## Using it

Open http://localhost:8080, create an account, pick a model, chat.

Or from the terminal:

```bash
docker exec ollama ollama pull llama3.2:3b
docker exec -it ollama ollama run llama3.2:3b
```

## Removing everything

```bash
# Stop and delete all data
docker compose down -v

# On Bazzite, to remove the layered toolkit:
sudo rpm-ostree uninstall nvidia-container-toolkit
systemctl reboot

# On Ubuntu:
sudo apt remove nvidia-container-toolkit
```

## SELinux note (Bazzite only)

The compose file disables SELinux labeling on the containers. This is the
standard workaround for NVIDIA GPU containers on Fedora. For a proper SELinux
policy that keeps enforcement active, see:
https://codeberg.org/hennrikk/container-services
