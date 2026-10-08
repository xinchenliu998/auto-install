; ==============================================================================
;  auto-install.au3  ——  auto-install 工控机出厂装机工具 · 总入口
; ------------------------------------------------------------------------------
;  执行流程：
;      配置界面（软件名称 / 安装根目录 / 开机账户 / 选择要安装的软件）
;        → 保存 config.ini
;        → 前置检查（系统版本 / ping 与远程桌面 / 电源 / 驱动 / 开机账户）
;        → 按所选软件依次执行安装，输出日志
;
;  命令行参数：
;      --run            跳过配置界面，直接按 config.ini 执行安装
;                       （用于无人值守场景，以及提权重启后继续执行）
;      --auto-close     执行结束后自动关闭，不等待人工确认
;      --help           显示帮助
;
;  编译建议：用 AutoIt v3 编译为 x64 可执行文件，可直接在无 AutoIt 环境的工控机上运行。
;  所有常量集中在 Include\Constants.au3，本文件不写死配置值。
; ==============================================================================

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <Misc.au3>

; ---- 框架模块 ----
#include "Include\Constants.au3"
#include "Include\Common.au3"
#include "Include\Logger.au3"
#include "Include\Config.au3"
#include "Include\Installer.au3"
#include "Include\Precheck.au3"
#include "Include\Gui\Config.au3"
#include "Include\Gui\Install.au3"

; ---- 各软件的安装模块（Include\Install\ 下，模块内部自注册）----
;      新增软件时只需在 Include\Install\All.au3 里登记一行，本文件无需改动。
#include "Include\Install\All.au3"

; ==============================================================================
;  入口
; ==============================================================================

Main()

Func Main()
    Config_Init()

    ; ---- 解析命令行 ----
    Local $bAutoRun   = False
    Local $bAutoClose = False

    For $i = 1 To $CmdLine[0]
        Switch StringLower($CmdLine[$i])
            Case $CLI_RUN, "/run"
                $bAutoRun = True
            Case $CLI_AUTO_CLOSE
                $bAutoClose = True
            Case $CLI_HELP, "/?", "-h", "/help"
                Main_ShowHelp()
                Return
        EndSwitch
    Next

    ; ---- 无人值守模式：直接按 config.ini 执行 ----
    If $bAutoRun Then
        If Not Config_Load() Then
            MsgBox($MB_WARN, $APP_TITLE, "未找到配置文件，无法执行。" & @CRLF & Config_File())
            Return
        EndIf

        Main_Execute($bAutoClose)
        Return
    EndIf

    ; ---- 配置界面模式（单实例保护）----
    If _Singleton($MUTEX_GUI, 1) = 0 Then
        MsgBox($MB_WARN, $APP_TITLE, "程序已在运行中，请勿重复启动。")
        Return
    EndIf

    Config_Load()

    If GuiConfig_Show() Then Main_Execute(False)
EndFunc

; ==============================================================================
;  执行安装
; ==============================================================================
Func Main_Execute($bUnattended = False)
    ; ---- 取出勾选的软件 ----
    Local $aSelected[1][$PKG_COL_COUNT]
    Local $iCount = Config_GetSelected($aSelected)

    ; ---- 初始化日志 ----
    Logger_Init(Config_LogFile())

    ; ---- 一项都没勾选：不中止，只记录日志 ----
    ;      出厂装机时可能只想跑一遍前置检查、或只做资源拷贝，所以「没有勾选软件」不算错误。
    If $iCount = 0 Then
        Logger_Warn("没有勾选任何要安装的软件，本次只记录日志。")
        If Not Config_CopyEnabled() Then
            Logger_Warn("        也未配置资源拷贝，将不会执行任何安装任务。")
        EndIf
    EndIf

    ; ---- 权限检查 ----
    If Common_IsElevated() Then
        Logger_Info("当前以管理员权限运行。")
    Else
        If Not $bUnattended Then
            Local $iRet = MsgBox($MB_YESNO_WARN, $APP_TITLE, _
                    "当前未以管理员权限运行。" & @CRLF & @CRLF & _
                    "部分软件（写入 Program Files、注册表等）需要管理员权限。" & @CRLF & _
                    "是否以管理员身份重新启动？" & @CRLF & @CRLF & _
                    "选择「否」将以当前权限继续执行。")

            If $iRet = $MB_RET_YES Then
                Config_Save()
                If Main_RelaunchElevated() Then Return
                MsgBox($MB_ERROR, $APP_TITLE, "提权启动失败，将以当前权限继续执行。")
            EndIf
        EndIf

        Logger_Warn("当前以普通用户权限运行，部分安装任务可能失败。")
    EndIf

    ; ---- 执行 ----
    $g_bRunAutoClose = $bUnattended
    Local $aStat = GuiInstall_Run($aSelected, $iCount)

    ; 有失败项时以非零退出码结束，便于外部批处理判断
    If IsArray($aStat) And $aStat[2] > 0 Then Exit($EXIT_FAIL)
EndFunc

; 以管理员身份重新启动自身，并直接进入执行模式
Func Main_RelaunchElevated()
    Local $sExe, $sParams

    If StringRight(@ScriptFullPath, 4) = ".au3" Then
        ; 源码方式运行（AutoIt 解释器）
        $sExe    = @AutoItExe
        $sParams = '"' & @ScriptFullPath & '" ' & $CLI_RUN
    Else
        ; 编译后的 exe
        $sExe    = @ScriptFullPath
        $sParams = $CLI_RUN
    EndIf

    Return ShellExecute($sExe, $sParams, @ScriptDir, "runas")
EndFunc

Func Main_ShowHelp()
    Local $sUsage = $APP_TITLE & "  v" & $APP_VERSION & @CRLF & @CRLF & "用法：" & @CRLF

    $sUsage &= StringFormat("  %-38s%s", "auto-install.exe", _
            "打开配置界面（默认）") & @CRLF
    $sUsage &= StringFormat("  %-38s%s", "auto-install.exe " & $CLI_RUN, _
            "按 config.ini 直接执行安装") & @CRLF
    $sUsage &= StringFormat("  %-38s%s", "auto-install.exe " & $CLI_RUN & " " & $CLI_AUTO_CLOSE, _
            "执行完自动关闭，不等待确认") & @CRLF
    $sUsage &= StringFormat("  %-38s%s", "auto-install.exe " & $CLI_HELP, _
            "显示本帮助") & @CRLF & @CRLF
    $sUsage &= "配置文件：" & Config_File() & @CRLF
    $sUsage &= "默认安装根目录：" & Config_DefaultRoot($APP_NAME)

    MsgBox($MB_INFO, $APP_TITLE, $sUsage)
EndFunc
