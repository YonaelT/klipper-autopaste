# klipper-autopaste

A Bash script for KDE Plasma 6 that makes Klipper's history menu (Super+V) paste for you. Pick an item from the list and it is pasted straight into the window you were in, with no extra Ctrl+V. It uses Ctrl+Shift+V in terminals and Ctrl+V everywhere else.

## Features

- Auto-pastes whatever you select from the Klipper history popup
- Detects the active window and picks the right shortcut: Ctrl+Shift+V for terminals (Konsole, Alacritty, Kitty, WezTerm, foot), Ctrl+V for everything else
- Works on Wayland (KWin) and X11
- Checks for missing dependencies and offers to install them with `yay`

## Requirements

- KDE Plasma 6 with Klipper running
- `qt6-tools` (provides `qdbus-qt6`, used to talk to Klipper)
- `ydotool`, with its daemon running (injects the paste keystroke on Wayland)
- `kdotool` from the AUR (identifies the active window on Wayland)
- `xdotool` (only for X11 sessions; the dependency check does not cover it)

Used only by the automatic installer, so they're optional:

- `yay`
- `konsole`
- `notify-send`

Install on Arch:

```bash
yay -S qt6-tools ydotool kdotool
```

### ydotool setup

`ydotool` types through the kernel's input system, so it needs its background service running and permission to use it:

```bash
systemctl --user enable --now ydotool
sudo usermod -aG input $USER
```

Then log out and back in. The `input` group gives your user access to raw input devices, so only do this on a machine you control. The script's installer runs both commands for you the first time it installs `ydotool`.

## Installation

```bash
git clone https://github.com/YonaelT/klipper-autopaste.git
cd klipper-autopaste
chmod +x klipper-autopaste.sh
```

## Usage

Bind the script to Super+V in System Settings → Keyboard → Shortcuts → Add New → Command or Script, and point it at `klipper-autopaste.sh`. If Super+V is already bound to Klipper's own popup, reassign or remove that shortcut first, or the two will conflict.

Then press Super+V, pick an item, and it gets pasted.

If dependencies are missing, the first run sends a notification, opens Konsole to install them, and exits. Run it again once the installer finishes.

## How it works

1. It saves the current clipboard contents through Klipper's D-Bus interface.
2. It records the active window's class before any menu appears. This uses `kdotool` on Wayland or `xdotool` on X11, lowercased.
3. It opens Klipper's history popup at the cursor.
4. It checks the clipboard every 100 ms for up to 8 seconds. If the contents change, you picked something.
5. It waits 0.3 seconds for focus to return to your window, then sends the paste keystroke. On Wayland that's done with `ydotool key` using raw key codes: `29` is Ctrl, `42` is Shift and `47` is V, where `:1` means pressed and `:0` means released. So `29:1 47:1 47:0 29:0` is Ctrl+V, and adding `42` makes it Ctrl+Shift+V.

## Limitations

- If you pick the item that is **already** the current clipboard content, nothing changes, so no paste happens and the script times out after 8 seconds.
- Closing the menu without choosing anything also ends quietly after 8 seconds.
- Terminals are recognized by a list of window class names (`konsole`, `alacritty`, `kitty`, `wezterm`, `foot`, `terminal`). For another terminal, add its class name to the two `=~` patterns in the script.
- The change detection compares text, so it's designed for text items in the history.

## License

MIT. See [LICENSE](LICENSE).

