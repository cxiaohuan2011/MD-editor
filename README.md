# md-editor

一个轻量、简单的 macOS Markdown 阅读和编辑工具。体积小、打开快、上手容易。输入的内容不会被程序改写，保存不弹窗，完全本地运行。

![md-editor 浅色界面](docs/screenshots/hero.png)

![md-editor 深色界面](docs/screenshots/dark.png)

## 功能

- 边写边看：左边编辑，右边实时预览
- 文件树：浏览目录、新建、重命名、拖拽
- 多标签页，可恢复会话（关掉后重开，之前打开的文件还在）
- 大纲导航，预览与大纲同步滚动
- Markdown 规范检查：不规范的地方标红、悬停看正确写法、按 `Tab` 一键修正（从不自动改你的文字）
- 搜索：全局搜索、按文件名跳转、全文搜索
- 导出 HTML
- 深色 / 浅色主题
- 双击 `.md` 文件直接打开

## 系统要求

- macOS 10.15 (Catalina) 及以上
- Apple Silicon 与 Intel 均可（通用二进制）

## 下载与安装

1. 到 [Releases](https://github.com/cxiaohuan2011/MD-editor/releases) 下载最新的 `md-editor_*_universal.dmg`。
2. 打开 dmg，把 **md-editor** 拖进「应用程序 / Applications」。
3. 首次打开前先去隔离（见下）。

### 提示「已损坏」/ 打不开？

本应用是自签名、未经 Apple 公证，macOS 会拦截从网络下载的应用并提示「已损坏」或「无法打开」。这不是应用真的坏了，只是没买苹果的签名。

打开「终端 / Terminal」，运行一次下面这行即可解除：

```bash
xattr -dr com.apple.quarantine /Applications/md-editor.app
```

之后双击就能正常打开，以后不再拦。

> 只对你信任来源的应用做去隔离。本应用完全本地运行、不联网、不收集任何数据。

## 许可

闭源免费软件，免费供个人非商业使用，版权归作者所有，禁止再分发、转售、反编译。详见 [LICENSE](LICENSE)。
