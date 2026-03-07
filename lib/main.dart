import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/baby_theme.dart';
import 'services/content_service.dart';
import 'catalog/catalog_screen.dart';

/// Remote manifest URL (Azure Blob Storage).
/// Replace with your actual Azure Blob container URL.
const kRemoteManifestUrl =
    'https://asobaby.blob.core.windows.net/games/manifest.json';

late ContentService contentService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize content service
  contentService = ContentService(remoteManifestUrl: kRemoteManifestUrl);
  await contentService.init();

  // Enter immersive fullscreen (hide status bar + nav bar)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Lock to portrait for now (individual games can override)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const AsobabyApp());
}

class AsobabyApp extends StatelessWidget {
  const AsobabyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asobaby',
      debugShowCheckedModeBanner: false,
      theme: BabyTheme.themeData,
      home: const CatalogScreen(),
    );
  }
}
