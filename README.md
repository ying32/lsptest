zed中dart无法使用`.`来自动完成代码。

### 原因分析

这个问题我一开始以为就是这样的，但搜索issue发现别人也有，在最新版本的zed中也有这个问题。于是我分析了下，发现是dart lsp在初始的时候返回的结果中未包含`triggerCharacters`字段，zed认为不需要。进一步测试发现dart lsp初始时返回的数据是很少的，与实际zed中获取到的dart lsp初始数据相差甚远，经过分析dart的代码(`dart-sdk-main\sdk-main\pkg\analysis_server\lib\src\lsp\constants.dart:dartCompletionTriggerCharacters`和`dart-sdk-main\sdk-main\pkg\analysis_server\lib\src\lsp\handlers\handler_completion.dart:CompletionRegistrations`)，似乎是通过其它事件动态注册的的，可能Zed并没有处理那个或者什么其它情况下忽略掉这个了吧，所以`.`无效。

```json
"completionProvider":{
  "resolveProvider":true,
  "triggerCharacters":["."]
} 
```

我尝试使用dart写了一个包装器，经过验证可以正常按`.`弹出，当然这只是一个实验，用来分析原因的，具体还得zed这边看能否解决，因为vs code和android studio并没有这样的问题。

### 编译Windows下的（因为只测试了Windows下的）

```shell 
dart compile exe bin/lsp_helper.dart
```

### 配置（zed的设置文件settings.json）

```json
{
    // lsp结点
    "lsp": {
      "dart": {
        "binary": {
          // 本代码编译后的可执行文件路径
          "path": "<your path>\\lsp_helper.exe", 
          "arguments": [
            // 可选的，如果不填则查找$PATH变量中的dart路径
            // "your dart fullpath(Optional)" 
          ]
        }
      }
    }
}
```


### 视频演示

可以看[QQ录屏20260208162526.mp4](QQ录屏20260208162526.mp4)的效果
