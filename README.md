# AGILA Mobile

AGILA Mobile is a Flutter application for the AGILA platform. It provides role-based mobile experiences for students, teachers, and program heads, including authentication, schedules, attendance, requests, profiles, notifications, and mobile security features.

## Features

- Student and teacher authentication flows
- Quick login with passcode and biometric authentication
- Student attendance viewing and attendance details
- Teacher schedules and enrolled-student information
- Home dashboard with dates, notes, and daily schedules
- Requests between students, teachers, and faculty
- User profiles with profile-picture support
- Light and dark theme support
- Firebase Cloud Messaging and local notifications
- Firebase Authentication, Cloud Firestore, Cloud Storage, and Cloud Functions integration
- PDF generation and printing support
- Notification, camera, photo, storage, and location permission handling

## Technology Stack

- **Flutter / Dart**
- **Firebase**: Authentication, App Check, Cloud Firestore, Cloud Messaging, Cloud Storage, and Cloud Functions
- **Local authentication**: Passcode and fingerprint/biometric support
- **Android and iOS** platform support

## Requirements

Before getting started, install:

- Flutter SDK compatible with Dart SDK `^3.7.0`
- Android Studio and/or Xcode
- A configured Android or iOS device or emulator
- Access to the project's Firebase configuration

Verify your Flutter installation with:

```bash
flutter doctor
```

## Getting Started

1. Clone the repository:

   ```bash
   git clone https://github.com/Gabbiruu18/AGILA_MOBILE.git
   cd AGILA_MOBILE
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Configure Firebase for the target platforms.

   Add the appropriate Firebase configuration files and ensure Firebase services are enabled for the project. Do not commit private credentials or production secrets to the repository.

4. Run the application:

   ```bash
   flutter run
   ```

## Useful Commands

```bash
# Check the project and installed tooling
flutter doctor

# Install or update Dart and Flutter dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run tests
flutter test

# Build an Android APK
flutter build apk

# Build an Android App Bundle
flutter build appbundle

# Build an iOS application
flutter build ios
```

## Project Structure

```text
lib/
├── Screens/          # Opening, login, theme, and other UI screens
├── Service_Modules/  # Home, notification, and application service modules
└── main.dart         # Application entry point and route configuration
assets/               # ML models, logos, and image assets
android/              # Android platform configuration
ios/                  # iOS platform configuration
```

## Configuration Notes

The application requests access to camera, storage, photos, location, and notification services depending on the platform and enabled features. Review the platform permission configuration before creating a production release.

Firebase App Check and notification providers should use production-ready providers and credentials for release builds. Debug providers are intended only for development and testing.

## Development Status

AGILA Mobile is under active development. Some screens and workflows may still require UI improvements, data-fetching fixes, and additional notification behavior.

## Contributing

1. Create a feature branch from `main`.
2. Make your changes and run `flutter analyze` and relevant tests.
3. Submit a pull request describing the change and any required Firebase or platform configuration.

## License

No license has been specified for this repository. Contact the repository owner before redistributing or using the project outside its intended environment.

## Author
**John Gabriel Purificacion**
