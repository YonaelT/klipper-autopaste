#!/bin/bash
# ==============================================================================
# Script Name:  klipper-autopaste.sh
# Description:  Modifies KDE Plasma 6 Klipper history behavior so that selecting 
#               an item from Super+V automatically pastes it.
# Features:     Detects active window classes on Wayland/KWin and automatically 
#               switches between Ctrl+V and terminal-friendly Ctrl+Shift+V.
#               Auto-detects and installs missing dependencies via yay.
# Dependencies: qt6-tools (for qdbus-qt6)
#               ydotool (for kernel-level key injection)
#               kdotool (from AUR, for Wayland window matching)
# ==============================================================================

# --- DEPENDENCY CHECK & AUTO-INSTALLER ---
MISSING_DEPS=()

# 1. Check for D-Bus components (provided by qt6-tools)
if ! command -v qdbus-qt6 &>/dev/null && ! command -v qdbus6 &>/dev/null && ! command -v qdbus &>/dev/null; then
    MISSING_DEPS+=("qt6-tools")
fi

# 2. Check for ydotool
if ! command -v ydotool &>/dev/null; then
    MISSING_DEPS+=("ydotool")
fi

# 3. Check for kdotool (AUR package)
if ! command -v kdotool &>/dev/null; then
    MISSING_DEPS+=("kdotool")
fi

# If dependencies are missing, launch an interactive installation terminal
if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    if command -v notify-send &>/dev/null; then
        notify-send "Klipper Auto-Paste" "Missing dependencies detected: ${MISSING_DEPS[*]}. Launching installer..." -i system-software-update
    fi
    
    # Open Konsole to execute the installation with yay
    konsole -e bash -c "echo '=> Installing missing components for Klipper Auto-Paste...'; yay -S --needed ${MISSING_DEPS[*]}; echo '=> Setup complete! Press any key to close.'; read -n 1"
    
    # Extra setup if ydotool was just installed (Space fixed here!)
    if [[ " ${MISSING_DEPS[*]} " == *"ydotool"* ]]; then
        systemctl --user enable --now ydotool
        sudo usermod -aG input $USER
        if command -v notify-send &>/dev/null; then
            notify-send "Klipper Auto-Paste" "ydotool installed. Please log out and back in for permissions to take effect!" -u critical
        fi
    fi
    exit 1
fi
# ----------------------------------------

# 0. Find the correct D-Bus utility binary for Plasma 6
if command -v qdbus-qt6 >/dev/null 2>&1; then
    QDBUS="qdbus-qt6"
elif command -v qdbus6 >/dev/null 2>&1; then
    QDBUS="qdbus6"
else
    QDBUS="qdbus"
fi

# 1. Grab current clipboard content
OLD_CLIP=$($QDBUS org.kde.klipper /klipper getClipboardContents)

# 2. Fingerprint the active window BEFORE popping up the menu
WINDOW_CLASS=""
if [ "$XDG_SESSION_TYPE" = "wayland" ] && command -v kdotool &>/dev/null; then
    ACTIVE_WIN=$(kdotool getactivewindow)
    WINDOW_CLASS=$(kdotool getwindowclassname "$ACTIVE_WIN" 2>/dev/null | tr '[:upper:]' '[:lower:]')
elif [ "$XDG_SESSION_TYPE" = "x11" ] && command -v xdotool &>/dev/null; then
    WINDOW_CLASS=$(xdotool getactivewindow getwindowclassname 2>/dev/null | tr '[:upper:]' '[:lower:]')
fi

# 3. Pop up the native Klipper history menu right at your cursor
$QDBUS org.kde.klipper /klipper showKlipperPopupMenu

# 4. Monitor for a change (loops every 100ms, times out after 8 seconds)
for i in {1..80}; do
    sleep 0.1
    NEW_CLIP=$($QDBUS org.kde.klipper /klipper getClipboardContents)
    
    # If the text changed, it means you picked an item from history!
    if [ "$NEW_CLIP" != "$OLD_CLIP" ]; then
        # Give KWin adequate time to return focus to the target window
        sleep 0.3
        
        # 5. Fire off the contextual paste command
        if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
            if [[ "$WINDOW_CLASS" =~ (konsole|alacritty|kitty|wezterm|foot|terminal) ]]; then
                ydotool key 29:1 42:1 47:1 47:0 42:0 29:0
            else
                ydotool key 29:1 47:1 47:0 29:0
            fi
        else
            if [[ "$WINDOW_CLASS" =~ (konsole|alacritty|kitty|wezterm|foot|terminal) ]]; then
                xdotool key ctrl+shift+v
            else
                xdotool key ctrl+v
            fi
        fi
        exit 0
    fi
done
