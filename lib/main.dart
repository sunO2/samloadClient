import 'dart:convert' as convert;

import 'package:firmware_client/clib/firmware_client.dart';
import 'package:flutter/material.dart';
import 'dart:isolate'; // For Isolate communication
import 'dart:async'; // For Completer
import 'package:firmware_client/widget/custom_progress_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // 确保 Flutter 引擎已初始化
  // 初始化 Dart_PostCObject_DL，以便在辅助 Isolate 中使用
  // Dart_PostCObject_DL.initialize(NativeApi.initializeMessagePort); // 这一行是旧的 API，不再需要
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

enum DownloadStatus { notStarted, downloading, completed, failed }

class _MyHomePageState extends State<MyHomePage> {
  double _downloadProgress = 0.0; // 下载进度
  String _downloadStatus = '未开始'; // 下载状态
  DownloadStatus _downloadStatusEnum = DownloadStatus.notStarted; // 下载状态枚举\
  DownloadStatus _checkStatus = DownloadStatus.notStarted; // 查询状态枚举

  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _fwController = TextEditingController();
  final TextEditingController _imeiController = TextEditingController();
  final TextEditingController _outputPathController =
      TextEditingController(); // 输出路径控制器

  FirmwareClient? client;

  @override
  void initState() {
    super.initState();
    // 根据平台加载不同的动态库
    FirmwareClient().create().then((client) {
      this.client = client;
    });
  }

  @override
  void dispose() {
    _modelController.dispose();
    _regionController.dispose();
    _fwController.dispose();
    _imeiController.dispose();
    _outputPathController.dispose();
    client?.dispose();
    super.dispose();
  }

  void _incrementCounter() {}

  void _checkFirmware() async {
    final model = _modelController.text;
    final region = _regionController.text;

    if (model.isEmpty || region.isEmpty) {
      setState(() {
        _downloadStatus = '错误: model 和 region 不能为空';
      });
      return;
    }

    if (_checkStatus == DownloadStatus.downloading) {
      return;
    }

    setState(() {
      _checkStatus = DownloadStatus.downloading;
    });

    var result = await client?.checkVersion(model, region);
    setState(() {
      _checkStatus = DownloadStatus.completed;
    });
    if (null != result) {
      Map<String, dynamic> resultJson = convert.jsonDecode(result);
      _fwController.text = resultJson['data']['versionCode'];
    }
  }

  Future<void> _downloadFirmware() async {
    setState(() {
      _downloadProgress = 0.0;
      _downloadStatus = '下载中...';
      _downloadStatusEnum = DownloadStatus.downloading;
    });

    final model = _modelController.text;
    final region = _regionController.text;
    final fwVersion = _fwController.text;
    final imeiSerial = _imeiController.text;
    final outputPath = _outputPathController.text;

    if (model.isEmpty ||
        region.isEmpty ||
        fwVersion.isEmpty ||
        imeiSerial.isEmpty ||
        outputPath.isEmpty) {
      setState(() {
        _downloadStatus = '错误: 所有字段都不能为空';
      });
      return;
    }

    final receivePort = ReceivePort();
    final completer = Completer<String>();

    receivePort.listen((message) {
      if (message is List<dynamic>) {
        final current = message[1];
        final max = message[2];
        final progress = (max > 0) ? current / max : 0.0;
        setState(() {
          _downloadProgress = progress;
          _downloadStatus = '下载中...';
          _downloadStatusEnum = DownloadStatus.downloading;
        });
      } else if (message is Map<String, dynamic>) {
        final type = message['type'];
        if (type == 'progress') {
          setState(() {
            _downloadProgress = message['progress'] as double;
            _downloadStatus = message['status'] as String;
          });
        } else if (type == 'result') {
          completer.complete(message['result'] as String);
          receivePort.close();
        } else if (type == 'error') {
          completer.completeError(message['error'] as String);
          receivePort.close();
        }
      }
    });

    try {
      client?.downloadFirmware(
        model,
        region,
        fwVersion,
        imeiSerial,
        outputPath,
        receivePort.sendPort,
      );
      final downloadResult = await completer.future;
      final downloadInfo = convert.jsonDecode(downloadResult);
      if (downloadInfo['success'] ?? false) {
        setState(() {
          _downloadStatus = '下载完成: $downloadResult';
          _downloadStatusEnum = DownloadStatus.completed;
        });
      } else {
        setState(() {
          _downloadStatus = '下载失败: ${downloadInfo["message"]}';
          _downloadStatusEnum = DownloadStatus.failed;
        });
      }
    } catch (e) {
      setState(() {
        _downloadStatus = '下载失败: $e';
        _downloadStatusEnum = DownloadStatus.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Container(
        margin: EdgeInsets.only(top: 56.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: _checkStatus == DownloadStatus.downloading
                        ? null
                        : _checkFirmware,
                    child: const Text('查询固件版本'),
                  ),
                  ElevatedButton(
                    onPressed: _downloadStatusEnum == DownloadStatus.downloading
                        ? null
                        : _downloadFirmware,
                    child: Text(
                      _downloadStatusEnum == DownloadStatus.downloading
                          ? '下载中...'
                          : _downloadStatusEnum == DownloadStatus.completed
                          ? "下载完成"
                          : _downloadStatusEnum == DownloadStatus.failed
                          ? "重试"
                          : '下载固件',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20), // 添加一些间距
              TextField(
                controller: _modelController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Model',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _regionController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Region',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _fwController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'FW',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _imeiController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'IMEI',
                ),
              ),
              const SizedBox(height: 20), // 添加一些间距
              TextField(
                controller: _outputPathController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '输出路径 (例如: /sdcard/Download)',
                ),
              ),
              const SizedBox(height: 20), // 添加一些间距
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: CustomProgressBar(
                      progress: _downloadProgress,
                      height: 10.0,
                      completedColor: Theme.of(context).primaryColor,
                      remainingColor: Colors.grey[300]!,
                      borderRadius: 10.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${(_downloadProgress * 100).toStringAsFixed(1)}%'),
                ],
              ),
              Text(_downloadStatus),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter, // 保持原有的计数器功能
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
