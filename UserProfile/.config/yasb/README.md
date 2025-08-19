# Pure Black Nord

A pure black variant of the Dark Nord theme for YASB (Yet Another Status Bar) with high contrast elements and clean aesthetics.

## Preview

![Pure Black Nord Theme](https://raw.githubusercontent.com/amnweb/yasb-themes/refs/heads/main/themes/03a6eaa2-6d0b-485d-94aa-2d87e98f3c64/image.png)

## Features

- **Pure Black Background**: Minimal visual noise with true black (`#000000`) base
- **Nord-Inspired Colors**: Based on the popular Dark Nord color scheme
- **High Contrast**: Bright text on dark backgrounds for excellent readability
- **Clean Typography**: Uses JetBrainsMono NFP font for crisp text rendering
- **Vibrant Accents**: Nord-inspired accent colors for important elements
- **GlazeWM Integration**: Full workspace indicator support with active state highlighting
- **Media Controls**: Integrated media player controls with modern styling
- **System Widgets**: Complete system monitoring with Cava audio visualization

## Widgets Included

- **GlazeWM Workspaces**: Visual workspace indicators with active highlighting
- **Active Window**: Current window title display
- **Media Player**: Now playing information with controls
- **Audio Visualizer**: Cava integration for audio visualization
- **Taskbar**: Application launcher and switcher
- **System Info**: Clock, weather, volume, WiFi, Bluetooth
- **Power Menu**: System power controls
- **Notes**: Quick note-taking widget
- **Wallpaper Manager**: Background image switcher

## Installation

1. Download the theme files
2. Copy `styles.css` to your YASB styles directory
3. Copy `config.yaml` to your YASB config directory
4. Restart YASB or reload configuration

## Customization

### Color Scheme

The theme uses CSS variables based on Nord colors with pure black backgrounds:

```css
:root {
    --background: #000000;    /* Pure black (modified from Nord) */
    --text: #ffffff;          /* Pure white text */
    --base1: #1a1a1a;        /* Dark gray variant */
    --base2: #0d0d0d;        /* Dark gray variant */
    --base3: #171717;        /* Dark gray variant */
    --red: #bf616a;          /* Nord red */
    --green: #a3be8c;        /* Nord green */
    --yellow: #ebcb8b;       /* Nord yellow */
    --blue: #88c0d0;         /* Nord blue */
    --pink: #b48ead;         /* Nord purple/pink */
}
```

### Font

Change the font family by modifying the universal selector:

```css
* {
    font-family: "Your Font Name", monospace;
}
```

## Requirements

- YASB (Yet Another Status Bar)
- GlazeWM (for workspace functionality)
- JetBrainsMono NFP font (recommended)

## Compatibility

- **Windows**: 10/11
- **YASB Version**: Latest
- **GlazeWM**: v3.x+

## Credits

- **Base Theme**: [Dark Nord by sumCottage](https://github.com/amnweb/yasb-themes/tree/main/themes/03a6eaa2-6d0b-485d-94aa-2d87e98f3c64)
- **Original Author**: sumCottage
- **Modified By**: dillacorn
- **YASB**: [amnweb/yasb](https://github.com/amnweb/yasb)
- **Font**: JetBrains Mono Nerd Font
- **Color Scheme**: Nord + Pure Black variant

## License

This theme is released under the MIT License. Feel free to modify and distribute.

---

*For issues or feature requests, please open an issue on the YASB themes repository.*
