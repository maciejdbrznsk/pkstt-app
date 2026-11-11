import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_scope.dart';
import 'screens/home_screen.dart';
import 'services/api_client.dart';
import 'services/favorites_store.dart';
import 'services/map_tile_cache.dart';
import 'services/offline_cache.dart';
import 'theme/one_ui_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final themeController = ThemeController(prefs);
  final favoritesStore = FavoritesStore(prefs);
  final cacheStore = await DiskOfflineCacheStore.createDefault();
  final apiClient = PksttApiClient(cacheStore: cacheStore);
  await MapTileCache.init(isOffline: () => apiClient.isOffline.value);

  runApp(
    PksttApp(
      apiClient: apiClient,
      favoritesStore: favoritesStore,
      themeController: themeController,
    ),
  );
}

class PksttApp extends StatelessWidget {
  const PksttApp({
    super.key,
    required this.apiClient,
    required this.favoritesStore,
    required this.themeController,
  });

  final PksttApiClient apiClient;
  final FavoritesStore favoritesStore;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            return AppScope(
              api: apiClient,
              favorites: favoritesStore,
              themeController: themeController,
              child: MaterialApp(
                title: 'PKSTT Rzeszów',
                debugShowCheckedModeBanner: false,
                themeMode: themeController.themeMode,
                theme: buildOneUiTheme(
                  brightness: Brightness.light,
                  dynamicScheme: lightDynamic,
                  useDynamicColor: themeController.useDynamicColor,
                  customAccent: themeController.customAccent,
                ),
                darkTheme: buildOneUiTheme(
                  brightness: Brightness.dark,
                  dynamicScheme: darkDynamic,
                  useDynamicColor: themeController.useDynamicColor,
                  customAccent: themeController.customAccent,
                ),
                home: const HomeScreen(),
              ),
            );
          },
        );
      },
    );
  }
}
