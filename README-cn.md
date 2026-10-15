# DualTime

DualTime 是一个原生 macOS 菜单栏应用，用于显示一个可自定义时区的第二个时钟。它使用系统菜单栏的样式，并在 macOS 允许的范围内尽量靠近系统时间显示。

[English README](README.md)

应用只支持配置一个自定义时区。时区以 IANA identifier 保存，因此夏令时规则和 UTC 偏移变化由系统时区数据库自动处理。

## 功能

- 英文格式：`Wed Oct 14 09:30`
- 中文格式：`10月14日 周三 09:30`
- 24 小时制，可选择显示秒数
- 可选择显示日期和星期
- 可选择闪烁时间分隔符
  - 不显示秒时，闪烁 `HH:mm` 中间的分隔符
  - 显示秒时，`HH:mm` 保持稳定，只闪烁 `mm:ss` 中间的分隔符
- 固定菜单栏状态项宽度，只在显示设置或时区变化时重新计算
- 使用系统 San Francisco 字体、等宽数字和右对齐文本
- 支持搜索 IANA 时区列表，常用城市置顶
- 自动处理夏令时和 UTC 偏移
- 支持中文和 English 设置界面
- 可通过 `SMAppService` 设置登录时启动
- 使用 accessory application 模式常驻菜单栏，不显示在 Dock 中
- 左键打开设置，右键提供设置和退出操作
- 使用浅色、单色的双时钟应用图标

## 系统要求

- macOS 14 或更高版本
- Apple Silicon 或 Intel Mac
- Xcode 26 或更高版本，用于打开项目并构建

## 构建

```sh
xcodebuild -project DualTime.xcodeproj -scheme DualTime -configuration Release -sdk macosx -derivedDataPath .build-universal ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
```

本地 Universal 2 应用位于 `dist/DualTime.app`，同时包含 `arm64` 和 `x86_64` 架构。应用未签名，适合本地使用。项目中的图标资源位于 `DualTime/Assets.xcassets`。

## 测试

```sh
xcodebuild -project DualTime.xcodeproj -scheme DualTime -configuration Debug -sdk macosx -derivedDataPath .build-universal ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO test
```

菜单栏状态项的位置由 macOS 管理。应用使用固定宽度、系统菜单栏颜色，以及带等宽数字的 San Francisco 系统字体。公开 API 无法保证第三方状态项始终紧贴系统时间，也不能让它获得高于其他菜单栏项目的固定优先级，因此应用会在不使用私有 API 的情况下请求可用的最近位置。

默认显示每分钟边界更新一次。开启显示秒或闪烁分隔符后，刷新频率会变为每秒一次。应用只更新一个轻量的菜单栏文本状态项，默认模式不会进行不必要的每秒刷新。

## 分发和签名

项目默认构建未签名的本地 `.app`。从其他机器下载或复制未签名应用后，macOS 可能显示安全提示。公开分发需要 Developer ID 签名和 notarization，本仓库暂未配置这些流程。

仓库不会提交 `dist/DualTime.app`，应用通过上面的 Release 构建命令重新生成。构建目录、Xcode 用户状态文件和 Finder 元数据已加入 Git 忽略规则。
