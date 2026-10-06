#!/usr/bin/env python3
"""auto-install 项目的 AutoIt 源码静态校验。

本脚本是**文本级**检查，不解析语法，因此无法替代真正的语法检查 ——
语法检查请用 tools/check_syntax.py（调 AutoIt 官方 Au3Check.exe）。
典型的漏检：`@PID`（AutoIt 没有这个宏，应为 `@AutoItPID`）本脚本会放行。

检查项：

  1. 编码      —— 每个 .au3 是否带 UTF-8 BOM（缺了会导致中文乱码）
  2. 块配对    —— Func/If/While/For/Switch/Do/Select/With 是否配对
  3. include   —— #include "xxx.au3" 的目标文件是否存在
  4. 函数      —— 调用的项目内函数是否都有定义
  5. 常量      —— 引用的项目内常量是否都有定义（能抓出拼写错误）
  6. 注册      —— Install 模块注册的目录名是否与 packages/ 下实际目录一致

用法：
    python tools/check_au3.py            # 在项目根目录执行
    python tools/check_au3.py -v         # 额外列出所有已定义的函数与常量

退出码：全部通过 0，存在任何问题 1。
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# AutoIt 内置 / UDF 常量中，前缀与本项目自定义常量可能撞车的那几个，跳过不检查
BUILTIN_CONST_IGNORE = (
    "MB_ICON", "MB_OK", "MB_YESNO", "MB_RETRYCANCEL", "MB_ABORTRETRYIGNORE",
    "MB_CANCELTRYCONTINUE", "MB_DEFBUTTON", "MB_TOPMOST", "MB_SYSTEMMODAL",
    "MB_TASKMODAL", "MB_APPLMODAL", "MB_SERVICE_NOTIFICATION", "MB_SETFOREGROUND",
    "MB_HELP", "MB_USERICON", "MB_RIGHT", "MB_RTLREADING", "MB_DEFAULT_DESKTOP_ONLY",
)

# 项目内函数前缀（用于区分 AutoIt 内置函数与 UDF）
FUNC_PREFIXES = (
    "Common_", "Logger_", "Config_", "Installer_",
    "Precheck_", "PrecheckSystem_", "PrecheckNetwork_", "PrecheckPower_",
    "PrecheckDriver_", "PrecheckAccount_",
    "GuiConfig_", "GuiConfigLayout_", "GuiConfigState_", "GuiPackageList_", "GuiInstall_",
    "Install_", "Action_", "Main",
)

OPEN_CLOSE = {
    "func": "endfunc", "while": "wend", "for": "next", "switch": "endswitch",
    "do": "until", "select": "endselect", "with": "endwith", "if": "endif",
}
CLOSE_OPEN = {v: k for k, v in OPEN_CLOSE.items()}


def collect_files(root: Path) -> list[Path]:
    r"""收集所有 .au3：根目录 + Include\ 全部层级 + tools\ 下的独立工具脚本。"""
    files: list[Path] = sorted(root.glob("*.au3"))
    files += sorted((root / "Include").rglob("*.au3"))
    files += sorted((root / "tools").glob("*.au3"))
    return files


def strip_comment(line: str) -> str:
    """去掉行尾注释，注意跳过字符串字面量内部的 ';'。"""
    out: list[str] = []
    quote: str | None = None
    for ch in line:
        if quote:
            if ch == quote:
                quote = None
        else:
            if ch in "\"'":
                quote = ch
            elif ch == ";":
                break
        out.append(ch)
    return "".join(out)


def strip_comments(text: str) -> str:
    return "\n".join(strip_comment(ln) for ln in text.splitlines())


def logical_lines(text: str) -> list[tuple[int, str]]:
    """按 AutoIt 的「逻辑行」切分：行尾（空白 + 下划线）表示续行。

    返回 (起始行号, 合并后的整行)。不处理续行会导致跨行的
    `If ... _\\n  ... Then <语句>` 被误判成未闭合的 If。
    """
    out: list[tuple[int, str]] = []
    buf = ""
    start = 0

    for idx, raw in enumerate(text.splitlines(), 1):
        s = raw.rstrip()
        if len(s) >= 2 and s.endswith("_") and s[-2].isspace():
            if not buf:
                start = idx
            buf += s[:-1]
            continue

        if buf:
            out.append((start, buf + raw))
            buf = ""
        else:
            out.append((idx, raw))

    if buf:
        out.append((start, buf))

    return out


# --------------------------------------------------------------------------- 1
def check_bom(files: list[Path]) -> list[str]:
    problems = []
    for f in files:
        if f.read_bytes()[:3] != b"\xef\xbb\xbf":
            problems.append(f"{f}: 缺少 UTF-8 BOM（含中文的 .au3 必须带 BOM）")
    return problems


# --------------------------------------------------------------------------- 2
def check_blocks(files: list[Path], clean: dict[Path, str]) -> list[str]:
    problems = []
    for f in files:
        stack: list[tuple[str, int]] = []
        errs: list[str] = []
        for ln, raw in logical_lines(clean[f]):
            s = raw.strip()
            if not s:
                continue
            first = s.split()[0].lower()

            if first == "if":
                m = re.match(r"(?i)^if\b.*?\bthen\b(.*)$", s)
                if m and m.group(1).strip():
                    continue  # 单行 If，没有 EndIf
                stack.append(("If", ln))
                continue

            if first in OPEN_CLOSE:
                stack.append((s.split()[0], ln))
                continue

            if first in CLOSE_OPEN:
                if not stack:
                    errs.append(f"  行 {ln}: 多余的 {s.split()[0]}")
                elif stack[-1][0].lower() != CLOSE_OPEN[first]:
                    errs.append(
                        f"  行 {ln}: {s.split()[0]} 与行 {stack[-1][1]} 的 {stack[-1][0]} 不匹配"
                    )
                else:
                    stack.pop()

        for kw, ln in stack:
            errs.append(f"  行 {ln}: {kw} 未闭合")

        if errs:
            problems.append(f"{f}:")
            problems += errs
    return problems


# --------------------------------------------------------------------------- 3
def check_includes(files: list[Path], raw: dict[Path, str]) -> list[str]:
    problems = []
    for f in files:
        for m in re.finditer(r'(?im)^\s*#include\s+"([^"]+)"', raw[f]):
            target = m.group(1).replace("\\", "/")
            if not (f.parent / target).resolve().exists():
                problems.append(f'{f}: #include "{m.group(1)}" 目标不存在')
    return problems


# --------------------------------------------------------------------------- 4/5
def check_symbols(
    clean: dict[Path, str], verbose: bool
) -> tuple[list[str], set[str], set[str]]:
    all_text = "\n".join(clean.values())

    defined_funcs = set(re.findall(r"(?im)^\s*Func\s+([A-Za-z_]\w*)\s*\(", all_text))
    defined_consts = set(re.findall(r"(?im)^\s*Global\s+Const\s+(\$\w+)", all_text))

    # 项目常量前缀集合（从已定义常量自动推导，如 $APP_NAME -> APP_）
    prefixes = set()
    for c in defined_consts:
        body = c[1:]
        if "_" in body:
            prefixes.add(body.split("_", 1)[0] + "_")

    called: set[str] = set()
    used_consts: set[str] = set()
    for text in clean.values():
        called |= set(re.findall(r"\b([A-Za-z_]\w*)\s*\(", text))
        called |= set(re.findall(r'(?i)\bCall\s*\(\s*"([^"]+)"', text))
        used_consts |= set(re.findall(r"(\$[A-Z][A-Za-z0-9_]*)", text))

    problems = []

    for name in sorted(called):
        if not name.startswith(FUNC_PREFIXES):
            continue
        if name in defined_funcs or name in ("Install_XXX", "Action_XXX"):
            continue
        problems.append(f"函数 {name}() 被调用但未定义")

    for name in sorted(used_consts):
        body = name[1:]
        if not any(body.startswith(p) for p in prefixes):
            continue
        if name in defined_consts:
            continue
        if any(body.startswith(ig) for ig in BUILTIN_CONST_IGNORE):
            continue
        problems.append(f"常量 {name} 被引用但未定义（拼写错误？）")

    if verbose:
        print(f"\n[verbose] 已定义函数 {len(defined_funcs)} 个：")
        for n in sorted(defined_funcs):
            print("   ", n)
        print(f"\n[verbose] 已定义常量 {len(defined_consts)} 个，前缀：{sorted(prefixes)}")

    return problems, defined_funcs, defined_consts


# --------------------------------------------------------------------------- 6
def check_registration(root: Path, clean: dict[Path, str]) -> list[str]:
    problems = []
    pkg_root = root / "packages"
    if not pkg_root.is_dir():
        return [f"{pkg_root}: 目录不存在"]

    dirs = {p.name for p in pkg_root.iterdir() if p.is_dir()}

    install_dir = root / "Include" / "Install"
    registered: dict[str, str] = {}

    for f in sorted(install_dir.glob("*.au3")):
        text = clean[f]
        consts = dict(re.findall(r'(?im)^\s*Global\s+Const\s+(\$\w+)\s*=\s*"([^"]*)"', text))
        for cname, fname in re.findall(r'Installer_Register\(\s*(\$\w+)\s*,\s*"([^"]+)"', text):
            folder = consts.get(cname)
            if folder is None:
                problems.append(f"{f}: Installer_Register 的常量 {cname} 不是字符串常量")
                continue
            registered[folder] = fname

    for folder, fname in sorted(registered.items()):
        if folder not in dirs:
            problems.append(
                f'注册的目录名 "{folder}"（{fname}）在 packages/ 下不存在，永远不会被调用'
            )

    unimpl = sorted(dirs - set(registered))
    if unimpl:
        print(f"  [提示] 尚未实现安装脚本的软件（执行时会标记为「跳过」）：{', '.join(unimpl)}")

    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description="auto-install 的 AutoIt 源码静态校验")
    ap.add_argument("-v", "--verbose", action="store_true", help="列出所有已定义的函数与常量")
    args = ap.parse_args()

    root = Path(__file__).resolve().parent.parent
    files = collect_files(root)
    if not files:
        print(f"未在 {root} 下找到 .au3 文件")
        return 1

    raw = {f: f.read_text(encoding="utf-8-sig") for f in files}
    clean = {f: strip_comments(t) for f, t in raw.items()}

    print(f"项目根目录：{root}")
    print(f"待检查文件：{len(files)} 个 .au3\n")

    results: list[tuple[str, list[str]]] = []
    results.append(("1. 文件编码 (UTF-8 BOM)", check_bom(files)))
    results.append(("2. 块级关键字配对", check_blocks(files, clean)))
    results.append(("3. #include 引用", check_includes(files, raw)))
    sym, _, _ = check_symbols(clean, args.verbose)
    results.append(("4/5. 函数与常量定义", sym))
    results.append(("6. 安装模块注册", check_registration(root, clean)))

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

    print("全部检查通过。")
    print("提醒：本脚本只做文本级检查，**查不出语法错误**；")
    print("      请另跑 python tools/check_syntax.py（Au3Check）做真正的语法检查。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
