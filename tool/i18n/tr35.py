# -*- coding: utf-8 -*-
T = []
def t(i, en, zh): T.append((i, en, zh))
# 6.4.0: di luar jatah harian
t('Di luar jatah harian', 'Outside daily allowance', '不计入每日额度')
t('Tetap tercatat. Jatah hari ini tidak dilewati, jatah besok menyesuaikan.', 'Still recorded. Does not push today past your allowance; tomorrow adjusts.', '仍会记录。不会让今天超额,明天的额度会相应调整。')
t('Belanja khusus {0}. Di luar jatah hari ini, jatah besok menyesuaikan.', 'Special spending {0}. Outside today\'s allowance; tomorrow adjusts.', '特殊支出 {0}。不计入今天额度,明天额度会调整。')
t('Belanja khusus hari ini {0} tidak dihitung ke jatah hari ini. Jatah besok menyesuaikan.', 'Special spending today ({0}) is not counted in today\'s allowance. Tomorrow adjusts.', '今天的特殊支出 ({0}) 不计入今天额度,明天额度会调整。')
t('Beli sesuatu yang disengaja, apa harus membuat hari itu "lewat jatah"?', 'If I buy something on purpose, does that day have to count as over my allowance?', '特意买东西,当天也一定要算“超额”吗?')
t('Tidak. Di form Catat pengeluaran, nyalakan "Di luar jatah harian". Transaksinya tetap tercatat dan tetap mengurangi sisa anggaran, tapi tidak dihitung ke jatah hari itu dan tidak membuat maskot berubah jadi Boros. Karena uangnya memang keluar, jatah hari-hari berikutnya turun sedikit, dibagi ke sisa hari.', 'No. In the expense form, turn on "Outside daily allowance". The transaction is still recorded and still reduces your remaining budget, but it is not counted toward that day\'s allowance and does not turn the mascot to Overspent. Because the money did leave, the allowance for the following days drops a little, spread over the remaining days.', '不会。在支出表单里打开“不计入每日额度”。这笔交易仍会记录并减少剩余预算,但不计入当天额度,也不会让吉祥物变成“超支”。因为钱确实花出去了,之后几天的额度会稍微降低,平摊到剩余天数。')
