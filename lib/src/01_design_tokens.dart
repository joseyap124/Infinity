part of '../main.dart';

// =============================================================================
// DESIGN TOKENS
// =============================================================================

/// Diisi saat build: --dart-define=APP_VERSION=1.x (lihat workflow).
const String kAppVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

class C {
  /// Diatur oleh InfinityApp sesuai pilihan tema (Terang/Gelap/Ikut sistem).
  static bool isDark = false;

  /// Indeks warna aksen pilihan user (lihat [accents]).
  static int accentIndex = 0;

  /// (nama, aksen terang, aksen tua mode terang, aksen mode gelap).
  /// Aksen tua dipakai untuk tombol bertulisan putih dan teks berwarna.
  static const List<(String, Color, Color, Color)> accents = [
    ('Hijau', Color(0xFF00AA13), Color(0xFF007A0E), Color(0xFF1E9E33)),
    ('Tosca', Color(0xFF14B8A6), Color(0xFF0F766E), Color(0xFF139C8C)),
    ('Biru', Color(0xFF3B82F6), Color(0xFF1D4ED8), Color(0xFF4589F3)),
    ('Indigo', Color(0xFF6366F1), Color(0xFF4338CA), Color(0xFF7878F2)),
    ('Ungu', Color(0xFFA855F7), Color(0xFF7E22CE), Color(0xFFA066F2)),
    ('Oranye', Color(0xFFF97316), Color(0xFFC2410C), Color(0xFFE2661A)),
    ('Pink', Color(0xFFEC4899), Color(0xFFBE185D), Color(0xFFE5568F)),
    ('Grafit', Color(0xFF475569), Color(0xFF334155), Color(0xFF7C8BA1)),
    // Pastel: warna lembut untuk sorotan, versi tuanya dipakai untuk tombol
    // dan teks supaya tulisan putih tetap terbaca.
    ('Sage', Color(0xFFA8D5BA), Color(0xFF4F7F62), Color(0xFF5F9878)),
    ('Lavender', Color(0xFFC9B8F0), Color(0xFF6E5BA8), Color(0xFF9583D1)),
    ('Rose', Color(0xFFF4B6C8), Color(0xFFA9506F), Color(0xFFD07595)),
    ('Peach', Color(0xFFFFCBA4), Color(0xFFA65A2A), Color(0xFFC77A4B)),
    ('Langit', Color(0xFFA9D6F5), Color(0xFF3C6F97), Color(0xFF5B93BF)),
    ('Mint', Color(0xFFA8E6D9), Color(0xFF3B7F72), Color(0xFF4F9E8E)),
  ];

  static (String, Color, Color, Color) get _acc =>
      accents[accentIndex.clamp(0, accents.length - 1)];

  /// Warna merek (header, tombol, navigasi). Bisa diganti di Tampilan.
  static Color get accent => _acc.$2;
  static Color get accentDark => isDark ? _acc.$4 : _acc.$3;

  // Warna arti (tetap, tidak ikut aksen): pemasukan hijau, pengeluaran merah.
  static const Color green = Color(0xFF00AA13);
  static const Color red = Color(0xFFEE2737);
  static const Color blue = Color(0xFF00AED6);
  static const Color amber = Color(0xFFFFA000);
  static const Color warning = Color(0xFFF59E0B);

  // Di mode gelap dibuat lebih terang supaya kontras teks >= 4.5:1 di atas
  // kartu gelap dan teks putih di atasnya >= 3:1.
  static Color get income =>
      isDark ? const Color(0xFF1E9E33) : const Color(0xFF007A0E);
  static Color get greenDark => income;
  static Color get redDark =>
      isDark ? const Color(0xFFEC5258) : const Color(0xFFD61F2E);
  static Color get blueDark =>
      isDark ? const Color(0xFF1497B5) : const Color(0xFF007A94);
  static Color get amberDark =>
      isDark ? const Color(0xFFD08A1E) : const Color(0xFFA35A00);

  // Netral.
  static Color get carbon =>
      isDark ? const Color(0xFFECEDEF) : const Color(0xFF1C1C1C);
  static Color get bg =>
      isDark ? const Color(0xFF121316) : const Color(0xFFF8F9FA);
  static Color get surface =>
      isDark ? const Color(0xFF1E2024) : const Color(0xFFFFFFFF);
  static Color get muted =>
      isDark ? const Color(0xFFA3A9B4) : const Color(0xFF5B6270);
  static Color get line =>
      isDark ? const Color(0xFF2E3137) : const Color(0xFFE9ECEF);

  /// Latar gelap untuk teks putih (snackbar, tombol "=", segmen terpilih).
  static Color get toast =>
      isDark ? const Color(0xFF3A3D44) : const Color(0xFF1C1C1C);
}

const List<int> kPalette = [
  0xFF00AED6,
  0xFF00AA13,
  0xFFFFA000,
  0xFFFB8C00,
  0xFFE91E63,
  0xFFEF5350,
  0xFF7C4DFF,
  0xFF5C6BC0,
  0xFF00897B,
  0xFF8D6E63,
  0xFF546E7A,
  0xFF1C1C1C,
];

const Map<String, IconData> kIcons = {
  'food': Icons.fastfood_rounded,
  'coffee': Icons.local_cafe_rounded,
  'bike': Icons.directions_bike_rounded,
  'car': Icons.directions_car_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'bag': Icons.shopping_bag_rounded,
  'movie': Icons.movie_rounded,
  'bill': Icons.receipt_long_rounded,
  'health': Icons.local_hospital_rounded,
  'school': Icons.school_rounded,
  'gift': Icons.card_giftcard_rounded,
  'salary': Icons.account_balance_wallet_rounded,
  'invest': Icons.trending_up_rounded,
  'home': Icons.home_rounded,
  'phone': Icons.smartphone_rounded,
  'pet': Icons.pets_rounded,
  'travel': Icons.flight_rounded,
  'other': Icons.category_rounded,
};

IconData iconOf(String key) => kIcons[key] ?? Icons.category_rounded;

/// Warna ikon/teks dari warna kategori: lebih gelap di mode terang, lebih
/// terang di mode gelap, supaya tetap terbaca di kedua latar.
Color darken(Color c, [double amount = 0.12]) {
  final h = HSLColor.fromColor(c);
  final l = C.isDark
      ? (h.lightness + amount * 1.6).clamp(0.55, 0.85)
      : (h.lightness - amount).clamp(0.0, 1.0);
  return h.withLightness(l.toDouble()).toColor();
}
