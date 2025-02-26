# Vimbisopay App Changelog

All notable changes to this app will be documented in this file.

## [1.0.0+34] - 2025-02-01
- Added ledger entry caching for improved performance:
  - Implemented local caching of ledger entries
  - Optimized API calls to only fetch new entries
  - Reduced data usage and improved load times
  - Added offline support for viewing transaction history
  - Added documentation in docs/LEDGER_OPTIMIZATION_STEPS.md

## [1.0.0+33] - 2025-01-30
- member tier update workflow

## [1.0.0+32] - 2025-01-30
- bug fixes and enhancements

## [1.0.0+31] - 2025-01-30
- Miscellaneous bug fixes and enhancements 

## [1.0.0+31] - 2025-01-28
- Demo with lawrance

## [1.0.0+30] - 2025-01-28
- Demo with Lawrance

## [1.0.1.0] - 2025-01-28

## [1.0.0.30] - 2025-01-28

## [1.0.0+28] - 2025-01-13
- Foreground notifications

## [1.0.0+26] - 2025-01-08
- Added Git hooks for automated testing:
  - Pre-push hook to run tests automatically
  - Tests must pass before pushing code
  - Added setup instructions in README.md
  - Updated testing strategy documentation

## [1.0.0+25] - 2025-01-08
- Enhanced test coverage and reliability:
  - Improved BLoC testing with proper state transition verification
  - Added comprehensive testing for Credex operations
  - Fixed timeout handling in async tests
  - Removed legacy widget tests
  - Added testing strategy documentation
- Added comprehensive testing documentation in docs/AD_SPACE_IMPLEMENTATION/09_TESTING_STRATEGY.md

## [1.0.0.0+24] - 2025-01-07
- UI Fixes

## [1.0.0+15] - 2024-12-23
- Transaction Confirmation and UI fixes

## [1.0.0+14] - 2024-12-20
- dashboard changes

## [1.0.0+13] - 2024-12-20
- Dashboard update

## [1.0.0+10] - 2024-12-20
- New Dashboard updates

## [1.0.0+9] - 2024-12-20

## [1.0.0+8] - 2024-12-20
- Dashboad updates

## [1.0.0+7] - 2024-12-20
- new dashboard changes

## [1.0.0+6] - 2024-12-18
- We are now using the updated dashboard structure 

## [1.0.0+5] - 2024-12-18
- fixed agressive pagination

## [1.0.0+4] - 2024-12-18
- fixed agrressive pagination

## [1.0.0+3] - 2024-12-18
- trying to upload package

## [1.0.0+2] - 2024-12-18
- First versioned build
- First github packages push
- bug fixes- trx list

## [1.0.0+1] - Initial Version
- Initial release for testing

## Version Format
`major.minor.patch+build`
- major: Major changes or complete revamps
- minor: New features
- patch: Bug fixes and small improvements
- build: Build number for internal tracking

## How to Update
1. When sending a new version to testers:
   - Update version in pubspec.yaml
   - Add new version entry in this file with changes
   - Include date of release

Example entry format:
```
## [1.0.1+2] - YYYY-MM-DD
- Added new feature X
- Fixed bug in Y
- Improved Z
-e 
## [1.0.0+35] - 2025-02-03
- Bug fixes and optimisations
-e 
## [1.0.0+36] - 2025-02-22
- onboarding verification and optimisations
-e 
## [1.0.0+37] - 2025-02-22
- Onboarding phone verification / change password / reset password and pin
-e 
## [1.0.0+38] - 2025-02-26
- Minor update -- fixed push notification issue 
