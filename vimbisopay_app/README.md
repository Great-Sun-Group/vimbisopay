# Vimbisopay App

A Flutter application for managing Vimbisopay transactions.

## Development Setup

1. Install Flutter by following the [official installation guide](https://docs.flutter.dev/get-started/install)
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Set up Firebase configuration (see below)
5. Set up Git hooks (see below)
6. Run `flutter run` to start the app in debug mode

## Git Hooks Setup

The repository includes Git hooks to ensure code quality:

1. Create Git hooks directory if it doesn't exist:
   ```bash
   mkdir -p .git/hooks
   ```

2. Link the pre-push hook:
   ```bash
   ln -s ../../scripts/git-hooks/pre-push .git/hooks/pre-push
   ```

This will ensure that:
- All tests pass before each push
- Failed pushes if tests fail
- Consistent code quality across the team

## Testing

The app includes comprehensive test coverage across different layers:

### Running Tests

- Run all tests:
  ```bash
  flutter test
  ```

- Run specific test file:
  ```bash
  flutter test test/path/to/test_file.dart
  ```

### Code Coverage

- Generate and view HTML coverage report:
  ```bash
  ./scripts/coverage-report.sh
  ```
  This script will:
  - Run tests with coverage enabled
  - Generate an HTML report
  - Open the report in your default browser
  - Install lcov if needed (via brew)

- Manual coverage commands:
  ```bash
  # Run tests with coverage
  flutter test --coverage
  
  # Generate HTML report (requires lcov)
  genhtml coverage/lcov.info -o coverage/html
  
  # View the report
  open coverage/html/index.html
  ```

Note: Coverage files are excluded from version control via .gitignore

### Test Categories

1. **Repository Tests** (`test/infrastructure/repositories/`)
   - Test API interactions and data mapping
   - Verify error handling
   - Mock HTTP responses
   ```bash
   flutter test test/infrastructure/repositories/
   ```

2. **BLoC Tests** (`test/presentation/blocs/`)
   - Test state management
   - Verify state transitions
   - Test error handling
   ```bash
   flutter test test/presentation/blocs/
   ```

For more details about testing strategy and best practices, see [Testing Strategy](docs/AD_SPACE_IMPLEMENTATION/09_TESTING_STRATEGY.md).

## Firebase Configuration

The app requires Firebase configuration files which are not checked into version control for security reasons:
- Android: `android/app/google-services.json`
- iOS: `ios/GoogleService-Info.plist`

To set up Firebase:

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Register your app:
   - For Android: Add an Android app in Firebase Console
     - Use package name from `android/app/build.gradle`
     - Download `google-services.json`
     - Place it in `android/app/google-services.json`
   - For iOS: Add an iOS app in Firebase Console
     - Use bundle ID from Xcode project
     - Download `GoogleService-Info.plist`
     - Place it in `ios/GoogleService-Info.plist`

Note: Different Firebase projects/configurations may be needed for development, staging, and production environments. Contact your team lead for the appropriate configuration files.

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
