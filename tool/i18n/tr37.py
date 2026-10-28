# -*- coding: utf-8 -*-
T = []
def t(i, en, zh): T.append((i, en, zh))
# 6.8.0: jatah 0 dijelaskan
t('Jatah hari ini', 'Today\'s allowance', '今日额度')
t('Anggaran periode ini sudah terpakai {0}%. Jatah harian kembali saat periode baru, {1}.', 'This period\'s budget is {0}% used. Your daily allowance returns when the new period starts, {1}.', '本期预算已用 {0}%。新一期开始({1})后,每日额度会恢复。')
t('Sisa anggaran sudah dicadangkan untuk tagihan, cicilan, atau anggaran khusus. Ketuk untuk rincian.', 'What is left of the budget is already set aside for bills, installments, or the special budget. Tap for details.', '剩余预算已预留给账单、分期或专项预算。点按查看明细。')
