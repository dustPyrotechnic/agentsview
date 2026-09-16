# AgentsView macOS Client

Native macOS SwiftUI application for AgentsView, backed by the Go sidecar.

## Architecture

- **Swift/SwiftUI**: App lifecycle, UI, view models, native charts, menu bar integration
- **Go sidecar**: SQLite access, usage computation, pricing, API server
- **Communication**: Swift → HTTP → Go sidecar on localhost

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 6.0

## Building

### Development Build

```bash
cd macos/AgentsViewMac
xcodebuild \
    -project AgentsViewMac.xcodeproj \
    -scheme AgentsViewMac \
    -configuration Debug \
    build
```

### Release Build

```bash
cd macos/AgentsViewMac
xcodebuild \
    -project AgentsViewMac.xcodeproj \
    -scheme AgentsViewMac \
    -configuration Release \
    build
```

The built application will be located at:
```
build/Release/AgentsViewMac.app
```

## Running

The macOS app expects the Go sidecar binary to be available:

1. **Development**: Place `agentsview` binary in the app bundle's `Resources` directory, or set a custom path
2. **Production**: The sidecar binary should be embedded in `AgentsViewMac.app/Contents/Resources/agentsview`

### Sidecar Launch Arguments

The Swift app launches the sidecar with:
```bash
agentsview serve --background --host 127.0.0.1
```

The sidecar will:
- Bind to an available port on localhost
- Print readiness status for the Swift process manager
- Serve HTTP API requests from the macOS client

## Configuration

### Bundle Identifier

The bundle identifier is configurable via build settings:
- Base: `PRODUCT_BUNDLE_IDENTIFIER_BASE = io.agentsview.mac`
- Override via environment or xcconfig if needed

### Development Team

Set `DEVELOPMENT_TEAM` in build settings for code signing during development.

## Project Structure

```
AgentsViewMac/
├── AgentsViewMac.xcodeproj    # Xcode project
└── AgentsViewMac/
    ├── App/                    # Application entry point
    ├── Core/                   # API client, sidecar manager, shared utilities
    ├── Features/               # Dashboard, usage charts, menu bar views
    └── Resources/              # Info.plist, entitlements, assets
```

## Testing

```bash
cd macos/AgentsViewMac
xcodebuild \
    -project AgentsViewMac.xcodeproj \
    -scheme AgentsViewMac \
    test
```

## Troubleshooting

### Sidecar fails to start
- Verify `agentsview` binary is present and executable
- Check Console.app for sidecar process logs
- Ensure no other process is binding the expected port

### Build failures
- Clean build folder: `rm -rf ~/Library/Developer/Xcode/DerivedData/AgentsViewMac-*`
- Verify Xcode command line tools: `xcode-select -p`
- Check Swift version: `swift --version` (should be 6.0+)
