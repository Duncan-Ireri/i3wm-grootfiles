#!/usr/bin/env bash
# Setup script for pkgman - i3-DevStack Package Manager

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Setting up pkgman - i3-DevStack Package Manager${NC}"
echo ""

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "Installing Go..."
    sudo pacman -S --needed go
fi

echo -e "${GREEN}✓ Go installed${NC}"

# Create project directory
PROJECT_DIR="$HOME/.local/src/pkgman"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Create go.mod
cat > go.mod << 'EOF'
module pkgman

go 1.21

require (
	github.com/charmbracelet/bubbles v0.18.0
	github.com/charmbracelet/bubbletea v0.25.0
	github.com/charmbracelet/lipgloss v0.9.1
)

require (
	github.com/atotto/clipboard v0.1.4 // indirect
	github.com/aymanbagabas/go-osc52/v2 v2.0.1 // indirect
	github.com/containerd/console v1.0.4-0.20230313162750-1ae8d489ac81 // indirect
	github.com/lucasb-eyer/go-colorful v1.2.0 // indirect
	github.com/mattn/go-isatty v0.0.20 // indirect
	github.com/mattn/go-localereader v0.0.1 // indirect
	github.com/mattn/go-runewidth v0.0.15 // indirect
	github.com/muesli/ansi v0.0.0-20211018074035-2e021307bc4b // indirect
	github.com/muesli/cancelreader v0.2.2 // indirect
	github.com/muesli/reflow v0.3.0 // indirect
	github.com/muesli/termenv v0.15.2 // indirect
	github.com/rivo/uniseg v0.4.4 // indirect
	github.com/sahilm/fuzzy v0.1.1-0.20230530133925-c48e322e2a8f // indirect
	golang.org/x/sync v0.3.0 // indirect
	golang.org/x/sys v0.12.0 // indirect
	golang.org/x/term v0.6.0 // indirect
	golang.org/x/text v0.3.8 // indirect
)
EOF

echo -e "${GREEN}✓ go.mod created${NC}"

# Copy the main.go from the artifact
cat > main.go << 'MAINEOF'
// The main.go content goes here - user should paste the code from the artifact
MAINEOF

# Create Makefile
cat > Makefile << 'EOF'
.PHONY: build install clean run

BINARY_NAME=pkgman
INSTALL_PATH=$(HOME)/.local/bin

build:
	@echo "Building $(BINARY_NAME)..."
	@go build -o $(BINARY_NAME) main.go
	@echo "✓ Build complete"

install: build
	@echo "Installing to $(INSTALL_PATH)..."
	@mkdir -p $(INSTALL_PATH)
	@cp $(BINARY_NAME) $(INSTALL_PATH)/
	@chmod +x $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "✓ Installed successfully"
	@echo ""
	@echo "Run 'pkgman' to start the package manager"

clean:
	@echo "Cleaning..."
	@rm -f $(BINARY_NAME)
	@echo "✓ Clean complete"

run: build
	@./$(BINARY_NAME)

uninstall:
	@echo "Uninstalling..."
	@rm -f $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "✓ Uninstalled"
EOF

echo -e "${GREEN}✓ Makefile created${NC}"

# Create README
cat > README.md << 'EOF'
# pkgman - i3-DevStack Package Manager

A beautiful TUI package manager for Arch Linux built with Go and Bubble Tea.

## Features

- 📦 View all installed packages
- 🔍 Search and install from AUR
- ❌ Remove packages
- 🔄 System updates
- 🧹 Clean package cache
- ⌨️ Keyboard-driven interface
- 🎨 Beautiful UI with syntax highlighting

## Installation

1. **Ensure Go is installed:**
   ```bash
   sudo pacman -S go
   ```

2. **Build and install:**
   ```bash
   make install
   ```

3. **Run:**
   ```bash
   pkgman
   ```

## Usage

### Main Menu
- `↑/↓` or `k/j` - Navigate menu
- `Enter` - Select option
- `q` - Quit

### Installed Packages View
- `↑/↓` or `k/j` - Navigate packages
- `d` or `x` - Remove selected package
- `r` - Refresh package list
- `Esc` - Back to main menu
- `q` - Quit

### Search AUR
- Type to search
- `Enter` - Install selected package
- `↑/↓` - Navigate results
- `Esc` - Back to main menu

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `↑/↓` or `k/j` | Navigate |
| `Enter` | Select/Confirm |
| `Esc` | Go back |
| `q` | Quit |
| `d` or `x` | Remove package |
| `r` | Refresh list |
| `/` | Search AUR |

## Requirements

- Arch Linux (or Arch-based distro)
- `pacman` package manager
- `yay` AUR helper
- Go 1.21 or higher

## Development

```bash
# Run without installing
make run

# Build only
make build

# Clean build artifacts
make clean

# Uninstall
make uninstall
```

## Dependencies

- [Bubble Tea](https://github.com/charmbracelet/bubbletea) - TUI framework
- [Bubbles](https://github.com/charmbracelet/bubbles) - TUI components
- [Lip Gloss](https://github.com/charmbracelet/lipgloss) - Style definitions

## Color Scheme

The UI uses the Tokyo Night color palette for consistency with i3-DevStack.

## Troubleshooting

### "yay: command not found"
Install yay first:
```bash
cd /tmp
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si
```

### Permission errors
Make sure you have sudo privileges configured correctly.

## License

MIT

## Part of i3-DevStack

This tool is part of the i3-DevStack project - a developer-focused Arch Linux setup.
EOF

echo -e "${GREEN}✓ README.md created${NC}"

# Download dependencies
echo ""
echo "Downloading dependencies..."
go mod download
echo -e "${GREEN}✓ Dependencies downloaded${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Copy the main.go code from the artifact"
echo "  2. Run: make install"
echo "  3. Run: pkgman"
echo ""
echo "Project location: $PROJECT_DIR"
echo -e "${BLUE}═══════════════════════════════════════${NC}"