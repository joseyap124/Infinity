part of '../main.dart';

// =============================================================================
// APP SHELL
// =============================================================================

/// Pilihan tampilan dari setelan, format "mode:aksen", mis. "system:0".
final ValueNotifier<String> themePref = ValueNotifier<String>('system:0');

/// Ukuran huruf pilihan di app (Lainnya → Pengaturan → Tampilan).
final ValueNotifier<double> appTextScale = ValueNotifier<double>(1.0);

/// Batas ukuran huruf efektif (HP x app). Di atas ini tata letak mulai
/// berdesakan, jadi dibatasi.
const double kMaxTextScale = 1.4;

/// Ukuran huruf HP dikali pilihan di app.
class _MulTextScaler extends TextScaler {
  const _MulTextScaler(this.base, this.factor);
  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is _MulTextScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}

String themeKey(AppSettings s) =>
    '${s.themeMode}:${s.accentIndex}:${s.stylePack}';

class InfinityApp extends StatefulWidget {
  const InfinityApp({super.key});

  @override
  State<InfinityApp> createState() => _InfinityAppState();
}

class _InfinityAppState extends State<InfinityApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    themePref.addListener(_apply);
    C.isDark = _wantDark();
    C.accentIndex = _wantAccent();
    C.pack = _wantPack();
  }

  @override
  void dispose() {
    themePref.removeListener(_apply);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _apply();

  String _wantPack() {
    final parts = themePref.value.split(':');
    final p = parts.length > 2 ? parts[2] : 'classic';
    return kStylePacks.containsKey(p) ? p : 'classic';
  }

  bool _wantDark() {
    final fixed = kStylePacks[_wantPack()];
    if (fixed != null) return fixed.dark;
    final sys = WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    final mode = themePref.value.split(':').first;
    return mode == 'dark' || (mode == 'system' && sys);
  }

  int _wantAccent() {
    final parts = themePref.value.split(':');
    return parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  }

  /// Warna C.* dibaca langsung oleh banyak widget, jadi saat tema berganti
  /// semua elemen dibangun ulang.
  void _apply() {
    final dark = _wantDark();
    final acc = _wantAccent();
    final pack = _wantPack();
    if ((dark == C.isDark && acc == C.accentIndex && pack == C.pack) ||
        !mounted) {
      return;
    }
    C.isDark = dark;
    C.accentIndex = acc;
    C.pack = pack;
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    setState(() {});
  }

  ThemeData _theme() {
    final dark = C.isDark;
    final scheme = ColorScheme.fromSeed(
      seedColor: C.accent,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: C.accentDark,
      onPrimary: Colors.white,
      error: C.redDark,
      surface: C.surface,
      onSurface: C.carbon,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: C.bg,
      canvasColor: C.surface,
      dividerColor: C.line,
      dialogTheme: DialogThemeData(backgroundColor: C.surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: C.surface),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: C.toast,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: const Color(0xFF7CFC8A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Infinity',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      builder: (context, child) => ValueListenableBuilder<double>(
        valueListenable: appTextScale,
        builder: (context, f, _) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: _MulTextScaler(mq.textScaler, f)
                  .clamp(minScaleFactor: 0.85, maxScaleFactor: kMaxTextScale),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              C.isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: C.isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: C.surface,
          systemNavigationBarIconBrightness:
              C.isDark ? Brightness.light : Brightness.dark,
        ),
        child: const RootPage(),
      ),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> with WidgetsBindingObserver {
  final AppStore store = AppStore();
  int _tab = 0;
  bool _locked = false;
  bool _splashDone = false;
  DateTime? _pausedAt;
  Timer? _notifDebounce;
  Timer? _capturePoll;
  Timer? _syncPoll;
  DateTime? _lastSaveWarn;
  StreamSubscription<Uri?>? _widgetSub;
  TxType? _pendingWidgetAction;
  QuickAction? _pendingQuick;
  StreamSubscription<QuickAction>? _quickSub;
  bool? _quickShown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await store.load();
    if (store.dataLocked) return;
    await _afterLoad();
  }

  Future<void> _retryLoad() async {
    await store.retryLoad();
    if (!store.dataLocked && mounted) await _afterLoad();
  }

  Future<void> _freshStart() async {
    await store.startFresh();
    if (!store.dataLocked && mounted) await _afterLoad();
  }

  Future<void> _afterLoad() async {
    await Receipts.init();
    Receipts.cleanup(store.transactions);
    await Notifier.instance.init();
    if (store.settings.notifEnabled) {
      unawaited(Notifier.instance.requestPermission());
    }
    themePref.value = themeKey(store.settings);
    appTextScale.value = store.settings.textScale;
    gIconStyle.value = store.settings.iconStyle;
    gMascotSkin.value = effectiveMascotSkin(store.settings);
    gMascotCustom.value = store.settings.mascotCustomPath;
    gLang.value = langOf(store.settings.lang);
    store.onSaveFailed = () {
      final now = DateTime.now();
      final last = _lastSaveWarn;
      if (!mounted || (last != null && now.difference(last).inSeconds < 30)) {
        return;
      }
      _lastSaveWarn = now;
      snack(context,
          'Perubahan terakhir GAGAL disimpan. Buka Lainnya, Laporan error, lalu kirim Jejak penyimpanan.');
    };
    store.addListener(_syncTheme);
    store.addListener(_scheduleNotifications);
    store.addListener(_syncCaptureConfig);
    _syncCaptureConfig();
    _scheduleNotifications();
    unawaited(NativeBridge.setSecure(store.settings.secureScreen));
    await _ingestCaptures(quiet: true);
    unawaited(store.backupToDownloads());
    // Saat app terbuka, cek notifikasi bank/e-wallet baru setiap 20 detik.
    _capturePoll = Timer.periodic(
        const Duration(seconds: 20), (_) => _ingestCaptures());
    // Kalau ada salinan Infinity lain yang menulis, ambil perubahannya cepat.
    _syncPoll = Timer.periodic(const Duration(seconds: 5),
        (_) => unawaited(store.syncIfChangedElsewhere()));
    _widgetSub = HomeWidgetBridge.clicks().listen(_handleWidgetUri);
    final launch = await HomeWidgetBridge.initialLaunch();
    if (!mounted) return;
    setState(() => _locked = store.settings.pin != null);
    _handleWidgetUri(launch);
    _quickSub = Notifier.instance.actions.listen(_handleQuick);
    final qa = await Notifier.instance.launchAction();
    if (!mounted) return;
    _handleQuick(qa);
    final warning = store.loadWarning;
    if (warning != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) snack(context, warning);
      });
    }
  }

  /// Setiap data berubah (dengan jeda kecil): jadwal notifikasi, widget, dan
  /// mode layar aman diperbarui.
  void _scheduleNotifications() {
    _notifDebounce?.cancel();
    _notifDebounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(
          Notifier.instance.replaceSchedule(store.plannedNotifications()));
      unawaited(HomeWidgetBridge.update(store.widgetData()));
      unawaited(NativeBridge.setSecure(store.settings.secureScreen));
      _syncQuickBar();
    });
  }

  void _syncTheme() {
    themePref.value = themeKey(store.settings);
    appTextScale.value = store.settings.textScale;
    gIconStyle.value = store.settings.iconStyle;
    gMascotSkin.value = effectiveMascotSkin(store.settings);
    gMascotCustom.value = store.settings.mascotCustomPath;
    final lang = langOf(store.settings.lang);
    if (gLang.value != lang) {
      gLang.value = lang;
      // Semua teks dibaca ulang dengan bahasa baru, tanpa menutup halaman yang terbuka.
      WidgetsBinding.instance.addPostFrameCallback((_) => rebuildAllApp());
    }
  }

  /// Pintasan tidak bergantung pada saklar pengingat: cukup setelannya aktif
  /// dan izin notifikasi Android diberikan.
  void _syncQuickBar() {
    final want = store.settings.quickBar;
    if (_quickShown == want) return;
    _quickShown = want;
    if (want) {
      unawaited(() async {
        await Notifier.instance.requestPermission();
        await NativeBridge.showQuickBar();
      }());
    } else {
      unawaited(NativeBridge.hideQuickBar());
    }
  }


  /// Tombol pintasan di panel notifikasi.
  void _handleQuick(QuickAction? action) {
    if (action == null) return;
    if (_locked && store.settings.pin != null) {
      _pendingQuick = action;
      return;
    }
    _runQuick(action);
  }

  void _runQuick(QuickAction action) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    switch (action.id) {
      case 'qb_quick':
        // Tampilkan ulang supaya kolom balasan di notifikasi bersih lagi.
        unawaited(NativeBridge.showQuickBar());
        final text = action.input?.trim() ?? '';
        final t = text.isEmpty ? null : store.quickExpense(text);
        if (t == null) {
          snack(context, 'Nominal tidak terbaca. Contoh: 25rb kopi');
          _openFromWidget(TxType.expense);
        } else {
          setState(() => _tab = 0);
          snack(context,
              tr('Tercatat: {0} {1} dari {2}', [t.title, money(t.amount), store.accountName(t.accountId)]));
        }
      case 'qb_add':
        _openFromWidget(TxType.expense);
      case 'qb_history':
        setState(() => _tab = 1);
      case 'qb_search':
        setState(() => _tab = 1);
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => historySearchRequest.value++);
      case 'qb_template':
        setState(() => _tab = 0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TemplatesPage(store: store)));
        });
    }
  }

  Future<void> _ingestCaptures({bool quiet = false}) async {
    if (!store.loaded || store.settings.captureMode == 'off') return;
    // Pilihan tombol di notifikasi dan notifikasi baru; antrean native
    // dikosongkan setelah hasilnya benar-benar tertulis.
    final r = await store.syncNativeCaptures();
    if (r.fetched == 0 || !mounted) return;
    if (quiet && r.auto == 0 && r.waiting <= 0 && r.buttons == 0) return;
    if (r.buttons > 0) {
      snack(context, tr('{0} transaksi dicatat dari tombol notifikasi ✅', [r.buttons]));
    } else if (r.auto > 0) {
      snack(context, tr('{0} transaksi tercatat otomatis dari notifikasi 🤖', [r.auto]));
    } else if (r.waiting > 0) {
      snack(context,
          tr('{0} transaksi dari notifikasi menunggu dicek di Beranda', [r.waiting]));
    }
  }

  String? _lastCaptureConfig;

  /// Kirim pengaturan notifikasi bertombol ke native kalau berubah
  /// (mode, saklar, atau bahasa).
  void _syncCaptureConfig() {
    if (!store.loaded) return;
    final json = store.captureConfigJson();
    if (json == _lastCaptureConfig) return;
    _lastCaptureConfig = json;
    unawaited(NativeBridge.setCaptureConfig(json));
  }

  /// Tombol widget: infinity://add?type=expense|income|transfer
  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    // Ikon notifikasi pintasan: infinity://history | search | template
    final quick = switch (uri.host) {
      'history' => 'qb_history',
      'search' => 'qb_search',
      'template' => 'qb_template',
      _ => null,
    };
    if (quick != null) {
      _handleQuick(QuickAction(quick));
      return;
    }
    if (uri.host != 'add') return;
    final type = switch (uri.queryParameters['type']) {
      'income' => TxType.income,
      'transfer' => TxType.transfer,
      _ => TxType.expense,
    };
    if (_locked && store.settings.pin != null) {
      _pendingWidgetAction = type;
      return;
    }
    _openFromWidget(type);
  }

  void _openFromWidget(TxType type) {
    setState(() => _tab = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) openTxForm(context, store, type: type);
    });
  }

  void _unlock() {
    setState(() => _locked = false);
    final pending = _pendingWidgetAction;
    _pendingWidgetAction = null;
    if (pending != null) _openFromWidget(pending);
    final quick = _pendingQuick;
    _pendingQuick = null;
    if (quick != null) _runQuick(quick);
  }

  @override
  void dispose() {
    _notifDebounce?.cancel();
    _capturePoll?.cancel();
    _syncPoll?.cancel();
    _widgetSub?.cancel();
    _quickSub?.cancel();
    store.removeListener(_syncTheme);
    store.removeListener(_syncCaptureConfig);
    store.removeListener(_scheduleNotifications);
    WidgetsBinding.instance.removeObserver(this);
    store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
      unawaited(store.flush());
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (!store.loaded) return;
      unawaited(store.syncIfChangedElsewhere());
      final created = store.processRecurring();
      _quickShown = null; // tampilkan ulang kalau sempat digeser hilang
      _scheduleNotifications();
      unawaited(_ingestCaptures());
      unawaited(store.backupToDownloads());
      if (store.settings.pin != null &&
          pausedAt != null &&
          DateTime.now().difference(pausedAt).inSeconds >= 30) {
        setState(() => _locked = true);
      }
      if (created > 0 && mounted) {
        snack(context, tr('{0} transaksi berulang otomatis tercatat', [created]));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        // Data ada tapi gagal dibuka: jangan mulai kosong diam-diam.
        if (store.dataLocked) {
          return DataLockedScreen(onRetry: _retryLoad, onFresh: _freshStart);
        }
        // Data belum terbaca: layar polos krem, senada splash bawaan Android.
        if (!store.loaded) {
          return const ColoredBox(color: kSplashCream);
        }
        // Animasi pembuka sesuai pilihan: sekali saja (bawaan), tiap buka, atau mati.
        final sm = store.settings.splashMode;
        final showSplash = !_splashDone &&
            (sm == 'always' || (sm == 'once' && !store.settings.splashSeen));
        if (showSplash) {
          return AnimatedSplash(
              quick: sm == 'always',
              look: splashLook(C.pack, dark: C.isDark),
              onDone: () {
                setState(() => _splashDone = true);
                if (!store.settings.splashSeen) {
                  store.updateSettings((s) => s.splashSeen = true);
                }
              });
        }
        // Panduan singkat untuk install baru.
        if (!store.settings.onboarded) {
          return OnboardingPage(
              store: store,
              onDone: () => store.updateSettings((s) => s.onboarded = true));
        }
        final pin = store.settings.pin;
        if (_locked && pin != null) {
          return PinLockScreen(
            pin: pin,
            biometric: store.settings.biometric,
            onUnlocked: _unlock,
          );
        }
        final pages = <Widget>[
          DashboardTab(
              store: store,
              onSeeAll: () => setState(() => _tab = 1),
              onOpenPlan: () => setState(() => _tab = 2)),
          HistoryTab(store: store),
          PlanTab(store: store),
          StatsTab(store: store),
          MoreTab(store: store),
        ];
        return AnnotatedRegion<SystemUiOverlayStyle>(
          // Beranda tidak lagi punya pita warna, jadi ikon status bar sama
          // dengan tab lain (gelap di tema terang, terang di tema gelap).
          value: (C.isDark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(statusBarColor: Colors.transparent),
          child: Scaffold(
            backgroundColor: C.bg,
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: IndexedStack(index: _tab, children: pages),
              ),
            ),
            floatingActionButton: _tab <= 2
                ? FloatingActionButton.extended(
                    onPressed: () => openTxForm(context, store),
                    backgroundColor: C.accentDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Catat',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  )
                : null,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              backgroundColor: C.surface,
              indicatorColor: C.accent.withValues(alpha: 0.18),
              destinations: [
                NavigationDestination(
                    icon: navIcon('home', Icons.home_outlined, Icons.home_rounded, false),
                    selectedIcon: navIcon('home', Icons.home_outlined, Icons.home_rounded, true),
                    label: tr('Beranda')),
                NavigationDestination(
                    icon: navIcon('receipt', Icons.receipt_long_outlined, Icons.receipt_long_rounded, false),
                    selectedIcon: navIcon('receipt', Icons.receipt_long_outlined, Icons.receipt_long_rounded, true),
                    label: tr('Riwayat')),
                NavigationDestination(
                    icon: navIcon('target', Icons.track_changes_outlined, Icons.track_changes_rounded, false),
                    selectedIcon: navIcon('target', Icons.track_changes_outlined, Icons.track_changes_rounded, true),
                    label: tr('Rencana')),
                NavigationDestination(
                    icon: navIcon('pie', Icons.pie_chart_outline, Icons.pie_chart_rounded, false),
                    selectedIcon: navIcon('pie', Icons.pie_chart_outline, Icons.pie_chart_rounded, true),
                    label: tr('Statistik')),
                NavigationDestination(
                    icon: navIcon('grid', Icons.grid_view_outlined, Icons.grid_view_rounded, false),
                    selectedIcon: navIcon('grid', Icons.grid_view_outlined, Icons.grid_view_rounded, true),
                    label: tr('Lainnya')),
              ],
            ),
          ),
        );
      },
    );
  }
}
