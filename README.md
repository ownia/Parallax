# Parallax

Native macOS fullscreen translation app using Apple Vision OCR.

## Features

- OCR text recognition using Apple Vision framework
- Auto translate to multiple languages
- Online (Google API) and Offline (Apple Translation) modes
- Translation overlay displayed at original text position
- Global hotkey `Ctrl+Shift+T` to trigger
- Multi-display support
- Menu bar app, lightweight
- Supports English and Chinese UI

## Requirements

- macOS 13.0 (Ventura) or later
- macOS 15.0 (Sequoia) or later for offline translation
- Screen recording permission required

## Usage

1. After launching, a document scan icon appears in the menu bar
2. Press `Ctrl+Shift+T` to trigger screen translation
3. Press `Ctrl+Shift+T` again to hide the translation overlay
4. Click the menu bar icon to:
   - Manually trigger translation
   - Select target language
   - Switch translation mode (Online/Offline)
   - Select display (for multi-monitor setups)
   - View about info
   - Quit the app

## Translation Modes

### Online Mode (Default)

- Uses Google Translate API
- Requires internet connection
- Supports auto language detection

### Offline Mode (macOS 15+)

- Uses Apple Translation framework
- Works without internet after downloading language packs
- Better privacy (all processing on device)
- First use requires downloading language packs from:
  - System Settings → General → Language & Region → Translation Languages

**Note:** Switching modes while translation overlay is visible will automatically re-translate using the new mode.

## Supported Languages

Chinese, English, Japanese, Korean, French, German, Spanish, Russian, Portuguese, Italian, Arabic, Thai, Vietnamese

## Permission Setup

First run requires screen recording permission:

1. Open **System Settings** → **Privacy & Security** → **Screen Recording**
2. Find **Parallax** and enable it
3. Restart the app

## Notice

This software contains artificial intelligence technology. Use it at your own risk. Please report any issues at [GitHub Issues](https://github.com/ownia/Parallax/issues).
