# Alat terjemahan

Kamus EN/ZH ditulis di `trN.py` (`t('teks Indonesia','English','中文')`, isian `{0}` harus sama di ketiganya). Entri baru ditaruh di berkas bernomor berikutnya.

Membuat ulang `lib/src/48_terjemahan_en.dart` dan `49_terjemahan_zh.dart` (jalankan dari folder ini):

```bash
python3 gen.py $(ls tr*.py | sed 's/\.py//' | sort -V | tr '\n' ' ')
```

`missing.py` menampilkan teks di berkas bernomor tertentu yang belum ada di kamus, mis. `python3 missing.py 13,32 tr5 tr6 ...` (argumen kedua dan seterusnya: modul `trN` tambahan). Hasilnya tidak sepenuhnya bisa dipercaya; cara yang lebih aman adalah mencari teks barunya langsung di `tr*.py`.

Skrip lama seperti `enc.py` mengacu ke `/tmp/claude-0/i18n`; skrip itu hanya dipakai saat import awal kamus dan tidak dibutuhkan untuk alur di atas. Alur lengkapnya ada di `docs/TEKNIS.md`.
