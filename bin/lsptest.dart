import 'dart:convert';
import 'dart:io';

import 'package:lsp_server/lsp_server.dart';
import 'package:json_rpc_2/json_rpc_2.dart';

// 编译：dart compile exe bin/lsptest.dart

void main(List<String> args) async {
  if (args.isEmpty) exit(1);
  // 第一个参数为dart的路径
  // zed的设置文件settings.json
  // "lsp": {
  //    "dart": { "binary": { "path":"<your path>\lsptest.exe", "arguments":[ "your dart fullpath" ] }}
  //}
  final process = await Process.start(
    args.first,
    ['language-server', '--protocol=lsp'],
    mode: ProcessStartMode.normal,
  );
  // final logFile =
  // File("${Directory(Platform.executable).parent.path}\\lsp2.log");
  // final logFileSink = logFile.openWrite();
  // 连接原dart的lsp服务
  var dartLSPConn = Connection(process.stdout, process.stdin);
  dartLSPConn.peer.registerFallback((pp) {
    // logFileSink.writeln("dartlsp=method=${pp.method}, data=${jsonEncode(pp.value)}");
  });
  var lspWrapConn = Connection(stdin, stdout);
  // 转发其它请求
  lspWrapConn.peer.registerFallback((Parameters parameters) async {
    // logFileSink.writeln(
    // "收到请求=${parameters.method}, value=${jsonEncode(parameters.value)}");
    try {
      final res =
          await dartLSPConn.sendRequest(parameters.method, parameters.value);
      // logFileSink.writeln("返回method=${parameters.method}, value=${jsonEncode(res)}");
      return res;
    } catch (e) {
      // logFileSink.writeln("发送请求到lsp错误=$e");
    }
  });
  // 这里拦截初始请求，添加一”triggerCharacters“字段的
  lspWrapConn.onInitialize((params) async {
    // logFileSink.writeln("收到初始请求");
    // logFileSink.writeln(jsonEncode(params.toJson()));
    final res = await dartLSPConn.sendRequest('initialize', params.toJson());
    //logFileSink.writeln(jsonEncode(res));
    // {"resolveProvider":true,"triggerCharacters":["."]} 要添加一个点
    // 这个json来自zed的lsp日志里面。因为我拿到的res结果与他的不一样。
    return InitializeResult.fromJson(jsonDecode(
        '{"capabilities":{"textDocumentSync":{"change":2},"selectionRangeProvider":true,"hoverProvider":{},"completionProvider":{"resolveProvider":true,"triggerCharacters":["."]},"signatureHelpProvider":{"triggerCharacters":["("],"retriggerCharacters":[","]},"definitionProvider":{},"typeDefinitionProvider":true,"implementationProvider":true,"referencesProvider":true,"documentHighlightProvider":true,"documentSymbolProvider":{},"workspaceSymbolProvider":true,"codeActionProvider":{"codeActionKinds":["source","source.organizeImports","source.fixAll","source.sortMembers","quickfix","refactor"]},"codeLensProvider":{},"documentFormattingProvider":{},"documentRangeFormattingProvider":{},"documentOnTypeFormattingProvider":{"firstTriggerCharacter":"}","moreTriggerCharacter":[";"]},"renameProvider":{"prepareProvider":true},"documentLinkProvider":{"resolveProvider":false},"colorProvider":{},"foldingRangeProvider":true,"executeCommandProvider":{"commands":["dart.edit.sortMembers","dart.edit.organizeImports","dart.edit.fixAll","dart.edit.fixAllInWorkspace.preview","dart.edit.fixAllInWorkspace","dart.edit.sendWorkspaceEdit","refactor.perform","refactor.validate","dart.logAction","dart.refactor.convert_all_formal_parameters_to_named","dart.refactor.convert_selected_formal_parameters_to_named","dart.refactor.move_selected_formal_parameters_left","dart.refactor.move_top_level_to_file"],"workDoneProgress":true},"workspace":{"workspaceFolders":{"supported":true,"changeNotifications":true}},"callHierarchyProvider":true,"semanticTokensProvider":{"legend":{"tokenTypes":["annotation","keyword","class","comment","method","variable","parameter","enum","enumMember","type","source","property","namespace","boolean","number","string","function","typeParameter"],"tokenModifiers":["documentation","constructor","declaration","importPrefix","instance","static","escape","annotation","control","label","interpolation","void"]},"range":true,"full":{"delta":false}},"inlayHintProvider":{"resolveProvider":false},"experimental":{"textDocument":{"super":{},"augmented":{},"augmentation":{}}}}}'));
  });

  lspWrapConn.onShutdown(() async {
    dartLSPConn.sendRequest('shutdown', null);
    // logFileSink.close();
    dartLSPConn.close();
    lspWrapConn.close();
    process.kill();
  });

  dartLSPConn.listen();
  await lspWrapConn.listen();
}
