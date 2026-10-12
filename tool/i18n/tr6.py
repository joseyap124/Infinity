# -*- coding: utf-8 -*-
T = []
def t(i, en, zh): T.append((i, en, zh))
# v4.3 notifikasi bertombol
t('Transaksi terdeteksi', 'Transaction detected', '检测到交易')
t('Dicatat saat Infinity dibuka.', 'Recorded when Infinity is opened.', '打开 Infinity 时记录。')
t('{0} transaksi dicatat dari tombol notifikasi ✅', '{0} transactions recorded from notification buttons ✅', '已根据通知按钮记录 {0} 笔交易 ✅')
t('{0} dicatat otomatis, {1} dari tombol notifikasi, {2} menunggu dicek.', '{0} recorded automatically, {1} from notification buttons, {2} waiting to be checked.', '自动记录 {0} 笔，通知按钮记录 {1} 笔，{2} 笔待确认。')
t('Notifikasi dengan tombol', 'Notifications with buttons', '带按钮的通知')
t('Saat notifikasi bank atau e-wallet terdeteksi, Infinity memunculkan notifikasi dengan tombol Keluar, Masuk, dan Abaikan. Pilihanmu dicatat begitu Infinity dibuka berikutnya.',
  'When a bank or e-wallet notification is detected, Infinity shows a notification with Out, In and Ignore buttons. Your choice is recorded the next time Infinity is opened.',
  '检测到银行或电子钱包通知时，Infinity 会弹出带有“支出”“收入”“忽略”按钮的通知。你的选择会在下次打开 Infinity 时记录。')
