package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"sync"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

const (
	ViewMain = iota
	ViewInstalled
	ViewSearch
	ViewConfirm
	ViewOutput
)

var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#7aa2f7")).
			Padding(0, 1)

	subtitleStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#9aa5ce")).
			Padding(0, 1)

	helpStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#565f89")).
			Padding(0, 1)

	selectedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#7dcfff")).
			Bold(true)

	errorStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#f7768e")).
			Bold(true)

	successStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#9ece6a")).
			Bold(true)

	installedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#9ece6a")).
			Bold(true)

	repoStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#9aa5ce"))

	aurStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#f7768e")).
			Bold(true)

	chaoticStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#ff9e64")).
			Bold(true)

	coreStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#7dcfff")).
			Bold(true)

	boxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#7aa2f7")).
			Padding(0, 1)

	outputStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#c0caf5"))
)

type Package struct {
	Name        string
	Version     string
	Description string
	Repo        string
	Installed   bool
	Votes       string
}

type keyMap struct {
	Up      key.Binding
	Down    key.Binding
	Enter   key.Binding
	Back    key.Binding
	Quit    key.Binding
	Remove  key.Binding
	Refresh key.Binding
}

var keys = keyMap{
	Up: key.NewBinding(
		key.WithKeys("up", "k"),
		key.WithHelp("↑/k", "up"),
	),
	Down: key.NewBinding(
		key.WithKeys("down", "j"),
		key.WithHelp("↓/j", "down"),
	),
	Enter: key.NewBinding(
		key.WithKeys("enter"),
		key.WithHelp("enter", "select"),
	),
	Back: key.NewBinding(
		key.WithKeys("esc"),
		key.WithHelp("esc", "back"),
	),
	Quit: key.NewBinding(
		key.WithKeys("q", "ctrl+c"),
		key.WithHelp("q", "quit"),
	),
	Remove: key.NewBinding(
		key.WithKeys("d", "x"),
		key.WithHelp("d/x", "remove"),
	),
	Refresh: key.NewBinding(
		key.WithKeys("r"),
		key.WithHelp("r", "refresh"),
	),
}

type model struct {
	currentView     int
	menuCursor      int
	menuItems       []string
	packages        []Package
	selectedPkg     int
	searchInput     textinput.Model
	searchResults   []Package
	searching       bool
	message         string
	messageType     string
	confirmAction   string
	confirmPackage  string
	width           int
	height          int
	scrollOffset    int
	outputViewport  viewport.Model
	commandRunning  bool
	commandComplete bool
	commandSuccess  bool
}

type packagesMsg []Package
type searchResultsMsg []Package
type commandOutputMsg string
type commandCompleteMsg struct {
	success bool
}

func initialModel() model {
	ti := textinput.New()
	ti.Placeholder = "Type package name and press Enter..."
	ti.Focus()
	ti.CharLimit = 100
	ti.Width = 50

	vp := viewport.New(78, 20)

	return model{
		currentView: ViewMain,
		menuCursor:  0,
		menuItems: []string{
			"■ View Installed Packages",
			"⌕ Search & Install Packages",
			"↻ Update System",
			"⊗ Clean Package Cache",
			"× Exit",
		},
		searchInput:     ti,
		packages:        []Package{},
		width:           80,
		height:          24,
		scrollOffset:    0,
		searching:       false,
		outputViewport:  vp,
		commandRunning:  false,
		commandComplete: false,
	}
}

func (m model) Init() tea.Cmd {
	return textinput.Blink
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		if m.currentView == ViewOutput {
			m.outputViewport.Width = min(msg.Width-8, 100)
			m.outputViewport.Height = max(msg.Height-12, 10)
		}
		return m, nil

	case tea.KeyMsg:
		switch m.currentView {
		case ViewMain:
			return m.updateMain(msg)
		case ViewInstalled:
			return m.updateInstalled(msg)
		case ViewSearch:
			return m.updateSearch(msg)
		case ViewConfirm:
			return m.updateConfirm(msg)
		case ViewOutput:
			return m.updateOutput(msg)
		}

	case packagesMsg:
		m.packages = []Package(msg)
		m.selectedPkg = 0
		m.scrollOffset = 0
		m.currentView = ViewInstalled
		return m, nil

	case searchResultsMsg:
		m.searchResults = []Package(msg)
		m.selectedPkg = 0
		m.scrollOffset = 0
		m.searching = false
		return m, nil

	case commandOutputMsg:
		m.outputViewport.SetContent(m.outputViewport.View() + string(msg))
		m.outputViewport.GotoBottom()
		return m, nil

	case commandCompleteMsg:
		m.commandRunning = false
		m.commandComplete = true
		m.commandSuccess = msg.success
		return m, nil
	}

	return m, nil
}

func (m model) updateMain(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch {
	case key.Matches(msg, keys.Quit):
		return m, tea.Quit

	case key.Matches(msg, keys.Up):
		if m.menuCursor > 0 {
			m.menuCursor--
		}

	case key.Matches(msg, keys.Down):
		if m.menuCursor < len(m.menuItems)-1 {
			m.menuCursor++
		}

	case key.Matches(msg, keys.Enter):
		switch m.menuCursor {
		case 0: // View installed
			return m, loadInstalledPackages
		case 1: // Search
			m.currentView = ViewSearch
			m.searchInput.Focus()
			m.searchResults = []Package{}
			m.selectedPkg = 0
			m.searching = false
			return m, textinput.Blink
		case 2: // Update
			m.confirmAction = "update"
			m.confirmPackage = "system"
			m.currentView = ViewConfirm
		case 3: // Clean
			m.confirmAction = "clean"
			m.confirmPackage = "cache"
			m.currentView = ViewConfirm
		case 4: // Exit
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m model) updateInstalled(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	maxVisible := max(m.height-12, 5)

	switch {
	case key.Matches(msg, keys.Back):
		m.currentView = ViewMain
		m.message = ""
		return m, nil

	case key.Matches(msg, keys.Quit):
		return m, tea.Quit

	case key.Matches(msg, keys.Up):
		if m.selectedPkg > 0 {
			m.selectedPkg--
			if m.selectedPkg < m.scrollOffset {
				m.scrollOffset = m.selectedPkg
			}
		}

	case key.Matches(msg, keys.Down):
		if m.selectedPkg < len(m.packages)-1 {
			m.selectedPkg++
			if m.selectedPkg >= m.scrollOffset+maxVisible {
				m.scrollOffset = m.selectedPkg - maxVisible + 1
			}
		}

	case key.Matches(msg, keys.Remove):
		if len(m.packages) > 0 {
			pkg := m.packages[m.selectedPkg]
			m.confirmAction = "remove"
			m.confirmPackage = pkg.Name
			m.currentView = ViewConfirm
		}

	case key.Matches(msg, keys.Refresh):
		return m, loadInstalledPackages
	}

	return m, nil
}

func (m model) updateSearch(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	maxVisible := max(m.height-14, 5)

	switch {
	case key.Matches(msg, keys.Back):
		m.currentView = ViewMain
		m.searchInput.SetValue("")
		m.searchResults = []Package{}
		m.searching = false
		return m, nil

	case key.Matches(msg, keys.Quit):
		return m, tea.Quit

	case key.Matches(msg, keys.Enter):
		if len(m.searchResults) > 0 && m.selectedPkg < len(m.searchResults) {
			// Install selected package
			pkg := m.searchResults[m.selectedPkg]
			m.confirmAction = "install"
			m.confirmPackage = pkg.Name
			m.currentView = ViewConfirm
			return m, nil
		}
		// Perform search
		query := strings.TrimSpace(m.searchInput.Value())
		if query != "" && !m.searching {
			m.searching = true
			return m, searchPackages(query)
		}

	case key.Matches(msg, keys.Up):
		if m.selectedPkg > 0 {
			m.selectedPkg--
			if m.selectedPkg < m.scrollOffset {
				m.scrollOffset = m.selectedPkg
			}
		}

	case key.Matches(msg, keys.Down):
		if m.selectedPkg < len(m.searchResults)-1 {
			m.selectedPkg++
			if m.selectedPkg >= m.scrollOffset+maxVisible {
				m.scrollOffset = m.selectedPkg - maxVisible + 1
			}
		}
	}

	m.searchInput, cmd = m.searchInput.Update(msg)
	return m, cmd
}

func (m model) updateConfirm(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "y", "Y":
		// Switch to output view
		m.currentView = ViewOutput
		m.outputViewport.SetContent("")
		m.outputViewport.Width = min(m.width-8, 100)
		m.outputViewport.Height = max(m.height-12, 10)
		m.commandRunning = true
		m.commandComplete = false
		return m, runCommand(m.confirmAction, m.confirmPackage)

	case "n", "N", "esc":
		if m.confirmAction == "install" {
			m.currentView = ViewSearch
		} else {
			m.currentView = ViewMain
		}
		return m, nil

	case "q", "ctrl+c":
		return m, tea.Quit
	}
	return m, nil
}

func (m model) updateOutput(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	switch {
	case key.Matches(msg, keys.Quit):
		if !m.commandRunning {
			return m, tea.Quit
		}

	case key.Matches(msg, keys.Back), key.Matches(msg, keys.Enter):
		if !m.commandRunning {
			if m.commandSuccess {
				m.messageType = "success"
				m.message = "Operation completed successfully"
			} else {
				m.messageType = "error"
				m.message = "Operation failed"
			}
			m.currentView = ViewMain
		}
		return m, nil

	case key.Matches(msg, keys.Up):
		m.outputViewport.LineUp(1)

	case key.Matches(msg, keys.Down):
		m.outputViewport.LineDown(1)
	}

	m.outputViewport, cmd = m.outputViewport.Update(msg)
	return m, cmd
}

func (m model) View() string {
	contentWidth := max(m.width-8, 40)

	switch m.currentView {
	case ViewMain:
		return m.viewMain(contentWidth)
	case ViewInstalled:
		return m.viewInstalled(contentWidth)
	case ViewSearch:
		return m.viewSearch(contentWidth)
	case ViewConfirm:
		return m.viewConfirm(contentWidth)
	case ViewOutput:
		return m.viewOutput(contentWidth)
	}
	return ""
}

func (m model) viewMain(width int) string {
	var s strings.Builder

	s.WriteString(titleStyle.Render("■ i3-DevStack Package Manager"))
	s.WriteString("\n")
	s.WriteString(subtitleStyle.Render("Manage your system packages with ease"))
	s.WriteString("\n\n")

	if m.message != "" {
		switch m.messageType {
		case "error":
			s.WriteString(errorStyle.Render("✗ " + truncate(m.message, width-4)))
		case "success":
			s.WriteString(successStyle.Render("✓ " + truncate(m.message, width-4)))
		}
		s.WriteString("\n\n")
		m.message = ""
	}

	for i, item := range m.menuItems {
		cursor := "  "
		if m.menuCursor == i {
			cursor = "▶ "
			item = selectedStyle.Render(item)
		}
		s.WriteString(cursor + item + "\n")
	}

	s.WriteString("\n")
	s.WriteString(helpStyle.Render("↑/↓: navigate • enter: select • q: quit"))

	return boxStyle.Width(min(width, 70)).Render(s.String())
}

func (m model) viewInstalled(width int) string {
	var s strings.Builder

	s.WriteString(titleStyle.Render("■ Installed Packages"))
	s.WriteString("\n")
	s.WriteString(subtitleStyle.Render(fmt.Sprintf("Total: %d packages", len(m.packages))))
	s.WriteString("\n\n")

	if len(m.packages) == 0 {
		s.WriteString(errorStyle.Render("Loading packages..."))
		s.WriteString("\n")
	} else {
		maxVisible := max(m.height-12, 5)
		end := min(m.scrollOffset+maxVisible, len(m.packages))

		nameWidth := min(35, width/3)
		versionWidth := min(18, width/4)

		for i := m.scrollOffset; i < end; i++ {
			pkg := m.packages[i]
			cursor := "  "

			if i == m.selectedPkg {
				cursor = "▶ "
			}

			name := truncate(pkg.Name, nameWidth)
			if i == m.selectedPkg {
				name = selectedStyle.Render(name)
			}

			version := truncate(pkg.Version, versionWidth)
			version = lipgloss.NewStyle().Foreground(lipgloss.Color("#9aa5ce")).Render(version)

			repoDisplay := formatRepo(pkg.Repo)

			s.WriteString(fmt.Sprintf("%s%-*s %-*s %s\n",
				cursor, nameWidth, name, versionWidth, version, repoDisplay))
		}

		if len(m.packages) > maxVisible {
			s.WriteString("\n")
			s.WriteString(subtitleStyle.Render(fmt.Sprintf("[%d-%d of %d]",
				m.scrollOffset+1, end, len(m.packages))))
		}
	}

	s.WriteString("\n")
	s.WriteString(helpStyle.Render("↑/↓: scroll • d: remove • r: refresh • esc: back • q: quit"))

	return boxStyle.Width(min(width, 90)).Render(s.String())
}

func (m model) viewSearch(width int) string {
	var s strings.Builder

	s.WriteString(titleStyle.Render("⌕ Search Packages"))
	s.WriteString("\n")
	s.WriteString(subtitleStyle.Render("Official repos, chaotic-aur, and AUR"))
	s.WriteString("\n\n")

	m.searchInput.Width = min(width-4, 60)
	s.WriteString(m.searchInput.View())
	s.WriteString("\n")

	if m.searching {
		s.WriteString("\n")
		s.WriteString(subtitleStyle.Render("Searching..."))
		s.WriteString("\n")
	} else if len(m.searchResults) > 0 {
		s.WriteString("\n")
		s.WriteString(subtitleStyle.Render(fmt.Sprintf("Found %d packages:", len(m.searchResults))))
		s.WriteString("\n\n")

		maxVisible := max(m.height-15, 5)
		end := min(m.scrollOffset+maxVisible, len(m.searchResults))

		nameWidth := min(30, width/3)
		versionWidth := min(15, width/5)

		for i := m.scrollOffset; i < end; i++ {
			pkg := m.searchResults[i]
			cursor := "  "

			name := truncate(pkg.Name, nameWidth)
			if i == m.selectedPkg {
				cursor = "▶ "
				name = selectedStyle.Render(name)
			}

			version := truncate(pkg.Version, versionWidth)
			version = lipgloss.NewStyle().Foreground(lipgloss.Color("#9aa5ce")).Render(version)

			repoDisplay := formatRepo(pkg.Repo)

			installedMark := ""
			if pkg.Installed {
				installedMark = " " + installedStyle.Render("✓")
			}

			extraInfo := ""
			if strings.Contains(strings.ToLower(pkg.Repo), "aur") && pkg.Votes != "" {
				voteStr := truncate(pkg.Votes, 15)
				extraInfo = lipgloss.NewStyle().
					Foreground(lipgloss.Color("#565f89")).
					Render(fmt.Sprintf(" (%s)", voteStr))
			}

			s.WriteString(fmt.Sprintf("%s%-*s %-*s %s%s%s\n",
				cursor, nameWidth, name, versionWidth, version,
				repoDisplay, installedMark, extraInfo))

			if i == m.selectedPkg && pkg.Description != "" {
				desc := truncate(pkg.Description, width-6)
				desc = lipgloss.NewStyle().
					Foreground(lipgloss.Color("#565f89")).
					Italic(true).
					Render("   " + desc)
				s.WriteString(desc + "\n")
			}
		}

		if len(m.searchResults) > maxVisible {
			s.WriteString("\n")
			s.WriteString(subtitleStyle.Render(fmt.Sprintf("[%d-%d of %d]",
				m.scrollOffset+1, end, len(m.searchResults))))
		}
	} else if m.searchInput.Value() != "" && !m.searching {
		s.WriteString("\n")
		s.WriteString(subtitleStyle.Render("No results. Try a different search."))
	} else {
		s.WriteString("\n")
		s.WriteString(subtitleStyle.Render("Type package name and press Enter..."))
	}

	s.WriteString("\n")
	s.WriteString(helpStyle.Render("↑/↓: scroll • enter: install • esc: back • q: quit"))

	return boxStyle.Width(min(width, 90)).Render(s.String())
}

func (m model) viewConfirm(width int) string {
	var s strings.Builder

	s.WriteString(titleStyle.Render("⚠ Confirmation Required"))
	s.WriteString("\n\n")

	switch m.confirmAction {
	case "remove":
		s.WriteString(errorStyle.Render("Remove: " + m.confirmPackage))
		s.WriteString("\n\n")
		s.WriteString(subtitleStyle.Render("Command: "))
		s.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("#565f89")).
			Render(fmt.Sprintf("sudo pacman -R %s", m.confirmPackage)))
	case "install":
		s.WriteString(successStyle.Render("Install: " + m.confirmPackage))
		s.WriteString("\n\n")
		s.WriteString(subtitleStyle.Render("Command: "))
		s.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("#565f89")).
			Render(fmt.Sprintf("yay -S %s", m.confirmPackage)))
	case "update":
		s.WriteString(selectedStyle.Render("Update entire system"))
		s.WriteString("\n\n")
		s.WriteString(subtitleStyle.Render("Command: "))
		s.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("#565f89")).
			Render("yay -Syu"))
	case "clean":
		s.WriteString(selectedStyle.Render("Clean package cache"))
		s.WriteString("\n\n")
		s.WriteString(subtitleStyle.Render("Command: "))
		s.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("#565f89")).
			Render("sudo pacman -Sc"))
	}

	s.WriteString("\n\n")
	s.WriteString(helpStyle.Render("y: confirm • n/esc: cancel"))

	return boxStyle.Width(min(width, 60)).Render(s.String())
}

func (m model) viewOutput(width int) string {
	var s strings.Builder

	s.WriteString(titleStyle.Render("▣ Command Output"))
	s.WriteString("\n\n")

	s.WriteString(boxStyle.Width(min(width, 100)).Render(m.outputViewport.View()))
	s.WriteString("\n")

	if m.commandRunning {
		s.WriteString(helpStyle.Render("↑/↓: scroll • Command running..."))
	} else {
		if m.commandSuccess {
			s.WriteString(successStyle.Render("✓ Command completed successfully"))
		} else {
			s.WriteString(errorStyle.Render("✗ Command failed"))
		}
		s.WriteString("\n")
		s.WriteString(helpStyle.Render("↑/↓: scroll • enter/esc: back to menu"))
	}

	return s.String()
}

func formatRepo(repo string) string {
	repo = strings.ToLower(strings.TrimSpace(repo))
	switch {
	case strings.Contains(repo, "aur"):
		return aurStyle.Render("[AUR]")
	case strings.Contains(repo, "chaotic"):
		return chaoticStyle.Render("[chaotic]")
	case repo == "core":
		return coreStyle.Render("[core]")
	case repo == "extra":
		return lipgloss.NewStyle().Foreground(lipgloss.Color("#7aa2f7")).Render("[extra]")
	case repo == "multilib":
		return lipgloss.NewStyle().Foreground(lipgloss.Color("#bb9af7")).Render("[multi]")
	case repo == "community":
		return lipgloss.NewStyle().Foreground(lipgloss.Color("#9ece6a")).Render("[comm]")
	default:
		if repo != "" {
			return repoStyle.Render(fmt.Sprintf("[%s]", truncate(repo, 8)))
		}
		return repoStyle.Render("[local]")
	}
}

func truncate(s string, max int) string {
	if len(s) <= max {
		return s
	}
	if max < 3 {
		return s[:max]
	}
	return s[:max-3] + "..."
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// Commands

func loadInstalledPackages() tea.Msg {
	cmd := exec.Command("bash", "-c", "pacman -Q")
	output, err := cmd.Output()
	if err != nil {
		return packagesMsg([]Package{})
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	packages := make([]Package, 0, len(lines))

	for _, line := range lines {
		if line == "" {
			continue
		}
		parts := strings.Fields(line)
		if len(parts) >= 2 {
			repoCmd := exec.Command("bash", "-c", fmt.Sprintf("pacman -Si %s 2>/dev/null | grep '^Repository' | awk '{print $3}'", parts[0]))
			repoOutput, _ := repoCmd.Output()
			repo := strings.TrimSpace(string(repoOutput))
			if repo == "" {
				repo = "local"
			}

			packages = append(packages, Package{
				Name:      parts[0],
				Version:   parts[1],
				Repo:      repo,
				Installed: true,
			})
		}
	}

	return packagesMsg(packages)
}

func searchPackages(query string) tea.Cmd {
	return func() tea.Msg {
		installedCmd := exec.Command("pacman", "-Q")
		installedOutput, _ := installedCmd.Output()
		installedMap := make(map[string]bool)
		for _, line := range strings.Split(string(installedOutput), "\n") {
			parts := strings.Fields(line)
			if len(parts) > 0 {
				installedMap[parts[0]] = true
			}
		}

		// Search official repos first
		officialCmd := exec.Command("pacman", "-Ss", query)
		officialOutput, _ := officialCmd.Output()

		// Then search AUR
		aurCmd := exec.Command("yay", "-Ssa", query)
		aurOutput, _ := aurCmd.Output()

		// Parse both outputs
		officialPkgs := parsePacmanOutput(string(officialOutput), installedMap)
		aurPkgs := parseYayOutput(string(aurOutput), installedMap)

		// Combine and deduplicate (official repos first)
		pkgMap := make(map[string]Package)
		for _, pkg := range officialPkgs {
			pkgMap[pkg.Name] = pkg
		}
		for _, pkg := range aurPkgs {
			if _, exists := pkgMap[pkg.Name]; !exists {
				pkgMap[pkg.Name] = pkg
			}
		}

		// Convert back to slice
		packages := make([]Package, 0, len(pkgMap))
		for _, pkg := range pkgMap {
			packages = append(packages, pkg)
		}

		return searchResultsMsg(packages)
	}
}

func parsePacmanOutput(output string, installedMap map[string]bool) []Package {
	packages := []Package{}
	lines := strings.Split(output, "\n")

	pkgLineRegex := regexp.MustCompile(`^([a-z0-9\-]+)/([a-z0-9\-_.+]+)\s+([^\s]+)(.*)$`)

	i := 0
	for i < len(lines) {
		line := strings.TrimSpace(lines[i])

		if line == "" {
			i++
			continue
		}

		matches := pkgLineRegex.FindStringSubmatch(line)
		if matches == nil {
			i++
			continue
		}

		repo := matches[1]
		name := matches[2]
		version := matches[3]
		rest := matches[4]

		installed := installedMap[name] || strings.Contains(rest, "[installed]")

		description := ""
		if i+1 < len(lines) {
			nextLine := lines[i+1]
			if len(nextLine) > 0 && (nextLine[0] == ' ' || nextLine[0] == '\t') {
				description = strings.TrimSpace(nextLine)
				i++
			}
		}

		packages = append(packages, Package{
			Name:        name,
			Version:     version,
			Description: description,
			Repo:        repo,
			Installed:   installed,
		})

		i++
	}

	return packages
}

func parseYayOutput(output string, installedMap map[string]bool) []Package {
	packages := []Package{}
	lines := strings.Split(output, "\n")

	pkgLineRegex := regexp.MustCompile(`^([a-z0-9\-]+)/([a-z0-9\-_.+]+)\s+([^\s]+)(.*)$`)

	i := 0
	for i < len(lines) {
		line := strings.TrimSpace(lines[i])

		if line == "" {
			i++
			continue
		}

		matches := pkgLineRegex.FindStringSubmatch(line)
		if matches == nil {
			i++
			continue
		}

		repo := matches[1]
		name := matches[2]
		version := matches[3]
		rest := matches[4]

		installed := installedMap[name] || strings.Contains(rest, "[installed]")

		votes := ""
		voteRegex := regexp.MustCompile(`\(([^)]+)\)`)
		if voteMatch := voteRegex.FindStringSubmatch(rest); voteMatch != nil {
			votes = voteMatch[1]
		}

		description := ""
		if i+1 < len(lines) {
			nextLine := lines[i+1]
			if len(nextLine) > 0 && (nextLine[0] == ' ' || nextLine[0] == '\t') {
				description = strings.TrimSpace(nextLine)
				i++
			}
		}

		packages = append(packages, Package{
			Name:        name,
			Version:     version,
			Description: description,
			Repo:        repo,
			Installed:   installed,
			Votes:       votes,
		})

		i++
	}

	return packages
}

func runCommand(action, pkgName string) tea.Cmd {
	return func() tea.Msg {
		var cmd *exec.Cmd

		switch action {
		case "remove":
			cmd = exec.Command("sudo", "pacman", "-R", pkgName)
		case "install":
			cmd = exec.Command("yay", "-S", "--noconfirm", pkgName)
		case "update":
			cmd = exec.Command("yay", "-Syu", "--noconfirm")
		case "clean":
			cmd = exec.Command("sudo", "pacman", "-Sc", "--noconfirm")
		default:
			return commandCompleteMsg{success: false}
		}

		stdout, _ := cmd.StdoutPipe()
		stderr, _ := cmd.StderrPipe()

		if err := cmd.Start(); err != nil {
			return commandCompleteMsg{success: false}
		}

		// Read output in goroutine
		var wg sync.WaitGroup
		wg.Add(2)

		go func() {
			defer wg.Done()
			scanner := bufio.NewScanner(stdout)
			for scanner.Scan() {
				// Send output back to UI (simplified - in real app use proper channel)
				fmt.Print(scanner.Text() + "\n")
			}
		}()

		go func() {
			defer wg.Done()
			scanner := bufio.NewScanner(stderr)
			for scanner.Scan() {
				fmt.Print(scanner.Text() + "\n")
			}
		}()

		wg.Wait()
		err := cmd.Wait()

		return commandCompleteMsg{success: err == nil}
	}
}

func streamCommandOutput(cmd *exec.Cmd, p *tea.Program) {
	stdout, _ := cmd.StdoutPipe()
	stderr, _ := cmd.StderrPipe()

	go func() {
		reader := io.MultiReader(stdout, stderr)
		scanner := bufio.NewScanner(reader)
		for scanner.Scan() {
			p.Send(commandOutputMsg(scanner.Text() + "\n"))
		}
	}()
}

func main() {
	p := tea.NewProgram(initialModel(), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
}
