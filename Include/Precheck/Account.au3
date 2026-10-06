; ==============================================================================
; Precheck\Account.au3 —— 前置检查 5/5：开机账户
; ------------------------------------------------------------------------------
; 确保存在一个确定的本地账户（用户名 / 密码在配置界面或 config.ini 的 [Account] 段配置，
; 默认 admin / BJ88888888）：
;   · 不存在则创建；
;   · 设置 / 重置密码；
;   · 启用账户，并加入 Administrators 组（系统管理员）；
;   · 密码设为永不过期（否则到期后无法登录）——设置后**回读确认**，不只看退出码。
;
; 只管理**本地账户**：域账户 / 微软账户（含 @ 或 \）只提示，不创建。
; 用户名 / 密码里出现英文双引号会破坏命令，直接报错跳过。
;
; 改动前后各打印一次状态（Precheck_LogBefore / Precheck_LogAfter）：
; 是否启用、是否在管理员组、密码会不会过期 —— 用 WMI 读，避免解析本地化输出。
; 注意：正因如此，改动后读到的「会过期」也可能是**尚在传播的中间态**，
; 所以判定以「带重试的回读」为准，最终再真查一次密码是否过期才打 OK。
;
; 函数前缀：PrecheckAccount_*
; 共享状态与辅助在 Base.au3 里声明，本文件已 include。
; ==============================================================================

#include-once

#include "Base.au3"
#include "..\Constants.au3"
#include "..\Common.au3"
#include "..\Logger.au3"
#include "..\Config.au3"
#include "..\Installer.au3"

; 5/5 开机账户
Func PrecheckAccount_Check()
    Logger_Step("5/5 开机账户")

    Local $sUser = StringStripWS(Config_UserName(), 3)
    Local $sPass = Config_Password()

    If $sUser = "" Then
        Logger_Warn("  未配置开机用户名，跳过账户检查。")
        Precheck_AddIssue("未配置开机账户（用户名 / 密码），无法保证机器可用确定凭据登录")
        Return
    EndIf

    ; 命令里用双引号包裹参数，值里再出现双引号会破坏命令
    If StringInStr($sUser, '"') Then
        Logger_Err("  用户名不能包含英文双引号。")
        Precheck_AddIssue("开机账户用户名包含非法字符（" & Chr(34) & "）")
        Return
    EndIf
    If StringInStr($sPass, '"') Then
        Logger_Err("  密码不能包含英文双引号。")
        Precheck_AddIssue("开机账户密码包含非法字符（" & Chr(34) & "）")
        Return
    EndIf

    ; 域账户 / 微软账户不由本工具管理
    If StringInStr($sUser, "@") Or StringInStr($sUser, "\") Then
        Logger_Warn("  「" & $sUser & "」看起来是域账户或微软账户，本工具只管理本地账户，跳过创建。")
        Precheck_AddIssue("开机账户「" & $sUser & "」不是本地账户，请自行确认其密码可用")
        Return
    EndIf

    Precheck_LogBefore("「" & $sUser & "」" & PrecheckAccount_StateText($sUser))

    ; ---- 存在性：不存在则创建，存在则重置密码 ----
    If PrecheckAccount_UserExists($sUser) Then
        Logger_Info("  本地账户已存在：" & $sUser)
        If $sPass <> "" Then
            Logger_Info("  正在重置密码…")
            If Precheck_RunCmd("设置账户密码", 'net user "' & $sUser & '" "' & $sPass & '"') <> 0 Then
                Logger_Warn("  重置账户密码失败：" & $sUser)
                Precheck_AddIssue("重置账户「" & $sUser & "」密码失败")
            EndIf
        EndIf
    Else
        Logger_Info("  本地账户不存在，正在创建：" & $sUser)
        Local $sAdd = 'net user "' & $sUser & '"'
        If $sPass <> "" Then $sAdd &= ' "' & $sPass & '"'
        $sAdd &= " /add"

        If Precheck_RunCmd("创建账户 " & $sUser, $sAdd) <> 0 Then
            Logger_Err("  创建账户失败：" & $sUser)
            Precheck_AddIssue("创建本地账户「" & $sUser & "」失败，请手动创建")
            Return
        EndIf
    EndIf

    ; ---- 确保可用：启用账户 + 加入管理员组 ----
    Precheck_RunCmd("启用账户", 'net user "' & $sUser & '" /active:yes')

    If Not PrecheckAccount_GroupHasUser($PRECHK_ADMIN_GROUP, $sUser) Then
        Logger_Info("  正在把「" & $sUser & "」加入 " & $PRECHK_ADMIN_GROUP & " 组…")
        Precheck_RunCmd("加入管理员组", 'net localgroup ' & $PRECHK_ADMIN_GROUP & ' "' & $sUser & '" /add')

        If Not PrecheckAccount_GroupHasUser($PRECHK_ADMIN_GROUP, $sUser) Then
            Logger_Warn("  加入 " & $PRECHK_ADMIN_GROUP & " 组失败。")
            Precheck_AddIssue("账户「" & $sUser & "」不是管理员组成员")
        EndIf
    EndIf

    ; ---- 密码策略 ----
    If $sPass = "" Then
        Logger_Warn("  未设置密码，空密码账户无法通过远程桌面登录。")
        Precheck_AddIssue("开机账户「" & $sUser & "」未设置密码，远程桌面将无法登录")
    ElseIf Not PrecheckAccount_PasswordNeverExpires($sUser) Then
        Logger_Warn("  设置密码永不过期失败，密码到期后将无法登录。")
        Precheck_AddIssue("未能将账户「" & $sUser & "」的密码设为永不过期")
    EndIf

    Precheck_LogAfter("「" & $sUser & "」" & PrecheckAccount_StateText($sUser))

    ; ---- 最终校验：账户存在 + 密码永不过期（后者是「到期后登不进去」的隐患，要真查） ----
    If Not PrecheckAccount_UserExists($sUser) Then
        Logger_Err("  账户校验失败：" & $sUser)
        Precheck_AddIssue("开机账户「" & $sUser & "」校验失败")
        Return
    EndIf

    If $sPass = "" Then
        Logger_Warn("  开机账户检查通过：" & $sUser & "（但未设密码）")
        Return
    EndIf

    ; 到这里说明密码策略那一步已经报过问题；这里再确认一次，避免「报错了却打 OK」
    If PrecheckAccount_PasswordExpires($sUser) Then
        Logger_Err("  账户「" & $sUser & "」密码仍会过期，检查未通过。")
        Return
    EndIf

    Logger_Ok("  开机账户检查通过：" & $sUser)
EndFunc

; 当前账户状态的一句话描述（改动前后各打一次）。
; 「是否禁用 / 密码是否会过期」用 WMI 的 Win32_UserAccount 读 ——
; 比解析 net user 的本地化输出可靠（那些标签会随系统语言变化）。
; 「是否过期」复用 PrecheckAccount_PasswordExpires()，保证与最终校验同一口径。
Func PrecheckAccount_StateText($sUser)
    Local $oWMI = ObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
    If Not IsObj($oWMI) Then Return "无法查询（WMI 不可用）"

    ; WQL 用单引号作字符串定界符，用户名里的单引号要写成两个
    Local $sWql = StringReplace($sUser, "'", "''")

    Local $oList = $oWMI.ExecQuery("SELECT Disabled FROM Win32_UserAccount " & _
            "WHERE LocalAccount=True AND Name='" & $sWql & "'")
    If Not IsObj($oList) Then Return "无法查询（WMI 查询失败）"

    Local $bFound = False, $bDisabled = False

    For $oAcc In $oList
        $bFound = True
        $bDisabled = $oAcc.Disabled
    Next

    If Not $bFound Then Return "账户不存在"

    Local $sEnabled = "已启用"
    If $bDisabled Then $sEnabled = "已禁用"

    Local $sAdmin = "不在 " & $PRECHK_ADMIN_GROUP & " 组"
    If PrecheckAccount_GroupHasUser($PRECHK_ADMIN_GROUP, $sUser) Then
        $sAdmin = "在 " & $PRECHK_ADMIN_GROUP & " 组（系统管理员）"
    EndIf

    Local $sPwd = "密码永不过期"
    If PrecheckAccount_PasswordExpires($sUser) Then $sPwd = "密码会过期"

    Return "账户存在（" & $sEnabled & "，" & $sAdmin & "，" & $sPwd & "）"
EndFunc

; 本地账户是否存在（net user <名> 存在时返回 0，不存在返回 2）
Func PrecheckAccount_UserExists($sUser)
    Return (Precheck_RunCmd("查询账户 " & $sUser, 'net user "' & $sUser & '"') = 0)
EndFunc

; 判断某用户是否是某本地组的成员。
; 内置组的 SAM 名（Administrators / Users / Guests）不随系统语言变化，可直接用。
Func PrecheckAccount_GroupHasUser($sGroup, $sUser)
    Local $sOut = Precheck_Capture("查询 " & $sGroup & " 组", "net localgroup " & $sGroup)
    If $sOut = "" Then Return False

    Local $aLine = StringSplit(StringReplace($sOut, @CR, ""), @LF, 1)
    Local $sTarget = StringLower(StringStripWS($sUser, 3))

    For $i = 1 To $aLine[0]
        Local $s = StringStripWS($aLine[$i], 3)
        If StringLeft($s, 1) = "*" Then $s = StringStripWS(StringTrimLeft($s, 1), 3)
        If $s <> "" And StringLower($s) = $sTarget Then Return True
    Next

    Return False
EndFunc

; 密码永不过期：先 `net accounts /maxpwage:unlimited` 设全局策略，
; 再试 PowerShell 的 `Set-LocalUser -PasswordNeverExpires $true` 设该账户的 per-user 标志，
; 最后**回读确认**。两条路都不生效才返回 False 并如实报错。
;
; 【为什么要回读校验，不能只看退出码】实测结论（在 Win10/11 工控机上验证）：
;   · `Set-LocalUser` / `Get-LocalUser` 属于 PowerShell 的 LocalAccounts 模块，
;     **很多机器上根本没装**，调用时 PowerShell 报
;       「无法将"Set-LocalUser"项识别为 cmdlet…」并返回退出码 1。
;     所以老日志里的「Set-LocalUser 不可用」是**真实情况**，不是误报。
;   · 老实现的两个真实缺陷：
;       ① 只看退出码，不校验结果 —— 命令失败/未生效都无从得知；
;       ② 最终校验只查「账户是否存在」就打 [OK]，完全没管密码策略，
;          于是出现「…密码会过期」紧跟「[OK] 检查通过」的自相矛盾日志。
;   · WMI 的 Win32_UserAccount.PasswordExpires 读的是**该账户的 per-user
;     DONT_EXPIRE_PASSWD 标志**，不是全局 maxpwage。因此：
;       - 若账户自带「密码永不过期」，即便全局 maxpwage=30 也读 False（不过期）；
;       - 读出来是权威的，适合做回读校验。
;   现在改成：执行后**带重试地回读确认**（策略写入到状态可见有短暂延迟），
;   最终校验也真查一次密码是否过期，不通过就不打 OK。
Func PrecheckAccount_PasswordNeverExpires($sUser)
    ; 已经是「永不过期」就直接返回 —— 省掉几秒的 PowerShell 调用（很多机器上它还会失败）
    If Not PrecheckAccount_PasswordExpires($sUser) Then Return True

    ; 先设「全局密码最长使用期限 = 无限制」——
    ; 它对账户的最终效果取决于 per-user 标志，但成本低、无副作用，值得先试。
    Precheck_RunCmd("设置全局密码策略", "net accounts /maxpwage:unlimited")

    ; 再试针对该账户的 Set-LocalUser（机器没装 LocalAccounts 模块时会失败，不影响后续回读）
    Local $sCmd = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command " & _
            '"Set-LocalUser -Name ' & Common_PsQuote($sUser) & ' -PasswordNeverExpires $true"'
    Local $iRet = Installer_RunWaitBeat("设置密码永不过期", $sCmd, @ScriptDir, $TIMEOUT_PRECHECK)

    ; 回读确认（允许重试，等策略传播）
    If PrecheckAccount_WaitNeverExpires($sUser) Then Return True

    If $iRet <> 0 Then
        Logger_Warn("  Set-LocalUser 不可用或执行失败（退出码 " & $iRet & "），且全局策略回读后仍未生效。")
    Else
        Logger_Warn("  Set-LocalUser 执行成功，但回读仍显示密码会过期。")
    EndIf
    Return False
EndFunc

; 回读「密码是否永不过期」，最多重试若干次 —— 策略写入到状态可见之间有短暂延迟。
Func PrecheckAccount_WaitNeverExpires($sUser, $iRetries = 5)
    For $i = 0 To $iRetries
        If Not PrecheckAccount_PasswordExpires($sUser) Then Return True
        If $i < $iRetries Then Sleep(400)
    Next
    Return False
EndFunc

; 读「密码是否会过期」。读不出来时返回 True（按「会过期」处理，宁可报警也不漏）。
;
; 原先直接用 WMI 的 Win32_UserAccount.PasswordExpires，但它有个坑：
; 该值在某些时刻会返回 **空**（属性不可用），而 AutoIt 里空值经布尔判断会被当成 False，
; 于是「读不出来」会被误判成「不会过期」。这里显式区分「确认不过期」与「读不出来」。
Func PrecheckAccount_PasswordExpires($sUser)
    Local $oWMI = ObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
    If Not IsObj($oWMI) Then Return True

    ; WQL 用单引号作字符串定界符，用户名里的单引号要写成两个
    Local $sWql = StringReplace($sUser, "'", "''")

    Local $oList = $oWMI.ExecQuery("SELECT Disabled, PasswordExpires FROM Win32_UserAccount " & _
            "WHERE LocalAccount=True AND Name='" & $sWql & "'")
    If Not IsObj($oList) Then Return True

    Local $bFound = False
    Local $vExp = True

    For $oAcc In $oList
        $bFound = True
        $vExp = $oAcc.PasswordExpires
    Next

    If Not $bFound Then Return True
    If IsKeyword($vExp) = $KEYWORD_NULL Then Return True     ; 读到空 -> 按「会过期」处理
    If Not IsBool($vExp) Then Return True

    Return $vExp
EndFunc
