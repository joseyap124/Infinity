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
  });

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

  /// true kalau user sudah memilih kategori sendiri (jangan ditimpa tebakan).
  late bool _catTouched;
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
    super.dispose();
  }

  String _otherAccount(String id) => store.accounts
      .firstWhere((a) => a.id != id, orElse: () => store.accounts.first)
      .id;

  String? _defaultCategory(TxType t) {
    if (t == TxType.transfer) return null;
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
    if (_titleFocus.hasFocus || _catTouched || !mounted) return;
    if (_type == TxType.transfer) return;
    final cat = store.learnedCategory(_titleCtrl.text, _type);
    if (cat == null || cat == _categoryId) return;
    setState(() {
      _categoryId = cat;
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

  void _submit() {
    final amount = _amount;
    String? err;
    double? toAmount;

    if (amount <= 0) {
      err = 'Nominal harus lebih dari 0 ya 🙏';
    } else if (_type == TxType.transfer && _fromId == _toId) {
      err = 'Akun asal dan tujuan tidak boleh sama. Tambah akun lain dulu kalau baru punya satu.';
    } else if (_type != TxType.transfer && _categoryId == null) {
      err = 'Pilih kategori dulu.';
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
      return;
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
    );
    final title = _titleCtrl.text.trim();
    draft.title = title.isEmpty ? _defaultTitle(store, draft) : title;

    Navigator.of(context).pop(FormResult(
      draft,
      frequency: widget.mode == FormMode.recurring ? _frequency : null,
      saveAsTemplate: _saveTemplate,
    ));
  }

  String get _heading {
    switch (widget.mode) {
      case FormMode.transaction:
        return widget.isEditing ? 'Edit Transaksi' : 'Catat ${_type.label}';
      case FormMode.recurring:
        return widget.isEditing ? 'Edit Transaksi Berulang' : 'Transaksi Berulang';
      case FormMode.template:
        return widget.isEditing ? 'Edit Template' : 'Template Baru';
    }
  }

  // ------------------------------------------------------------ pemilih (gaya Money Manager)

  String _categoryLabel() {
    final c = store.categoryById(_categoryId);
    if (c == null) return '';
    final pid = c.parentId;
    final p = pid == null ? null : store.categoryById(pid);
    return p == null ? c.name : '${p.name} / ${c.name}';
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
      _error = null;
    });
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

  @override
  Widget build(BuildContext context) {
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
                  tooltip: 'Tutup',
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
                    DateFormat('EEE, dd/MM/yyyy', 'id_ID').format(_date)),
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
                      // Selesai isi nominal -> langsung pilih kategori.
                      onSubmitted: (_) {
                        if (!isTransfer) _pickCategory();
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
                        prefixText: '${currencySymbol(_fromCur)} ',
                        prefixStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: accent),
                        hintText: '0',
                        hintStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: accent.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kalkulator',
                    visualDensity: VisualDensity.compact,
                    onPressed: _openCalculator,
                    icon: Icon(Icons.calculate_rounded, color: accent),
                  ),
                ],
              ),
            ),
            if (!isTransfer)
              FormRow(
                label: 'Kategori',
                accent: accent,
                onTap: _pickCategory,
                child: FormValue(_categoryId == null ? null : _categoryLabel(),
                    placeholder: 'Pilih kategori'),
              ),
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
                    prefixText: '${currencySymbol(_toCur)} ',
                    helperText: 'Otomatis dari kurs, ubah kalau beda.',
                  ),
                ),
              ),
            if (mode == FormMode.transaction && store.events.isNotEmpty)
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
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  hintText: 'Opsional, misal "Nasi padang"',
                ),
              ),
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
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  hintText: 'Opsional',
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
              label: widget.isEditing ? 'Simpan Perubahan' : 'Simpan',
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
                      tooltip: 'Kembali',
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
                    tooltip: 'Tutup',
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
                  tooltip: 'Tutup',
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
