# DualTime

DualTime is a native macOS menu bar app that shows a second clock using a configurable time zone. It keeps the system menu bar style and displays the configured time beside the system clock as closely as macOS allows.

## Features

- English: `Wed Oct 14 09:30`
- Chinese: `10月14日 周三 09:30`
- 24-hour time with optional seconds
- Optional date and weekday display
- Optional flashing time separators
- Searchable IANA time zone list with common cities pinned first
- Automatic daylight-saving and UTC-offset handling
- English and Chinese UI
- Optional launch at login through `SMAppService`
- Accessory application that stays in the menu bar and does not appear in the Dock
- Settings open on left click; right click provides settings and quit

## Requirements

- macOS 14 or later
- Apple Silicon
- Xcode 26 or later for the included project

## Build

```sh
xcodebuild -project DualTime.xcodeproj -scheme DualTime -configuration Release -sdk macosx -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
```

The local arm64 app is available at `dist/DualTime.app`. It is unsigned and intended for local use.

## Tests

```sh
xcodebuild -project DualTime.xcodeproj -scheme DualTime -configuration Debug -sdk macosx -derivedDataPath .build CODE_SIGNING_ALLOWED=NO test
```

The menu bar is managed by macOS. The app requests a variable-width status item and uses the system menu bar font and color, but public APIs cannot guarantee a fixed position directly beside the system clock or force priority over other status items when space is unavailable.

The default display updates at the next minute boundary. Enabling seconds or flashing separators changes the refresh cadence to once per second, which is sufficient for this lightweight single-label status item and avoids unnecessary work in the default mode.
