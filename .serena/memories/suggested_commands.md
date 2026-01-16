# Suggested Commands

## Build Commands
```bash
make generate       # Generate Xcode project from project.yml
make build          # Build for iOS Simulator (default: iPhone 17)
make build SIMULATOR="iPhone 15 Pro"  # Build for specific simulator
make build-release  # Build for release
make test           # Run tests on simulator
```

## Code Quality
```bash
make lint           # Run SwiftLint (--strict mode)
make format         # Format code with SwiftFormat
```

## Before Committing
Always run:
```bash
make lint && make format
```

## Other Commands
```bash
make setup          # Install dev dependencies
make open           # Open Xcode project
make resolve        # Resolve Swift package dependencies
make clean          # Clean build artifacts
```
