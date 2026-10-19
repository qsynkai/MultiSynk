import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/app_theme.dart';
import 'app.dart';
import 'screens/login_screen.dart';
import 'services/supabase_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  try {
    await SupabaseService.initialize();
    ConnectivityService.instance.start();
    DatabaseHelper.instance.onLocalChange = SyncService.scheduleSync;
  } catch (_) {}
  try {
    await HomeWidget.setAppGroupId('group.com.focusbudget.app');
  } catch (_) {}

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final loggedUser = await LoginScreen.loggedUser();

  runApp(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MultiSynk',
        theme: buildTheme(),
        home: loggedUser != null ? const MultiSynkApp() : const LoginScreen(),
      ),
    ),
  );
}
