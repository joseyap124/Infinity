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
# 6.5.0: anggaran khusus
t('Anggaran khusus', 'Special budget', '专项预算')
t('Anggaran khusus (di dalam batas total)', 'Special budget (within the total limit)', '专项预算(包含在总额度内)')
t('Anggaran khusus disisihkan', 'Special budget set aside', '已预留专项预算')
t('Anggaran khusus (terpakai melebihi)', 'Special budget (overspent)', '专项预算(已超出)')
t('Habis, lebih {0}', 'Used up, {0} over', '已用完,超出 {0}')
t('Sisa {0} dari {1}', '{0} left of {1}', '剩余 {0} / {1}')
t('Pakai anggaran khusus', 'Use special budget', '使用专项预算')
t('Anggaran khusus habis. Kelebihannya mengurangi jatah mulai besok.', 'Special budget is used up. The excess reduces your allowance from tomorrow.', '专项预算已用完。超出部分会从明天起降低每日额度。')
t('Sisa {0} dari {1}. Tidak menyentuh jatah harian.', '{0} left of {1}. Does not touch your daily allowance.', '剩余 {0} / {1}。不影响每日额度。')
t('Anggaran khusus tidak boleh lebih besar dari batas total, jadi akan dipotong sebesar batas total.', 'The special budget cannot be larger than the total limit, so it will be capped at the total limit.', '专项预算不能大于总额度,将按总额度截断。')
t('Untuk self reward atau barang besar. Belanja yang ditandai "Di luar jatah harian" memakai ini dulu dan tidak menyentuh jatah harian. Kosongkan kalau tidak dipakai.', 'For rewards or big purchases. Spending marked "Outside daily allowance" uses this first and does not touch your daily allowance. Leave empty if unused.', '用于奖励自己或大额购物。标记为“不计入每日额度”的支出会先用它,不影响每日额度。不用请留空。')
t('Jatah harian dihitung dari {0}, di luar anggaran khusus.', 'Daily allowance is calculated from {0}, excluding the special budget.', '每日额度按 {0} 计算,不含专项预算。')
t('Belanja khusus hari ini {0} memakai anggaran khusus dan tidak dihitung ke jatah hari ini.', 'Special spending today ({0}) uses the special budget and is not counted in today\'s allowance.', '今天的特殊支出 ({0}) 使用专项预算,不计入今天额度。')
# 6.6.0: Beranda lebih tenang saat lewat jatah
t('Melewati jatah hari ini', 'Past today\'s allowance', '已超出今日额度')
t('Tercatat. Jatah besok dihitung ulang dari sisa periode.', 'Recorded. Tomorrow\'s allowance is recalculated from what is left in the period.', '已记录。明天的额度会按本期剩余重新计算。')
t('Hari ini lewat jatah. Tercatat, besok mulai lagi ya.', 'Over today\'s allowance. It\'s recorded, let\'s start fresh tomorrow.', '今天超出额度了。已记录,明天重新开始吧。')
t('Hampir habis. Pikir dulu sebelum belanja.', 'Almost gone. Think before you shop.', '快没了。买之前先想一想。')
