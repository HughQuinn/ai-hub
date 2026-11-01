import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme_config.dart';
import 'providers/theme_provider.dart';
import 'pages/main_shell.dart';
import 'services/app_info.dart';
import 'services/update_service.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Map<String, dynamic>? _availableUpdate;

  @override
  void initState() {
    super.initState();
    _checkUpdateOnStartup();
  }

  void _checkUpdateOnStartup() async {
    final update = await UpdateService().checkForUpdate(AppInfo.version);
    if (mounted && update != null) {
      setState(() => _availableUpdate = update);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'AI Hub',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF5F2EE),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF5F2EE),
              foregroundColor: Color(0xFF1A1A1A),
              elevation: 0,
            ),
            cardColor: AppColors.cardBackground(isDark: false),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A1A1A),
              surface: Color(0xFFF5F2EE),
            ),
            snackBarTheme: const SnackBarThemeData(
              backgroundColor: Color(0xFF1F2937),
              contentTextStyle: TextStyle(color: Color(0xFFF9FAFB)),
              actionTextColor: Color(0xFF5EEAD4),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF111318),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF111318),
              foregroundColor: Color(0xFFF1F5F9),
              elevation: 0,
            ),
            cardColor: AppColors.cardBackground(isDark: true),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF1F5F9),
              surface: Color(0xFF111318),
            ),
            snackBarTheme: const SnackBarThemeData(
              backgroundColor: Color(0xFF374151),
              contentTextStyle: TextStyle(color: Color(0xFFF3F4F6)),
              actionTextColor: Color(0xFF5EEAD4),
            ),
          ),
          home: MainShell(
            initialUpdate: _availableUpdate,
            onClearUpdate: () => setState(() => _availableUpdate = null),
          ),
        );
      },
    );
  }
}
