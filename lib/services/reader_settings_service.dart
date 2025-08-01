import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读器设置服务，用于管理字体大小、背景颜色等设置
class ReaderSettingsService {
  // 默认字体大小
  double _fontSize = 16.0;
  // 默认背景颜色
  Color _backgroundColor = Colors.white;
  // 默认字体
  String _fontFamily = 'System';
  // 默认是否固定行高
  final bool _fixedLineHeight = false;// 改为默认启用
  // 默认行高比例
  double _lineHeight = 1.5;

  // Getter
  double get fontSize => _fontSize;
  Color get backgroundColor => _backgroundColor;
  String get fontFamily => _fontFamily;
  bool get fixedLineHeight => _fixedLineHeight;
  double get lineHeight => _lineHeight;

  /// 根据字体大小计算最佳行高比例
  double getIdealLineHeight(double fontSize) {
    if (fontSize <= 14) return 1.5;
    if (fontSize <= 18) return 1.35; 
    if (fontSize <= 24) return 1.25; 
    return 1.2;
  }

  /// 加载保存的设置
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _fontSize = prefs.getDouble('reader_font_size') ?? 16.0;
      final colorValue = prefs.getInt('reader_background_color');
      _backgroundColor = colorValue != null ? Color(colorValue) : Colors.white;
      _fontFamily = prefs.getString('reader_font_family') ?? 'System';
      _lineHeight = prefs.getDouble('reader_line_height') ?? getIdealLineHeight(_fontSize); // 使用计算的理想行高
    } catch (e) {
      debugPrint('读取设置出错: $e');
      // 使用默认值
      _lineHeight = getIdealLineHeight(_fontSize); // 确保即使出错也应用理想行高
    }
  }

  /// 保存设置
  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setDouble('reader_font_size', _fontSize);
      await prefs.setInt('reader_background_color', _backgroundColor.value);
      await prefs.setString('reader_font_family', _fontFamily);
      await prefs.setBool('reader_fixed_line_height', _fixedLineHeight);
      await prefs.setDouble('reader_line_height', _lineHeight);
    } catch (e) {
      debugPrint('保存设置出错: $e');
    }
  }

  // 移除 fixedLineHeight 相关的代码，所有行高都自动按照字号调整

  Future<void> updateAllSettings({
    double? fontSize,
    Color? backgroundColor,
    String? fontFamily,
    double? lineHeight,
  }) async {
    if (fontSize != null) {
      _fontSize = fontSize;
      
      // 如果没有明确设置行高，计算理想行高
      if (lineHeight == null) {
        _lineHeight = getIdealLineHeight(fontSize);
      }
    }
    
    if (backgroundColor != null) _backgroundColor = backgroundColor;
    if (fontFamily != null) _fontFamily = fontFamily;
    if (lineHeight != null) _lineHeight = lineHeight;
    
    await saveSettings();
  }
}