#!/usr/bin/env python3
"""auto-install 项目的文档一致性检查。

文档容易和代码脱节，这个脚本把「对不上」的地方自动找出来。检查项：

  1. 相对链接  —— Markdown 里的仓库内链接目标是否存在（跳过代码块）
  2. 函数名    —— 文档里写的项目函数（`Foo_Bar()`）是否真的定义了
  3. 常量名    —— 文档里写的项目常量（`$FOO_BAR`）是否真的定义了
  4. 文件路径  —— 文档里反引号引的仓库内文件是否存在
  5. 索引完整  —— docs/packages/ 下每份 <软件>.md 是否都在索引表里登记

用法：
    python tools/check_docs.py

退出码：全部通过 0，存在问题 1。

注意：模板 / 示例里的占位符（`$XXX_*`、`<软件名>`）和外部程序名（`7z.exe`）
      会被自动跳过，不当作错误。
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# 项目自己的函数前缀（用来区分 AutoIt 内置函数与 UDF）
FUNC_PREFIXES = (
    "Common_", "Logger_", "Config_", "Installer_",
    "Precheck_", "PrecheckSystem_", "PrecheckNetwork_", "PrecheckPower_",
    "PrecheckDriver_", "PrecheckAccount_",
    "GuiConfig_", "GuiConfigLayout_", "GuiConfigState_", "GuiPackageList_", "GuiInstall_",
    "Install_", "Action_", "Main",
)

# 文档里合法的「示例 / 占位」名字，不算错
PLACEHOLDER_NAMES = {"Install_XXX", "Action_XXX", "Action_CleanTemp"}

# 只写了前缀、没写具体名字的常量（如文档里的「前缀取软件名，如 $ZIP7_」「$LOG_COLOR_* 系列」）
# 以 "_" 结尾的一定是前缀引用，不是真实常量名（本项目常量名不以 "_" 结尾）
PLACEHOLDER_CONST_RE = re.compile(r"^\$[A-Z0-9_]+_$")

# 反引号里以这些命令开头的，是命令行而不是文件路径
COMMAND_PREFIXES = ("python ", "python3 ", "py ", "node ", "npm ", "git ", "cd ",
                    "AutoIt3.exe ", "AutoIt3_x64.exe ", "Au3Check.exe ", "Aut2exe_x64.exe ")

# 路径里的占位符片段（<软件名> / Xxx）
PLACEHOLDER_PATH_RE = re.compile(r"xxx|[<>]", re.I)

FENCE_RE = re.compile(r"^\s*(```|~~~)")


def strip_code_blocks(text: str) -> str:
    """去掉围栏代码块内容，只保留正文。模板里的示例链接不该被当成真链接。"""
    out, inside = [], False
    for line in text.splitlines():
        if FENCE_RE.match(line):
            inside = not inside
            continue
        if not inside:
            out.append(line)
    return "\n".join(out)


def collect_au3(root: Path) -> str:
    files = sorted(root.glob("*.au3")) + sorted((root / "Include").rglob("*.au3"))
    files += sorted((root / "tools").glob("*.au3"))
    return "\n".join(f.read_text(encoding="utf-8-sig") for f in files)


def check_links(md_files: list[Path], body: dict[Path, str]) -> list[str]:
    problems = []
    for m in md_files:
        for _, target in re.findall(r"\[([^\]]+)\]\(([^)]+)\)", body[m]):
            if target.startswith(("http://", "https://", "#", "mailto:")):
                continue
            path = target.split("#")[0]
            if not path or "<" in path:
                continue
            if not (m.parent / path).resolve().exists():
                problems.append(f"{m}: 链接目标不存在 -> {target}")
    return problems


def check_symbols(md_files: list[Path], body: dict[Path, str], au3: str) -> list[str]:
    defined_fns = set(re.findall(r"(?im)^\s*Func\s+([A-Za-z_]\w*)\s*\(", au3))
    defined_consts = set(re.findall(r"(?im)^\s*Global\s+Const\s+(\$\w+)", au3))

    problems = []
    for m in md_files:
        t = body[m]

        for name in sorted(set(re.findall(r"\b([A-Za-z_]\w*)\(\)", t))):
            if not name.startswith(FUNC_PREFIXES):
                continue
            if name in defined_fns or name in PLACEHOLDER_NAMES:
                continue
            problems.append(f"{m}: 函数 {name}() 在代码中不存在")

        for c in sorted(set(re.findall(r"(\$[A-Z][A-Z0-9_]+)\b", t))):
            if c in defined_consts:
                continue
            if PLACEHOLDER_CONST_RE.match(c):
                continue
            problems.append(f"{m}: 常量 {c} 在代码中不存在")

    return problems


def check_paths(root: Path, md_files: list[Path], body: dict[Path, str]) -> list[str]:
    """检查反引号里引用的仓库内文件。

    要求带目录分隔符（裸文件名如 7z.exe / package.ini 视为外部程序或示例，跳过）。
    依次尝试三种解析方式，任一命中即视为存在：
      1. 相对当前文档所在目录（与 Markdown 链接的规则一致）
      2. 相对仓库根目录
      3. 仓库内任意位置存在同名后缀路径
    """
    problems = []
    seen = set()

    for m in md_files:
        for raw in set(re.findall(r"`([A-Za-z0-9_\-./\\ ]+\.(?:au3|md|py|ini|exe|zip))`", body[m])):
            p = raw.replace("\\", "/").strip()

            if PLACEHOLDER_PATH_RE.search(p) or p.startswith(("C:", "D:")):
                continue
            if p.startswith(COMMAND_PREFIXES):
                continue
            if "/" not in p:
                continue

            if (m, p) in seen:
                continue
            seen.add((m, p))

            if (m.parent / p).exists() or (root / p).exists():
                continue
            if list(root.rglob(p.lstrip("./"))):
                continue

            problems.append(f"{m}: 引用的路径不存在 -> {p}")

    return problems


def check_package_index(root: Path, body: dict[Path, str]) -> list[str]:
    """docs/packages/ 下每份 <软件>.md 都应在该目录 README 的索引表里出现。"""
    pkg_docs = root / "docs" / "packages"
    index = pkg_docs / "README.md"
    if not index.exists():
        return [f"{index}: 索引文件不存在"]

    text = body[index]
    problems = []

    for f in sorted(pkg_docs.glob("*.md")):
        if f.name == "README.md":
            continue
        if f.name not in text:
            problems.append(f"{index}: 未登记 {f.name}")

    # 反向：索引里写了但文件不存在（链接检查已覆盖，这里只查文件名出现）
    for name in re.findall(r"\[([a-z0-9\-]+\.md)\]", text):
        if not (pkg_docs / name).exists():
            problems.append(f"{index}: 索引指向不存在的 {name}")

    return problems


def main() -> int:
    root = Path(__file__).resolve().parent.parent

    md_files = [p for p in sorted(root.rglob("*.md")) if ".workbuddy-ai" not in p.as_posix()]
    if not md_files:
        print(f"未在 {root} 下找到 Markdown 文件")
        return 1

    raw = {m: m.read_text(encoding="utf-8") for m in md_files}
    body = {m: strip_code_blocks(t) for m, t in raw.items()}
    au3 = collect_au3(root)

    print(f"项目根目录：{root}")
    print(f"待检查文档：{len(md_files)} 个 Markdown\n")

    results = [
        ("1. 相对链接", check_links(md_files, body)),
        ("2. 函数名", check_symbols(md_files, body, au3)),
        ("3. 文件路径", check_paths(root, md_files, body)),
        ("4. docs/packages 索引", check_package_index(root, body)),
    ]

    total = 0
    for title, problems in results:
        if problems:
            total += len(problems)
            print(f"[FAIL] {title}")
            for p in problems:
                print("   ", p)
        else:
            print(f"[ OK ] {title}")

    print()
    if total:
        print(f"共发现 {total} 个问题。")
        return 1

    print("文档与代码一致，检查通过。")
    print("提醒：本脚本只能查「名称/路径是否存在」，描述性内容是否过时仍需人工判断。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
