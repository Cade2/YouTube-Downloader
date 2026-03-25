# PullTube

A personal YouTube downloader for iOS with a polished dark UI.

## Features

- Paste any YouTube URL and instantly preview the video thumbnail, title, and channel
- Download as **MP4** (video) or **MP3** (audio-only)
- All available quality options shown — highest quality pre-selected
- Real-time download progress with speed (MB/s)
- MP3 mode switches to an amber accent with animated sound-wave indicator
- Saved to Camera Roll (MP4) or Files app / Documents (MP3)
- Loading shimmer, animated progress, success snackbar
- Graceful error handling for invalid URLs, network failures, and restricted videos

## Stack

| Package | Purpose |
|---|---|
| `youtube_explode_dart` | Fetch stream info from YouTube |
| `dio` | HTTP stream download |
| `photo_manager` | Save videos to the iOS photo library |
| `permission_handler` | Photo library permission |
| `google_fonts` | DM Sans typography |
| `shimmer` | Loading skeleton |
| `cached_network_image` | Thumbnail caching |

## Project Layout

```
lib/
├── main.dart                  # App entry, ThemeData, AppColors
├── models/
│   └── video_info.dart        # VideoInfo & StreamOption models
├── services/
│   └── youtube_service.dart   # Fetch & download logic
├── screens/
│   └── home_screen.dart       # Main screen state machine
└── widgets/
    ├── format_toggle.dart      # MP4 / MP3 pill toggle
    ├── quality_dropdown.dart   # Quality / bitrate selector
    ├── video_info_card.dart    # Thumbnail + title + channel
    ├── download_button.dart    # Full-width gradient CTA
    ├── progress_card.dart      # Download progress bar + speed
    ├── sound_wave_widget.dart  # Animated audio-mode indicator
    └── shimmer_loader.dart     # Loading skeleton cards
```

## Setup

Requirements: **Flutter stable**, **Xcode 15+**, **CocoaPods**

```bash
git clone <repo>
cd pulltube
bash setup.sh
```

Then open `ios/Runner.xcworkspace` in Xcode, select your device, and run.

> **Note:** This is a personal-use app, not intended for the App Store.
> Set your own development team in Xcode → Runner target → Signing.

## iOS Permissions

The following are declared in `ios/Runner/Info.plist`:

- `NSPhotoLibraryAddUsageDescription` — to save MP4 videos to the Camera Roll
- `NSAppTransportSecurity` (allow arbitrary loads) — required for YouTube stream URLs

MP3 files are saved to the app's **Documents** folder, accessible via **Files → On My iPhone → PullTube**.
