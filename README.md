修复Zed中dart无法使用`.`来自动完成代码。

### 原因分析

2026/5/11重新分析后得出结论：

**这是一个`Zed的bug`，在dart向客户端（Zed）注册事件`client/registerCapability`中，dart返回的结果中发现此事件中存在多个`textDocument/completion`节点，其中有未包含`triggerCharacters`的字段，而且在有字段的后面，而Zed在处理的时候是使用的覆盖模式，造成前一个结果被后面的null字段给替换了。**

----

**我已经向Zed项目提交了一个issue: [Zed issue 56428](https://github.com/zed-industries/zed/issues/56428)**

### 编译（因为只测试了Windows下的）

**无第三方依赖，可以直接编译，之前版本的已经在macOS下编译测试过了**

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

可以看[效果演示](video.mp4)的效果
<video width="320" height="240" controls>
  <source src="video.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>
