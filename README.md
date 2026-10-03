# RE2 Legacy Trainer

《生化危机 2 重制版》的 REFramework 修改器，按原 `Re2 Trainer.exe` 迁移 26 项游戏功能及其可见子选项。保留左侧功能列表、右侧选项、原默认快捷键，以及原版升降幅度。

**当前版本：0.1.5-beta。14 项经用户游戏内测试通过，12 项待测试。** “真隐身模式”标为待测试。具体清单见下方和 [验收记录](validation/gameplay_acceptance.json)。

本项目通过 **REFramework 执行 Lua 脚本**。完整安装还需要随包提供的 **原生辅助 DLL**，由 REFramework 的 PluginLoader 加载：可交互提示距离、移动速度、瞬移&穿墙、人物大小修改这四项依赖辅助 DLL。安装后不需要运行原 `Re2 Trainer.exe`。

- [下载安装包（含修订安装说明）](https://github.com/LQB9/RE2LegacyTrainer/releases/download/v0.1.5-beta/RE2LegacyTrainer-0.1.5-beta-docs1.zip)
- [项目主页](https://github.com/LQB9/RE2LegacyTrainer)
- [问题反馈](https://github.com/LQB9/RE2LegacyTrainer/issues)

## 0.1.5 的改动

- 保存功能开关状态，下一次启动游戏或重载脚本时自动恢复；参数、语言、主功能及坐标按钮快捷键一并保留。
- 保存、读取、上升、下降的历史操作不会在重载后再次执行。保存点本身沿用原版的当前游戏会话范围。
- 滚动条加宽到 18 像素，并使用亮色滑块，方便找到列表后面的功能。
- 修改器字体放大到 26 像素，按钮及窗口尺寸同步放大。
- 界面底部显示 GitHub 项目地址，点击复制链接。
- “真隐身模式”选项标注“待测试”。

## 兼容范围

已核对的环境：Windows x64、Steam Build **11636119**、TDB **70**，REFramework 构建 **5bae470**，原生 API **1.10**。游戏 EXE SHA256：

```text
6CAAA815BF9E95F8A841BC81FDF29FEC55E836C87BAB8A76D55C69BEF9ADA941
```

安装脚本会校验这个游戏版本。本发布不修改游戏 EXE，也不分发原修改器、游戏程序或 Windows 字体。原生辅助 DLL 沿用实测的 0.1.4（状态接口版本 4）。

## REFramework 出处与安装

REFramework 是 **praydog** 发布的独立开源项目，本修改器依赖它运行。官方出处：

- [REFramework 源码与官方说明](https://github.com/praydog/REFramework)
- [官方稳定版下载](https://github.com/praydog/REFramework/releases)
- [官方安装说明](https://github.com/praydog/REFramework#installation)
- [Lua 与插件接口文档](https://cursey.github.io/reframework-book/)

1. **关闭游戏。** 在 Steam 库右键游戏 → 管理 → 浏览本地文件，找到包含 `re2.exe` 的文件夹。这是下面所有步骤使用的“游戏根目录”。默认安装路径可能不同，以实际找到的目录为准。
2. 打开官方稳定版下载页面，选择 RE2 对应的 **`RE2.zip`**。本项目核对的是 TDB 70 游戏版本，`RE2_TDB66.zip` 对应另一套旧版游戏接口。编写说明时官方稳定版为 [v1.5.9.1](https://github.com/praydog/REFramework/releases/tag/v1.5.9.1)，可[直接下载 RE2.zip](https://github.com/praydog/REFramework/releases/download/v1.5.9.1/RE2.zip)。本修改器实际游戏测试使用的框架构建为 `5bae470`；尚未逐项重测其他框架构建。
3. 按官方非 VR 安装说明，从压缩包中取出 **`dinput8.dll`**，放在游戏根目录中，与 **`re2.exe` 同级**。已有 REFramework 时可直接进入下一节；框架由官方项目维护，修改器 ZIP 不包含它。

## 安装本修改器

**无论选择安装脚本还是手工复制，都必须先安装 REFramework。** 上一节说明了框架的官方下载和安装方法：官方 `RE2.zip` 中的 `dinput8.dll` 要放在含 `re2.exe` 的游戏根目录中。本项目的安装脚本只安装修改器 Lua、辅助 DLL 和本机字体，**不会下载或安装 REFramework**；缺少 `dinput8.dll` 时会停止并提示 `REFramework is not installed.`。

已有 REFramework 并能在游戏中按 Insert 打开框架菜单的用户，不需要重复安装框架。

### 安装前：找到自己的游戏目录

1. 在 Steam 库中右键《生化危机 2 重制版》→ **管理 → 浏览本地文件**。
2. 确认打开的文件夹中能看到 **`re2.exe`**。
3. 点击文件资源管理器顶部的**地址栏**，复制完整文件夹路径。复制的是地址栏，不是右上角搜索框。
4. 这个路径就是后面需要填写的“游戏目录”。它可能在 C、D、E、F 等任何盘符，不要求使用作者电脑上的路径。

两种目录的用途如下，请分别复制自己的实际路径：

| 目录 | 怎样确认 | 用在哪里 |
|---|---|---|
| 修改器安装包目录 | 解压后能看到 `Install.ps1`、`manifest.json` 和 `reframework` 文件夹 | 在 PowerShell 中用 `Set-Location` 进入这里，运行安装脚本 |
| 游戏目录 | Steam“浏览本地文件”打开、里面能看到 `re2.exe` | 填在 `-GameDirectory` 后；手工安装时也复制到这个目录 |

### 方式一：运行安装脚本（先安装 REFramework）

#### 1. 下载并解压修改器

从本项目 [Releases](https://github.com/LQB9/RE2LegacyTrainer/releases/tag/v0.1.5-beta) 下载 **`RE2LegacyTrainer-0.1.5-beta-docs1.zip`**。这是补充安装说明的包，Lua 和 DLL 与原 0.1.5 测试版一致。

右键 ZIP → **全部解压**。打开解压后的 **`RE2LegacyTrainer`** 文件夹，确认能看到 **`Install.ps1`**，然后从地址栏复制这个文件夹的完整路径。不要直接在压缩包预览窗口内运行脚本。

#### 2. 打开截图中的 Windows PowerShell 窗口

按键盘 **Win + R** 打开“运行”窗口，输入 **`powershell`**，按 Enter。这就是截图中的 Windows PowerShell 命令窗口。也可以打开开始菜单，搜索 **Windows PowerShell**，点击“打开”。[微软说明](https://learn.microsoft.com/en-us/powershell/scripting/windows-powershell/starting-windows-powershell)

在窗口中输入下面这条命令，将**单引号内的整段占位文字**替换为刚才复制的**安装包目录**，保留两端英文单引号，然后按 Enter：

```powershell
Set-Location -LiteralPath '这里粘贴含 Install.ps1 的解压后文件夹路径'
```

例如，安装包解压到了 `E:\ModDownloads\RE2LegacyTrainer`，这一条就改成：

```powershell
Set-Location -LiteralPath 'E:\ModDownloads\RE2LegacyTrainer'
```

示例路径只演示格式，请使用自己的实际路径。输入下面这条检查命令并按 Enter，应返回 **`True`**；返回 `False` 表示进入的文件夹不对，需要找到含 `Install.ps1` 的文件夹再执行 `Set-Location`：

```powershell
Test-Path -LiteralPath '.\Install.ps1'
```

#### 3. 填入自己的游戏目录并安装

保持 RE2 关闭。在同一个 PowerShell 窗口输入下面这条命令，把 **`-GameDirectory` 后单引号内的整段占位文字**替换为 Steam“浏览本地文件”打开的**游戏目录**，保留两端英文单引号，然后按 Enter：

```powershell
.\Install.ps1 -GameDirectory '这里粘贴含 re2.exe 的游戏文件夹路径'
```

假设另一位用户的游戏实际装在 `F:\Games\SteamLibrary\steamapps\common\RESIDENT EVIL 2 BIOHAZARD RE2`，安装命令就是：

```powershell
.\Install.ps1 -GameDirectory 'F:\Games\SteamLibrary\steamapps\common\RESIDENT EVIL 2 BIOHAZARD RE2'
```

**替换的是单引号内的完整目录，包括盘符和所有子文件夹。** 不要只改盘符，不要在最后加 `\re2.exe`，也不要填写修改器的解压目录。游戏文件夹名中的空格以地址栏复制到的实际路径为准，不要手动增减。

命令开头的 `.\Install.ps1` 和 `-GameDirectory` 保持不变；`.\` 表示运行当前安装包文件夹中的脚本。不需要输入 PowerShell 提示符中的 `PS ...>`。

若提示“无法加载……因为在此系统上禁止运行脚本”，仍在同一个安装包目录中执行下面的命令，将单引号内替换为**同一个游戏目录**：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -GameDirectory '这里粘贴含 re2.exe 的游戏文件夹路径'
```

此命令只对这一次脚本运行使用该执行策略。安装脚本会校验游戏版本和包内文件、备份同名旧插件、安装 Lua 和辅助 DLL，并从本机 Windows 复制中文字体。看到 **`Installed and verified both files.`** 表示两个插件文件安装完成。随后按下面“启动、重载与卸载”的说明启动游戏。

脚本只接受“兼容范围”中已核对的游戏 EXE；版本不同会停止安装，需要先确认兼容性。

### 方式二：手工复制（同样先安装 REFramework）

1. **关闭游戏，并先按上面的官方步骤安装 REFramework。** 确认游戏根目录中同时有 `re2.exe` 和框架的 `dinput8.dll`。
2. 下载并完整解压本修改器 ZIP，打开解压后的 `RE2LegacyTrainer` 文件夹。这是下表的**来源**。
3. 在另一个文件资源管理器窗口中，通过 Steam → 管理 → 浏览本地文件打开自己的游戏目录。这是下表的**目标起点**。目标使用自己的实际目录，不使用作者电脑上的 D 盘示例。
4. 按下表分别复制文件；目标子文件夹不存在时新建。已有同名本修改器文件时可先备份再替换。**Lua 和辅助 DLL 两个文件都要复制**。

| 从解压后的安装包取出 | 复制到自己游戏目录下 |
|---|---|
| `RE2LegacyTrainer\reframework\autorun\re2_legacy_trainer.lua` | `reframework\autorun\re2_legacy_trainer.lua` |
| `RE2LegacyTrainer\reframework\plugins\re2_legacy_native.dll` | `reframework\plugins\re2_legacy_native.dll` |

例如，自己的游戏根目录为 `F:\Games\RE2`，Lua 的目标位置就是 `F:\Games\RE2\reframework\autorun\re2_legacy_trainer.lua`，DLL 的目标位置就是 `F:\Games\RE2\reframework\plugins\re2_legacy_native.dll`。这个例子只演示如何在游戏目录后拼接子目录；实际根目录要从 Steam 复制。

5. 中文界面还需要本机字体：按 **Win + R**，输入 **`%WINDIR%\Fonts`** 并按 Enter，打开自己 Windows 的字体目录。复制微软雅黑文件 **`msyh.ttc`** 到**游戏目录的 `reframework\fonts` 文件夹**；目标文件夹不存在时新建，将复制出的文件重命名为 **`re2_legacy_font.ttc`**。字体窗口可能显示“微软雅黑 / Microsoft YaHei”这个名称，复制后确认文件名为 `msyh.ttc`。原 Windows 字体文件保留。没有这个字体时可选择 ENG；安装脚本会自动完成这一步，手工安装需要自己复制。字体不随项目分发。

正确的目标目录结构如下，最顶层是**你自己的游戏根目录**：

```text
你的游戏根目录（包含 re2.exe）
├── re2.exe
├── dinput8.dll                          ← 来自官方 REFramework 的 RE2.zip
└── reframework
    ├── autorun
    │   └── re2_legacy_trainer.lua       ← 本修改器 Lua 脚本
    ├── plugins
    │   └── re2_legacy_native.dll        ← 本修改器辅助 DLL
    └── fonts
        └── re2_legacy_font.ttc          ← 本机字体的副本
```

复制完成后，Lua 应位于 `游戏根目录\reframework\autorun\`，不要出现多套一层 `RE2LegacyTrainer` 或 `reframework\reframework` 的情况。`dinput8.dll` 与 `re2.exe` 同级；它来自 REFramework 下载包，不在修改器 ZIP 中。

### 启动、重载与卸载

完成任一种安装方式后，启动游戏，按 **Insert** 打开 REFramework，展开 **ScriptRunner → Script Generated UI → RE2 Legacy Trainer / 原版修改器 (26)**，勾选“显示修改器面板”。读入存档后面板应显示“游戏正在运行中”。Lua 从 `autorun` 自动加载，辅助 DLL 从 `plugins` 自动加载。

**Reset Scripts** 按钮位于 REFramework 的 **ScriptRunner** 下，只用于重新加载 Lua。首次安装 DLL 或替换 DLL 后，需要关闭并重新启动游戏才能加载它。从 0.1.4 更新到本版时 DLL 没有变动；只替换 Lua 后 Reset Scripts 即可。

设置保存在游戏目录的 `reframework\data\re2_legacy_settings.json` 中，开关、参数、语言和快捷键会在下次启动恢复。点击“恢复设置”会关闭所有功能并恢复默认参数和键位。

卸载本修改器时先关闭游戏，再移除 `re2_legacy_trainer.lua` 和 `re2_legacy_native.dll`。本修改器的字体及以 `re2_legacy_` 开头的配置文件可按需一并移除；REFramework 和其他插件使用的文件保留。

## 使用

在左侧选择功能，在右侧修改参数或热键。把鼠标放在左侧列表内滚动，可查看全部 26 项。“极速开枪”是第 18 项，位于“湿身效果”和“无敌”之间。

默认快捷键区分左右修饰键，小键盘需要 NumLock 开启：

- 1–10：左 Ctrl + 小键盘 1–9、0。
- 11–20：左 Alt + 小键盘 1–9、0。
- 21–26：左 Win + 小键盘 1–6。

保存、读取、上升、下降默认未绑定，右侧各按钮下可设置组合键；Esc 取消设置，清除解除绑定。同一组合键重新分配时旧绑定会清除，按住不会重复触发。

穿墙采用正常移动并拦截重力、贴地和防穿透位置修正的设计。升降按原版每帧 0.1、持续 16 帧，单次名义距离 1.6；读取保存点后做短暂三轴稳定处理。没有角色控制器 warp 调用。

## 游戏内测试状态

测试来源为用户提供的 0.1.4 截图；勾选项通过，红框第 21 项按用户后续要求记为“待测试”，未勾选项也待测试。以下状态用于说明验收范围，自动检查不能替代待测试项的实际游戏效果。

| 状态 | 功能 |
|---|---|
| 通过（14） | 无限生命、无消耗、一击即死、暴君无法复活、无后坐力、超级精准度、包裹格数、移动速度、瞬移&穿墙、视角距离、湿身效果、极速开枪、无敌、人物大小修改 |
| 待测试（12） | 可交互提示距离、游戏时间、存档次数、开箱次数、治疗次数、走动步数、动态难度、真隐身模式、免疫中毒、混合药草增益、艾达秒入侵、锁定倒计时 |

截图展示的是 0.1.4 的测试界面；0.1.5 增加开关记忆、滚动条高亮、更大字体和项目链接。“真隐身模式”仍需验证敌人行为，当前版本没有新增该项修复。

![前半部分测试截图](docs/screenshots/feature-list.png)
![后半部分测试截图；红框项目待测试](docs/screenshots/more-features.png)

## 功能与子选项

| 编号 | 功能 | 默认热键 | 原版子选项／参数 |
|---|---|---|---|
| 1 | 无限生命 | LCtrl+N1 | 敌人也一样，默认关闭 |
| 2 | 无消耗 | LCtrl+N2 | 保留数量增加 |
| 3 | 一击即死 | LCtrl+N3 | 排除当前玩家 |
| 4 | 暴君无法复活 | LCtrl+N4 | 开关 |
| 5 | 无后坐力 | LCtrl+N5 | 开关 |
| 6 | 超级精准度 | LCtrl+N6 | 原版内部值 100 |
| 7 | 包裹格数 | LCtrl+N7 | 8–20，默认 20 |
| 8 | 可交互提示距离 | LCtrl+N8 | 1–50，默认 15，步进 1 |
| 9 | 游戏时间 | LCtrl+N9 | 时／分／秒，默认 0 |
| 10 | 存档次数 | LCtrl+N0 | 自定义次数，存档后生效 |
| 11 | 开箱次数 | LAlt+N1 | 自定义次数，开箱后生效 |
| 12 | 治疗次数 | LAlt+N2 | 自定义次数，治疗后生效 |
| 13 | 走动步数 | LAlt+N3 | 自定义步数，走动时生效 |
| 14 | 移动速度 | LAlt+N4 | 0.5–5，默认 2，步进 0.1 |
| 15 | 瞬移&穿墙 | LAlt+N5 | 随意上升／下降；保存、读取、上升、下降及各自热键 |
| 16 | 视角距离 | LAlt+N6 | 距离 0–20，默认 1.3；高度 -5–5，默认 0；瞄准恢复、平滑镜头默认开启；增幅 0.05–0.5，默认 0.2 |
| 17 | 湿身效果 | LAlt+N7 | 湿度 0–1，默认 1，步进 0.1 |
| 18 | 极速开枪 | LAlt+N8 | 开关 |
| 19 | 无敌 | LAlt+N9 | 开关 |
| 20 | 动态难度(分数) | LAlt+N0 | 0–12999，默认 12999，步进 100 |
| 21 | 真隐身模式 | LWin+N1 | 开关 |
| 22 | 人物大小修改 | LWin+N2 | 0.1–5，默认 1；是否修改碰撞体积，默认关闭 |
| 23 | 免疫中毒 | LWin+N3 | 开关 |
| 24 | 混合药草增益状态 | LWin+N4 | 原版内部值 180 秒 |
| 25 | 艾达秒入侵 | LWin+N5 | 开关 |
| 26 | 锁定倒计时 | LWin+N6 | 开关 |

## 构建与检查

源码在 `src/`，Lua 和原生测试在 `tests/`。准备 Zig 0.13.0 与 Python 3，再执行：

```powershell
python -m pip install -r tests/requirements.txt
.\Build.ps1 -Zig 'C:\tools\zig\zig.exe' -Verify -Python 'python'
```

构建结果位于 `build/`。检查包含 25 组 Lua 行为与界面验证、6 组原生坐标动作验证及 6 项 DLL ABI 检查。原生测试运行于独立模拟进程，不向游戏注入测试对象。

发布包中包含文件校验清单 `manifest.json`。用户的设置、存档、内存转储、机器路径和原始 EXE 不包含在项目或发布包内。

## 依赖

[REFramework](https://github.com/praydog/REFramework) API 头文件遵循 MIT，许可证在 `licenses/REFramework-MIT.txt`；[MinHook](https://github.com/TsudaKageyu/minhook) 与 HDE 的许可证保留在 `src/minhook/LICENSE.txt`。接口参考：[REFramework 文档](https://cursey.github.io/reframework-book/)。
