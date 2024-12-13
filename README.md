# VimbisoPay

VimbisoPay client to manage your payments, accounts, corporations, and portfolios in the credex ecosystem.

## Development Setup

This project uses Flutter and can be developed either locally or using GitHub Codespaces.

### GitHub Codespaces Development

1. Click the "Code" button on the GitHub repository
2. Select "Create codespace on main"
3. Wait for the container to build and VS Code to load
4. The development environment will be automatically configured with:
   - Flutter SDK (stable channel)
   - Android SDK
   - Required VS Code extensions
   - Optimal Flutter development settings

### Local Development

#### Prerequisites

1. Install [Flutter](https://flutter.dev/docs/get-started/install) (stable channel)
2. Install [Android Studio](https://developer.android.com/studio) and Android SDK
3. Install [VS Code](https://code.visualstudio.com/)
4. Install required VS Code extensions:
   - Dart-Code.dart-code
   - Dart-Code.flutter
   - usernamehw.errorlens
   - streetsidesoftware.code-spell-checker
   - eamodio.gitlens
   - ryanluker.vscode-coverage-gutters

#### Setup Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/vimbisopay.git
   cd vimbisopay
   ```

2. Open in VS Code with devcontainer:
   - Open VS Code
   - Install the "Remote - Containers" extension
   - Open the project folder
   - When prompted, click "Reopen in Container"
   - Wait for the container to build (first time only)

## Development

The development environment includes:
- Automatic code formatting on save
- Import organization
- Code actions for quick fixes
- Bracket pair colorization
- 80-character line length ruler
- Git configuration persistence

## Ports

The development environment forwards the following ports:
- 3000: Flutter web development
- 9100: Flutter debugging

## Getting Started

After setting up the development environment:

1. Verify Flutter installation:
   ```bash
   flutter doctor
   ```

2. Get dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
