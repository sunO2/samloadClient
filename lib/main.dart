import 'package:firmware_client/page/check_page.dart';
import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:dynamic_color/dynamic_color.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // 确保 Flutter 引擎已初始化
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'SamLoadF',
          darkTheme: null != darkDynamic
              ? ThemeData.dark(
                  useMaterial3: true,
                ).copyWith(colorScheme: darkDynamic)
              : FlexThemeData.dark(
                  useMaterial3: true,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.deepPurple,
                  ),
                ),
          theme: null != lightDynamic
              ? ThemeData.light(
                  useMaterial3: true,
                ).copyWith(colorScheme: lightDynamic)
              : FlexThemeData.light(
                  useMaterial3: true,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.deepPurple,
                  ),
                ),
          home: const MyHomePage(title: 'SamLoadF'),
        );
      },
    );
  }
}
