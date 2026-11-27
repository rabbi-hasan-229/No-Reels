import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const NoDoomApp());
}

class NoDoomApp extends StatelessWidget {
  const NoDoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppUiController.instance,
      builder: (context, _) {
        final ui = AppUiController.instance;
        final palette = ui.palette;
        final fontSettings = ui.fontSettings;

        return MaterialApp(
          title: 'No-Reels',
          debugShowCheckedModeBanner: false,
          theme: palette.buildThemeData(fontSettings: fontSettings),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(fontSettings.uiTextScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}
