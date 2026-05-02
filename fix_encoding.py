import os

# ---- result_screen.dart fix line 106 ----
path3 = 'C:/dev/jpworddb/src/quicktap/lib/result_screen.dart'
data3 = open(path3, 'rb').read()
lines3 = data3.split(b'\n')

lines3[105] = "                        child: const Text('タイトルへ戻る'),\r".encode('utf-8')

open(path3, 'wb').write(b'\n'.join(lines3))
print('result_screen.dart line 106: Done')
