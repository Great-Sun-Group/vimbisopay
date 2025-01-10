# Testing Strategy

## Overview
This document outlines the testing strategy for the VimbisoPay app, detailing our approach to ensuring code quality and reliability through comprehensive testing.

## Test Categories

### 1. Unit Tests
- **Repository Tests**
  - Test API interactions and data mapping
  - Verify error handling for network failures
  - Mock HTTP responses for consistent testing
  - Coverage includes:
    - Login functionality
    - Credex operations (create, cancel, accept)
    - Notification token registration
    - Ledger data retrieval

- **BLoC Tests**
  - Test state management and business logic
  - Verify correct state transitions
  - Test error handling and recovery
  - Coverage includes:
    - Initial states
    - Complex state sequences
    - Error states
    - Async operations
    - Data refresh flows

### 2. Integration Tests
- Test interaction between different layers
- Verify data flow from UI through BLoC to Repository
- Test database operations and caching

### 3. Widget Tests
- Test UI components in isolation
- Verify widget behavior and user interactions
- Test screen layouts and responsiveness

## Testing Best Practices

### 1. State Management Testing
- Use `emitsInOrder` for testing complex state sequences
- Verify intermediate states during operations
- Test timeout scenarios
- Mock dependencies for consistent results

### 2. Repository Testing
- Mock HTTP responses for both success and failure cases
- Test error handling and retry logic
- Verify correct data mapping between API and domain models

### 3. Error Handling
- Test all error scenarios
- Verify error messages and user feedback
- Test recovery from error states

## Test Organization
- Tests mirror the source code structure
- Clear naming conventions for test files and cases
- Group related tests for better organization
- Use descriptive test names that explain the scenario

## Tools and Libraries
- **Testing Framework**: Flutter Test
- **Mocking**: Mocktail
- **State Management Testing**: bloc_test
- **Network Mocking**: Mock HTTP client

## Continuous Integration

### 1. Git Hooks
- Pre-push hook enforces test execution
- All tests must pass before code can be pushed
- Located in `scripts/git-hooks/pre-push`
- Setup instructions in README.md

### 2. Pull Request Requirements
- All tests must pass before merge
- Coverage reports generated automatically
- Required passing tests before merge
- Coverage thresholds enforced

### 3. Automated Testing
- Tests run on every push
- Tests run on every pull request
- Tests run before releases
- Automated test reports generated

## Recent Improvements
- Enhanced BLoC testing with proper state transition verification
- Improved error case coverage in repository tests
- Removed legacy widget tests
- Added comprehensive testing for Credex operations
- Implemented proper timeout handling in async tests
- Added Git hooks for automated test execution
- Improved documentation and setup instructions

## Setting Up Local Testing

### 1. Git Hooks Setup
```bash
mkdir -p .git/hooks
ln -s ../../scripts/git-hooks/pre-push .git/hooks/pre-push
```

### 2. Running Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/path/to/test_file.dart

# Run with coverage
flutter test --coverage
```

### 3. Code Coverage

#### Coverage Reports
- Coverage reports are generated in the `coverage/` directory
- HTML reports provide detailed visualization of code coverage
- Reports show line-by-line coverage analysis
- Coverage metrics include:
  - Line coverage percentage
  - Uncovered lines highlighted
  - File-by-file breakdown
  - Overall project coverage statistics

#### Generating Coverage Reports
Using the convenience script:
```bash
./scripts/coverage-report.sh
```
This automated script will:
- Run all tests with coverage enabled
- Generate an HTML report using lcov
- Open the report in your default browser
- Install lcov if needed (via brew)

Manual steps:
```bash
# Run tests with coverage
flutter test --coverage

# Generate HTML report (requires lcov)
genhtml coverage/lcov.info -o coverage/html

# View the report
open coverage/html/index.html
```

#### Coverage Files
- Coverage files are excluded from version control
- The following files are git-ignored:
  - `/coverage/` directory
  - `lcov.info` files
  - Generated HTML reports

#### Best Practices
- Review coverage reports regularly
- Focus on critical code paths
- Aim for high coverage in core business logic
- Document areas intentionally left uncovered
- Use coverage data to guide test development

#### CI/CD Integration
- Test results and coverage reports logged in CI/CD pipeline
- Coverage thresholds can be enforced in CI
- Historical coverage data tracked
