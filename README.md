# Cursor 永久汉化工具

把 Cursor 自研界面（Agent/Chat 面板、Cursor Settings、内置浏览器、更改面板等）永久显示为简体中文，
无需每次用注入窗口启动。仅限 Windows，不需要 Node.js / git。

## 获取

打开 [github.com/zhang777hao/cursor-zh-tool](https://github.com/zhang777hao/cursor-zh-tool)，点 **Code → Download ZIP** 后解压。保持 `assets` 文件夹和 `cursor-zh.ps1` 在一起。

## 使用

1. 双击 `install.bat`，如弹出 UAC 提示请点"是"。
2. 完全退出并重新打开 Cursor。
3. （建议）在 Cursor 扩展里安装官方中文语言包 `MS-CEINTL.vscode-language-pack-zh-hans`，它负责菜单、命令面板等 VS Code 底座部分。

| 文件 | 作用 |
| --- | --- |
| `install.bat` | 安装 / 重新安装汉化 |
| `restore.bat` | 还原为英文原版 |
| `status.bat` | 查看当前状态 |

## 指定 Cursor 安装目录

不传路径时，工具按下面顺序找，用第一个同时包含 `Cursor.exe` 和 `resources\app\product.json` 的目录：

1. 你用 `-CursorPath` 指定的路径
2. 当前正在运行的 Cursor 进程所在目录
3. `%LOCALAPPDATA%\Programs\cursor`（默认的用户安装位置）
4. `%ProgramFiles%\cursor`
5. `%ProgramFiles(x86)%\cursor`（该环境变量存在时）

装在默认位置，或安装时 Cursor 正开着，直接双击 `install.bat` 即可。

装在其他盘、其他文件夹时，先找到安装目录：开始菜单里右键 Cursor → **打开文件所在的位置**。如果打开的是快捷方式，再右键该快捷方式 → **属性** → **打开文件所在的位置**。正确的目录里应有 `Cursor.exe` 和 `resources` 文件夹，不要指到 `Cursor.exe` 本身，也不要指到 `resources` 里面。

然后在本工具目录打开命令行，把路径换成你的：

```bat
install.bat -CursorPath "D:\Apps\cursor"
```

还原、查看状态同样可以带上路径：

```bat
restore.bat -CursorPath "D:\Apps\cursor"
status.bat -CursorPath "D:\Apps\cursor"
```

也可以直接调用脚本：

```powershell
.\cursor-zh.ps1 -Action install -CursorPath "D:\Apps\cursor"
```

三个操作都支持：`install`（安装）、`restore`（还原）、`status`（查看状态）。找不到目录时会提示你加上 `-CursorPath`。

## 原理

- 在 `resources\app\out\vs\code\electron-sandbox\workbench\` 下生成 `zh-inject.js`（翻译引擎 + 词典合并文件）。
- 给同目录的 `workbench.html` 末尾加一行 `<script src="./zh-inject.js">`（Cursor 的 CSP 允许同源脚本）。
- 同步更新 `product.json` 中 `workbench.html` 的校验和，避免"安装似乎已损坏"提示。
- 原始 `workbench.html` 备份在 `resources\app\zh-backup\`。
- 翻译脚本只改文本节点和 title/aria-label/placeholder/alt 属性，跳过代码编辑器、终端、AI 回复正文。

## 注意

- **Cursor 更新后汉化会失效**（文件被覆盖），再双击一次 `install.bat` 即可。
- **更新词典**：把新的 `zh-CN.json` 覆盖到 `assets\`，重新运行 `install.bat`。
- 本工具修改了 Cursor 安装目录下的文件。是否符合 Cursor 服务条款无法确认，使用风险自负。
- 内置浏览器里的网页、webview 内容不在翻译范围内。

## 来源与许可

翻译引擎 `assets/translator.js` 与词典 `assets/zh-CN.json` 来自开源项目
[Ver3ce/cursor-zh](https://github.com/Ver3ce/cursor-zh)（MIT License）。
本工具把它们由"运行时 CDP 注入"改为"静态嵌入"，其余安装逻辑为新写。分发时请保留本段署名。
