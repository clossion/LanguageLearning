// 保留原来的 cleanWord，不要动 —— 它仍负责
// ① 去掉首尾符号与空白 ② 统一转成小写
String cleanWord(String word) {
  if (word.isEmpty) return word;
  var cleaned = word.trim();
  cleaned = cleaned.replaceAll(RegExp(r'^[^\w]+'), '');
  cleaned = cleaned.replaceAll(RegExp(r'[^\w]+$'), '');
  return cleaned.toLowerCase();                       // ← 保持不变
}

// ============  新增：大小写模式 & 转换 ============

/// 查询 / 显示时用到的大小写模式
enum CaseMode { lower, capitalized, upper }

/// 把 **已 clean 且为小写** 的单词转换成指定大小写形式
String applyCase(String word, CaseMode mode) {
  switch (mode) {
    case CaseMode.capitalized:
      return word.isNotEmpty
          ? word[0].toUpperCase() + word.substring(1)
          : word;
    case CaseMode.upper:
      return word.toUpperCase();
    default:
      return word;            // lower
  }
}
