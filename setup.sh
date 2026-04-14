#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  Ollama Local AI Setup                                                    ║
# ║  Supports: Bazzite (Fedora Atomic) and Ubuntu/Debian                      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ── Colors & Formatting ──────────────────────────────────────────────────────

BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BG_GREEN='\033[42m'
BG_RED='\033[41m'
BG_BLUE='\033[44m'

# ── Output helpers ────────────────────────────────────────────────────────────

banner() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════╗"
    echo "  ║                                                       ║"
    echo "  ║       🦙  Local AI Setup — Ollama + Open WebUI       ║"
    echo "  ║                                                       ║"
    echo "  ╚═══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

step() {
    local num="$1"; shift
    local total="$1"; shift
    echo ""
    echo -e "  ${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BLUE}${BOLD}  Step ${num} of ${total}: $*${RESET}"
    echo -e "  ${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

info()    { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
err()     { echo -e "  ${RED}✗${RESET}  $*"; }
detail()  { echo -e "  ${DIM}   $*${RESET}"; }
blank()   { echo ""; }

die() {
    echo ""
    echo -e "  ${BG_RED}${WHITE}${BOLD} FATAL ${RESET}  $*"
    echo ""
    exit 1
}

success_box() {
    echo ""
    echo -e "  ${GREEN}${BOLD}╔═══════════════════════════════════════════════════════╗${RESET}"
    echo -e "  ${GREEN}${BOLD}║                                                       ║${RESET}"
    echo -e "  ${GREEN}${BOLD}║   ✓  $1${RESET}"
    echo -e "  ${GREEN}${BOLD}║                                                       ║${RESET}"
    if [[ -n "${2:-}" ]]; then
    echo -e "  ${GREEN}${BOLD}║${RESET}   $2"
    echo -e "  ${GREEN}${BOLD}║                                                       ║${RESET}"
    fi
    if [[ -n "${3:-}" ]]; then
    echo -e "  ${GREEN}${BOLD}║${RESET}   $3"
    echo -e "  ${GREEN}${BOLD}║                                                       ║${RESET}"
    fi
    echo -e "  ${GREEN}${BOLD}╚═══════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

# Ask a yes/no question, default to yes
confirm() {
    local prompt="$1"
    echo ""
    echo -ne "  ${CYAN}?${RESET}  ${prompt} ${DIM}[Y/n]${RESET} "
    read -r reply
    [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
}

# Ask user to pick from numbered options
pick() {
    local prompt="$1"; shift
    local options=("$@")
    echo ""
    echo -e "  ${CYAN}?${RESET}  ${prompt}"
    echo ""
    for i in "${!options[@]}"; do
        echo -e "     ${BOLD}$((i+1))${RESET}  ${options[$i]}"
    done
    echo ""
    while true; do
        echo -ne "  ${DIM}   Enter number:${RESET} "
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            PICK_RESULT=$((choice - 1))
            return 0
        fi
        echo -e "  ${RED}   Please enter a number between 1 and ${#options[@]}${RESET}"
    done
}

pause() {
    echo ""
    echo -ne "  ${DIM}Press Enter to continue...${RESET}"
    read -r
}

spinner() {
    local pid=$1
    local msg="${2:-Working...}"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        echo -ne "\r  ${CYAN}${frames[$i]}${RESET}  ${msg}"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.1
    done
    wait "$pid" 2>/dev/null
    local exit_code=$?
    echo -ne "\r\033[K"
    return $exit_code
}

# Run a command with a spinner, logging output to file
run_with_spinner() {
    local msg="$1"; shift
    local logfile="/tmp/ollama-setup-$$.log"
    "$@" &>"$logfile" &
    local pid=$!
    if spinner "$pid" "$msg"; then
        info "$msg"
        return 0
    else
        err "$msg"
        echo -e "  ${DIM}   Log output:${RESET}"
        tail -5 "$logfile" | while read -r line; do
            echo -e "  ${DIM}   │ ${line}${RESET}"
        done
        return 1
    fi
}

# ── Script directory ──────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Distro detection ─────────────────────────────────────────────────────────

detect_distro() {
    DISTRO="unknown"
    DISTRO_PRETTY="Unknown"

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release

        if rpm-ostree status &>/dev/null 2>&1; then
            if rpm-ostree status 2>/dev/null | grep -qi 'bazzite'; then
                DISTRO="bazzite"
                DISTRO_PRETTY="Bazzite (Fedora Atomic)"
            else
                DISTRO="fedora-atomic"
                DISTRO_PRETTY="Fedora Atomic (${PRETTY_NAME:-unknown})"
            fi
        elif [[ "${ID:-}" == "ubuntu" ]] || [[ "${ID_LIKE:-}" == *"ubuntu"* ]] || [[ "${ID_LIKE:-}" == *"debian"* ]] || [[ "${ID:-}" == "debian" ]]; then
            DISTRO="debian"
            DISTRO_PRETTY="${PRETTY_NAME:-Ubuntu/Debian}"
        elif [[ "${ID:-}" == "fedora" ]]; then
            DISTRO="fedora"
            DISTRO_PRETTY="${PRETTY_NAME:-Fedora}"
        fi
    fi
}

# ── NVIDIA detection ──────────────────────────────────────────────────────────

detect_gpu() {
    HAS_NVIDIA=false
    GPU_NAME="(not detected)"
    GPU_VRAM="unknown"

    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        HAS_NVIDIA=true
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "NVIDIA GPU")
        GPU_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1 || echo "unknown")
    elif lspci 2>/dev/null | grep -qi 'nvidia'; then
        # GPU exists but drivers aren't working
        GPU_NAME=$(lspci 2>/dev/null | grep -i nvidia | head -1 | sed 's/.*: //')
        HAS_NVIDIA="driver_missing"
    fi
}

# ── Docker check ──────────────────────────────────────────────────────────────

detect_docker() {
    HAS_DOCKER=false
    DOCKER_CMD="docker"

    if command -v docker &>/dev/null; then
        if docker info &>/dev/null 2>&1; then
            HAS_DOCKER=true
        elif sudo docker info &>/dev/null 2>&1; then
            HAS_DOCKER=true
            DOCKER_CMD="sudo docker"
        fi
    fi
}

# ── Install functions: Bazzite ────────────────────────────────────────────────

bazzite_check_nvidia_image() {
    if ! rpm-ostree status 2>/dev/null | grep -qi 'nvidia'; then
        warn "You're not on a Bazzite NVIDIA image."
        detail "Your GPU needs the proprietary NVIDIA drivers, which come"
        detail "pre-installed on the bazzite-nvidia image."
        blank
        if confirm "Want me to show you how to switch? (won't do it automatically)"; then
            echo ""
            echo -e "  ${BOLD}Run this command, then reboot and re-run this script:${RESET}"
            echo ""
            echo -e "  ${CYAN}  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-nvidia:stable${RESET}"
            echo -e "  ${CYAN}  systemctl reboot${RESET}"
            echo ""
            exit 0
        else
            warn "Continuing anyway — GPU acceleration may not work."
        fi
    else
        info "Running Bazzite NVIDIA image."
    fi
}

bazzite_install_docker() {
    if systemctl is-active --quiet docker.socket || systemctl is-active --quiet docker.service; then
        info "Docker is already running."
        return 0
    fi

    detail "Bazzite ships Docker but it's not enabled by default."
    detail "Enabling Docker socket (on-demand activation)..."
    blank

    if command -v ujust &>/dev/null; then
        ujust configure docker enable-socket 2>/dev/null || true
    fi
    sudo systemctl enable --now docker.socket
    info "Docker socket enabled."
}

bazzite_install_nvidia_toolkit() {
    if command -v nvidia-ctk &>/dev/null; then
        info "NVIDIA Container Toolkit already installed."
        return 0
    fi

    detail "Installing NVIDIA Container Toolkit..."
    detail "On Bazzite this requires layering a package with rpm-ostree."
    detail "This means a reboot is needed after install."
    blank

    if ! confirm "Install nvidia-container-toolkit? (requires reboot)"; then
        die "Can't set up GPU containers without the toolkit. Exiting."
    fi

    # Add repo if needed
    if [[ ! -f /etc/yum.repos.d/nvidia-container-toolkit.repo ]]; then
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
            | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo > /dev/null
    fi

    if rpm -q nvidia-container-toolkit &>/dev/null; then
        info "Package already layered (may need reboot to activate)."
    else
        run_with_spinner "Layering nvidia-container-toolkit..." \
            sudo rpm-ostree install --idempotent nvidia-container-toolkit

        echo ""
        echo -e "  ${YELLOW}${BOLD}╔═══════════════════════════════════════════════════════╗${RESET}"
        echo -e "  ${YELLOW}${BOLD}║                                                       ║${RESET}"
        echo -e "  ${YELLOW}${BOLD}║   ⚠  Reboot required!                                ║${RESET}"
        echo -e "  ${YELLOW}${BOLD}║                                                       ║${RESET}"
        echo -e "  ${YELLOW}${BOLD}║${RESET}   The NVIDIA container toolkit has been installed     ${YELLOW}${BOLD}║${RESET}"
        echo -e "  ${YELLOW}${BOLD}║${RESET}   but needs a reboot to activate.                    ${YELLOW}${BOLD}║${RESET}"
        echo -e "  ${YELLOW}${BOLD}║                                                       ║${RESET}"
        echo -e "  ${YELLOW}${BOLD}║${RESET}   After reboot, run this script again:                ${YELLOW}${BOLD}║${RESET}"
        echo -e "  ${YELLOW}${BOLD}║${RESET}   ${CYAN}cd $(pwd) && ./setup.sh${RESET}                     ${YELLOW}${BOLD}║${RESET}"
        echo -e "  ${YELLOW}${BOLD}║                                                       ║${RESET}"
        echo -e "  ${YELLOW}${BOLD}╚═══════════════════════════════════════════════════════╝${RESET}"
        echo ""

        if confirm "Reboot now?"; then
            sudo systemctl reboot
        fi
        exit 0
    fi
}

# ── Install functions: Ubuntu/Debian ──────────────────────────────────────────

debian_install_docker() {
    if command -v docker &>/dev/null; then
        info "Docker is already installed."
        # Make sure it's running
        if ! systemctl is-active --quiet docker; then
            sudo systemctl enable --now docker
        fi
        return 0
    fi

    detail "Installing Docker from the official Docker repository..."
    detail "This is the recommended way — the Ubuntu repo version is often outdated."
    blank

    # Install prerequisites
    run_with_spinner "Installing prerequisites..." \
        sudo apt-get update -qq

    sudo apt-get install -y -qq ca-certificates curl gnupg >/dev/null 2>&1

    # Add Docker GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
        sudo chmod a+r /etc/apt/keyrings/docker.asc
    fi

    # Determine the upstream distro for Docker repo
    # (works for Ubuntu and derivatives like Mint, Pop, etc.)
    local codename
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    fi

    if [[ -z "${codename:-}" ]]; then
        codename=$(lsb_release -cs 2>/dev/null || echo "jammy")
    fi

    local arch
    arch=$(dpkg --print-architecture)

    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    run_with_spinner "Updating package lists..." \
        sudo apt-get update -qq

    run_with_spinner "Installing Docker Engine..." \
        sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo systemctl enable --now docker
    info "Docker installed and running."
}

debian_install_nvidia_toolkit() {
    if command -v nvidia-ctk &>/dev/null; then
        info "NVIDIA Container Toolkit already installed."
        return 0
    fi

    detail "Installing NVIDIA Container Toolkit..."
    blank

    # Add NVIDIA repo
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg 2>/dev/null

    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

    run_with_spinner "Updating package lists..." \
        sudo apt-get update -qq

    run_with_spinner "Installing nvidia-container-toolkit..." \
        sudo apt-get install -y -qq nvidia-container-toolkit

    info "NVIDIA Container Toolkit installed."
}

# ── Shared functions ──────────────────────────────────────────────────────────

ensure_docker_group() {
    if groups | grep -qw docker; then
        info "User is in the docker group."
        return 0
    fi

    sudo usermod -aG docker "$USER"
    warn "Added you to the docker group."
    detail "This takes effect on next login. For now, using sudo for docker."
    DOCKER_CMD="sudo docker"
}

configure_nvidia_runtime() {
    detail "Generating CDI spec (maps GPU devices for containers)..."
    sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml 2>/dev/null
    info "CDI spec generated."

    detail "Configuring Docker to use NVIDIA runtime..."
    sudo nvidia-ctk runtime configure --runtime=docker 2>/dev/null
    info "Docker runtime configured."

    detail "Restarting Docker..."
    sudo systemctl restart docker
    info "Docker restarted."
}

test_gpu_container() {
    detail "Testing GPU access inside a container..."
    detail "(This downloads a small CUDA test image — may take a minute)"
    blank

    if run_with_spinner "Running GPU container test..." \
        $DOCKER_CMD run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi; then
        info "GPU container test passed!"
        return 0
    else
        warn "GPU container test failed."
        detail "Ollama might still work — it has its own CUDA bundled."
        detail "If models run on CPU only, check the troubleshooting section in README.md."
        return 1
    fi
}

pick_model() {
    local vram_mb=0

    if [[ "$HAS_NVIDIA" == "true" ]]; then
        # Parse VRAM in MiB
        vram_mb=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ' || echo "0")
    fi

    echo ""
    echo -e "  ${BOLD}Which model would you like to start with?${RESET}"
    echo ""

    if (( vram_mb > 0 && vram_mb < 3072 )); then
        echo -e "  ${DIM}Your GPU has ~${vram_mb} MiB VRAM — recommending small models.${RESET}"
        echo ""
        pick "Choose a starting model:" \
            "tinyllama — Very small, fast, good for testing (1.1B params)" \
            "phi3:mini — Microsoft's compact model, surprisingly capable (3.8B params)" \
            "Skip — I'll pick my own model later"
        case $PICK_RESULT in
            0) MODEL="tinyllama" ;;
            1) MODEL="phi3:mini" ;;
            2) MODEL="" ;;
        esac
    elif (( vram_mb >= 3072 && vram_mb < 6144 )); then
        echo -e "  ${DIM}Your GPU has ~${vram_mb} MiB VRAM — good for 3B-7B models.${RESET}"
        echo ""
        pick "Choose a starting model:" \
            "llama3.2:3b — Meta's latest small model, great all-rounder" \
            "gemma2:2b — Google's compact model, fast responses" \
            "phi3:mini — Microsoft's compact model (3.8B params)" \
            "Skip — I'll pick my own model later"
        case $PICK_RESULT in
            0) MODEL="llama3.2:3b" ;;
            1) MODEL="gemma2:2b" ;;
            2) MODEL="phi3:mini" ;;
            3) MODEL="" ;;
        esac
    elif (( vram_mb >= 6144 )); then
        echo -e "  ${DIM}Your GPU has ~${vram_mb} MiB VRAM — nice, you can run larger models.${RESET}"
        echo ""
        pick "Choose a starting model:" \
            "llama3.1:8b — Meta's 8B model, excellent quality" \
            "mistral:7b — Mistral's flagship, great for chat" \
            "llama3.2:3b — Smaller/faster if you want quick responses" \
            "Skip — I'll pick my own model later"
        case $PICK_RESULT in
            0) MODEL="llama3.1:8b" ;;
            1) MODEL="mistral:7b" ;;
            2) MODEL="llama3.2:3b" ;;
            3) MODEL="" ;;
        esac
    else
        echo -e "  ${DIM}Couldn't detect VRAM — showing safe options.${RESET}"
        echo ""
        pick "Choose a starting model:" \
            "llama3.2:3b — Good balance of speed and quality" \
            "tinyllama — Very small, works on almost anything" \
            "Skip — I'll pick my own model later"
        case $PICK_RESULT in
            0) MODEL="llama3.2:3b" ;;
            1) MODEL="tinyllama" ;;
            2) MODEL="" ;;
        esac
    fi
}

start_stack() {
    cd "$SCRIPT_DIR"

    detail "Pulling container images (this may take a few minutes)..."
    blank
    $DOCKER_CMD compose pull

    blank
    detail "Starting Ollama + Open WebUI..."
    $DOCKER_CMD compose up -d

    # Wait for ollama to be ready
    detail "Waiting for Ollama to start..."
    local retries=30
    while (( retries > 0 )); do
        if curl -sf http://localhost:11434/api/tags &>/dev/null; then
            break
        fi
        sleep 2
        retries=$((retries - 1))
    done

    if (( retries == 0 )); then
        warn "Ollama didn't respond in time. It may still be starting."
        detail "Check with: docker compose logs ollama"
    else
        info "Ollama is running."
    fi

    # Pull the selected model
    if [[ -n "${MODEL:-}" ]]; then
        blank
        echo -e "  ${BOLD}Downloading model: ${MODEL}${RESET}"
        detail "(This downloads the model weights — can be 1-5 GB depending on the model)"
        blank
        $DOCKER_CMD exec ollama ollama pull "$MODEL"
        info "Model ${MODEL} ready."
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════════════════════

main() {
    banner

    echo -e "  ${DIM}This script will set up a local AI chat on your computer.${RESET}"
    echo -e "  ${DIM}Everything runs locally — nothing leaves your machine.${RESET}"
    blank

    # ── Detect environment ────────────────────────────────────────────────────

    detect_distro
    detect_gpu
    detect_docker

    echo -e "  ${BOLD}System detected:${RESET}"
    echo -e "    OS:    ${DISTRO_PRETTY}"
    echo -e "    GPU:   ${GPU_NAME}"
    if [[ "$HAS_NVIDIA" == "true" ]]; then
    echo -e "    VRAM:  ${GPU_VRAM}"
    fi
    echo -e "    Docker: $(if [[ "$HAS_DOCKER" == "true" ]]; then echo "installed"; else echo "not installed"; fi)"
    blank

    # Bail on unsupported distros
    if [[ "$DISTRO" == "unknown" ]]; then
        die "Couldn't detect your Linux distribution.
     This script supports Bazzite and Ubuntu/Debian.
     You can still set things up manually — see MANUAL.md."
    fi

    # Handle missing NVIDIA drivers
    if [[ "$HAS_NVIDIA" == "driver_missing" ]]; then
        warn "Found NVIDIA hardware but drivers aren't loaded."
        if [[ "$DISTRO" == "bazzite" ]]; then
            detail "You need the bazzite-nvidia image. See README.md for rebase instructions."
        else
            detail "Install NVIDIA drivers first: sudo apt install nvidia-driver-XXX"
            detail "(Replace XXX with your driver version — check nvidia.com for your GPU)"
        fi
        blank
        if ! confirm "Continue anyway? (will run without GPU acceleration)"; then
            exit 0
        fi
    fi

    # ── Set compose profile ────────────────────────────────────────────────
    local compose_profile="cpu"
    if [[ "$HAS_NVIDIA" == "true" ]]; then
        compose_profile="gpu"
    fi

    # Write profile to .env so `docker compose up -d` works without flags
    echo "COMPOSE_PROFILES=${compose_profile}" > "$SCRIPT_DIR/.env"
    info "Compose profile set to: ${compose_profile}"

    if ! confirm "Ready to set up? This will install Docker and configure GPU containers."; then
        echo -e "  ${DIM}No worries. Run this script again when you're ready.${RESET}"
        exit 0
    fi

    # ── Determine step count ──────────────────────────────────────────────────

    local total_steps=4
    if [[ "$HAS_NVIDIA" == "true" ]]; then
        total_steps=6
    fi
    local current_step=0

    # ── Step: Install Docker ──────────────────────────────────────────────────

    current_step=$((current_step + 1))
    step "$current_step" "$total_steps" "Install Docker"

    case "$DISTRO" in
        bazzite|fedora-atomic)
            bazzite_check_nvidia_image
            bazzite_install_docker
            ;;
        debian)
            debian_install_docker
            ;;
        fedora)
            # Standard Fedora — use dnf
            if ! command -v docker &>/dev/null; then
                run_with_spinner "Installing Docker..." \
                    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                sudo systemctl enable --now docker
            fi
            info "Docker installed."
            ;;
    esac

    # ── Step: Docker group ────────────────────────────────────────────────────

    current_step=$((current_step + 1))
    step "$current_step" "$total_steps" "Configure Docker permissions"

    ensure_docker_group

    # ── Steps: NVIDIA (conditional) ───────────────────────────────────────────

    if [[ "$HAS_NVIDIA" == "true" ]]; then
        current_step=$((current_step + 1))
        step "$current_step" "$total_steps" "Install NVIDIA Container Toolkit"

        case "$DISTRO" in
            bazzite|fedora-atomic)
                bazzite_install_nvidia_toolkit
                ;;
            debian)
                debian_install_nvidia_toolkit
                ;;
            fedora)
                if ! command -v nvidia-ctk &>/dev/null; then
                    curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
                        | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo > /dev/null
                    run_with_spinner "Installing nvidia-container-toolkit..." \
                        sudo dnf install -y nvidia-container-toolkit
                fi
                info "NVIDIA Container Toolkit installed."
                ;;
        esac

        current_step=$((current_step + 1))
        step "$current_step" "$total_steps" "Configure GPU container access"

        configure_nvidia_runtime
        test_gpu_container || true
    fi

    # ── Step: Pick model ──────────────────────────────────────────────────────

    current_step=$((current_step + 1))
    step "$current_step" "$total_steps" "Choose a model"

    pick_model

    # ── Step: Start everything ────────────────────────────────────────────────

    current_step=$((current_step + 1))
    step "$current_step" "$total_steps" "Start Ollama + Open WebUI"

    start_stack

    # ── Done! ─────────────────────────────────────────────────────────────────

    echo ""
    echo -e "  ${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "  ${GREEN}${BOLD}║                                                           ║${RESET}"
    echo -e "  ${GREEN}${BOLD}║   🎉  All done! Your local AI is ready.                  ║${RESET}"
    echo -e "  ${GREEN}${BOLD}║                                                           ║${RESET}"
    echo -e "  ${GREEN}${BOLD}║${RESET}   Open your browser and go to:                          ${GREEN}${BOLD}║${RESET}"
    echo -e "  ${GREEN}${BOLD}║                                                           ║${RESET}"
    echo -e "  ${GREEN}${BOLD}║${RESET}       ${CYAN}${BOLD}http://localhost:8080${RESET}                             ${GREEN}${BOLD}║${RESET}"
    echo -e "  ${GREEN}${BOLD}║                                                           ║${RESET}"
    echo -e "  ${GREEN}${BOLD}║${RESET}   1. Create an account (it's local, just for you)       ${GREEN}${BOLD}║${RESET}"
    if [[ -n "${MODEL:-}" ]]; then
    echo -e "  ${GREEN}${BOLD}║${RESET}   2. Pick ${BOLD}${MODEL}${RESET} from the model dropdown            ${GREEN}${BOLD}║${RESET}"
    else
    echo -e "  ${GREEN}${BOLD}║${RESET}   2. Click the model selector and download one          ${GREEN}${BOLD}║${RESET}"
    fi
    echo -e "  ${GREEN}${BOLD}║${RESET}   3. Start chatting!                                    ${GREEN}${BOLD}║${RESET}"
    echo -e "  ${GREEN}${BOLD}║                                                           ║${RESET}"
    echo -e "  ${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${DIM}Useful commands:${RESET}"
    echo -e "  ${DIM}  Stop:    docker compose down${RESET}"
    echo -e "  ${DIM}  Start:   docker compose up -d${RESET}"
    echo -e "  ${DIM}  Logs:    docker compose logs -f${RESET}"
    echo -e "  ${DIM}  Models:  docker exec ollama ollama list${RESET}"
    echo ""
}

main "$@"
