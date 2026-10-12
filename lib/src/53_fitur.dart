part of '../main.dart';

// Saklar fitur (v5.0): fitur yang dimatikan disembunyikan dan tidak ikut
// dihitung (cadangan Aman dibelanjakan, saran, notifikasi). Datanya tetap
// tersimpan dan kembali saat dinyalakan.

extension FeatureStore on AppStore {
  bool feature(String id) => settings.feature(id);
  List<Debt> get debtsOn => feature('utang') ? debts : const <Debt>[];
  List<Goal> get goalsOn => feature('target') ? goals : const <Goal>[];
  int get featuresOnCount =>
      kFeatureDefaults.keys.where((k) => settings.feature(k)).length;
}

/// (id, nama, keterangan) berurutan seperti di layar Fitur.
const List<(String, String, String)> kFeatureList = [
  ('cicilan', 'Cicilan', 'Cicilan 0% dan tagihannya'),
  ('utang', 'Utang & Piutang', 'Catatan pinjam dan meminjamkan'),
  ('target', 'Target tabungan', 'Target dan setoran'),
  ('patungan', 'Patungan', 'Bagi tagihan dengan teman'),
  ('acara', 'Acara', 'Kelompokkan pengeluaran per acara'),
  ('tunda', 'Tunda beli', 'Daftar tunggu sebelum membeli'),
  ('bocor', 'Biaya bocor', 'Deteksi biaya kecil yang berulang'),
];

class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          appBar: pageBar('Fitur'),
          body: ListView(
            padding: pagePad(context, 32),
            children: [
              Text(
                  'Matikan fitur yang tidak kamu pakai. Datanya tidak dihapus, dan kembali lagi kalau dinyalakan.',
                  style: TextStyle(fontSize: 13.5, color: C.muted, height: 1.4)),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    for (final (id, name, desc) in kFeatureList)
                      SwitchListTile(
                        value: store.feature(id),
                        onChanged: (v) => store.updateSettings((x) {
                          if (v == (kFeatureDefaults[id] ?? true)) {
                            x.features.remove(id);
                          } else {
                            x.features[id] = v;
                          }
                        }),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14.5)),
                        subtitle: Text(desc,
                            style: TextStyle(fontSize: 12.5, color: C.muted)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                  'Fitur baru (Tunda beli, Biaya bocor) mati bawaannya, kamu yang memilih memakainya. Yang mati juga berhenti dihitung, misalnya cicilan tidak lagi mengurangi "Aman dibelanjakan".',
                  style: TextStyle(fontSize: 12.5, color: C.muted, height: 1.4)),
            ],
          ),
        );
      },
    );
  }
}
