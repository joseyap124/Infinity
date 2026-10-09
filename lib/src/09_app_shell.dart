part of '../main.dart';

// =============================================================================
// APP SHELL
// =============================================================================

/// Pilihan tampilan dari setelan, format "mode:aksen", mis. "system:0".
final ValueNotifier<String> themePref = ValueNotifier<String>('system:0');

String themeKey(AppSettings s) => '${s.themeMode}:${s.accentIndex}';

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
  }

  @override
  void dispose() {
    themePref.removeListener(_apply);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _apply();

  bool _wantDark() {
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
    if ((dark == C.isDark && acc == C.accentIndex) || !mounted) return;
    C.isDark = dark;
    C.accentIndex = acc;
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
    await Receipts.init();
    Receipts.cleanup(store.transactions);
    await Notifier.instance.init();
    if (store.settings.notifEnabled) {
      unawaited(Notifier.instance.requestPermission());
    }
    themePref.value = themeKey(store.settings);
    store.addListener(_syncTheme);
    store.addListener(_scheduleNotifications);
    _scheduleNotifications();
    unawaited(NativeBridge.setSecure(store.settings.secureScreen));
    await _ingestCaptures(quiet: true);
    unawaited(store.backupToDownloads());
    // Saat app terbuka, cek notifikasi bank/e-wallet baru setiap 20 detik.
    _capturePoll = Timer.periodic(
        const Duration(seconds: 20), (_) => _ingestCaptures());
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

  void _syncTheme() => themePref.value = themeKey(store.settings);

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
              'Tercatat: ${t.title} ${money(t.amount)} dari ${store.accountName(t.accountId)}');
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
    final raw = await NativeBridge.fetchCaptured();
    if (raw.isEmpty || !mounted) return;
    final before = store.pendingCaptures.length;
    final auto = store.ingestCaptured(raw);
    final waiting = store.pendingCaptures.length - before;
    // Antrean native baru dikosongkan setelah hasilnya benar-benar tertulis.
    if (await store.flush()) {
      await NativeBridge.ackCaptured([
        for (final r in raw)
          if (r['qid'] is String) r['qid'] as String
      ]);
    }
    if (!mounted || quiet && auto == 0 && waiting <= 0) return;
    if (auto > 0) {
      snack(context, '$auto transaksi tercatat otomatis dari notifikasi 🤖');
    } else if (waiting > 0) {
      snack(context,
          '$waiting transaksi dari notifikasi menunggu dicek di Beranda');
    }
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
    _widgetSub?.cancel();
    _quickSub?.cancel();
    store.removeListener(_syncTheme);
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
        snack(context, '$created transaksi berulang otomatis tercatat');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        // Data belum terbaca: layar polos senada splash bawaan Android.
        if (!store.loaded) {
          return const ColoredBox(color: Color(0xFF16181D));
        }
        // Animasi koin hanya saat app pertama kali dibuka.
        if (!store.settings.splashSeen && !_splashDone) {
          return AnimatedSplash(onDone: () {
            setState(() => _splashDone = true);
            store.updateSettings((s) => s.splashSeen = true);
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
          DashboardTab(store: store, onSeeAll: () => setState(() => _tab = 1)),
          HistoryTab(store: store),
          StatsTab(store: store),
          MoreTab(store: store),
        ];
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (_tab == 0
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
            floatingActionButton: _tab <= 1
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
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Beranda'),
                NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded),
                    label: 'Riwayat'),
                NavigationDestination(
                    icon: Icon(Icons.pie_chart_outline),
                    selectedIcon: Icon(Icons.pie_chart_rounded),
                    label: 'Statistik'),
                NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: 'Lainnya'),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Splash animasi: koin jatuh masuk ke celengan, celengan memantul, lalu
/// tulisan Infinity muncul. Gambarnya sama dengan ikon app (lihat
/// tool/make_icons.py) supaya menyambung dari splash bawaan Android.
class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _c.value = 1; // hormati setelan "kurangi animasi"
        widget.onDone();
      } else {
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16181D),
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final textIn = Curves.easeOut
                .transform(((t - 0.68) / 0.25).clamp(0.0, 1.0));
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CustomPaint(painter: _PiggyPainter(t)),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: textIn,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - textIn)),
                    child: const Text('Infinity',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PiggyPainter extends CustomPainter {
  _PiggyPainter(this.t);
  final double t;

  static const pink = Color(0xFFFF8FB1);
  static const pinkD = Color(0xFFE25E8A);
  static const dark = Color(0xFF281E28);
  static const gold = Color(0xFFFFC83D);
  static const goldD = Color(0xFFD69614);

  double _seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    // Kanvas ikon 108x108, ditampilkan area 18..90 seperti ikon PNG.
    final k = size.width / 72;
    canvas.save();
    canvas.scale(k);
    canvas.translate(-18, -18);

    final appear = Curves.easeOutBack.transform(_seg(0.0, 0.18));
    final fall = Curves.easeIn.transform(_seg(0.16, 0.56));
    final bounce = _seg(0.56, 0.74);
    final squash = 1 - 0.07 * math.sin(bounce * math.pi);
    final p = Paint()..isAntiAlias = true;

    // Koin: jatuh dari atas ke celah, makin pipih (masuk ke celah), terpotong
    // di garis celah supaya terlihat masuk.
    if (t < 0.6) {
      final cy = -14 + (45.4 - -14) * fall;
      final flat = 1 - 0.75 * Curves.easeIn.transform(_seg(0.42, 0.56));
      canvas.save();
      canvas.clipRect(const Rect.fromLTRB(0, -40, 108, 45.4));
      canvas.translate(54, cy);
      canvas.scale(flat, 1);
      canvas.drawCircle(Offset.zero, 6.5, p..color = gold);
      canvas.drawCircle(Offset.zero, 6.5 * 0.62, p..color = goldD);
      canvas.drawCircle(Offset.zero, 6.5 * 0.45, p..color = gold);
      canvas.restore();
    }

    // Celengan (muncul membesar, lalu memantul saat koin masuk).
    canvas.save();
    canvas.translate(54, 81);
    canvas.scale(appear, appear * squash);
    canvas.translate(-54, -81);

    final tail = Paint()
      ..isAntiAlias = true
      ..color = pinkD
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        const Rect.fromLTRB(27.5, 50, 33.5, 57.5), math.pi / 2, math.pi * 1.5, false, tail);
    p.color = pinkD;
    for (final l in const [
      Rect.fromLTRB(40, 70, 47, 81),
      Rect.fromLTRB(59, 70, 66, 81),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(l, const Radius.circular(2.5)), p);
    }
    canvas.drawPath(
        Path()
          ..moveTo(61, 48)
          ..lineTo(64.5, 38.5)
          ..lineTo(71, 48.5)
          ..close(),
        p);
    canvas.drawOval(Rect.fromCenter(center: const Offset(54, 60), width: 44, height: 32),
        p..color = pink);
    canvas.drawOval(Rect.fromCenter(center: const Offset(77, 60), width: 12, height: 14),
        p..color = pinkD);
    p.color = dark;
    canvas.drawCircle(const Offset(75.6, 58.2), 1.1, p);
    canvas.drawCircle(const Offset(75.6, 61.8), 1.1, p);
    // Mata berkedip sesaat setelah koin masuk.
    final blink = bounce > 0.3 && bounce < 0.7 ? 0.25 : 1.0;
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(67, 54), width: 4.4, height: 4.4 * blink), p);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTRB(47, 44.2, 61, 46.6), const Radius.circular(1.2)),
        p);
    canvas.restore();

    // Kilau kecil di atas celah saat koin masuk.
    if (bounce > 0 && bounce < 1) {
      final a = math.sin(bounce * math.pi);
      final sp = Paint()
        ..isAntiAlias = true
        ..color = gold.withValues(alpha: a)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 5; i++) {
        final ang = -math.pi / 2 + (i - 2) * 0.5;
        final r1 = 5 + 3 * bounce, r2 = 9 + 5 * bounce;
        canvas.drawLine(
            Offset(54 + r1 * math.cos(ang), 42 + r1 * math.sin(ang)),
            Offset(54 + r2 * math.cos(ang), 42 + r2 * math.sin(ang)),
            sp);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PiggyPainter old) => old.t != t;
}
