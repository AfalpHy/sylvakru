# AGENTS.md

## 语言

始终使用中文回复用户。所有输出、解释、代码注释都应该使用中文。

## Codex 窗口约束

所有 Codex 窗口进入本项目后，必须先阅读并遵守本文件。若本文件与通用习惯冲突，以本文件为准；若用户在当前对话中给出更明确的新要求，以用户当前要求为准。

## Android 编译约束

- 默认只编译 Android arm64-v8a，也就是 armv8；不要编译 armeabi-v7a、x86 或 x86_64。
- 默认只编译性能包，也就是 Flutter profile 包；不要编译 debug 包或 release 包，除非用户明确要求。
- 推荐编译命令：

```powershell
& 'F:\software\flutter_3.44.0\bin\flutter.bat' build apk --profile --target-platform android-arm64
```

## 设备安装约束

- Android 性能包编译成功后，若有设备已连接，必须把编译好的包安装到设备上。
- 安装前先确认设备连接状态：

```powershell
adb devices
```

- 推荐安装命令：

```powershell
adb install -r build\app\outputs\flutter-apk\app-profile.apk
```

- 如果没有可用设备、设备未授权或安装失败，必须明确告诉用户失败原因和下一步需要用户处理的事项。

## 提交约束

- 每完成一个明确任务后，必须进行本地 git 提交。
- 提交时只纳入本任务相关文件；工作区中已有的其它修改不要回滚、不要混入提交。
- 提交前必须查看 `git status --short`，确认 staged 文件范围正确。
