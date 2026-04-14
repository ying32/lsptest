//ignore_for_file: empty_catches

import 'dart:convert';
import 'dart:io';

import 'package:lsp_server/lsp_server.dart';
// 测试完后就注释掉
// import 'package:json_rpc_2/json_rpc_2.dart';
// import 'package:win32/win32.dart';
// import 'package:ffi/ffi.dart';

/// 测试用，Windows下使用Dgbview.exe或者CnDebugViewer.exe来捕获数据，测试完后就可以不要这个函数了。
///
/// 代码是使用VS Code写的，Zed只是用来测试
void printDebug(Object? object) {
  if (Platform.isWindows && object != null) {
    // final ptr = "$object".toNativeUtf16();
    // try {
    //   OutputDebugString(ptr);
    // } finally {}
    // free(ptr);
  }
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

void main(List<String> args) async {
  // 启动dart进程
  final dartProcess = await Process.start(
    args.firstOrNull ?? getDartFullPath() ?? dartFileName, // ?? maybe ???
    ['language-server', '--protocol=lsp'],
    mode: ProcessStartMode.normal,
  );
  // 桥接的中间lsp服务
  var lspBridge = Connection(stdin, stdout);
  // 连接原dart的lsp服务
  var dartLsp = Connection(dartProcess.stdout, dartProcess.stdin);

  // dart lsp请求简化
  dynamic sendDartLspRequest(String method, dynamic params) async {
    printDebug("收到zed消息：method=$method, value=$params");
    try {
      final res = await dartLsp.sendRequest(method, params);
      printDebug(
          "请求dart成功，返回结果：method=$method, result=$res, type=${res?.runtimeType}");
      return res;
    } catch (e) {
      // TODO: 这地方感觉不太对，光屏蔽异常？是否需要返回给zed???
      printDebug("请求dart错误 method=$method, value=$params, 异常=$e");
    }
    return null;
  }

  // 监听dart lsp的主动消息？？？
  dartLsp.peer.registerFallback((parameters) {
    printDebug(
        "dartLsp method=${parameters.method}, value=${parameters.value}");
    //TODO: 这里应该这样做？？？？我也不知道！
    return lspBridge.sendNotification(parameters.method, parameters.value);
  });

  // 转发其它请求
  lspBridge.peer.registerFallback((parameters) async =>
      sendDartLspRequest(parameters.method, parameters.value));

  // lsp初始化消息
  lspBridge.onInitialize((parameters) async {
    // 请求原始的dart lsp初始化方法，必须要请求，否则lsp无法工作
    await sendDartLspRequest('initialize', parameters.toJson());
    // 返回固定的结果
    return InitializeResult.fromJson(initializeResultJson);
  });

  // lsp结束消息
  lspBridge.onShutdown(() async {
    await sendDartLspRequest('shutdown', {});
    dartLsp.close();
    lspBridge.close();
    dartProcess.kill();
  });

  // 监听2个
  dartLsp.listen();
  await lspBridge.listen();
}

/// 一段固定的返回结果（数据来自zed启动dart返回的结果，并增加了一个`"triggerCharacters":["."]`字段）
// TODO: 这个随zed或者dart的更新，可能需要定期更新吧？？？
final initializeResultJson = jsonDecode('''{
  "capabilities": {
    "textDocumentSync": {"change": 2},
    "selectionRangeProvider": true,
    "hoverProvider": {},
    "completionProvider": {
      "resolveProvider": true,
      "triggerCharacters": ["."]
    },
    "signatureHelpProvider": {
      "triggerCharacters": ["("],
      "retriggerCharacters": [","]
    },
    "definitionProvider": {},
    "typeDefinitionProvider": true,
    "implementationProvider": true,
    "referencesProvider": true,
    "documentHighlightProvider": true,
    "documentSymbolProvider": {},
    "workspaceSymbolProvider": true,
    "codeActionProvider": {
      "codeActionKinds": [
        "source",
        "source.organizeImports",
        "source.fixAll",
        "source.sortMembers",
        "quickfix",
        "refactor"
      ]
    },
    "codeLensProvider": {},
    "documentFormattingProvider": {},
    "documentRangeFormattingProvider": {},
    "documentOnTypeFormattingProvider": {
      "firstTriggerCharacter": "}",
      "moreTriggerCharacter": [";"]
    },
    "renameProvider": {"prepareProvider": true},
    "documentLinkProvider": {"resolveProvider": false},
    "colorProvider": {},
    "foldingRangeProvider": true,
    "executeCommandProvider": {
      "commands": [
        "dart.edit.sortMembers",
        "dart.edit.organizeImports",
        "dart.edit.fixAll",
        "dart.edit.fixAllInWorkspace.preview",
        "dart.edit.fixAllInWorkspace",
        "dart.edit.sendWorkspaceEdit",
        "refactor.perform",
        "refactor.validate",
        "dart.logAction",
        "dart.refactor.convert_all_formal_parameters_to_named",
        "dart.refactor.convert_selected_formal_parameters_to_named",
        "dart.refactor.move_selected_formal_parameters_left",
        "dart.refactor.move_top_level_to_file"
      ],
      "workDoneProgress": true
    },
    "workspace": {
      "workspaceFolders": {"supported": true, "changeNotifications": true}
    },
    "callHierarchyProvider": true,
    "semanticTokensProvider": {
      "legend": {
        "tokenTypes": [
          "annotation",
          "keyword",
          "class",
          "comment",
          "method",
          "variable",
          "parameter",
          "enum",
          "enumMember",
          "type",
          "source",
          "property",
          "namespace",
          "boolean",
          "number",
          "string",
          "function",
          "typeParameter"
        ],
        "tokenModifiers": [
          "documentation",
          "constructor",
          "declaration",
          "importPrefix",
          "instance",
          "static",
          "escape",
          "annotation",
          "control",
          "label",
          "interpolation",
          "void"
        ]
      },
      "range": true,
      "full": {"delta": false}
    },
    "inlayHintProvider": {"resolveProvider": false},
    "experimental": {
      "textDocument": {"super": {}, "augmented": {}, "augmentation": {}}
    }
  }
}''');
