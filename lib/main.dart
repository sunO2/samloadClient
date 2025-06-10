import 'dart:convert' as convert;

import 'package:firmware_client/clib/firmwarelib.dart';
import 'package:flutter/material.dart';
import 'dart:io'; // For Platform.isAndroid, Platform.isIOS
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'dart:isolate'; // For Isolate communication
import 'dart:async'; // For Completer

void main() {
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
  int _counter = 0;
  String _firmwareVersion = '未查询'; // 新增状态变量
  double _downloadProgress = 0.0; // 下载进度
  String _downloadStatus = '未开始'; // 下载状态

  late final FirmwareLibBindings bindings;
  late final ffi.Pointer<ffi.NativeFunction<progressCallbackFunction>>
  _progressCbPtr; // 声明为类成员

  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _fwController = TextEditingController();
  final TextEditingController _imeiController = TextEditingController();
  final TextEditingController _outputPathController =
      TextEditingController(); // 输出路径控制器

  @override
  void initState() {
    super.initState();
    // 根据平台加载不同的动态库
    if (Platform.isAndroid) {
      bindings = FirmwareLibBindings(
        ffi.DynamicLibrary.open('libfirmwarelib.so'),
      );
    } else if (Platform.isIOS) {
      bindings = FirmwareLibBindings(
        ffi.DynamicLibrary.open('libfirmwarelib.dylib'),
      );
    } else if (Platform.isMacOS) {
      bindings = FirmwareLibBindings(
        ffi.DynamicLibrary.open('libfirmwarelib.dylib'),
      );
    } else if (Platform.isWindows) {
      bindings = FirmwareLibBindings(
        ffi.DynamicLibrary.open('firmwarelib.dll'),
      );
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    // 在主 Isolate 中创建回调函数指针
    _progressCbPtr = ffi.Pointer.fromFunction<progressCallbackFunction>(
      _progressCallback, // 使用静态方法
      // debugName: 'progressCallback', // 可选，用于调试
    );
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

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _checkFirmware() {
    final model = _modelController.text;
    final region = _regionController.text;
    final fw = _fwController.text;
    final imei = _imeiController.text;

    // 将 Dart 字符串转换为 C 字符串指针
    final modelC = model.toNativeUtf8().cast<ffi.Char>();
    final regionC = region.toNativeUtf8().cast<ffi.Char>();
    // fw 和 imei 目前没有对应的 C 函数，但为了完整性，也进行转换
    final fwC = fw.toNativeUtf8().cast<ffi.Char>();
    final imeiC = imei.toNativeUtf8().cast<ffi.Char>();

    // 调用 C 函数
    final ffi.Pointer<ffi.Char> resultC = bindings.CheckFirmwareVersion(
      modelC,
      regionC,
    );

    // 将 C 字符串指针转换回 Dart 字符串
    final result = resultC.cast<Utf8>().toDartString();

    Map<String, dynamic> resultJson = convert.jsonDecode(result);
    _fwController.text = resultJson['data']['versionCode'];

    // 释放 C 字符串内存
    // 注意：FreeString 是在 firmwarelib.dart 中定义的，用于释放 C 分配的字符串内存
    calloc.free(modelC);
    calloc.free(regionC);
    calloc.free(fwC);
    calloc.free(imeiC);
    bindings.FreeString(resultC); // 释放返回的字符串内存

    setState(() {
      _firmwareVersion = result;
    });
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
      if (message is Map<String, dynamic>) {
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
      await Isolate.spawn(_downloadEntrypoint, {
        'sendPort': receivePort.sendPort,
        'model': model,
        'region': region,
        'fwVersion': fwVersion,
        'imeiSerial': imeiSerial,
        'outputPath': outputPath,
        'progressCbPtr': _progressCbPtr.address, // 传递指针地址
      });
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

  // 新 Isolate 的入口点
  static void _downloadEntrypoint(Map<String, dynamic> message) {
    final sendPort = message['sendPort'] as SendPort;
    final model = message['model'] as String;
    final region = message['region'] as String;
    final fwVersion = message['fwVersion'] as String;
    final imeiSerial = message['imeiSerial'] as String;
    final outputPath = message['outputPath'] as String;
    final progressCbPtrAddress = message['progressCbPtr'] as int; // 获取指针地址

    final bindings = FirmwareLibBindings(
      Platform.isAndroid
          ? ffi.DynamicLibrary.open('libfirmwarelib.so')
          : Platform.isIOS
          ? ffi.DynamicLibrary.open('libfirmwarelib.dylib')
          : Platform.isMacOS
          ? ffi.DynamicLibrary.open('libfirmwarelib.dylib')
          : Platform.isWindows
          ? ffi.DynamicLibrary.open('firmwarelib.dll')
          : throw UnsupportedError('Unsupported platform'),
    );

    // 将 Dart 字符串转换为 C 字符串指针
    final modelC = model.toNativeUtf8().cast<ffi.Char>();
    final regionC = region.toNativeUtf8().cast<ffi.Char>();
    final fwVersionC = fwVersion.toNativeUtf8().cast<ffi.Char>();
    final imeiSerialC = imeiSerial.toNativeUtf8().cast<ffi.Char>();
    final outputPathC = outputPath.toNativeUtf8().cast<ffi.Char>();

    // 从地址重新创建指针
    final progressCbPtr =
        ffi.Pointer<ffi.NativeFunction<progressCallbackFunction>>.fromAddress(
          progressCbPtrAddress,
        );

    try {
      final ffi.Pointer<ffi.Char> resultC = bindings.DownloadFirmware(
        modelC,
        regionC,
        fwVersionC,
        imeiSerialC,
        outputPathC,
        progressCbPtr.cast<ffi.Void>(), // 传递回调函数指针
      );

      final result = resultC.cast<Utf8>().toDartString();
      sendPort.send({'type': 'result', 'result': result});

      // 释放 C 字符串内存
      calloc.free(modelC);
      calloc.free(regionC);
      calloc.free(fwVersionC);
      calloc.free(imeiSerialC);
      calloc.free(outputPathC);
      bindings.FreeString(resultC);
    } catch (e) {
      sendPort.send({'type': 'error', 'error': e.toString()});
    }
  }

  // 静态回调函数，用于接收 C 层的进度更新
  @pragma('vm:entry-point') // 标记为入口点，防止被 tree-shaking 优化掉
  static void _progressCallback(int current, int max, int bps) {
    // 这个函数在主 Isolate 中运行，但它是由 C 代码调用的
    // 实际的进度更新通过 SendPort 发送到主 Isolate 的 ReceivePort
    // 这里只是一个占位符，实际的逻辑在 ReceivePort.listen 中处理
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
              const SizedBox(height: 20), // 添加一些间距
              const Text('固件版本查询结果:'),
              Text(
                _firmwareVersion,
                style: Theme.of(context).textTheme.headlineMedium,
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
