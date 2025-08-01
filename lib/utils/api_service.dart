// lib/utils/api_service.dart
import 'dart:convert' show jsonDecode, utf8;
import 'package:http/http.dart' as http;

/// 后端所有 JSON 响应统一用这个函数解码，避免 charset 缺省导致的乱码
dynamic decodeJson(http.Response res) =>
    jsonDecode(utf8.decode(res.bodyBytes));

const String API_BASE = 'http://localhost:8000/api';
