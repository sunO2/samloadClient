import 'dart:async';
import 'dart:collection';
import 'dart:ffi' as ffi;
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';
import 'dart:isolate';

import 'package:firmware_client/clib/firmwarelib.dart';

typedef FirmwareFunction =
    void Function(FirmwareMethod method, FirmwareLibBindings bindings);

class FirmwareMethod {
  final String methodName;
  final Map<String, dynamic> arguments;
  final SendPort sendPort;

  FirmwareMethod(this.methodName, this.sendPort, this.arguments);

  receove(Object? message) {
    sendPort.send(message);
  }
}

class FirmwareClient {
  SendPort? sendPort;

  Future<FirmwareClient> create() async {
    Completer<FirmwareClient> completer = Completer();
    ReceivePort mainReceivePort = ReceivePort();
    await Isolate.spawn(_subIsolateEntrypoint, mainReceivePort.sendPort);
    mainReceivePort.listen((message) {
      if (message is SendPort) {
        sendPort = message;
        completer.complete(this);
      }
    });
    return completer.future;
  }

  Future<String> checkVersion(String model, region) {
    ReceivePort receivePort = ReceivePort();
    Completer<String> completer = Completer();
    receivePort.listen((data) {
      completer.complete(data);
    });
    sendPort?.send(
      FirmwareMethod('checkVersion', receivePort.sendPort, {
        'model': model,
        'region': region,
      }),
    );
    return completer.future;
  }

  downloadFirmware(
    String model,
    region,
    fwVersion,
    imeiSerial,
    outputPath,
    SendPort downloadPort,
  ) {
    sendPort?.send(
      FirmwareMethod('downloadFirmware', downloadPort, {
        'model': model,
        'region': region,
        'fwVersion': fwVersion,
        'imeiSerial': imeiSerial,
        'outputPath': outputPath,
      }),
    );
  }

  decryptFirmware(
    String model,
    region,
    fwVersion,
    imeiSerial,
    outputPath,
    firmwarePath,
    SendPort downloadPort,
  ) {
    sendPort?.send(
      FirmwareMethod('decryptFirmware', downloadPort, {
        'model': model,
        'region': region,
        'fwVersion': fwVersion,
        'imeiSerial': imeiSerial,
        'firmwarePath': firmwarePath,
        'outputPath': outputPath,
      }),
    );
  }

  dispose() {
    sendPort?.send('dispose');
  }

  @pragma('vm:entry-point')
  void _subIsolateEntrypoint(SendPort mainSendPort) {
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

    ReceivePort subReceivePort = ReceivePort();
    mainSendPort.send(subReceivePort.sendPort);
    Map<String, FirmwareFunction> functions = HashMap();
    functions['checkVersion'] = _checkVersion;
    functions['downloadFirmware'] = _downloadFirmware;
    functions['decryptFirmware'] = _decryptFirmware;

    subReceivePort.listen((message) {
      switch (message) {
        case "dispose":
          Isolate.exit();
        case FirmwareMethod(methodName: var methodName):
          try {
            if (functions.containsKey(methodName)) {
              functions[methodName]!(message, bindings);
            }
          } catch (_) {}
          break;
      }
    });
  }

  _checkVersion(FirmwareMethod method, FirmwareLibBindings bindings) {
    var args = method.arguments;

    final model = args['model'] as String;
    final region = args['region'] as String;
    final modelC = model.toNativeUtf8().cast<ffi.Char>();
    final regionC = region.toNativeUtf8().cast<ffi.Char>();
    var versionResultC = bindings.CheckFirmwareVersion(modelC, regionC);

    var versionReuslt = versionResultC.cast<Utf8>().toDartString();
    calloc.free(modelC);
    calloc.free(regionC);
    bindings.FreeString(versionResultC);
    method.receove(versionReuslt);
  }

  _downloadFirmware(FirmwareMethod method, FirmwareLibBindings bindings) {
    var args = method.arguments;

    final model = args['model'] as String;
    final region = args['region'] as String;
    final fwVersion = args['fwVersion'] as String;
    final imeiSerial = args['imeiSerial'] as String;
    final outputPath = args['outputPath'] as String;

    // 将 Dart 字符串转换为 C 字符串指针
    final modelC = model.toNativeUtf8().cast<ffi.Char>();
    final regionC = region.toNativeUtf8().cast<ffi.Char>();
    final fwVersionC = fwVersion.toNativeUtf8().cast<ffi.Char>();
    final imeiSerialC = imeiSerial.toNativeUtf8().cast<ffi.Char>();
    final outputPathC = outputPath.toNativeUtf8().cast<ffi.Char>();

    final callback = bindings.NewDartCallbackHandle(
      method.sendPort.nativePort,
      NativeApi.postCObject.cast<ffi.Void>(),
    );

    final ffi.Pointer<ffi.Char> resultC = bindings.DownloadFirmware(
      modelC,
      regionC,
      fwVersionC,
      imeiSerialC,
      outputPathC,
      callback,
    );

    final result = resultC.cast<Utf8>().toDartString();
    method.receove({'type': 'result', 'result': result});

    calloc.free(modelC);
    calloc.free(regionC);
    calloc.free(fwVersionC);
    calloc.free(imeiSerialC);
    calloc.free(outputPathC);
    bindings.FreeString(resultC);
  }

  _decryptFirmware(FirmwareMethod method, FirmwareLibBindings bindings) {}
}
