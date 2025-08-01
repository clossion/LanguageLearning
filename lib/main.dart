import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/service_provider.dart';
import 'pages/login/login_page.dart';
import 'pages/library/library_page.dart';
import 'pages/reader/subtitles_page.dart';
import 'package:media_kit/media_kit.dart';

// 模拟全局的登录状态（当前登录用户ID）
String? currentUserId;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Tauri App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'NotoSansSC',),
      initialRoute: '/login',
      routes: {
        '/login': (_) => LoginPage(),

        // 书架页不依赖 ServiceProvider，可保持原样
        '/library': (_) => LibraryPage(),
      },
      // 使用 onGenerateRoute 来处理带参数的路由
      onGenerateRoute: (settings) {
        if (settings.name == '/reader') {
          // 先把传进来的 arguments 解包
          final args = settings.arguments as Map<String, dynamic>?;

          // 如果用户未登录，重定向到登录页
          if (currentUserId == null) {
            return MaterialPageRoute(builder: (_) => LoginPage());
          }

          return MaterialPageRoute(
            settings: settings,
            builder: (context) => ServiceProvider.init(
              showMessage: (msg) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg)),
              ),
              userId: currentUserId!,
              // child 下真正渲染 ReaderPage，并把所有参数都传进去
              child: ReaderPage(
                userId:       currentUserId!,
                subtitlePath: args?['subtitlePath'] as String?,
                filePath:     args?['filePath'] as String?,
                type:         args?['type']     as String?,
                title:        args?['title']    as String?,
              ),
            ),
          );
        }
        // 其它命名路由交给 routes 里处理
        return null;
      },
    );
  }
}
