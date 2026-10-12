# Alat terjemahan (v4.2)

Kamus EN/ZH ditulis di `trN.py` (`t('teks Indonesia','English','中文')`, isian `{0}` harus sama).
`python3 gen.py tr1 tr2 tr3 tr4 tr5` membuat ulang `lib/src/48_terjemahan_en.dart` dan `49_terjemahan_zh.dart`.
`missing.py 13,32` menampilkan teks di file bernomor itu yang belum ada di kamus.
Skrip ini mengacu ke `/tmp/claude-0/i18n` untuk import; sesuaikan `sys.path` kalau dipindah.
