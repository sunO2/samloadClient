import 'dart:convert' as convert;

import 'package:firmware_client/clib/firmware_client.dart';
import 'package:flutter/material.dart';
import 'dart:isolate'; // For Isolate communication
import 'dart:async'; // For Completer
import 'package:firmware_client/widget/custom_progress_bar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rxdart/rxdart.dart';

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
  String _downloadStatus = ''; // 下载状态
  String? _osVersion = "";
  DownloadStatus _downloadStatusEnum = DownloadStatus.notStarted; // 下载状态枚举\
  DownloadStatus _checkStatus = DownloadStatus.notStarted; // 查询状态枚举

  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _fwController = TextEditingController();
  final TextEditingController _imeiController = TextEditingController();
  final TextEditingController _outputPathController =
      TextEditingController(); // 输出路径控制器

  FirmwareClient? client;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final _progressController = StreamController<double>();
  Stream<double> get progressStream => _progressController.stream;
  StreamSubscription<double>? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    // 根据平台加载不同的动态库
    _progressSubscription = progressStream
        .sampleTime(Duration(milliseconds: 500))
        .listen((progress) {
          setState(() {
            _downloadProgress = progress;
            _downloadStatus = '下载中...';
            _downloadStatusEnum = DownloadStatus.downloading;
          });
          _showNotification(
            '固件下载中',
            '进度: ${(progress * 100).toStringAsFixed(1)}%',
            (progress * 100).toInt(),
          );
        });
    FirmwareClient().create().then((client) {
      this.client = client;
    });
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // 替换为你的应用图标名称

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  @override
  void dispose() {
    _modelController.dispose();
    _regionController.dispose();
    _fwController.dispose();
    _imeiController.dispose();
    _outputPathController.dispose();
    client?.dispose();
    _progressSubscription?.cancel();
    _progressController.close();
    super.dispose();
  }

  void _fileSelect() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _outputPathController.text = selectedDirectory;
      });
    }
  }

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
    var osVersion = "";
    if (null != result) {
      Map<String, dynamic> resultJson = convert.jsonDecode(result);
      _fwController.text = resultJson['data']['versionCode'];
      osVersion = resultJson['data']['androidVersion'];
    }

    setState(() {
      _checkStatus = DownloadStatus.completed;
      _osVersion = osVersion;
    });
  }

  Future<void> _downloadFirmware() async {
    setState(() {
      _downloadProgress = 0.0;
      _downloadStatus = '下载中...';
      _downloadStatusEnum = DownloadStatus.downloading;
    });

    _showNotification('固件下载', '下载已开始...', 0);

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
        _progressController.sink.add(progress);
      } else if (message is Map<String, dynamic>) {
        final type = message['type'];
        if (type == 'result') {
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
        _showNotification('固件下载', '下载完成!', 100);
      } else {
        setState(() {
          _downloadStatus = '下载失败: ${downloadInfo["message"]}';
          _downloadStatusEnum = DownloadStatus.failed;
        });
        _showNotification('固件下载', '下载失败: ${downloadInfo["message"]}', 0);
      }
    } catch (e) {
      setState(() {
        _downloadStatus = '下载失败: $e';
        _downloadStatusEnum = DownloadStatus.failed;
      });
      _showNotification('固件下载', '下载失败: $e', 0);
    }
  }

  _showNotification(String title, String body, int progress) {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'download_channel',
          '下载通知',
          channelDescription: '用于显示固件下载进度的通知',
          importance: Importance.low,
          priority: Priority.low,
          showProgress: true,
          maxProgress: 100,
          progress: progress,
          onlyAlertOnce: true,
          // ongoing: true, // 下载进行中时，通知会一直存在
        );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    flutterLocalNotificationsPlugin.show(
      0, // 通知ID
      title,
      body,
      platformChannelSpecifics,
      payload: 'download_firmware',
    );
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  labelText: 'Model (e.g SM-S9080)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _regionController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Region (e.g CHC)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _fwController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Firmware Version',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _imeiController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'IMEI/Serial',
                ),
              ),
              const SizedBox(height: 20), // 添加一些间距
              TextField(
                controller: _outputPathController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '输出路径',
                  suffixIcon: IconButton(
                    onPressed: _fileSelect,
                    icon: Icon(Icons.insert_drive_file_rounded),
                  ),
                ),
              ),
              if (_osVersion?.isNotEmpty ?? false)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text("OS Version: $_osVersion"),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: CustomProgressBar(
                      progress: _downloadProgress,
                      height: 10.0,
                      completedColor: Theme.of(context).colorScheme.primary,
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
    );
  }
}
