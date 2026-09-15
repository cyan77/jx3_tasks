# 角色日程

一个干净、紧凑的多游戏、多角色任务与日程管理应用。

## 已实现

- 多游戏管理：游戏 → 角色 → 任务，支持添加、切换、改名和删除游戏。
- 角色管理：添加、切换、编辑、归档、删除角色。
- 批量建任务：一次选择多个角色，为每个角色生成独立任务记录。
- 周期：一次性、每日、每周、每月、每周目标次数、每月目标次数。
- 周目标任务支持可选周内日期；不选日期时按本周任意几天完成。
- 截止日期、备注，以及每个角色独立的完成状态。
- 角色待办、任务矩阵、日历/时间线、本周/月进度。
- 本地离线保存：使用 `shared_preferences`，首次启动带少量示例数据。
- 坚果云 WebDAV 手动上传 / 下载恢复。
- JSON 本地备份导入 / 导出。

## 运行

```bash
flutter pub get
flutter run
```

指定桌面平台：

```bash
flutter run -d macos
flutter run -d windows
flutter run -d linux
```

移动端可以直接用 Android Studio / Xcode 打开对应平台目录，或使用 `flutter devices` 选择设备后运行。

## 主要结构

```text
lib/
├── main.dart                 # 应用入口与本地数据加载
├── app.dart                  # MaterialApp 与全局状态
├── models/task_models.dart   # 游戏、角色、任务、周期与日期工具
├── data/local_store.dart     # SharedPreferences 离线存储与示例数据
├── data/sync_service.dart    # WebDAV 配置、连接、上传与下载
├── state/app_state.dart      # 任务、角色、切换与完成状态
├── theme/app_theme.dart      # 白/浅灰背景与紧凑工具应用样式
└── ui/
    ├── home_shell.dart       # 桌面侧栏 / 移动底部导航
    ├── task_editor.dart      # 新建任务、添加角色表单
    ├── game_editor.dart      # 添加与编辑游戏
    ├── screens/              # 待办、任务、日历、设置及管理页面
    └── widgets/common.dart   # 通用头像、进度条、任务勾选
```

## 检查

```bash
flutter analyze --no-fatal-infos
flutter test
flutter build macos --debug
```
