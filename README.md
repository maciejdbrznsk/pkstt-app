# PKSTT Rzeszów (pkstt-app)

Aplikacja mobilna we **Flutterze** do sprawdzania rozkładów jazdy oraz śledzenia autobusów na żywo w Rzeszowie i okolicach (**MPK / ZTM Rzeszów** oraz **MKS / PKS Rzeszów**).

Interfejs został zaprojektowany w stylistyce inspirowanej **One UI 9** (bez domyślnego wyglądu Material 3), z podglądem przebiegu kursu w stylu **mobileMPK** (dwie ścieżki na trasie: planowa oraz rzeczywista GPS) i obsługą map **OpenStreetMap**.

## Funkcje aplikacji

- **Ekran główny:** szybki dostęp do rozkładu przystanków, rozkładu linii, mapy na żywo, komunikatów przewoźników oraz listy ulubionych przystanków i słupków.
- **Rozkład jazdy przystanku:** ulubione, pobliskie przystanki (GPS, także offline), kompaktowa wyszukiwarka A–Z bez rozróżniania polskich znaków, wybór wariantu/słupka z kierunkami oraz najbliższe odjazdy z okna 24h wraz ze statusem lokalizacji na żywo.
- **Śledzenie kursu (mobileMPK):** pionowa oś trasy pokazująca jednocześnie teoretyczną pozycję **planową** i **rzeczywistą GPS**, zwijana mapa kursu z trybem pełnoekranowym oraz opcjonalne szczegóły pojazdu (numer boczny, rejestracja, brygada, niska podłoga) w Ustawieniach.
- **Rozkład jazdy linii:** rozróżnienie kolorystyczne linii **MPK** (oraz linii nocnych) i **MKS / PKS**, wybór kierunku, kolejności przystanków na trasie oraz „tabliczka przystankowa” z legendą wariantów i podziałem na dni robocze, soboty i święta.
- **Mapa na żywo (OpenStreetMap):** pozycje autobusów MPK i PKS na żywo, przystanki filtrowane względem widocznego obszaru mapy po przybliżeniu oraz trwały cache kafelków mapy na dysku.
- **Tryb offline i wersjonowane aktualizacje:** lokalne buforowanie pobranych rozkładów (skompresowane pliki `.json.gz`), weryfikacja zmian przez `/v1/meta` bez ponownego pobierania niezmienionych rozkładów, pasek statusu offline oraz zarządzanie pamięcią lokalną w Ustawieniach.
- **Motyw i kolorystyka:** tryb System / Jasny / AMOLED, kolorystyka dynamiczna Android 13+ oraz ręczny wybór koloru akcentu przy wyłączonym kolorze dynamicznym.

## Wymagania

- **Flutter / Dart:** Dart SDK `^3.14.0`
- **Android:** `minSdk = 33` (Android 13+)
- **iOS:** projekt bazowy skonfigurowany w `ios/` (`IPHONEOS_DEPLOYMENT_TARGET = 15.0`); kompilacja i podpisanie wymagają systemu **macOS** z **Xcode** oraz konta Apple Developer przy wdrażaniu na urządzenie.
- **Backend:** kompatybilne API `pkstt-backend` (domyślny adres w `lib/services/api_client.dart`).

## Uruchomienie i testy

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Jeśli korzystasz z własnej instancji backendu, ustaw odpowiedni adres w `PksttApiClient.baseUrl` w pliku `lib/services/api_client.dart`.

## Budowanie wersji produkcyjnej (Android)

1. W pliku `pubspec.yaml` zaktualizuj pole `version` (np. `1.0.1+2`).
2. Do publikacji lub stałych aktualizacji skonfiguruj własny klucz podpisujący (domyślnie `release` w `android/app/build.gradle.kts` używa tymczasowo klucza `debug`):
   - utwórz keystore (`keytool -genkey -v ...`),
   - zapisz dane dostępowe w `android/key.properties` (ignorowanym przez `android/.gitignore`),
   - skonfiguruj `signingConfigs` w `android/app/build.gradle.kts`.
3. Zbuduj paczkę:
   ```bash
   # Plik APK do instalacji bezpośredniej:
   flutter build apk --release

   # Lub paczka AAB do Google Play:
   flutter build appbundle --release
   ```

## Dane zewnętrzne i licencje

- Rozkłady jazdy i dane GTFS-RT pochodzą z API [pkstt-backend](https://github.com/maciejdbrznsk/pkstt-backend) opartego na otwartych danych ZTM i PKS Rzeszów (`kmrzeszow.live/otwartedane`).
- Mapy i kafelki: © autorzy [OpenStreetMap](https://www.openstreetmap.org/copyright).
