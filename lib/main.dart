import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:ffi';
import 'package:win32/win32.dart' as win32;
import 'package:ffi/ffi.dart';

void main() {
  runApp(const TeaPosswordApp());
}

class TeaPosswordApp extends StatefulWidget {
  const TeaPosswordApp({super.key});

  @override
  State<TeaPosswordApp> createState() => _TeaPosswordAppState();
}

class _TeaPosswordAppState extends State<TeaPosswordApp> {
  bool isDark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tea Possword',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Colors.blue,
          secondary: Colors.lightBlueAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.blueGrey[900],
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          secondary: Colors.lightBlueAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(
        isDark: isDark,
        onThemeSwitch: () => setState(() => isDark = !isDark),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatelessWidget {
  final bool isDark;
  final VoidCallback onThemeSwitch;
  const HomePage({
    super.key,
    required this.isDark,
    required this.onThemeSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tea Possword 密码管理器'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: '主题切换',
            onPressed: onThemeSwitch,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '大黑子工作室出品',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _MainButton(
              icon: Icons.lock,
              label: '进入密码管理',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PasswordManagerPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _MainButton(
              icon: Icons.vpn_key,
              label: '解码器（多端通用文件）',
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const DecoderPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MainButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _MainButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 48,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

class PasswordManagerPage extends StatefulWidget {
  const PasswordManagerPage({super.key});

  @override
  State<PasswordManagerPage> createState() => _PasswordManagerPageState();
}

class _PasswordManagerPageState extends State<PasswordManagerPage> {
  List<Map<String, String>> passwords = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadPasswords();
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/tea_passwords.json');
  }

  Future<void> _loadPasswords() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        setState(() {
          passwords = jsonList.map((item) => Map<String, String>.from(item as Map)).toList();
          loading = false;
        });
      } else {
        setState(() {
          passwords = [];
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        passwords = [];
        loading = false;
      });
    }
  }

  Future<void> _savePasswords() async {
    final file = await _localFile;
    await file.writeAsString(jsonEncode(passwords));
  }

  Future<void> _exportPasswords() async {
    try {
      final savePath = await _selectSavePath();
      if (savePath != null) {
        final file = await _localFile;
        await file.copy(savePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导出成功')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: \$e')));
      }
    }
  }

  Future<void> _importPasswords() async {
    try {
      final importPath = await _selectOpenPath();
      if (importPath != null) {
        final importFile = File(importPath);
        if (await importFile.exists()) {
          final content = await importFile.readAsString();
          final List<dynamic> jsonList = jsonDecode(content);
          if (mounted) {
            setState(() {
              passwords = jsonList.map((item) => Map<String, String>.from(item as Map)).toList();
            });
            await _savePasswords();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入成功')));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: \$e')));
      }
    }
  }

  Future<String?> _selectSavePath() async {
    if (Platform.isWindows) {
      return await _showWindowsSaveDialog();
    }
    return null;
  }

  Future<String?> _selectOpenPath() async {
    if (Platform.isWindows) {
      return await _showWindowsOpenDialog();
    }
    return null;
  }

  Future<String?> _showWindowsSaveDialog() async {
    final fileBuffer = calloc<Uint16>(260);
    final filter = 'JSON文件 (*.json)\u0000*.json\u0000所有文件 (*.*)\u0000*.*\u0000';
    final filterPtr = filter.toNativeUtf16();
    fileBuffer[0] = 0;
    final ofn = calloc<win32.OPENFILENAME>();
    ofn.ref.lStructSize = sizeOf<win32.OPENFILENAME>();
    ofn.ref.lpstrFile = fileBuffer.cast();
    ofn.ref.nMaxFile = 260;
    ofn.ref.lpstrFilter = filterPtr.cast();
    ofn.ref.nFilterIndex = 1;
    ofn.ref.lpstrDefExt = 'json'.toNativeUtf16().cast();
    ofn.ref.lpstrFileTitle = nullptr;
    ofn.ref.Flags = win32.OFN_OVERWRITEPROMPT | win32.OFN_PATHMUSTEXIST;
    ofn.ref.lpstrTitle = '保存密码文件'.toNativeUtf16().cast();
    String? path;
    if (win32.GetSaveFileName(ofn) != 0) {
      path = fileBuffer.cast<Utf16>().toDartString();
    }
    calloc.free(ofn);
    calloc.free(fileBuffer);
    calloc.free(filterPtr);
    return path;
  }

  Future<String?> _showWindowsOpenDialog() async {
    final fileBuffer = calloc<Uint16>(260);
    final filter = 'JSON文件 (*.json)\u0000*.json\u0000所有文件 (*.*)\u0000*.*\u0000';
    final filterPtr = filter.toNativeUtf16();
    fileBuffer[0] = 0;
    final ofn = calloc<win32.OPENFILENAME>();
    ofn.ref.lStructSize = sizeOf<win32.OPENFILENAME>();
    ofn.ref.lpstrFile = fileBuffer.cast();
    ofn.ref.nMaxFile = 260;
    ofn.ref.lpstrFilter = filterPtr.cast();
    ofn.ref.nFilterIndex = 1;
    ofn.ref.lpstrDefExt = 'json'.toNativeUtf16().cast();
    ofn.ref.lpstrFileTitle = nullptr;
    ofn.ref.Flags = win32.OFN_FILEMUSTEXIST | win32.OFN_PATHMUSTEXIST;
    ofn.ref.lpstrTitle = '打开密码文件'.toNativeUtf16().cast();
    String? path;
    if (win32.GetOpenFileName(ofn) != 0) {
      path = fileBuffer.cast<Utf16>().toDartString();
    }
    calloc.free(ofn);
    calloc.free(fileBuffer);
    calloc.free(filterPtr);
    return path;
  }

  void _addPassword() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _PasswordDialog(),
    );
    if (result != null) {
      setState(() {
        passwords.add(result);
      });
      _savePasswords();
    }
  }

  void _deletePassword(int index) async {
    setState(() {
      passwords.removeAt(index);
    });
    _savePasswords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('密码管理'), actions: [
        IconButton(
          icon: const Icon(Icons.upload_file),
          tooltip: '导出密码文件',
          onPressed: _exportPasswords,
        ),
        IconButton(
          icon: const Icon(Icons.download),
          tooltip: '导入密码文件',
          onPressed: _importPasswords,
        ),
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : passwords.isEmpty
          ? const Center(child: Text('暂无密码记录'))
          : ListView.builder(
              itemCount: passwords.length,
              itemBuilder: (context, index) {
                final item = passwords[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ExpansionTile(
                    title: Text(item['title'] ?? ''),
                    subtitle: Text(item['username'] ?? ''),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('密码: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: SelectableText(
                                    item['password'] ?? '',
                                    style: const TextStyle(fontFamily: 'monospace'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deletePassword(index),
                                  tooltip: '删除',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPassword,
        tooltip: '添加密码',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: '账号'),
          ),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: '密码'),
            obscureText: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'title': _titleController.text,
              'username': _usernameController.text,
              'password': _passwordController.text,
            });
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class DecoderPage extends StatefulWidget {
  const DecoderPage({super.key});

  @override
  State<DecoderPage> createState() => _DecoderPageState();
}

class _DecoderPageState extends State<DecoderPage> {
  String _decoded = '';
  String _error = '';

  Future<void> _decodeFile() async {
    setState(() {
      _decoded = '';
      _error = '';
    });
    try {
      // final result = await FilePicker.platform.pickFiles(type: FileType.any);
      // TODO: 可用原生文件选择或提示暂不支持 Windows 文件选择
      // if (result != null) {
      //   // FilePicker 相关逻辑已移除
      // }
      // if (result != null && result.files.single.path != null) {
      //   final file = File(result.files.single.path!);
      //   final content = await file.readAsString();
      //   // 假设解码为 JSON 格式
      //   final decodedJson = jsonDecode(content);
      //   setState(() {
      //     _decoded = const JsonEncoder.withIndent('  ').convert(decodedJson);
      //   });
      // }
      // TODO: Windows 下暂不支持文件选择与解码
      // final file = File(result.files.single.path!);
      // TODO: Windows 下暂不支持文件选择与解码
      // final content = await file.readAsString();
      // TODO: Windows 下暂不支持文件选择与解码
      // 假设解码为 JSON 格式
      // final decodedJson = jsonDecode(content);
      setState(() {
        _decoded = '暂不支持 Windows 文件选择与解码功能';
      });
    } catch (e) {
      setState(() {
        _error = '解码失败: \$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('解码器')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _decodeFile,
              child: const Text('选择并解码文件'),
            ),
            const SizedBox(height: 16),
            if (_decoded.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(child: SelectableText(_decoded)),
              ),
            if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
