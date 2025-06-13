import 'dart:isolate';

import 'package:firmware_client/page/check_page.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firmware_client/clib/firmware_client.dart'; // 假设需要这个
import 'package:firmware_client/widget/custom_progress_bar.dart'; // 假设需要这个

class DecrypterPage extends StatefulWidget {
  const DecrypterPage({super.key});

  @override
  State<DecrypterPage> createState() => _DecrypterPageState();
}

class _DecrypterPageState extends State<DecrypterPage> {
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _fwVersionController = TextEditingController();
  final TextEditingController _imeiController = TextEditingController();
  final TextEditingController _firmwareFilePathController =
      TextEditingController();
  final TextEditingController _outputPathController = TextEditingController();

  DownloadStatus _downloadStatusEnum = DownloadStatus.notStarted;

  double _downloadProgress = 0.0; // 进度条
  String _message = "";

  FirmwareClient? client;
  @override
  void initState() {
    FirmwareClient().create().then((client) {
      this.client = client;
    });
    super.initState();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _regionController.dispose();
    _fwVersionController.dispose();
    _imeiController.dispose();
    _firmwareFilePathController.dispose();
    _outputPathController.dispose();
    super.dispose();
  }

  void _selectFirmwareFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false, // 明确设置为 false
      withReadStream: false, // 明确设置为 false
    );

    if (result != null) {
      setState(() {
        _firmwareFilePathController.text = result.files.first.path ?? "";
      });
    }
  }

  void _selectOutputPath() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _outputPathController.text = "$selectedDirectory/firmware.zip";
      });
    }
  }

  // 模拟解密过程，更新进度条
  void _startDecryption() async {
    // 这里可以添加实际的解密逻辑
    // 模拟进度更新

    final model = _modelController.text;
    final region = _regionController.text;
    final fwVersion = _fwVersionController.text;
    final imeiSerial = _imeiController.text;
    final firmwarePath = _firmwareFilePathController.text;
    final outputPath = _outputPathController.text;

    if (model.isEmpty ||
        region.isEmpty ||
        fwVersion.isEmpty ||
        imeiSerial.isEmpty ||
        outputPath.isEmpty) {
      setState(() {});
      return;
    }

    final receivePort = ReceivePort();
    receivePort.listen((message) {
      if (message is List<dynamic>) {
        final current = message[1];
        final max = message[2];
        final progress = (max > 0) ? current / max : 0.0;
        setState(() {
          _downloadStatusEnum = DownloadStatus.downloading;
          _downloadProgress = progress;
        });
      } else {
        setState(() {
          _downloadStatusEnum = DownloadStatus.completed;
          _message = message.toString();
        });
      }
    });

    client?.decryptFirmware(
      model,
      region,
      fwVersion,
      imeiSerial,
      outputPath,
      firmwarePath,
      receivePort.sendPort,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('固件解密'),
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 72.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.end, // 将按钮对齐到右侧
              children: <Widget>[
                ElevatedButton(
                  onPressed: _downloadStatusEnum == DownloadStatus.downloading
                      ? null
                      : _startDecryption,
                  child: Text(
                    _downloadStatusEnum == DownloadStatus.downloading
                        ? '解密中...'
                        : '开始解密',
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
              controller: _fwVersionController,
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
            const SizedBox(height: 20),
            TextField(
              controller: _firmwareFilePathController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Firmware 文件路径',
                suffixIcon: IconButton(
                  onPressed: _selectFirmwareFile,
                  icon: Icon(Icons.insert_drive_file_rounded), // 文件选择图标
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _outputPathController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: '输出路径',
                suffixIcon: IconButton(
                  onPressed: _selectOutputPath,
                  icon: Icon(Icons.folder), // 文件夹选择图标
                ),
              ),
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
            Text(_message),
          ],
        ),
      ),
    );
  }
}
