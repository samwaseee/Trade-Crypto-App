# Trade Crypto App

Trade Crypto is a user-friendly mobile application that allows users to trade cryptocurrencies, manage their portfolio, and stay updated with the latest market trends. This app is designed to provide a seamless trading experience with an intuitive interface and robust features.

## Screenshots

### Splash Screen
![Splash Screen](url_to_splash_screen_image)
- **Description**: A bright yellow background with the app name "Trade Crypto" and the creator's name at the bottom.

### Welcome Screen
![Welcome Screen](url_to_welcome_screen_image)
- **Description**: Includes a dynamic Bitcoin icon, title "The Future," description, input fields for email and password, and buttons for logging in or creating a new portfolio.

### Register Screen
![Register Screen](url_to_register_screen_image)
- **Description**: Allows users to create a new portfolio with input fields for name, phone number, email, and password. Information is stored securely using Firebase Authentication and Firestore.

### Login Success Message
![Login Success](url_to_login_success_image)
- **Description**: A success message informing users of a successful login. Includes a portfolio balance, assets section, and recommendations.

### Profile Screen
![Profile Screen](url_to_profile_screen_image)
- **Description**: Displays user profile information with fields for email, name, and phone number. Users can edit their information or log out securely.

### Profile Editing Confirmation
![Profile Editing Confirmation](url_to_profile_editing_image)
- **Description**: Confirms that the profile has been updated successfully with a message "Profile updated successfully!" displayed at the bottom of the screen.

### Notification Screen
![Notification Screen](url_to_notification_screen_image)
- **Description**: Displays recent trade changes with icons, market information, and a bottom navigation bar for easy access to other features.

### News Screen
![News Screen](url_to_news_screen_image)
- **Description**: Provides the latest market updates and financial news with images, headlines, brief descriptions, and a prompt to read more.

### Individual Coin Trade Screen
![Individual Coin Trade Screen](url_to_individual_coin_trade_screen_image)
- **Description**: Provides detailed information about a specific cryptocurrency, including current price, percentage change, market metrics, a candlestick chart, news integration, and easy trading options.

### Trade Alert Screen
![Trade Alert Screen](url_to_trade_alert_screen_image)
- **Description**: Provides real-time notifications about buying or selling actions with detailed price information, market metrics, a candlestick chart, and news integration.

### Transaction History
- **Description**: Displays the user's transaction history sorted by the latest date, with detailed profit and coin data.
- **User Interaction**:
    - Tap on a transaction to view more details or close a trade.
    - Confirm trade closures via a modal dialog with profit calculations.

### Recommendations
- **Description**: Lists top cryptocurrency recommendations for buying based on market trends.
- **Features**:
    - Horizontal scrollable view of coins with real-time price updates.
    - Integrated market API for accurate recommendations.
    - Displays a loading state during data fetch.

## Features

- **User-Friendly Interface**: Easy navigation and intuitive design.
- **Secure Authentication**: Uses Firebase Authentication for secure login and registration.
- **Portfolio Management**: View and manage your cryptocurrency portfolio.
- **Market Trends**: Stay updated with the latest market trends and recommendations.
- **Profile Management**: View and edit your profile information, with confirmation messages upon successful updates.
- **Notifications**: Receive timely updates about significant market changes.
- **News Updates**: Stay informed with the latest financial news and market updates.
- **Individual Coin Trading**: Detailed trading information and options for each cryptocurrency.
- **Real-Time Trade Alerts**: Immediate notifications about buying or selling actions.
- **Transaction History**: Manage trades with real-time profit/loss calculations.
- **Recommendations**: Curated list of trending cryptocurrencies with actionable insights.

## Dependencies

Your project relies on the following dependencies:

```yaml
dependencies:
  cupertino_icons: ^1.0.8
  http: ^0.13.3
  chart_sparkline: ^1.0.12
  syncfusion_flutter_charts: ^20.4.48
  firebase_core: ^3.8.0
  firebase_auth: ^5.3.3
  cloud_firestore: ^5.5.0
  url_launcher: ^6.0.13
  intl: ^0.17.0
  flutter_dotenv: ^5.0.3
```

### Package Descriptions

1. **`cupertino_icons`**: Adds the Cupertino Icons font to your application, enabling iOS style icons.
2. **`http`**: A package for making HTTP requests to fetch or send data to a server.
3. **`chart_sparkline`**: Provides sparklines (small inline charts) for visual data representation.
4. **`syncfusion_flutter_charts`**: A library offering a variety of charts for complex data visualizations.
5. **`firebase_core`**: Initializes and uses Firebase services in your Flutter app.
6. **`firebase_auth`**: Enables Firebase authentication for user sign-in and management.
7. **`cloud_firestore`**: Integrates Cloud Firestore for real-time database functionalities.
8. **`url_launcher`**: A package to launch URLs in the mobile platform's browser or other applications.
9. **`intl`**: Supports internationalization and localization, including date, number, and currency formatting.
10. **`flutter_dotenv`**: Loads environment variables from a `.env` file to securely manage configuration and sensitive information.

## Getting Started

Here’s an example of how to initialize Firebase and run the app:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:my_crypto/View/splash_screen.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
```

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/trade-crypto-app.git
   ```
2. Navigate to the project directory:
   ```bash
   cd trade-crypto-app
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## Technologies Used

- **Flutter**: For building the cross-platform mobile application.
- **Firebase Authentication**: For secure user authentication.
- **Firestore Database**: For storing user information and data.

## Contributing

Contributions are welcome! Please read the [contributing guidelines](CONTRIBUTING.md) for more information.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

Thank you for using Trade Crypto! If you have any questions or need further assistance, feel free to contact us.

