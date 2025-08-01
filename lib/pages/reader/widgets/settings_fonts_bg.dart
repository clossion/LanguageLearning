import 'package:flutter/material.dart';

class FontSettingsDialog extends StatefulWidget {
  final double initialFontSize;
  final Color initialBackgroundColor;
  final double lineHeight;   // 兼容外部调用，内部将重新计算
  final Function(double fontSize, Color backgroundColor, double lineHeight) onSave;

  const FontSettingsDialog({
    super.key,
    required this.initialFontSize,
    required this.initialBackgroundColor,
    required this.lineHeight,
    required this.onSave,
  });

  @override
  _FontSettingsDialogState createState() => _FontSettingsDialogState();
}

class _FontSettingsDialogState extends State<FontSettingsDialog> {
  late double _fontSize;
  late double _lineHeight;
  late Color _backgroundColor;

  /// 字号对应的推荐行高
  double _getIdealLineHeight(double fontSize) {
    if (fontSize <= 14) {
      return 1.4;
    } else if (fontSize <= 18) {
      return 1.2;
    } else if (fontSize <= 24) {
      return 1.0;
    } else {
      return 0.8;
    }
  }

  @override
  void initState() {
    super.initState();
    _fontSize = widget.initialFontSize;
    _lineHeight = _getIdealLineHeight(_fontSize);
    _backgroundColor = widget.initialBackgroundColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('字体与背景设置'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== 字号 =====
            const Text('字号', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _fontSize > 12
                      ? () => setState(() {
                            _fontSize -= 2;
                            _lineHeight = _getIdealLineHeight(_fontSize);
                          })
                      : null,
                ),
                Text(
                  _fontSize.toInt().toString(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _fontSize < 30
                      ? () => setState(() {
                            _fontSize += 2;
                            _lineHeight = _getIdealLineHeight(_fontSize);
                          })
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              '行高：${_lineHeight.toStringAsFixed(2)}（自动）',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 16),

            // ===== 背景颜色 =====
            const Text('背景', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColorOption(Colors.white, '白色'),
                _buildColorOption(Colors.black, '黑色'),
                _buildColorOption(Colors.amber.shade50, '米色'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_fontSize, _backgroundColor, _lineHeight);
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  // ---------- 私有方法 ----------
  Widget _buildColorOption(Color color, String label) {
    final isSelected = _backgroundColor == color;
    return InkWell(
      onTap: () => setState(() => _backgroundColor = color),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.blue : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
