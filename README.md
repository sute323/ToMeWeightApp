# Weight Tracker App

A personal weight tracking application built with Flutter.

## Features
- **Dark Mode**: Deep dark theme for comfortable viewing.
- **Daily Tracking**: Log Weight, Body Fat, Muscle Mass.
- **Stamps & Memos**: Add multiple stamps and memos per day.
- **Trends**: View weekly and monthly graphs.
- **CSV Import**: Import data from other apps.
- **Local Storage**: Data is stored locally using Hive.

## How to Run

Since the project files were generated manually, you need to perform a one-time setup to generate the Android build files.

1.  **Open a Terminal** (Command Prompt or PowerShell).
2.  **Navigate to the project directory**:
    ```powershell
    cd C:\Users\alred\.gemini\antigravity\playground\warped-nadir\weight_tracker
    ```
3.  **Generate Build Files**:
    Run the following command to recreate the Android/iOS project structure:
    ```powershell
    flutter create .
    ```
    *(Note the dot `.` at the end, which means "current directory")*

4.  **Install Dependencies**:
    ```powershell
    flutter pub get
    ```

5.  **Run the App**:
    Connect your Android phone via USB (ensure USB Debugging is on) and run:
    ```powershell
    flutter run
    ```

## Troubleshooting
- If you see errors about `minSdkVersion`, open `android/app/build.gradle` (after running `flutter create .`) and change `minSdkVersion` to `21` or higher.
- If `flutter create .` fails, ensure you have Flutter installed and in your PATH.
