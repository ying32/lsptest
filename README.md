zed中dart无法使用`.`来自动完成代码。

这个问题我一开始以为就是这样的，但搜索issue发现别人也有，在最新版本的zed中也有这个问题。
于是我分析了下，发现是dart lsp在初始的时候返回的结果中未包含`triggerCharacters`字段，zed认为不需要，所以按`.`无法弹出。
```json
"completionProvider":{
  "resolveProvider":true,
  "triggerCharacters":["."]
} 

```

我尝试使用dart写了一个包装器，经过验证可以正常按`.`弹出，当然这只是一个实验，用来分析原因的，具体还得zed这边看能否解决，因为vscode和android并没有这样的问题。

可以看[QQ录屏20260208162526.mp4](QQ录屏20260208162526.mp4)的效果