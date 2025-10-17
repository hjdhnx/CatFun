<img src="design/logo_round.svg" width="120" />

## 猫趣 🐈

使用 `Flutter` 构建, 支持 `Android` | `Windows` | `Macos` | `iOS` | `Linux`

![](https://img.shields.io/badge/macOS-000000?style=flat&logo=apple&logoColor=white)
![](https://img.shields.io/badge/iOS-000000?style=flat&logoColor=white)
![](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![](https://img.shields.io/badge/Windows-0078D6?style=flat&logo=windows&logoColor=white)
![](https://img.shields.io/badge/Android-3DDC84?style=flat&logo=android&logoColor=white)

**仅供学习参考, 请勿用于商业用途**

<!-- <img src="https://s2.loli.net/2025/08/12/dN78kJ1pAwqHYVZ.webp" width="120" /> -->

吹牛逼飞机群: https://t.me/catmovie1145

<details>
<summary>查看截图 🖼️</summary>

![首页](https://s2.loli.net/2025/09/14/QJmYod9K7G6cRkE.png)
![搜索](https://s2.loli.net/2025/09/14/8eEsAtpcM3dIX5C.png)
![TV](https://s2.loli.net/2025/09/14/trgyicKe47mf5I2.png)
![播放.jpg](https://s2.loli.net/2025/09/14/oO6iKgFPEth9M43.png)

</details>

### 安装指南 📦

#### **Macos 🍎**

`macOS` 可以使用 [homebrew](https://brew.sh) 快速安装, 也可自行下载安装

[![](https://img.shields.io/badge/-点我下载-blue?logo=github)](https://github.com/hjdhnx/CatFun/releases/latest/download/catmovie-mac.zip
)

> 更新的话可直接使用 `brew reinstall -f yoyo`

```bash
brew tap waifu-project/brew
brew install yoyo
```

#### **Linux 🐧**

[![](https://img.shields.io/badge/-点我下载-blue?logo=github)](https://github.com/hjdhnx/CatFun/releases/latest/download/catmovie-linux-x86_64.tar.gz)

在 `Archlinux` 需要安装两个包

```sh
yay -S webkit2gtk-4.1
yay -S xdg-user-dir xdg-utils
```

#### **Windows 🪟**

在 `Win10` 下, 如果使用 `Webview` 播放器内核, 需要额外安装 [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2)

> https://docs.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution

[![](https://img.shields.io/badge/-点我下载-blue?logo=github)](https://github.com/hjdhnx/CatFun/releases/latest/download/catmovie-windows.zip)

#### **Android 🤖**

大部分手机直接使用常用架构包就行了, 通用包兼容多种架构

- [常用(arm64-v8a)](https://github.com/hjdhnx/CatFun/releases/latest/download/catmovie.apk)
- [旧手机(armeabi-v7a)](https://github.com/hjdhnx/CatFun/releases/latest/download/catmovie-legacy.apk)
- [通用(universal)](https://github.com/hjdhnx/CatFun/releases/latest/download/catmovie-universal.apk)

#### **iOS 📱**

自签的话建议使用:

- [Sideloadly](https://sideloadly.io)
- [TrollStore](https://github.com/opa334/TrollStore)
- [NB助手](https://nbtool8.com)

> [!NOTE]
> apple-magnifier://install?url=https://github.com/hjdhnx/CatFun/releases/latest/download/catmovie.ipa

[![](https://img.shields.io/badge/-点我下载-blue?logo=github)](https://github.com/hjdhnx/CatFun/releases/latest/download/catmovie.ipa)

### 开发环境搭建 🛠️

#### **Windows 开发环境搭建指南**

如果你想在Windows上开发和运行这个项目，请按照以下步骤操作：

##### 1. 安装必要软件

**安装 Git**
- 下载并安装 [Git for Windows](https://git-scm.com/download/win)
- 安装时选择默认选项即可

**安装 Flutter SDK**
- 访问 [Flutter 中文网](https://flutter.cn/docs/get-started/install/windows)
- 下载 Flutter SDK 3.35.1 版本（推荐版本）
- 解压到 `C:\flutter` 目录
- 将 `C:\flutter\bin` 添加到系统环境变量 PATH 中

**安装 Visual Studio Code**
- 下载并安装 [VS Code](https://code.visualstudio.com/)
- 安装 Flutter 和 Dart 插件

**安装 Android Studio（可选，用于Android开发）**
- 下载并安装 [Android Studio](https://developer.android.com/studio)
- 安装 Android SDK 和模拟器

##### 2. 配置国内镜像（推荐）

打开命令提示符（CMD）或PowerShell，设置环境变量：

```cmd
setx FLUTTER_STORAGE_BASE_URL "https://mirrors.tuna.tsinghua.edu.cn/flutter"
setx PUB_HOSTED_URL "https://mirrors.tuna.tsinghua.edu.cn/dart-pub"
```

##### 3. 验证安装

```cmd
flutter doctor
```

确保所有检查项都通过（✓）。

##### 4. 克隆并运行项目

```cmd
# 克隆项目
git clone https://github.com/hjdhnx/CatFun.git
cd movie

# 获取依赖
flutter pub get

# 生成代码（如果需要）
flutter pub run build_runner build

# 运行项目（Windows桌面版）
flutter run -d windows

# 或者运行Web版本
flutter run -d chrome
```

##### 5. 常见问题解决

**问题1：flutter doctor 显示Android toolchain问题**
- 打开Android Studio
- 进入 SDK Manager 安装最新的 Android SDK
- 接受所有许可协议

**问题2：Windows桌面支持未启用**
```cmd
flutter config --enable-windows-desktop
```

**问题3：依赖安装失败**
- 确保网络连接正常
- 尝试使用VPN或更换网络
- 清除缓存：`flutter clean && flutter pub get`

##### 6. 开发工具推荐

- **IDE**: Visual Studio Code 或 Android Studio
- **调试**: Flutter Inspector（VS Code插件自带）
- **性能分析**: Flutter DevTools

##### 7. 项目结构说明

```
CatFun/
├── lib/                 # 主要源代码
│   ├── app/            # 应用程序模块
│   ├── shared/         # 共享组件
│   └── main.dart       # 应用入口
├── android/            # Android平台代码
├── windows/            # Windows平台代码
├── assets/             # 资源文件
└── pubspec.yaml        # 项目配置文件
```

### 文档 📜

- [制作源](./docs/create_source.md)
- [键盘快捷键](./docs/keyboard.md) 
- [解析VIP视频](./docs/parse_vip.md)
- [URL Scheme](./docs/protocol.md)
- [贡献代码](./docs/PR.md)
- [调试代码](./docs/start_dev.md)