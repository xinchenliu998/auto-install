; ==============================================================================
; Precheck\Driver.au3 —— 前置检查 4/5：设备驱动
; ------------------------------------------------------------------------------
; 通过 WMI 枚举 ConfigManagerErrorCode <> 0 的设备（设备管理器里的感叹号），
; 列出设备名与错误码，只**报告**不修改 —— 装驱动无法自动化，交给现场处理。
;
; 错误码 45（设备当前未连接，如拔掉的 U 盘、未连接的蓝牙设备）属正常状态，不计入。
;
; 函数前缀：PrecheckDriver_*
; 共享状态与辅助（Precheck_AddDevice 等）在 Base.au3 里声明，本文件已 include。
; ==============================================================================

#include-once

#include "Base.au3"
#include "..\Constants.au3"
#include "..\Logger.au3"

; 4/5 设备驱动
Func PrecheckDriver_Check()
    Logger_Step("4/5 设备驱动")

    If Not PrecheckDriver_Collect() Then
        Logger_Warn("  无法通过 WMI 枚举设备，跳过驱动检查。")
        Return
    EndIf

    If $g_iPrecheckDevs = 0 Then
        Logger_Ok("  未发现驱动异常的设备。")
        Return
    EndIf

    Logger_Warn("  发现 " & $g_iPrecheckDevs & " 个设备存在驱动问题：")

    Local $iShow = $g_iPrecheckDevs
    If $iShow > 20 Then $iShow = 20

    For $i = 0 To $iShow - 1
        Logger_Warn("    · " & $g_aPrecheckDevs[$i][0] & _
                "（错误码 " & $g_aPrecheckDevs[$i][1] & "：" & $g_aPrecheckDevs[$i][2] & "）")
    Next
    If $g_iPrecheckDevs > $iShow Then
        Logger_Warn("    ... 另有 " & ($g_iPrecheckDevs - $iShow) & " 个设备，详见设备管理器。")
    EndIf

    Precheck_AddIssue("有 " & $g_iPrecheckDevs & " 个设备驱动异常（如「" & $g_aPrecheckDevs[0][0] & _
            "」），请在设备管理器中确认无感叹号设备")
EndFunc

; 枚举 ConfigManagerErrorCode <> 0 的设备。成功返回 True（结果存入共享数组）
Func PrecheckDriver_Collect()
    Local $oWMI = ObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
    If Not IsObj($oWMI) Then Return False

    Local $oList = $oWMI.ExecQuery( _
            "SELECT Name, ConfigManagerErrorCode FROM Win32_PnPEntity WHERE ConfigManagerErrorCode <> 0")
    If Not IsObj($oList) Then Return False

    For $oDev In $oList
        Local $iCode = Number($oDev.ConfigManagerErrorCode)

        ; 45 = 设备当前未连接，属正常状态，不计入
        If $iCode = $PRECHK_DEV_SKIP Then ContinueLoop

        Local $sName = $oDev.Name
        If StringStripWS($sName, 3) = "" Then $sName = "(未命名设备)"

        Precheck_AddDevice($sName, $iCode, PrecheckDriver_ErrText($iCode))
    Next

    Return True
EndFunc

; 设备管理器错误码 → 中文说明（只列常见项，其余归为「未知错误」）
Func PrecheckDriver_ErrText($iCode)
    Switch $iCode
        Case 1
            Return "设备未正确配置"
        Case 3
            Return "驱动程序已损坏或系统内存不足"
        Case 10
            Return "设备无法启动"
        Case 12
            Return "资源不足，无法分配所需资源"
        Case 14
            Return "需重启计算机后驱动才能生效"
        Case 16
            Return "无法识别该设备使用的全部资源"
        Case 18
            Return "需要重新安装驱动程序"
        Case 19
            Return "注册表内容损坏"
        Case 21
            Return "系统正在移除该设备"
        Case 22
            Return "设备已被禁用"
        Case 24
            Return "设备不存在或未正常工作"
        Case 28
            Return "驱动程序未安装"
        Case 29
            Return "固件未提供设备所需的资源"
        Case 31
            Return "Windows 无法加载该设备的驱动程序"
        Case 32
            Return "驱动程序的启动类型已禁用"
        Case 37
            Return "无法初始化设备驱动程序"
        Case 39
            Return "驱动程序已损坏或缺失"
        Case 43
            Return "设备因报告问题已被 Windows 停止"
        Case 52
            Return "无法验证驱动程序的数字签名"
        Case Else
            Return "未知错误"
    EndSwitch
EndFunc
