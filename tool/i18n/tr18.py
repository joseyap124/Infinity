# -*- coding: utf-8 -*-
T = []
def t(i, en, zh): T.append((i, en, zh))
# 5.2.0: Statistik dan Rencana lebih ringan
t('minggu lalu', 'last week', '上周')
t('bulan lalu', 'last month', '上月')
t('tahun lalu', 'last year', '去年')
t('Sama seperti {0}', 'Same as {0}', '与{0}持平')
t('{0}% lebih hemat dari {1}', '{0}% less than {1}', '比{1}少花{0}%')
t('{0}% lebih boros dari {1}', '{0}% more than {1}', '比{1}多花{0}%')
t('Rata-rata/hari', 'Average/day', '日均')
t('Simpan atau kirim laporan bulan ini', 'Save or send this month\'s report', '保存或发送本月报告')
t('Gambar ringkas untuk dikirim', 'A short picture to send', '可发送的简要图片')
t('Tren', 'Trend', '趋势')
t('Aset', 'Assets', '资产')
t('{0} saran untuk bulan ini', '{0} tips for this month', '本月有 {0} 条建议')
