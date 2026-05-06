# WYTurtle

WYTurtle 是一份基于 Turtle/MaNGOS 1.12 服务端源码整理的 Windows 可编译工程，目标客户端版本为 `CLIENT_BUILD_1_12_1`。

当前工程已经集成并默认启用 Lua 脚本兼容层，用来在 Turtle 1.12 核心上运行一部分从 3.3.5 Eluna 迁移过来的自定义 Lua 功能。Lua 移植不是照搬 AzerothCore 3.3.5，而是按 Turtle 1.12 的真实系统做适配：有真实核心入口的功能尽量接入，没有真实系统支撑的 3.3.5 专属功能不会做假接口。

Lua 当前状态请看：

```text
docs/lua-port-status.md
```

## 目录说明

```text
src/                 服务端源码，包含 realmd、mangosd、game、scripts 等模块
dep/                 第三方依赖源码和 Windows 预编译库
sql/                 数据库结构、world 数据和更新 SQL
lua_scripts/         Lua 脚本目录，默认示例为 example.lua
docs/                项目文档和 Lua 移植状态记录
build_vs2022/        本机 VS2022 构建目录，不建议提交或手动改里面的文件
```

主要服务端程序：

```text
realmd.exe           登录服务
mangosd.exe          世界服务
lua52_compiler.exe   Lua 语法检查工具
```

## Windows 编译环境

推荐环境：

```text
Windows 11 x64
Visual Studio 2022，安装“使用 C++ 的桌面开发”
CMake 3.16 或更新版本
Git for Windows，可选但推荐
MySQL Server 5.7，用于运行服务端数据库
ACE，当前工程使用 E:\deps\ACE_wrappers
```

说明：

- 编译 MySQL 客户端库、OpenSSL、Zlib 等会优先使用仓库里的 `dep/windows`，一般不需要单独安装这些开发库。
- MySQL 5.7 是运行数据库服务用的版本；编译阶段主要用的是 `dep/windows/include/mysql` 和 `dep/windows/lib/.../libmySQL.lib`。
- 默认使用 `USE_STD_MALLOC=ON`，所以通常不需要额外安装 TBB。
- 默认启用 `USE_LUA=ON` 和 `USE_SCRIPTS=ON`。

## 准备 ACE

当前本机验证过的 ACE 位置是：

```text
E:\deps\ACE_wrappers
```

CMake 会从这里查找：

```text
E:\deps\ACE_wrappers\ace
E:\deps\ACE_wrappers\lib\ACE.lib
```

如果你的机器没有 ACE，可以按下面方式准备：

1. 下载 ACE 源码包并解压到 `E:\deps\ACE_wrappers`。
2. 用 Visual Studio 打开 ACE 自带的解决方案，例如 `ACE_vs2019.sln` 或 `ACE_wrappers_vs2019.sln`。VS2022 可以升级打开。
3. 选择 `x64` 和 `Release`，编译 ACE。
4. 确认生成了 `E:\deps\ACE_wrappers\lib\ACE.lib` 和 `ACE.dll`。

如果你把 ACE 放在别的位置，后面的 CMake 命令里把 `-DACE_ROOT=...` 改成你的实际路径。

## 生成 VS2022 工程

建议使用 PowerShell 或 “Developer PowerShell for VS 2022”。

```powershell
cmake -S E:\GIT\WYTurtle `
      -B E:\GIT\WYTurtle\build_vs2022 `
      -G "Visual Studio 17 2022" `
      -A x64 `
      -DPREFIX=E:/TurtleBY `
      -DACE_ROOT=E:/deps/ACE_wrappers `
      -DUSE_LUA=ON `
      -DUSE_SCRIPTS=ON `
      -DUSE_EXTRACTORS=OFF
```

参数说明：

```text
-S                  源码目录
-B                  构建目录
-G                  使用 Visual Studio 2022 生成器
-A x64              生成 64 位工程
-DPREFIX            安装输出目录
-DACE_ROOT          ACE 根目录
-DUSE_LUA=ON        启用 Lua 脚本兼容层
-DUSE_SCRIPTS=ON    编译脚本模块
-DUSE_EXTRACTORS=OFF 不编译地图提取工具
```

本项目要求 out-of-source build，不要直接在源码根目录里生成 CMakeCache。

## 编译和安装

完整编译并安装到 `E:\TurtleBY`：

```powershell
cmake --build E:\GIT\WYTurtle\build_vs2022 --config Release --target INSTALL
```

只编译世界服：

```powershell
cmake --build E:\GIT\WYTurtle\build_vs2022 --config Release --target mangosd -- /m
```

只编译登录服：

```powershell
cmake --build E:\GIT\WYTurtle\build_vs2022 --config Release --target realmd -- /m
```

编译 Lua 语法检查工具：

```powershell
cmake --build E:\GIT\WYTurtle\build_vs2022 --config Release --target lua52_compiler -- /m
```

编译成功后，安装目录通常是：

```text
E:\TurtleBY
```

里面会包含服务端 exe、配置文件和运行所需 DLL。当前工程的 Lua 脚本目录为：

```text
E:\TurtleBY\lua_scripts
```

如果需要先检查 Lua 脚本语法：

```powershell
E:\TurtleBY\lua52_compiler.exe -p E:\GIT\WYTurtle\lua_scripts\example.lua
```

## 数据库和运行提示

运行服务端前需要准备 MySQL 5.7，并导入对应数据库：

```text
sql\_structure_logon.sql
sql\_structure_characters.sql
sql\_structure_logs.sql
sql\world_1171_release.zip
sql\database_updates\*.sql
```

实际数据库名、账号、端口以 `realmd.conf` 和 `mangosd.conf` 为准。常见本地测试配置为：

```text
MySQL: 127.0.0.1:3306
版本: 5.7
```

启动顺序：

```powershell
E:\TurtleBY\realmd.exe
E:\TurtleBY\mangosd.exe
```

如果要在测试服目录运行，可以把 `E:\TurtleBY` 里编译好的服务端文件同步到你的测试目录，例如：

```text
E:\WYwg1.0\server
```

注意：如果 `mangosd.exe` 或 `realmd.exe` 正在运行，Windows 可能会锁定文件。同步新版本前应先关闭正在运行的服务端窗口。

## Lua 脚本

Lua 脚本默认放在：

```text
lua_scripts/
```

安装后对应：

```text
E:\TurtleBY\lua_scripts
```

示例脚本：

```text
lua_scripts\example.lua
```

Lua 移植状态、已支持事件、对象方法、1.12 不适用项和已知差异都记录在：

```text
docs\lua-port-status.md
```

重要原则：

- Turtle 1.12 没有真实载具系统，所以不移植 Vehicle 事件和 Vehicle API。
- 没有真实核心入口的动作接口不做“可注册但不会触发”的假实现。
- 3.3.5 专属系统，例如 Halaa、部分 LFG、公会日历、直接打开邮箱包等，按 Turtle 1.12 的实际能力跳过或另行设计。

## 常见问题

### CMake 提示找不到 ACE

确认 `ACE_ROOT` 指向 ACE 根目录，并且下面文件存在：

```text
E:\deps\ACE_wrappers\ace
E:\deps\ACE_wrappers\lib\ACE.lib
```

重新配置：

```powershell
cmake -S E:\GIT\WYTurtle -B E:\GIT\WYTurtle\build_vs2022 -G "Visual Studio 17 2022" -A x64 -DPREFIX=E:/TurtleBY -DACE_ROOT=E:/deps/ACE_wrappers
```

### CMakeCache 配置乱了

删除构建目录后重新生成：

```powershell
Remove-Item -LiteralPath E:\GIT\WYTurtle\build_vs2022 -Recurse -Force
cmake -S E:\GIT\WYTurtle -B E:\GIT\WYTurtle\build_vs2022 -G "Visual Studio 17 2022" -A x64 -DPREFIX=E:/TurtleBY -DACE_ROOT=E:/deps/ACE_wrappers -DUSE_LUA=ON -DUSE_SCRIPTS=ON
```

### Release 和 Debug 库不要混用

Release 编译使用：

```text
dep\windows\lib\x64_release
```

Debug 编译会使用：

```text
dep\windows\lib\x64_Debug
```

如果遇到链接错误，先确认当前 `--config` 和依赖库目录匹配。

### 修改 Lua 后是否必须重编译

普通 Lua 脚本修改不需要重编译 C++，重启 `mangosd` 或按服务端支持的重载流程加载即可。只有修改 `src/game/LuaEngine` 或其他 C++ 源码时才需要重新编译。
