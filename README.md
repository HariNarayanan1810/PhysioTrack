# PhysioTrack

PhysioTrack is a physiotherapy management application built with Flutter and a Node.js backend. The system supports patients, doctors, and administrators with appointment booking, doctor verification, exercise plans, location support , payment tracking, reports, notifications, and clinic/home-visit workflows.

## Project Overview

The project is designed to help physiotherapy clinics and patients manage treatment digitally. Patients can find doctors, book appointments, track assigned exercises, make payments, and view treatment progress. Doctors can manage appointments, patients, exercise recommendations, blogs, fees, and home visits. Administrators can verify doctors, review reports, and monitor platform activity.

## Main Features

- Role-based login for Admin, Doctor, and Patient
- Firebase Authentication integration
- Patient registration and doctor registration
- Doctor verification and approval workflow
- Doctor profile, clinic, pricing, and home-visit management
- Patient appointment booking and appointment history
- Clinic and home-visit appointment support
- Google Maps based location and direction support
- Exercise library with video-based physiotherapy exercises
- Patient daily exercise tracking and completion flow
- Treatment plan and patient progress management
- Razorpay payment integration
- Doctor blogs and discussion features
- Push notifications using Firebase Cloud Messaging
- User reports and admin report management

## Technology Stack

### Frontend

- Flutter
- Dart
- Material Design
- Firebase Core, Firebase Auth, Firebase Messaging
- Google Maps Flutter
- Razorpay Flutter
- Riverpod
- HTTP API integration

### Backend

- Node.js
- Express.js
- MySQL
- Firebase Admin SDK
- Multer for file uploads
- Razorpay Node SDK

### Database

- MySQL database named `physiotrack`
- Database schema is available in `backend/schema.sql`
- Optional seed data is available in `backend/seed.sql`


## Prerequisites

Install the following before running the project:

- Flutter SDK
- Dart SDK
- Android Studio or VS Code with Flutter extensions
- Node.js and npm
- MySQL Server
- Firebase project with Authentication and Cloud Messaging enabled
- Google Maps API key
- Razorpay test/live keys, if payment testing is required

## Restoring Dependencies After Download

This repository does not need to include generated dependency folders such as `build/`, `.dart_tool/`, or `backend/node_modules/`. If the project is downloaded from GitHub or extracted from a clean zip, restore the dependencies with these commands:

```bash
flutter pub get
cd backend
npm install
```

Run `flutter pub get` from the project root folder. Run `npm install` from inside the `backend/` folder.

## Backend Setup

1. Open a terminal in the backend folder:

```bash
cd backend
```

2. Install backend dependencies:

```bash
npm install
```

3. Configure MySQL.

Create a MySQL database using the schema file:

```bash
mysql -u root -p < schema.sql
```

If required, load sample data:

```bash
mysql -u root -p physiotrack < seed.sql
```

4. Check the database connection in `backend/db.js`.

Current local configuration:

```js
host: "127.0.0.1"
user: "root"
password: "root"
database: "physiotrack"
port: 3307
```

Update these values if your MySQL username, password, or port is different.

5. Create or update `backend/.env`.

Use the provided example file as a reference:

```text
PORT=4000
DB_HOST=127.0.0.1
DB_PORT=3307
DB_USER=root
DB_PASSWORD=root
DB_NAME=physiotrack
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
RAZORPAY_KEY_ID=your_razorpay_key_id
RAZORPAY_KEY_SECRET=your_razorpay_key_secret
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccountKey.json
```

6. Add the Firebase Admin service account JSON file as:

```text
backend/serviceAccountKey.json
```

7. Start the backend server:

```bash
npm start
```

The backend runs at:

```text
http://localhost:4000
```

## Flutter App Setup

1. Open a terminal in the project root:

```bash
cd physiotrack
```

2. Install Flutter dependencies:

```bash
flutter pub get
```

3. Ensure Firebase configuration files are available:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- Required iOS Firebase files if running on iOS

4. Check backend API URL in:

```text
lib/services/api_service.dart
```

Current values:

```dart
static const String _webBaseUrl = 'http://localhost:4000';
static const String _androidBaseUrl = 'http://--your wifi ipv4 addres --';
" androidBaseUrl will be used only when you want to run the app on the physical mobile , for this the mobile and backend server should be connect to the same wife , that wifi ipv4 address should be pasted in the above _androidBaseUrl"
```

For Android emulator, use:

```dart
http://10.0.2.2:4000
```

For a physical phone, use the computer's local network IP address and keep both devices on the same Wi-Fi network.

5. Run the Flutter app:

```bash
flutter run
```

## Running Tests

Run Flutter tests from the project root:

```bash
flutter test
```

## Important Notes for Evaluation

- Start the backend server before using the mobile/web app.
- MySQL must be running and the `physiotrack` database must be created.
- Firebase Authentication is required for login and token-based backend access.
- Google Maps features require a valid Google Maps API key.
- Razorpay payment features require valid Razorpay API keys.
- Uploaded files are stored inside `backend/uploads/`.
- Exercise videos are stored inside `backend/uploads/exercises/`.

## Suggested Zip Submission Contents

Include these folders and files:

- `android/`
- `assets/`
- `backend/`
- `ios/`
- `lib/`
- `test/`
- `web/`
- `windows/`, `linux/`, and `macos/` if desktop support is required
- `pubspec.yaml`
- `pubspec.lock`
- `analysis_options.yaml`
- `firebase.json`
- `README.md`

Avoid including generated or dependency folders in the final zip unless specifically required. These are safe to remove from the zip because they can be regenerated:

- `build/` located at the project root
- `.dart_tool/` located at the project root
- `backend/node_modules/` located inside the backend folder
- `.idea/` located at the project root
- `.vscode/` located at the project root, unless you want to share VS Code settings

Do not remove these dependency definition files:

- `pubspec.yaml`
- `pubspec.lock`
- `backend/package.json`
- `backend/package-lock.json`

The backend upload folder is different from dependencies. `backend/uploads/` contains uploaded/sample files. Remove it only if those uploaded files are not required for evaluation.

If API keys or Firebase service keys are included for department evaluation, delete or disable those keys from the respective provider dashboards after submission.

##Demo Video


https://github.com/user-attachments/assets/d2327a94-6bab-4fda-bb5b-632f2cc1c4a9



## To create a apk 
"flutter build apk --debug"

## Project Status

PhysioTrack is a semester project prototype that demonstrates a complete physiotherapy management workflow using Flutter, Node.js, MySQL, Firebase, Google Maps, and Razorpay integrations.
