import 'dart:convert';
import 'dart:io';

import 'package:lsp_server/lsp_server.dart';
// import 'package:json_rpc_2/json_rpc_2.dart';
// import 'package:win32/win32.dart';
// import 'package:ffi/ffi.dart';

// 编译：dart compile exe bin/lsp_helper.dart

void printDebug(Object? object) {
  if (Platform.isWindows && object != null) {
    // final ptr = "$object".toNativeUtf16();
    // try {
    //   OutputDebugString(ptr);
    // } finally {}
    // free(ptr);
  }
}

String? getDartFullPath() {
  for (final String path
      in Platform.environment["PATH"]?.split(Platform.isWindows ? ";" : ":") ??
          []) {
    final file = File(
        "$path${Platform.pathSeparator}dart${Platform.isWindows ? '.bat' : ''}");
    //print("file=${file.path}");
    if (file.existsSync()) return file.path;
  }
  return null;
}

void main(List<String> args) async {
  // 第一个参数为dart的路径
  // zed的设置文件settings.json
  // "lsp": {
  //    "dart": { "binary": { "path":"<your path>\lsp_helper.exe", "arguments":[ "your dart fullpath(Optional)" ] }}
  //}
  final dartProcess = await Process.start(
    args.firstOrNull ??
        getDartFullPath() ??
        "dart${Platform.isWindows ? '.bat' : ''}", // ?? maybe ???
    ['language-server', '--protocol=lsp'],
    mode: ProcessStartMode.normal,
  );
  // 桥接的中间lsp服务
  var lspBridge = Connection(stdin, stdout);
  // 连接原dart的lsp服务
  var dartLsp = Connection(dartProcess.stdout, dartProcess.stdin);
  // 监听dart lsp的主动消息？？？
  //dartLsp.onNotification(method, handler)
  dartLsp.peer.registerFallback((parameters) {
    printDebug(
        "dartLsp method=${parameters.method}, value=${parameters.value}");
    // lspBridge.sendDiagnostics();
    // 这里应该这样做？？？？我也不知道！
    return lspBridge.sendNotification(parameters.method, parameters.value);
  });
  // 转发其它请求
  lspBridge.peer.registerFallback((parameters) async {
    printDebug(
        "收到zed消息：method=${parameters.method}, value=${parameters.value}");
    try {
      final res =
          await dartLsp.sendRequest(parameters.method, parameters.value);

      printDebug(
          "请求dart成功，返回结果：method=${parameters.method}, value=$res, type=${res?.runtimeType}");
      if (parameters.method == "initialize") {
        // printDebug("收到初始消息=$res");
        // res["capabilities"]["completionProvider"] = {
        //   "resolveProvider": true,
        //   "triggerCharacters": ["."]
        // };
        // printDebug("修改后的结果=$res");
        return initializeResultJson;
      } else if (parameters.method == "shutdown") {
        dartLsp.close();
        lspBridge.close();
        dartProcess.kill();
      }
      return res;
    } catch (e) {
      printDebug(
          "请求dart错误 method=${parameters.method}, value=${parameters.value}, 异常=$e");
    }
  });

  dartLsp.listen();
  await lspBridge.listen();
}

/// 拿了一段固定的返回结果
final initializeResultJson = jsonDecode(
    '{"capabilities":{"textDocumentSync":{"change":2},"selectionRangeProvider":true,"hoverProvider":{},"completionProvider":{"resolveProvider":true,"triggerCharacters":["."]},"signatureHelpProvider":{"triggerCharacters":["("],"retriggerCharacters":[","]},"definitionProvider":{},"typeDefinitionProvider":true,"implementationProvider":true,"referencesProvider":true,"documentHighlightProvider":true,"documentSymbolProvider":{},"workspaceSymbolProvider":true,"codeActionProvider":{"codeActionKinds":["source","source.organizeImports","source.fixAll","source.sortMembers","quickfix","refactor"]},"codeLensProvider":{},"documentFormattingProvider":{},"documentRangeFormattingProvider":{},"documentOnTypeFormattingProvider":{"firstTriggerCharacter":"}","moreTriggerCharacter":[";"]},"renameProvider":{"prepareProvider":true},"documentLinkProvider":{"resolveProvider":false},"colorProvider":{},"foldingRangeProvider":true,"executeCommandProvider":{"commands":["dart.edit.sortMembers","dart.edit.organizeImports","dart.edit.fixAll","dart.edit.fixAllInWorkspace.preview","dart.edit.fixAllInWorkspace","dart.edit.sendWorkspaceEdit","refactor.perform","refactor.validate","dart.logAction","dart.refactor.convert_all_formal_parameters_to_named","dart.refactor.convert_selected_formal_parameters_to_named","dart.refactor.move_selected_formal_parameters_left","dart.refactor.move_top_level_to_file"],"workDoneProgress":true},"workspace":{"workspaceFolders":{"supported":true,"changeNotifications":true}},"callHierarchyProvider":true,"semanticTokensProvider":{"legend":{"tokenTypes":["annotation","keyword","class","comment","method","variable","parameter","enum","enumMember","type","source","property","namespace","boolean","number","string","function","typeParameter"],"tokenModifiers":["documentation","constructor","declaration","importPrefix","instance","static","escape","annotation","control","label","interpolation","void"]},"range":true,"full":{"delta":false}},"inlayHintProvider":{"resolveProvider":false},"experimental":{"textDocument":{"super":{},"augmented":{},"augmentation":{}}}}}');
