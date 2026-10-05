# klipper-autopaste

A Bash script for KDE Plasma 6 that makes Klipper's history menu (Super+V) paste for you. Pick an item from the list and it is pasted straight into the window you were in, with no extra Ctrl+V. It uses Ctrl+Shift+V in terminals and Ctrl+V everywhere else.

> [!IMPORTANT]
> **This script does nothing without a working `ydotool`.** The `ydotool` service must be running and your user must be in the `input` group. If the menu appears but nothing gets pasted, this is almost always why. Follow the setup below, in order.

## Setup (do this first)

**1. Install the dependencies**

```bash
yay -S qt6-tools ydotool kdotool
```

**2. Start the ydotool service and add yourself to the `input` group**

```bash
systemctl --user enable --now ydotool
sudo usermod -aG input $USER
```

- `systemctl --user enable --now ydotool` starts the background service now and at every login.
- `usermod -aG input $USER` gives your user access to the input devices. The `-a` matters: it appends the group instead of replacing your existing ones.

> [!WARNING]
> **The script only does step 2 for you if the script itself installed `ydotool`.** If you installed `ydotool` yourself first (a fresh OS install, for example), the script skips this step, and you have to run the two commands above by hand. This is exactly what went wrong on the move from EndeavourOS to CachyOS.

**3. Log out and back in**

Group changes only apply to new login sessions. Opening a new terminal is not enough.

**4. Verify**

```bash
systemctl --user is-active ydotool   # should print: active
groups | grep -w input               # should print a line containing "input"
```

**5. Test that ydotool can type**

```bash
sleep 3; ydotool key 29:1 47:1 47:0 29:0
```

After pressing Enter, click into a text field that has something on the clipboard. It should paste by itself (this sends Ctrl+V). If it does, `ydotool` is working.

**6. Install and bind the script**

```bash
git clone https://github.com/YonaelT/klipper-autopaste.git
cd klipper-autopaste
chmod +x klipper-autopaste.sh
```

In System Settings → Keyboard → Shortcuts:

1. Clear Plasma's built-in clipboard shortcut on Meta+V, or the two will conflict.
2. Click Add New → Command or Script, choose `klipper-autopaste.sh`, and bind it to Meta+V.

Press Meta+V, pick an item, and it gets pasted.

## Features

- Auto-pastes whatever you select from the Klipper history popup
- Detects the active window and picks the right shortcut: Ctrl+Shift+V for terminals (Konsole, Alacritty, Kitty, WezTerm, foot), Ctrl+V for everything else
- Works on Wayland (KWin) and X11
- Checks for missing dependencies and offers to install them with `yay`

## Requirements

- KDE Plasma 6 with Klipper running
- `qt6-tools` (provides `qdbus-qt6` or `qdbus6`, used to talk to Klipper)
- `ydotool`, with its service running (see Setup)
- `kdotool` from the AUR (identifies the active window on Wayland)
- `xdotool` (only for X11 sessions; the dependency check does not cover it)

Used only by the automatic installer, so they're optional:

- `yay`
- `konsole`
- `notify-send`

## How it works

1. It saves the current clipboard contents through Klipper's D-Bus interface.
2. It records the active window's class before any menu appears. This uses `kdotool` on Wayland or `xdotool` on X11, lowercased.
3. It opens Klipper's history popup at the cursor.
4. It checks the clipboard every 100 ms for up to 8 seconds. If the contents change, you picked something.
5. It waits 0.3 seconds for focus to return to your window, then sends the paste keystroke. On Wayland that's done with `ydotool key` using raw key codes: `29` is Ctrl, `42` is Shift and `47` is V, where `:1` means pressed and `:0` means released. So `29:1 47:1 47:0 29:0` is Ctrl+V, and adding `42` makes it Ctrl+Shift+V.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Menu appears, but nothing is pasted | `ydotool` isn't running, or you're not in the `input` group | Redo Setup steps 2 to 4, and make sure you logged out and back in |
| `ydotool: failed to connect socket` | The service isn't running | `systemctl --user enable --now ydotool` |
| Nothing happens at all | The shortcut isn't bound, or Plasma's built-in Meta+V still owns the key | Setup step 6 |
| Notification about missing dependencies | A required package isn't installed | `yay -S qt6-tools ydotool kdotool` |
| A Konsole window flashes with `yay: command not found` | The auto-installer calls `yay` | Install `yay`, or install the packages by hand |
| `qdbus-qt6` shows as missing | Normal if `qdbus6` exists | Nothing, the script tries both names |
| Pastes with Ctrl+V in a terminal that needs Ctrl+Shift+V | The terminal's class name isn't in the script's list | Add it to the two `=~` patterns in the script |

If the service is `active`, you're in the `input` group and it still fails, check who owns the uinput device:

```bash
stat -c '%U:%G %a' /dev/uinput   # should print: root:input 660
```

If it prints `root:root`, add a udev rule so the `input` group can use it, then reboot:

```bash
echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/80-uinput.rules
```

## Limitations

- If you pick the item that is **already** the current clipboard content, nothing changes, so no paste happens and the script times out after 8 seconds.
- Closing the menu without choosing anything also ends quietly after 8 seconds.
- Terminals are recognized by a list of window class names (`konsole`, `alacritty`, `kitty`, `wezterm`, `foot`, `terminal`).
- The change detection compares text, so it's designed for text items in the history.

## License

MIT. See [LICENSE](LICENSE).
