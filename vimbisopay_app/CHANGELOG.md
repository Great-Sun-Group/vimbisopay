# Vimbisopay App Changelog

All notable changes to this app will be documented in this file.

## [1.0.0+42] - 2025-03-15
- Added a new product search screen

## [1.0.0+41] - 2025-03-12
- Removed database migrationindex creation for db version 9

## [1.0.0+40] - 2025-03-12
- More sample vendors and products 

## [1.0.0+39] - 2025-03-10
- WIP market place

## [1.0.0+38] - 2025-02-26
- Minor update -- fixed push notification issue 

## [1.0.0+37] - 2025-02-22
- Onboarding phone verification / change password / reset password and pin

## [1.0.0+36] - 2025-02-22
- Onboarding verification and optimisations

## [1.0.0+35] - 2025-02-03
- Bug fixes and optimisations

## [1.0.0+34] - 2025-02-01
- Added ledger entry caching for improved performance:
  - Implemented local caching of ledger entries
  - Optimized API calls to only fetch new entries
  - Reduced data usage and improved load times
  - Added offline support for viewing transaction history
  - Added documentation in docs/LEDGER_OPTIMIZATION_STEPS.md

## [1.0.0+33] - 2025-03-22
- UI cosmetic changes, hustler10k and app update ground work

## [1.0.0+32] - 2025-01-30
- Bug fixes and enhancements

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
- Dashboard changes

## [1.0.0+13] - 2024-12-20
- Dashboard update

## [1.0.0+10] - 2024-12-20
- New Dashboard updates

## [1.0.0+9] - 2024-12-20

## [1.0.0+8] - 2024-12-20
- Dashboad updates

## [1.0.0+7] - 2024-12-20
- New dashboard changes

## [1.0.0+6] - 2024-12-18
- We are now using the updated dashboard structure 

## [1.0.0+5] - 2024-12-18
- Fixed agressive pagination

## [1.0.0+4] - 2024-12-18
- Fixed agrressive pagination

## [1.0.0+3] - 2024-12-18
- Trying to upload package

## [1.0.0+2] - 2024-12-18
- First versioned build
- First github packages push
- Bug fixes- trx list

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
## [1.0.0+43] - 2025-03-22
- UI cosmetic enhancements, hustler10k and app update ground work
-e 
## [1.0.0+44] - 2025-03-30
- Market place functionality
-e 
## [minor fix-- preserving stor open close state] - 2025-03-30
-e 
## [1.0.0+46] - 2025-03-30
- minor fix  .. preserving store open close state
-e 
## [1.0.0+47] - 2025-04-01
- Seeking alignment
-e 
## [1.0.0+48] - 2025-04-03
- Cleaned up market place workflows
-e 
## [1.0.0+49] - 2025-04-03
- Added offline handling and ui clean ups
-e 
## [2.1.0+01] - 2025-04-14
- testing app update
-e 
## [2.1.1+02] - 2025-04-17
-e 
## [2.1.1+03] - 2025-04-17
- testing urls 
-e 
## [2.1.2+11] - 2025-04-17
- testing auto app update on device 
-e 
## [2.2.0+1] - 2025-04-17
- checking version checksums
-e 
## [2.2.0+2] - 2025-04-17
- version check
-e 
## [2.3.0+01] - 2025-04-17
- formatted urls
-e 
## [2.4.0+2] - 2025-04-18
- checking self install
-e 
## [2.5.0+03] - 2025-04-18
- test url formatting
-e 
## [2.6.0+4] - 2025-04-18
- using package installer 
-e 
## [2.7.0+01] - 2025-04-18
- testing package installer
-e 
## [2.8.1+01] - 2025-04-18
- package inster test
-e 
## [2.9.1+3] - 2025-04-18
- testing version number
-e 
## [3.0.0-debug+01] - 2025-04-18 (Debug Build)
- Debug build with API environment: dev
- testing debug flavour
-e 
## [3.0.1-debug+01] - 2025-04-18 (Debug Build)
- Debug build with API environment: dev
- test debug builds

## [3.2.2-debug+2] - 2025-04-18 (Debug Build)
- Debug build with API environment: dev
- testing debug version
-e 
## [4.0.0+01] - 2025-04-19
- Release managenet framework
-e 
## [4.0.0+02] - 2025-04-19
- Testing release signing keys
-e 
## [4.0.0+03] - 2025-04-19
- Debuging release version
-e 
## [4.1.0-debug+01] - 2025-04-19 (Debug Build)
- Debug build with API environment: dev
- testing auto update
-e 
## [4.2.0-debug+12] - 2025-04-19 (Debug Build)
- Debug build with API environment: dev
- TESTING VERSION DOWNGRADE
-e 
## [4.3.0-debug+01] - 2025-04-20 (Debug Build)
- Debug build with API environment: dev
- testing with ryans accounts changes
-e 
## [4.4.0+01] - 2025-04-21
- Using dev whatsapp otp and settings clean up
-e 
## [4.5.0+02] - 2025-04-22
- 1.0.0
- UI clean up and disabled unsecured credexes
-e 
## [4.5.1+01] - 2025-04-24
- Testing push notifications
-e 
## [4.5.2+02] - 2025-04-30
- Updated Whatsapp verification flow
-e 
## [4.5.3+03] - 2025-05-04
- Added unsecured credex and minor bug fixes and enhancements
-e 
## [4.5.3+04] - 2025-05-04
- Unsecured credexes and minor bug fixes and enhancements
-e 
## [4.5.3+05] - 2025-05-04
- asdada
-e 
## [4.5.3+06] - 2025-05-04
- fsfsfs
-e 
## [4.5.3+07] - 2025-05-04
- Unsecured credex and minor bug fixes and enhancements
-e 
## [4.5.3+08] - 2025-05-04
- Unsecured credex and minor bug fixes and enhancements 
-e 
## [4.5.3+09] - 2025-05-04
- Unsecured credexes and minor bug fixes and enhancements 
-e 
## [4.5.3+10] - 2025-05-04
- Unsecured credex and minor bug fixes
-e 
## [4.5.3+11] - 2025-05-04
- Unsecured credexes and minor bug fixes
-e 
## [4.5.3+12] - 2025-05-04
- daad
-e 
## [4.5.3+12] - 2025-05-04
- hdhdhd
-e 
## [4.5.3+13] - 2025-05-04
- Unsecured credexes and minor bug fixes
-e 
## [4.5.3+14] - 2025-05-04
- Unsecured credex and  minor version updates
-e 
## [4.5.3+15] - 2025-05-04
- Unsecured credex and minor fixes
-e 
## [4.5.3+16] - 2025-05-04
- Disabled market place feature for release builds
