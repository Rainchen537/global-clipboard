# 全局剪切板

一个轻量 macOS 原生应用，把 Windows `Win + V` 的文字剪贴板历史体验搬到 macOS。

## 功能

- 自动记录最近 12 条文字剪贴板内容
- 使用 `Option + Command + V` 在输入光标附近打开历史下拉框，靠近屏幕边缘时会自动向内侧避让
- 支持鼠标点击、数字键、方向键和 `Enter` 选择
- 选择后写回剪贴板，并自动向当前应用发送 `Command + V`
- 弹窗不会主动激活应用，尽量保留原输入框焦点
- 文本预览最多显示三行，超出后省略
- 菜单栏常驻图标，可显示历史、清空历史、打开权限设置或退出

## 构建

```zsh
./build.sh
```

构建完成后会生成：

```text
build/Global Clipboard.app
```

安装到用户应用目录：

```zsh
./install_app.sh
```

安装后位置：

```text
~/Applications/Global Clipboard.app
```

双击打开，或执行：

```zsh
open "$HOME/Applications/Global Clipboard.app"
```

## 权限

第一次选择历史记录自动粘贴时，macOS 会要求开启「辅助功能」权限。  
如果没有自动弹出，可以从菜单栏的剪贴板图标选择「打开自动粘贴权限」。

路径通常是：

```text
系统设置 -> 隐私与安全性 -> 辅助功能 -> Global Clipboard
```

没有开启权限时，应用仍会把选中的历史记录复制回系统剪贴板，只是不会自动粘贴。

如果系统设置里看起来已经开启，但应用仍提示没有权限，通常是重新构建后的代码签名记录和旧授权不一致。执行：

```zsh
./reset_accessibility.sh
```

然后重新打开应用，并在「辅助功能」里重新添加或勾选 `Global Clipboard`。
