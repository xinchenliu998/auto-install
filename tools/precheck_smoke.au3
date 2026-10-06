; ==============================================================================
; tools\precheck_smoke.au3 —— 前置检查「只读探针」冒烟测试
; ------------------------------------------------------------------------------
; 只调用**不会修改系统**的探针函数，把它们读到的实际值打印出来，
; 用来验证前置检查的解析逻辑在目标机器上真的能读到状态。
;
; 【为什么需要它】
;   前置检查要求「必须明确知道改前 / 改后的状态」。这类解析逻辑
;   （powercfg / netsh / WMI 的输出）**只有真跑一遍才知道对不对** ——
;   静态检查和语法检查都查不出来（曾经就因为 StringRegExp 的返回值理解错，
;   导致电源状态一直显示「无法读取」）。
;
;   本脚本**不开启远程桌面、不改防火墙、不改电源计划、不创建账户**，
;   只做查询，可以放心在任意机器上运行。
;
; 用法（需要 AutoIt 环境）：
;     AutoIt3_x64.exe tools\precheck_smoke.au3
;
; 输出：日志写到 %TEMP%\precheck-smoke.txt，运行完直接看这个文件。
;
; 注意：本文件不在总入口 auto-install.au3 的 include 链里，是独立工具；
;       tools\check_syntax.py 会把它当作「单文件检查」的对象一并做语法检查。
; ==============================================================================

#include-once

#include "..\Include\Precheck.au3"

Global $g_sSmokeLog = @TempDir & "\precheck-smoke.txt"
If FileExists($g_sSmokeLog) Then FileDelete($g_sSmokeLog)

Logger_Init($g_sSmokeLog)
Logger_Write("============ 前置检查只读探针（不修改系统） ============")

; ---- 1 系统版本（只读）----
PrecheckSystem_Check()

; ---- 2 网络与远程桌面：只读部分 ----
Logger_Step("网络只读探针")
Logger_Info("  ping 规则：" & PrecheckNetwork_FwRuleState($PRECHK_FW_ICMP))
Logger_Info("  RDP  规则：" & PrecheckNetwork_FwRuleState($PRECHK_FW_RDP))
Logger_Info("  远程桌面：" & PrecheckNetwork_RdpState())

; ---- 3 电源：只读部分 ----
Logger_Step("电源只读探针")
Global $aSleep = PrecheckPower_ReadPair("STANDBYIDLE")
Logger_Info("  睡眠：" & PrecheckPower_PairText($aSleep))
Global $aHib = PrecheckPower_ReadPair("HIBERNATEIDLE")
Logger_Info("  休眠：" & PrecheckPower_PairText($aHib))

; ---- 4 设备驱动（只读）----
PrecheckDriver_Check()

; ---- 5 开机账户状态（只读）----
Logger_Step("账户只读探针")
Logger_Info("  不存在的账户（应报「账户不存在」）：" & PrecheckAccount_StateText("__no_such_account__"))
Logger_Info("  当前用户 " & @UserName & "：" & PrecheckAccount_StateText(@UserName))

Logger_Write("============ 探针结束，日志见 %TEMP%\precheck-smoke.txt ============")
