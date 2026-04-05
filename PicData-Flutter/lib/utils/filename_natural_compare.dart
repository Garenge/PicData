/// 文件名自然排序：数字子串按数值比较，避免 `10` 排在 `2` 前。
///
/// 使用小写 ASCII 比较非数字段；仅识别连续 ASCII 数字 `0`–`9`。
int compareFilenameNatural(String a, String b) {
  final s1 = a.toLowerCase();
  final s2 = b.toLowerCase();
  var i = 0;
  var j = 0;
  while (i < s1.length && j < s2.length) {
    final c1 = s1.codeUnitAt(i);
    final c2 = s2.codeUnitAt(j);
    final d1 = _isAsciiDigit(c1);
    final d2 = _isAsciiDigit(c2);
    if (d1 && d2) {
      final end1 = _endOfDigitRun(s1, i);
      final end2 = _endOfDigitRun(s2, j);
      final n1 = int.parse(s1.substring(i, end1));
      final n2 = int.parse(s2.substring(j, end2));
      if (n1 != n2) {
        return n1.compareTo(n2);
      }
      final len1 = end1 - i;
      final len2 = end2 - j;
      if (len1 != len2) {
        return len1.compareTo(len2);
      }
      i = end1;
      j = end2;
    } else {
      if (c1 != c2) {
        return c1.compareTo(c2);
      }
      i++;
      j++;
    }
  }
  return s1.length.compareTo(s2.length);
}

bool _isAsciiDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

int _endOfDigitRun(String s, int start) {
  var k = start;
  while (k < s.length && _isAsciiDigit(s.codeUnitAt(k))) {
    k++;
  }
  return k;
}
