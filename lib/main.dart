import 'dart:convert' as convert;

import 'package:firmware_client/clib/firmware_client.dart';
import 'package:flutter/material.dart';
import 'dart:isolate'; // For Isolate communication
import 'dart:async'; // For Completer

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

class _MyHomePageState extends State<MyHomePage> {
  double _downloadProgress = 0.0; // 下载进度
  String _downloadStatus = '未开始'; // 下载状态

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

    var result = await client?.checkVersion(model, region);
    if (null != result) {
      Map<String, dynamic> resultJson = convert.jsonDecode(result);
      _fwController.text = resultJson['data']['versionCode'];
    }
  }

  Future<void> _downloadFirmware() async {
    setState(() {
      _downloadProgress = 0.0;
      _downloadStatus = '下载中...';
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
      setState(() {
        _downloadStatus = '下载完成: $downloadResult';
      });
    } catch (e) {
      setState(() {
        _downloadStatus = '下载失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            // Column is also a layout widget. It takes a list of children and
            // arranges them vertically. By default, it sizes itself to fit its
            // children horizontally, and tries to be as tall as its parent.
            //
            // Column has various properties to control how it sizes itself and
            // how it positions its children. Here we use mainAxisAlignment to
            // center the children vertically; the main axis here is the vertical
            // axis because Columns are vertical (the cross axis would be
            // horizontal).
            //
            // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
            // action in the IDE, or press "p" in the console), to see the
            // wireframe for each widget.
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
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
                  labelText: '输出路径 (例如: /sdcard/Download/firmware.zip)',
                ),
              ),
              const SizedBox(height: 20), // 添加一些间距
              ElevatedButton(
                onPressed: _checkFirmware,
                child: const Text('查询固件版本'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _downloadFirmware,
                child: const Text('下载固件'),
              ),
              const SizedBox(height: 20), // 添加一些间距
              LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 10),
              Text(
                '下载状态: $_downloadStatus (${(_downloadProgress * 100).toStringAsFixed(1)}%)',
              ),
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
