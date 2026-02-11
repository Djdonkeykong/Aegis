# Drug Interaction Checker - Flutter App

A beautiful, simple one-page Flutter app for checking drug interactions using the FDA API.

## Features

✅ **Check Two Drugs** - Instant interaction checking with severity indicators  
✅ **My Medications** - Save and manage your medication list  
✅ **Beautiful UI** - Modern, clean design with intuitive navigation  
✅ **Severity Levels** - Clear visual indicators (🔴 High, 🟡 Moderate, 🟢 Low)  
✅ **FDA Data** - Real-time data from OpenFDA API  
✅ **Privacy First** - No data collection, all processing on device  

## Screenshots

- Clean, modern interface
- Easy drug name input
- Clear severity indicators
- Medication list management
- Helpful disclaimers

## Setup Instructions

### Prerequisites

1. **Install Flutter**
   - Download from: https://flutter.dev/docs/get-started/install
   - Follow installation guide for your OS

2. **Verify Installation**
   ```bash
   flutter doctor
   ```

### Quick Start

1. **Create Flutter Project**
   ```bash
   flutter create drug_interaction_checker
   cd drug_interaction_checker
   ```

2. **Replace Files**
   - Replace `lib/main.dart` with `drug_checker_app.dart`
   - Replace `pubspec.yaml` with the provided one

3. **Get Dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the App**
   
   **On Android Emulator/Device:**
   ```bash
   flutter run
   ```
   
   **On iOS Simulator (Mac only):**
   ```bash
   flutter run
   ```
   
   **On Web:**
   ```bash
   flutter run -d chrome
   ```
   
   **On Desktop (Windows/Mac/Linux):**
   ```bash
   flutter run -d windows  # or macos, linux
   ```

## Project Structure

```
drug_interaction_checker/
├── lib/
│   └── main.dart                 # Main app code
├── pubspec.yaml                  # Dependencies
└── README.md                     # This file
```

## How to Use

1. **Check Interaction**
   - Enter first drug name (e.g., "warfarin")
   - Enter second drug name (e.g., "ibuprofen")
   - Tap "Check Interaction"
   - View severity level and summary

2. **Manage Medications**
   - Tap the "+" button in "My Medications"
   - Add your regular medications
   - Remove by tapping the X on any chip

3. **Future Feature** (Not yet implemented)
   - Check new drug against all saved medications

## API Details

**OpenFDA API:**
- Endpoint: `https://api.fda.gov/drug/label.json`
- No API key required
- Rate limit: 240 requests per minute (for testing)
- Production rate limit: 1000 requests per minute with API key

## Technical Stack

- **Framework:** Flutter 3.0+
- **Language:** Dart
- **HTTP Client:** http package
- **Design:** Material Design 3
- **Data Source:** OpenFDA API

## Features Breakdown

### Implemented ✅
- Two-drug interaction checking
- Severity detection (High/Moderate/Low)
- Medication list management (add/remove)
- Beautiful modern UI
- Error handling
- Loading states
- Disclaimers

### Coming Soon 🚀
- Check against all saved medications
- Local database for offline caching
- History tracking
- Export results
- Push notifications for interactions
- Drug name autocomplete
- Barcode scanning

## Customization

### Change Colors
Edit the theme in `main.dart`:
```dart
theme: ThemeData(
  primarySwatch: Colors.blue, // Change to your color
  // ...
)
```

### Adjust API Timeout
In `fetchDrugInteractions()`:
```dart
.timeout(const Duration(seconds: 10)) // Change timeout
```

## Building for Production

### Android APK
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS App
```bash
flutter build ios --release
```
Then open Xcode to archive and upload

### Web
```bash
flutter build web --release
```
Output: `build/web/`

### Desktop
```bash
flutter build windows --release  # or macos, linux
```

## Known Limitations

1. **No Local AI** - Uses rule-based summaries (no Ollama integration yet)
2. **Basic Summaries** - Extracts key sentences from FDA data
3. **No Caching** - Every check hits the API (add later for production)
4. **No History** - Checks aren't saved (add database later)

## Future Enhancements

1. **Backend Integration** - Connect to Python MVP for AI summaries
2. **Local Database** - SQLite for caching and history
3. **Push Notifications** - Alert for dangerous interactions
4. **User Accounts** - Sync across devices
5. **QR Code** - Scan prescription labels
6. **Multi-language** - Support for Spanish, French, etc.

## Troubleshooting

**Issue:** "flutter not found"  
**Solution:** Add Flutter to PATH, restart terminal

**Issue:** App won't run  
**Solution:** Run `flutter doctor` and fix any issues

**Issue:** API errors  
**Solution:** Check internet connection, verify FDA API is up

**Issue:** Build errors  
**Solution:** Run `flutter clean` then `flutter pub get`

## License

Free to use for personal and commercial projects.

## Disclaimer

⚠️ This app provides information from FDA databases but is not a substitute for professional medical advice. Always consult your healthcare provider before making medication decisions.

## Credits

- **OpenFDA API** - https://open.fda.gov
- **Flutter** - https://flutter.dev
- **Material Icons** - https://fonts.google.com/icons

## Support

For issues or questions, refer to:
- Flutter docs: https://docs.flutter.dev
- OpenFDA docs: https://open.fda.gov/apis

---

**Made with ❤️ for safer medication management**
