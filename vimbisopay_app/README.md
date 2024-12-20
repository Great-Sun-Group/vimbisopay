# Vimbisopay App

A Flutter application for managing Vimbisopay transactions.

## Development Setup

1. Install Flutter by following the [official installation guide](https://docs.flutter.dev/get-started/install)
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the app in debug mode

## Release Process

### Setting up GitHub Authentication

1. Copy the template configuration file:
   ```bash
   cp scripts/github_config.template.sh scripts/github_config.sh
   ```

2. Get a GitHub token:
   - Go to GitHub.com → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Click "Generate new token" → "Generate new token (classic)"
   - Name: "Release Management" (or your preferred name)
   - Select the 'repo' scope
   - Click "Generate token"
   - Copy the generated token

3. Update `scripts/github_config.sh`:
   - Replace `your-token-here` with your GitHub token
   - Replace `owner/repository-name` with the correct repository path
   - Keep this file secure and never commit it (it's git-ignored)

### Creating a Release

To create a new release with an APK:

1. Ensure your changes are committed and pushed
2. Run the release script:
   ```bash
   ./scripts/update-version.sh
   ```
3. Follow the prompts to:
   - Enter the new version number
   - Add changelog entries

The script will:
- Update version in pubspec.yaml
- Update CHANGELOG.md
- Build and package the APK
- Create a GitHub release
- Upload the APK as a release asset

## Resources

For Flutter development help:
- [Flutter Documentation](https://docs.flutter.dev/)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook)
- [Flutter API Reference](https://api.flutter.dev/)
