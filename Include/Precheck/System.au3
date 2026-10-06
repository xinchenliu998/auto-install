; ==============================================================================
; Precheck\System.au3 —— 前置检查 1/5：系统版本与内部版本号
; ------------------------------------------------------------------------------
; 记录产品名 / 版本标识 / 内部版本号 / 架构，并判断是否为家庭版。
; 家庭版不支持远程桌面主机、组策略、域加入等，会记一条问题交给操作员确认。
;
; 函数前缀：PrecheckSystem_*
; 共享状态与辅助（$g_bPrecheckHome / Precheck_AddIssue 等）在 Base.au3 里声明，本文件已 include。
; ==============================================================================

#include-once

#include "Base.au3"
#include "..\Constants.au3"
#include "..\Logger.au3"

; 1/5 系统版本
Func PrecheckSystem_Check()
    Logger_Step("1/5 系统版本与版本号")

    Local $sProduct = RegRead($PRECHK_WIN_KEY, "ProductName")
    Local $sEdition = RegRead($PRECHK_WIN_KEY, "EditionID")
    Local $sDisplay = RegRead($PRECHK_WIN_KEY, "DisplayVersion")
    Local $sUBR     = RegRead($PRECHK_WIN_KEY, "UBR")

    If $sProduct = "" Then $sProduct = @OSVersion
    If $sEdition = "" Then $sEdition = "未知"

    Local $iBuild = Int(@OSBuild)
    Local $sBuild = @OSBuild
    If $sUBR <> "" Then $sBuild &= "." & $sUBR

    ; @OSVersion 在旧版 AutoIt 上对 Win11 仍返回 WIN_10，故按内部版本号再判一次
    Local $sOsName = PrecheckSystem_OsName($iBuild)

    Logger_Info("  产品名称　：" & $sProduct & "（注册表 ProductName，Win11 上可能仍写着 Windows 10）")
    Logger_Info("  版本标识　：" & $sEdition)
    Logger_Info("  系统版本　：" & $sOsName & "（" & @OSVersion & "）")
    Logger_Info("  内部版本号：" & $sBuild)
    Logger_Info("  系统架构　：" & @OSArch)
    If $sDisplay <> "" Then Logger_Info("  功能更新　：" & $sDisplay)

    $g_bPrecheckHome = PrecheckSystem_IsHome($sEdition, $sProduct)

    If $g_bPrecheckHome Then
        Logger_Warn("  检测到 Windows 家庭版：" & $sOsName & "，EditionID=" & $sEdition)
        Logger_Warn("  家庭版不支持远程桌面主机（RDP Server）、组策略、域加入等功能，")
        Logger_Warn("  可能无法满足工控机远程运维与批量管理的需求。")
        Precheck_AddIssue("系统为 Windows 家庭版（" & $sOsName & "，EditionID=" & $sEdition & _
                "），不支持远程桌面主机等功能")
    Else
        Logger_Ok("  系统版本检查通过（" & $sEdition & "）。")
    EndIf
EndFunc

; 由内部版本号推断产品名（@OSVersion 在旧版 AutoIt 上对 Win11 仍返回 WIN_10）
Func PrecheckSystem_OsName($iBuild)
    If $iBuild >= 22000 Then Return "Windows 11"
    If $iBuild >= 10240 Then Return "Windows 10"
    If $iBuild >= 9600  Then Return "Windows 8.1"
    If $iBuild >= 9200  Then Return "Windows 8"
    If $iBuild >= 7600  Then Return "Windows 7"
    If $iBuild >= 2600  Then Return "Windows Vista"
    Return @OSVersion
EndFunc

; 判断是否家庭版：EditionID 为 Core 系列（Core / CoreSingleLanguage / CoreCountrySpecific / CoreN）
Func PrecheckSystem_IsHome($sEdition, $sProduct)
    Local $sE = StringLower(StringStripWS($sEdition, 3))
    Local $sP = StringLower(StringStripWS($sProduct, 3))

    If StringLeft($sE, 4) = "core" Then Return True
    If StringInStr($sP, "home")   Then Return True
    If StringInStr($sP, "家庭")   Then Return True

    Return False
EndFunc
