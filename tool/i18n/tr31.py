# -*- coding: utf-8 -*-
T = []
def t(i, en, zh): T.append((i, en, zh))
# 5.13.0: salinan harian di HP
t('Pulihkan versi ini?', 'Restore this version?', '恢复此版本？')
t('versi {0}', 'version {0}', '{0} 的版本')
t('Versi harian di HP', 'Daily versions on this phone', '手机上的每日版本')
t('Infinity menyimpan salinan terkunci sekali sehari di dalam app ({0} hari terakhir). Dipakai kalau data tiba-tiba kembali ke kondisi lama. Salinan ikut hilang kalau app di-uninstall; untuk itu pakai backup di Download.',
  'Infinity keeps one locked copy per day inside the app (last {0} days). Use it if your data suddenly goes back to an older state. The copies are lost if the app is uninstalled; for that, use the backups in Downloads.',
  'Infinity 每天在应用内保存一份加密副本（最近 {0} 天）。如果数据突然回到旧状态，可以用它恢复。卸载应用后这些副本会消失；那种情况请使用“下载”里的备份。')
t('{0} transaksi, {1} kantong', '{0} transactions, {1} accounts', '{0} 笔交易，{1} 个账户')
t('Salinan terlalu pendek', 'The copy is too short', '副本太短')
t('Salinan tidak bisa dibuka', 'The copy could not be opened', '无法打开副本')
