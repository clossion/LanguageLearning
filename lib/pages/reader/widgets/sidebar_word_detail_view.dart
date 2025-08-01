import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/pages/reader/widgets/content_screen.dart';
import 'package:frontend/pages/reader/widgets/reader_sidebar.dart';
import 'package:frontend/services/vocabulary_service.dart';
import 'package:frontend/services/service_provider.dart';
import 'package:frontend/utils/word_utils.dart';
import 'package:frontend/pages/reader/controller/reader_state.dart';
import 'package:frontend/pages/reader/controller/reader_provider.dart';

class SidebarWordDetailView extends ConsumerStatefulWidget {
  final WordInfo word;
  const SidebarWordDetailView({super.key, required this.word});

  @override
  _SidebarWordDetailViewState createState() => _SidebarWordDetailViewState();
}

class _SidebarWordDetailViewState extends ConsumerState<SidebarWordDetailView> {
  // 自定义释义相关状态
  List<String> userMeanings = [];
  List<bool> isEditing     = [];
  List<bool> isHovering    = [];
  bool _loadedMeanings     = false;
  bool _isInitializing = false;
  bool _disposed = false;
  String? _lastQueriedText;

  late CaseMode _caseMode;

  // 捕捉 TextField 失焦
  final FocusScopeNode _focusScope = FocusScopeNode();

  // 缓存一次字典请求
  Future<Map<String, dynamic>?>? _dictFuture;
  bool _initialised = false;    

  // initState 里不要碰 InheritedWidget
  @override
  void initState() {
    super.initState();
    _caseMode = CaseMode.lower;      // 先给一个默认值
  }

  /// 依赖发生变化（或第一次 attach）时调用——此时可以安全访问 InheritedWidget
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;

    final cleaned = cleanWord(widget.word.text);
    _dictFuture =
        _getWordDefinition(context, cleaned);      // 首次查词
    _caseMode = ServiceProvider.of(context)
        .vocabularyService.caseMode;               // 读取当前大小写模式
    _initialised = true;
  }  



  @override
  void dispose() {
    _disposed = true;
    _focusScope.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SidebarWordDetailView old) {
    super.didUpdateWidget(old);
    if (old.word.text != widget.word.text) {
      // 重置状态，但不立即初始化
      setState(() {
        _loadedMeanings = false;
        _isInitializing = false;
        userMeanings.clear();
        isEditing.clear();
        isHovering.clear();
      });
      
      // 延迟初始化，确保 build 完成
      Future.delayed(Duration.zero, () {
        if (mounted && !_disposed) {
          _initMeanings();
        }
      });
    }
  }

    // 修改初始化方法
  Future<void> _initMeanings() async {
    if (_disposed || _loadedMeanings || _isInitializing) return;
    
    if (!mounted) return;
    setState(() => _isInitializing = true);
    
    try {
      final vocab = ServiceProvider.of(context).vocabularyService;
      final cleaned = cleanWord(widget.word.text);

      // 添加超时处理
      final entry = await vocab.fetchSingleMeaning(cleaned)
          .timeout(Duration(seconds: 5));

      if (_disposed || !mounted) return;

      final saved = (entry != null && entry['meaning'] != null)
          ? entry['meaning'] as String
          : '';
      final parts = saved.isEmpty ? <String>[] : saved.split(';');

      setState(() {
        if (parts.isEmpty) {
          userMeanings = [''];
          isEditing    = [true];
          isHovering   = [false];
        } else {
          userMeanings = List<String>.from(parts);
          isEditing    = List<bool>.filled(userMeanings.length, false, growable: true);
          isHovering   = List<bool>.filled(userMeanings.length, false, growable: true);
        }
        _loadedMeanings = true;
        _isInitializing = false;
      });
    } catch (e) {
      debugPrint('初始化释义出错: $e');
      if (!_disposed && mounted) {
        setState(() {
          userMeanings = [''];
          isEditing    = [true];
          isHovering   = [false];
          _loadedMeanings = true;
          _isInitializing = false;
        });
      }
    }
  }

  // 保存所有释义到后端
  Future<void> _saveAllMeanings() async {
    if (!mounted) return;  // 添加这行检查
    
    final vocab = ServiceProvider.of(context).vocabularyService;
    final list = userMeanings.where((s) => s.trim().isNotEmpty).toList();
    final key    = cleanWord(widget.word.text);
    final dbWord = vocab.getDisplayForm(key);
    await vocab.saveUserMeaning(dbWord, list.join(';'));
  }

  // 获取词典数据 (缓存)
  Future<Map<String, dynamic>?> _getWordDefinition(BuildContext ctx, String word) async {
    try {
      // 确保使用正确的单词文本
      final selectedText = ref.watch(contentSelectedWordTextProvider);
      final textToUse = selectedText != null && cleanWord(selectedText) == cleanWord(word) 
          ? selectedText : word;
      
      final vocab = ServiceProvider.of(ctx).vocabularyService;
      
      // 检查缓存
      if (vocab.selectedWord == textToUse && vocab.selectedWordInfo != null) {
        return vocab.selectedWordInfo;
      }
      
      // 查询词典
      await vocab.lookupWord(textToUse);
      return vocab.selectedWordInfo;
    } catch (e) {
      debugPrint('查询词典出错: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vocab = ServiceProvider.of(context).vocabularyService;

    final selectedText = ref.watch(contentSelectedWordTextProvider);

    final cleanedWord = cleanWord(widget.word.text);
    final currentTextToUse = selectedText != null && cleanWord(selectedText) == cleanedWord 
        ? selectedText : cleanedWord;

    // 检查是否需要重新查询词典
    if (_dictFuture == null || _lastQueriedText != currentTextToUse) {
      _dictFuture = _getWordDefinition(context, currentTextToUse);
      _lastQueriedText = currentTextToUse;
    }

    // 只在组件首次构建且未初始化时触发
    if (!_loadedMeanings && !_isInitializing && mounted) {
      // 使用 microtask 避免在 build 期间调用 setState
      Future.microtask(() {
        if (mounted && !_disposed && !_loadedMeanings && !_isInitializing) {
          _initMeanings();
        }
      });
    }

    // 显示加载状态
    if (_isInitializing) {
      return Container(
        color: Colors.grey[50],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('加载中...'),
            ],
          ),
        ),
      );
    }
    final displayWord = applyCase(cleanedWord, _caseMode);
    final boxWidth = MediaQuery.of(context).size.width * 0.8;

    return FocusScope(
      node: _focusScope,
      child: Container(
        color: Colors.grey[50],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // —— 头部：发音 + 单词 + 音标 —— //
            _buildHeader(vocab, displayWord),

            const SizedBox(height: 16),

            // —— 自定义释义 区域 —— //
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('我的释义', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(userMeanings.length, (i) {
                      if (isEditing[i]) {
                        // 编辑模式
                        return SizedBox(
                          width: boxWidth,
                          child: TextField(
                            autofocus: true,
                            controller: TextEditingController()..text = userMeanings[i],
                            onSubmitted: (v) {
                              setState(() {
                                isEditing[i]    = false;
                                userMeanings[i] = v;
                                if (v.trim().isEmpty) {
                                  userMeanings.removeAt(i);
                                  isEditing.removeAt(i);
                                  isHovering.removeAt(i);
                                }
                                if (userMeanings.isEmpty) {
                                  userMeanings = [''];
                                  isEditing    = [true];
                                  isHovering   = [false];
                                }
                              });
                              _saveAllMeanings();
                            },
                            onEditingComplete: () => _focusScope.unfocus(),
                            onTapOutside: (_) {
                              setState(() => isEditing[i] = false);
                              if (userMeanings[i].trim().isEmpty) {
                                userMeanings.removeAt(i);
                                isEditing.removeAt(i);
                                isHovering.removeAt(i);
                              }
                              if (userMeanings.isEmpty) {
                                userMeanings = [''];
                                isEditing    = [true];
                                isHovering   = [false];
                              }
                              _saveAllMeanings();
                            },
                            decoration: const InputDecoration(
                              hintText: '在这里输入新的释义',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        );
                      } else {
                        // 展示模式
                        return MouseRegion(
                          onEnter: (_) => setState(() => isHovering[i] = true),
                          onExit:  (_) => setState(() => isHovering[i] = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            width: boxWidth,
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isHovering[i] ? Colors.grey[100] : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => isEditing[i] = true),
                                    child: Text(userMeanings[i]),
                                  ),
                                ),
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: isHovering[i] ? 1 : 0,
                                  child: Material(
                                    color: Colors.white,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        setState(() {
                                          userMeanings.removeAt(i);
                                          isEditing.removeAt(i);
                                          isHovering.removeAt(i);
                                          if (userMeanings.isEmpty) {
                                            userMeanings = [''];
                                            isEditing    = [true];
                                            isHovering   = [false];
                                          }
                                        });
                                        _saveAllMeanings();
                                      },
                                      child: const SizedBox(width: 24, height: 24, child: Icon(Icons.close, size: 16)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: isHovering[i] ? 1 : 0,
                                  child: Material(
                                    color: Colors.white,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        setState(() {
                                          userMeanings.insert(i + 1, '');
                                          isEditing.insert(i + 1, true);
                                          isHovering.insert(i + 1, false);
                                        });
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          _focusScope.requestFocus();
                                        });
                                      },
                                      child: const SizedBox(width: 24, height: 24, child: Icon(Icons.add, size: 16)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // —— 词典释义 区域 —— //
            Expanded(
              child: FutureBuilder<Map<String, dynamic>?>(

                future: _dictFuture,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final info = snap.data;
                  if (info == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('释义', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (info['definition'] != null)
                            Text(info['definition'], style: const TextStyle(fontSize: 15)),
                          if (info['translation'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(info['translation'], style: const TextStyle(fontSize: 15)),
                            ),
                          if (info['exchange'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text('相关短语：${info['exchange']}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                            ),
                          if (info['examples'] != null) ...[
                            const SizedBox(height: 16),
                            const Text('例句', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                              child: _buildExamples(info['examples'].toString()),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // —— 底部：设置熟练度 —— //
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // —— 大小写按钮行 —— //
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCaseButton(CaseMode.lower, 'abc'),
                      _buildCaseButton(CaseMode.capitalized, 'Abc'),
                      _buildCaseButton(CaseMode.upper, 'ABC'),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // —— 熟练度&废弃/熟练 行（保持等宽） —— //
                  Row(
                    children: [
                      Expanded(child: _buildActionButton(
                        context, ref, widget.word, 0,
                        Colors.red.shade100, Icons.delete, '废弃')),
                      for (int lvl = 1; lvl <= 4; lvl++)
                        Expanded(child: _buildFamiliarityButton(
                          context, ref, widget.word, lvl)),
                      Expanded(child: _buildActionButton(
                        context, ref, widget.word, 5,
                        Colors.green.shade100, Icons.check, '熟练')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 头部：左发音，右单词+音标
  Widget _buildHeader(VocabularyService vocab, String displayWord) {
    final phon = vocab.selectedWordInfo?['phonetic']?.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () {
              // 使用单词学习推荐语速0.5，添加性别参数
              ServiceProvider.of(context).ttsService.speakText(
                displayWord, 
                lang: 'en', 
                speed: 0.8,
                gender: 'female'  // 默认使用女声
              );
            },
            tooltip: '发音',
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayWord, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
              if (phon != null) ...[
                const SizedBox(height: 2),
                Text('/$phon/', style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaseButton(CaseMode mode, String label) {
    final vocab = ServiceProvider.of(context).vocabularyService;
    final bool selected = vocab.caseMode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? Colors.blue.shade100 : null,
          side: BorderSide(
              color: selected ? Colors.blue : Colors.grey.shade400),
          minimumSize: const Size(40, 30),
          padding: EdgeInsets.zero,
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? Colors.blue : Colors.black87)),
        onPressed: () {
          vocab.setCaseMode(mode);                // 更新服务
          setState(() {
            _caseMode = mode;                     // 更新本地
            final cleaned = cleanWord(widget.word.text);
            _dictFuture =
                _getWordDefinition(context, applyCase(cleaned, mode));
          });
        },
      ),
    );
  }

  // 构建熟练度按钮 1-4
  Widget _buildFamiliarityButton(
      BuildContext context,
      WidgetRef ref,
      WordInfo word,
      int level,
  ) {
    final isSelected = word.familiarity == level;
    final isNewWord  = word.familiarity == -1;
    final vocab      = ServiceProvider.of(context).vocabularyService;
    final colors = {
      0: Colors.red.shade300,
      1: Colors.amber.shade500,
      2: Colors.amber.shade300,
      3: Colors.amber.shade100,
      4: Colors.grey.shade200,
      5: Colors.green.shade300,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        onPressed: () async {
          // 保存当前选中的单词ID和文本
          final currentWordId = widget.word.id;
          final currentWordText = widget.word.text;
          
          // 先查词，拿到标准形式
          final cleanedWord = cleanWord(currentWordText);

          // 使用精确更新模式，传入文本参数
          ref.read(readerProvider.notifier).updateWordLevel(
            currentWordId, 
            level,
            wordText: currentWordText
          );
          
          // 确保选中状态不变
          ref.read(selectedWordIdProvider.notifier).state = currentWordId;
          
          // 更新后端
          await vocab.updateWordLevel(cleanedWord, level);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isNewWord && !isSelected
              ? Colors.blue.shade100
              : isSelected
                  ? colors[level]
                  : Colors.grey[200],
          foregroundColor: isSelected ? Colors.black : Colors.grey[600],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: isSelected
                ? const BorderSide(color: Colors.blue, width: 2)
                : BorderSide.none,
          ),
          minimumSize: const Size(0, 40),
          padding: EdgeInsets.zero,
        ),
        child: Text('$level'),
      ),
    );
  }

  // 0 和 5 级按钮
  Widget _buildActionButton(
    BuildContext context,
    WidgetRef ref,
    WordInfo word,
    int level,
    Color? backgroundColor,
    IconData icon,
    String tooltip,
  ) {
    final isSelected = word.familiarity == level;
    final vocab      = ServiceProvider.of(context).vocabularyService;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        onPressed: () async {
          // 保存当前选中的单词ID和文本
          final currentWordId = widget.word.id;
          final currentWordText = widget.word.text;
          
          // 直接使用cleanWord处理单词，不查询API
          final cleanedWord = cleanWord(currentWordText);
          
          // 使用精确更新模式，传入文本参数
          ref.read(readerProvider.notifier).updateWordLevel(
            currentWordId, 
            level,
            wordText: currentWordText
          );
          
          // 确保选中状态不变
          ref.read(selectedWordIdProvider.notifier).state = currentWordId;
          
          // 直接使用cleanWord结果更新后端
          await vocab.updateWordLevel(cleanedWord, level);
          
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? backgroundColor : Colors.grey[200],
          foregroundColor: isSelected ? Colors.black : Colors.grey[600],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: isSelected
                ? const BorderSide(color: Colors.blue, width: 2)
                : BorderSide.none,
          ),
          minimumSize: const Size(0, 40),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon),
      ),
    );
  }

  // 渲染例句
  Widget _buildExamples(String examples) {
    final lines = examples
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return SelectableText.rich(
      TextSpan(
        children: lines.map((line) {
          final isEn = RegExp(r'^[A-Za-z]').hasMatch(line);
          return TextSpan(
            text: '$line\n\n',
            style: TextStyle(fontSize: 14, fontStyle: isEn ? FontStyle.italic : FontStyle.normal),
          );
        }).toList(),
      ),
    );
  }
}
