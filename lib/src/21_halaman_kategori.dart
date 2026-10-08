part of '../main.dart';

// =============================================================================
// HALAMAN: KATEGORI
// =============================================================================

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Kategori',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
            backgroundColor: C.bg,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            bottom: TabBar(
              labelColor: C.accentDark,
              indicatorColor: C.accentDark,
              tabs: [Tab(text: 'Pengeluaran'), Tab(text: 'Pemasukan')],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              final idx = DefaultTabController.of(context).index;
              showSheet<void>(
                  context,
                  CategoryEditorSheet(
                      store: store,
                      type: idx == 0 ? TxType.expense : TxType.income));
            },
            backgroundColor: C.accentDark,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Kategori baru'),
          ),
          body: ListenableBuilder(
            listenable: store,
            builder: (context, _) => TabBarView(
              children: [
                _list(context, TxType.expense),
                _list(context, TxType.income),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _list(BuildContext context, TxType type) {
    final tops = store.topCategories(type);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        for (final c in tops) ...[
          _row(context, c, false),
          for (final s in store.childrenOf(c.id)) _row(context, s, true),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, TxCategory c, bool isChild) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: isChild ? 28 : 0),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: () => showSheet<void>(context,
            CategoryEditorSheet(store: store, type: c.type, category: c)),
        child: Row(
          children: [
            if (isChild)
              Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.subdirectory_arrow_right_rounded,
                    color: C.muted, size: 18),
              ),
            CatIcon(icon: c.iconData, color: c.colorValue, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(c.name,
                  style: TextStyle(
                      fontWeight: isChild ? FontWeight.w600 : FontWeight.w800)),
            ),
            Icon(Icons.edit_rounded, size: 18, color: C.muted),
          ],
        ),
      ),
    );
  }
}

class CategoryEditorSheet extends StatefulWidget {
  const CategoryEditorSheet(
      {super.key, required this.store, required this.type, this.category});
  final AppStore store;
  final TxType type;
  final TxCategory? category;

  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  AppStore get store => widget.store;
  final _nameCtrl = TextEditingController();
  late String _icon;
  late int _color;
  String? _parentId;
  String? _error;

  bool get _editing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _nameCtrl.text = c?.name ?? '';
    _icon = c?.icon ?? 'other';
    _color = c?.color ?? kPalette[3];
    _parentId = c?.parentId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nama kategori wajib diisi.');
      return;
    }
    store.upsertCategory(TxCategory(
      id: widget.category?.id ?? store.newId(),
      name: name,
      type: widget.type,
      icon: _icon,
      color: _color,
      parentId: _parentId,
    ));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final c = widget.category!;
    final ok = await confirmDialog(context,
        title: 'Hapus kategori?',
        message: 'Kategori "${c.name}" akan dihapus.',
        confirmLabel: 'Hapus',
        destructive: true);
    if (!ok || !mounted) return;
    final err = store.deleteCategory(c.id);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final selfId = widget.category?.id;
    final hasChildren =
        selfId != null && store.childrenOf(selfId).isNotEmpty;
    final parents = store
        .topCategories(widget.type)
        .where((c) => c.id != selfId)
        .toList();
    return SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CatIcon(icon: iconOf(_icon), color: Color(_color), size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    _editing
                        ? 'Edit Kategori'
                        : 'Kategori ${widget.type.label} Baru',
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: fieldDeco('Nama kategori', icon: Icons.label_rounded),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: SmallLabel('Induk kategori')),
              DropdownButton<String?>(
                value: _parentId,
                borderRadius: BorderRadius.circular(16),
                onChanged: hasChildren
                    ? null
                    : (v) => setState(() => _parentId = v),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Tidak ada (utama)')),
                  for (final p in parents)
                    DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
                ],
              ),
            ],
          ),
          if (hasChildren)
            Text('Kategori ini punya sub-kategori, jadi tetap kategori utama.',
                style: TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 14),
          const SmallLabel('Ikon'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in kIcons.entries)
                Semantics(
                  button: true,
                  selected: e.key == _icon,
                  label: e.key,
                  child: GestureDetector(
                    onTap: () => setState(() => _icon = e.key),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: e.key == _icon
                            ? Color(_color).withValues(alpha: 0.18)
                            : C.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: e.key == _icon
                                ? darken(Color(_color))
                                : C.line,
                            width: e.key == _icon ? 2 : 1),
                      ),
                      child: Icon(e.value,
                          color: e.key == _icon
                              ? darken(Color(_color))
                              : C.muted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const SmallLabel('Warna'),
          const SizedBox(height: 8),
          _ColorPicker(
              selected: _color, onSelected: (c) => setState(() => _color = c)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBox(_error!),
          ],
          const SizedBox(height: 16),
          PrimaryButton(label: 'Simpan Kategori', onPressed: _save),
          if (_editing) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: C.redDark),
              icon: const Icon(Icons.delete_rounded),
              label: const Text('Hapus kategori'),
            ),
          ],
        ],
      ),
    );
  }
}
