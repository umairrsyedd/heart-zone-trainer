# ❤️ Heart Zone Trainer

Real-time heart rate zone monitoring app for athletes who want to optimize their training intensity.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Play Store](https://img.shields.io/badge/Play%20Store-Coming%20Soon-green?logo=google-play)](https://play.google.com/store)

<p align="center">
  <img src="screenshots/home_screen.png" width="250" alt="Home Screen">
  <img src="screenshots/zone_settings.png" width="250" alt="Zone Settings">
  <img src="screenshots/alert_management.png" width="250" alt="Alert Management">
</p>

## 🎯 About

Heart Zone Trainer shows you exactly which heart rate zone you're in—Zone 0 (Rest) through Zone 5 (Max)—so you can optimize every workout. Connect any Bluetooth Low Energy heart rate monitor and train smarter.

## ✨ Features

- **📊 Real-Time Monitoring** - Live heart rate display with animated visual feedback
- **🎨 Visual Zone Gauge** - Circular arc showing your current zone position
- **🔔 Smart Alerts** - Customizable notifications (sound, vibration, voice) for zone changes
- **📱 Compatible Devices** - Works with Polar, Garmin, Wahoo, Whoop, and any BLE HR monitor
- **⚙️ Personalized Zones** - Karvonen formula-based calculation using your resting and max HR
- **🌙 Dark Mode** - Easy to read mid-workout
- **🔄 Auto-Reconnect** - Automatically reconnects if connection drops
- **📲 Background Monitoring** - Continues tracking when app is in background

## 🏃 Heart Rate Zones

| Zone | Name      | % HRR   | Purpose                  |
| ---- | --------- | ------- | ------------------------ |
| 0    | Rest      | 0-49%   | Recovery                 |
| 1    | Light     | 50-59%  | Warm-up, cool-down       |
| 2    | Moderate  | 60-69%  | Fat burn, base fitness   |
| 3    | Tempo     | 70-79%  | Aerobic endurance        |
| 4    | Threshold | 80-89%  | Lactate threshold, speed |
| 5    | Maximum   | 90-100% | Peak performance         |

Zones are calculated using the **Karvonen Formula**:
Target HR = ((Max HR - Resting HR) × % Intensity) + Resting HR

## 🔗 Compatible Heart Rate Monitors

- **Polar** - H10, H9, OH1, Verity Sense
- **Garmin** - HRM-Pro, HRM-Dual, HRM-Run
- **Wahoo** - TICKR, TICKR X, TICKR FIT
- **Whoop** - 4.0 and newer
- **Coospo** - H6, H808S, HW807
- **Magene** - H303, H64
- Any other **Bluetooth Low Energy (BLE)** heart rate monitor

## 🛠️ Tech Stack

| Category         | Technology                 |
| ---------------- | -------------------------- |
| Framework        | Flutter 3.x                |
| Language         | Dart 3.x                   |
| State Management | Riverpod                   |
| Bluetooth        | flutter_blue_plus          |
| Local Storage    | shared_preferences         |
| Text-to-Speech   | flutter_tts                |
| Audio            | audioplayers               |
| Code Generation  | Freezed, JSON Serializable |

## 📱 Screenshots

<details>
<summary>Click to expand screenshots</summary>

### Home Screen - Active Monitoring

![Home Screen](screenshots/home_screen.png)

### Zone Settings

![Zone Settings](screenshots/zone_settings.png)

### Alert Management

![Alert Management](screenshots/alert_management.png)

### Settings

![Settings](screenshots/settings.png)

</details>

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.x or higher
- Android Studio / VS Code with Flutter extensions
- Android device with BLE support (for testing)
- A Bluetooth heart rate monitor

### Installation

1. **Clone the repository**

```bash
   git clone https://github.com/umairrsyedd/heart-zone-trainer.git
   cd heart-zone-trainer
```

2. **Install dependencies**

```bash
   flutter pub get
```

3. **Generate code (Freezed models)**

```bash
   dart run build_runner build --delete-conflicting-outputs
```

4. **Run the app**

```bash
   flutter run
```

### Building for Release

1. **Set up signing** (see [Flutter Android deployment docs](https://docs.flutter.dev/deployment/android))

2. **Build APK**

```bash
   flutter build apk --release
```

3. **Build App Bundle (for Play Store)**

```bash
   flutter build appbundle --release
```

## 📁 Project Structure

```
lib/
├── core/
│   ├── constants/     # App colors, zone info, constants
│   └── utils/         # Utility functions, helpers
├── data/
│   ├── models/        # Data models (Freezed)
│   └── services/      # BLE service, alert service
├── features/
│   ├── home/          # Home screen, circular gauge, heart animation
│   ├── settings/      # App settings, device connection
│   ├── zone_settings/ # Zone configuration
│   └── alert_management/ # Alert preferences
├── providers/         # Riverpod providers
├── widgets/           # Shared widgets
└── main.dart          # App entry point
```

## 🔐 Permissions

The app requires the following permissions:

| Permission           | Purpose               | Android Version      |
| -------------------- | --------------------- | -------------------- |
| BLUETOOTH_SCAN       | Scan for HR monitors  | Android 12+          |
| BLUETOOTH_CONNECT    | Connect to devices    | Android 12+          |
| BLUETOOTH            | Legacy Bluetooth      | Android 11 and below |
| ACCESS_FINE_LOCATION | BLE scanning (legacy) | Android 11 and below |
| POST_NOTIFICATIONS   | Zone change alerts    | Android 13+          |
| VIBRATE              | Vibration alerts      | All                  |
| FOREGROUND_SERVICE   | Background monitoring | All                  |

**Note:** Location permission is only requested on Android 11 and below (required for BLE scanning). Android 12+ users won't see location permission requests.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) style guidelines
- Use Riverpod for state management
- Use Freezed for data models
- Write meaningful commit messages
- Test on real BLE devices when possible

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔒 Privacy

Heart Zone Trainer respects your privacy:

- All data stays on your device
- No analytics or tracking
- No data sent to external servers
- No account required

See our [Privacy Policy](https://umairrsyedd.github.io/heart-zone-trainer-privacy/) for details.

## 📬 Contact

**Umair** - [@umairrsyedd](https://github.com/umairrsyedd)

Email: umairrsyedd@gmail.com

Project Link: [https://github.com/umairrsyedd/heart-zone-trainer](https://github.com/umairrsyedd/heart-zone-trainer)

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev/) - Beautiful native apps in record time
- [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) - BLE connectivity
- [Riverpod](https://riverpod.dev/) - State management
- [Freezed](https://pub.dev/packages/freezed) - Code generation for data classes
- The open source community

---

<p align="center">
  Made with ❤️ and Flutter
</p>
