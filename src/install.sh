#!/usr/bin/env bash
#
# i3-DevStack: Unified Installation Script
# Merges Justus0405's i3wm-dotfiles with developer-focused enhancements
#
# Author: Community Modified
# License: MIT

set -euo pipefail

export scriptVersion="2.0-dev"

### COLOR CODES ###
export black="\e[1;30m"
export red="\e[1;31m"
export green="\e[1;32m"
export yellow="\e[1;33m"
export blue="\e[1;34m"
export purple="\e[1;35m"
export cyan="\e[1;36m"
export lightGray="\e[1;37m"
export gray="\e[1;90m"
export lightRed="\e[1;91m"
export lightGreen="\e[1;92m"
export lightYellow="\e[1;93m"
export lightBlue="\e[1;94m"
export lightPurple="\e[1;95m"
export lightCyan="\e[1;96m"
export white="\e[1;97m"
export bold="\e[1m"
export reset="\e[0m"

### GLOBAL VARIABLES ###
directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
edition=""
selected_browsers=()
selected_dev_tools=()
selected_extras=()
installation_errors=0

### HELPER FUNCTIONS ###

log_info() {
    echo -e "${green}[$(date +%H:%M:%S)]${reset} $1"
}

log_warn() {
    echo -e "${yellow}[WARNING]${reset} $1"
}

log_error() {
    echo -e "${red}[ERROR]${reset} $1"
    ((installation_errors++))
}

safe_install_pacman() {
    local packages=("$@")
    for pkg in "${packages[@]}"; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            sudo pacman -S --needed --noconfirm "$pkg" 2>&1 | tee -a install.log || {
                log_error "Failed to install $pkg (pacman)"
            }
        fi
    done
}

safe_install_yay() {
    local packages=("$@")
    for pkg in "${packages[@]}"; do
        if ! yay -Q "$pkg" &>/dev/null; then
            yay -S --noconfirm "$pkg" 2>&1 | tee -a install.log || {
                log_error "Failed to install $pkg (AUR)"
            }
        fi
    done
}

print_header() {
    clear
    cat <<"EOF"
┌──────────────────────────────────────────────────┐
│                                                  │
│         i3-DevStack Installation Script          │
│          For Web/Software Developers             │
│                                                  │
│              Version 2.0-dev                     │
│                                                  │
└──────────────────────────────────────────────────┘

EOF
}

### MULTI-SELECT MENU ###

multi_select() {
    local title="$1"
    shift
    local options=("$@")
    local selected=()
    local cursor=0
    
    # Initialize selected array
    for i in "${!options[@]}"; do
        selected[$i]=0
    done
    
    # Save terminal settings
    local old_tty_settings=$(stty -g)
    
    while true; do
        clear
        print_header
        echo -e "${cyan}${title}${reset}"
        echo -e "${gray}Use ↑/↓ or k/j, SPACE to select, ENTER to confirm, q to skip${reset}"
        echo -e ""
        
        # Display options
        for i in "${!options[@]}"; do
            if [ $i -eq $cursor ]; then
                if [ ${selected[$i]} -eq 1 ]; then
                    echo -e "  ${green}► [✓] ${options[$i]}${reset}"
                else
                    echo -e "  ${yellow}► [ ] ${options[$i]}${reset}"
                fi
            else
                if [ ${selected[$i]} -eq 1 ]; then
                    echo -e "    ${green}[✓] ${options[$i]}${reset}"
                else
                    echo -e "    [ ] ${options[$i]}"
                fi
            fi
        done
        
        # Read a single character
        IFS= read -rsn1 key 2>/dev/null
        
        # Handle different key inputs
        case "$key" in
            $'\x1b')  # ESC sequence (arrow keys)
                # Read the next two characters
                read -rsn2 -t 0.1 key 2>/dev/null
                case "$key" in
                    '[A'|'[D')  # Up arrow or Left arrow
                        ((cursor--))
                        [ $cursor -lt 0 ] && cursor=$((${#options[@]} - 1))
                        ;;
                    '[B'|'[C')  # Down arrow or Right arrow
                        ((cursor++))
                        [ $cursor -ge ${#options[@]} ] && cursor=0
                        ;;
                esac
                ;;
            'k'|'K')  # Vim-style up
                ((cursor--))
                [ $cursor -lt 0 ] && cursor=$((${#options[@]} - 1))
                ;;
            'j'|'J')  # Vim-style down
                ((cursor++))
                [ $cursor -ge ${#options[@]} ] && cursor=0
                ;;
            ' ')  # Space to toggle selection
                if [ ${selected[$cursor]} -eq 1 ]; then
                    selected[$cursor]=0
                else
                    selected[$cursor]=1
                fi
                ;;
            'a'|'A')  # Select all
                for i in "${!options[@]}"; do
                    selected[$i]=1
                done
                ;;
            'n'|'N')  # Select none
                for i in "${!options[@]}"; do
                    selected[$i]=0
                done
                ;;
            'q'|'Q')  # Skip/Quit without selection
                REPLY=()
                stty "$old_tty_settings"
                return 0
                ;;
            '')  # Enter to confirm
                break
                ;;
        esac
    done
    
    # Restore terminal settings
    stty "$old_tty_settings"
    
    # Build result array
    REPLY=()
    for i in "${!options[@]}"; do
        if [ ${selected[$i]} -eq 1 ]; then
            REPLY+=("${options[$i]}")
        fi
    done
}

### INSTALLATION STEPS ###

confirmInstallation() {
    print_header
    cat <<"EOF"
This script will install and configure:
  • i3 Window Manager with Catppuccin theme
  • Development tools (Docker, Git, etc.)
  • Programming languages (Python, Node, Go, Rust, Java)
  • Enhanced CLI tools (bat, eza, fzf, zoxide, etc.)
  • Zsh with Starship prompt
  • Chaotic AUR for faster package installation

WARNING: This will modify system configurations!

The script will continue on errors and show a summary at the end.

EOF

    while true; do
        read -rp "Continue installation? [Y/n] " confirm
        case "${confirm}" in
        [Nn]) exitScript "Aborted!" ;;
        *) log_info "Starting installation..."; sleep 1; break ;;
        esac
    done
}

chooseProfile() {
    print_header
    
    cat <<"EOF"
Choose your installation profile:

┌────────────────────────────────────────────────────────────────┐
│ 1) Minimal                                                     │
├────────────────────────────────────────────────────────────────┤
│ • Window Manager, Login Manager, Basic Tools                  │
│ • Essential fonts, icons, audio                               │
│ • Browser: Chromium                                            │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ 2) Standard (Recommended for Developers)                      │
├────────────────────────────────────────────────────────────────┤
│ • Minimal + Calculator, Disk Utility                          │
│ • Python, Node.js (NVM), Docker                               │
│ • Enhanced CLI tools (bat, eza, fzf, lazygit)                │
│ • Browser: Brave                                               │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ 3) Full                                                        │
├────────────────────────────────────────────────────────────────┤
│ • Standard + Go, Rust, Java                                   │
│ • Media tools (GIMP, Shotcut, VLC)                            │
│ • Communication (Discord, Slack)                               │
│ • Gaming (Steam)                                               │
└────────────────────────────────────────────────────────────────┘

EOF
    
    while true; do
        read -rp "Your Choice [1-3]: " choice
        case "${choice}" in
        "1"|"minimal"|"Minimal")
            edition="0"; log_info "Installing Minimal Edition"; sleep 1; break ;;
        "2"|"standard"|"Standard")
            edition="1"; log_info "Installing Standard Edition (Recommended)"; sleep 1; break ;;
        "3"|"full"|"Full")
            edition="2"; log_info "Installing Full Edition"; sleep 1; break ;;
        *) echo -e "${red}Invalid choice${reset}" ;;
        esac
    done
}

numbered_select() {
    local title="$1"
    shift
    local options=("$@")
    
    clear
    print_header
    echo -e "${cyan}${title}${reset}"
    echo -e "${gray}Enter numbers separated by spaces (e.g., 1 3 5) or 'all' or 'none'${reset}"
    echo -e ""
    
    for i in "${!options[@]}"; do
        echo -e "  $((i+1))) ${options[$i]}"
    done
    
    echo -e ""
    read -rp "Your selection: " input
    
    REPLY=()
    
    case "$input" in
        "all"|"ALL"|"a"|"A")
            REPLY=("${options[@]}")
            ;;
        "none"|"NONE"|"n"|"N"|"")
            REPLY=()
            ;;
        *)
            for num in $input; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#options[@]} ]; then
                    REPLY+=("${options[$((num-1))]}")
                fi
            done
            ;;
    esac
}

# Modified function calls to use numbered_select as fallback
chooseBrowsers() {
    if [ "$edition" = "0" ]; then
        selected_browsers=("Chromium")
        return
    fi
    
    local browser_options=("Brave" "Firefox" "Google Chrome" "Chromium")
    
    # Try multi_select, fallback to numbered_select
    multi_select "Select browsers (at least one):" "${browser_options[@]}" 2>/dev/null || {
        log_warn "Multi-select failed, using numbered selection"
        numbered_select "Select browsers (at least one):" "${browser_options[@]}"
    }
    
    selected_browsers=("${REPLY[@]}")
    
    if [ ${#selected_browsers[@]} -eq 0 ]; then
        log_warn "No browser selected. Installing Brave by default."
        selected_browsers=("Brave")
        sleep 2
    fi
}

chooseDevTools() {
    if [ "$edition" = "0" ]; then
        return
    fi
    
    local dev_options=(
        "VS Code"
        "VS Codium"
        "Neovim"
        "Postman"
        "Insomnia"
        "DBeaver"
        "GitKraken"
        "Sublime Text 4"
        "JetBrains Mono Font"
    )
    
    # Try multi_select, fallback to numbered_select
    multi_select "Select development tools:" "${dev_options[@]}" 2>/dev/null || {
        log_warn "Multi-select failed, using numbered selection"
        numbered_select "Select development tools:" "${dev_options[@]}"
    }
    
    selected_dev_tools=("${REPLY[@]}")
}

chooseExtras() {
    if [ "$edition" = "0" ]; then
        return
    fi
    
    local extra_options=(
        "1Password"
        "Bitwarden"
        "Obsidian"
        "Slack"
        "Discord (Vesktop)"
        "Spotify"
        "VLC"
    )
    
    # Try multi_select, fallback to numbered_select
    multi_select "Select additional applications:" "${extra_options[@]}" 2>/dev/null || {
        log_warn "Multi-select failed, using numbered selection"
        numbered_select "Select additional applications:" "${extra_options[@]}"
    }
    
    selected_extras=("${REPLY[@]}")
}

setupChaoticAur() {
    print_header
    log_info "Setting up Chaotic AUR..."
    
    if grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
        log_info "Chaotic AUR already configured"
        return
    fi
    
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com 2>&1 | tee -a install.log || {
        log_error "Failed to receive Chaotic AUR key"
        return
    }
    
    sudo pacman-key --lsign-key 3056513887B78AEB 2>&1 | tee -a install.log || {
        log_error "Failed to sign Chaotic AUR key"
        return
    }
    
    sudo pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' 2>&1 | tee -a install.log || {
        log_error "Failed to install Chaotic AUR packages"
        return
    }
    
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf >/dev/null
    
    log_info "Chaotic AUR configured successfully"
}

updateSystem() {
    print_header
    log_info "Updating system..."
    
    sudo pacman -Syyu --noconfirm 2>&1 | tee -a install.log || {
        log_error "System update failed"
        return
    }
    
    log_info "System updated successfully"
}

installEssentials() {
    print_header
    log_info "Installing essential packages..."
    
    local essentials=(
        git base-devel wget curl unzip
        zsh zsh-completions zsh-autosuggestions zsh-syntax-highlighting
    )
    
    safe_install_pacman "${essentials[@]}"
    log_info "Essential packages installed"
}

handleXorgConflicts() {
    print_header
    log_info "Checking for Xorg package conflicts..."
    
    # Check if any -git versions of xorg-server are installed
    local git_packages=$(pacman -Q | grep -E 'xorg-server.*-git' | awk '{print $1}')
    
    if [ -n "$git_packages" ]; then
        echo ""
        log_warn "Found conflicting xorg-server-git packages:"
        echo "$git_packages" | while read -r pkg; do
            echo "  • $pkg"
        done
        echo ""
        echo "These conflict with the standard xorg packages."
        echo ""
        echo "Options:"
        echo "  1) Remove -git versions and install standard xorg (Recommended)"
        echo "  2) Keep -git versions and skip standard xorg installation"
        echo "  3) Abort installation"
        echo ""
        
        while true; do
            read -rp "Your choice [1-3]: " choice
            case "$choice" in
                1)
                    log_info "Removing xorg-server-git packages..."
                    echo "$git_packages" | xargs sudo pacman -Rdd --noconfirm 2>&1 | tee -a install.log || {
                        log_error "Failed to remove some -git packages"
                    }
                    return 0
                    ;;
                2)
                    log_warn "Keeping -git versions, will skip standard xorg installation"
                    return 1
                    ;;
                3)
                    exitScript "Installation aborted by user"
                    ;;
                *)
                    echo -e "${red}Invalid choice${reset}"
                    ;;
            esac
        done
    fi
    
    return 0
}

# Modified installMinimalPackages function
installMinimalPackages() {
    print_header
    log_info "Installing minimal system packages..."
    
    # Handle xorg conflicts before installation
    local install_xorg=true
    if ! handleXorgConflicts; then
        install_xorg=false
    fi
    
    local packages=(
        # Window Manager Core
        i3-wm i3status i3lock polybar rofi dunst
        
        # Login Manager
        sddm
        
        # Terminal
        alacritty kitty
        
        # File Managers
        thunar yazi
        
        # Screenshots
        flameshot maim scrot xclip xdotool
        
        # Audio
        pipewire pipewire-pulse pipewire-alsa pipewire-jack
        wireplumber pavucontrol
        
        # Network
        networkmanager network-manager-applet
        
        # Fonts
        ttf-jetbrains-mono-nerd ttf-firacode-nerd
        noto-fonts noto-fonts-emoji noto-fonts-cjk
        ttf-liberation ttf-dejavu
        
        # Icons & Themes
        papirus-icon-theme
        
        # System Utilities
        htop btop
        
        # Archives
        unrar p7zip zip
        
        # Basic productivity
        gedit

        # Font Config (fixes font rendering issues)
        fontconfig
        noto-fonts-emoji
        noto-color-emoji-fontconfig
    )
    
    # Add display packages if we're installing standard xorg
    if [ "$install_xorg" = true ]; then
        packages+=(
            # Display
            xorg-xinit picom nitrogen xorg-xrandr xorg-xset xorg-xprop
        )
    else
        # Install minimal xorg components that shouldn't conflict
        packages+=(
            xorg-xinit picom nitrogen
            xorg-xrandr xorg-xset xorg-xprop
        )
    fi
    
    safe_install_pacman "${packages[@]}"
    log_info "Minimal packages installed"
}

installStandardPackages() {
    print_header
    log_info "Installing standard packages..."
    
    local packages=(
        # System utilities
        gnome-calculator gnome-disk-utility
        
        # Enhanced CLI tools
        bat eza fd ripgrep fzf tree jq
        
        # Development essentials
        docker docker-compose
        git-lfs
        
        # Git tools
		zellij
		github-cli
        lazygit
        
        # Build tools
        cmake make gcc
        
        # Media
        mpv
        
        # Image viewer
        imv
        
        # Additional utilities
        rsync
    )
    
    safe_install_pacman "${packages[@]}"
    log_info "Standard packages installed"
}

installFullPackages() {
    print_header
    log_info "Installing full edition packages..."
    
    local packages=(
        # Media editing
        gimp inkscape
        
        # Video
        vlc kdenlive
        
        # Office
        libreoffice-fresh
        
    )
    
    safe_install_pacman "${packages[@]}"
    
    # Handle Steam separately with vulkan driver selection
    installSteamWithVulkan
    
    log_info "Full packages installed"
}

installSteamWithVulkan() {
    echo ""
    echo -e "┌────────────────────────────────────────────────────────────────┐"
    echo -e "│ Steam requires Vulkan driver selection:                        │"
    echo -e "├────────────────────────────────────────────────────────────────┤"
    echo -e "│ Nvidia      → nvidia-utils (Proprietary, Recommended)          │"
    echo -e "│ Nvidia      → vulkan-nouveau (Open-Source)                     │"
    echo -e "│ AMD         → vulkan-radeon (Open-Source, Recommended)         │"
    echo -e "│ AMD         → amdvlk (Proprietary)                              │"
    echo -e "│ Intel       → vulkan-intel (Open-Source, Recommended)          │"
    echo -e "│ VM          → vulkan-virtio (Open-Source, Recommended)         │"
    echo -e "│ Software    → vulkan-swrast (Very Slow)                        │"
    echo -e "└────────────────────────────────────────────────────────────────┘"
    echo ""
    
    safe_install_pacman steam
}

installAurHelper() {
    if command -v yay >/dev/null 2>&1; then
        log_info "yay already installed"
        return
    fi
    
    print_header
    log_info "Installing yay (AUR helper)..."
    
    cd "/tmp" || return
    rm -rf yay-bin
    git clone https://aur.archlinux.org/yay-bin.git 2>&1 | tee -a install.log || {
        log_error "Failed to clone yay repository"
        cd "${directory}" || exit 1
        return
    }
    
    cd yay-bin || return
    makepkg -si --noconfirm 2>&1 | tee -a install.log || {
        log_error "Failed to build yay"
    }
    
    cd "${directory}" || exit 1
    log_info "yay installed successfully"
}

installBrowsers() {
    if [ ${#selected_browsers[@]} -eq 0 ]; then
        return
    fi
    
    print_header
    log_info "Installing selected browsers..."
    
    for browser in "${selected_browsers[@]}"; do
        case "$browser" in
            "Brave")
                safe_install_yay brave-bin ;;
            "Firefox")
                safe_install_pacman firefox ;;
            "Google Chrome")
                safe_install_yay google-chrome ;;
            "Chromium")
                safe_install_pacman chromium ;;
        esac
    done
    
    log_info "Browsers installed"
}

installDevTools() {
    if [ ${#selected_dev_tools[@]} -eq 0 ]; then
        return
    fi
    
    print_header
    log_info "Installing development tools..."
    
    for tool in "${selected_dev_tools[@]}"; do
        case "$tool" in
            "VS Code")
                safe_install_yay visual-studio-code-bin ;;
            "VS Codium")
                safe_install_yay vscodium-bin ;;
            "Neovim")
                safe_install_pacman neovim ;;
            "Postman")
                safe_install_yay postman-bin ;;
            "Insomnia")
                safe_install_yay insomnia-bin ;;
            "DBeaver")
                safe_install_pacman dbeaver ;;
            "GitKraken")
                safe_install_yay gitkraken ;;
			"sublime-text-4")
				safe_install_yay sublime-text-4 ;;
			"ttf-jetbrains-mono")
				safe_install_yay ttf-jetbrains-mono ;;
        esac
    done
    
    log_info "Development tools installed"
}

installExtras() {
    if [ ${#selected_extras[@]} -eq 0 ]; then
        return
    fi
    
    print_header
    log_info "Installing additional applications..."
    
    for app in "${selected_extras[@]}"; do
        case "$app" in
            "1Password")
                safe_install_yay 1password ;;
            "Bitwarden")
                safe_install_pacman bitwarden ;;
            "Obsidian")
                safe_install_pacman obsidian ;;
            "Slack")
                safe_install_yay slack-desktop ;;
            "Discord (Vesktop)")
                safe_install_yay vesktop-bin ;;
            "Spotify")
                safe_install_pacman spotify-launcher ;;
            "VLC")
                safe_install_pacman vlc ;;
        esac
    done
    
    log_info "Additional applications installed"
}

setupNvm() {
    if [ "$edition" = "0" ]; then
        return
    fi
    
    print_header
    log_info "Installing NVM (Node Version Manager)..."
    
    # Temporarily disable unbound variable checking for NVM
    set +u
    
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh 2>&1 | bash | tee -a install.log || {
            log_error "Failed to install NVM"
            set -u  # Re-enable before returning
            return
        }
    fi
    
    export NVM_DIR="$HOME/.nvm"
    
    # Source NVM with error handling
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
    else
        log_error "NVM script not found"
        set -u  # Re-enable before returning
        return
    fi
    
    log_info "Installing Node.js LTS..."
    nvm install --lts 2>&1 | tee -a install.log || {
        log_error "Failed to install Node.js"
        set -u  # Re-enable before returning
        return
    }
    
    nvm use --lts 2>/dev/null || true
    nvm alias default 'lts/*' 2>/dev/null || true
    
    # Re-enable unbound variable checking
    set -u
    
    local node_version=$(node --version 2>/dev/null || echo "unknown")
    log_info "Node.js ${node_version} configured"
}

setupPython() {
    if [ "$edition" = "0" ]; then
        return
    fi
    
    print_header
    log_info "Setting up Python development environment..."
    
    safe_install_pacman python python-pip python-virtualenv python-pipenv
    
    log_info "Python environment configured"
}

setupGo() {
    if [ "$edition" != "2" ]; then
        return
    fi
    
    print_header
    log_info "Installing Go..."
    
    safe_install_pacman go
    mkdir -p "$HOME/go"/{bin,src,pkg} 2>/dev/null || true
    
    log_info "Go installed"
}

setupRust() {
    if [ "$edition" != "2" ]; then
        return
    fi
    
    print_header
    log_info "Installing Rust..."
    
    safe_install_pacman rust rust-analyzer cargo
    
    log_info "Rust installed"
}

setupJava() {
    if [ "$edition" != "2" ]; then
        return
    fi
    
    print_header
    log_info "Installing Java..."
    
    safe_install_pacman jdk-openjdk jre-openjdk maven
    
    log_info "Java installed"
}

setupDocker() {
    if [ "$edition" = "0" ]; then
        return
    fi
    
    print_header
    log_info "Configuring Docker..."
    
    sudo usermod -aG docker "$USER" 2>&1 | tee -a install.log || {
        log_error "Failed to add user to docker group"
    }
    
    sudo systemctl enable docker.service 2>&1 | tee -a install.log || log_error "Failed to enable docker service"
    sudo systemctl enable containerd.service 2>&1 | tee -a install.log || log_error "Failed to enable containerd service"
    
    safe_install_yay lazydocker
    
    log_info "Docker configured (requires logout/login to take effect)"
}

setupZsh() {
    print_header
    log_info "Setting up Zsh..."
    
    safe_install_pacman starship zoxide
    
    # Create comprehensive .zshrc
    cat > "$HOME/.zshrc" << 'EOF'
# i3-DevStack Zsh Configuration

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory sharehistory
setopt hist_ignore_all_dups hist_find_no_dups

# Completion
autoload -Uz compinit
compinit

# Case insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select

# Colors
autoload -U colors && colors

### ALIASES ###

# Enhanced CLI tools
if command -v eza &> /dev/null; then
    alias ls='eza --icons'
    alias ll='eza -l --icons --git'
    alias la='eza -la --icons --git'
    alias lt='eza --tree --icons'
    alias l='eza -lah --icons --git'
fi

if command -v bat &> /dev/null; then
    alias cat='bat --style=plain'
    alias cath='bat'
fi

if command -v fd &> /dev/null; then
    alias find='fd'
fi

if command -v rg &> /dev/null; then
    alias grep='rg'
fi

# System
alias c='clear'
alias h='history'
alias j='jobs'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git shortcuts
if command -v lazygit &> /dev/null; then
    alias lg='lazygit'
fi
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# Docker shortcuts
if command -v lazydocker &> /dev/null; then
    alias ld='lazydocker'
fi
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dcu='docker compose up'
alias dcd='docker compose down'
alias dcb='docker compose build'
alias dcl='docker compose logs -f'

# System shortcuts
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias remove='sudo pacman -R'
alias search='pacman -Ss'
alias yinstall='yay -S'
alias ysearch='yay -Ss'

# Python aliases
alias py='python'
alias py3='python3'
alias pip='python -m pip'
alias ve='python -m venv venv'
alias va='source venv/bin/activate'
alias vd='deactivate'
alias pi='pip install'
alias pir='pip install -r requirements.txt'
alias pf='pip freeze > requirements.txt'

# Development
alias e='$EDITOR'
alias v='nvim'

### FUNCTIONS ###

# Create and enter directory
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract various archive formats
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

### PATH CONFIGURATION ###

# Local bin
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Go
if command -v go &> /dev/null; then
    export GOPATH="$HOME/go"
    export PATH="$PATH:$GOPATH/bin"
fi

# Rust
if [ -d "$HOME/.cargo" ]; then
    export PATH="$PATH:$HOME/.cargo/bin"
fi

### PLUGINS & INTEGRATIONS ###

# Zsh plugins
[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Zoxide (smart cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init zsh)"
    alias cd='z'
fi

# FZF
if [ -f /usr/share/fzf/key-bindings.zsh ]; then
    source /usr/share/fzf/key-bindings.zsh
fi
if [ -f /usr/share/fzf/completion.zsh ]; then
    source /usr/share/fzf/completion.zsh
fi

# Editor
export EDITOR='nvim'
export VISUAL='nvim'

# Starship prompt (must be at the end)
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi
EOF
    
    # Set zsh as default shell
    if [ "$SHELL" != "$(which zsh)" ]; then
        chsh -s "$(which zsh)" 2>&1 | tee -a install.log || {
            log_error "Failed to set zsh as default shell"
        }
    fi
    
    log_info "Zsh configured successfully"
}

chooseInput() {
    print_header
    log_info "Input settings configuration"
    echo ""
    
    while true; do
        read -rp "Keyboard layout (us/de/de-latin1): " layout
        if sudo localectl set-keymap "${layout}" 2>&1 | tee -a install.log; then
            log_info "Keyboard layout set to ${layout}"
            break
        else
            log_error "Invalid keyboard layout"
        fi
    done
    
    echo ""
    echo -e "Input driver:"
    echo -e "  1) libinput (Recommended - Best compatibility)"
    echo -e "  2) evdev (Lower latency, limited support)"
    echo ""
    
    while true; do
        read -rp "Your choice [1-2]: " choice
        case "${choice}" in
        "1"|"libinput")
            log_info "Using libinput"
            break
            ;;
        "2"|"evdev")
            log_info "Using evdev"
            mkdir -p "$HOME/.config"
            sudo mv "/usr/share/X11/xorg.conf.d/40-libinput.conf" "$HOME/.config/" 2>/dev/null || true
            break
            ;;
        *)
            echo -e "${red}Invalid choice${reset}"
            ;;
        esac
    done
}

chooseSystemExtras() {
    print_header
    log_info "System extras configuration"
    echo ""
    
    read -rp "Add WiFi menu to top bar? [y/N]: " option
    if [[ "$option" =~ ^[Yy]$ ]]; then
        safe_install_pacman network-manager-applet
        log_info "WiFi menu enabled"
    fi
    
    echo ""
    read -rp "Add Bluetooth support? [y/N]: " option
    if [[ "$option" =~ ^[Yy]$ ]]; then
        safe_install_pacman bluez bluez-utils blueman
        sudo systemctl enable bluetooth.service 2>&1 | tee -a install.log || log_error "Failed to enable bluetooth"
        log_info "Bluetooth enabled"
    fi
    
    echo ""
    read -rp "Set CPU Governor to performance? [y/N]: " option
    if [[ "$option" =~ ^[Yy]$ ]]; then
        safe_install_pacman cpupower
        echo "governor='performance'" | sudo tee "/etc/default/cpupower" >/dev/null
        sudo systemctl enable cpupower 2>&1 | tee -a install.log || log_error "Failed to enable cpupower"
        log_info "CPU Governor set to performance"
    fi
}

copyConfigs() {
    print_header
    log_info "Installing configurations..."
    
    # Clone dotfiles if directory doesn't exist
    local dotfiles_dir="$HOME/.i3wm-dotfiles"
    if [ ! -d "$dotfiles_dir" ]; then
        git clone https://github.com/Justus0405/i3wm-dotfiles.git "$dotfiles_dir" 2>&1 | tee -a install.log || {
            log_error "Failed to clone dotfiles repository"
            return
        }
    fi
    
    cd "$dotfiles_dir" || return
    
    # Create necessary directories
    mkdir -p "$HOME/.config"/{i3,polybar,rofi,alacritty,dunst,picom,nitrogen,wallpapers}
    mkdir -p "$HOME/.local/share/themes"
    
    # Copy configurations
    if [ -d "config" ]; then
        cp -r config/* "$HOME/.config/" 2>/dev/null || true
    fi
    
    # Copy assets if they exist
    if [ -d "assets" ]; then
        [ -d "assets/gtk" ] && unzip -oq "assets/gtk/catppuccin-mocha-mauve-standard+default.zip" -d "$HOME/.local/share/themes/" 2>/dev/null || true
        [ -d "assets/gtk" ] && unzip -oq "assets/gtk/gtk-4.0.zip" -d "$HOME/.config/" 2>/dev/null || true
        [ -d "assets/sddm" ] && sudo unzip -oq "assets/sddm/catppuccin-mocha.zip" -d "/usr/share/sddm/themes/" 2>/dev/null || true
        [ -f "assets/sddm/sddm.conf" ] && sudo cp "assets/sddm/sddm.conf" "/etc/" 2>/dev/null || true
    fi
    
    # Set permissions
    chmod +x "$HOME/.config/polybar/launch.sh" 2>/dev/null || true
    chmod +x "$HOME/.config/rofi/scripts/"* 2>/dev/null || true
    
    # Configure Nemo
    gsettings set org.cinnamon.desktop.default-applications.terminal exec alacritty 2>/dev/null || true
    gsettings set org.nemo.icon-view default-zoom-level 'larger' 2>/dev/null || true
    
    # Update browser keybinding
    if [ ${#selected_browsers[@]} -gt 0 ]; then
        local first_browser="${selected_browsers[0]}"
        case "$first_browser" in
            "Brave") sed -i 's/exec chromium/exec brave/g' "$HOME/.config/i3/config" 2>/dev/null || true ;;
            "Firefox") sed -i 's/exec chromium/exec firefox/g' "$HOME/.config/i3/config" 2>/dev/null || true ;;
            "Google Chrome") sed -i 's/exec chromium/exec google-chrome-stable/g' "$HOME/.config/i3/config" 2>/dev/null || true ;;
        esac
    fi
    
    # Add pipewire group
    sudo usermod -a -G rtkit "${USER}" 2>/dev/null || true
    
    cd "${directory}" || exit 1
    log_info "Configurations installed"
}

enableServices() {
    print_header
    log_info "Enabling system services..."
    
    sudo systemctl enable NetworkManager 2>&1 | tee -a install.log || log_error "Failed to enable NetworkManager"
    sudo systemctl enable systemd-timesyncd 2>&1 | tee -a install.log || log_error "Failed to enable timesyncd"
    systemctl --user enable pipewire pipewire-pulse wireplumber 2>&1 | tee -a install.log || log_error "Failed to enable pipewire"
    sudo systemctl enable fstrim.timer 2>&1 | tee -a install.log || log_error "Failed to enable fstrim"
    sudo systemctl disable gdm 2>/dev/null || true
    sudo systemctl disable lightdm 2>/dev/null || true
    sudo systemctl enable sddm 2>&1 | tee -a install.log || log_error "Failed to enable sddm"
    
    log_info "Services enabled"
}

createReadme() {
    cat > "$HOME/i3-DEVSTACK-README.md" << 'EOF'
# i3-DevStack Installation Complete!

## Window Management Shortcuts

### Basic
- `Super + Enter`: Terminal (Alacritty)
- `Super + Q`: Close window
- `Super + D`: App launcher (Rofi)
- `Super + E`: File manager (Nemo)
- `Super + B`: Browser

### Screenshots
- `Super + N`: Screenshot selected area
- `Super + M`: Screenshot full screen

### Workspaces
- `Super + [1-9]`: Switch to workspace
- `Super + Shift + [1-9]`: Move window to workspace

### Window Layout
- `Super + H`: Split horizontal
- `Super + V`: Split vertical
- `Super + F`: Fullscreen mode
- `Super + Shift + Space`: Toggle floating

## Enhanced CLI Tools

All of these are pre-configured in your ~/.zshrc:

- `ls` → eza (better ls with icons)
- `ll` → eza -l (detailed list)
- `la` → eza -la (show hidden files)
- `cat` → bat (syntax highlighting)
- `cd` → z (smart directory jumping)
- `find` → fd (faster find)
- `grep` → rg (ripgrep)

## Development Shortcuts

### Git
- `lg` → lazygit (Git TUI)
- `gs` → git status
- `ga` → git add
- `gc` → git commit
- `gp` → git push

### Docker
- `ld` → lazydocker (Docker TUI)
- `dps` → docker ps
- `dcu` → docker compose up
- `dcd` → docker compose down

### Python
- `ve` → create virtual environment
- `va` → activate venv
- `vd` → deactivate venv
- `pi <package>` → pip install
- `pir` → pip install -r requirements.txt

## Programming Languages

### Node.js (via NVM)
```bash
nvm ls                    # List installed versions
nvm install --lts         # Install latest LTS
nvm install 20            # Install specific version
nvm use 20                # Use specific version
nvm alias default lts/*   # Set default version
```

### Go
```bash
go version               # Check version
go mod init <name>       # Initialize module
go build                 # Build project
go run main.go           # Run directly
```

### Rust
```bash
rustc --version          # Check version
cargo new <name>         # New project
cargo build              # Build project
cargo run                # Build and run
cargo test               # Run tests
```

### Java
```bash
java --version           # Check version
javac Main.java          # Compile
java Main                # Run
mvn clean install        # Maven build
gradle build             # Gradle build
```

## System Management

### Package Management
```bash
update                   # Update system (pacman -Syu)
install <pkg>            # Install package
remove <pkg>             # Remove package
search <pkg>             # Search packages
yinstall <pkg>           # Install from AUR
```

### Useful Functions
```bash
mkcd <dir>               # Create and enter directory
extract <file>           # Extract any archive format
```

## Important Notes

1. **Docker**: Requires logout/login for group changes to take effect
2. **Zsh**: Now your default shell (configured with Starship prompt)
3. **Editor**: Default is nvim (`$EDITOR`)
4. **Theme**: Catppuccin Mocha applied system-wide

## Configuration Files

- `~/.zshrc` - Shell configuration
- `~/.config/i3/config` - i3 window manager
- `~/.config/polybar/` - Status bar
- `~/.config/rofi/` - Application launcher
- `~/.config/alacritty/` - Terminal
- `~/.config/starship.toml` - Prompt (if customized)

## Next Steps

1. Reboot your system
2. Login via SDDM
3. Start developing!

## Getting Help

- i3 docs: https://i3wm.org/docs/
- Arch Wiki: https://wiki.archlinux.org/
- Check installation log: ~/install.log

Happy coding! 🚀
EOF
    
    log_info "README created at ~/i3-DEVSTACK-README.md"
}

showSummary() {
    print_header
    
    echo -e "${green}═══════════════════════════════════════════${reset}"
    echo -e "${green}     Installation Complete! 🎉${reset}"
    echo -e "${green}═══════════════════════════════════════════${reset}"
    echo ""
    
    if [ $installation_errors -gt 0 ]; then
        echo -e "${yellow}⚠ Completed with ${installation_errors} error(s)${reset}"
        echo -e "${yellow}Check install.log for details${reset}"
        echo ""
    fi
    
    echo -e "📋 Summary:"
    echo -e "  • Profile: ${cyan}$([ "$edition" = "0" ] && echo "Minimal" || [ "$edition" = "1" ] && echo "Standard" || echo "Full")${reset}"
    echo -e "  • Browsers: ${cyan}${selected_browsers[*]:-None}${reset}"
    echo -e "  • Dev Tools: ${cyan}${selected_dev_tools[*]:-None}${reset}"
    echo -e "  • Extras: ${cyan}${selected_extras[*]:-None}${reset}"
    echo ""
    echo -e "📖 Next steps:"
    echo -e "  1. Read ${cyan}~/i3-DEVSTACK-README.md${reset}"
    echo -e "  2. Reboot your system"
    echo -e "  3. Login via SDDM"
    echo -e "  4. Start developing!"
    echo ""
    echo -e "${yellow}⚠ Important:${reset}"
    echo -e "  • Log out/in for Docker group to take effect"
    echo -e "  • Default shell changed to Zsh"
    echo -e "  • Installation log saved to ~/install.log"
    echo ""
    
    read -rp "Reboot now? [y/N]: " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        log_info "Rebooting in 3 seconds..."
        sleep 3
        sudo reboot
    else
        echo -e "${cyan}Remember to reboot before using the system!${reset}"
    fi
}

exitScript() {
    echo ""
    echo -e "${red}$1${reset}"
    exit 0
}

### MAIN EXECUTION ###

trap 'exitScript "Installation cancelled!"' SIGINT

# Start installation log
echo "i3-DevStack Installation Log - $(date)" > install.log

# Execute installation steps
confirmInstallation
chooseProfile
chooseBrowsers
chooseDevTools
chooseExtras

# Core installation
setupChaoticAur
updateSystem
installEssentials
installMinimalPackages

# Profile-based installation
if [ "$edition" != "0" ]; then
    installStandardPackages
    installAurHelper
fi

if [ "$edition" = "2" ]; then
    installFullPackages
fi

# User selections
installBrowsers
installDevTools
installExtras

# Development environment setup
if [ "$edition" != "0" ]; then
    setupNvm
    setupPython
    setupDocker
fi

if [ "$edition" = "2" ]; then
    setupGo
    setupRust
    setupJava
fi

# System configuration
setupZsh
chooseInput
chooseSystemExtras
copyConfigs
enableServices
createReadme

# Final summary
showSummary