import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:yaltes_car_app/admin/admin_home_shell.dart';
import 'package:yaltes_car_app/admin/admin_pages/add_vehicle_page.dart';
import 'package:yaltes_car_app/admin/admin_pages/admin_cars_page.dart';
import 'package:yaltes_car_app/admin/admin_pages/admin_edit_car_page.dart';
import 'package:yaltes_car_app/admin/admin_pages/admin_login_page.dart';
import 'package:yaltes_car_app/features/location/location_picker_page.dart';
import 'package:yaltes_car_app/models/vehicle.dart';
import 'package:yaltes_car_app/pages/calendar_page.dart';
import 'package:yaltes_car_app/pages/car_detail_page.dart';
import 'package:yaltes_car_app/pages/create_booking_page.dart';
import 'package:yaltes_car_app/pages/home_shell.dart';
import 'package:yaltes_car_app/pages/login_page.dart';
import 'package:yaltes_car_app/pages/notifications_page.dart';
import 'package:yaltes_car_app/pages/settings_page.dart';
import 'package:yaltes_car_app/pages/sign_up_page.dart';
import 'package:yaltes_car_app/services/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    // await Firebase.initializeApp(
    //   options: DefaultFirebaseOptions.currentPlatform,
    // );
    await _initPush();
  }

  final api = ApiClient.instance;
  final loggedIn = await api.loadToken();

  await _initPush();

  runApp(MyApp(initialRoute: loggedIn ? HomeShell.route : LoginPage.route));
}

Future<void> _initPush() async {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS)
    return;

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
  final token = await messaging.getToken();
  debugPrint('Push token: $token');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialRoute = LoginPage.route});
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: initialRoute,
      routes: {
        LoginPage.route: (_) => LoginPage(),
        SignUpPage.route: (_) => SignUpPage(),
        HomeShell.route: (_) => const HomeShell(),
        NotificationsPage.route: (_) => const NotificationsPage(),
        SettingsPage.route: (_) => const SettingsPage(),
        CarDetailPage.route: (ctx) {
          final v = ModalRoute.of(ctx)!.settings.arguments as Vehicle;
          return CarDetailPage(vehicle: v);
        },
        CreateBookingPage.route: (ctx) {
          final v = ModalRoute.of(ctx)!.settings.arguments as Vehicle;
          return CreateBookingPage(vehicle: v);
        },
        LocationPickerPage.route: (_) => const LocationPickerPage(),

        AdminLoginPage.route: (_) => const AdminLoginPage(),
        AdminHomeShell.route: (_) => const AdminHomeShell(),
        AdminCarsPage.route: (_) => const AdminCarsPage(),
        CalendarPage.route: (_) => const CalendarPage(),
        AddVehiclePage.route: (_) => const AddVehiclePage(),
        AdminEditCarPage.route: (ctx) {
          final args =
              ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>?;
          return AdminEditCarPage(car: args);
        },
      },
    );
  }
}

ThemeData _buildTheme() {
  const yaltesPurple = Color(0xFF232B74);
  const yaltesPurpleDark = Color(0xFF3C3F86);
  const indigo = Color(0xFF9FA8DA);
  const available = Color(0xFF5BA44C);
  const inUse = Color.fromARGB(255, 180, 60, 60);
  const cardGrey = Color(0xFFE8EAF6);
  const white = Colors.white;

  final base = ThemeData(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: white,
    canvasColor: white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: yaltesPurple,
      primary: yaltesPurple,
      secondary: indigo,
      error: inUse,
      surface: white,
      background: white,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: white,
      foregroundColor: yaltesPurple,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      color: cardGrey,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: yaltesPurple,
      foregroundColor: white,
      shape: CircleBorder(),
    ),
    bottomAppBarTheme: const BottomAppBarThemeData(
      color: indigo,
      elevation: 2,
      shape: CircularNotchedRectangle(),
      padding: EdgeInsets.symmetric(horizontal: 24),
    ),
    textTheme: base.textTheme.copyWith(
      titleLarge: const TextStyle(
        fontWeight: FontWeight.w700,
        color: yaltesPurple,
        letterSpacing: 0.2,
      ),
      titleMedium: const TextStyle(
        fontWeight: FontWeight.w600,
        color: yaltesPurpleDark,
      ),
      bodyMedium: const TextStyle(fontSize: 14),
    ),
    iconTheme: const IconThemeData(color: yaltesPurple),
  );
}
