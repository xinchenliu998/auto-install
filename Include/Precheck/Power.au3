; ==============================================================================
; Precheck\Power.au3 —— 前置检查 3/5：电源设置（永不睡眠 / 永不休眠）
; ------------------------------------------------------------------------------
; 把当前电源计划的睡眠 / 休眠超时全部设为 0（从不），交流与电池都设。
; 改完再回读 powercfg 的实际设置索引做校验。
;
; 改动前后各打印一次实际读数（Precheck_LogBefore / Precheck_LogAfter），便于核对。
;
; 函数前缀：PrecheckPower_*
; 共享状态与辅助在 Base.au3 里声明，本文件已 include。
; ==============================================================================

#include-once

#include "Base.au3"
#include "..\Constants.au3"
#include "..\Logger.au3"
#include "..\Installer.au3"

; 3/5 电源设置
Func PrecheckPower_Check()
    Logger_Step("3/5 电源设置（永不睡眠 / 永不休眠）")

    ; 改动前先读一遍实际值（读两次，改动后再读两次做对照）
    Local $aSleepBefore = PrecheckPower_ReadPair("STANDBYIDLE")
    Local $aHibBefore   = PrecheckPower_ReadPair("HIBERNATEIDLE")
    Precheck_LogBefore("睡眠：" & PrecheckPower_PairText($aSleepBefore) & _
            "；休眠：" & PrecheckPower_PairText($aHibBefore))

    ; ---- 睡眠 ----
    Local $bSleep = PrecheckPower_Set("睡眠（交流电源）", "standby-timeout-ac")
    If Not PrecheckPower_Set("睡眠（电池）", "standby-timeout-dc") Then $bSleep = False

    If Not $bSleep Then
        Logger_Warn("  睡眠超时设置失败，请检查当前电源计划。")
        Precheck_AddIssue("未能将睡眠超时设为「从不」，机器可能在空闲后进入睡眠")
    EndIf

    ; ---- 休眠 ----
    ; 机器若已禁用休眠（powercfg /h off），这两条会失败，但效果等同于「永不休眠」，不算问题
    Local $bHib = PrecheckPower_Set("休眠（交流电源）", "hibernate-timeout-ac")
    If Not PrecheckPower_Set("休眠（电池）", "hibernate-timeout-dc") Then $bHib = False

    If Not $bHib Then
        Logger_Info("  休眠超时设置未生效（该机器可能已禁用休眠，等效于「永不休眠」）。")
    EndIf

    ; ---- 改动后：重新读实际值 ----
    Local $aSleepAfter = PrecheckPower_ReadPair("STANDBYIDLE")
    Local $aHibAfter   = PrecheckPower_ReadPair("HIBERNATEIDLE")
    Precheck_LogAfter("睡眠：" & PrecheckPower_PairText($aSleepAfter) & _
            "；休眠：" & PrecheckPower_PairText($aHibAfter))

    ; ---- 校验：以「更改后」的实际读数为准 ----
    If UBound($aSleepAfter) < 2 Or UBound($aHibAfter) < 2 Then
        ; 读不出实际值就不能声称已改好 —— 必须报出来，不能悄悄放过
        Logger_Warn("  无法读取电源设置的实际值，无法确认改动结果。")
        Precheck_AddIssue("无法读取电源设置的实际值，无法确认是否已设为「从不」/「永不休眠」")
    ElseIf $aSleepAfter[0] <> 0 Or $aSleepAfter[1] <> 0 Then
        Logger_Warn("  校验发现睡眠超时不为「从不」，请手动检查电源计划。")
        Precheck_AddIssue("电源计划的睡眠超时不为「从不」")
    EndIf
EndFunc

; 把某项超时设为 0（从不）。返回 True / False
Func PrecheckPower_Set($sLabel, $sKey)
    Local $iRet = Installer_RunWaitBeat("电源设置：" & $sLabel, _
            @ComSpec & " /c powercfg /change " & $sKey & " 0", _
            @ScriptDir, $TIMEOUT_PRECHECK)
    Return ($iRet = 0)
EndFunc

; 读取 SUB_SLEEP 下某项超时的「交流 / 电池」秒数，返回 2 元素数组 [交流, 电池]；
; 读不出来时返回只有 1 个元素的数组（用 UBound() 判断）。
Func PrecheckPower_ReadPair($sSetting)
    Local $aFail[1] = [-1]

    Local $sOut = Precheck_Capture("读取电源设置 " & $sSetting, _
            "powercfg /query SCHEME_CURRENT SUB_SLEEP " & $sSetting)
    If $sOut = "" Then Return $aFail

    ; powercfg 的输出（本地化后文字不同，但值认得）：
    ;       最小可能的设置: 0x00000000
    ;       最大可能的设置: 0xffffffff
    ;       可能的设置增量: 0x00000001
    ;     当前交流电源设置索引: 0x00000000     <- 倒数第二个
    ;     当前直流电源设置索引: 0x00000000     <- 最后一个
    ; 所以「最后两个 0x 值」就是交流 / 直流。
    ;
    ; 【坑】StringRegExp 的 flag 3 返回的是**纯匹配数组（0 基，没有计数元素）**，
    ; 匹配个数要用 UBound() 取。不要以为 $aM[0] 是匹配个数 —— 它是第一个匹配值。
    Local $aM = StringRegExp($sOut, "0x([0-9A-Fa-f]{8})", 3)
    If Not IsArray($aM) Then Return $aFail

    Local $iN = UBound($aM)
    If $iN < 2 Then Return $aFail

    Local $aOut[2] = [Dec($aM[$iN - 2]), Dec($aM[$iN - 1])]
    Return $aOut
EndFunc

Func PrecheckPower_PairText($aPair)
    If UBound($aPair) < 2 Then Return "无法读取"
    Return "交流 " & PrecheckPower_SecText($aPair[0]) & " / 电池 " & PrecheckPower_SecText($aPair[1])
EndFunc

; 超时值（秒）转文字：0 = 从不
Func PrecheckPower_SecText($iSec)
    If $iSec <= 0 Then Return "从不"
    Return Int($iSec / 60) & " 分钟"
EndFunc
