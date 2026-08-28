# minidex-lyrics

A lightweight, modern KDE Plasma desktop widget and standalone music player card with real-time synchronized lyrics, ambient album art tinting, and MPRIS playback controls.

## Features

- Real-Time Synchronized Lyrics: Auto-scrolling lyrics powered by the LRCLIB database with active line highlighting and jump-to-timestamp seeking.
- Ambient Album Art Tinting: Atmospheric dynamic background wash derived from the active track's album cover art with a high-contrast dark vignette.
- Adaptive Layout: Expandable lyrics sheet that contracts into a compact media bar when toggled.
- Auto-Hide When Idle: Automatically conceals itself when no media player is playing or active.
- Fixed Control Alignment: Playback transport buttons remain centered and stationary during resize and toggle operations.
- Native Networking: Pure asynchronous JavaScript networking with zero background subprocess overhead.
- Universal MPRIS Support: Works seamlessly with Spotify, VLC, Firefox, Chrome, Brave, Elisa, MPV, Strawberry, and any MPRIS2-compliant player.

## Requirements

- KDE Plasma 5 or KDE Plasma 6
- Plasma Core and Plasma Components QML modules
- Any MPRIS2-compatible media player or browser with media integration enabled

## Installation

### Method 1: Automatic Script

1. Clone the repository:
   ```bash
   git clone https://github.com/dexorto/minidex-lyrics.git
   cd minidex-lyrics
   ```

2. Run the installation script:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. Refresh Plasma Shell (if not reloaded automatically):
   ```bash
   plasmashell --replace &
   ```

### Method 2: Manual Installation

Copy the repository contents into your local Plasma plasmoids directory:

```bash
mkdir -p ~/.local/share/plasma/plasmoids/org.kde.plasma.minidex-lyrics
cp -r * ~/.local/share/plasma/plasmoids/org.kde.plasma.minidex-lyrics/
kbuildsycoca6 --noincremental || kbuildsycoca5 --noincremental
plasmashell --replace &
```

## Adding the Widget to Plasma

1. Right-click on your desktop or panel.
2. Select "Add Widgets...".
3. Search for "minidex-lyrics".
4. Drag and drop the widget onto your desktop or panel.

## Window Manager Compatibility

### 1. Native Desktop Environments
- KDE Plasma (KWin on Wayland and X11) - Direct drag-and-drop desktop widget and panel applet.

### 2. Standalone Window Managers (via plasmawindowed)
The widget can be run as an independent floating or tiled window across all standalone window managers using the built-in `plasmawindowed` runner:

```bash
plasmawindowed org.kde.plasma.minidex-lyrics &
```

Compatible Window Managers:
- Wayland Compositors: Hyprland, Sway, River, Niri, Wayfire, Labwc
- X11 Tiling Window Managers: i3, i3-gaps, bspwm, AwesomeWM, dwm, xmonad, qtile, herbstluftwm
- Stacking / Floating Window Managers: Openbox, Fluxbox, IceWM, Xfwm4 (XFCE), Marco (MATE), Mutter

### Example Window Rules (Hyprland)
To float and position the widget in your `hyprland.conf`:
```ini
windowrulev2 = float, class:^(plasmawindowed)$, title:^(minidex-lyrics)$
windowrulev2 = size 400 540, class:^(plasmawindowed)$, title:^(minidex-lyrics)$
windowrulev2 = pin, class:^(plasmawindowed)$, title:^(minidex-lyrics)$
```

## File Structure

```text
minidex-lyrics/
|-- metadata.json       # Plasma package manifest (Plasma 6 & 5)
|-- metadata.desktop    # Desktop service entry for Plasma 5 compatibility
|-- install.sh          # One-click deployment script
|-- README.md           # Documentation
`-- contents/
    `-- ui/
        `-- main.qml    # Core QML interface, MPRIS controller, and lyrics engine
```

## Troubleshooting

- Widget not showing up in the widget list:
  Run `kbuildsycoca6 --noincremental` (or `kbuildsycoca5 --noincremental`) in your terminal and restart plasmashell using `plasmashell --replace &`.

- Lyrics not loading for a song:
  Verify internet connectivity. The lyrics engine queries the public LRCLIB database. Instrumental songs or uncatalogued indie tracks may not have synchronized LRC timestamps available.

- Media player not detected:
  Ensure your player supports MPRIS2. For web browsers (Firefox, Chrome, Brave), verify that the "Plasma Browser Integration" extension or native media session support is enabled in your browser settings.

## License

This project is licensed under the GPL-3.0 License.
