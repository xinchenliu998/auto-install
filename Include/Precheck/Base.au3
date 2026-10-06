; ==============================================================================
; Precheck\Base.au3 —— 前置检查的共享基础（状态 + 辅助函数）
; ------------------------------------------------------------------------------
; 本文件是前置检查模块的「共享底座」，被入口与 5 个检查项子模块**各自 include**：
;
;     ..\Precheck.au3           入口：Precheck_RunAll()
;     System.au3  Network.au3  Power.au3  Driver.au3  Account.au3
;
; 【为什么单独抽出来】
;   共享状态与辅助如果放在入口 Precheck.au3 里，子模块单独打开（或用 Au3Check 单独检查）
;   就会报 `Precheck_AddIssue(): undefined function` / `$g_bPrecheckHome: undeclared global variable`——
;   整体编译虽然不报错（编译时入口先声明了），但在 SciTE 里逐个浏览每个文件都是红字。
;   抽成 Base.au3 后，**每个文件都能单独通过语法检查**，整体编译也不受影响。
;
;   规则：**共享声明只在这里写一次**，子模块与入口都用 `#include "Base.au3"` 引入，
;   不要在任何地方再声明一遍。
;
; 依赖：Constants / Common / Logger / Installer（Precheck_RunCmd / Precheck_Capture 要用）。
; ==============================================================================

#include-once

#include "..\Constants.au3"
#include "..\Common.au3"
#include "..\Logger.au3"
#include "..\Installer.au3"

; ------------------------------------------------------------------------------
; 共享状态
; ------------------------------------------------------------------------------
Global $g_bPrecheckHome    = False          ; 是否家庭版（Network 检查据此调整提示）
Global $g_aPrecheckIssues[1]                ; 需要操作员确认的问题（至少 1 个元素）
Global $g_iPrecheckIssues  = 0
Global $g_aPrecheckDevs[1][3]               ; 驱动异常设备：[i][0]名称 [i][1]错误码 [i][2]说明
Global $g_iPrecheckDevs    = 0
Global $g_iPrecheckTmpSeq  = 0              ; 临时文件名序号

; ==============================================================================
; 共享辅助
; ==============================================================================

; 打印「更改前 / 更改后」状态。
; 会修改系统的检查项（网络与远程桌面、电源、开机账户）都要成对调用：
; 先记改动前的状态，执行改动后再记一次，方便对照到底改成了什么。
Func Precheck_LogBefore($sText)
    Logger_Info("  [更改前] " & $sText)
EndFunc

Func Precheck_LogAfter($sText)
    Logger_Info("  [更改后] " & $sText)
EndFunc

; 记一条「需要操作员确认」的问题
Func Precheck_AddIssue($sText)
    If $g_iPrecheckIssues > 0 Then ReDim $g_aPrecheckIssues[$g_iPrecheckIssues + 1]
    $g_aPrecheckIssues[$g_iPrecheckIssues] = $sText
    $g_iPrecheckIssues += 1
EndFunc

; 记一个驱动异常的设备
Func Precheck_AddDevice($sName, $iCode, $sDesc)
    If $g_iPrecheckDevs > 0 Then ReDim $g_aPrecheckDevs[$g_iPrecheckDevs + 1][3]
    $g_aPrecheckDevs[$g_iPrecheckDevs][0] = $sName
    $g_aPrecheckDevs[$g_iPrecheckDevs][1] = $iCode
    $g_aPrecheckDevs[$g_iPrecheckDevs][2] = $sDesc
    $g_iPrecheckDevs += 1
EndFunc

; 以 cmd 执行一条命令并等待，返回退出码（日志由调用方补）
Func Precheck_RunCmd($sLabel, $sCmd)
    Return Installer_RunWaitBeat($sLabel, @ComSpec & " /c " & $sCmd, @ScriptDir, $TIMEOUT_PRECHECK)
EndFunc

; 执行一条命令并把标准输出 / 标准错误捕获为文本（经临时文件，避免阻塞界面）
Func Precheck_Capture($sLabel, $sCmd)
    $g_iPrecheckTmpSeq += 1
    Local $sTmp = Common_JoinPath(@TempDir, _
            "auto-install-precheck-" & @AutoItPID & "-" & $g_iPrecheckTmpSeq & ".txt")

    If FileExists($sTmp) Then FileDelete($sTmp)

    Installer_RunWaitBeat($sLabel, _
            @ComSpec & " /c " & $sCmd & ' > "' & $sTmp & '" 2>&1', _
            @ScriptDir, $TIMEOUT_PRECHECK)

    Local $sOut = ""
    If FileExists($sTmp) Then
        Local $hF = FileOpen($sTmp, 0)
        If $hF <> -1 Then
            $sOut = FileRead($hF)
            FileClose($hF)
        EndIf
        FileDelete($sTmp)
    EndIf

    Return $sOut
EndFunc
