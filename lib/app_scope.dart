import 'package:material_ui/material_ui.dart';
import 'services/api_client.dart';
import 'services/favorites_store.dart';
import 'theme/one_ui_theme.dart';

/// Inherited dependency container sharing API client, favorites, and theme controller.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.favorites,
    required this.themeController,
    required super.child,
  });

  final PksttApiClient api;
  final FavoritesStore favorites;
  final ThemeController themeController;

  static AppScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>();

  static AppScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      api != oldWidget.api ||
      favorites != oldWidget.favorites ||
      themeController != oldWidget.themeController;
}
