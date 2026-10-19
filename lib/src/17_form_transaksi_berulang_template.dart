part of '../main.dart';

// =============================================================================
// FORM TRANSAKSI / BERULANG / TEMPLATE (Bottom Sheet)
// =============================================================================

class TxFormSheet extends StatefulWidget {
  const TxFormSheet({
    super.key,
    required this.store,
    required this.draft,
    required this.mode,
    this.excludeTxId,
    this.isEditing = false,
    this.frequency,
    this.onContinue,
  });

  /// Dipanggil untuk menyimpan transaksi tanpa menutup form (Simpan & lanjut).
  final Future<void> Function(FormResult r)? onContinue;

  final AppStore store;
  final TxDraft draft;
  final FormMode mode;
  final String? excludeTxId;
  final bool isEditing;
  final Frequency? frequency;

  @override
  State<TxFormSheet> createState() => _TxFormSheetState();
}

class _TxFormSheetState extends State<TxFormSheet> {
  AppStore get store => widget.store;

  late TxType _type;
  String? _categoryId;
  late String _fromId;
  late String _toId;
  late DateTime _date;
  late Frequency _frequency;
  bool _saveTemplate = false;
  bool _toTouched = false;

  /// Acara/tag transaksi (null = tanpa acara).
  String? _eventId;
  String? _error;
  String? _info;

  final _amountCtrl = TextEditingController();
  final _toAmountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  bool _catAuto = false; // kategori terisi otomatis dari riwayat catatan
  bool _catManual = false; // kategori dipilih sendiri di form ini

  /// true kalau user sudah memilih kategori sendiri (jangan ditimpa tebakan).
  late bool _catTouched;

  /// Bagian tambahan saat transaksi dibagi ke beberapa kategori. Bagian
  /// kategori utama ([_categoryId]) = total dikurangi semua bagian ini.
  final List<(String, TextEditingController)> _splits = [];
  bool get _splitting => _splits.isNotEmpty;

  double _splitAmount(TextEditingController c) =>
      parseAmount(c.text, decimals: hasDecimals(_fromCur));

  double get _mainShare =>
      _amount - _splits.fold(0.0, (s, e) => s + _splitAmount(e.$2));

  bool get _canSplit =>
      widget.mode == FormMode.transaction && _type != TxType.transfer;
  late List<String> _photos;
  final _noteFocus = FocusNode();

  String get _fromCur => store.currencyOf(_fromId);
  String get _toCur => store.currencyOf(_toId);
  bool get _crossCurrency => _type == TxType.transfer && _fromCur != _toCur;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _type = d.type;
    _fromId = store.accountById(d.accountId) != null
        ? d.accountId
        : store.accounts.first.id;
    final to = d.toAccountId;
    _toId = (to != null && store.accountById(to) != null && to != _fromId)
        ? to
        : _otherAccount(_fromId);
    _categoryId = (d.categoryId != null && store.categoryById(d.categoryId) != null)
        ? d.categoryId
        : _defaultCategory(_type);
    _date = d.date;
    _photos = [...d.photos];
    _frequency = widget.frequency ?? Frequency.monthly;
    if (d.amount > 0) _amountCtrl.text = amountToInput(d.amount, _fromCur);
    final ta = d.toAmount;
    if (ta != null && _crossCurrency) {
      _toAmountCtrl.text = amountToInput(ta, _toCur);
      _toTouched = true;
    } else {
      _syncToAmount();
    }
    _titleCtrl.text = d.title;
    _noteCtrl.text = d.note;
    _catTouched = widget.isEditing;
    _titleFocus.addListener(_onTitleFocus);
    if (d.splits.length > 1 && d.type != TxType.transfer) {
      // Bagian pertama = kategori utama (dihitung otomatis).
      _categoryId = store.categoryById(d.splits.first.categoryId) != null
          ? d.splits.first.categoryId
          : _categoryId;
      for (final s in d.splits.skip(1)) {
        _splits.add((
          s.categoryId,
          TextEditingController(text: amountToInput(s.amount, _fromCur))
        ));
      }
    }
    _eventId = store.eventById(d.eventId)?.id ??
        ((widget.mode == FormMode.transaction && !widget.isEditing)
            ? store.autoEventFor(d.date)?.id
            : null);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _toAmountCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _titleFocus.dispose();
    _noteFocus.dispose();
    for (final s in _splits) {
      s.$2.dispose();
    }
    super.dispose();
  }

  String _otherAccount(String id) => store.accounts
      .firstWhere((a) => a.id != id, orElse: () => store.accounts.first)
      .id;

  String? _defaultCategory(TxType t) {
    if (t == TxType.transfer) return null;
    final often = store.suggestedCategory(t);
    if (often != null) return often;
    // Belum ada riwayat: kotak pertama "Sering dipakai" (kategori tanpa
    // sub-kategori), bukan kategori induk.
    final first = store.frequentCategories(t, limit: 1);
    if (first.isNotEmpty) return first.first;
    final tops = store.topCategories(t);
    return tops.isEmpty ? null : tops.first.id;
  }

  double get _amount =>
      parseAmount(_amountCtrl.text, decimals: hasDecimals(_fromCur));

  void _syncToAmount() {
    if (!_crossCurrency || _toTouched) return;
    final a = _amount;
    if (a <= 0) {
      _toAmountCtrl.text = '';
      return;
    }
    final converted = a * store.rate(_fromCur) / store.rate(_toCur);
    _toAmountCtrl.text = amountToInput(converted, _toCur);
  }

  void _changeType(TxType t) {
    if (t == _type) return;
    setState(() {
      _type = t;
      _categoryId = _defaultCategory(t);
      _clearSplits();
      _error = null;
      if (t == TxType.transfer && _toId == _fromId) {
        _toId = _otherAccount(_fromId);
      }
      _toTouched = false;
      _syncToAmount();
    });
  }

  void _selectFrom(String id) {
    final oldCur = _fromCur;
    final value = parseAmount(_amountCtrl.text, decimals: hasDecimals(oldCur));
    setState(() {
      _fromId = id;
      _error = null;
      if (_type == TxType.transfer && _toId == id) _toId = _otherAccount(id);
      if (oldCur != _fromCur) {
        _amountCtrl.text = value > 0 ? amountToInput(value, _fromCur) : '';
      }
      _toTouched = false;
      _syncToAmount();
    });
  }

  void _selectTo(String id) {
    setState(() {
      _toId = id;
      _error = null;
      _toTouched = false;
      _syncToAmount();
    });
  }

  void _applyTemplate(TxTemplate t) {
    setState(() {
      _type = t.type;
      _fromId = store.accountById(t.accountId) != null
          ? t.accountId
          : store.accounts.first.id;
      final to = t.toAccountId;
      _toId = (to != null && store.accountById(to) != null && to != _fromId)
          ? to
          : _otherAccount(_fromId);
      _categoryId = store.categoryById(t.categoryId) != null
          ? t.categoryId
          : _defaultCategory(t.type);
      _amountCtrl.text = amountToInput(t.amount, _fromCur);
      _titleCtrl.text = t.title;
      _noteCtrl.text = t.note;
      _error = null;
      _toTouched = false;
      final ta = t.toAmount;
      if (ta != null && _crossCurrency) {
        _toAmountCtrl.text = amountToInput(ta, _toCur);
        _toTouched = true;
      } else {
        _syncToAmount();
      }
    });
  }

  Future<void> _addPhoto() async {
    FocusScope.of(context).unfocus();
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: C.surface,
      sheetAnimationStyle: AnimationStyle.noAnimation,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Foto pakai kamera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Pilih dari galeri'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (src == null) return;
    try {
      final name = await Receipts.add(src);
      if (name != null && mounted) {
        setState(() => _photos.add(name));
        if (_amount <= 0 && _type != TxType.transfer) await _readReceipt(name);
      }
    } catch (_) {
      if (mounted) snack(context, 'Gagal mengambil foto.');
    }
  }

  /// Isi nominal (dan catatan/kategori) dari foto struk, offline.
  Future<void> _readReceipt(String name) async {
    setState(() {
      _error = null;
      _info = 'Membaca struk…';
    });
    final text = await Receipts.readText(name);
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      setState(() => _info = null);
      return;
    }
    final p = parseReceipt(text, store);
    final amount = receiptTotal(text) ?? p.amount;
    final merchant = receiptMerchant(text);
    setState(() {
      if (amount == null) {
        _info = 'Nominal di struk tidak terbaca. Isi manual ya.';
        return;
      }
      _amountCtrl.text = amountToInput(amount, _fromCur);
      _syncToAmount();
      if (_titleCtrl.text.trim().isEmpty && merchant != null) {
        _titleCtrl.text = merchant;
      }
      final cat = p.categoryId;
      if (cat != null && _type == TxType.expense) _categoryId = cat;
      _info =
          'Terbaca dari struk: ${money(amount, _fromCur)}${merchant != null ? ' · $merchant' : ''}. Cek dulu sebelum simpan.';
    });
  }

  /// Pilih saran Catatan: kategori (dan akun) ikut diisi dari transaksi
  /// terakhir dengan catatan yang sama, seperti Money Manager.
  /// Selesai mengetik judul: isi kategori dari kebiasaan (kalau kategori
  /// belum dipilih sendiri).
  void _onTitleFocus() {
    if (_titleFocus.hasFocus) return;
    _applyLearned();
  }

  /// Isi kategori dari kebiasaan (catatan yang sama) kalau belum dipilih
  /// sendiri. Dipanggil saat kolom Catatan ditinggalkan dan sebelum simpan.
  void _applyLearned() {
    if (_catTouched || !mounted) return;
    if (_type == TxType.transfer) return;
    final cat = store.learnedCategory(_titleCtrl.text, _type);
    if (cat == null || cat == _categoryId) return;
    setState(() {
      _categoryId = cat;
      _catAuto = true;
      _info =
          'Kategori ${store.categoryById(cat)?.name ?? ''} dipilih dari kebiasaanmu. Ketuk kategori untuk mengganti.';
    });
  }

  void _pickedTitle(String title) {
    final last = store.lastWithTitle(title, _type);
    if (last == null) return;
    setState(() {
      final cat = store.learnedCategory(title, _type) ?? last.categoryId;
      if (!_catTouched && cat != null && store.categoryById(cat) != null) {
        _categoryId = cat;
        _catAuto = true;
      }
      _error = null;
    });
    if (!widget.isEditing && store.accountById(last.accountId) != null) {
      _selectFrom(last.accountId);
    }
    // Nominal ikut diisi kalau masih kosong (bisa diubah).
    if (!widget.isEditing &&
        parseAmount(_amountCtrl.text, decimals: hasDecimals(_fromCur)) <= 0 &&
        last.amount > 0 &&
        store.currencyOf(last.accountId) == _fromCur) {
      setState(() {
        _amountCtrl.text = amountToInput(last.amount, _fromCur);
        _syncToAmount();
      });
    }
  }

  /// Isi form dari teks struk/notifikasi yang disalin user.
  Future<void> _pasteReceipt() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      setState(() {
        _info = null;
        _error =
            'Clipboard kosong. Salin dulu teks struk atau notifikasi transaksinya.';
      });
      return;
    }
    final p = parseReceipt(text, store);
    final amount = p.amount;
    if (amount == null) {
      setState(() {
        _info = null;
        _error = 'Tidak ketemu nominal (Rp ...) di teks yang disalin.';
      });
      return;
    }
    setState(() {
      final type = p.type ?? TxType.expense;
      if (type != _type) {
        _type = type;
        _categoryId = _defaultCategory(type);
      }
      final acc = p.accountId;
      if (acc != null) {
        _fromId = acc;
        if (_toId == _fromId) _toId = _otherAccount(_fromId);
      }
      final cat = p.categoryId;
      if (cat != null) _categoryId = cat;
      _amountCtrl.text = amountToInput(amount, _fromCur);
      final title = p.title;
      if (title != null) _titleCtrl.text = title;
      _error = null;
      _info =
          'Terisi dari struk: ${money(amount, _fromCur)}${title != null ? ' · $title' : ''}. Cek akun dan kategori sebelum simpan.';
    });
  }

  Future<void> _openCalculator() async {
    final v = await showSheet<double>(context, CalculatorSheet(initial: _amount));
    if (v == null || !mounted) return;
    setState(() {
      _amountCtrl.text = amountToInput(v, _fromCur);
      _error = null;
      _syncToAmount();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 10);
    final last = widget.mode == FormMode.recurring
        ? DateTime(now.year + 5)
        : now;
    var initial = _date;
    if (initial.isAfter(last)) initial = last;
    if (initial.isBefore(first)) initial = first;
    final picked = await showDatePicker(
        context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (picked != null) setState(() => _date = picked);
  }

  /// Bagian kategori untuk disimpan (kategori sama digabung).
  List<TxSplit> _mergedSplits() {
    final m = <String, double>{};
    m[_categoryId!] = _mainShare;
    for (final (c, ctrl) in _splits) {
      m[c] = (m[c] ?? 0) + _splitAmount(ctrl);
    }
    if (m.length < 2) return [];
    return [for (final e in m.entries) TxSplit(e.key, e.value)];
  }

  /// Validasi lalu susun hasil form; null kalau ada isian yang salah.
  FormResult? _buildResult() {
    _applyLearned();
    final amount = _amount;
    String? err;
    double? toAmount;

    if (amount <= 0) {
      err = 'Nominal harus lebih dari 0 ya 🙏';
    } else if (_type == TxType.transfer && _fromId == _toId) {
      err = 'Akun asal dan tujuan tidak boleh sama. Tambah akun lain dulu kalau baru punya satu.';
    } else if (_type != TxType.transfer && _categoryId == null) {
      err = 'Pilih kategori dulu.';
    } else if (_splitting &&
        _splits.any((s) => _splitAmount(s.$2) <= 0)) {
      err = 'Isi nominal setiap bagian kategori, atau hapus bagian yang kosong.';
    } else if (_splitting && _mainShare <= 0) {
      err = 'Jumlah bagian melebihi total. Kurangi salah satu bagian.';
    } else if (widget.mode == FormMode.transaction && _type != TxType.income) {
      final acc = store.accountById(_fromId)!;
      final bal = store.balanceOf(_fromId, excludeTxId: widget.excludeTxId);
      if (acc.type == AccountType.credit) {
        if (acc.creditLimit > 0 && bal - amount < -acc.creditLimit - 0.001) {
          err =
              'Melebihi limit ${acc.name} (sisa limit ${money(acc.creditLimit + bal, acc.currency)}).';
        }
      } else if (amount > bal + 0.001) {
        err =
            'Saldo ${acc.name} tidak cukup (sisa ${money(bal, acc.currency)}).';
      }
    }
    if (err == null && _crossCurrency) {
      toAmount =
          parseAmount(_toAmountCtrl.text, decimals: hasDecimals(_toCur));
      if (toAmount <= 0) err = 'Isi jumlah yang diterima di akun tujuan.';
    }
    if (err != null) {
      HapticFeedback.mediumImpact();
      setState(() => _error = err);
      return null;
    }

    final now = DateTime.now();
    DateTime date;
    if (widget.mode == FormMode.recurring) {
      date = DateTime(_date.year, _date.month, _date.day, 8);
    } else if (widget.isEditing) {
      final orig = widget.draft.date;
      date = DateTime(
          _date.year, _date.month, _date.day, orig.hour, orig.minute, orig.second);
    } else {
      date = DateTime(_date.year, _date.month, _date.day, now.hour, now.minute,
          now.second);
    }

    final draft = TxDraft(
      type: _type,
      amount: amount,
      toAmount: _crossCurrency ? toAmount : null,
      categoryId: _type == TxType.transfer ? null : _categoryId,
      accountId: _fromId,
      toAccountId: _type == TxType.transfer ? _toId : null,
      date: date,
      note: _noteCtrl.text.trim(),
      photos: _photos,
      eventId: widget.mode == FormMode.transaction ? _eventId : null,
      splits: _splitting && _canSplit ? _mergedSplits() : null,
    );
    final title = _titleCtrl.text.trim();
    draft.title = title.isEmpty ? _defaultTitle(store, draft) : title;

    return FormResult(
      draft,
      frequency: widget.mode == FormMode.recurring ? _frequency : null,
      saveAsTemplate: _saveTemplate,
    );
  }

  void _submit() {
    final r = _buildResult();
    if (r != null) Navigator.of(context).pop(r);
  }

  /// Simpan & lanjut (v5.12): transaksi disimpan, form tetap terbuka dan
  /// dikosongkan. Akun, jenis, tanggal, dan acara tetap.
  Future<void> _submitContinue() async {
    final r = _buildResult();
    final cb = widget.onContinue;
    if (r == null || cb == null) return;
    await cb(r);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _amountCtrl.clear();
      _toAmountCtrl.clear();
      _titleCtrl.clear();
      _noteCtrl.clear();
      _photos = [];
      _clearSplits();
      _saveTemplate = false;
      _catTouched = false;
      _catAuto = false;
      _catManual = false;
      _openParent = null;
      _categoryId = _defaultCategory(_type);
      _toTouched = false;
      _syncToAmount();
      _error = null;
      _info = tr('{0} {1} tercatat. Catat berikutnya.',
          [tr(r.draft.type.label), money(r.draft.amount, _fromCur)]);
    });
  }

  String get _heading {
    switch (widget.mode) {
      case FormMode.transaction:
        return widget.isEditing ? 'Edit transaksi' : 'Catat ${_type.label}';
      case FormMode.recurring:
        return widget.isEditing ? 'Edit transaksi berulang' : 'Transaksi berulang';
      case FormMode.template:
        return widget.isEditing ? 'Edit template' : 'Template baru';
    }
  }

  // ------------------------------------------------------------ pemilih (gaya Money Manager)

  void _clearSplits() {
    for (final s in _splits) {
      s.$2.dispose();
    }
    _splits.clear();
  }

  Future<String?> _chooseCategory(String? selected) {
    FocusScope.of(context).unfocus();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      sheetAnimationStyle: AnimationStyle.noAnimation,
      builder: (_) => CategoryPanel(
          store: store, type: _type, selectedId: selected, accent: _type.color),
    );
  }

  /// Tambah satu bagian kategori (mulai membagi kalau belum).
  Future<void> _addSplit() async {
    final id = await _chooseCategory(null);
    if (id == null || !mounted) return;
    setState(() {
      _splits.add((id, TextEditingController()));
      _catTouched = true;
      _error = null;
    });
  }

  Future<void> _changeSplitCategory(int i) async {
    final id = await _chooseCategory(_splits[i].$1);
    if (id == null || !mounted) return;
    setState(() => _splits[i] = (id, _splits[i].$2));
  }

  void _removeSplit(int i) {
    setState(() {
      _splits[i].$2.dispose();
      _splits.removeAt(i);
    });
  }

  String _catName(String? id) {
    final c = store.categoryById(id);
    if (c == null) return 'Pilih kategori';
    final p = store.categoryById(c.parentId);
    return p == null ? c.name : '${p.name} › ${c.name}';
  }

  Widget _splitCard(Color accent) {
    final main = _mainShare;
    final noTotal = _amount <= 0;
    final ok = main > 0 || noTotal;
    Widget line({
      required String name,
      required VoidCallback onTapName,
      required Widget amount,
      VoidCallback? onRemove,
    }) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onTapName,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: C.carbon)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 120, child: amount),
              SizedBox(
                width: 36,
                child: onRemove == null
                    ? null
                    : IconButton(
                        tooltip: tr('Hapus bagian'),
                        visualDensity: VisualDensity.compact,
                        onPressed: onRemove,
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: C.muted)),
              ),
            ],
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Dibagi ke beberapa kategori',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: C.carbon)),
              ),
              TextButton(
                onPressed: () => setState(_clearSplits),
                child: const Text('Batal bagi'),
              ),
            ],
          ),
          line(
            name: _catName(_categoryId),
            onTapName: _pickCategory,
            amount: Text(
                money(main, _fromCur),
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: ok ? C.carbon : C.redDark)),
          ),
          for (var i = 0; i < _splits.length; i++)
            line(
              name: _catName(_splits[i].$1),
              onTapName: () => _changeSplitCategory(i),
              amount: TextField(
                controller: _splits[i].$2,
                keyboardType: TextInputType.numberWithOptions(
                    decimal: hasDecimals(_fromCur)),
                inputFormatters: [
                  AmountFormatter(decimals: hasDecimals(_fromCur))
                ],
                textAlign: TextAlign.right,
                onChanged: (_) => setState(() => _error = null),
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: C.carbon),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '0',
                  filled: true,
                  fillColor: C.bg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              onRemove: () => _removeSplit(i),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addSplit,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah kategori'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
                noTotal
                    ? 'Isi Jumlah di atas dulu. Baris pertama otomatis berisi sisanya.'
                    : ok
                        ? tr('Baris pertama otomatis berisi sisanya. Total tetap {0}.', [money(_amount, _fromCur)])
                        : tr('Bagian lain melebihi total {0}. Kurangi salah satunya.', [money(_amount, _fromCur)]),
                style: TextStyle(
                    fontSize: 12, color: ok ? C.muted : C.redDark)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCategory() async {
    FocusScope.of(context).unfocus();
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      sheetAnimationStyle: AnimationStyle.noAnimation,
      builder: (_) => CategoryPanel(
          store: store,
          type: _type,
          selectedId: _categoryId,
          accent: _type.color),
    );
    if (id == null || !mounted) return;
    setState(() {
      _categoryId = id;
      _catTouched = true;
      _catAuto = false;
      _catManual = true;
      _error = null;
    });
  }

  /// Kategori yang paling sering dipakai untuk jenis ini (lima teratas).
  List<String> _topCategoryIds() {
    final count = <String, int>{};
    for (final t in store.transactions) {
      if (t.type != _type) continue;
      final id = t.categoryId;
      if (id == null || store.categoryById(id) == null) continue;
      count[id] = (count[id] ?? 0) + 1;
    }
    final ids = count.keys.toList()
      ..sort((a, b) => count[b]!.compareTo(count[a]!));
    return ids.take(5).toList();
  }

  Widget _catChip(String id, Color accent) {
    final c = store.categoryById(id)!;
    final selected = id == _categoryId;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _categoryId = id;
          _catTouched = true;
          _catAuto = false;
          _catManual = true;
          _error = null;
        }),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? accent : C.line, width: selected ? 2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CatIcon(
                  icon: c.iconData, art: c.art, color: c.colorValue, size: 24),
              const SizedBox(width: 6),
              Flexible(
                child: Text(c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: C.carbon)),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_rounded, size: 16, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Baris Kategori berupa chip: pilihan sekarang, lima yang sering dipakai,
  /// dan "Semua kategori" yang membuka panel lengkap.
  Widget _categoryChips(Color accent) {
    final ids = <String>[
      if (_categoryId != null && store.categoryById(_categoryId) != null)
        _categoryId!,
      for (final id in _topCategoryIds())
        if (id != _categoryId) id,
    ].take(6).toList();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tr('Kategori'),
                    style: TextStyle(
                        fontSize: 14,
                        color: C.muted,
                        fontWeight: FontWeight.w600)),
              ),
              if (_canSplit && _categoryId != null)
                TextButton(
                  onPressed: _addSplit,
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: accent),
                  child: Text(tr('Bagi')),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in ids) _catChip(id, accent),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickCategory,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.apps_rounded, size: 18, color: C.muted),
                      const SizedBox(width: 6),
                      Text(tr('Semua kategori'),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: C.carbon)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_categoryId != null && (_catAuto || _catManual)) ...[
            const SizedBox(height: 6),
            Text(
                _catManual
                    ? tr('Dipilih manual')
                    : tr('Otomatis dari riwayat catatan'),
                style: TextStyle(fontSize: 12, color: C.muted)),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAccount({required bool to}) async {
    FocusScope.of(context).unfocus();
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      sheetAnimationStyle: AnimationStyle.noAnimation,
      builder: (_) => AccountPanel(
        store: store,
        selectedId: to ? _toId : _fromId,
        disabledId: to ? _fromId : null,
        accent: _type.color,
        excludeTxId: widget.excludeTxId,
        title: to ? 'Ke akun' : 'Akun',
      ),
    );
    if (id == null || !mounted) return;
    if (to) {
      _selectTo(id);
    } else {
      _selectFrom(id);
    }
  }

  Widget _accountValue(String id) {
    final a = store.accountById(id);
    if (a == null) return const FormValue(null);
    final bal = store.balanceOf(a.id, excludeTxId: widget.excludeTxId);
    return Row(
      children: [
        Expanded(child: FormValue(a.name)),
        Text(money(bal, a.currency),
            style: TextStyle(
                fontSize: 12, color: bal < 0 ? C.redDark : C.muted)),
      ],
    );
  }

  // ------------------------------------------------ catat satu layar (v4.0)

  Widget _accentTheme(Color accent, Widget child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: accent),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: accent,
            selectionHandleColor: accent,
            selectionColor: accent.withValues(alpha: 0.25),
          ),
        ),
        child: child,
      );

  /// Tombol angka bawaan app: 1-9, 000 (atau koma untuk mata uang desimal),
  /// 0, hapus. Tahan hapus untuk mengosongkan.
  void _key(String k) {
    final dec = hasDecimals(_fromCur);
    final old = _amountCtrl.text;
    var t = old;
    if (k == 'del') {
      if (dec) {
        t = old.isEmpty ? '' : old.substring(0, old.length - 1);
      } else {
        final d = old.replaceAll(RegExp(r'[^0-9]'), '');
        t = d.isEmpty ? '' : d.substring(0, d.length - 1);
      }
    } else if (k == '.') {
      if (!dec || old.contains('.')) return;
      t = '${old.isEmpty ? '0' : old}.';
    } else {
      t = old + k;
    }
    if (dec && !t.contains('.')) t = t.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    var text = AmountFormatter(decimals: dec)
        .formatEditUpdate(
            TextEditingValue(text: old), TextEditingValue(text: t))
        .text;
    if (!dec && parseAmount(text) == 0) text = '';
    HapticFeedback.selectionClick();
    setState(() {
      _amountCtrl.text = text;
      _error = null;
      _syncToAmount();
    });
  }

  void _clearAmount() {
    HapticFeedback.mediumImpact();
    setState(() {
      _amountCtrl.text = '';
      _error = null;
      _syncToAmount();
    });
  }

  Widget _numpad() {
    final dec = hasDecimals(_fromCur);
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', dec ? '.' : '000', '0', 'del'];
    Widget keyBox(String k) {
      final isDel = k == 'del';
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Semantics(
            button: true,
            label: isDel ? 'Hapus' : (k == '.' ? 'Koma' : k),
            excludeSemantics: true,
            child: Material(
              color: C.bg,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _key(k),
                onLongPress: isDel ? _clearAmount : null,
                child: SizedBox(
                  height: 46,
                  child: Center(
                    child: isDel
                        ? Icon(Icons.backspace_outlined,
                            size: 21, color: C.carbon)
                        : Text(k == '.' ? ',' : k,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: C.carbon)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var r = 0; r < 4; r++)
          Padding(
            padding: EdgeInsets.only(top: r == 0 ? 0 : 6),
            child: Row(children: [for (final k in keys.sublist(r * 3, r * 3 + 3)) keyBox(k)]),
          ),
      ],
    );
  }

  String _dateLabel() {
    final n = DateTime.now();
    final diff = DateTime(n.year, n.month, n.day)
        .difference(DateTime(_date.year, _date.month, _date.day))
        .inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    return DateFormat('d MMM yyyy', gDateLoc).format(_date);
  }

  Widget _pill({
    required Widget leading,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    bool disabled = false,
    Color? accent,
    bool dropdown = false,
  }) {
    final a = accent ?? _type.color;
    return Opacity(
      opacity: disabled ? 0.35 : 1,
      child: Material(
        color: selected ? a.withValues(alpha: 0.08) : Colors.transparent,
        shape: StadiumBorder(
            side: BorderSide(
                color: selected ? a : C.line, width: selected ? 1.6 : 1)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading,
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? a : C.carbon)),
                ),
                if (dropdown)
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: C.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _accountLeading(String id, {double size = 22}) {
    final a = store.accountById(id);
    if (a == null) return SizedBox(width: size, height: size);
    return CatIcon(icon: a.type.icon, art: a.type.art, color: a.colorValue, size: size);
  }

  Widget _accountRow({required bool to}) {
    final selected = to ? _toId : _fromId;
    final disabled = to ? _fromId : null;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: store.accounts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final a = store.accounts[i];
          return _pill(
            leading: _accountLeading(a.id),
            label: a.name,
            selected: a.id == selected,
            disabled: a.id == disabled,
            onTap: () => to ? _selectTo(a.id) : _selectFrom(a.id),
          );
        },
      ),
    );
  }

  /// Induk kategori yang sub-nya sedang terbuka di form (null = tertutup).
  String? _openParent;

  String _plainName(String raw) =>
      tr(raw).replaceAll(_emojiRe, '').replaceAll(RegExp(r'\s+'), ' ').trim();

  void _tapParent(TxCategory c) {
    if (store.childrenOf(c.id).isEmpty) {
      _chooseCategory1(c.id);
      setState(() => _openParent = null);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _openParent = _openParent == c.id ? null : c.id);
  }

  Widget _parentTile(TxCategory c, Color accent, {required bool sel}) {
    final hasSubs = store.childrenOf(c.id).isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _tapParent(c),
      child: Semantics(
        button: true,
        selected: sel,
        label: c.name,
        excludeSemantics: true,
        child: Container(
          decoration: BoxDecoration(
            color: sel ? accent.withValues(alpha: 0.08) : null,
            border: sel ? Border.all(color: accent, width: 1.6) : null,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
          child: Stack(
            children: [
              Column(
                children: [
                  CatIcon(
                      icon: c.iconData, art: c.art, color: c.colorValue, size: 42),
                  const SizedBox(height: 4),
                  Text(shortCategoryName(c.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10.5,
                          height: 1.15,
                          fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                          color: sel ? accent : C.carbon)),
                ],
              ),
              if (hasSubs)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(
                      _openParent == c.id
                          ? Icons.expand_less_rounded
                          : Icons.chevron_right_rounded,
                      size: 14,
                      color: C.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sub-kategori yang muncul tepat di bawah baris induknya.
  Widget _subPanel(TxCategory parent, Color accent) {
    Widget chip(String label, String id) {
      final sel = id == _categoryId;
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _chooseCategory1(id);
          setState(() => _openParent = null);
        },
        child: Semantics(
          button: true,
          selected: sel,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? accent.withValues(alpha: 0.08) : C.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: sel ? accent : C.line, width: sel ? 2 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                          color: sel ? accent : C.carbon)),
                ),
                if (sel) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check_rounded, size: 16, color: accent),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: C.bg, borderRadius: BorderRadius.circular(14)),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          chip(tr('Umum ({0})', [shortCategoryName(parent.name)]), parent.id),
          for (final sub in store.childrenOf(parent.id))
            chip(_plainName(sub.name), sub.id),
        ],
      ),
    );
  }

  /// Kategori langsung di form (v5.12): pintasan sering dipakai, lalu semua
  /// kategori induk dengan sub-kategori yang terbuka di tempat. Tanpa sheet.
  Widget _categoryArea(Color accent) {
    final tops = store.topCategories(_type);
    final selTop = _categoryId == null ? null : store.topCategoryId(_categoryId!);
    final rows = <Widget>[];
    for (var i = 0; i < tops.length; i += 4) {
      final chunk = tops.sublist(i, math.min(i + 4, tops.length));
      rows.add(GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 0.86,
        children: [
          for (final c in chunk) _parentTile(c, accent, sel: c.id == selTop),
        ],
      ));
      for (final c in chunk) {
        if (c.id == _openParent) rows.add(_subPanel(c, accent));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(tr('SERING DIPAKAI'),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: C.muted)),
            const Spacer(),
            Text(tr('tahan untuk pin'),
                style: TextStyle(fontSize: 11, color: C.muted)),
          ],
        ),
        const SizedBox(height: 4),
        _frequentGrid(accent, limit: 4, withAll: false),
        const SizedBox(height: 6),
        Text(tr('SEMUA KATEGORI'),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: C.muted)),
        const SizedBox(height: 4),
        ...rows,
      ],
    );
  }

  /// Nominal yang paling sering dipakai di kategori terpilih (maks. 3, minimal
  /// dua kali dipakai dalam 180 hari terakhir), urut dari yang kecil.
  List<double> _usualAmounts() {
    final id = _categoryId;
    if (id == null || _type == TxType.transfer) return const [];
    final from = DateTime.now().subtract(const Duration(days: 180));
    final count = <double, int>{};
    final last = <double, DateTime>{};
    for (final t in store.transactions) {
      if (t.type != _type || t.categoryId != id || t.date.isBefore(from)) {
        continue;
      }
      if (store.currencyOf(t.accountId) != _fromCur || t.amount <= 0) continue;
      count[t.amount] = (count[t.amount] ?? 0) + 1;
      final l = last[t.amount];
      if (l == null || t.date.isAfter(l)) last[t.amount] = t.date;
    }
    final ranked = count.keys.where((a) => count[a]! >= 2).toList()
      ..sort((a, b) {
        final c = count[b]!.compareTo(count[a]!);
        return c != 0 ? c : last[b]!.compareTo(last[a]!);
      });
    return ranked.take(3).toList()..sort();
  }

  Widget _usualAmountChips(Color accent) {
    final c = store.categoryById(_categoryId);
    final amounts = _usualAmounts();
    if (c == null || amounts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(tr('Biasanya di {0}:', [shortCategoryName(c.name)]),
              style: TextStyle(fontSize: 12, color: C.muted)),
          for (final a in amounts)
            Semantics(
              button: true,
              label: money(a, _fromCur),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _amountCtrl.text = amountToInput(a, _fromCur);
                    _syncToAmount();
                    _error = null;
                  });
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accent),
                  ),
                  child: Text(amountToInput(a, _fromCur),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accent)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _chooseCategory1(String id) {
    if (id == _categoryId) return;
    HapticFeedback.selectionClick();
    setState(() {
      _categoryId = id;
      _catTouched = true;
      _error = null;
    });
  }

  Future<void> _categoryMenu(String id) async {
    final c = store.categoryById(id);
    if (c == null) return;
    HapticFeedback.mediumImpact();
    final pinned = store.isPinned(id);
    final hidden = store.settings.hiddenFreq.contains(id);
    final uses = store.categoryUseCount(id);
    final act = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      sheetAnimationStyle: AnimationStyle.noAnimation,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CatIcon(icon: c.iconData, art: c.art, color: c.colorValue, size: 40),
              title: Text(c.name,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(uses == 0
                  ? 'Belum dipakai dalam 90 hari terakhir'
                  : tr('Dipakai {0} kali dalam 90 hari terakhir', [uses])),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                  pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded),
              title: Text(pinned ? 'Lepas pin' : 'Pin ke atas'),
              onTap: () => Navigator.pop(ctx, 'pin'),
            ),
            if (hidden)
              ListTile(
                leading: const Icon(Icons.visibility_rounded),
                title: const Text('Tampilkan lagi di "Sering dipakai"'),
                onTap: () => Navigator.pop(ctx, 'show'),
              )
            else
              ListTile(
                leading: const Icon(Icons.visibility_off_rounded),
                title: const Text('Sembunyikan dari "Sering dipakai"'),
                onTap: () => Navigator.pop(ctx, 'hide'),
              ),
          ],
        ),
      ),
    );
    if (act == null || !mounted) return;
    switch (act) {
      case 'pin':
        final ok = store.togglePin(id);
        if (!ok) {
          snack(context,
              tr('Maksimal {0} kategori dipin. Lepas pin satu dulu.', [AppStore.kFrequentSlots]));
        }
      case 'hide':
        store.hideFromFrequent(id);
      case 'show':
        store.showInFrequent(id);
    }
    setState(() {});
  }

  Widget _frequentGrid(Color accent, {int? limit, bool withAll = true}) {
    final ids = limit == null
        ? store.frequentCategories(_type, ensure: _categoryId)
        : store.frequentCategories(_type, ensure: _categoryId, limit: limit);
    final cells = <Widget>[];
    for (final id in ids) {
      final c = store.categoryById(id);
      if (c == null) continue;
      final sel = id == _categoryId;
      cells.add(InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _chooseCategory1(id),
        onLongPress: () => _categoryMenu(id),
        child: Semantics(
          button: true,
          selected: sel,
          label: c.name,
          excludeSemantics: true,
          child: Container(
            decoration: BoxDecoration(
              color: sel ? accent.withValues(alpha: 0.08) : null,
              border: sel ? Border.all(color: accent, width: 1.6) : null,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CatIcon(icon: c.iconData, art: c.art, color: c.colorValue, size: 42),
                    if (store.isPinned(id))
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                              color: C.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: C.line)),
                          child: Icon(Icons.push_pin_rounded,
                              size: 11, color: accent),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(shortCategoryName(c.name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10.5,
                        height: 1.15,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                        color: sel ? accent : C.carbon)),
              ],
            ),
          ),
        ),
      ));
    }
    if (withAll) cells.add(InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _pickCategory,
      child: Semantics(
        button: true,
        label: 'Semua kategori',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              CatIcon(
                  icon: Icons.apps_rounded,
                  art: 'other',
                  color: C.muted,
                  size: 42),
              const SizedBox(height: 4),
              Text('Semua',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: C.carbon)),
            ],
          ),
        ),
      ),
    ));
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 0.86,
      children: cells,
    );
  }

  /// Foto struk (dipakai di layar detail).
  Widget _photoSection(Color accent, VoidCallback refresh) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final p in _photos)
            ReceiptThumb(
              name: p,
              onRemove: () {
                setState(() => _photos.remove(p));
                refresh();
              },
            ),
          InkWell(
            onTap: () async {
              await _addPhoto();
              refresh();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.line, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_rounded, size: 20, color: accent),
                  Text('Struk',
                      style: TextStyle(fontSize: 10, color: C.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasDetails =>
      _noteCtrl.text.trim().isNotEmpty ||
      _photos.isNotEmpty ||
      _eventId != null ||
      _saveTemplate;

  /// Judul, catatan, foto struk, acara, bagi kategori, tempel struk, template.
  ///
  /// [focusTitle]: dibuka dari tulisan judul, jadi kolom Judul langsung aktif
  /// dan keyboard muncul tanpa perlu mengetuk lagi.
  Future<void> _openDetails({bool focusTitle = false}) async {
    FocusScope.of(context).unfocus();
    if (focusTitle) {
      // Tunggu lembar terbuka dulu, baru fokus (kolomnya baru ada di dalamnya).
      unawaited(Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (mounted && !_titleFocus.hasFocus) _titleFocus.requestFocus();
      }));
    }
    final accent = _type.color;
    await showSheet<void>(
      context,
      StatefulBuilder(
        builder: (ctx, setInner) {
          void refresh() {
            if (mounted) setInner(() {});
          }

          return _accentTheme(
            accent,
            SheetFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Detail transaksi',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: C.carbon)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Selesai'),
                      ),
                    ],
                  ),
                  FormRow(
                    label: 'Judul',
                    accent: accent,
                    child: SuggestField(
                      controller: _titleCtrl,
                      focusNode: _titleFocus,
                      suggest: (q) => store.suggestTitles(q, _type),
                      detail: (t) {
                        final last = store.lastWithTitle(t, _type);
                        if (last == null) return null;
                        final cat = store
                            .categoryById(store.learnedCategory(t, _type) ??
                                last.categoryId)
                            ?.name;
                        return [
                          money(last.amount, store.currencyOf(last.accountId)),
                          ?cat,
                          store.accountName(last.accountId),
                        ].join(' · ');
                      },
                      onPicked: (t) {
                        _pickedTitle(t);
                        refresh();
                      },
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: C.carbon),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        hintText: tr('Misal "Nasi padang"'),
                      ),
                    ),
                  ),
                  FormRow(
                    label: 'Catatan',
                    accent: accent,
                    child: SuggestField(
                      controller: _noteCtrl,
                      focusNode: _noteFocus,
                      suggest: store.suggestNotes,
                      maxLength: 120,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(fontSize: 14, color: C.carbon),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        hintText: tr('Opsional'),
                      ),
                    ),
                  ),
                  if (store.feature('acara') && store.events.isNotEmpty)
                    FormRow(
                      label: 'Acara',
                      accent: accent,
                      onTap: () async {
                        final id = await pickEvent(ctx, store, _eventId);
                        if (id == null || !mounted) return;
                        setState(() => _eventId = id.isEmpty ? null : id);
                        refresh();
                      },
                      child: FormValue(store.eventById(_eventId)?.name,
                          placeholder: 'Tanpa acara'),
                    ),
                  if (Receipts.available)
                    FormRow(
                      label: 'Foto',
                      accent: accent,
                      child: _photoSection(accent, refresh),
                    ),
                  if (_canSplit && !_splitting && _categoryId != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.call_split_rounded, color: accent),
                      title: const Text('Bagi ke beberapa kategori',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _addSplit();
                      },
                    ),
                  if (!widget.isEditing) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.content_paste_rounded, color: accent),
                      title: const Text('Isi dari teks struk atau notifikasi',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Salin dulu teksnya, lalu ketuk di sini'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _pasteReceipt();
                      },
                    ),
                    if (store.templates.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Pakai template',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: C.muted)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in store.templates)
                            ActionChip(
                              avatar: const Icon(Icons.bolt_rounded, size: 16),
                              label: Text(t.title),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              side: BorderSide(color: C.line),
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _applyTemplate(t);
                              },
                            ),
                        ],
                      ),
                    ],
                    CheckboxListTile(
                      value: _saveTemplate,
                      onChanged: (v) {
                        setState(() => _saveTemplate = v ?? false);
                        refresh();
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Simpan juga sebagai template catat cepat',
                          style: TextStyle(fontSize: 13.5)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: 'Selesai',
                    color: accent,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  String get _saveLabel {
    if (widget.isEditing) return 'Simpan perubahan';
    final a = _amount;
    if (a <= 0) return 'Simpan';
    final m = money(a, _fromCur);
    return switch (_type) {
      TxType.expense => 'Simpan $m',
      TxType.income => 'Simpan pemasukan $m',
      TxType.transfer => 'Simpan transfer $m',
    };
  }

  Widget _buildOnePage(BuildContext context) {
    final accent = _type.color;
    final isTransfer = _type == TxType.transfer;
    final dec = hasDecimals(_fromCur);
    final raw = _amountCtrl.text;
    final empty = raw.isEmpty;
    final shown = empty ? '0' : (dec ? raw.replaceAll('.', ',') : raw);
    final title = _titleCtrl.text.trim();

    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Segmented<TxType>(
          values: const [TxType.expense, TxType.income, TxType.transfer],
          selected: _type,
          labelOf: (t) => t.label,
          colorOf: (t) => t.color,
          dense: true,
          onChanged: _changeType,
        ),
        const SizedBox(height: 10),
        // Nominal besar (diisi lewat tombol angka di bawah).
        Row(
          children: [
            const SizedBox(width: 44),
            Expanded(
              child: Semantics(
                label: 'Nominal $shown',
                excludeSemantics: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(currencySymbol(_fromCur),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: C.muted)),
                      const SizedBox(width: 6),
                      Text(shown,
                          style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: empty ? C.muted.withValues(alpha: 0.45) : C.carbon)),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: tr('Kalkulator'),
              onPressed: _openCalculator,
              icon: Icon(Icons.calculate_rounded, color: accent),
            ),
          ],
        ),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openDetails(focusTitle: true),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Text(title.isEmpty ? '+ Tambah judul atau catatan' : title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: title.isEmpty ? FontWeight.w600 : FontWeight.w700,
                    color: title.isEmpty ? C.muted : C.carbon)),
          ),
        ),
        const SizedBox(height: 8),
        if (!isTransfer && _amountCtrl.text.isEmpty && !widget.isEditing)
          _usualAmountChips(accent),
        if (isTransfer) ...[
          Text('DARI AKUN',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: C.muted)),
          const SizedBox(height: 6),
          _accountRow(to: false),
          const SizedBox(height: 10),
          Text('KE AKUN',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: C.muted)),
          const SizedBox(height: 6),
          _accountRow(to: true),
          if (_crossCurrency) ...[
            const SizedBox(height: 6),
            FormRow(
              label: 'Diterima',
              accent: accent,
              child: TextField(
                controller: _toAmountCtrl,
                keyboardType:
                    TextInputType.numberWithOptions(decimal: hasDecimals(_toCur)),
                inputFormatters: [AmountFormatter(decimals: hasDecimals(_toCur))],
                onChanged: (_) => setState(() {
                  _toTouched = true;
                  _error = null;
                }),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(currencySymbol(_toCur),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  helperText: tr('Otomatis dari kurs, ubah kalau beda.'),
                ),
              ),
            ),
          ],
        ] else if (_splitting && _canSplit)
          _splitCard(accent)
        else
          _categoryArea(accent),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!isTransfer)
              _pill(
                leading: _accountLeading(_fromId, size: 22),
                label: store.accountName(_fromId),
                dropdown: true,
                onTap: () => _pickAccount(to: false),
              ),
            _pill(
              leading: ArtIcon(Icons.calendar_month_rounded,
                  color: accent, size: 16),
              label: _dateLabel(),
              dropdown: true,
              onTap: _pickDate,
            ),
            _pill(
              leading: Icon(
                  _hasDetails ? Icons.edit_note_rounded : Icons.add_rounded,
                  size: 18,
                  color: _hasDetails ? accent : C.muted),
              label: _hasDetails ? 'Detail terisi' : 'Catatan, struk, bagi',
              selected: _hasDetails,
              onTap: _openDetails,
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );

    return _accentTheme(
      accent,
      Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      decoration: BoxDecoration(
                          color: C.line, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                              widget.isEditing ? 'Edit transaksi' : 'Catat transaksi',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: C.carbon)),
                        ),
                        IconButton(
                          tooltip: tr('Tutup'),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: top,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(17, 4, 17, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_info != null && _error == null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(_info!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: C.accentDark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5)),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ErrorBox(_error!),
                          ),
                        _numpad(),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Row(
                            children: [
                              if (widget.onContinue != null && !widget.isEditing) ...[
                                Expanded(
                                  flex: 4,
                                  child: OutlinedButton(
                                    onPressed: _submitContinue,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                      foregroundColor: accent,
                                      side: BorderSide(color: accent, width: 1.5),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: Text(tr('Simpan & lanjut'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            height: 1.15)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                flex: 6,
                                child: PrimaryButton(
                                  label: _saveLabel,
                                  color: accent,
                                  onPressed: _submit,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == FormMode.transaction) return _buildOnePage(context);
    final accent = _type.color;
    final isTransfer = _type == TxType.transfer;
    final mode = widget.mode;
    final showQuickRow = mode == FormMode.transaction && !widget.isEditing;
    final fromDecimals = hasDecimals(_fromCur);

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: accent),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: accent,
          selectionHandleColor: accent,
          selectionColor: accent.withValues(alpha: 0.25),
        ),
      ),
      child: SheetFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_heading,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: C.carbon)),
                ),
                IconButton(
                  tooltip: tr('Tutup'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tab jenis: Pemasukan | Pengeluaran | Transfer
            Row(
              children: [
                for (final t in const [
                  TxType.income,
                  TxType.expense,
                  TxType.transfer
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Semantics(
                        button: true,
                        selected: t == _type,
                        child: GestureDetector(
                          onTap: () => _changeType(t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: t == _type
                                  ? t.color.withValues(alpha: 0.08)
                                  : C.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: t == _type ? t.color : C.line,
                                  width: t == _type ? 1.6 : 1),
                            ),
                            child: Text(t.label,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: t == _type ? t.color : C.muted)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),

            // Baris-baris isian
            if (mode != FormMode.template)
              FormRow(
                label: mode == FormMode.recurring ? 'Mulai' : 'Tanggal',
                accent: accent,
                onTap: _pickDate,
                child: FormValue(
                    DateFormat('EEE, dd/MM/yyyy', gDateLoc).format(_date)),
              ),
            FormRow(
              label: 'Jumlah',
              accent: accent,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      autofocus: !widget.isEditing,
                      keyboardType: TextInputType.numberWithOptions(
                          decimal: fromDecimals),
                      textInputAction: TextInputAction.next,
                      // Selesai isi nominal -> lanjut ke Catatan; kategori
                      // terisi otomatis dari riwayat atau dipilih lewat chip.
                      onSubmitted: (_) {
                        if (!isTransfer) _titleFocus.requestFocus();
                      },
                      inputFormatters: [
                        AmountFormatter(decimals: fromDecimals)
                      ],
                      onChanged: (_) => setState(() {
                        _error = null;
                        _syncToAmount();
                      }),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: accent),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                        // prefixIcon (bukan prefixText) supaya simbol mata
                        // uang tetap tampil walau kolom kosong dan tidak fokus.
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(currencySymbol(_fromCur),
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: accent)),
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                        hintText: '0',
                        hintStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: accent.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('Kalkulator'),
                    visualDensity: VisualDensity.compact,
                    onPressed: _openCalculator,
                    icon: Icon(Icons.calculate_rounded, color: accent),
                  ),
                ],
              ),
            ),
            FormRow(
              label: mode == FormMode.template ? 'Nama' : 'Catatan',
              accent: accent,
              child: SuggestField(
                controller: _titleCtrl,
                focusNode: _titleFocus,
                suggest: (q) => store.suggestTitles(q, _type),
                detail: (t) {
                  final last = store.lastWithTitle(t, _type);
                  if (last == null) return null;
                  final cat = store.categoryById(
                          store.learnedCategory(t, _type) ?? last.categoryId)
                      ?.name;
                  return [
                    money(last.amount, store.currencyOf(last.accountId)),
                    ?cat,
                    store.accountName(last.accountId),
                  ].join(' · ');
                },
                onPicked: _pickedTitle,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: C.carbon),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  hintText: tr('Opsional, misal "Nasi padang"'),
                ),
              ),
            ),
            if (!isTransfer && _splitting && _canSplit)
              _splitCard(accent)
            else if (!isTransfer)
              _categoryChips(accent),
            FormRow(
              label: isTransfer ? 'Dari' : 'Akun',
              accent: accent,
              onTap: () => _pickAccount(to: false),
              child: _accountValue(_fromId),
            ),
            if (isTransfer)
              FormRow(
                label: 'Ke',
                accent: accent,
                onTap: () => _pickAccount(to: true),
                child: _accountValue(_toId),
              ),
            if (isTransfer && _crossCurrency)
              FormRow(
                label: 'Diterima',
                accent: accent,
                child: TextField(
                  controller: _toAmountCtrl,
                  keyboardType: TextInputType.numberWithOptions(
                      decimal: hasDecimals(_toCur)),
                  inputFormatters: [
                    AmountFormatter(decimals: hasDecimals(_toCur))
                  ],
                  onChanged: (_) => setState(() {
                    _toTouched = true;
                    _error = null;
                  }),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    // prefixIcon supaya simbol tetap tampil walau kosong.
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(currencySymbol(_toCur),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 0, minHeight: 0),
                    helperText: tr('Otomatis dari kurs, ubah kalau beda.'),
                  ),
                ),
              ),
            if (mode == FormMode.transaction && store.feature('acara') && store.events.isNotEmpty)
              FormRow(
                label: 'Acara',
                accent: accent,
                onTap: () async {
                  final id = await pickEvent(context, store, _eventId);
                  if (id == null || !mounted) return;
                  setState(() => _eventId = id.isEmpty ? null : id);
                },
                child: FormValue(store.eventById(_eventId)?.name,
                    placeholder: 'Tanpa acara'),
              ),
            FormRow(
              label: 'Deskripsi',
              accent: accent,
              child: SuggestField(
                controller: _noteCtrl,
                focusNode: _noteFocus,
                suggest: store.suggestNotes,
                maxLength: 120,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: C.carbon),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  hintText: tr('Opsional'),
                ),
              ),
            ),
            if (mode == FormMode.transaction && Receipts.available)
              FormRow(
                label: 'Foto',
                accent: accent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final p in _photos)
                        ReceiptThumb(
                          name: p,
                          onRemove: () => setState(() => _photos.remove(p)),
                        ),
                      InkWell(
                        onTap: _addPhoto,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: C.line, width: 1.5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_rounded,
                                  size: 20, color: accent),
                              Text('Struk',
                                  style:
                                      TextStyle(fontSize: 10, color: C.muted)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (showQuickRow) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ActionChip(
                      avatar: Icon(Icons.content_paste_rounded,
                          size: 16, color: accent),
                      label: const Text('Tempel struk',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(color: accent),
                      onPressed: _pasteReceipt,
                    ),
                    for (final t in store.templates) ...[
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.bolt_rounded, size: 16),
                        label: Text(t.title),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(color: C.line),
                        onPressed: () => _applyTemplate(t),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_info != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: C.accentDark, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_info!,
                          style: TextStyle(
                              color: C.accentDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            // Frekuensi (khusus berulang)
            if (mode == FormMode.recurring) ...[
              const SizedBox(height: 14),
              const SmallLabel('Ulangi setiap'),
              const SizedBox(height: 8),
              Segmented<Frequency>(
                values: Frequency.values,
                selected: _frequency,
                labelOf: (f) => f.label,
                colorOf: (_) => accent,
                dense: true,
                onChanged: (f) => setState(() => _frequency = f),
              ),
            ],
            if (mode == FormMode.transaction && !widget.isEditing)
              CheckboxListTile(
                value: _saveTemplate,
                onChanged: (v) => setState(() => _saveTemplate = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Simpan juga sebagai template catat cepat',
                    style: TextStyle(fontSize: 13.5)),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorBox(_error!),
            ],
            const SizedBox(height: 14),
            PrimaryButton(
              label: widget.isEditing ? 'Simpan perubahan' : 'Simpan',
              color: accent,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- baris form

/// TextField dengan saran dari teks yang pernah diketik (ketik "pot" ->
/// "Potong rambut").
class SuggestField extends StatelessWidget {
  const SuggestField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.suggest,
    this.detail,
    this.onPicked,
    this.decoration = const InputDecoration(),
    this.style,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> Function(String) suggest;

  /// Keterangan kecil di bawah saran (mis. "Rp 24.000 · Kafe").
  final String? Function(String)? detail;
  final ValueChanged<String>? onPicked;
  final InputDecoration decoration;
  final TextStyle? style;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => RawAutocomplete<String>(
        textEditingController: controller,
        focusNode: focusNode,
        optionsBuilder: (v) => suggest(v.text),
        onSelected: (v) => onPicked?.call(v),
        fieldViewBuilder: (context, ctrl, focus, onSubmit) => TextField(
          controller: ctrl,
          focusNode: focus,
          maxLength: maxLength,
          minLines: minLines,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          style: style,
          decoration: decoration,
          onSubmitted: (_) => onSubmit(),
        ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: C.surface,
            elevation: 6,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: 230,
                  maxWidth: box.maxWidth.clamp(180.0, 420.0).toDouble()),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    InkWell(
                      onTap: () => onSelected(o),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded,
                                size: 16, color: C.muted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(o,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 14, color: C.carbon)),
                                  if (detail?.call(o) case final d?)
                                    Text(d,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12, color: C.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FormRow extends StatelessWidget {
  const FormRow({
    super.key,
    required this.label,
    required this.child,
    required this.accent,
    this.onTap,
  });

  final String label;
  final Widget child;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    color: C.muted,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(child: child),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return row;
    return InkWell(onTap: tap, child: row);
  }
}

class FormValue extends StatelessWidget {
  const FormValue(this.text, {super.key, this.placeholder = '-'});
  final String? text;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final t = text;
    final empty = t == null || t.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(empty ? placeholder : t,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 15,
              fontWeight: empty ? FontWeight.w500 : FontWeight.w700,
              color: empty ? C.muted : C.carbon)),
    );
  }
}

// ------------------------------------------------- panel kategori (grid MM)

/// Nama kategori untuk kotak kecil: tanpa emoji dan tanpa keterangan dalam
/// kurung, mis. "Bills (Listrik, Air, Kuota) 💡" menjadi "Bills".
String shortCategoryName(String rawName) {
  final name = tr(rawName);
  final t = name
      .replaceAll(_emojiRe, '')
      .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return t.isEmpty ? name.trim() : t;
}

final RegExp _emojiRe = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}]',
    unicode: true);

class CategoryPanel extends StatefulWidget {
  const CategoryPanel({
    super.key,
    required this.store,
    required this.type,
    required this.selectedId,
    required this.accent,
  });

  final AppStore store;
  final TxType type;
  final String? selectedId;
  final Color accent;

  @override
  State<CategoryPanel> createState() => _CategoryPanelState();
}

class _CategoryPanelState extends State<CategoryPanel> {
  String? _open; // parent yang sedang dibuka sub-kategorinya

  AppStore get store => widget.store;

  String? get _selectedTop {
    final s = widget.selectedId;
    return s == null ? null : store.topCategoryId(s);
  }

  void _tapTop(TxCategory c) {
    if (store.childrenOf(c.id).isEmpty) {
      Navigator.pop(context, c.id);
    } else {
      setState(() => _open = c.id);
    }
  }

  Widget _label(TxCategory c, {required bool selected, double size = 13}) {
    final hasEmoji = _emojiRe.hasMatch(c.name);
    final text = Text(c.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: size,
            height: 1.2,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? widget.accent : C.carbon));
    if (hasEmoji) return text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(c.iconData, size: 18, color: darken(c.colorValue)),
        const SizedBox(height: 2),
        text,
      ],
    );
  }

  Widget _grid(List<TxCategory> tops) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisExtent: 68),
      itemCount: tops.length,
      itemBuilder: (context, i) {
        final c = tops[i];
        final sel = c.id == _selectedTop;
        final hasSubs = store.childrenOf(c.id).isNotEmpty;
        return InkWell(
          onTap: () => _tapTop(c),
          child: Container(
            decoration: BoxDecoration(
              color: sel ? widget.accent.withValues(alpha: 0.08) : null,
              border: Border(
                right: BorderSide(color: C.line),
                bottom: BorderSide(color: C.line),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Stack(
              children: [
                Center(child: _label(c, selected: sel)),
                if (hasSubs)
                  Positioned(
                    right: 0,
                    bottom: 4,
                    child: Icon(Icons.chevron_right_rounded,
                        size: 14, color: C.muted),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _split(List<TxCategory> tops, String open) {
    final parent = store.categoryById(open);
    final subs = store.childrenOf(open);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.42,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final c in tops)
                InkWell(
                  onTap: () => _tapTop(c),
                  child: Container(
                    color: c.id == open ? C.bg : C.surface,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                    child: Text(c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: c.id == open
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: c.id == open ? widget.accent : C.carbon)),
                  ),
                ),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: C.line),
        Expanded(
          child: Container(
            color: C.bg,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _subTile(
                    parent == null ? 'Umum' : 'Umum (${parent.name})',
                    open,
                    widget.selectedId == open),
                for (final s in subs)
                  _subTile(s.name, s.id, widget.selectedId == s.id),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _subTile(String name, String id, bool sel) {
    return InkWell(
      onTap: () => Navigator.pop(context, id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.line))),
        child: Row(
          children: [
            Expanded(
              child: Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                      color: sel ? widget.accent : C.carbon)),
            ),
            if (sel)
              Icon(Icons.check_rounded, size: 18, color: widget.accent),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tops = store.topCategories(widget.type);
    final open = _open;
    // Setinggi isinya saja (maks. 50% layar) supaya kategori dekat jempol.
    final rows = (tops.length / 3).ceil().clamp(2, 99);
    final h = math.min(MediaQuery.sizeOf(context).height * 0.5,
        57.0 + rows * 68.0);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
              child: Row(
                children: [
                  if (open != null)
                    IconButton(
                      tooltip: tr('Kembali'),
                      onPressed: () => setState(() => _open = null),
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  else
                    const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Kategori',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                    tooltip: tr('Tutup'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: C.line),
            Expanded(
              child: tops.isEmpty
                  ? Center(
                      child: Text('Belum ada kategori. Tambah di Lainnya > Kategori.',
                          style: TextStyle(color: C.muted)))
                  : (open == null ? _grid(tops) : _split(tops, open)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------- panel akun (grid MM)

class AccountPanel extends StatelessWidget {
  const AccountPanel({
    super.key,
    required this.store,
    required this.selectedId,
    required this.accent,
    required this.title,
    this.disabledId,
    this.excludeTxId,
  });

  final AppStore store;
  final String selectedId;
  final String? disabledId;
  final String? excludeTxId;
  final Color accent;
  final String title;

  @override
  Widget build(BuildContext context) {
    final accs = store.accounts;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                IconButton(
                  tooltip: tr('Tutup'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: C.line),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5),
            child: GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, mainAxisExtent: 68),
              itemCount: accs.length,
              itemBuilder: (context, i) {
                final a = accs[i];
                final sel = a.id == selectedId;
                final disabled = a.id == disabledId;
                final bal = store.balanceOf(a.id, excludeTxId: excludeTxId);
                return Opacity(
                  opacity: disabled ? 0.35 : 1,
                  child: InkWell(
                    onTap: disabled ? null : () => Navigator.pop(context, a.id),
                    child: Container(
                      decoration: BoxDecoration(
                        color: sel ? accent.withValues(alpha: 0.08) : null,
                        border: Border(
                          right: BorderSide(color: C.line),
                          bottom: BorderSide(color: C.line),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      sel ? FontWeight.w800 : FontWeight.w600,
                                  color: sel ? accent : C.carbon)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(money(bal, a.currency),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: bal < 0 ? C.redDark : C.muted)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
