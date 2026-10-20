# LratCheck 初审意见整改记录

评审指出原项目主要覆盖文本 LRAT 解析、校验及统计，缺少其他主流格式、
证明生成衔接及跨平台交付。本次扩展保留原有检查器，补充从 DRAT 到 LRAT
证书生成、二进制交换和可调用的 JavaScript 接口。

| 反馈 | 本次交付 | 验证方式 |
| --- | --- | --- |
| 仅支持文本 LRAT | 支持文本/二进制 LRAT 与文本/二进制 DRAT 输入 | 四种格式共用语义检查；整数边界、截断及错误引用回归 |
| 没有证明生成衔接 | 原生 DRAT 校验，自动发现 RUP/RAT 传播原因并生成 LRAT 证书 | 独立 C checker 校验本项目的输出，包含真正的 RAT 步骤 |
| 缺少完整工具链 | 固定版本 CaDiCaL 输出证明，本项目检查和转换，再由外部工具复核 | 9 组自建 CNF、4 种格式，共 36 份实际求解器输出；附 SAT 与截断反例 |
| 跨平台能力不足 | Windows/Linux CLI、无文件依赖的 MoonBit 核心、Node.js ESM 接口和浏览器例子 | 双系统 CI、JavaScript 实际调用测试；浏览器页面提供手工验证入口 |

## 已有证据

- `60ccba0`：DRAT 校验与 LRAT 提示生成，独立 C checker 接受转换结果。
- `e784b48`：二进制 LRAT/DRAT 与命令行格式交换。
- `1c15e6d`、`653b2fc`：导出接口、求解器互操作、Windows/Linux 流程及运行配置修正。
- [完整 CI 记录](https://github.com/clbbbb/lrat-check/actions/runs/39443148621)：Windows、Linux 和 solver-interop 全部通过。
- 收尾新增真值表反例验证及 blocked RAT 回归，本地共 79 项 MoonBit 测试通过。
- `solver-interop` 工件包含 CNF、原始证明、转换后的证明及 `report.json`；参考工具 commit、格式、输入/输出大小和整次 CLI 耗时均有记录。后续运行亦记录可用的 GNU time 最大 RSS。

## 复现

```sh
moon update
moon check --deny-warn
moon test --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
moon build --target js --release --deny-warn bindings
node scripts/test_js.mjs
bash scripts/cross_check_lrat.sh
python3 scripts/solver_interop.py
```

独立求解器集成脚本在 Linux 上运行，需要 gcc、make、Python 3.12+ 和网络。
外部源码只下载到临时目录，不进入项目仓库。浏览器例子按 README 启动，
当前验证环境没有可用浏览器，页面未在本机会话中实际点击验证；Node.js
导出接口已实测。此处不把 Node 测试表述成浏览器 UI 测试。

## 交付边界与发布状态

- 证书生成以 CNF 和已有 DRAT 推导为输入，补全 LRAT 提示；不从 CNF 单独搜索证明。
- DRAT 默认忽略单位子句删除，与 DRAT-trim 的策略一致。API 可显式选择实际删除语义；两种策略不能混称。
- 二进制 LRAT 对齐 CaDiCaL 1.9.0 及以后的 signed-ID 编码；文字和 ID 的绝对值限正 31 位范围。
- 转换器使用有限工作预算，超限有独立资源错误；整份输入及输出记录驻留内存，不宣称超大证明流式处理或工业 checker 的性能。
- lrat-trim 不校验一般的负 RAT 前件；这里用它独立读取二进制并转换，再由支持 RAT 的 C checker 校验其输出，而非宣称它支持全部 RAT 校验。
- 以上是 GitHub 源码的扩展内容，原 Mooncakes `0.1.0` 不包含本次扩展。新包发布和报名表补交需单独执行。
- 本记录说明实际交付和验证范围，不代表赛方已批准扩展题目或已通过重新审核。
