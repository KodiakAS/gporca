# AI 维护与开发指引（GPORCA）

面向 AI 编程助手（Codex/Claude/…）：在本仓库内做 bug 修复、补测试、功能实现、性能优化与构建/CI 调整。
本仓库不包含与 GPDB 的联调流程；不要在此加入 GPDB 侧操作指引。

## 必读（硬约束）

- 先保证可构建/可测试：优先 `make test`；大改动至少跑 `RelWithDebInfo` + `Debug`。
- 遵循风格与低噪音 diff：`StyleGuide.md` + `.editorconfig`；避免全仓格式化/批量改名/无关 include 重排。
- 保持 C++11 + 零告警：不要引入 C++14+；新增代码需过 `-Werror`。
- 资源/异常模型保持一致：内存池 `GPOS_NEW(mp)` + `CRefCount/CAutoRef/CAutoP`；异常用 `GPOS_TRY/GPOS_CATCH/GPOS_RAISE`；析构不抛异常。
- 不提交生成物：`build*/`、临时文件、下载产物等不应进入版本库。

## 构建与测试（已验证）

```sh
make test
make test BUILD_DIR=build-rel   BUILD_TYPE=RelWithDebInfo
make test BUILD_DIR=build-debug BUILD_TYPE=Debug
```

只跑单个 ctest（避免全量构建：指定 `TARGET`）：

```sh
make test BUILD_DIR=build-rel TARGET=gporca_test CTEST_ARGS='-R gporca_test_CAggTest'
make test BUILD_DIR=build-rel TARGET=gpos_test   CTEST_ARGS='-R gpos_test_CBitSetIterTest -V'
```

直接跑测试二进制（在 `BUILD_DIR` 下执行）：

```sh
cd build-rel
./server/gporca_test -U CAggTest
./server/gporca_test -d ../data/dxl/minidump/TVFRandom.mdp
./libgpos/server/gpos_test -U CBitSetIterTest
```

## 依赖（最小说明）

- CMake `>= 3.10`；推荐 Ninja（根 `Makefile` 默认使用）。
- Xerces：CMake 用 `cmake/FindXerces.cmake` 查找；必要时显式指定：

```sh
make configure CMAKE_ARGS='-DXERCES_INCLUDE_DIR=/path/to/include -DXERCES_LIBRARY=/path/to/libxerces-c.so'
```

## 测试、Minidump 与 DXL

新增单元测试除了添加 `*.cpp` 还必须“注册”：

- `gporca_test`：`server/src/startup/main.cpp` + `server/CMakeLists.txt`（`add_orca_test(<TestClass>)`）
- `gpos_test`：`libgpos/server/src/startup/main.cpp` + `libgpos/server/CMakeLists.txt`（`add_gpos_test(<TestClass>)`）

Minidump（`.mdp`）：

- 代表性验证：`./server/gporca_test -d ...`
- 新增/更新用例通常需要把 `.mdp` 加入测试集合（例如 `server/src/unittest/gpopt/minidump/CICGTest.cpp` 或 `server/CMakeLists.txt` 的 `MDP_GROUPS`）
- 更新已有 `.mdp`（脚本会调用 `./server/gporca_test`，需在构建目录运行）：

```sh
cd build-rel
../scripts/fix_mdps.py --dryRun --logFile /path/to/ctest-output.txt
```

DXL/schema：

- `server/dxl.xsd` 在部分平台上无法用 `xmllint --schema` 直接校验（libxml2 不接受该 schema）。
- 用可执行验证替代：跑 minidump + 相关单测（例如 `gporca_test_CParseHandlerTest`、`gporca_test_CTranslator*Test`）。

## 常见改动入口（按仓库现状整理）

提示：优先参照同类实现并用 `rg` 搜索 enum/factory/CMake 的注册点。

- 新增 Xform：`libgpopt/include/gpopt/xforms/CXform.h`（`EXformId` 末尾追加）+ `libgpopt/include/gpopt/xforms/xforms.h`（include）+ `libgpopt/src/xforms/CXformFactory.cpp`（`Instantiate()` 注册）。
- 新增/改 Operator：`libgpopt/include/gpopt/operators/*`；若需进入 DXL/minidump，更新 `libgpopt/src/translate/CTranslator{DXLToExpr,ExprToDXL}.cpp`。
- 新增/改 DXL 元素：通常涉及 `server/dxl.xsd`、`dxltokens.{h,cpp}`、`CDXLOperator.h`、`CParseHandlerFactory.cpp`、`CDXLOperatorFactory.cpp` 以及 translators。
- 成本模型：`libgpdbcost/src/CCostModelGPDB.cpp`；对应单测常在 `server/src/unittest/gpopt/cost/CCostTest.cpp`。

## 版本/ABI（需要时）

- 影响功能/对外语义：按 `README.md` 约定 bump 根 `CMakeLists.txt` 的 `GPORCA_VERSION_*`。
- 破坏 ABI：bump `GPORCA_ABI_VERSION`（根 `CMakeLists.txt`）。

## 快速调试

- `./server/gporca_test -U <TestClass>` / `-d <file.mdp>`（参数定义见 `server/src/startup/main.cpp`）
- Debug 构建：`make build BUILD_DIR=build-debug BUILD_TYPE=Debug TARGET=gporca_test`
