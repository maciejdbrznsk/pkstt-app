import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Custom One UI 9 palette extension separating canvas, elevated cards, and operator colors.
@immutable
class OneUiPalette extends ThemeExtension<OneUiPalette> {
  const OneUiPalette({
    required this.canvas,
    required this.card,
    required this.cardAlt,
    required this.ink,
    required this.inkSecondary,
    required this.divider,
    required this.accent,
    required this.accentSoft,
    required this.ztmOrange,
    required this.ztmSoft,
    required this.pksBlue,
    required this.pksSoft,
    required this.nightInk,
    required this.liveGreen,
    required this.liveGreenSoft,
    required this.warnAmber,
    required this.dangerRed,
    required this.dangerSoft,
  });

  final Color canvas;
  final Color card;
  final Color cardAlt;
  final Color ink;
  final Color inkSecondary;
  final Color divider;
  final Color accent;
  final Color accentSoft;
  final Color ztmOrange;
  final Color ztmSoft;
  final Color pksBlue;
  final Color pksSoft;
  final Color nightInk;
  final Color liveGreen;
  final Color liveGreenSoft;
  final Color warnAmber;
  final Color dangerRed;
  final Color dangerSoft;

  static const Color defaultSamsungBlue = Color(0xFF0381FE);

  factory OneUiPalette.light({Color? accentOverride}) {
    final accent = accentOverride ?? defaultSamsungBlue;
    return OneUiPalette(
      canvas: const Color(0xFFF1F2F5),
      card: const Color(0xFFFFFFFF),
      cardAlt: const Color(0xFFF7F8FA),
      ink: const Color(0xFF050507),
      inkSecondary: const Color(0xFF63656E),
      divider: const Color(0xFFE5E7ED),
      accent: accent,
      accentSoft: accent.withValues(alpha: 0.12),
      ztmOrange: const Color(0xFFD32A00),
      ztmSoft: const Color(0xFFFFEDE8),
      pksBlue: const Color(0xFF007EA7),
      pksSoft: const Color(0xFFE5F5FA),
      nightInk: const Color(0xFF1A1D28),
      liveGreen: const Color(0xFF0F9D58),
      liveGreenSoft: const Color(0xFFE4F6EC),
      warnAmber: const Color(0xFFD97706),
      dangerRed: const Color(0xFFDC2626),
      dangerSoft: const Color(0xFFFEECEC),
    );
  }

  factory OneUiPalette.dark({Color? accentOverride}) {
    final accent = accentOverride ?? const Color(0xFF3E9BFF);
    return OneUiPalette(
      canvas: const Color(0xFF000000),
      card: const Color(0xFF17171B),
      cardAlt: const Color(0xFF222228),
      ink: const Color(0xFFF8F9FC),
      inkSecondary: const Color(0xFF989AA6),
      divider: const Color(0xFF2A2A32),
      accent: accent,
      accentSoft: accent.withValues(alpha: 0.18),
      ztmOrange: const Color(0xFFFF5933),
      ztmSoft: const Color(0xFF3A1A14),
      pksBlue: const Color(0xFF28B5D9),
      pksSoft: const Color(0xFF102B35),
      nightInk: const Color(0xFF272B3A),
      liveGreen: const Color(0xFF2DD47C),
      liveGreenSoft: const Color(0xFF0F2D1E),
      warnAmber: const Color(0xFFFBBF24),
      dangerRed: const Color(0xFFF87171),
      dangerSoft: const Color(0xFF381619),
    );
  }

  @override
  OneUiPalette copyWith({
    Color? canvas,
    Color? card,
    Color? cardAlt,
    Color? ink,
    Color? inkSecondary,
    Color? divider,
    Color? accent,
    Color? accentSoft,
    Color? ztmOrange,
    Color? ztmSoft,
    Color? pksBlue,
    Color? pksSoft,
    Color? nightInk,
    Color? liveGreen,
    Color? liveGreenSoft,
    Color? warnAmber,
    Color? dangerRed,
    Color? dangerSoft,
  }) {
    return OneUiPalette(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      cardAlt: cardAlt ?? this.cardAlt,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      divider: divider ?? this.divider,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      ztmOrange: ztmOrange ?? this.ztmOrange,
      ztmSoft: ztmSoft ?? this.ztmSoft,
      pksBlue: pksBlue ?? this.pksBlue,
      pksSoft: pksSoft ?? this.pksSoft,
      nightInk: nightInk ?? this.nightInk,
      liveGreen: liveGreen ?? this.liveGreen,
      liveGreenSoft: liveGreenSoft ?? this.liveGreenSoft,
      warnAmber: warnAmber ?? this.warnAmber,
      dangerRed: dangerRed ?? this.dangerRed,
      dangerSoft: dangerSoft ?? this.dangerSoft,
    );
  }

  @override
  OneUiPalette lerp(ThemeExtension<OneUiPalette>? other, double t) {
    if (other is! OneUiPalette) return this;
    return OneUiPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardAlt: Color.lerp(cardAlt, other.cardAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      ztmOrange: Color.lerp(ztmOrange, other.ztmOrange, t)!,
      ztmSoft: Color.lerp(ztmSoft, other.ztmSoft, t)!,
      pksBlue: Color.lerp(pksBlue, other.pksBlue, t)!,
      pksSoft: Color.lerp(pksSoft, other.pksSoft, t)!,
      nightInk: Color.lerp(nightInk, other.nightInk, t)!,
      liveGreen: Color.lerp(liveGreen, other.liveGreen, t)!,
      liveGreenSoft: Color.lerp(liveGreenSoft, other.liveGreenSoft, t)!,
      warnAmber: Color.lerp(warnAmber, other.warnAmber, t)!,
      dangerRed: Color.lerp(dangerRed, other.dangerRed, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
    );
  }
}

extension OneUiThemeContext on BuildContext {
  OneUiPalette get oneUi => Theme.of(this).extension<OneUiPalette>()!;
}

/// Curated One UI 9 accent color presets available when Dynamic Color is off.
const List<({String name, Color color})> kOneUiAccentPresets = [
  (name: 'Samsung Niebieski', color: OneUiPalette.defaultSamsungBlue),
  (name: 'MPK Pomarańcz', color: Color(0xFFE04819)),
  (name: 'PKS Błękit', color: Color(0xFF007EA7)),
  (name: 'Szmaragd', color: Color(0xFF0F9D58)),
  (name: 'Indygo', color: Color(0xFF5B5FEF)),
  (name: 'Fiolet', color: Color(0xFF8B5CF6)),
  (name: 'Malina', color: Color(0xFFE11D48)),
  (name: 'Turkus', color: Color(0xFF00897B)),
];

Color _adaptAccentForBrightness(Color base, Brightness brightness) {
  if (brightness != Brightness.dark) return base;
  final hsl = HSLColor.fromColor(base);
  if (hsl.lightness < 0.56) {
    return hsl.withLightness(0.58).toColor();
  }
  return base;
}

/// Builds a One UI 9 styled ThemeData without standard Material Design chrome.
ThemeData buildOneUiTheme({
  required Brightness brightness,
  ColorScheme? dynamicScheme,
  required bool useDynamicColor,
  Color? customAccent,
}) {
  final isDark = brightness == Brightness.dark;
  final rawAccent = useDynamicColor ? dynamicScheme?.primary : customAccent;
  final accentOverride =
      rawAccent != null ? _adaptAccentForBrightness(rawAccent, brightness) : null;
  final palette = isDark
      ? OneUiPalette.dark(accentOverride: accentOverride)
      : OneUiPalette.light(accentOverride: accentOverride);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: palette.accent,
    onPrimary: Colors.white,
    secondary: palette.pksBlue,
    onSecondary: Colors.white,
    error: palette.dangerRed,
    onError: Colors.white,
    surface: palette.card,
    onSurface: palette.ink,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.canvas,
    canvasColor: palette.canvas,
    splashFactory: InkSparkle.splashFactory,
    highlightColor: palette.accent.withValues(alpha: 0.06),
    dividerColor: palette.divider,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: palette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: palette.ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: palette.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: palette.ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.5,
        color: palette.ink,
      ),
      bodySmall: TextStyle(
        fontSize: 12.5,
        color: palette.inkSecondary,
      ),
    ),
    extensions: [palette],
  );
}

/// Persists light/dark mode, dynamic color preference, and advanced bus info toggles.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    final modeIdx = _prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[modeIdx.clamp(0, ThemeMode.values.length - 1)];
    _useDynamicColor = _prefs.getBool(_dynamicColorKey) ?? true;
    final savedAccent = _prefs.getInt(_customAccentKey);
    _customAccent = savedAccent != null
        ? Color(savedAccent)
        : OneUiPalette.defaultSamsungBlue;
    _showAdvancedBusInfo = _prefs.getBool(_showAdvBusKey) ?? false;
    _showBusNumber = _prefs.getBool(_showBusNumberKey) ?? true;
    _showBusPlate = _prefs.getBool(_showBusPlateKey) ?? true;
    _showBusBrigade = _prefs.getBool(_showBusBrigadeKey) ?? true;
    _showBusLowFloor = _prefs.getBool(_showBusLowFloorKey) ?? true;
  }

  static const _themeModeKey = 'pkstt_theme_mode';
  static const _dynamicColorKey = 'pkstt_dynamic_color';
  static const _customAccentKey = 'pkstt_custom_accent';
  static const _showAdvBusKey = 'pkstt_show_adv_bus_info';
  static const _showBusNumberKey = 'pkstt_show_bus_number';
  static const _showBusPlateKey = 'pkstt_show_bus_plate';
  static const _showBusBrigadeKey = 'pkstt_show_bus_brigade';
  static const _showBusLowFloorKey = 'pkstt_show_bus_low_floor';

  final SharedPreferences _prefs;
  late ThemeMode _themeMode;
  late bool _useDynamicColor;
  late Color _customAccent;
  late bool _showAdvancedBusInfo;
  late bool _showBusNumber;
  late bool _showBusPlate;
  late bool _showBusBrigade;
  late bool _showBusLowFloor;

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;
  Color get customAccent => _customAccent;
  bool get showAdvancedBusInfo => _showAdvancedBusInfo;
  bool get showBusNumber => _showBusNumber;
  bool get showBusPlate => _showBusPlate;
  bool get showBusBrigade => _showBusBrigade;
  bool get showBusLowFloor => _showBusLowFloor;

  bool get displayBusNumber => _showAdvancedBusInfo && _showBusNumber;
  bool get displayBusPlate => _showAdvancedBusInfo && _showBusPlate;
  bool get displayBusBrigade => _showAdvancedBusInfo && _showBusBrigade;
  bool get displayBusLowFloor => _showAdvancedBusInfo && _showBusLowFloor;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _prefs.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  Future<void> setUseDynamicColor(bool enabled) async {
    if (_useDynamicColor == enabled) return;
    _useDynamicColor = enabled;
    await _prefs.setBool(_dynamicColorKey, enabled);
    notifyListeners();
  }

  Future<void> setCustomAccent(Color color) async {
    if (_customAccent.toARGB32() == color.toARGB32()) return;
    _customAccent = color;
    await _prefs.setInt(_customAccentKey, color.toARGB32());
    notifyListeners();
  }

  Future<void> setShowAdvancedBusInfo(bool enabled) async {
    if (_showAdvancedBusInfo == enabled) return;
    _showAdvancedBusInfo = enabled;
    await _prefs.setBool(_showAdvBusKey, enabled);
    notifyListeners();
  }

  Future<void> setShowBusNumber(bool enabled) async {
    if (_showBusNumber == enabled) return;
    _showBusNumber = enabled;
    await _prefs.setBool(_showBusNumberKey, enabled);
    notifyListeners();
  }

  Future<void> setShowBusPlate(bool enabled) async {
    if (_showBusPlate == enabled) return;
    _showBusPlate = enabled;
    await _prefs.setBool(_showBusPlateKey, enabled);
    notifyListeners();
  }

  Future<void> setShowBusBrigade(bool enabled) async {
    if (_showBusBrigade == enabled) return;
    _showBusBrigade = enabled;
    await _prefs.setBool(_showBusBrigadeKey, enabled);
    notifyListeners();
  }

  Future<void> setShowBusLowFloor(bool enabled) async {
    if (_showBusLowFloor == enabled) return;
    _showBusLowFloor = enabled;
    await _prefs.setBool(_showBusLowFloorKey, enabled);
    notifyListeners();
  }
}
