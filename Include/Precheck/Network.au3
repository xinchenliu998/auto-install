; ==============================================================================
; Precheck\Network.au3 —— 前置检查 2/5：网络可达性（ping）与远程桌面（RDP）
; ------------------------------------------------------------------------------
; 放通 ICMPv4 回显请求，并开启远程桌面（写注册表 + 放通 TCP 3389）。
;
; 防火墙规则用**自建名称**，不引用系统内置规则 —— 内置规则名（组名）随系统语言变化，
; 引用不可靠。每次先删除同名旧规则再添加，避免反复执行时规则越堆越多。
;
; 改动前后各打印一次状态（Precheck_LogBefore / Precheck_LogAfter），便于核对实际改了什么。
;
; 函数前缀：PrecheckNetwork_*
; 共享状态与辅助在 Base.au3 里声明，本文件已 include。
; ==============================================================================

#include-once

#include "Base.au3"
#include "..\Constants.au3"
#include "..\Logger.au3"
#include "..\Installer.au3"

; 2/5 网络可达性与远程桌面
Func PrecheckNetwork_Check()
    Logger_Step("2/5 网络可达性与远程桌面")

    Precheck_LogBefore(PrecheckNetwork_StateText())

    ; ---- ping：放通 ICMPv4 回显请求 ----
    If PrecheckNetwork_AddFwRule("放通 ping（ICMPv4 回显）", $PRECHK_FW_ICMP, "protocol=icmpv4:8,any") Then
        Logger_Ok("  已放通 ICMPv4 回显请求（ping），入站规则：" & $PRECHK_FW_ICMP)
    Else
        Logger_Warn("  放通 ping 失败，请检查 Windows 防火墙服务是否正常。")
        Precheck_AddIssue("未能放通 ping（ICMPv4 回显），本机可能无法被 ping 通")
    EndIf

    ; ---- 远程桌面 ----
    If $g_bPrecheckHome Then
        Logger_Warn("  家庭版不支持远程桌面主机，跳过 RDP 开启（防火墙规则即使添加也不会生效）。")
        Precheck_LogAfter(PrecheckNetwork_StateText())
        Return
    EndIf

    Local $bReg = PrecheckNetwork_EnableRdpReg()
    Local $bFw  = PrecheckNetwork_AddFwRule("放通远程桌面（TCP 3389）", $PRECHK_FW_RDP, _
            "protocol=TCP localport=3389")

    If $bReg And $bFw Then
        Logger_Ok("  远程桌面已开启（" & $PRECHK_RDP_VAL & "=0），并已放通 TCP 3389。")
    Else
        If Not $bReg Then Logger_Warn("  写入远程桌面注册表失败：" & $PRECHK_RDP_KEY & " / " & $PRECHK_RDP_VAL)
        If Not $bFw  Then Logger_Warn("  放通远程桌面防火墙规则失败。")
        Precheck_AddIssue("未能完整开启远程桌面（RDP），请手动确认「系统属性 - 远程」与防火墙规则")
    EndIf

    Precheck_LogAfter(PrecheckNetwork_StateText())
EndFunc

; 当前状态的一句话描述（改动前后各打一次）
Func PrecheckNetwork_StateText()
    Local $sText = "ping 规则（" & $PRECHK_FW_ICMP & "）：" & PrecheckNetwork_FwRuleState($PRECHK_FW_ICMP) & _
            "；RDP 规则（" & $PRECHK_FW_RDP & "）：" & PrecheckNetwork_FwRuleState($PRECHK_FW_RDP)

    If Not $g_bPrecheckHome Then
        $sText &= "；远程桌面：" & PrecheckNetwork_RdpState()
    EndIf

    Return $sText
EndFunc

; 远程桌面开关状态（读注册表 fDenyTSConnections）
Func PrecheckNetwork_RdpState()
    Local $vValue = RegRead($PRECHK_RDP_KEY, $PRECHK_RDP_VAL)
    If @error Then Return "未配置"

    If Number($vValue) = 0 Then Return "已开启"
    Return "已关闭"
EndFunc

; 防火墙规则是否存在。
; 判据是「netsh 的输出里有没有出现这条规则名」—— 规则名是我们自己起的纯 ASCII 名，
; 而「没有匹配的规则」那句提示是本地化文字，所以这个判断不受系统语言影响。
Func PrecheckNetwork_FwRuleState($sName)
    Local $sOut = Precheck_Capture("查询防火墙规则 " & $sName, _
            'netsh advfirewall firewall show rule name="' & $sName & '"')

    If StringStripWS($sOut, 3) = "" Then Return "无法查询（需要管理员权限？）"
    If StringInStr($sOut, $sName) Then Return "已存在"
    Return "不存在"
EndFunc

; 开启远程桌面：把 fDenyTSConnections 置 0，并回读确认
Func PrecheckNetwork_EnableRdpReg()
    If RegWrite($PRECHK_RDP_KEY, $PRECHK_RDP_VAL, "REG_DWORD", 0) = 0 Then Return False
    Return (Number(RegRead($PRECHK_RDP_KEY, $PRECHK_RDP_VAL)) = 0)
EndFunc

; 删除同名旧规则后重新添加（netsh 允许存在同名规则，先删是为了不堆积）
Func PrecheckNetwork_AddFwRule($sLabel, $sName, $sProto)
    Installer_RunWaitBeat($sLabel & "（清理旧规则）", _
            @ComSpec & ' /c netsh advfirewall firewall delete rule name="' & $sName & '"', _
            @ScriptDir, $TIMEOUT_PRECHECK)

    Local $iRet = Installer_RunWaitBeat($sLabel, _
            @ComSpec & ' /c netsh advfirewall firewall add rule name="' & $sName & _
            '" dir=in action=allow ' & $sProto, _
            @ScriptDir, $TIMEOUT_PRECHECK)

    Return ($iRet = 0)
EndFunc
