# Change PIN and Password Dialogs to Bottom Sheets

## Description
This PR converts the existing PIN and Password change dialogs to modern bottom sheets for a more user-friendly mobile experience.

## Changes Made

### New Files Created
- `lib/presentation/widgets/change_pin_bottom_sheet.dart`
- `lib/presentation/widgets/change_password_bottom_sheet.dart`

### Modified Files
- `lib/presentation/screens/security_settings_screen.dart`
  - Replaced dialog imports with bottom sheet imports
  - Updated dialog show calls to use bottom sheets
  - Added bottom sheet configuration for better UX

### UI/UX Improvements
- Better keyboard handling with `isScrollControlled: true`
- Smoother animations
- Modern bottom sheet design with rounded corners
- Improved visual hierarchy
- Enhanced error state visibility
- Consistent styling with app theme

### Functionality
- Maintained all existing validation logic
- Preserved success/error messaging
- Kept security service integration
- Retained biometric authentication options

## Testing
- Verify PIN change flow
- Test password validation and strength indicator
- Check keyboard behavior
- Confirm error states display correctly
- Validate success messages
- Test navigation and dismissal gestures

## Screenshots
[Add screenshots here]
