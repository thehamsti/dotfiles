#!/usr/bin/env bash
set -uo pipefail

errors=()

record_error() {
    local message="$1"
    errors+=("$message")
    if [ -n "${SETUP_ERRORS_FILE:-}" ]; then
        printf "%s\n" "$message" >> "$SETUP_ERRORS_FILE"
    fi
}

run_step() {
    local label="$1"
    shift
    echo "$label"
    if "$@"; then
        echo "  ✓ OK"
    else
        local status=$?
        echo "  ✗ Failed (exit $status)"
        record_error "$label (exit $status)"
    fi
}

# Close any open System Settings panes, to prevent them from overriding
# settings we're about to change
run_step "Closing System Settings" bash -c "osascript -e 'tell application \"System Settings\" to quit' 2>/dev/null || true"
run_step "Closing System Preferences" bash -c "osascript -e 'tell application \"System Preferences\" to quit' 2>/dev/null || true"

# Ask for the administrator password upfront
if sudo -v; then
    echo "Sudo credentials available"
else
    record_error "Sudo authentication failed"
fi

# Keep-alive: update existing `sudo` time stamp until `.macos` has finished
if sudo -n true 2>/dev/null; then
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
fi

# Disable the sound effects on boot
run_step "Disabling boot sound effects" sudo nvram SystemAudioVolume=" "

# Always show scrollbars
run_step "Always show scrollbars" defaults write NSGlobalDomain AppleShowScrollBars -string "Always"

# Expand save panel by default
run_step "Expand save panel (mode 1)" defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
run_step "Expand save panel (mode 2)" defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
run_step "Expand print panel (mode 1)" defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
run_step "Expand print panel (mode 2)" defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Disable the "Are you sure you want to open this application?" dialog
run_step "Disable app launch quarantine dialog" defaults write com.apple.LaunchServices LSQuarantine -bool false

# Enable full keyboard access for all controls (Tab in modal dialogs)
run_step "Enable full keyboard access (Tab in dialogs)" defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

## Disable annoying things
# Disable automatic capitalization as it’s annoying when typing code
run_step "Disable automatic capitalization" defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
# Disable smart dashes as they’re annoying when typing code
run_step "Disable smart dashes" defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
# Disable automatic period substitution as it’s annoying when typing code
run_step "Disable automatic period substitution" defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
# Disable smart quotes as they’re annoying when typing code
run_step "Disable smart quotes" defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
# Disable auto-correct
run_step "Disable auto-correct" defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Disable press-and-hold for keys in favor of key repeat
run_step "Disable press-and-hold for keys" defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
# Set a blazingly fast keyboard repeat rate
run_step "Set KeyRepeat" defaults write NSGlobalDomain KeyRepeat -int 1
run_step "Set InitialKeyRepeat" defaults write NSGlobalDomain InitialKeyRepeat -int 10

# Save screenshots to the desktop
run_step "Save screenshots to Desktop" defaults write com.apple.screencapture location -string "${HOME}/Desktop"
# Save screenshots in PNG format (other options: BMP, GIF, JPG, PDF, TIFF)
run_step "Save screenshots as PNG" defaults write com.apple.screencapture type -string "png"
# Finder: show hidden files by default
run_step "Finder: show hidden files" defaults write com.apple.finder AppleShowAllFiles -bool true
# Finder: show all filename extensions
run_step "Finder: show all filename extensions" defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Finder: show status bar
run_step "Finder: show status bar" defaults write com.apple.finder ShowStatusBar -bool true
# Finder: show path bar
run_step "Finder: show path bar" defaults write com.apple.finder ShowPathbar -bool true
# When performing a search, search the current folder by default
run_step "Finder: search current folder by default" defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
# Disable the warning when changing a file extension
run_step "Finder: disable extension change warning" defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
# Show the ~/Library folder
# chflags nohidden ~/Library && xattr -d com.apple.FinderInfo ~/Library
# Show the /Volumes folder
run_step "Show /Volumes folder" sudo chflags nohidden /Volumes

# Set the icon size of Dock items to 36 pixels
run_step "Dock: set icon size to 36" defaults write com.apple.dock tilesize -int 36
# Show indicator lights for open applications in the Dock
run_step "Dock: show indicator lights" defaults write com.apple.dock show-process-indicators -bool true
# Remove the auto-hiding Dock delay
run_step "Dock: remove auto-hide delay" defaults write com.apple.dock autohide-delay -float 0
# Remove the animation when hiding/showing the Dock
run_step "Dock: remove auto-hide animation" defaults write com.apple.dock autohide-time-modifier -float 0
# Automatically hide and show the Dock
run_step "Dock: enable auto-hide" defaults write com.apple.dock autohide -bool true

# Don't show recent applications in Dock
run_step "Dock: hide recent applications" defaults write com.apple.dock show-recents -bool false

# Speed up Mission Control animations
run_step "Mission Control: speed up animations" defaults write com.apple.dock expose-animation-duration -float 0.1

# Disable Dashboard
run_step "Disable Dashboard" defaults write com.apple.dashboard mcx-disabled -bool true

# Don't automatically rearrange Spaces based on most recent use
run_step "Spaces: disable auto-rearrange" defaults write com.apple.dock mru-spaces -bool false

# Hot corners: bottom-right → Mission Control
run_step "Hot corner: bottom-right = Mission Control" defaults write com.apple.dock wvous-br-corner -int 2
run_step "Hot corner: bottom-right modifier" defaults write com.apple.dock wvous-br-modifier -int 0

# Prevent Time Machine from prompting to use new hard drives as backup volume
run_step "Time Machine: disable new disk prompts" defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# Show the main window when launching Activity Monitor
run_step "Activity Monitor: show main window" defaults write com.apple.ActivityMonitor OpenMainWindow -bool true

# Visualize CPU usage in the Activity Monitor Dock icon
run_step "Activity Monitor: show CPU in Dock icon" defaults write com.apple.ActivityMonitor IconType -int 5

# Sort Activity Monitor results by CPU usage
run_step "Activity Monitor: sort by CPU usage" defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
run_step "Activity Monitor: sort direction" defaults write com.apple.ActivityMonitor SortDirection -int 0

for app in "Activity Monitor" \
    "Address Book" \
    "Calendar" \
    "cfprefsd" \
    "Contacts" \
    "Dock" \
    "Finder" \
    "Mail" \
    "Messages" \
    "Photos" \
    "Safari" \
    "SystemUIServer" \
    "Terminal" \
    "Transmission"; do
    killall "${app}" &>/dev/null || true
done
echo "Done. Note that some of these changes require a logout/restart to take effect."

if [ -z "${SETUP_ERRORS_FILE:-}" ] && ((${#errors[@]} > 0)); then
    echo ""
    echo "macOS defaults completed with errors:"
    for err in "${errors[@]}"; do
        echo "  - $err"
    done
    exit 1
fi
