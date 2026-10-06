#!/usr/bin/env python3
"""auto-install 项目的 AutoIt **语法**检查（调用 AutoIt 官方 Au3Check.exe）。

为什么还需要这个脚本：
    tools/check_au3.py 与 tools/check_docs.py 都只是「文本级」静态检查 ——
    能查 BOM、块级关键字配对、名字是否存在，但**查不出语法错误**。
    例如 `@PID`（AutoIt 里根本没有这个宏，正确写法是 `@AutoItPID`），
    两个脚本都放行了，只有 Au3Check 能抓到。

本脚本做三件事：

  1. 覆盖范围 —— 核对有没有 .au3 文件没被任何 #include 引用。
     这种文件不会进入总入口的编译/检查链，等于漏检。
  2. 整体语法检查 —— 调用 Au3Check.exe 检查总入口 auto-install.au3。
     Au3Check 会自行跟进整条 #include 链，因此等于检查了全部源码。
  3. 单文件语法检查 —— 对每个 .au3 单独跑一次 Au3Check，
     模拟「在 SciTE 里直接打开这个文件」。

     为什么需要第 3 步：共享声明放在「父文件」里时（控件 ID、共享辅助函数等），
     整体编译不报错（编译时父文件先声明了），但单独打开子模块就会报
     `Foo_Bar(): undefined function` / `$g_x: undeclared global variable`。
     本项目的约定是：**共享声明抽成独立文件，由子模块各自 #include**。

用法：
    python tools/check_syntax.py

退出码：
    0 = 通过
    1 = 有语法错误，或有源码未纳入检查范围
    2 = 没找到 Au3Check.exe（此时**不能**认为语法检查通过了）
"""

from __future__ import annotations

import os
import re
import shutil
import string
import subprocess
import sys
from pathlib import Path

ENTRY = "auto-install.au3"

# 严一些的警告级别（都是 Au3Check 默认关闭、但本项目已能做到 0 warning 的档位）：
#   -w 3 重复声明的变量   -w 4 全局作用域里用了局部变量
#   -w 5 声明了但没用的局部变量   -w 6 使用 Dim
# 默认已开启的是 -w 1（文件被重复 include）/ -w 2（缺 #comments-end）/ -w 7（ByRef 传常量或表达式）
STRICT_FLAGS = ["-w", "3", "-w", "4", "-w", "5", "-w", "6"]

INCLUDE_RE = re.compile(r'(?im)^\s*#include\s+"([^"]+)"')


def find_au3check() -> Path | None:
    """定位 Au3Check.exe：先查 PATH，再查常见安装位置。"""
    found = shutil.which("Au3Check.exe") or shutil.which("Au3Check")
    if found:
        return Path(found)

    roots: list[Path] = []
    for var in ("ProgramFiles", "ProgramFiles(x86)", "ProgramW6432"):
        value = os.environ.get(var)
        if value:
            roots.append(Path(value))

    # AutoIt 常被装在非系统盘（本机就在 D 盘），把各盘的 Program Files 都纳入
    for letter in string.ascii_uppercase:
        for name in ("Program Files (x86)", "Program Files"):
            drive = Path(f"{letter}:/")
            if drive.is_dir():
                roots.append(drive / name)

    seen: set[Path] = set()
    for base in roots:
        cand = base / "AutoIt3" / "Au3Check.exe"
        if cand in seen:
            continue
        seen.add(cand)
        if cand.is_file():
            return cand

    return None


def collect_reachable(entry: Path) -> set[Path]:
    """从总入口出发，递归收集所有被 #include 引用的项目 .au3 文件。

    只看双引号形式的 include（`#include "..\\Common.au3"`）——
    尖括号形式（`#include <GUIConstantsEx.au3>`）是 AutoIt 自带 UDF，不属于本项目。
    """
    reached: set[Path] = set()
    stack = [entry]

    while stack:
        current = stack.pop()
        try:
            current = current.resolve()
        except OSError:
            continue

        if current in reached or not current.is_file():
            continue
        reached.add(current)

        try:
            text = current.read_text(encoding="utf-8-sig", errors="replace")
        except OSError:
            continue

        for match in INCLUDE_RE.finditer(text):
            target = current.parent / match.group(1).replace("\\", "/")
            if target.suffix.lower() == ".au3":
                stack.append(target)

    return reached


def run_au3check(au3check: Path, target: Path, root: Path) -> tuple[int, str]:
    """对单个文件跑 Au3Check，返回 (退出码, 输出)。"""
    proc = subprocess.run(
        [str(au3check), *STRICT_FLAGS, str(target)],
        cwd=str(root),
        capture_output=True,
        text=True,
        errors="replace",
    )
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def collect_diagnostics(output: str) -> list[str]:
    """从 Au3Check 输出里挑出 error / warning 行。"""
    lines = []
    for line in output.splitlines():
        text = line.strip()
        if ": error:" in text or ": warning:" in text:
            lines.append(text)
    return lines


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    entry = root / ENTRY
    if not entry.is_file():
        print(f"未找到总入口：{entry}")
        return 1

    # 会被总入口 include 的源码 —— 要求都能从入口到达
    linked_files = sorted({p.resolve() for p in root.glob("*.au3")})
    linked_files += sorted({p.resolve() for p in (root / "Include").rglob("*.au3")})

    # 独立工具脚本（如 tools\precheck_smoke.au3）—— 不在 include 链里，但要单独做语法检查
    tool_files = sorted({p.resolve() for p in (root / "tools").glob("*.au3")})

    all_files = linked_files + tool_files

    print(f"项目根目录：{root}")
    print(f"项目源码：{len(all_files)} 个 .au3（其中独立工具 {len(tool_files)} 个）\n")

    total = 0

    # ------------------------------------------------------------------ 1
    reachable = collect_reachable(entry)
    missed = [p for p in linked_files if p not in reachable]
    if missed:
        total += len(missed)
        print("[FAIL] 1. 检查覆盖范围")
        for p in missed:
            print(f"    {p.relative_to(root)}：没有被任何 #include 引用，不会被语法检查覆盖")
    else:
        print("[ OK ] 1. 检查覆盖范围（全部源码都在总入口的 include 链里）")

    # ------------------------------------------------------------------ 2
    au3check = find_au3check()
    if au3check is None:
        print()
        print("[SKIP] 2/3 语法检查 —— 未找到 Au3Check.exe（AutoIt 官方语法检查器）")
        print("       安装 AutoIt v3 后重试，或手动执行：")
        print(f"           Au3Check.exe {ENTRY}")
        print()
        print("提醒：check_au3.py / check_docs.py 都只是文本级检查，**不能替代语法检查**。")
        return 2

    print(f"[ .. ] 2. 整体语法检查（{au3check}）")
    code, output = run_au3check(au3check, entry, root)
    for line in output.splitlines():
        if line.strip():
            print(f"    {line.strip()}")
    if code != 0:
        total += 1
        print(f"    -> 未通过（Au3Check 退出码 {code}）")
    else:
        print("    -> 通过")

    # ------------------------------------------------------------------ 3
    print(f"[ .. ] 3. 单文件语法检查（{len(all_files)} 个文件，逐个跑）")
    bad_files = 0
    for f in all_files:
        code, output = run_au3check(au3check, f, root)
        if code == 0:
            continue

        bad_files += 1
        total += 1
        diags = collect_diagnostics(output)
        print(f"    [FAIL] {f.relative_to(root)}（退出码 {code}，{len(diags)} 条）")
        for line in diags[:3]:
            print(f"           {line}")
        if len(diags) > 3:
            print(f"           ... 另有 {len(diags) - 3} 条")

    if bad_files == 0:
        print("    -> 通过（每个文件单独检查都干净）")
    else:
        print()
        print(f"    -> {bad_files} 个文件单独检查不通过。")
        print("       多半是「共享声明放在了父文件里」：把共享的常量/变量/函数抽到独立文件，")
        print("       由需要它的每个文件自己 #include（参考 Include/Precheck/Base.au3、")
        print("       Include/Gui/ConfigShared.au3）。")

    print()
    if total:
        print(f"共发现 {total} 个问题。")
        return 1

    print("语法检查通过。")
    print("提醒：语法正确 ≠ 行为正确。界面布局、外部命令参数等仍需在目标机上实测。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
