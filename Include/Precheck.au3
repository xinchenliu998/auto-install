; ==============================================================================
; Precheck.au3 —— 安装前置检查（入口）
; ------------------------------------------------------------------------------
; 在开始安装软件之前，先确认目标机器满足出厂交付的基本条件。共 5 项：
;
;   1. 系统版本　　　—— 产品名 / 内部版本号 / 架构；家庭版会提示确认是否继续；
;   2. 网络与远程桌面 —— 放通 ICMPv4 回显（ping），开启远程桌面（RDP）并放通 3389；
;   3. 电源设置　　　—— 睡眠 / 休眠超时全部设为「从不」（交流 + 电池）；
;   4. 设备驱动　　　—— 枚举存在问题的设备（设备管理器里的感叹号），只报告不修改；
;   5. 开机账户　　　—— 确保配置里的本地账户存在（不存在则创建）、属管理员、密码可用。
;
; 【本文件是模块的「入口」】只做两件事：
;   · #include 共享底座与 5 个检查项子模块；
;   · 提供唯一入口 Precheck_RunAll()，汇总结果并做「继续 / 中止」确认。
;
;   共享状态与共享辅助（Precheck_AddIssue / Precheck_Capture 等）在 Precheck\Base.au3；
;   子模块（Include\Precheck\ 下，各自独立函数前缀）：
;     Base.au3      Precheck_*          共享状态 + 共享辅助
;     System.au3    PrecheckSystem_*    系统版本与内部版本号
;     Network.au3   PrecheckNetwork_*   ping 与远程桌面
;     Power.au3     PrecheckPower_*     电源（永不睡眠 / 永不休眠）
;     Driver.au3    PrecheckDriver_*    设备驱动异常
;     Account.au3   PrecheckAccount_*   开机账户
;
;   各子模块自己 `#include "Base.au3"`，因此**单独打开 / 单独检查也不会报错**。
;
; 【处置策略】Precheck_RunAll($bInteractive)
;   · $bInteractive = True　—— 把发现的问题汇总成一个对话框，由操作员决定「继续 / 中止」；
;   · $bInteractive = False —— 无人值守：只记日志，不打断流程（产线不能因一个警告停下来）。
;
; 能自动修复的（防火墙规则、电源计划、开机账户）直接修好并写日志；
; 不能自动修复的（家庭版、驱动异常）只报告，交由操作员判断。
; ==============================================================================

#include-once

#include "Precheck\Base.au3"
#include "Precheck\System.au3"
#include "Precheck\Network.au3"
#include "Precheck\Power.au3"
#include "Precheck\Driver.au3"
#include "Precheck\Account.au3"

; ==============================================================================
; 入口
; ==============================================================================

; 执行全部前置检查。
;   返回 True　—— 可以继续安装
;   返回 False —— 操作员选择中止（仅交互模式会出现）
Func Precheck_RunAll($bInteractive)
    ; 复位状态，允许重复调用
    $g_bPrecheckHome   = False
    $g_iPrecheckIssues = 0
    ReDim $g_aPrecheckIssues[1]
    $g_iPrecheckDevs   = 0
    ReDim $g_aPrecheckDevs[1][3]

    Logger_Write("==================== 前置检查 ====================")
    Logger_Info("开始系统前置检查（共 5 项）")
    Logger_Info("会修改系统的检查项会打印「更改前 / 更改后」两行状态，便于核对实际发生了什么。")

    PrecheckSystem_Check()
    PrecheckNetwork_Check()
    PrecheckPower_Check()
    PrecheckDriver_Check()
    PrecheckAccount_Check()

    Logger_Write("")

    If $g_iPrecheckIssues = 0 Then
        Logger_Ok("前置检查全部通过。")
        Return True
    EndIf

    If Not $bInteractive Then
        Logger_Warn("前置检查发现 " & $g_iPrecheckIssues & " 个问题，无人值守模式下继续执行。")
        Return True
    EndIf

    ; ---- 交互模式：汇总后由操作员决定 ----
    Local $iShow = $g_iPrecheckIssues
    If $iShow > 8 Then $iShow = 8

    Local $sMsg = "前置检查发现 " & $g_iPrecheckIssues & " 个问题：" & @CRLF & @CRLF
    For $i = 0 To $iShow - 1
        $sMsg &= "  " & ($i + 1) & ". " & $g_aPrecheckIssues[$i] & @CRLF
    Next
    If $g_iPrecheckIssues > $iShow Then
        $sMsg &= "  ... 另有 " & ($g_iPrecheckIssues - $iShow) & " 个问题，详见日志。" & @CRLF
    EndIf
    $sMsg &= @CRLF & "是否仍要继续安装？" & @CRLF & _
            "选择「否」将中止本次安装，建议先处理上述问题后重试。"

    If MsgBox($MB_YESNO_WARN, $APP_TITLE, $sMsg) = $MB_RET_YES Then
        Logger_Warn("操作员选择继续安装（存在 " & $g_iPrecheckIssues & " 个前置检查问题）。")
        Return True
    EndIf

    Logger_Warn("操作员选择中止安装。")
    Return False
EndFunc
