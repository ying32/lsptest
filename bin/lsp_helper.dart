//ignore_for_file: empty_catches

import 'dart:async';
import 'dart:convert';
import 'dart:io';
// import 'package:win32/win32.dart';
// import 'package:ffi/ffi.dart';
import 'dart:math' as math;

/// 测试用，Windows下使用Dgbview.exe或者CnDebugViewer.exe来捕获数据，测试完后就可以不要这个函数了。
///
/// 代码是使用VS Code写的，Zed只是用来测试
void printDebug(Object? object) async {
  // if (Platform.isWindows && object != null) {
  //   try {
  //     final ptr = "$object".toNativeUtf16();
  //     try {
  //       OutputDebugString(ptr);
  //     } finally {
  //       free(ptr);
  //     }
  //   } catch (e) {
  //     printDebug("异常=$e");
  //   }
  // }
}

/// 要启动的dart进程文件名（短文件名），比如`dart.bat`
@pragma("vm:platform-const")
final dartFileName = "dart${Platform.isWindows ? '.bat' : ''}";

/// 环境变量值分割符
@pragma("vm:platform-const")
final envPathSeparator = Platform.isWindows ? ";" : ":";

/// 获取PATH中定义的dart路径（Windows下是一个.bat的文件）
String? getDartFullPath() {
  for (String path
      in Platform.environment["PATH"]?.split(envPathSeparator) ?? []) {
    if (path.isEmpty) continue;
    // 如果需要的话，添加一个路径分割符
    if (!path.endsWith(Platform.pathSeparator)) {
      path += Platform.pathSeparator;
    }
    final file = File("$path$dartFileName");
    if (file.existsSync()) return file.path;
  }
  return null;
}

/// LSP解码
class LspMessageDecoder {
  static const contentLength = 'Content-Length:';
  static const contentType =
      'Content-Type: application/vscode-jsonrpc; charset=utf-8';
  // 提取正文内容长度
  static final lengthRegEx = RegExp(r'Content-Length:\s*(\d+)');

  final _buffer = <int>[];

  /// 添加片断
  void addChunk(Iterable<int> iterable) => _buffer.addAll(iterable);

  /// 尝试解析，并通知监听的
  void tryParseToSink(EventSink<Map<String, dynamic>> sink) {
    final message = tryParse();
    if (message == null) return;
    sink.add(message);
  }

  /// 写lsp消息
  static writeMessage(IOSink stream, dynamic message) async {
    if (message == null) return;
    // 注意文本这块，一定要先编码成utf-8的，否则会造成其它问题
    final text = utf8.encode(message is String ? message : jsonEncode(message));
    stream.add(
        utf8.encode("$contentLength ${text.length}\r\n$contentType\r\n\r\n"));
    stream.add(text);
    await stream.flush();
  }

  /// 解析缓冲区完整 LSP 帧
  Map<String, dynamic>? tryParse() {
    try {
      final headerEnd = _findHeaderEnd();
      // 头部不完整，等待更多数据
      if (headerEnd == -1) return null;
      // 解析 Content-Length
      final headerStr = utf8.decode(_buffer.sublist(0, headerEnd));
      // 内容长度
      final contentLength = _parseContentLength(headerStr);
      if (contentLength <= 0) {
        // 异常帧，丢弃头部
        _buffer.removeRange(0, math.min(headerEnd + 4, _buffer.length));
        return null;
      }
      // 报文整体长度 = 头部长度 + 分隔符\r\n\r\n + json长度
      final totalFrameSize = headerEnd + 4 + contentLength;
      if (_buffer.length < totalFrameSize) return null;
      // 取json数据
      final jsonBytes = _buffer.sublist(headerEnd + 4, totalFrameSize);
      // 移除一个message
      _buffer.removeRange(0, totalFrameSize);
      // 解码JSON
      return jsonDecode(utf8.decode(jsonBytes));
    } catch (e, s) {
      printDebug("_parseBuffer  exception: $e, \n $s");
    }
    return null;
  }

  /// 查找 \r\n\r\n 帧头结束位置
  int _findHeaderEnd() {
    for (int i = 0; i < _buffer.length; i++) {
      if (_buffer[i] == 13 &&
          i + 3 < _buffer.length &&
          (_buffer[i + 1] == 10 &&
              _buffer[i + 2] == 13 &&
              _buffer[i + 3] == 10)) {
        return i;
      }
    }
    return -1;
  }

  /// 解析 Content-Length 数值
  int _parseContentLength(String header) {
    final match = lengthRegEx.firstMatch(header);
    if (match == null) return 0;
    return int.tryParse(match.group(1)!) ?? 0;
  }
}

/// LSP 协议帧解码Transformer
class LspMessageTransformer
    extends StreamTransformerBase<List<int>, Map<String, dynamic>> {
  final LspMessageDecoder decoder = LspMessageDecoder();

  @override
  Stream<Map<String, dynamic>> bind(Stream<List<int>> stream) {
    return stream.transform(
      StreamTransformer<List<int>, Map<String, dynamic>>.fromHandlers(
        handleData: (data, sink) {
          decoder.addChunk(data);
          decoder.tryParseToSink(sink);
        },
        handleDone: (sink) {
          decoder.tryParseToSink(sink);
          sink.close();
        },
        handleError: (error, stackTrace, sink) =>
            sink.addError(error, stackTrace),
      ),
    );
  }
}

var initialized = false;
void main(List<String> args) async {
  // 启动dart进程
  final dartProcess = await Process.start(
    args.firstOrNull ?? getDartFullPath() ?? dartFileName, // ?? maybe ???
    ['language-server', '--protocol=lsp'],
    mode: ProcessStartMode.normal,
  );
  // 重定向dart进程的管道
  dartProcess.stderr.pipe(stderr);
  stdin.pipe(dartProcess.stdin);
  // 监听dart stdout
  dartProcess.stdout.transform(LspMessageTransformer()).listen((message) async {
    try {
      //printDebug("dartProcess.stdout message=$message");
      if (!initialized) {
        // 经过研究，发现此事件中存在多个`textDocument/completion`, 在dart返回的结果中
        // 有定义`triggerCharacters`字段的在前面，zed在处理的时候是使用的覆盖模式，造成
        // 结果被替换为null了。
        if (message['method'] == 'client/registerCapability') {
          final registrations = message['params']?['registrations'];
          List? oldtriggerCharacters;
          if (registrations != null && registrations is List) {
            for (final item in registrations) {
              if (item['method'] == "textDocument/completion") {
                final triggerCharacters =
                    item['registerOptions']?['triggerCharacters'];
                if (triggerCharacters != null) {
                  oldtriggerCharacters = triggerCharacters;
                } else {
                  item['registerOptions']?['triggerCharacters'] =
                      oldtriggerCharacters;
                }
              }
            }
          }
          initialized = true;
        }
      }
      await LspMessageDecoder.writeMessage(stdout, message);
    } catch (e, s) {
      printDebug("object stdout exception: $e\n$s");
    }
  });
}
