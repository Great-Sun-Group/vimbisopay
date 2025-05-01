# VimbisoPay Release Signing Keys

This document provides information about the release signing keys used for the VimbisoPay app, including setup, management, and security considerations.

## Overview

Android requires that all APKs be digitally signed with a certificate before they can be installed or updated. For production releases, it's important to use a secure, private key that is properly managed and protected.

The VimbisoPay app uses a dedicated release signing key for production builds, which is separate from the debug key used during development.

## Key Information

- **Keystore File**: `vimbisopay-release-key.jks`
- **Key Alias**: `vimbisopay`
- **Validity**: 10,000 days (approximately 27 years)
- **Algorithm**: RSA
- **Key Size**: 2048 bits

## Key Configuration

The signing key configuration is stored in `android/key.properties`, which contains:

```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=vimbisopay
storeFile=../vimbisopay-release-key.jks
```

This file is referenced in `android/app/build.gradle` to configure the release signing.

## Security Considerations

### Key Protection

The release signing key is critical for the app's security and update process. If the key is lost, you will not be able to publish updates to your app. If the key is compromised, someone else could potentially publish malicious updates to your app.

To protect the key:

1. **Backup**: Keep secure backups of the keystore file in multiple secure locations.
2. **Password Management**: Use a strong password and store it securely (e.g., in a password manager).
3. **Access Control**: Limit access to the keystore file and its password to authorized personnel only.
4. **Version Control**: Do not commit the keystore file or key.properties to version control. They are already added to .gitignore.

### Key Rotation

While the key has a long validity period, consider implementing a key rotation strategy for enhanced security:

1. **Periodic Review**: Annually review the key's security and consider if rotation is needed.
2. **Planned Rotation**: If rotation is needed, plan it carefully to ensure a smooth transition for users.
3. **App Signing by Google Play**: Consider using Google Play App Signing, which allows for key rotation while maintaining the ability to update the app.

## Build Process Integration

The release signing key is integrated into the build process through:

1. **build.gradle Configuration**: The `android/app/build.gradle` file is configured to use the release signing key for release builds.
2. **Update Script**: The `scripts/update-version.sh` script verifies the existence of the keystore file and key.properties before building and checks the signature of the built APKs.

## Creating a New Key

If you need to create a new signing key, use the following command:

```bash
keytool -genkey -v -keystore vimbisopay-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias vimbisopay
```

You will be prompted to enter:
- A password for the keystore
- Your name, organizational unit, organization, city, state, and country code
- A password for the key (can be the same as the keystore password)

After creating the key, update the `android/key.properties` file with the new information.

## Verifying APK Signatures

To verify that an APK has been properly signed with the release key, use:

```bash
jarsigner -verify -verbose -certs path/to/your-app.apk
```

This command will display information about the signature, including the certificate used to sign the APK.

## Troubleshooting

### Common Issues

1. **Missing Keystore File**: Ensure the keystore file is in the correct location (project root directory).
2. **Incorrect Key.properties**: Verify that the key.properties file contains the correct information.
3. **Build Failures**: If the build fails with signing-related errors, check the keystore password and alias.

### Resolution Steps

1. Verify the keystore file exists and is accessible.
2. Check the key.properties file for correct paths and credentials.
3. Try manually signing an APK to test the keystore:
   ```bash
   jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 -keystore vimbisopay-release-key.jks path/to/unsigned.apk vimbisopay
   ```

## References

- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Flutter Android Deployment](https://flutter.dev/docs/deployment/android)
- [Google Play App Signing](https://support.google.com/googleplay/android-developer/answer/7384423)
