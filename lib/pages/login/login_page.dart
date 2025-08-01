import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../main.dart'; // 修改路径，向上两级到根目录
import '../../utils/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  String username = '';
  String errorMessage = '';
  bool isLoading = false;

  double overlayOpacity = 0.0; // 遮罩透明度
  double formOpacity = 0.0; // 表单透明度

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // 初始化滑入动画
    _slideController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3), // 从下往上滑（y轴偏移 0.3）
      end: Offset(0, 0),
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _startAnimationSequence();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _startAnimationSequence() async {
    await Future.delayed(Duration(seconds: 1));
    setState(() => overlayOpacity = 1.0);

    await Future.delayed(Duration(milliseconds: 1500));
    setState(() => formOpacity = 1.0);
    _slideController.forward(); // 表单滑入开始
  }

  Future<void> _handleLogin() async {
    if (username.isEmpty) {
      setState(() => errorMessage = '请输入用户名');
      return;
    }
    setState(() {
      errorMessage = '';
      isLoading = true;
    });
    try {
      final response = await http.post(
        Uri.parse('$API_BASE/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      );
      final data = decodeJson(response);
      if (response.statusCode == 200 && data['status'] == 'ok') {
        currentUserId = data['user_id'].toString(); // 登录、注册两个地方都要改
        // ignore: use_build_context_synchronously
        Navigator.pushReplacementNamed(context, '/library'); // 改为跳转到library页面
      } else {
        setState(() => errorMessage = '用户不存在，请先注册');
      }
    } catch (e) {
      setState(() => errorMessage = '登录失败：$e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (username.isEmpty) {
      setState(() => errorMessage = '请输入用户名');
      return;
    }
    setState(() {
      errorMessage = '';
      isLoading = true;
    });
    try {
      final response = await http.post(
        Uri.parse('$API_BASE/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      );
      final data = decodeJson(response);
      if (response.statusCode == 200 && data['status'] == 'ok') {
        currentUserId = data['user_id'].toString();
        // ignore: use_build_context_synchronously
        Navigator.pushReplacementNamed(context, '/library'); // 改为跳转到library页面
      } else {
        setState(() => errorMessage = '注册失败，请重试');
      }
    } catch (e) {
      setState(() => errorMessage = '注册失败：$e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/Login.png', fit: BoxFit.cover),
          // 遮罩带动画
          AnimatedOpacity(
            opacity: overlayOpacity,
            duration: Duration(seconds: 1),
            child: Container(color: Colors.black45),
          ),
          // 表单带动画
          AnimatedOpacity(
            opacity: formOpacity,
            duration: Duration(seconds: 1),
            child: Center(
              child: SlideTransition(
                position: _slideAnimation, // 滑动动画
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '我的应用',
                        style: TextStyle(fontSize: 32, color: Colors.white),
                      ),
                      SizedBox(height: 20),
                      Container(
                        width: 300,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white70,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          onChanged: (val) => username = val,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '输入用户名',
                          ),
                        ),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        SizedBox(height: 10),
                        Text(errorMessage, style: TextStyle(color: Colors.red)),
                      ],
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: isLoading ? null : _handleLogin,
                            child: Text('登录'),
                          ),
                          SizedBox(width: 20),
                          ElevatedButton(
                            onPressed: isLoading ? null : _handleRegister,
                            child: Text('注册'),
                          ),
                        ],
                      ),
                      if (isLoading) ...[
                        SizedBox(height: 20),
                        CircularProgressIndicator(color: Colors.white),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
