using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;
using System.Xml;
using Microsoft.Win32;

internal static class WgdotNative
{
    const string Version = "native-preview-72";
    const int WingetPreflightTimeoutMs = 30000;
    const string RepoFullName = "dillacorn/win-glaze-dots";
    const string RepoUrl = "https://github.com/dillacorn/win-glaze-dots.git";
    const string ApiBase = "https://api.github.com/repos/dillacorn/win-glaze-dots";
    const string StableTagPattern = "^v[0-9]+\\.[0-9]+\\.[0-9]+$";

    static readonly string TestRootOverride = Environment.GetEnvironmentVariable("WGDOT_TEST_ROOT");
    static readonly string InstallRoot = String.IsNullOrWhiteSpace(TestRootOverride)
        ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "wgdot")
        : Path.Combine(TestRootOverride, "wgdot");
    static readonly string BinRoot = Path.Combine(InstallRoot, "bin");
    static readonly string StateRoot = Path.Combine(InstallRoot, "state");
    static readonly string CacheRoot = Path.Combine(InstallRoot, "cache");
    static readonly string BaselineRoot = Path.Combine(StateRoot, "baseline");
    static readonly string InstallStatePath = Path.Combine(StateRoot, "installation.json");
    static readonly string BootstrapStatePath = Path.Combine(StateRoot, "native-bootstrap.json");
    static readonly string BaselineIndexPath = Path.Combine(BaselineRoot, "index.json");
    static readonly string BackupStatePath = Path.Combine(StateRoot, "backups.json");
    static readonly string ConfigStatePath = Path.Combine(StateRoot, "config.json");
    static readonly string GitStatePath = Path.Combine(StateRoot, "git-testing.json");
    static readonly string TweakStatePath = Path.Combine(StateRoot, "tweaks.json");
    static readonly string GpuStatePath = Path.Combine(StateRoot, "gpu-maintenance.json");
    static readonly string BrowserStatePath = Path.Combine(StateRoot, "browser-management.json");
    static readonly string ThemeStatePath = Path.Combine(StateRoot, "theme.json");
    static readonly string GlazeBindingModeStatePath = Path.Combine(StateRoot, "glazewm-binding-mode.json");
    static readonly string StartupStatePath = Path.Combine(StateRoot, "startup.json");
    static readonly string CursorStatePath = Path.Combine(StateRoot, "cursor.json");
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue, RecursionLimit = 100 };

    static readonly IntPtr HwndBroadcast = new IntPtr(0xffff);
    const uint WmSettingChange = 0x001A;
    const uint SmtoAbortIfHung = 0x0002;

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern IntPtr SendMessageTimeout(
        IntPtr hWnd,
        uint Msg,
        UIntPtr wParam,
        string lParam,
        uint fuFlags,
        uint uTimeout,
        out UIntPtr lpdwResult);

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);

    [DllImport("user32.dll")]
    static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    static extern short GetAsyncKeyState(int vKey);

    [StructLayout(LayoutKind.Sequential)]
    struct POINT
    {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct MSLLHOOKSTRUCT
    {
        public POINT pt;
        public uint mouseData;
        public uint flags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    delegate IntPtr LowLevelMouseProc(int nCode, IntPtr wParam, IntPtr lParam);


    [StructLayout(LayoutKind.Sequential)]
    struct KBDLLHOOKSTRUCT
    {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);

    [DllImport("user32.dll")]
    static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr SetWindowsHookEx(
        int idHook,
        LowLevelMouseProc lpfn,
        IntPtr hMod,
        uint dwThreadId);

    [DllImport("user32.dll")]
    static extern IntPtr WindowFromPoint(POINT point);

    [DllImport("user32.dll")]
    static extern IntPtr GetAncestor(IntPtr hWnd, uint gaFlags);

    [DllImport("user32.dll")]
    static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    static extern bool GetCursorPos(out POINT lpPoint);

    [DllImport("user32.dll", EntryPoint = "SetWindowsHookEx", SetLastError = true)]
    static extern IntPtr SetWindowsHookExKeyboard(
        int idHook,
        LowLevelKeyboardProc lpfn,
        IntPtr hMod,
        uint dwThreadId);

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    static extern IntPtr CallNextHookEx(
        IntPtr hhk,
        int nCode,
        IntPtr wParam,
        IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int GetClassName(IntPtr hWnd, StringBuilder className, int maxCount);

    [DllImport("user32.dll")]
    static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool LockWorkStation();

    [DllImport("powrprof.dll", SetLastError = true)]
    static extern bool SetSuspendState(bool hibernate, bool forceCritical, bool disableWakeEvent);

    [DllImport("dwmapi.dll")]
    static extern int DwmGetWindowAttribute(IntPtr hWnd, int attribute, out int value, int valueSize);

    const uint WmClose = 0x0010;
    const uint WmNcLButtonDown = 0x00A1;
    const uint WmLButtonUp = 0x0202;
    const int WmLButtonDown = 0x0201;
    const int WmRButtonDown = 0x0204;
    const int WmRButtonUp = 0x0205;
    const int WmMButtonDown = 0x0207;
    const int WmKeyDown = 0x0100;
    const int WmKeyUp = 0x0101;
    const int WmSysKeyDown = 0x0104;
    const int WmSysKeyUp = 0x0105;
    const int WhKeyboardLl = 13;
    const int WhMouseLl = 14;
    const uint GaRoot = 2;
    const uint LlMhfInjected = 0x00000001;
    const uint LlKhfInjected = 0x00000010;
    const int HtCaption = 2;
    const int HtTopLeft = 13;
    const int HtTopRight = 14;
    const int HtBottomLeft = 16;
    const int HtBottomRight = 17;
    const int DwmwaCloaked = 14;
    const int SwShowNormal = 1;
    const uint SwpNoSize = 0x0001;
    const uint SwpNoZOrder = 0x0004;
    const uint SwpShowWindow = 0x0040;
    const uint ShgfiIcon = 0x00000100;
    const uint KeyeventfKeyup = 0x0002;
    const uint WmFontChange = 0x001D;

    const string IdleInhibitorMutexName = @"Local\WGDot.IdleInhibitor";
    const string IdleInhibitorStopEventName = @"Local\WGDot.IdleInhibitorStop";

    const string MouseModeMutexName = @"Local\WGDot.MouseModeHook";
    const string MouseModeStopEventName = @"Local\WGDot.MouseModeStop";
    const string SuperLTestMutexName = @"Local\WGDot.SuperLTestHook";
    const string SuperLTestStopEventName = @"Local\WGDot.SuperLTestStop";

    const string DesktopWorkerMutexName = @"Local\WGDot.DesktopWorker";
    const string DesktopWorkerStopEventName = @"Local\WGDot.DesktopWorkerStop";
    const string ClipboardHistoryWindowTitle = "WGDot Clipboard History";

    static LowLevelKeyboardProc SuperLHookProc;
    static IntPtr SuperLHookHandle = IntPtr.Zero;
    static bool SuperLLeftWinDown;
    static bool SuperLRightWinDown;
    static bool SuperLSuppressKeyUp;

    const byte VkL = 0x4C;
    const byte VkV = 0x56;
    const byte VkLwin = 0x5B;
    const byte VkRwin = 0x5C;

    [DllImport("shell32.dll")]
    static extern void SHChangeNotify(uint wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr ShellExecute(
        IntPtr hwnd,
        string operation,
        string file,
        string parameters,
        string directory,
        int showCommand);

    [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern int AddFontResourceEx(
        string fileName,
        uint flags,
        IntPtr reserved);

    [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool RemoveFontResourceEx(
        string fileName,
        uint flags,
        IntPtr reserved);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct SHFILEINFO
    {
        public IntPtr hIcon;
        public int iIcon;
        public uint dwAttributes;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
        public string szDisplayName;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)]
        public string szTypeName;
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr SHGetFileInfo(
        string path,
        uint fileAttributes,
        out SHFILEINFO fileInfo,
        uint fileInfoSize,
        uint flags);

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool DestroyIcon(IntPtr icon);

    [DllImport("user32.dll", SetLastError = true)]
    static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr insertAfter,
        int x,
        int y,
        int width,
        int height,
        uint flags);

    [StructLayout(LayoutKind.Sequential)]
    struct SP_DEVINFO_DATA
    {
        public int cbSize;
        public Guid ClassGuid;
        public uint DevInst;
        public IntPtr Reserved;
    }

    [DllImport("setupapi.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern IntPtr SetupDiGetClassDevs(
        ref Guid ClassGuid,
        string Enumerator,
        IntPtr hwndParent,
        uint Flags);

    [DllImport("setupapi.dll", SetLastError = true)]
    static extern bool SetupDiEnumDeviceInfo(
        IntPtr DeviceInfoSet,
        uint MemberIndex,
        ref SP_DEVINFO_DATA DeviceInfoData);

    [DllImport("setupapi.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern bool SetupDiGetDeviceRegistryProperty(
        IntPtr DeviceInfoSet,
        ref SP_DEVINFO_DATA DeviceInfoData,
        uint Property,
        out uint PropertyRegDataType,
        byte[] PropertyBuffer,
        uint PropertyBufferSize,
        out uint RequiredSize);

    [DllImport("setupapi.dll", SetLastError = true)]
    static extern bool SetupDiDestroyDeviceInfoList(IntPtr DeviceInfoSet);

    const uint DigcfPresent = 0x00000002;
    const uint SpdrpDeviceDesc = 0x00000000;
    const uint SpdrpHardwareId = 0x00000001;
    const uint SpdrpDriver = 0x00000009;
    const uint SpdrpMfg = 0x0000000B;
    const uint SpdrpFriendlyName = 0x0000000C;
    static readonly IntPtr InvalidHandleValue = new IntPtr(-1);

    sealed class ChoiceItem
    {
        public string Id;
        public string Label;
        public string Category;
        public bool Selected;
    }

    sealed class InstallationSelection
    {
        public string Scope;
        public string GlazeProfile;
        public List<string> Components = new List<string>();
        public List<string> Packages = new List<string>();
        public List<string> Tweaks = new List<string>();
        public bool TweaksConfigured;
        public Dictionary<string, List<string>> BrowserOptions =
            new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
        public bool BrowserOptionsConfigured;
    }

    sealed class IniSection
    {
        public string Name;
        public Dictionary<string, string> Values =
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    }

    sealed class PlanItem
    {
        public string FileId;
        public string Component;
        public string Destination;
        public string Target;
        public string Baseline;
        public string Status;
        public string Action;
        public bool Merge;
        public bool CommitTargetBaseline;
        public string Validator;
    }

    sealed class ProcResult
    {
        public int ExitCode;
        public string StdOut;
        public string StdErr;
        public bool TimedOut;
    }

    sealed class SourceContext
    {
        public string Mode;
        public string Tag;
        public string Revision;
        public string Branch;
        public string SourceRoot;
        public Dictionary<string, object> Manifest;
    }

    sealed class GpuAdapterInfo
    {
        public string Vendor;
        public string Name;
        public string HardwareId;
        public string Manufacturer;
        public string DriverProvider;
        public string DriverVendor;
        public string DriverVersion;
        public string DriverKey;
    }

    sealed class PowerAction
    {
        public char Key;
        public string Icon;
        public string Label;
        public Action Invoke;

        public PowerAction(char key, string icon, string label, Action invoke)
        {
            Key = key;
            Icon = icon;
            Label = label;
            Invoke = invoke;
        }
    }

    sealed class PowerMenuAnimationState
    {
        public bool AllowClose;
        public bool FadingOut;
        public Action AfterClose;
        public System.Windows.Forms.Timer FadeInTimer;
        public System.Windows.Forms.Timer FadeOutTimer;
    }

    sealed class LauncherApp
    {
        public string Name;
        public string Path;
        public string IconPath;
        public System.Drawing.Image IconImage;
        public bool IconLoaded;

        public override string ToString()
        {
            return Name ?? "";
        }
    }

    // Windows/YASB equivalents of the current Awtarchy theme palettes.
    // GlazeWM is intentionally excluded so applying a theme never reloads the WM.
    sealed class YasbTheme
    {
        public string Id;
        public string Label;
        public string Background;
        public string Foreground;
        public string Hover;
        public string Focus;
        public string Active;
        public string Urgent;
        public string Dark;
        public string Charging;
        public string Critical;
        public string Muted;

        public YasbTheme(
            string id,
            string label,
            string background,
            string foreground,
            string hover,
            string focus,
            string active,
            string urgent,
            string dark,
            string charging,
            string critical,
            string muted)
        {
            Id = id;
            Label = label;
            Background = background;
            Foreground = foreground;
            Hover = hover;
            Focus = focus;
            Active = active;
            Urgent = urgent;
            Dark = dark;
            Charging = charging;
            Critical = critical;
            Muted = muted;
        }
    }

    // Windows/YASB equivalents of the current Awtarchy theme palettes.
    // GlazeWM is intentionally excluded so applying a theme never reloads the WM.
    static readonly List<YasbTheme> YasbThemes = new List<YasbTheme>
    {
        new YasbTheme("carbon-night", "Carbon Night", "#353535", "#d0d0d0", "#404040", "#4a4a4a", "#2b2b2b", "#ff5555", "#1a1a1a", "#6a9955", "#ff5555", "#5c5c5c"),
        new YasbTheme("catppuccin-frappe", "Catppuccin Frappe", "#303446", "#c6d0f5", "#414559", "#535970", "#383c4d", "#e78284", "#232634", "#a6d189", "#ef9f76", "#a5adce"),
        new YasbTheme("crimson-red", "Crimson Red", "#1e1e2e", "#f38ba8", "#352630", "#5a3442", "#292330", "#f38ba8", "#1e1e2e", "#fab387", "#f38ba8", "#9f8994"),
        new YasbTheme("electric-blue", "Electric Blue", "#1e1e2e", "#89b4fa", "#293448", "#34445e", "#252938", "#f38ba8", "#1e1e2e", "#a6e3a1", "#fab387", "#8993a8"),
        new YasbTheme("gruvbox", "Gruvbox", "#282828", "#ebdbb2", "#4a423c", "#665c4e", "#3c3836", "#b16286", "#fbf1c7", "#98971a", "#cc241d", "#a89984"),
        new YasbTheme("iron-forge", "Iron Forge", "#0f1113", "#bcd2d2", "#1f2328", "#242a32", "#0d0f12", "#a31717", "#ffffff", "#1f6f6f", "#a31717", "#6a7b86"),
        new YasbTheme("obsidian-night", "Obsidian Night", "#0f0f0f", "#cdd6f4", "#1e1e2e", "#313244", "#1a1a1a", "#ff5555", "#1e1e2e", "#6a9955", "#ff5555", "#4b4b4b"),
        new YasbTheme("pink", "Pink", "#D297A1", "#2E2E2E", "#B77F91", "#C0AFC0", "#C0AFC0", "#B04155", "#FFFFFF", "#D3D3D3", "#B04155", "#7A7A7A"),
        new YasbTheme("pipboy", "Pip-Boy", "#050805", "#a4ff47", "#1f301f", "#1b281b", "#101810", "#263826", "#050805", "#a4ff47", "#3c1b1b", "#2a3d2a")
    };

    static readonly string[] CursorThemeIds = new[]
    {
        "bibata-modern-ice", "bibata-modern-classic", "bibata-modern-amber",
        "bibata-original-ice", "bibata-original-classic", "bibata-original-amber",
        "bibata-modern-ice-right", "bibata-modern-classic-right", "bibata-modern-amber-right",
        "bibata-original-ice-right", "bibata-original-classic-right", "bibata-original-amber-right",
        "oops-all-links", "windows-default"
    };

    static readonly Dictionary<string, string> CursorThemeLabels =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "bibata-modern-ice", "Bibata Modern Ice - rounded / normal" },
            { "bibata-modern-classic", "Bibata Modern Classic - rounded / normal" },
            { "bibata-modern-amber", "Bibata Modern Amber - rounded / normal" },
            { "bibata-original-ice", "Bibata Original Ice - sharp / normal" },
            { "bibata-original-classic", "Bibata Original Classic - sharp / normal" },
            { "bibata-original-amber", "Bibata Original Amber - sharp / normal" },
            { "bibata-modern-ice-right", "Bibata Modern Ice - rounded / right hand" },
            { "bibata-modern-classic-right", "Bibata Modern Classic - rounded / right hand" },
            { "bibata-modern-amber-right", "Bibata Modern Amber - rounded / right hand" },
            { "bibata-original-ice-right", "Bibata Original Ice - sharp / right hand" },
            { "bibata-original-classic-right", "Bibata Original Classic - sharp / right hand" },
            { "bibata-original-amber-right", "Bibata Original Amber - sharp / right hand" },
            { "oops-all-links", "Oops all links" },
            { "windows-default", "Windows default / restore pre-WGDot cursor" }
        };

    static readonly Dictionary<string, string> BibataCursorAssets =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "bibata-modern-ice", "Bibata-Modern-Ice" },
            { "bibata-modern-classic", "Bibata-Modern-Classic" },
            { "bibata-modern-amber", "Bibata-Modern-Amber" },
            { "bibata-original-ice", "Bibata-Original-Ice" },
            { "bibata-original-classic", "Bibata-Original-Classic" },
            { "bibata-original-amber", "Bibata-Original-Amber" },
            { "bibata-modern-ice-right", "Bibata-Modern-Ice-Right" },
            { "bibata-modern-classic-right", "Bibata-Modern-Classic-Right" },
            { "bibata-modern-amber-right", "Bibata-Modern-Amber-Right" },
            { "bibata-original-ice-right", "Bibata-Original-Ice-Right" },
            { "bibata-original-classic-right", "Bibata-Original-Classic-Right" },
            { "bibata-original-amber-right", "Bibata-Original-Amber-Right" }
        };

    [STAThread]
    static int Main(string[] args)
    {
        bool stagedRuntime = false;
        string command = args.Length == 0 ? "menu" : args[0].ToLowerInvariant();

        try
        {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            EnsureStateDirectories();
            stagedRuntime = IsStagedRuntimeProcess() && !IsRuntimeSwapInternalCommand(command);

            if (ShouldAutoRefreshRuntime(command) &&
                !String.Equals(Environment.GetEnvironmentVariable("WGDOT_SKIP_RUNTIME_REFRESH"), "1", StringComparison.Ordinal))
            {
                try
                {
                    int refreshedExitCode;
                    if (TryRefreshRuntimeAndRun(args, out refreshedExitCode))
                        return refreshedExitCode;
                }
                catch (Exception ex)
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("WGDot runtime refresh check failed; continuing installed runtime.");
                    Console.WriteLine(ex.Message);
                    Console.ResetColor();
                    Console.WriteLine();
                }
            }

            if (command == "install") return Install();
            if (command == "status") return Status();
            if (command == "menu") return Menu();
            if (command == "self-test") return SelfTest();
            if (command == "git-review") return GitManagedFromArgs("review", args.Skip(1).ToArray());
            if (command == "git-update") return GitManagedFromArgs("update", args.Skip(1).ToArray());
            if (command == "git-reset") return GitManagedFromArgs("reset", args.Skip(1).ToArray());
            if (command == "apply-tweak") return ApplyTweakFromArgs(args.Skip(1).ToArray());
            if (command == "restore-clipboard-history") return RestorePrivacySexyClipboardHistory();
            if (command == "migrate-legacy-hotkeys") return MigrateLegacyWindowsShellHotkeys(true);
            if (command == "mark-runtime") return MarkRuntimeFromArgs(args.Skip(1).ToArray());
            if (command == "runtime-swap-stop") return RuntimeSwapStopFromArgs(args.Skip(1).ToArray());
            if (command == "runtime-swap-restore") return RuntimeSwapRestoreFromArgs(args.Skip(1).ToArray());
            if (command == "maintenance-self-test") return MaintenanceSelfTest();
            if (command == "source-self-test") return SourceSelfTestFromArgs(args.Skip(1).ToArray());
            if (command == "dots-only") return DotsOnlyFromArgs(args.Skip(1).ToArray());
            if (command == "software") return SoftwareManager();
            if (command == "software-reconcile") return SoftwareReconcile();
            if (command == "software-uninstall") return SoftwareUninstallManager();
            if (command == "startup") return StartupManager();
            if (command == "startup-disable-all") return DisableAllManagedStartup(true);
            if (command == "software-audit") return SoftwareCatalogAudit();
            if (command == "ensure-winget") return EnsureWingetAvailable();
            if (command == "acceptance-audit") return AcceptanceAudit();
            if (command == "software-elevated") return SoftwareElevatedFromArgs(args.Skip(1).ToArray());
            if (command == "cursor") return CursorManagerFromArgs(args.Skip(1).ToArray());
            if (command == "window-audit") return WindowAudit();
            if (command == "super-l-test") return SuperLTestFromArgs(args.Skip(1).ToArray());
            if (command == "super-l-hook") return SuperLHookWorker();
            if (command == "bar-autohide-toggle") return BarAutoHideToggle();
            if (command == "glazewm-binding-mode-toggle") return GlazeWmBindingModeToggleFromArgs(args.Skip(1).ToArray());
            if (command == "theme") return ThemeManagerFromArgs(args.Skip(1).ToArray());
            if (command == "theme-window-toggle") return ThemeWindowToggle();
            if (command == "clipboard-history-open") return ClipboardHistoryOpen();
            if (command == "launcher") return LauncherFromArgs(args.Skip(1).ToArray());
            if (command == "power-menu") return PowerMenu();
            if (command == "rawaccel-toggle") return RawAccelToggle();
            if (command == "gpu-driver") return GpuDriverMaintenance();
            if (command == "gpu-stage-safe") return GpuStageSafeFromArgs(args.Skip(1).ToArray());
            if (command == "gpu-safe-resume") return GpuSafeResume();
            if (command == "gpu-install") return GpuInstallFromArgs(args.Skip(1).ToArray());
            if (command == "update") return ManagedOperation("update", ResolveDefaultSource());
            if (command == "reset") return ManagedOperation("reset", ResolveDefaultSource());
            if (command == "review") return ManagedOperation("review", ResolveDefaultSource());

            Console.Error.WriteLine("Unknown WGDot native command: " + command);
            Console.Error.WriteLine("Run wgdot with no arguments for the menu.");
            return 2;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("WGDot native error: " + ex.Message);
            return 1;
        }
        finally
        {
            if (stagedRuntime)
            {
                try
                {
                    ScheduleStagedRuntimeInstall();
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine("WGDot runtime install finalization warning: " + ex.Message);
                }
            }
        }
    }

    static bool ShouldAutoRefreshRuntime(string command)
    {
        return
            String.Equals(command, "menu", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "status", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "git-review", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "git-update", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "git-reset", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "dots-only", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "apply-tweak", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "super-l-test", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "window-audit", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "software", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "software-reconcile", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "software-uninstall", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "startup", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "startup-disable-all", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "software-audit", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "acceptance-audit", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "cursor", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "gpu-driver", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "update", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "reset", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "review", StringComparison.OrdinalIgnoreCase);
    }

    static bool IsRuntimeSwapInternalCommand(string command)
    {
        return
            String.Equals(command, "runtime-swap-stop", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(command, "runtime-swap-restore", StringComparison.OrdinalIgnoreCase);
    }

    static bool IsStagedRuntimeProcess()
    {
        if (!String.Equals(
                Environment.GetEnvironmentVariable("WGDOT_SKIP_RUNTIME_REFRESH"),
                "1",
                StringComparison.Ordinal))
            return false;

        string currentExe = Path.GetFullPath(Process.GetCurrentProcess().MainModule.FileName);
        string installedExe = Path.GetFullPath(Path.Combine(BinRoot, "wgdot.exe"));
        return !String.Equals(currentExe, installedExe, StringComparison.OrdinalIgnoreCase);
    }

    static void EnsureStateDirectories()
    {
        Directory.CreateDirectory(InstallRoot);
        Directory.CreateDirectory(BinRoot);
        Directory.CreateDirectory(StateRoot);
        Directory.CreateDirectory(CacheRoot);
        Directory.CreateDirectory(BaselineRoot);
    }

    static void WaitForRuntimeWorkerState(string mutexName, bool expected, string label)
    {
        for (int i = 0; i < 100; i++)
        {
            if (NamedMutexExists(mutexName) == expected)
                return;
            System.Threading.Thread.Sleep(50);
        }

        throw new Exception(
            "WGDot " + label + " worker did not " + (expected ? "start." : "stop."));
    }

    static void StartRuntimeWorkerFrom(string exe, string arguments)
    {
        var psi = new ProcessStartInfo();
        psi.FileName = exe;
        psi.Arguments = arguments;
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.WindowStyle = ProcessWindowStyle.Hidden;
        psi.EnvironmentVariables["WGDOT_SKIP_RUNTIME_REFRESH"] = "1";

        Process process = Process.Start(psi);
        if (process == null)
            throw new Exception("Failed to restart WGDot runtime worker '" + arguments + "'.");
    }

    static void CopyRuntimeWithRetry(string source, string destination)
    {
        Exception last = null;
        for (int i = 0; i < 100; i++)
        {
            try
            {
                File.Copy(source, destination, true);
                return;
            }
            catch (IOException ex)
            {
                last = ex;
            }
            catch (UnauthorizedAccessException ex)
            {
                last = ex;
            }

            System.Threading.Thread.Sleep(50);
        }

        throw new IOException(
            "Could not replace the installed WGDot runtime after waiting for active helpers to release it.",
            last);
    }

    static int Install()
    {
        EnsureStateDirectories();

        string currentExe = Process.GetCurrentProcess().MainModule.FileName;
        string targetExe = Path.Combine(BinRoot, "wgdot.exe");
        string sourceRoot = Environment.GetEnvironmentVariable("WGDOT_SOURCE_ROOT");
        if (String.IsNullOrWhiteSpace(sourceRoot)) sourceRoot = FindRepoRoot(AppDomain.CurrentDomain.BaseDirectory);
        if (!String.IsNullOrWhiteSpace(sourceRoot)) sourceRoot = Path.GetFullPath(sourceRoot);
        string sourceRef = Environment.GetEnvironmentVariable("WGDOT_SOURCE_REF") ?? "";
        string sourceRevision = Environment.GetEnvironmentVariable("WGDOT_SOURCE_REVISION") ?? "";
        bool sourceExplicit = String.Equals(
            Environment.GetEnvironmentVariable("WGDOT_SOURCE_EXPLICIT"),
            "1",
            StringComparison.Ordinal);

        bool replacingInstalledRuntime =
            !String.Equals(
                Path.GetFullPath(currentExe),
                Path.GetFullPath(targetExe),
                StringComparison.OrdinalIgnoreCase);

        if (replacingInstalledRuntime && File.Exists(targetExe))
        {
            // Migration cleanup only: stop any workers left behind by an older
            // WGDot desktop-helper build. The management-only runtime never
            // restores these workers after replacement.
            bool idle = NamedMutexExists(IdleInhibitorMutexName);
            bool mouse = NamedMutexExists(MouseModeMutexName);
            bool superL = NamedMutexExists(SuperLTestMutexName);
            bool desktop = NamedMutexExists(DesktopWorkerMutexName);

            IntPtr clipboardWindow = FindTopLevelWindowByExactTitle(ClipboardHistoryWindowTitle);
            if (clipboardWindow != IntPtr.Zero)
                PostMessage(clipboardWindow, WmClose, IntPtr.Zero, IntPtr.Zero);

            if (idle) SignalIdleInhibitorStop();
            if (mouse) SignalMouseModeHookStop();
            if (superL) SignalSuperLTestStop();
            if (desktop) SignalDesktopWorkerStop();

            if (idle) WaitForRuntimeWorkerState(IdleInhibitorMutexName, false, "legacy idle inhibitor");
            if (mouse) WaitForRuntimeWorkerState(MouseModeMutexName, false, "legacy mouse-mode");
            if (superL) WaitForRuntimeWorkerState(SuperLTestMutexName, false, "Super+L test");
            if (desktop) WaitForRuntimeWorkerState(DesktopWorkerMutexName, false, "legacy desktop worker");
        }

        if (replacingInstalledRuntime)
            CopyRuntimeWithRetry(currentExe, targetExe);

        EnsureHiddenLauncher();

        string cmd = "@echo off\r\n\"%~dp0wgdot.exe\" %*\r\n";
        File.WriteAllText(Path.Combine(BinRoot, "wgdot.cmd"), cmd, Encoding.ASCII);
        AddUserPath(BinRoot);

        var state = new Dictionary<string, object>();
        state["version"] = Version;
        state["installedAt"] = DateTime.UtcNow.ToString("o");
        state["sourceRoot"] = sourceRoot;
        state["sourceRef"] = sourceRef;
        state["sourceRevision"] = sourceRevision;
        state["sourceExplicit"] = sourceExplicit;
        state["executionPolicyIndependent"] = true;
        WriteJson(BootstrapStatePath, state);

        Console.WriteLine("WGDot native runtime installed to:");
        Console.WriteLine("  " + BinRoot);
        Console.WriteLine();
        Console.WriteLine("It does not change or bypass PowerShell execution policy.");
        Console.WriteLine("Run: wgdot");
        return 0;
    }

    static int Status()
    {
        Console.WriteLine("WGDot native runtime");
        Console.WriteLine("Version: " + Version);
        Console.WriteLine("Install root: " + InstallRoot);
        Console.WriteLine("Executable: " + Process.GetCurrentProcess().MainModule.FileName);
        Console.WriteLine("PowerShell execution policy required: no");

        var state = ReadJson(BootstrapStatePath);
        if (state != null)
        {
            string sourceRoot = GetString(state, "sourceRoot");
            string sourceRef = GetString(state, "sourceRef");
            string sourceRevision = GetString(state, "sourceRevision");
            if (!String.IsNullOrWhiteSpace(sourceRoot)) Console.WriteLine("Runtime source root: " + sourceRoot);
            if (!String.IsNullOrWhiteSpace(sourceRef)) Console.WriteLine("Runtime source ref: " + sourceRef);
            if (!String.IsNullOrWhiteSpace(sourceRevision)) Console.WriteLine("Runtime source revision: " + sourceRevision);
            if (GetBool(state, "sourceExplicit")) Console.WriteLine("Runtime config source: explicit ref testing");
            Console.WriteLine("Installed: " + GetString(state, "installedAt"));
        }

        var config = ReadJson(ConfigStatePath);
        if (config != null)
            Console.WriteLine("Stable config: " + GetString(config, "tag") + " @ " + GetString(config, "revision"));

        var git = ReadJson(GitStatePath);
        if (git != null)
            Console.WriteLine("Git test: " + GetString(git, "branch") + " @ " + GetString(git, "revision"));

        Console.WriteLine("Managed selection: " + (File.Exists(InstallStatePath) ? "configured" : "not configured"));
        Console.WriteLine("Baseline: " + (File.Exists(BaselineIndexPath) ? "present" : "not initialized"));
        Console.WriteLine("Recorded backups: " + CountRecordedBackups().ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Cursor theme: " + CurrentCursorThemeId());

        var gpuState = ReadJson(GpuStatePath);
        if (gpuState != null)
            Console.WriteLine("GPU maintenance: " + GetString(gpuState, "phase") + " (" + GpuVendorLabel(GetString(gpuState, "targetVendor")) + ")");

        return 0;
    }

    static int Menu()
    {
        if (IsSafeMode() && HasPendingGpuSafeModeCleanup())
            return GpuSafeResume();

        if (ShowGpuPendingNotice())
            Pause();

        var items = new List<string>
        {
            "Update managed dots",
            "Software / startup manager",
            "GPU driver maintenance",
            "Cursor theme switcher",
            "Windows tweaks / integrations",
            "Reset / reconfigure managed dots",
            "Review changes without applying",
            "Backup manager",
            "Manual PowerShell fallback",
            "Version / status",
            "Development / testing",
            "Exit"
        };

        while (true)
        {
            int choice = ReadSingleChoice("Maintenance", items, 0);
            if (choice < 0 || choice == 11) return 0;

            try
            {
                if (choice == 0)
                {
                    ManagedOperation("update", ResolveDefaultSource());
                    Pause();
                }
                else if (choice == 1) SoftwareManager();
                else if (choice == 2) GpuDriverMaintenance();
                else if (choice == 3) CursorManager();
                else if (choice == 4) TweakManager();
                else if (choice == 5)
                {
                    ManagedOperation("reset", ResolveDefaultSource());
                    Pause();
                }
                else if (choice == 6)
                {
                    ManagedOperation("review", ResolveDefaultSource());
                    Pause();
                }
                else if (choice == 7) BackupManager();
                else if (choice == 8)
                {
                    ShowManualFallback();
                    Pause();
                }
                else if (choice == 9)
                {
                    WriteTitle("Version / status");
                    Status();
                    Pause();
                }
                else if (choice == 10) ShowDevelopmentMenu();
            }
            catch (Exception ex)
            {
                Console.WriteLine();
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("ERROR: " + ex.Message);
                Console.ResetColor();
                Pause();
            }
        }
    }

    static void ShowDevelopmentMenu()
    {
        var items = new List<string>
        {
            "Audit all software (no install)",
            "Automated acceptance audit (safe)",
            "Advanced / Git testing",
            "Back"
        };

        while (true)
        {
            int choice = ReadSingleChoice(
                "Development / testing - maintainer tools",
                items,
                0);
            if (choice < 0 || choice == 3) return;

            if (choice == 0)
            {
                SoftwareCatalogAudit();
                Pause();
            }
            else if (choice == 1)
            {
                AcceptanceAudit();
                Pause();
            }
            else if (choice == 2) ShowGitMenu();
        }
    }

    static void AppendRuntimeRefreshDiagnostic(string message)
    {
        try
        {
            Directory.CreateDirectory(StateRoot);
            File.AppendAllText(
                Path.Combine(StateRoot, "runtime-refresh.log"),
                DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture) +
                " " + (message ?? "") + Environment.NewLine,
                new UTF8Encoding(false));
        }
        catch
        {
        }
    }

    static bool TryRefreshRuntimeAndRun(string[] originalArgs, out int exitCode)
    {
        exitCode = 0;

        var state = ReadJson(BootstrapStatePath);
        if (state == null) return false;

        string sourceRef = GetString(state, "sourceRef");
        if (String.IsNullOrWhiteSpace(sourceRef)) sourceRef = "main";
        ValidateBranchName(sourceRef);

        string installedRevision = GetString(state, "sourceRevision");
        string remoteRevision;
        try
        {
            remoteRevision = ResolveBranchHeadViaApi(sourceRef);
        }
        catch (Exception ex)
        {
            // Some managed/corporate networks allow raw.githubusercontent.com
            // while blocking api.github.com. A refresh check is optional; an
            // already-installed exact runtime must remain usable offline from
            // the API rather than failing every user-facing command.
            AppendRuntimeRefreshDiagnostic(
                "Runtime refresh check skipped for " + sourceRef + ": " + ex.Message);
            return false;
        }

        if (String.Equals(installedRevision, remoteRevision, StringComparison.OrdinalIgnoreCase))
            return false;

        WriteTitle("Runtime refresh");
        Console.WriteLine("New WGDot runtime available from " + sourceRef + ".");
        Console.WriteLine("Installed: " + (String.IsNullOrWhiteSpace(installedRevision) ? "(unknown)" : installedRevision));
        Console.WriteLine("Remote:    " + remoteRevision);
        Console.WriteLine();

        string sourcePath = Path.Combine(CacheRoot, "runtime-" + remoteRevision + ".cs");
        string nextExe = Path.Combine(CacheRoot, "wgdot-next-" + remoteRevision + ".exe");
        SafeDeleteFile(sourcePath);
        SafeDeleteFile(nextExe);

        string rawUrl = "https://raw.githubusercontent.com/" + RepoFullName + "/" + remoteRevision + "/wgdot/wgdot-native.cs";
        using (var client = new WebClient())
        {
            client.Headers[HttpRequestHeader.UserAgent] = "wgdot";
            client.DownloadFile(rawUrl, sourcePath);
        }

        CompileNativeSource(sourcePath, nextExe);
        ProcResult test = Run(nextExe, "self-test", null);
        if (test.ExitCode != 0)
            throw new Exception("Refreshed runtime self-test failed: " + LastUsefulLine(test.StdErr));

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("Runtime refreshed. Starting the new WGDot runtime...");
        Console.ResetColor();
        Console.WriteLine();

        string stagedArguments =
            originalArgs == null || originalArgs.Length == 0
                ? "menu"
                : BuildCommandLine(originalArgs);

        ProcResult staged = RunInteractiveStagedRuntime(nextExe, stagedArguments);
        exitCode = staged.ExitCode;
        return true;
    }

    static string BuildCommandLine(IEnumerable<string> args)
    {
        if (args == null) return "";
        return String.Join(" ", args.Select(Q).ToArray());
    }

    static string NormalizeRuntimeSwapStatePath(string path)
    {
        if (String.IsNullOrWhiteSpace(path))
            throw new Exception("Runtime-swap worker state path is required.");

        string full = Path.GetFullPath(path);
        string temp = Path.GetFullPath(Path.GetTempPath())
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) +
            Path.DirectorySeparatorChar;
        string fileName = Path.GetFileName(full);

        if (!full.StartsWith(temp, StringComparison.OrdinalIgnoreCase) ||
            !fileName.StartsWith("wgdot-worker-state-", StringComparison.OrdinalIgnoreCase) ||
            !fileName.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
            throw new Exception("Runtime-swap worker state must stay in the Windows temporary directory.");

        return full;
    }

    static int RuntimeSwapStopFromArgs(string[] args)
    {
        string statePath = NormalizeRuntimeSwapStatePath(GetOption(args, "--state"));

        var state = new Dictionary<string, object>();
        bool idle = NamedMutexExists(IdleInhibitorMutexName);
        bool mouse = NamedMutexExists(MouseModeMutexName);
        bool superL = NamedMutexExists(SuperLTestMutexName);
        bool desktop = NamedMutexExists(DesktopWorkerMutexName);

        // State file is retained only as a staged-swap handoff marker. Legacy
        // desktop workers are stopped below and deliberately never restored.
        state["createdAt"] = DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture);
        WriteJson(statePath, state);

        IntPtr clipboardWindow = FindTopLevelWindowByExactTitle(ClipboardHistoryWindowTitle);
        if (clipboardWindow != IntPtr.Zero)
            PostMessage(clipboardWindow, WmClose, IntPtr.Zero, IntPtr.Zero);

        if (idle) SignalIdleInhibitorStop();
        if (mouse) SignalMouseModeHookStop();
        if (superL) SignalSuperLTestStop();
        if (desktop) SignalDesktopWorkerStop();

        if (idle) WaitForRuntimeWorkerState(IdleInhibitorMutexName, false, "idle inhibitor");
        if (mouse) WaitForRuntimeWorkerState(MouseModeMutexName, false, "mouse-mode");
        if (superL) WaitForRuntimeWorkerState(SuperLTestMutexName, false, "Super+L test");
        if (desktop) WaitForRuntimeWorkerState(DesktopWorkerMutexName, false, "desktop");

        return 0;
    }

    static int RuntimeSwapRestoreFromArgs(string[] args)
    {
        string statePath = NormalizeRuntimeSwapStatePath(GetOption(args, "--state"));
        // Compatibility endpoint for swap helpers created by older runtimes.
        // The management-only architecture never restarts desktop workers.
        SafeDeleteFile(statePath);
        return 0;
    }

    static void ScheduleStagedRuntimeInstall()
    {
        string currentExe = Path.GetFullPath(Process.GetCurrentProcess().MainModule.FileName);
        string fileName = Path.GetFileName(currentExe);
        Match match = Regex.Match(
            fileName ?? "",
            "^wgdot-next-([0-9a-fA-F]{40})\\.exe$",
            RegexOptions.IgnoreCase);

        if (!match.Success)
            return;

        string revision = match.Groups[1].Value.ToLowerInvariant();
        var state = ReadJson(BootstrapStatePath);
        string sourceRef = state == null ? "" : GetString(state, "sourceRef");
        if (String.IsNullOrWhiteSpace(sourceRef)) sourceRef = "main";
        ValidateBranchName(sourceRef);

        string installedExe = Path.Combine(BinRoot, "wgdot.exe");
        string workerState = Path.Combine(
            Path.GetTempPath(),
            "wgdot-worker-state-" + Guid.NewGuid().ToString("N") + ".json");
        string helper = CreateRuntimeSwapHelper(
            currentExe,
            installedExe,
            sourceRef,
            revision,
            workerState);

        var helperInfo = new ProcessStartInfo();
        helperInfo.FileName = "cmd.exe";
        helperInfo.Arguments = "/d /c " + Q(helper);
        helperInfo.UseShellExecute = false;
        helperInfo.CreateNoWindow = true;
        Process.Start(helperInfo);
    }

    static int MarkRuntimeFromArgs(string[] args)
    {
        string sourceRef = GetOption(args, "--ref");
        string revision = GetOption(args, "--revision");

        if (String.IsNullOrWhiteSpace(sourceRef))
            sourceRef = "main";
        ValidateBranchName(sourceRef);

        if (!Regex.IsMatch(revision ?? "", "^[0-9a-fA-F]{40}$"))
            throw new Exception("mark-runtime requires a full 40-character revision.");

        var state = ReadJson(BootstrapStatePath) ?? new Dictionary<string, object>();
        state["sourceRef"] = sourceRef;
        state["sourceRevision"] = revision.ToLowerInvariant();
        state["refreshedAt"] = DateTime.UtcNow.ToString("o");
        state.Remove("runtimeSyncPendingRevision");
        state.Remove("runtimeSyncScheduledAt");
        WriteJson(BootstrapStatePath, state);
        return 0;
    }

    static void CompileNativeSource(string sourcePath, string outputPath)
    {
        string csc = GetCscPath();
        if (String.IsNullOrWhiteSpace(csc))
            throw new Exception("Windows .NET Framework C# compiler was not found.");

        string args =
            "/nologo /optimize+ /target:exe /out:" + Q(outputPath) +
            " /r:System.Web.Extensions.dll" +
            " /r:System.IO.Compression.dll" +
            " /r:System.IO.Compression.FileSystem.dll" +
            " /r:System.Xml.dll " +
            Q(sourcePath);

        ProcResult compile = Run(csc, args, null);
        if (compile.ExitCode != 0)
            throw new Exception("Runtime compilation failed: " + LastUsefulLine(compile.StdErr + "\n" + compile.StdOut));
    }

    static string HiddenLauncherPath()
    {
        return Path.Combine(BinRoot, "wgdotw.exe");
    }

    static void EnsureHiddenLauncher()
    {
        string destination = HiddenLauncherPath();
        if (File.Exists(destination))
            return;

        Directory.CreateDirectory(BinRoot);
        Directory.CreateDirectory(CacheRoot);
        string sourcePath = Path.Combine(CacheRoot, "wgdotw-wrapper.cs");
        string source = @"
using System;
using System.Diagnostics;
using System.IO;

class WgdotHidden
{
    static int Main(string[] args)
    {
        string exe = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, ""wgdot.exe"");
        if (!File.Exists(exe))
            return 127;

        var psi = new ProcessStartInfo();
        psi.FileName = exe;
        psi.Arguments = String.Join("" "", args ?? new string[0]);
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;

        using (Process process = Process.Start(psi))
        {
            process.WaitForExit();
            return process.ExitCode;
        }
    }
}
";
        File.WriteAllText(sourcePath, source, new UTF8Encoding(false));

        string csc = GetCscPath();
        if (String.IsNullOrWhiteSpace(csc))
            throw new Exception("Windows .NET Framework C# compiler was not found for wgdotw.exe.");

        ProcResult compile = Run(
            csc,
            "/nologo /optimize+ /target:winexe /out:" + Q(destination) + " " + Q(sourcePath),
            null);
        if (compile.ExitCode != 0)
            throw new Exception(
                "Hidden WGDot launcher compilation failed: " +
                LastUsefulLine((compile.StdErr ?? "") + "\n" + (compile.StdOut ?? "")));
    }

    static string GetCscPath()
    {
        string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        string x64 = Path.Combine(windows, "Microsoft.NET", "Framework64", "v4.0.30319", "csc.exe");
        if (File.Exists(x64)) return x64;

        string x86 = Path.Combine(windows, "Microsoft.NET", "Framework", "v4.0.30319", "csc.exe");
        return File.Exists(x86) ? x86 : "";
    }

    static string CreateRuntimeSwapHelper(string sourceExe, string destinationExe, string sourceRef, string revision, string workerStatePath)
    {
        string helper = Path.Combine(Path.GetTempPath(), "wgdot-swap-" + Guid.NewGuid().ToString("N") + ".cmd");
        var lines = new List<string>();
        lines.Add("@echo off");
        lines.Add("setlocal EnableExtensions");
        lines.Add("set \"SRC=" + sourceExe + "\"");
        lines.Add("set \"DST=" + destinationExe + "\"");
        lines.Add("set \"STATE=" + workerStatePath + "\"");
        lines.Add("set \"WGDOT_SKIP_RUNTIME_REFRESH=1\"");
        lines.Add("\"%SRC%\" runtime-swap-stop --state \"%STATE%\" >nul 2>&1");
        lines.Add("if errorlevel 1 goto failed");
        lines.Add("set /a TRIES=0");
        lines.Add(":retry");
        lines.Add("set /a TRIES+=1");
        lines.Add("copy /Y \"%SRC%\" \"%DST%\" >nul 2>&1");
        lines.Add("if not errorlevel 1 goto copied");
        lines.Add("if %TRIES% GEQ 60 goto failed");
        lines.Add("ping 127.0.0.1 -n 2 >nul");
        lines.Add("goto retry");
        lines.Add(":copied");
        lines.Add("\"%DST%\" mark-runtime --ref " + Q(sourceRef) + " --revision " + Q(revision) + " >nul 2>&1");
        lines.Add("if errorlevel 1 goto failed");
        lines.Add("\"%DST%\" runtime-swap-restore --state \"%STATE%\" >nul 2>&1");
        lines.Add("if errorlevel 1 goto failed");
        lines.Add("del /q \"%SRC%\" >nul 2>&1");
        lines.Add("del /q \"%~f0\" >nul 2>&1");
        lines.Add("exit /b 0");
        lines.Add(":failed");
        lines.Add("if exist \"%STATE%\" \"%SRC%\" runtime-swap-restore --state \"%STATE%\" >nul 2>&1");
        lines.Add("exit /b 1");
        File.WriteAllLines(helper, lines.ToArray(), Encoding.ASCII);
        return helper;
    }

    static void ShowManualFallback()
    {
        WriteTitle("Manual PowerShell fallback");
        Console.WriteLine("WGDot never changes or bypasses execution policy.");
        Console.WriteLine();
        Console.WriteLine("Paste-only fallback documentation:");
        Console.WriteLine("https://github.com/dillacorn/win-glaze-dots/blob/main/MANUAL_POWERSHELL.md");
        Console.WriteLine();
        Console.WriteLine("Use this path on managed/work machines where native WGDot is unavailable or disallowed.");
    }

    static void ShowGitMenu()
    {
        var operations = new List<string>
        {
            "Review branch / commit without applying",
            "Update from branch / commit",
            "Reset from branch / commit",
            "Back"
        };

        while (true)
        {
            int operation = ReadSingleChoice("Advanced / Git testing", operations, 0);
            if (operation < 0 || operation == 3) return;

            try
            {
                List<string> branches = GetRemoteBranches();
                if (branches.Count == 0) throw new Exception("No remote branches were found.");

                string preferred = GetPreferredGitBranch();
                int initialBranch = branches.FindIndex(x => String.Equals(x, preferred, StringComparison.OrdinalIgnoreCase));
                if (initialBranch < 0) initialBranch = 0;

                int branchIndex = ReadSingleChoice("Select remote branch", branches, initialBranch);
                if (branchIndex < 0) continue;
                string branch = branches[branchIndex];

                int revisionMode = ReadSingleChoice(
                    "Select revision",
                    new List<string>
                    {
                        "Use selected branch head",
                        "Enter exact 40-character commit manually"
                    },
                    0);
                if (revisionMode < 0) continue;

                string requestedRevision = "";
                if (revisionMode == 1)
                {
                    WriteTitle("Exact Git-testing revision");
                    Console.Write("Exact 40-character commit: ");
                    requestedRevision = (Console.ReadLine() ?? "").Trim();
                    if (String.IsNullOrWhiteSpace(requestedRevision)) continue;
                }

                string revision = ResolveGitRevision(branch, requestedRevision);
                string sourceRoot = PrepareGitSource(revision);
                var context = new SourceContext
                {
                    Mode = "git",
                    Branch = branch,
                    Revision = revision,
                    SourceRoot = sourceRoot,
                    Manifest = ReadManifest(sourceRoot)
                };

                if (operation == 0) ManagedOperation("review", context);
                else if (operation == 1) ManagedOperation("update", context);
                else ManagedOperation("reset", context);
            }
            catch (Exception ex)
            {
                Console.WriteLine();
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("ERROR: " + ex.Message);
                Console.ResetColor();
            }

            Pause();
        }
    }

    static int GitManagedFromArgs(string operation, string[] args)
    {
        if (operation != "review" && operation != "update" && operation != "reset")
            throw new Exception("Unsupported Git-testing operation '" + operation + "'.");

        string branch = GetOption(args, "--branch");
        string revision = GetOption(args, "--revision");

        if (String.IsNullOrWhiteSpace(branch))
            throw new Exception("git-" + operation + " requires --branch <remote-branch>.");

        string resolved = ResolveGitRevision(branch, revision);
        string sourceRoot = PrepareGitSource(resolved);
        var context = new SourceContext
        {
            Mode = "git",
            Branch = branch,
            Revision = resolved,
            SourceRoot = sourceRoot,
            Manifest = ReadManifest(sourceRoot)
        };
        return ManagedOperation(operation, context);
    }


    static bool ManagedPlanWritesThemeState(List<PlanItem> plan)
    {
        if (plan == null) return false;

        return plan.Any(item =>
            item != null &&
            (String.Equals(item.FileId, "yasb-theme", StringComparison.OrdinalIgnoreCase) ||
             String.Equals(item.FileId, "terminal-settings", StringComparison.OrdinalIgnoreCase)) &&
            (String.Equals(item.Action, "APPLY", StringComparison.OrdinalIgnoreCase) ||
             String.Equals(item.Action, "REPLACE", StringComparison.OrdinalIgnoreCase) ||
             String.Equals(item.Action, "MERGE", StringComparison.OrdinalIgnoreCase)));
    }

    static void RestoreRememberedThemeAfterManagedApply(List<PlanItem> plan)
    {
        if (!ManagedPlanWritesThemeState(plan))
            return;

        string rememberedTheme = CurrentYasbThemeId();
        int result = ApplyYasbTheme(rememberedTheme);
        if (result != 0)
            throw new Exception("Managed dots were applied, but the selected WGDot theme could not be restored.");

        Console.WriteLine("Preserved selected WGDot theme: " + rememberedTheme);
    }

    static int DotsOnlyFromArgs(string[] args)
    {
        string profile = GetOption(args ?? new string[0], "--profile");
        profile = (profile ?? "").Trim().ToLowerInvariant();
        if (profile != "normal" && profile != "work")
            throw new Exception("dots-only requires --profile normal or --profile work.");

        bool apply = (args ?? new string[0]).Any(
            x => String.Equals(x, "--yes", StringComparison.OrdinalIgnoreCase));

        SourceContext source = ResolveDefaultSource();
        InstallationSelection existing = ReadInstallationSelection();
        InstallationSelection selection = BuildDotsOnlySelection(source.Manifest, profile, existing);
        List<PlanItem> plan = GetPlan(source.Manifest, source.SourceRoot, selection, "reset");

        WriteTitle("Dots-only managed configuration");
        Console.WriteLine("Profile: " + (profile == "work" ? "Work PC" : "Normal / personal PC"));
        Console.WriteLine("GlazeWM profile: " + selection.GlazeProfile);
        Console.WriteLine("Software operations: disabled");
        Console.WriteLine("Package, tweak, and browser selection state: " +
            (existing == null ? "left empty" : "preserved"));
        Console.WriteLine();
        ShowPlan(plan);

        if (!apply)
        {
            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.DarkGray;
            Console.WriteLine("Review only. No managed files, backups, baselines, or selection state were changed.");
            Console.ResetColor();
            return 0;
        }

        ApplyPlan(plan, source.Manifest, selection, source, true);
        RestoreRememberedThemeAfterManagedApply(plan);
        WriteInstallationSelection(selection);
        UpdateSourceStateAfterApply(source);

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("WGDot managed dots applied. Software was not installed, upgraded, reconciled, or uninstalled.");
        Console.ResetColor();
        return 0;
    }

    static InstallationSelection BuildDotsOnlySelection(
        Dictionary<string, object> manifest,
        string profile,
        InstallationSelection existing)
    {
        var result = new InstallationSelection();
        result.Scope = profile;
        result.GlazeProfile = profile;

        string defaultKey = profile == "work" ? "defaultWork" : "defaultNormal";
        foreach (object rawComponent in GetList(manifest, "components"))
        {
            Dictionary<string, object> component = AsDictionary(rawComponent);
            if (!GetBool(component, defaultKey))
                continue;

            // Strict dots-only means file-backed managed configuration. Components
            // that exist only to apply registry/system post-actions (for example
            // cursor themes) are deliberately excluded.
            if (GetList(component, "files").Count == 0)
                continue;

            string id = GetString(component, "id");
            if (!String.IsNullOrWhiteSpace(id))
                result.Components.Add(id);
        }

        if (existing != null)
        {
            result.Packages = new List<string>(existing.Packages);
            result.Tweaks = new List<string>(existing.Tweaks);
            result.TweaksConfigured = existing.TweaksConfigured;
            result.BrowserOptionsConfigured = existing.BrowserOptionsConfigured;
            result.BrowserOptions = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
            foreach (KeyValuePair<string, List<string>> pair in existing.BrowserOptions)
                result.BrowserOptions[pair.Key] = new List<string>(pair.Value);
        }

        return result;
    }

    static SourceContext ResolveDefaultSource()
    {
        var bootstrap = ReadJson(BootstrapStatePath);
        if (bootstrap != null)
        {
            string sourceRef = GetString(bootstrap, "sourceRef");
            bool explicitRefTesting = GetBool(bootstrap, "sourceExplicit");
            bool useRuntimeRef =
                !String.IsNullOrWhiteSpace(sourceRef) &&
                (explicitRefTesting ||
                 !String.Equals(sourceRef, "main", StringComparison.OrdinalIgnoreCase));

            if (useRuntimeRef)
            {
                string recordedRevision = GetString(bootstrap, "sourceRevision");
                string revision =
                    explicitRefTesting &&
                    Regex.IsMatch(recordedRevision ?? "", "^[0-9a-fA-F]{40}$")
                        ? recordedRevision.ToLowerInvariant()
                        : ResolveBranchHeadViaApi(sourceRef);

                string sourceRoot = PrepareRevisionArchive(revision);
                return new SourceContext
                {
                    Mode = "git",
                    Branch = sourceRef,
                    Revision = revision,
                    SourceRoot = sourceRoot,
                    Manifest = ReadManifest(sourceRoot)
                };
            }
        }

        return ResolveStableSource();
    }

    static SourceContext ResolveStableSource()
    {
        var release = GetStableRelease();
        string revision = GetString(release, "revision");
        string sourceRoot = PrepareRevisionArchive(revision);
        var manifest = ReadManifest(sourceRoot);

        return new SourceContext
        {
            Mode = "stable",
            Tag = GetString(release, "tag"),
            Revision = revision,
            SourceRoot = sourceRoot,
            Manifest = manifest
        };
    }

    static Dictionary<string, object> GetStableRelease()
    {
        var release = GetJsonUrl(ApiBase + "/releases/latest");
        if (GetBool(release, "draft") || GetBool(release, "prerelease"))
            throw new Exception("Latest release is not a normal published stable release.");

        string tag = GetString(release, "tag_name");
        if (!Regex.IsMatch(tag, StableTagPattern))
            throw new Exception("Latest published release '" + tag + "' is not a WGDot semantic stable tag.");

        var tagRef = GetJsonUrl(ApiBase + "/git/ref/tags/" + tag);
        var gitObject = GetDictionary(tagRef, "object");
        string revision = ResolveGitObjectToCommit(gitObject);

        var result = new Dictionary<string, object>();
        result["tag"] = tag;
        result["revision"] = revision;
        result["publishedAt"] = GetString(release, "published_at");
        return result;
    }

    static string ResolveGitObjectToCommit(Dictionary<string, object> gitObject)
    {
        Dictionary<string, object> current = gitObject;
        int guard = 0;

        while (String.Equals(GetString(current, "type"), "tag", StringComparison.OrdinalIgnoreCase))
        {
            guard++;
            if (guard > 8) throw new Exception("Tag resolution exceeded safety limit.");

            string sha = GetString(current, "sha");
            var tag = GetJsonUrl(ApiBase + "/git/tags/" + sha);
            current = GetDictionary(tag, "object");
        }

        if (!String.Equals(GetString(current, "type"), "commit", StringComparison.OrdinalIgnoreCase))
            throw new Exception("Git tag did not resolve to a commit.");

        string commit = GetString(current, "sha");
        if (!Regex.IsMatch(commit, "^[0-9a-fA-F]{40}$"))
            throw new Exception("Resolved release commit is not a full SHA.");

        return commit.ToLowerInvariant();
    }

    static string ResolveBranchHeadViaApi(string branch)
    {
        ValidateBranchName(branch);
        var reference = GetJsonUrl(ApiBase + "/git/ref/heads/" + branch);
        var obj = GetDictionary(reference, "object");
        string sha = GetString(obj, "sha");
        if (!Regex.IsMatch(sha, "^[0-9a-fA-F]{40}$"))
            throw new Exception("Could not resolve branch '" + branch + "' to a full commit SHA.");
        return sha.ToLowerInvariant();
    }

    static Dictionary<string, object> GetJsonUrl(string url)
    {
        using (var client = new WebClient())
        {
            client.Headers[HttpRequestHeader.UserAgent] = "wgdot";
            client.Headers[HttpRequestHeader.Accept] = "application/vnd.github+json";

            // GitHub-hosted CI shares public egress and can exhaust GitHub's
            // anonymous API quota. Normal installs remain tokenless, but an
            // explicitly supplied token is honored when present.
            string githubToken = Environment.GetEnvironmentVariable("GITHUB_TOKEN");
            if (!String.IsNullOrWhiteSpace(githubToken))
                client.Headers[HttpRequestHeader.Authorization] = "Bearer " + githubToken.Trim();

            string raw = client.DownloadString(url);
            return AsDictionary(Json.DeserializeObject(raw));
        }
    }

    static string RawRepositoryUrl(string revision, string relativePath)
    {
        string normalized = (relativePath ?? "").Replace('\\', '/').Trim('/');
        if (String.IsNullOrWhiteSpace(normalized))
            throw new Exception("Raw repository path is empty.");

        string[] segments = normalized.Split('/');
        if (segments.Any(
                segment =>
                    String.IsNullOrWhiteSpace(segment) ||
                    segment == "." ||
                    segment == ".."))
            throw new Exception("Unsafe raw repository path: " + relativePath);

        string encoded = String.Join(
            "/",
            segments.Select(segment => Uri.EscapeDataString(segment)).ToArray());

        return "https://raw.githubusercontent.com/" +
            RepoFullName + "/" + revision + "/" + encoded;
    }

    static string SafeRawSourceDestination(string root, string relativePath)
    {
        string normalized = (relativePath ?? "").Replace('\\', '/').Trim('/');
        if (String.IsNullOrWhiteSpace(normalized))
            throw new Exception("Managed source path is empty.");

        string fullRoot = Path.GetFullPath(root)
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) +
            Path.DirectorySeparatorChar;
        string destination = Path.GetFullPath(
            Path.Combine(
                root,
                normalized.Replace('/', Path.DirectorySeparatorChar)));

        if (!destination.StartsWith(fullRoot, StringComparison.OrdinalIgnoreCase))
            throw new Exception("Managed source escaped the raw revision cache: " + relativePath);

        return destination;
    }

    static void DownloadRawRevisionFile(
        WebClient client,
        string revision,
        string relativePath,
        string root)
    {
        string destination = SafeRawSourceDestination(root, relativePath);
        string parent = Path.GetDirectoryName(destination);
        if (!String.IsNullOrWhiteSpace(parent))
            Directory.CreateDirectory(parent);

        client.DownloadFile(
            RawRepositoryUrl(revision, relativePath),
            destination);
    }

    static string PrepareRawRevisionSource(string revision)
    {
        string rawRoot = Path.Combine(CacheRoot, "raw-revision-" + revision);
        string marker = Path.Combine(rawRoot, ".wgdot-raw-source");
        string manifestPath = Path.Combine(rawRoot, "wgdot", "manifest.json");

        if (File.Exists(marker) && File.Exists(manifestPath))
            return rawRoot;

        SafeDeleteDirectory(rawRoot);
        Directory.CreateDirectory(rawRoot);

        try
        {
            using (var client = new WebClient())
            {
                client.Headers[HttpRequestHeader.UserAgent] = "wgdot";
                DownloadRawRevisionFile(
                    client,
                    revision,
                    "wgdot/manifest.json",
                    rawRoot);

                Dictionary<string, object> manifest = ReadManifest(rawRoot);
                var sources = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

                foreach (object rawComponent in GetList(manifest, "components"))
                {
                    Dictionary<string, object> component = AsDictionary(rawComponent);
                    foreach (object rawFile in GetList(component, "files"))
                    {
                        Dictionary<string, object> file = AsDictionary(rawFile);
                        string source = GetString(file, "source");
                        if (!String.IsNullOrWhiteSpace(source))
                            sources.Add(source);

                        object byProfileRaw;
                        if (file.TryGetValue("sourceByGlazeProfile", out byProfileRaw) &&
                            byProfileRaw != null)
                        {
                            Dictionary<string, object> byProfile = AsDictionary(byProfileRaw);
                            foreach (object value in byProfile.Values)
                            {
                                string profileSource = Convert.ToString(
                                    value,
                                    CultureInfo.InvariantCulture);
                                if (!String.IsNullOrWhiteSpace(profileSource))
                                    sources.Add(profileSource);
                            }
                        }
                    }
                }

                foreach (string source in sources.OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
                    DownloadRawRevisionFile(client, revision, source, rawRoot);
            }

            File.WriteAllText(
                marker,
                revision + Environment.NewLine,
                Encoding.ASCII);
            return rawRoot;
        }
        catch
        {
            SafeDeleteDirectory(rawRoot);
            throw;
        }
    }

    static int SourceSelfTestFromArgs(string[] args)
    {
        string revision = GetOption(args, "--revision");
        if (!Regex.IsMatch(revision ?? "", "^[0-9a-fA-F]{40}$"))
            throw new Exception("source-self-test requires --revision <full 40-character SHA>.");

        string sourceRoot = PrepareRevisionArchive(revision.ToLowerInvariant());
        Dictionary<string, object> manifest = ReadManifest(sourceRoot);

        int componentCount = GetList(manifest, "components").Count;
        if (componentCount == 0)
            throw new Exception("Source self-test resolved a manifest with no components.");

        Console.WriteLine("WGDot source self-test passed.");
        Console.WriteLine("Revision: " + revision.ToLowerInvariant());
        Console.WriteLine("Source:   " + sourceRoot);
        Console.WriteLine("Components: " + componentCount.ToString(CultureInfo.InvariantCulture));
        return 0;
    }

    static string PrepareRevisionArchive(string revision)
    {
        if (!Regex.IsMatch(revision ?? "", "^[0-9a-fA-F]{40}$"))
            throw new Exception("Source revision must be a full 40-character SHA.");

        revision = revision.ToLowerInvariant();

        if (String.Equals(
                Environment.GetEnvironmentVariable("WGDOT_FORCE_RAW_SOURCE"),
                "1",
                StringComparison.Ordinal))
            return PrepareRawRevisionSource(revision);

        string revisionRoot = Path.Combine(CacheRoot, "revision-" + revision);
        string marker = Path.Combine(revisionRoot, ".wgdot-source");

        if (File.Exists(marker))
        {
            string cached = File.ReadAllText(marker).Trim();
            if (Directory.Exists(cached) &&
                File.Exists(Path.Combine(cached, "wgdot", "manifest.json")))
                return cached;
        }

        string zipPath = Path.Combine(CacheRoot, revision + ".zip");
        string extractRoot = Path.Combine(CacheRoot, "extract-" + revision);

        SafeDeleteFile(zipPath);
        SafeDeleteDirectory(extractRoot);
        SafeDeleteDirectory(revisionRoot);
        Directory.CreateDirectory(extractRoot);

        Exception archiveFailure = null;
        try
        {
            string url =
                "https://github.com/" + RepoFullName + "/archive/" + revision + ".zip";
            using (var client = new WebClient())
            {
                client.Headers[HttpRequestHeader.UserAgent] = "wgdot";
                client.DownloadFile(url, zipPath);
            }

            ZipFile.ExtractToDirectory(zipPath, extractRoot);
            string[] children = Directory.GetDirectories(extractRoot);
            if (children.Length != 1)
                throw new Exception("Unexpected GitHub archive layout.");

            string source = children[0];
            if (!File.Exists(Path.Combine(source, "wgdot", "manifest.json")))
                throw new Exception("Revision " + revision + " is not WGDot-compatible.");

            Directory.CreateDirectory(revisionRoot);
            File.WriteAllText(marker, source, Encoding.ASCII);
            SafeDeleteFile(zipPath);
            return source;
        }
        catch (Exception ex)
        {
            archiveFailure = ex;
            SafeDeleteFile(zipPath);
            SafeDeleteDirectory(extractRoot);
            SafeDeleteDirectory(revisionRoot);
        }

        try
        {
            return PrepareRawRevisionSource(revision);
        }
        catch (Exception rawFailure)
        {
            throw new Exception(
                "Could not acquire WGDot revision " + revision +
                " from either the GitHub archive endpoint or raw.githubusercontent.com. " +
                "Archive error: " + archiveFailure.Message +
                " Raw error: " + rawFailure.Message);
        }
    }

    static Dictionary<string, object> ReadManifest(string sourceRoot)
    {
        string path = Path.Combine(sourceRoot, "wgdot", "manifest.json");
        if (!File.Exists(path))
            throw new Exception("WGDot manifest not found in source: " + path);

        var manifest = ReadJson(path);
        if (manifest == null || GetInt(manifest, "schemaVersion") != 1)
            throw new Exception("Unsupported or invalid WGDot manifest.");

        return manifest;
    }

    static int MaintenanceSelfTest()
    {
        if (String.IsNullOrWhiteSpace(TestRootOverride))
            throw new Exception("maintenance-self-test requires WGDOT_TEST_ROOT.");

        string root = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "wgdot-native-maintenance-selftest-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);

        try
        {
            string sourceRoot = Path.Combine(root, "source");
            string liveRoot = Path.Combine(root, "live");
            Directory.CreateDirectory(sourceRoot);
            Directory.CreateDirectory(liveRoot);

            string target = Path.Combine(sourceRoot, "target.txt");
            string live = Path.Combine(liveRoot, "target.txt");
            File.WriteAllText(target, "release-two", new UTF8Encoding(false));
            File.WriteAllText(live, "release-one", new UTF8Encoding(false));

            var file = new Dictionary<string, object>();
            file["id"] = "selftest-file";
            file["source"] = "target.txt";
            file["destination"] = live;
            file["merge"] = true;

            var component = new Dictionary<string, object>();
            component["id"] = "selftest";
            component["name"] = "Self Test";
            component["files"] = new object[] { file };
            component["postActions"] = new object[0];

            var manifest = new Dictionary<string, object>();
            manifest["schemaVersion"] = 1;
            manifest["components"] = new object[] { component };
            manifest["migrations"] = new object[0];
            manifest["packages"] = new object[0];

            var selection = new InstallationSelection();
            selection.Scope = "normal";
            selection.GlazeProfile = "normal";
            selection.Components.Add("selftest");

            List<PlanItem> resetPlan = GetPlan(manifest, sourceRoot, selection, "reset");
            if (resetPlan.Count != 1 || resetPlan[0].Status != "RESET" || resetPlan[0].Action != "REPLACE")
                throw new Exception("Reset planner self-test failed.");

            var context = new SourceContext
            {
                Mode = "git",
                Branch = "selftest",
                Revision = new string('a', 40),
                SourceRoot = sourceRoot,
                Manifest = manifest
            };

            ApplyPlan(resetPlan, manifest, selection, context);

            if (File.ReadAllText(live) != "release-two")
                throw new Exception("Apply self-test did not replace the live file.");

            string adjacentBackup = live + ".wgdot.backup";
            if (!File.Exists(adjacentBackup) || File.ReadAllText(adjacentBackup) != "release-one")
                throw new Exception("Adjacent backup self-test failed.");

            string baseline = GetBaselinePath("selftest-file");
            if (!File.Exists(baseline) || File.ReadAllText(baseline) != "release-two")
                throw new Exception("Baseline self-test failed.");

            string mergeTarget = Path.Combine(sourceRoot, "merge.txt");
            string mergeLive = Path.Combine(liveRoot, "merge.txt");
            File.WriteAllText(mergeTarget, "upstream-one\r\ntwo\r\nthree\r\nfour\r\nfive\r\n", new UTF8Encoding(false));
            File.WriteAllText(mergeLive, "one\r\ntwo\r\nthree\r\nfour\r\nlocal-five\r\n", new UTF8Encoding(false));
            string mergeBaseline = GetBaselinePath("selftest-merge");
            File.WriteAllText(mergeBaseline, "one\r\ntwo\r\nthree\r\nfour\r\nfive\r\n", new UTF8Encoding(false));

            var mergeFile = new Dictionary<string, object>();
            mergeFile["id"] = "selftest-merge";
            mergeFile["source"] = "merge.txt";
            mergeFile["destination"] = mergeLive;
            mergeFile["merge"] = true;

            component["files"] = new object[] { mergeFile };
            List<PlanItem> mergePlan = GetPlan(manifest, sourceRoot, selection, "update");
            PlanItem mergeItem = mergePlan.FirstOrDefault(x => x.FileId == "selftest-merge");
            PlanItem removedItem = mergePlan.FirstOrDefault(x => x.FileId == "selftest-file");
            if (mergeItem == null || mergeItem.Status != "BOTH" || mergeItem.Action != "MERGE")
                throw new Exception("Three-way merge planner self-test failed.");
            if (removedItem == null || removedItem.Status != "REMOVED-UPSTREAM" || removedItem.Action != "PRESERVE")
                throw new Exception("Removed-upstream preservation self-test failed.");

            ApplyPlan(mergePlan, manifest, selection, context);
            string merged = File.ReadAllText(mergeLive);
            if (merged.IndexOf("upstream-one", StringComparison.Ordinal) < 0 ||
                merged.IndexOf("local-five", StringComparison.Ordinal) < 0)
                throw new Exception("Three-way merge application self-test failed.");

            string legacy = Path.Combine(root, "clipboard.yazi");
            Directory.CreateDirectory(Path.Combine(legacy, ".git"));
            File.WriteAllText(
                Path.Combine(legacy, ".git", "config"),
                "[remote \"origin\"]\r\nurl = https://github.com/XYenon/clipboard.yazi.git\r\n",
                new UTF8Encoding(false));

            var migration = new Dictionary<string, object>();
            migration["id"] = "selftest-yazi-legacy";
            migration["component"] = "selftest";
            migration["path"] = legacy;
            migration["type"] = "git-remote-directory";
            migration["expectedRemoteFragment"] = "XYenon/clipboard.yazi";
            manifest["migrations"] = new object[] { migration };
            component["files"] = new object[0];

            ShowMigrations(manifest, selection, false);

            if (Directory.Exists(legacy))
                throw new Exception("Guarded migration self-test did not remove the known legacy directory.");

            string migrationBackup = legacy + ".wgdot.backup";
            if (!Directory.Exists(migrationBackup))
                throw new Exception("Guarded migration self-test did not create an adjacent directory backup.");

            var backupState = ReadJson(BackupStatePath);
            if (backupState == null || GetList(backupState, "records").Count < 3)
                throw new Exception("Backup record self-test failed.");

            string registrySelfTestPath =
                @"Software\WGDot\SelfTest\" + Guid.NewGuid().ToString("N");
            try
            {
                using (RegistryKey key = Registry.CurrentUser.CreateSubKey(registrySelfTestPath))
                {
                    if (key == null) throw new Exception("Registry self-test key could not be created.");
                    key.SetValue("Text", "before", RegistryValueKind.String);
                    key.SetValue("Blob", new byte[] { 1, 2, 3 }, RegistryValueKind.Binary);
                }

                SetRegistryValueWithSnapshot(
                    "selftest-registry", "HKCU", registrySelfTestPath,
                    "Text", "after", RegistryValueKind.String);
                SetRegistryValueWithSnapshot(
                    "selftest-registry", "HKCU", registrySelfTestPath,
                    "Blob", new byte[] { 9 }, RegistryValueKind.Binary);
                SetRegistryValueWithSnapshot(
                    "selftest-registry", "HKCU", registrySelfTestPath,
                    "Transient", new byte[0], RegistryValueKind.None);

                RestoreRegistryOriginals("selftest-registry");

                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(registrySelfTestPath, false))
                {
                    if (key == null ||
                        !String.Equals(Convert.ToString(key.GetValue("Text")), "before", StringComparison.Ordinal))
                        throw new Exception("Registry string rollback self-test failed.");

                    byte[] blob = key.GetValue("Blob") as byte[];
                    if (blob == null || !blob.SequenceEqual(new byte[] { 1, 2, 3 }))
                        throw new Exception("Registry binary rollback self-test failed.");

                    if (key.GetValue("Transient", null) != null)
                        throw new Exception("Registry missing-value rollback self-test failed.");
                }

                string transientKey = registrySelfTestPath + @"\TransientKey";
                SetRegistryValueWithSnapshot(
                    "selftest-registry-key", "HKCU", transientKey,
                    "", "owned", RegistryValueKind.String);
                RestoreRegistryOriginals("selftest-registry-key");
                DeleteRegistryKeyIfOriginallyAbsentAndEmpty(
                    "selftest-registry-key", "HKCU", transientKey, "");

                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(transientKey, false))
                {
                    if (key != null)
                        throw new Exception("Registry created-key cleanup self-test failed.");
                }
            }
            finally
            {
                try { Registry.CurrentUser.DeleteSubKeyTree(registrySelfTestPath, false); } catch { }
            }

            if (!IsBrowserOptionsKey(ConsoleKey.E) ||
                !IsBackKey(ConsoleKey.Q) ||
                !IsBackKey(ConsoleKey.Escape))
                throw new Exception("Browser keyboard navigation self-test failed.");

            var firefoxBrowser = new Dictionary<string, object>();
            firefoxBrowser["packageId"] = "Mozilla.Firefox";
            firefoxBrowser["name"] = "Firefox";
            firefoxBrowser["mode"] = "firefox-managed";
            firefoxBrowser["options"] = new object[]
            {
                new Dictionary<string, object>
                {
                    { "id", "betterfox" },
                    { "name", "Betterfox" },
                    { "defaultNormal", true },
                    { "defaultWork", true }
                },
                new Dictionary<string, object>
                {
                    { "id", "dark-reader" },
                    { "name", "Dark Reader" },
                    { "defaultNormal", false },
                    { "defaultWork", false }
                }
            };

            var mullvadBrowser = new Dictionary<string, object>();
            mullvadBrowser["packageId"] = "MullvadVPN.MullvadBrowser";
            mullvadBrowser["name"] = "Mullvad Browser";
            mullvadBrowser["mode"] = "preserve-upstream";
            mullvadBrowser["options"] = new object[0];

            var browserManifest = new Dictionary<string, object>();
            browserManifest["browserOptions"] = new object[]
            {
                firefoxBrowser,
                mullvadBrowser
            };

            Dictionary<string, List<string>> browserDefaults =
                BuildBrowserOptionSelection(browserManifest, "normal", null);
            if (!browserDefaults.ContainsKey("Mozilla.Firefox") ||
                browserDefaults["Mozilla.Firefox"].Count != 1 ||
                !browserDefaults["Mozilla.Firefox"].Contains("betterfox") ||
                !browserDefaults.ContainsKey("MullvadVPN.MullvadBrowser") ||
                browserDefaults["MullvadVPN.MullvadBrowser"].Count != 0)
                throw new Exception("Browser manifest/default self-test failed.");

            var browserSelection = new InstallationSelection();
            browserSelection.Scope = "normal";
            browserSelection.GlazeProfile = "normal";
            browserSelection.Components.Add("selftest");
            browserSelection.Packages.Add("Mozilla.Firefox");
            browserSelection.BrowserOptions = browserDefaults;
            browserSelection.BrowserOptionsConfigured = true;
            WriteInstallationSelection(browserSelection);

            InstallationSelection browserRoundTrip = ReadInstallationSelection();
            if (browserRoundTrip == null ||
                !browserRoundTrip.BrowserOptionsConfigured ||
                !browserRoundTrip.BrowserOptions.ContainsKey("Mozilla.Firefox") ||
                !browserRoundTrip.BrowserOptions["Mozilla.Firefox"].Contains("betterfox") ||
                !browserRoundTrip.BrowserOptions.ContainsKey("MullvadVPN.MullvadBrowser") ||
                browserRoundTrip.BrowserOptions["MullvadVPN.MullvadBrowser"].Count != 0)
                throw new Exception("Browser selection persistence self-test failed.");

            List<string> nextOwned;
            List<string> mergedInstallUrls = MergeManagedFirefoxInstallUrls(
                new[]
                {
                    "https://example.invalid/external.xpi",
                    "https://addons.mozilla.org/old-wgdot.xpi"
                },
                new[] { "https://addons.mozilla.org/old-wgdot.xpi" },
                new[]
                {
                    "https://example.invalid/external.xpi",
                    "https://addons.mozilla.org/new-wgdot.xpi"
                },
                out nextOwned);
            if (mergedInstallUrls.Count != 2 ||
                !mergedInstallUrls.Contains("https://example.invalid/external.xpi") ||
                !mergedInstallUrls.Contains("https://addons.mozilla.org/new-wgdot.xpi") ||
                mergedInstallUrls.Contains("https://addons.mozilla.org/old-wgdot.xpi") ||
                nextOwned.Count != 1 ||
                !nextOwned.Contains("https://addons.mozilla.org/new-wgdot.xpi"))
                throw new Exception("Firefox managed extension policy merge self-test failed.");

            string firefoxTestRoot = Path.Combine(root, "firefox-profile-selftest");
            Directory.CreateDirectory(
                Path.Combine(firefoxTestRoot, "Profiles", "existing.default"));
            File.WriteAllText(
                Path.Combine(firefoxTestRoot, "profiles.ini"),
                "[General]\r\nStartWithLastProfile=1\r\nVersion=2\r\n\r\n" +
                "[Profile0]\r\nName=Existing\r\nIsRelative=1\r\n" +
                "Path=Profiles/existing.default\r\nDefault=1\r\n\r\n" +
                "[InstallABC]\r\nDefault=Profiles/existing.default\r\nLocked=1\r\n",
                new UTF8Encoding(false));
            File.WriteAllText(
                Path.Combine(firefoxTestRoot, "installs.ini"),
                "[ABC]\r\nDefault=Profiles/existing.default\r\nLocked=1\r\n",
                new UTF8Encoding(false));

            string beforeDefault = GetFirefoxDefaultProfilePath(firefoxTestRoot);
            if (!String.Equals(
                beforeDefault,
                "Profiles/existing.default",
                StringComparison.OrdinalIgnoreCase))
                throw new Exception("Firefox default-profile discovery self-test failed.");

            string wgdotProfile = EnsureWgdotFirefoxProfile(firefoxTestRoot);
            if (!Directory.Exists(Path.Combine(
                firefoxTestRoot,
                wgdotProfile.Replace('/', Path.DirectorySeparatorChar))))
                throw new Exception("WGDot Firefox profile creation self-test failed.");

            if (!File.Exists(
                Path.Combine(firefoxTestRoot, "profiles.ini") + ".wgdot.backup"))
                throw new Exception("Firefox profile metadata backup self-test failed.");

            SetFirefoxDefaultProfile(
                firefoxTestRoot,
                wgdotProfile,
                beforeDefault);
            if (!String.Equals(
                GetFirefoxDefaultProfilePath(firefoxTestRoot),
                wgdotProfile,
                StringComparison.OrdinalIgnoreCase))
                throw new Exception("Firefox default-profile set self-test failed.");

            RestoreFirefoxDefaultProfile(
                firefoxTestRoot,
                beforeDefault,
                wgdotProfile);
            if (!String.Equals(
                GetFirefoxDefaultProfilePath(firefoxTestRoot),
                beforeDefault,
                StringComparison.OrdinalIgnoreCase))
                throw new Exception("Firefox default-profile rollback self-test failed.");

            Console.WriteLine("WGDot native maintenance self-test passed.");
            return 0;
        }
        finally
        {
            SafeDeleteDirectory(root);
            SafeDeleteDirectory(InstallRoot);
        }
    }

    static bool ResolveGitHubReleasePackageAsset(
        Dictionary<string, object> package,
        out string assetName,
        out string assetUrl)
    {
        string repo = GetString(package, "fallbackGitHubRepo");
        string assetPattern = GetString(package, "fallbackAssetRegex");
        string name = GetString(package, "name");

        assetName = "";
        assetUrl = "";

        if (!Regex.IsMatch(repo ?? "", "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"))
            throw new Exception("Invalid fallback GitHub repository for " + name + ".");
        if (String.IsNullOrWhiteSpace(assetPattern))
            throw new Exception("Missing fallback GitHub asset pattern for " + name + ".");

        Regex assetRegex;
        try
        {
            assetRegex = new Regex(assetPattern, RegexOptions.IgnoreCase);
        }
        catch (ArgumentException ex)
        {
            throw new Exception("Invalid fallback asset regex for " + name + ": " + ex.Message);
        }

        var release = GetJsonUrl("https://api.github.com/repos/" + repo + "/releases/latest");
        foreach (object rawAsset in GetList(release, "assets"))
        {
            var asset = AsDictionary(rawAsset);
            string candidate = GetString(asset, "name");
            if (!assetRegex.IsMatch(candidate ?? ""))
                continue;

            string candidateUrl = GetString(asset, "browser_download_url");
            if (String.IsNullOrWhiteSpace(candidateUrl) ||
                !candidateUrl.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
                continue;

            assetName = candidate;
            assetUrl = candidateUrl;
            return true;
        }

        return false;
    }

    static bool IsWindowsExecutableFile(string path)
    {
        if (String.IsNullOrWhiteSpace(path) || !File.Exists(path))
            return false;

        try
        {
            using (FileStream stream = File.OpenRead(path))
            {
                if (stream.Length < 2) return false;
                return stream.ReadByte() == 0x4D && stream.ReadByte() == 0x5A;
            }
        }
        catch
        {
            return false;
        }
    }

    static string DownloadOfficialGitHubPackageAsset(
        Dictionary<string, object> package,
        out string assetName)
    {
        string name = GetString(package, "name");
        string assetUrl;

        if (!ResolveGitHubReleasePackageAsset(package, out assetName, out assetUrl))
            throw new Exception("No matching upstream release asset found for " + name + ".");

        string packageCache = Path.Combine(CacheRoot, "package-fallback");
        Directory.CreateDirectory(packageCache);
        string path = Path.Combine(packageCache, assetName);
        SafeDeleteFile(path);

        using (var client = new WebClient())
        {
            client.Headers[HttpRequestHeader.UserAgent] = "wgdot";
            client.DownloadFile(assetUrl, path);
        }

        if (!File.Exists(path) || new FileInfo(path).Length == 0)
            throw new Exception("Downloaded upstream release asset is empty or missing for " + name + ".");

        if (assetName.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) &&
            !IsWindowsExecutableFile(path))
        {
            SafeDeleteFile(path);
            throw new Exception("Downloaded upstream release asset is not a valid Windows executable for " + name + ".");
        }

        return path;
    }

    static string GetPackageProgramDirectory(Dictionary<string, object> package)
    {
        string leaf = GetString(package, "installDirectory");
        if (String.IsNullOrWhiteSpace(leaf) ||
            !String.Equals(Path.GetFileName(leaf), leaf, StringComparison.Ordinal) ||
            leaf == "." ||
            leaf == "..")
            throw new Exception("Invalid package install directory for " + GetString(package, "name") + ".");

        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Programs",
            leaf);
    }

    static string GetPackageProgramFilePath(
        Dictionary<string, object> package,
        string fieldName)
    {
        string fileName = GetString(package, fieldName);
        if (String.IsNullOrWhiteSpace(fileName) ||
            !String.Equals(Path.GetFileName(fileName), fileName, StringComparison.Ordinal))
            throw new Exception("Invalid " + fieldName + " for " + GetString(package, "name") + ".");

        return Path.Combine(GetPackageProgramDirectory(package), fileName);
    }

    static bool IsInstalledService(string serviceName)
    {
        if (String.IsNullOrWhiteSpace(serviceName)) return false;

        try
        {
            using (RegistryKey key = Registry.LocalMachine.OpenSubKey(
                @"SYSTEM\CurrentControlSet\Services\" + serviceName,
                false))
            {
                return key != null;
            }
        }
        catch
        {
            return false;
        }
    }

    static bool IsOfficialGitHubPortablePackageInstalled(Dictionary<string, object> package)
    {
        return File.Exists(GetPackageProgramFilePath(package, "installedFile"));
    }

    static string GetUserFontFilePath(Dictionary<string, object> package)
    {
        string fileName = GetString(package, "fontFile");
        if (String.IsNullOrWhiteSpace(fileName) ||
            !String.Equals(Path.GetFileName(fileName), fileName, StringComparison.Ordinal) ||
            !fileName.EndsWith(".ttf", StringComparison.OrdinalIgnoreCase))
            throw new Exception("Invalid fontFile for " + GetString(package, "name") + ".");

        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Microsoft",
            "Windows",
            "Fonts",
            fileName);
    }

    static string GetUserFontRegistryValueName(Dictionary<string, object> package)
    {
        string family = GetString(package, "fontFamily");
        if (String.IsNullOrWhiteSpace(family) ||
            family.IndexOf('\0') >= 0 ||
            family.IndexOf('\\') >= 0 ||
            family.IndexOf('/') >= 0)
            throw new Exception("Invalid fontFamily for " + GetString(package, "name") + ".");

        return family + " (TrueType)";
    }

    static bool IsOfficialGitHubFontArchivePackageInstalled(Dictionary<string, object> package)
    {
        string path = GetUserFontFilePath(package);
        if (!File.Exists(path))
            return false;

        using (RegistryKey key = Registry.CurrentUser.OpenSubKey(
            @"Software\Microsoft\Windows NT\CurrentVersion\Fonts",
            false))
        {
            if (key == null) return false;
            string value = Convert.ToString(
                key.GetValue(
                    GetUserFontRegistryValueName(package),
                    null,
                    RegistryValueOptions.DoNotExpandEnvironmentNames));
            return String.Equals(value, path, StringComparison.OrdinalIgnoreCase);
        }
    }

    static bool IsOfficialGitHubArchiveDriverPackageInstalled(Dictionary<string, object> package)
    {
        string serviceName = GetString(package, "installedService");
        string driverFileName = GetString(package, "driverFileName");
        bool servicePresent = IsInstalledService(serviceName);
        bool appPresent = File.Exists(GetPackageProgramFilePath(package, "installedFile"));

        bool driverPresent = true;
        if (!String.IsNullOrWhiteSpace(driverFileName))
        {
            if (!String.Equals(Path.GetFileName(driverFileName), driverFileName, StringComparison.Ordinal))
                throw new Exception("Invalid driverFileName for " + GetString(package, "name") + ".");

            driverPresent = File.Exists(Path.Combine(
                Environment.SystemDirectory,
                "drivers",
                driverFileName));
        }

        return servicePresent && appPresent && driverPresent;
    }

    static void ExtractZipToDirectorySafe(string archivePath, string destination)
    {
        Directory.CreateDirectory(destination);
        string root = Path.GetFullPath(destination);
        if (!root.EndsWith(Path.DirectorySeparatorChar.ToString(), StringComparison.Ordinal))
            root += Path.DirectorySeparatorChar;

        using (ZipArchive archive = ZipFile.OpenRead(archivePath))
        {
            foreach (ZipArchiveEntry entry in archive.Entries)
            {
                string relative = (entry.FullName ?? "").Replace('/', Path.DirectorySeparatorChar);
                if (String.IsNullOrWhiteSpace(relative)) continue;
                if (Path.IsPathRooted(relative) || relative.IndexOf(':') >= 0)
                    throw new Exception("Unsafe path in upstream package archive.");

                string target = Path.GetFullPath(Path.Combine(destination, relative));
                if (!target.StartsWith(root, StringComparison.OrdinalIgnoreCase))
                    throw new Exception("Unsafe path in upstream package archive.");

                if (String.IsNullOrEmpty(entry.Name))
                {
                    Directory.CreateDirectory(target);
                    continue;
                }

                string parent = Path.GetDirectoryName(target);
                if (!String.IsNullOrWhiteSpace(parent))
                    Directory.CreateDirectory(parent);
                entry.ExtractToFile(target, true);
            }
        }
    }

    static string FindPackageArchiveFile(string root, string fileName)
    {
        if (String.IsNullOrWhiteSpace(fileName) ||
            !String.Equals(Path.GetFileName(fileName), fileName, StringComparison.Ordinal))
            throw new Exception("Invalid package archive file name.");

        string[] matches = Directory.GetFiles(root, fileName, SearchOption.AllDirectories);
        if (matches.Length == 0)
            throw new Exception("Required file '" + fileName + "' was not found in the upstream package archive.");

        return matches
            .OrderBy(path => path.Length)
            .ThenBy(path => path, StringComparer.OrdinalIgnoreCase)
            .First();
    }

    static bool InstallGitHubPortablePackage(Dictionary<string, object> package)
    {
        string name = GetString(package, "name");
        string assetName;
        string downloaded = DownloadOfficialGitHubPackageAsset(package, out assetName);
        string target = GetPackageProgramFilePath(package, "installedFile");

        Directory.CreateDirectory(Path.GetDirectoryName(target));
        File.Copy(downloaded, target, true);

        if (!File.Exists(target) || !IsWindowsExecutableFile(target))
            throw new Exception(name + " portable executable was not installed correctly.");

        Console.WriteLine("Installed " + name + ": " + target);

        if (GetBool(package, "launchAfterInstall"))
        {
            var psi = new ProcessStartInfo();
            psi.FileName = target;
            psi.UseShellExecute = true;
            Process.Start(psi);
            Console.WriteLine("Started " + name + ".");
        }

        return true;
    }

    static bool InstallGitHubFontArchivePackage(Dictionary<string, object> package)
    {
        string name = GetString(package, "name");
        string assetName;
        string archivePath = DownloadOfficialGitHubPackageAsset(package, out assetName);
        if (!assetName.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
            throw new Exception(name + " font source must be a ZIP release asset.");

        string staging = Path.Combine(
            CacheRoot,
            "font-extract",
            Guid.NewGuid().ToString("N"));

        try
        {
            ExtractZipToDirectorySafe(archivePath, staging);
            string fontFile = GetString(package, "fontFile");
            string stagedFont = FindPackageArchiveFile(staging, fontFile);
            string target = GetUserFontFilePath(package);

            Directory.CreateDirectory(Path.GetDirectoryName(target));
            File.Copy(stagedFont, target, true);
            if (!File.Exists(target) || new FileInfo(target).Length == 0)
                throw new Exception(name + " font file was not installed correctly.");

            const string fontsKeyPath = @"Software\Microsoft\Windows NT\CurrentVersion\Fonts";
            using (RegistryKey key = Registry.CurrentUser.CreateSubKey(fontsKeyPath))
            {
                if (key == null)
                    throw new Exception("Could not open the current-user Windows Fonts registry key.");

                key.SetValue(
                    GetUserFontRegistryValueName(package),
                    target,
                    RegistryValueKind.String);
            }

            if (AddFontResourceEx(target, 0, IntPtr.Zero) == 0)
                throw new Exception("Windows did not load the installed font resource.");

            PostMessage(new IntPtr(0xFFFF), WmFontChange, IntPtr.Zero, IntPtr.Zero);
            Console.WriteLine("Installed " + name + ": " + target);
            return true;
        }
        finally
        {
            SafeDeleteDirectory(staging);
        }
    }

    static bool UninstallGitHubFontArchivePackage(Dictionary<string, object> package)
    {
        string target = GetUserFontFilePath(package);
        string valueName = GetUserFontRegistryValueName(package);
        const string fontsKeyPath = @"Software\Microsoft\Windows NT\CurrentVersion\Fonts";

        try { RemoveFontResourceEx(target, 0, IntPtr.Zero); } catch { }

        using (RegistryKey key = Registry.CurrentUser.OpenSubKey(fontsKeyPath, true))
        {
            if (key != null)
            {
                string current = Convert.ToString(
                    key.GetValue(
                        valueName,
                        null,
                        RegistryValueOptions.DoNotExpandEnvironmentNames));
                if (String.Equals(current, target, StringComparison.OrdinalIgnoreCase))
                    key.DeleteValue(valueName, false);
            }
        }

        SafeDeleteFile(target);
        PostMessage(new IntPtr(0xFFFF), WmFontChange, IntPtr.Zero, IntPtr.Zero);
        Console.WriteLine("Uninstalled WGDot-owned font: " + GetString(package, "name"));
        return true;
    }

    static bool InstallGitHubArchiveDriverPackage(Dictionary<string, object> package)
    {
        string name = GetString(package, "name");
        string assetName;
        string archivePath = DownloadOfficialGitHubPackageAsset(package, out assetName);
        if (!assetName.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
            throw new Exception(name + " archive-driver source must be a ZIP release asset.");

        string staging = Path.Combine(
            CacheRoot,
            "package-extract",
            Guid.NewGuid().ToString("N"));

        try
        {
            ExtractZipToDirectorySafe(archivePath, staging);

            string installerName = GetString(package, "archiveInstaller");
            string stagedInstaller = FindPackageArchiveFile(staging, installerName);
            string stagedRoot = Path.GetDirectoryName(stagedInstaller);
            if (String.IsNullOrWhiteSpace(stagedRoot))
                throw new Exception("Could not determine extracted package root for " + name + ".");

            string installedFileName = GetString(package, "installedFile");
            if (String.IsNullOrWhiteSpace(installedFileName) ||
                !String.Equals(Path.GetFileName(installedFileName), installedFileName, StringComparison.Ordinal) ||
                !File.Exists(Path.Combine(stagedRoot, installedFileName)))
                throw new Exception("Required application file '" + installedFileName + "' was not found beside the driver installer.");

            string targetRoot = GetPackageProgramDirectory(package);
            CopyDirectory(stagedRoot, targetRoot);

            string installer = Path.Combine(targetRoot, installerName);
            if (!File.Exists(installer) || !IsWindowsExecutableFile(installer))
                throw new Exception(name + " installer was not extracted correctly.");

            Console.WriteLine("Launching official upstream driver installer: " + installerName);
            ProcResult result = RunInteractiveInDirectory(installer, "", targetRoot);
            if (result.ExitCode != 0)
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine(name + " installer failed with exit " + result.ExitCode.ToString(CultureInfo.InvariantCulture) + ".");
                Console.ResetColor();
                return false;
            }

            if (!IsOfficialGitHubArchiveDriverPackageInstalled(package))
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine(name + " installer closed without a complete driver installation.");
                Console.ResetColor();
                return false;
            }

            return true;
        }
        finally
        {
            SafeDeleteDirectory(staging);
        }
    }

    static bool InstallGitHubReleasePackage(Dictionary<string, object> package)
    {
        string name = GetString(package, "name");
        string assetName;
        string installer;

        try
        {
            installer = DownloadOfficialGitHubPackageAsset(package, out assetName);
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine(ex.Message);
            Console.ResetColor();
            return false;
        }

        Console.WriteLine("Launching official upstream installer: " + assetName);
        ProcResult result = RunInteractive(installer, "");
        if (result.ExitCode != 0)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine(name + " installer failed with exit " + result.ExitCode.ToString(CultureInfo.InvariantCulture) + ".");
            Console.ResetColor();
            return false;
        }

        return true;
    }

    static void RunPackagePostInstall(Dictionary<string, object> package)
    {
        string action = GetString(package, "postInstallAction");
        if (String.IsNullOrWhiteSpace(action)) return;

        if (String.Equals(action, "rawaccel-restart-notice", StringComparison.OrdinalIgnoreCase))
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("Raw Accel driver installed. Restart Windows before using Raw Accel.");
            Console.ResetColor();
            Console.WriteLine("Raw Accel GUI: " + GetPackageProgramFilePath(package, "installedFile"));
            return;
        }

        if (String.Equals(action, "launch-open-shell", StringComparison.OrdinalIgnoreCase))
        {
            string[] candidates =
            {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Open-Shell", "StartMenu.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Open-Shell", "StartMenu.exe")
            };

            string exe = candidates.FirstOrDefault(File.Exists);
            if (String.IsNullOrWhiteSpace(exe))
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("Open-Shell installed, but StartMenu.exe was not found to launch it automatically.");
                Console.ResetColor();
                return;
            }

            var psi = new ProcessStartInfo();
            psi.FileName = exe;
            psi.UseShellExecute = true;
            Process.Start(psi);
            Console.WriteLine("Open-Shell started.");
            return;
        }

        throw new Exception("Unknown package post-install action '" + action + "'.");
    }

    static Dictionary<string, object> FindPackageById(
        Dictionary<string, object> manifest,
        string packageId)
    {
        foreach (object rawPackage in GetList(manifest, "packages"))
        {
            var package = AsDictionary(rawPackage);
            if (String.Equals(
                    GetString(package, "id"),
                    packageId,
                    StringComparison.OrdinalIgnoreCase))
                return package;
        }
        return null;
    }

    static string NormalizeSoftwarePlanPath(string planPath)
    {
        if (String.IsNullOrWhiteSpace(planPath))
            throw new Exception("Missing WGDot elevated software plan path.");

        string full = Path.GetFullPath(planPath);
        string root = Path.GetFullPath(StateRoot);
        string rootPrefix =
            root.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) +
            Path.DirectorySeparatorChar;
        string fileName = Path.GetFileName(full);

        if (!full.StartsWith(rootPrefix, StringComparison.OrdinalIgnoreCase) ||
            !fileName.StartsWith("software-elevated-", StringComparison.OrdinalIgnoreCase) ||
            !fileName.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
            throw new Exception("Elevated software plans must stay inside the WGDot state directory.");

        return full;
    }

    static int SoftwareElevatedFromArgs(string[] args)
    {
        if (!IsAdministrator())
            throw new Exception("The WGDot software worker requires administrator rights.");

        string planPath = GetOption(args, "--plan");
        return RunSoftwareElevatedPlan(planPath);
    }

    static int GetWingetInstallTimeoutMs(Dictionary<string, object> package)
    {
        int seconds = GetInt(package, "wingetInstallTimeoutSeconds");
        if (seconds <= 0) seconds = 900;
        seconds = Math.Max(30, Math.Min(seconds, 3600));
        return seconds * 1000;
    }

    static bool HasOfficialGitHubFallback(Dictionary<string, object> package)
    {
        return
            !String.IsNullOrWhiteSpace(GetString(package, "fallbackGitHubRepo")) &&
            !String.IsNullOrWhiteSpace(GetString(package, "fallbackAssetRegex"));
    }

    static int RunSoftwareElevatedPlan(string rawPlanPath)
    {
        string planPath = NormalizeSoftwarePlanPath(rawPlanPath);
        string resultPath = planPath + ".result";
        var result = new Dictionary<string, object>();
        var installedIds = new List<string>();
        var alreadyIds = new List<string>();
        var unavailableIds = new List<string>();
        var failedIds = new List<string>();
        var upgradedIds = new List<string>();
        var upgradeFailedIds = new List<string>();
        var adminTweakFailedIds = new List<string>();
        var failureDetails = new List<string>();
        string browserPolicyError = "";
        int failures = 0;

        try
        {
            Dictionary<string, object> plan = ReadJson(planPath);
            if (plan == null)
                throw new Exception("WGDot elevated software plan was not found.");

            SourceContext source = ResolveDefaultSource();
            Dictionary<string, object> manifest = source.Manifest;
            string expectedRevision = GetString(plan, "sourceRevision");
            if (!String.IsNullOrWhiteSpace(expectedRevision) &&
                !String.Equals(expectedRevision, source.Revision, StringComparison.OrdinalIgnoreCase))
                throw new Exception("WGDot software plan source changed before elevation. Re-run software reconciliation.");

            EnsureWingetAvailable();

            foreach (string id in GetStringList(plan, "packageIds")
                .Distinct(StringComparer.OrdinalIgnoreCase))
            {
                Dictionary<string, object> package = FindPackageById(manifest, id);
                if (package == null)
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("Package is no longer present in the active WGDot manifest; skipped: " + id);
                    Console.ResetColor();
                    failedIds.Add(id);
                    failureDetails.Add("Package missing from active WGDot manifest: " + id);
                    failures++;
                    continue;
                }

                Console.WriteLine();
                Console.WriteLine("Installing " + id + "...");

                if (IsOfficialGitHubPortablePackage(package) ||
                    IsOfficialGitHubFontArchivePackage(package))
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("Refusing to install a user-level package inside the elevated worker: " + id);
                    Console.ResetColor();
                    failedIds.Add(id);
                    failureDetails.Add("User-level package was incorrectly sent to the elevated worker: " + id);
                    failures++;
                    continue;
                }

                if (IsOfficialGitHubArchiveDriverPackage(package))
                {
                    Console.WriteLine("Using approved official GitHub driver archive for " + id + ".");
                    if (InstallGitHubArchiveDriverPackage(package))
                        installedIds.Add(id);
                    else
                    {
                        failedIds.Add(id);
                        failureDetails.Add("Official GitHub driver archive install failed: " + id);
                        failures++;
                    }
                    continue;
                }

                if (IsOfficialGitHubPackage(package))
                {
                    Console.WriteLine("Using approved official GitHub source for " + id + ".");
                    if (InstallGitHubReleasePackage(package))
                        installedIds.Add(id);
                    else
                    {
                        failedIds.Add(id);
                        failureDetails.Add("Official GitHub install failed: " + id);
                        failures++;
                    }
                    continue;
                }

                ProcResult show = RunWithTimeout(
                    "winget.exe",
                    "show --id " + Q(id) + " --exact --source winget --accept-source-agreements --disable-interactivity",
                    null,
                    WingetPreflightTimeoutMs);
                if (show.TimedOut)
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("WinGet validation timed out for " + id + "; skipped.");
                    Console.ResetColor();
                    failedIds.Add(id);
                    failureDetails.Add("WinGet validation timed out: " + id);
                    failures++;
                    continue;
                }
                if (show.ExitCode != 0)
                {
                    string fallbackRepo = GetString(package, "fallbackGitHubRepo");
                    string fallbackAssetRegex = GetString(package, "fallbackAssetRegex");
                    if (!String.IsNullOrWhiteSpace(fallbackRepo) &&
                        !String.IsNullOrWhiteSpace(fallbackAssetRegex))
                    {
                        Console.ForegroundColor = ConsoleColor.Yellow;
                        Console.WriteLine("Exact WinGet ID unavailable; using approved upstream GitHub fallback for " + id + ".");
                        Console.ResetColor();

                        if (InstallGitHubReleasePackage(package))
                            installedIds.Add(id);
                        else
                        {
                            failedIds.Add(id);
                            failureDetails.Add("Official GitHub fallback failed: " + id);
                            failures++;
                        }
                        continue;
                    }

                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("Unavailable by exact WinGet ID; skipped: " + id);
                    Console.ResetColor();
                    unavailableIds.Add(id);
                    continue;
                }

                int installTimeoutMs = GetWingetInstallTimeoutMs(package);
                ProcResult install = RunInteractiveWithTimeout(
                    "winget.exe",
                    "install --id " + Q(id) + " --exact --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity",
                    installTimeoutMs);

                if (install.ExitCode == 0)
                {
                    installedIds.Add(id);
                }
                else if (HasOfficialGitHubFallback(package))
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    if (install.TimedOut)
                        Console.WriteLine("WinGet install timed out for " + id + "; trying the approved official GitHub fallback.");
                    else
                        Console.WriteLine("WinGet install failed for " + id + "; trying the approved official GitHub fallback.");
                    Console.ResetColor();

                    if (InstallGitHubReleasePackage(package))
                        installedIds.Add(id);
                    else
                    {
                        failedIds.Add(id);
                        failureDetails.Add("WinGet failed/timed out and official GitHub fallback also failed: " + id);
                        failures++;
                    }
                }
                else
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    if (install.TimedOut)
                        Console.WriteLine("Install timed out: " + id + ".");
                    else
                        Console.WriteLine("Install failed: " + id + " (exit " + install.ExitCode.ToString(CultureInfo.InvariantCulture) + ")");
                    Console.ResetColor();
                    failedIds.Add(id);
                    failureDetails.Add(
                        install.TimedOut
                            ? "WinGet install timed out: " + id
                            : "WinGet install failed (" + install.ExitCode.ToString(CultureInfo.InvariantCulture) + "): " + id);
                    failures++;
                }
            }

            foreach (string id in GetStringList(plan, "upgradeIds")
                .Distinct(StringComparer.OrdinalIgnoreCase))
            {
                if (FindPackageById(manifest, id) == null)
                {
                    upgradeFailedIds.Add(id);
                    failureDetails.Add("Upgrade package missing from active WGDot manifest: " + id);
                    failures++;
                    continue;
                }

                Console.WriteLine();
                Console.WriteLine("Upgrading " + id + "...");
                ProcResult upgrade = RunInteractive(
                    "winget.exe",
                    "upgrade --id " + Q(id) + " --exact --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity");

                if (upgrade.ExitCode == 0)
                {
                    upgradedIds.Add(id);
                }
                else
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("Upgrade failed: " + id + " (exit " + upgrade.ExitCode.ToString(CultureInfo.InvariantCulture) + ")");
                    Console.ResetColor();
                    upgradeFailedIds.Add(id);
                    failureDetails.Add("WinGet upgrade failed (" + upgrade.ExitCode.ToString(CultureInfo.InvariantCulture) + "): " + id);
                    failures++;
                }
            }

            if (GetBool(plan, "firefoxPolicyConfigured"))
            {
                try
                {
                    ApplyFirefoxExtensionInstallPolicy(
                        GetStringList(plan, "firefoxInstallUrls"));
                }
                catch (Exception ex)
                {
                    browserPolicyError = ex.Message;
                    failureDetails.Add("Firefox extension policy: " + ex.Message);
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("Firefox extension policy failed in elevated setup: " + ex.Message);
                    Console.ResetColor();
                    failures++;
                }
            }

            foreach (string id in GetStringList(plan, "adminTweakIds")
                .Distinct(StringComparer.OrdinalIgnoreCase))
            {
                if (!TweakRunsInElevatedBatch(id))
                {
                    adminTweakFailedIds.Add(id);
                    failureDetails.Add("Unexpected non-elevated tweak in elevated plan: " + id);
                    failures++;
                    continue;
                }

                try
                {
                    Console.WriteLine("Applying elevated setup: " + id + "...");
                    ApplyTweak(id, true, false);
                }
                catch (Exception ex)
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("Administrator tweak failed: " + id + ": " + ex.Message);
                    Console.ResetColor();
                    adminTweakFailedIds.Add(id);
                    failureDetails.Add("Administrator tweak '" + id + "': " + ex.Message);
                    failures++;
                }
            }
        }
        catch (Exception ex)
        {
            result["fatalError"] = ex.Message;
            failureDetails.Add("Elevated software worker: " + ex.Message);
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("WGDot elevated software worker failed: " + ex.Message);
            Console.ResetColor();
            failures++;
        }
        finally
        {
            result["installedIds"] = installedIds;
            result["alreadyIds"] = alreadyIds;
            result["unavailableIds"] = unavailableIds;
            result["failedIds"] = failedIds;
            result["upgradedIds"] = upgradedIds;
            result["upgradeFailedIds"] = upgradeFailedIds;
            result["adminTweakFailedIds"] = adminTweakFailedIds;
            result["browserPolicyError"] = browserPolicyError;
            result["failureDetails"] = failureDetails;
            WriteJson(resultPath, result);
        }

        return failures == 0 ? 0 : 1;
    }

    static bool IsOfficialGitHubPackage(Dictionary<string, object> package)
    {
        string mode = GetString(package, "installMode");
        return
            String.Equals(mode, "official-github", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(mode, "official-github-portable", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(mode, "official-github-font-archive", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(mode, "official-github-archive-driver", StringComparison.OrdinalIgnoreCase);
    }

    static bool IsOfficialGitHubPortablePackage(Dictionary<string, object> package)
    {
        return String.Equals(
            GetString(package, "installMode"),
            "official-github-portable",
            StringComparison.OrdinalIgnoreCase);
    }

    static bool IsOfficialGitHubFontArchivePackage(Dictionary<string, object> package)
    {
        return String.Equals(
            GetString(package, "installMode"),
            "official-github-font-archive",
            StringComparison.OrdinalIgnoreCase);
    }

    static bool IsOfficialGitHubArchiveDriverPackage(Dictionary<string, object> package)
    {
        return String.Equals(
            GetString(package, "installMode"),
            "official-github-archive-driver",
            StringComparison.OrdinalIgnoreCase);
    }

    static bool IsOfficialPagePackage(Dictionary<string, object> package)
    {
        return String.Equals(
            GetString(package, "installMode"),
            "official-page",
            StringComparison.OrdinalIgnoreCase);
    }

    static bool ProbeOfficialHttpsPage(string url, out string error)
    {
        error = "";
        if (String.IsNullOrWhiteSpace(url) ||
            !url.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
        {
            error = "Official page URL must use HTTPS.";
            return false;
        }

        try
        {
            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(url);
            request.Method = "GET";
            request.UserAgent = "Mozilla/5.0 WGDot";
            request.AllowAutoRedirect = true;
            request.Timeout = WingetPreflightTimeoutMs;
            request.ReadWriteTimeout = WingetPreflightTimeoutMs;

            using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
            using (Stream stream = response.GetResponseStream())
            {
                int status = (int)response.StatusCode;
                if (status < 200 || status >= 400)
                {
                    error = "HTTP " + status.ToString(CultureInfo.InvariantCulture);
                    return false;
                }

                if (stream != null)
                    stream.ReadByte();
            }

            return true;
        }
        catch (Exception ex)
        {
            error = ex.Message;
            return false;
        }
    }

    static bool IsKnownPackagePostInstallAction(string action)
    {
        return
            String.IsNullOrWhiteSpace(action) ||
            String.Equals(action, "launch-open-shell", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(action, "rawaccel-restart-notice", StringComparison.OrdinalIgnoreCase);
    }

    static int SoftwareCatalogAudit()
    {
        return SoftwareCatalogAudit(true);
    }

    static int SoftwareCatalogAudit(bool askConfirmation)
    {
        SourceContext source = ResolveDefaultSource();
        Dictionary<string, object> manifest = source.Manifest;
        List<object> packages = GetList(manifest, "packages");

        WriteTitle("Software catalog audit (no install)");
        Console.WriteLine("Packages in manifest: " + packages.Count.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine();
        Console.WriteLine("This audit does not install, upgrade, download installers, launch apps,");
        Console.WriteLine("change registry settings, or request administrator access.");
        Console.WriteLine("It validates each package's declared source: WinGet, official GitHub, or official publisher page.");
        Console.WriteLine();

        if (askConfirmation &&
            !ReadYesNo("Audit all software now? [y/N]", false))
        {
            Console.WriteLine("No audit was run.");
            return 0;
        }

        EnsureWingetAvailable();

        int wingetOk = 0;
        int fallbackOk = 0;
        int officialPageOk = 0;
        int alternateSourceCount = 0;
        int warningCount = 0;
        int failureCount = 0;
        var failureDetails = new List<string>();
        var warningDetails = new List<string>();

        for (int index = 0; index < packages.Count; index++)
        {
            var package = AsDictionary(packages[index]);
            string id = GetString(package, "id");
            string name = GetString(package, "name");
            string postInstallAction = GetString(package, "postInstallAction");
            bool hasFallback = HasOfficialGitHubFallback(package);
            bool officialGitHub = IsOfficialGitHubPackage(package);
            bool officialPage = IsOfficialPagePackage(package);

            Console.Write(
                "[" + (index + 1).ToString(CultureInfo.InvariantCulture) +
                "/" + packages.Count.ToString(CultureInfo.InvariantCulture) + "] " +
                id + " ... ");

            if (String.IsNullOrWhiteSpace(id))
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("FAIL");
                Console.ResetColor();
                failureCount++;
                failureDetails.Add("Manifest package has an empty WinGet ID: " + name);
                continue;
            }

            if (!IsKnownPackagePostInstallAction(postInstallAction))
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("FAIL");
                Console.ResetColor();
                failureCount++;
                failureDetails.Add(
                    "Unknown post-install action '" + postInstallAction + "' for " + id);
                continue;
            }

            if (officialGitHub)
            {
                try
                {
                    string assetName;
                    string assetUrl;
                    if (ResolveGitHubReleasePackageAsset(package, out assetName, out assetUrl))
                    {
                        fallbackOk++;
                        alternateSourceCount++;
                        Console.ForegroundColor = ConsoleColor.Green;
                        Console.Write("official GitHub OK");
                        Console.ResetColor();
                        Console.WriteLine(" (" + assetName + ")");
                    }
                    else
                    {
                        failureCount++;
                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.WriteLine("official GitHub FAIL");
                        Console.ResetColor();
                        failureDetails.Add(
                            "Official GitHub source has no matching latest-release asset: " + id);
                    }
                }
                catch (Exception ex)
                {
                    failureCount++;
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("official GitHub FAIL");
                    Console.ResetColor();
                    failureDetails.Add(
                        "Official GitHub source check failed for " + id + ": " + ex.Message);
                }
                continue;
            }

            if (officialPage)
            {
                string pageUrl = GetString(package, "officialPageUrl");
                string pageError;
                bool pageOk = ProbeOfficialHttpsPage(pageUrl, out pageError);
                if (pageOk)
                {
                    officialPageOk++;
                    alternateSourceCount++;
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine("official page OK");
                    Console.ResetColor();
                }
                else
                {
                    failureCount++;
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("official page FAIL");
                    Console.ResetColor();
                    failureDetails.Add(
                        "Official download page check failed for " + id + ": " + pageError);
                }
                continue;
            }

            ProcResult show = RunWithTimeout(
                "winget.exe",
                "show --id " + Q(id) +
                " --exact --source winget --accept-source-agreements --disable-interactivity",
                null,
                WingetPreflightTimeoutMs);

            bool exactOk = !show.TimedOut && show.ExitCode == 0;
            if (exactOk)
            {
                wingetOk++;
                Console.ForegroundColor = ConsoleColor.Green;
                Console.Write("WinGet OK");
                Console.ResetColor();
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.Write(show.TimedOut ? "WinGet TIMEOUT" : "WinGet MISSING");
                Console.ResetColor();

                if (!hasFallback)
                {
                    failureCount++;
                    failureDetails.Add(
                        show.TimedOut
                            ? "WinGet exact-ID lookup timed out: " + id
                            : "WinGet exact ID unavailable and no fallback is declared: " + id);
                }
            }

            if (hasFallback)
            {
                try
                {
                    string assetName;
                    string assetUrl;
                    if (ResolveGitHubReleasePackageAsset(package, out assetName, out assetUrl))
                    {
                        fallbackOk++;
                        Console.Write(" | fallback ");
                        Console.ForegroundColor = ConsoleColor.Green;
                        Console.Write("OK");
                        Console.ResetColor();
                        Console.Write(" (" + assetName + ")");
                    }
                    else
                    {
                        failureCount++;
                        Console.Write(" | fallback ");
                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.Write("FAIL");
                        Console.ResetColor();
                        failureDetails.Add(
                            "Official GitHub fallback has no matching latest-release asset: " + id);
                    }
                }
                catch (Exception ex)
                {
                    failureCount++;
                    Console.Write(" | fallback ");
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.Write("FAIL");
                    Console.ResetColor();
                    failureDetails.Add(
                        "Official GitHub fallback check failed for " + id + ": " + ex.Message);
                }
            }

            if (!exactOk && hasFallback)
            {
                alternateSourceCount++;
                Console.Write(" | using verified fallback path");
            }

            Console.WriteLine();
        }

        Console.WriteLine();
        Console.WriteLine("Software catalog audit complete.");
        Console.WriteLine("Packages checked: " + packages.Count.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Exact WinGet IDs available: " + wingetOk.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Official GitHub fallbacks verified: " + fallbackOk.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Official download pages verified: " + officialPageOk.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Packages using alternate official source: " + alternateSourceCount.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Warnings: " + warningCount.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Failures: " + failureCount.ToString(CultureInfo.InvariantCulture));

        if (warningDetails.Count > 0)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine();
            Console.WriteLine("Warnings:");
            foreach (string detail in warningDetails.Distinct(StringComparer.OrdinalIgnoreCase))
                Console.WriteLine("  - " + detail);
            Console.ResetColor();
        }

        if (failureDetails.Count > 0)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine();
            Console.WriteLine("Failure details:");
            foreach (string detail in failureDetails.Distinct(StringComparer.OrdinalIgnoreCase))
                Console.WriteLine("  - " + detail);
            Console.ResetColor();
        }

        Console.WriteLine();
        Console.WriteLine(
            "Audit scope: catalog/fallback/post-install metadata only. " +
            "Installer execution and application-specific runtime behavior still require an installed app.");

        return failureCount == 0 ? 0 : 1;
    }

    static ProcResult RunIsolatedMaintenanceSelfTest()
    {
        string testRoot = Path.Combine(
            Path.GetTempPath(),
            "wgdot-acceptance-" + Guid.NewGuid().ToString("N"));

        string previousTestRoot = Environment.GetEnvironmentVariable("WGDOT_TEST_ROOT");
        string previousSkipRefresh = Environment.GetEnvironmentVariable("WGDOT_SKIP_RUNTIME_REFRESH");

        try
        {
            Environment.SetEnvironmentVariable("WGDOT_TEST_ROOT", testRoot);
            Environment.SetEnvironmentVariable("WGDOT_SKIP_RUNTIME_REFRESH", "1");

            string currentExe = Process.GetCurrentProcess().MainModule.FileName;
            return Run(currentExe, "maintenance-self-test", null);
        }
        finally
        {
            Environment.SetEnvironmentVariable("WGDOT_TEST_ROOT", previousTestRoot);
            Environment.SetEnvironmentVariable("WGDOT_SKIP_RUNTIME_REFRESH", previousSkipRefresh);
            SafeDeleteDirectory(testRoot);
        }
    }

    static bool ValidateBrowserSelectionState(
        Dictionary<string, object> manifest,
        InstallationSelection selection,
        out string error)
    {
        error = "";
        if (selection == null || !selection.BrowserOptionsConfigured)
            return true;

        var browserByPackage =
            new Dictionary<string, Dictionary<string, object>>(StringComparer.OrdinalIgnoreCase);

        foreach (object rawBrowser in GetList(manifest, "browserOptions"))
        {
            var browser = AsDictionary(rawBrowser);
            string packageId = GetString(browser, "packageId");
            if (String.IsNullOrWhiteSpace(packageId))
            {
                error = "Browser option entry is missing packageId.";
                return false;
            }
            browserByPackage[packageId] = browser;
        }

        foreach (KeyValuePair<string, List<string>> pair in selection.BrowserOptions)
        {
            Dictionary<string, object> browser;
            if (!browserByPackage.TryGetValue(pair.Key, out browser))
            {
                error = "Saved browser options reference unknown package: " + pair.Key;
                return false;
            }

            var knownOptions = new HashSet<string>(
                GetList(browser, "options")
                    .Select(raw => GetString(AsDictionary(raw), "id"))
                    .Where(id => !String.IsNullOrWhiteSpace(id)),
                StringComparer.OrdinalIgnoreCase);

            foreach (string optionId in pair.Value ?? new List<string>())
            {
                if (!knownOptions.Contains(optionId))
                {
                    error =
                        "Saved browser option '" + optionId +
                        "' is no longer declared for " + pair.Key + ".";
                    return false;
                }
            }
        }

        return true;
    }

    static int AcceptanceAudit()
    {
        WriteTitle("Automated acceptance audit (safe)");
        Console.WriteLine(
            "This audit is read-only against your live WGDot/Windows configuration. " +
            "Mutation tests run only inside an isolated temporary WGDot test root.");
        Console.WriteLine("It does not install software, change tweaks, apply managed dots, launch DDU, or modify browser profiles.");
        Console.WriteLine();

        int failures = 0;
        int warnings = 0;
        var failureDetails = new List<string>();
        var warningDetails = new List<string>();

        Console.WriteLine("[1/5] Isolated native mutation/rollback suite...");
        ProcResult isolated = RunIsolatedMaintenanceSelfTest();
        if (isolated.ExitCode == 0)
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("PASS");
            Console.ResetColor();
        }
        else
        {
            failures++;
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("FAIL");
            Console.ResetColor();
            failureDetails.Add(
                "Isolated maintenance self-test: " +
                LastUsefulLine(
                    String.IsNullOrWhiteSpace(isolated.StdErr)
                        ? isolated.StdOut
                        : isolated.StdErr));
        }

        Console.WriteLine();
        Console.WriteLine("[2/5] Managed configuration planner...");
        try
        {
            SourceContext source = ResolveDefaultSource();
            InstallationSelection selection = ReadInstallationSelection();
            if (selection == null)
            {
                warnings++;
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("SKIP: no saved installation selection exists yet.");
                Console.ResetColor();
                warningDetails.Add(
                    "Managed-plan audit skipped because installation selection is not configured.");
            }
            else
            {
                bool hasBaseline = File.Exists(BaselineIndexPath);
                string effectiveMode = hasBaseline ? "update" : "reset";
                List<PlanItem> plan = GetPlan(
                    source.Manifest,
                    source.SourceRoot,
                    selection,
                    effectiveMode);

                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine(
                    "PASS: " + plan.Count.ToString(CultureInfo.InvariantCulture) +
                    " managed file plan item(s) resolved with safe destinations and present sources.");
                Console.ResetColor();

                string browserError;
                if (!ValidateBrowserSelectionState(source.Manifest, selection, out browserError))
                {
                    failures++;
                    failureDetails.Add("Browser selection state: " + browserError);
                }
            }
        }
        catch (Exception ex)
        {
            failures++;
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("FAIL");
            Console.ResetColor();
            failureDetails.Add("Managed configuration planner: " + ex.Message);
        }

        Console.WriteLine();
        Console.WriteLine("[3/5] Full software catalog/source audit...");
        int softwareResult = SoftwareCatalogAudit(false);
        if (softwareResult != 0)
        {
            failures++;
            failureDetails.Add("Software catalog/source audit reported one or more failures.");
        }

        Console.WriteLine();
        Console.WriteLine("[4/5] GPU inventory (read-only)...");
        try
        {
            List<GpuAdapterInfo> adapters = DetectGpuAdapters();
            if (adapters.Count == 0)
            {
                warnings++;
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("WARN: no present display adapters were detected.");
                Console.ResetColor();
                warningDetails.Add("No present display adapters were detected by SetupAPI.");
            }
            else
            {
                foreach (GpuAdapterInfo adapter in adapters)
                {
                    Console.WriteLine(
                        "  " + GpuVendorLabel(adapter.Vendor) +
                        " | " + adapter.Name +
                        " | provider: " + adapter.DriverProvider +
                        " | version: " + adapter.DriverVersion);
                }
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("PASS: GPU inventory completed without changing drivers.");
                Console.ResetColor();
            }
        }
        catch (Exception ex)
        {
            failures++;
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("FAIL");
            Console.ResetColor();
            failureDetails.Add("GPU inventory: " + ex.Message);
        }

        Console.WriteLine();
        Console.WriteLine("[5/5] Runtime refresh policy...");
        string[] requiredRefreshCommands =
        {
            "menu",
            "status",
            "git-review",
            "git-update",
            "git-reset",
            "dots-only",
            "software",
            "software-reconcile",
            "software-uninstall",
            "startup",
            "startup-disable-all",
            "software-audit",
            "acceptance-audit",
            "cursor",
            "gpu-driver",
            "update",
            "reset",
            "review"
        };
        List<string> missingRefresh = requiredRefreshCommands
            .Where(command => !ShouldAutoRefreshRuntime(command))
            .ToList();

        if (missingRefresh.Count == 0)
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("PASS: all normal user-facing maintenance commands refresh before dispatch.");
            Console.ResetColor();
        }
        else
        {
            failures++;
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("FAIL");
            Console.ResetColor();
            failureDetails.Add(
                "Runtime auto-refresh missing for: " +
                String.Join(", ", missingRefresh.ToArray()));
        }

        Console.WriteLine();
        Console.WriteLine("Automated acceptance audit complete.");
        Console.WriteLine("Failures: " + failures.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Warnings: " + warnings.ToString(CultureInfo.InvariantCulture));

        if (failureDetails.Count > 0)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine();
            Console.WriteLine("Failure details:");
            foreach (string detail in failureDetails)
                Console.WriteLine("  - " + detail);
            Console.ResetColor();
        }

        if (warningDetails.Count > 0)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine();
            Console.WriteLine("Warnings:");
            foreach (string detail in warningDetails)
                Console.WriteLine("  - " + detail);
            Console.ResetColor();
        }

        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.DarkGray;
        Console.WriteLine(
            "Still requires real Windows interaction: hotkey behavior, idle-inhibitor/cursor live behavior, " +
            "Windows Terminal live theme reload, actual Firefox/Brave extension consumption, one real managed-dots " +
            "apply/rollback cycle, and any intentionally tested DDU reboot flow.");
        Console.ResetColor();

        return failures == 0 ? 0 : 1;
    }

    static List<Dictionary<string, object>> GetStartupPackages(Dictionary<string, object> manifest)
    {
        return GetList(manifest, "packages")
            .Select(AsDictionary)
            .Where(p => !String.IsNullOrWhiteSpace(GetString(p, "startupHandler")))
            .OrderBy(p => GetString(p, "name"), StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    static Dictionary<string, object> ReadStartupState()
    {
        Dictionary<string, object> state =
            ReadJson(StartupStatePath) ??
            new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        if (!state.ContainsKey("preferences"))
            state["preferences"] = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        return state;
    }

    static bool TryGetStartupPreference(
        Dictionary<string, object> state,
        string packageId,
        out bool enabled)
    {
        Dictionary<string, object> prefs = GetDictionary(state, "preferences");
        object raw;
        if (prefs.TryGetValue(packageId, out raw) && raw != null)
        {
            enabled = Convert.ToBoolean(raw);
            return true;
        }

        enabled = false;
        return false;
    }

    static void SetStartupPreference(string packageId, bool enabled)
    {
        Dictionary<string, object> state = ReadStartupState();
        Dictionary<string, object> prefs = GetDictionary(state, "preferences");
        prefs[packageId] = enabled;
        state["preferences"] = prefs;
        state["updatedAt"] = DateTime.UtcNow.ToString("o");
        WriteJson(StartupStatePath, state);
    }

    static string FindExecutableWithCandidates(
        string fileName,
        IEnumerable<string> candidates)
    {
        string registered = FindRegisteredAppPath(fileName);
        if (!String.IsNullOrWhiteSpace(registered))
            return registered;

        ProcResult where = Run("where.exe", fileName, null);
        if (where.ExitCode == 0)
        {
            foreach (string line in (where.StdOut ?? "").Replace("\r", "").Split('\n'))
            {
                string candidate = line.Trim();
                if (!String.IsNullOrWhiteSpace(candidate) && File.Exists(candidate))
                    return candidate;
            }
        }

        foreach (string candidate in candidates ?? Enumerable.Empty<string>())
            if (!String.IsNullOrWhiteSpace(candidate) && File.Exists(candidate))
                return candidate;

        return "";
    }

    static string FindGlazeWmExe()
    {
        string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        return FindExecutableWithCandidates(
            "glazewm.exe",
            new[]
            {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "glzr.io", "cli", "glazewm.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "glzr.io", "cli", "glazewm.exe"),
                Path.Combine(local, "Programs", "glzr.io", "cli", "glazewm.exe"),
                Path.Combine(local, "Microsoft", "WinGet", "Packages", "glzr-io.glazewm", "glazewm.exe")
            });
    }

    static string RequireGlazeWmExe()
    {
        string exe = FindGlazeWmExe();
        if (String.IsNullOrWhiteSpace(exe))
            throw new Exception("GlazeWM executable could not be found.");
        return exe;
    }

    static string FindAltSnapExe()
    {
        string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        return FindExecutableWithCandidates(
            "AltSnap.exe",
            new[]
            {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "AltSnap", "AltSnap.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "AltSnap", "AltSnap.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "AltSnap", "AltSnap.exe"),
                Path.Combine(local, "Programs", "AltSnap", "AltSnap.exe")
            });
    }

    static bool IsLegacyYasbStartupCommand(string command)
    {
        string trimmed = (command ?? "").Trim();
        if (trimmed.Length < 3 || trimmed[0] != '"' || trimmed[trimmed.Length - 1] != '"')
            return false;

        string path = trimmed.Substring(1, trimmed.Length - 2);
        if (String.IsNullOrWhiteSpace(path) || path.IndexOf('"') >= 0 || !Path.IsPathRooted(path))
            return false;

        string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        string[] oldCandidates =
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "YASB", "yasb.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "YASB", "yasb.exe"),
            Path.Combine(local, "Programs", "YASB", "yasb.exe"),
            Path.Combine(local, "yasb", "yasb.exe")
        };

        try
        {
            string normalized = Path.GetFullPath(path);
            return oldCandidates
                .Where(candidate => !String.IsNullOrWhiteSpace(candidate))
                .Any(candidate =>
                    String.Equals(
                        normalized,
                        Path.GetFullPath(candidate),
                        StringComparison.OrdinalIgnoreCase));
        }
        catch
        {
            return false;
        }
    }

    static void RemoveLegacyYasbStartupRegistrationIfOwned()
    {
        const string runPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
        const string valueName = "WGDot.yasb";

        using (RegistryKey key = Registry.CurrentUser.OpenSubKey(runPath, true))
        {
            if (key == null) return;

            object raw = key.GetValue(
                valueName,
                null,
                RegistryValueOptions.DoNotExpandEnvironmentNames);
            if (raw == null) return;

            string command = Convert.ToString(raw);
            if (!IsLegacyYasbStartupCommand(command))
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine(
                    "Legacy WGDot.yasb startup value no longer matches WGDot's old direct YASB command; preserved.");
                Console.ResetColor();
                return;
            }

            key.DeleteValue(valueName, false);
            Console.WriteLine("Removed legacy duplicate WGDot.yasb startup registration.");
        }
    }

    static string StartupRunValueName(Dictionary<string, object> package)
    {
        string handler = GetString(package, "startupHandler");
        if (String.IsNullOrWhiteSpace(handler) ||
            !Regex.IsMatch(handler, "^[A-Za-z0-9-]+$"))
            throw new Exception("Invalid WGDot startup handler for " + GetString(package, "name") + ".");
        return "WGDot." + handler;
    }

    static string BuildStartupCommand(Dictionary<string, object> package)
    {
        string handler = GetString(package, "startupHandler");

        if (String.Equals(handler, "glazewm", StringComparison.OrdinalIgnoreCase))
        {
            string exe = FindGlazeWmExe();
            if (String.IsNullOrWhiteSpace(exe))
                throw new Exception("GlazeWM is selected for startup, but glazewm.exe could not be found.");

            string config = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                ".glzr",
                "glazewm",
                "config.yaml");
            return Q(exe) + " start --config=" + Q(config);
        }

        if (String.Equals(handler, "altsnap", StringComparison.OrdinalIgnoreCase))
        {
            string exe = FindAltSnapExe();
            if (String.IsNullOrWhiteSpace(exe))
                throw new Exception("AltSnap is selected for startup, but AltSnap.exe could not be found.");
            return Q(exe);
        }

        if (String.Equals(handler, "eartrumpet", StringComparison.OrdinalIgnoreCase))
            return "explorer.exe shell:AppsFolder\\40459File-New-Project.EarTrumpet_1sdd7yawvg6ne!EarTrumpet";

        if (String.Equals(handler, "rawaccel", StringComparison.OrdinalIgnoreCase))
        {
            string path = GetPackageProgramFilePath(package, "installedFile");
            if (!File.Exists(path))
                throw new Exception("RawAccel is selected for startup, but its WGDot-managed executable is missing.");
            return Q(path);
        }

        if (String.Equals(handler, "miclocktray", StringComparison.OrdinalIgnoreCase))
        {
            string path = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs",
                "MicLockTray",
                "MicLockTray.exe");
            if (!File.Exists(path))
                throw new Exception("MicLockTray is selected for startup, but its WGDot-managed executable is missing.");
            return Q(path);
        }

        throw new Exception("Unknown WGDot startup handler: " + handler);
    }

    static bool IsStartupRegistrationEnabled(Dictionary<string, object> package)
    {
        string name = StartupRunValueName(package);
        using (RegistryKey key = Registry.CurrentUser.OpenSubKey(
            @"Software\Microsoft\Windows\CurrentVersion\Run",
            false))
        {
            return key != null && key.GetValue(name, null) != null;
        }
    }

    static void SetStartupRegistration(Dictionary<string, object> package, bool enable)
    {
        string name = StartupRunValueName(package);
        const string runPath = @"Software\Microsoft\Windows\CurrentVersion\Run";

        RemoveLegacyYasbStartupRegistrationIfOwned();

        using (RegistryKey key = Registry.CurrentUser.CreateSubKey(runPath))
        {
            if (key == null)
                throw new Exception("Could not open the current-user Windows startup registry key.");

            if (!enable)
            {
                key.DeleteValue(name, false);
                Console.WriteLine("Startup disabled: " + GetString(package, "name"));
                return;
            }

            string command = BuildStartupCommand(package);
            key.SetValue(name, command, RegistryValueKind.String);
            Console.WriteLine("Startup enabled: " + GetString(package, "name"));
        }
    }

    static void ApplyStartupDefaultsForSelection(
        Dictionary<string, object> manifest,
        InstallationSelection selection)
    {
        if (selection == null) return;

        var selected = new HashSet<string>(
            selection.Packages,
            StringComparer.OrdinalIgnoreCase);
        Dictionary<string, object> state = ReadStartupState();
        Dictionary<string, object> prefs = GetDictionary(state, "preferences");
        bool changedState = false;

        foreach (Dictionary<string, object> package in GetStartupPackages(manifest))
        {
            string id = GetString(package, "id");
            bool preferred;
            object rawPreference;
            if (prefs.TryGetValue(id, out rawPreference) && rawPreference != null)
                preferred = Convert.ToBoolean(rawPreference);
            else
            {
                preferred = GetBool(package, "startupDefault");
                prefs[id] = preferred;
                changedState = true;
            }

            bool desired = selected.Contains(id) && preferred;
            try
            {
                SetStartupRegistration(package, desired);
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine(
                    "Startup integration skipped for " +
                    GetString(package, "name") + ": " + ex.Message);
                Console.ResetColor();
            }
        }

        if (changedState)
        {
            state["preferences"] = prefs;
            state["updatedAt"] = DateTime.UtcNow.ToString("o");
            WriteJson(StartupStatePath, state);
        }
    }

    static int StartupManager()
    {
        SourceContext source = ResolveDefaultSource();
        Dictionary<string, object> manifest = source.Manifest;
        InstallationSelection selection = ReadInstallationSelection();
        if (selection == null)
        {
            WriteTitle("Startup applications");
            Console.WriteLine("No WGDot software selection exists yet.");
            Console.WriteLine("Install / reconcile software first.");
            return 0;
        }

        var selectedPackages = new HashSet<string>(
            selection.Packages,
            StringComparer.OrdinalIgnoreCase);
        List<Dictionary<string, object>> packages = GetStartupPackages(manifest)
            .Where(p => selectedPackages.Contains(GetString(p, "id")))
            .ToList();

        if (packages.Count == 0)
        {
            WriteTitle("Startup applications");
            Console.WriteLine("No selected WGDot applications expose managed startup entries.");
            return 0;
        }

        var choices = new List<ChoiceItem>();
        foreach (Dictionary<string, object> package in packages)
        {
            choices.Add(new ChoiceItem
            {
                Id = GetString(package, "id"),
                Label =
                    (String.Equals(GetString(package, "startupHandler"), "glazewm", StringComparison.OrdinalIgnoreCase)
                        ? "GlazeWM + YASB"
                        : GetString(package, "name")) +
                    " [Windows login]",
                Category = "startup",
                Selected = IsStartupRegistrationEnabled(package)
            });
        }

        List<ChoiceItem> edited = ReadMultiChoice("Startup applications", choices);
        if (edited == null) return 0;

        WriteTitle("Startup applications review");
        foreach (ChoiceItem item in edited)
            Console.WriteLine((item.Selected ? "[ON]  " : "[OFF] ") + item.Label);
        Console.WriteLine();
        Console.WriteLine("WGDot only changes its own HKCU Run entries (WGDot.*).");
        Console.WriteLine("Vendor/user startup entries are left untouched.");
        Console.WriteLine();

        if (!ReadYesNo("Apply this startup selection? [y/N]", false))
        {
            Console.WriteLine("No startup changes were made.");
            return 0;
        }

        foreach (ChoiceItem item in edited)
        {
            Dictionary<string, object> package = FindPackageById(manifest, item.Id);
            if (package == null) continue;

            try
            {
                SetStartupRegistration(package, item.Selected);
                SetStartupPreference(item.Id, item.Selected);
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine(
                    "Startup change failed for " +
                    GetString(package, "name") + ": " + ex.Message);
                Console.ResetColor();
            }
        }

        return 0;
    }

    static int DisableAllManagedStartup(bool askConfirmation)
    {
        SourceContext source = ResolveDefaultSource();
        Dictionary<string, object> manifest = source.Manifest;

        WriteTitle("Disable all WGDot startup");
        Console.WriteLine("This keeps applications installed and removes only WGDot-owned startup registrations.");
        Console.WriteLine("Vendor/user startup entries are not touched.");
        Console.WriteLine();

        if (askConfirmation &&
            !ReadYesNo("Disable all WGDot-managed startup applications? [y/N]", false))
        {
            Console.WriteLine("No startup changes were made.");
            return 0;
        }

        foreach (Dictionary<string, object> package in GetStartupPackages(manifest))
        {
            SetStartupRegistration(package, false);
            SetStartupPreference(GetString(package, "id"), false);
        }

        Console.WriteLine("All WGDot-managed startup entries are disabled.");
        return 0;
    }

    static bool PackageLooksInstalled(
        Dictionary<string, object> package,
        string wingetList)
    {
        if (IsOfficialGitHubPortablePackage(package))
            return IsOfficialGitHubPortablePackageInstalled(package);

        if (IsOfficialGitHubFontArchivePackage(package))
            return IsOfficialGitHubFontArchivePackageInstalled(package);

        if (IsOfficialGitHubArchiveDriverPackage(package))
            return IsOfficialGitHubArchiveDriverPackageInstalled(package);

        string id = GetString(package, "id");
        string installedName = GetString(package, "installedName");
        if (!String.IsNullOrWhiteSpace(id) &&
            (wingetList ?? "").IndexOf(id, StringComparison.OrdinalIgnoreCase) >= 0)
            return true;
        if (!String.IsNullOrWhiteSpace(installedName) &&
            (wingetList ?? "").IndexOf(installedName, StringComparison.OrdinalIgnoreCase) >= 0)
            return true;
        return false;
    }

    static bool UninstallManagedPackage(Dictionary<string, object> package)
    {
        string name = GetString(package, "name");

        if (IsOfficialGitHubArchiveDriverPackage(package))
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine(
                name +
                " includes a kernel driver and is not removed by WGDot's generic application uninstaller.");
            Console.WriteLine("Use its upstream uninstaller/manual driver removal path.");
            Console.ResetColor();
            return false;
        }

        if (IsOfficialGitHubFontArchivePackage(package))
            return UninstallGitHubFontArchivePackage(package);

        if (IsOfficialGitHubPortablePackage(package))
        {
            string installedFile = GetPackageProgramFilePath(package, "installedFile");
            string processName = Path.GetFileNameWithoutExtension(installedFile);
            if (!String.IsNullOrWhiteSpace(processName))
                StopProcessesByName(processName);

            string root = GetPackageProgramDirectory(package);
            if (Directory.Exists(root))
                Directory.Delete(root, true);

            Console.WriteLine("Uninstalled WGDot-owned portable application: " + name);
            return true;
        }

        EnsureWingetAvailable();

        string id = GetString(package, "id");
        string installedName = GetString(package, "installedName");
        string arguments;
        if (!String.IsNullOrWhiteSpace(installedName) &&
            (IsOfficialGitHubPackage(package) || IsOfficialPagePackage(package)))
        {
            arguments =
                "uninstall --name " + Q(installedName) +
                " --exact --disable-interactivity";
        }
        else
        {
            arguments =
                "uninstall --id " + Q(id) +
                " --exact --disable-interactivity";
        }

        ProcResult result = RunInteractive("winget.exe", arguments);
        if (result.ExitCode != 0)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine(
                "Uninstall failed for " + name + " with exit " +
                result.ExitCode.ToString(CultureInfo.InvariantCulture) + ".");
            Console.ResetColor();
            return false;
        }

        Console.WriteLine("Uninstalled: " + name);
        return true;
    }

    static int SoftwareUninstallManager()
    {
        EnsureWingetAvailable();

        SourceContext source = ResolveDefaultSource();
        Dictionary<string, object> manifest = source.Manifest;
        InstallationSelection selection = ReadInstallationSelection();

        WriteTitle("Uninstall applications");
        Console.WriteLine("Reading installed package state...");
        ProcResult list = RunWithTimeout(
            "winget.exe",
            "list --accept-source-agreements --disable-interactivity",
            null,
            WingetPreflightTimeoutMs);
        if (list.TimedOut || list.ExitCode != 0)
            throw new Exception(
                "WinGet could not read installed applications: " +
                LastUsefulLine(list.StdErr + "\n" + list.StdOut));

        var packages = GetList(manifest, "packages")
            .Select(AsDictionary)
            .Where(p => PackageLooksInstalled(p, list.StdOut))
            .ToList();

        if (packages.Count == 0)
        {
            Console.WriteLine("No WGDot catalog applications are currently detected as installed.");
            return 0;
        }

        var choices = packages.Select(p => new ChoiceItem
        {
            Id = GetString(p, "id"),
            Label = GetString(p, "name") + " [" + GetString(p, "category") + "]",
            Category = GetString(p, "category"),
            Selected = false
        }).ToList();

        choices = ReadMultiChoice("Select applications to uninstall", choices);
        if (choices == null) return 0;

        List<string> ids = choices
            .Where(x => x.Selected)
            .Select(x => x.Id)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
        if (ids.Count == 0)
        {
            Console.WriteLine("No applications selected.");
            return 0;
        }

        WriteTitle("Uninstall review");
        foreach (string id in ids)
        {
            Dictionary<string, object> package = FindPackageById(manifest, id);
            if (package != null)
                Console.WriteLine("REMOVE  " + GetString(package, "name") + " (" + id + ")");
        }
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine("This removes applications. Managed dotfile backups are unaffected.");
        Console.ResetColor();
        Console.WriteLine();

        if (!ReadYesNo("Uninstall exactly these applications? [y/N]", false))
        {
            Console.WriteLine("No applications were removed.");
            return 0;
        }

        int removed = 0;
        int failed = 0;
        foreach (string id in ids)
        {
            Dictionary<string, object> package = FindPackageById(manifest, id);
            if (package == null) continue;

            try
            {
                SetStartupRegistration(package, false);
            }
            catch
            {
            }
            SetStartupPreference(id, false);

            if (UninstallManagedPackage(package))
            {
                removed++;
                if (selection != null)
                    selection.Packages.RemoveAll(
                        x => String.Equals(x, id, StringComparison.OrdinalIgnoreCase));
            }
            else
            {
                failed++;
            }
        }

        if (selection != null)
            WriteInstallationSelection(selection);

        Console.WriteLine();
        Console.WriteLine("Uninstalled: " + removed.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Failed / manual removal required: " + failed.ToString(CultureInfo.InvariantCulture));
        return failed == 0 ? 0 : 1;
    }

    static int SoftwareManager()
    {
        var items = new List<string>
        {
            "Install / reconcile selected software",
            "Startup applications",
            "Uninstall individual applications",
            "Disable all WGDot-managed startup (keep applications)",
            "Back"
        };

        while (true)
        {
            int choice = ReadSingleChoice("Software / startup manager", items, 0);
            if (choice < 0 || choice == 4) return 0;

            if (choice == 0)
            {
                SoftwareReconcile();
                Pause();
            }
            else if (choice == 1)
            {
                StartupManager();
                Pause();
            }
            else if (choice == 2)
            {
                SoftwareUninstallManager();
                Pause();
            }
            else if (choice == 3)
            {
                DisableAllManagedStartup(true);
                Pause();
            }
        }
    }

    static int SoftwareReconcile()
    {
        SourceContext source = ResolveDefaultSource();
        Dictionary<string, object> manifest = source.Manifest;
        InstallationSelection existing = ReadInstallationSelection();
        InstallationSelection selection = existing;

        if (selection == null)
        {
            selection = ConfigureInstallationSelection(manifest, null, true);
            if (selection == null) return 0;
        }
        else
        {
            int action = ReadSingleChoice(
                "Software selection",
                new List<string>
                {
                    "Reconcile current software selection",
                    "Edit software selection",
                    "Back"
                },
                0);
            if (action < 0 || action == 2) return 0;
            if (action == 1)
            {
                selection = ConfigureSoftwareSelection(manifest, existing);
                if (selection == null) return 0;
            }
        }

        int selectedCount = selection.Packages.Count;
        WriteTitle("Software reconciliation review");
        Console.WriteLine("Profile: " + selection.Scope);
        Console.WriteLine("Selected packages: " + selectedCount.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Selected setup tweaks: " + selection.Tweaks.Count.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine();
        Console.WriteLine("Only missing packages will be installed.");
        Console.WriteLine("Exact WinGet IDs are validated before install.");
        Console.WriteLine("Package installs and administrator-only setup are grouped behind one elevation request.");
        Console.WriteLine("Browser and user-level configuration returns to the normal unelevated WGDot process.");
        Console.WriteLine("No global upgrade command is used.");
        Console.WriteLine();

        if (!ReadYesNo("Install/reconcile this software selection? [y/N]", false))
        {
            Console.WriteLine("No software changes were made.");
            return 0;
        }

        EnsureWingetAvailable();

        var wanted = new HashSet<string>(selection.Packages, StringComparer.OrdinalIgnoreCase);
        var installIds = new List<string>();
        var installedExistingIds = new List<string>();
        var upgradeIds = new List<string>();
        var officialPagePending = new List<Dictionary<string, object>>();
        var portableGitHubPending = new List<Dictionary<string, object>>();
        var fontGitHubPending = new List<Dictionary<string, object>>();
        int installed = 0;
        int already = 0;
        int unavailable = 0;
        int failed = 0;
        int upgraded = 0;
        var failureDetails = new List<string>();

        Console.WriteLine();
        Console.WriteLine("Reading installed WinGet package state...");
        ProcResult installedSnapshot = RunWithTimeout(
            "winget.exe",
            "list --source winget --accept-source-agreements --disable-interactivity",
            null,
            WingetPreflightTimeoutMs);
        if (installedSnapshot.TimedOut)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("WinGet stopped responding while reading installed packages.");
            Console.WriteLine("WGDot stopped before starting the elevated install batch.");
            Console.ResetColor();
            return 1;
        }
        if (installedSnapshot.ExitCode != 0)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("WinGet could not read installed package state: " + LastUsefulLine(installedSnapshot.StdErr));
            Console.WriteLine("WGDot stopped before starting the elevated install batch.");
            Console.ResetColor();
            return 1;
        }

        foreach (object rawPackage in GetList(manifest, "packages"))
        {
            var package = AsDictionary(rawPackage);
            string id = GetString(package, "id");
            if (!wanted.Contains(id)) continue;

            Console.WriteLine();
            Console.WriteLine("Checking " + id + "...");

            if (IsOfficialGitHubPortablePackage(package))
            {
                if (IsOfficialGitHubPortablePackageInstalled(package))
                {
                    Console.WriteLine("Already installed.");
                    already++;
                }
                else
                {
                    Console.WriteLine("Official GitHub portable source selected.");
                    portableGitHubPending.Add(package);
                }
                continue;
            }

            if (IsOfficialGitHubFontArchivePackage(package))
            {
                if (IsOfficialGitHubFontArchivePackageInstalled(package))
                {
                    Console.WriteLine("Already installed.");
                    already++;
                }
                else
                {
                    Console.WriteLine("Official GitHub font archive selected.");
                    fontGitHubPending.Add(package);
                }
                continue;
            }

            if (IsOfficialGitHubArchiveDriverPackage(package))
            {
                if (IsOfficialGitHubArchiveDriverPackageInstalled(package))
                {
                    Console.WriteLine("Already installed.");
                    already++;
                }
                else
                {
                    Console.WriteLine("Official GitHub driver archive selected.");
                    installIds.Add(id);
                }
                continue;
            }

            if (IsOfficialGitHubPackage(package))
            {
                string installedName = GetString(package, "installedName");
                ProcResult githubList = RunWithTimeout(
                    "winget.exe",
                    "list --name " + Q(installedName) + " --exact --disable-interactivity",
                    null,
                    WingetPreflightTimeoutMs);

                bool githubInstalled =
                    !githubList.TimedOut &&
                    (githubList.StdOut ?? "").IndexOf(installedName, StringComparison.OrdinalIgnoreCase) >= 0;

                if (githubInstalled)
                {
                    Console.WriteLine("Already installed.");
                    already++;
                }
                else
                {
                    Console.WriteLine("Official GitHub source selected.");
                    installIds.Add(id);
                }
                continue;
            }

            if (IsOfficialPagePackage(package))
            {
                string installedName = GetString(package, "installedName");
                ProcResult manualList = RunWithTimeout(
                    "winget.exe",
                    "list --name " + Q(installedName) + " --exact --disable-interactivity",
                    null,
                    WingetPreflightTimeoutMs);

                bool manualInstalled =
                    !manualList.TimedOut &&
                    (manualList.StdOut ?? "").IndexOf(installedName, StringComparison.OrdinalIgnoreCase) >= 0;

                if (manualInstalled)
                {
                    Console.WriteLine("Already installed.");
                    already++;
                }
                else
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("WinGet cannot install this package; official download page will be offered after reconciliation.");
                    Console.ResetColor();
                    officialPagePending.Add(package);
                }
                continue;
            }

            bool isInstalled =
                (installedSnapshot.StdOut ?? "").IndexOf(id, StringComparison.OrdinalIgnoreCase) >= 0;
            if (isInstalled)
            {
                Console.WriteLine("Already installed.");
                already++;
                installedExistingIds.Add(id);
                continue;
            }

            ProcResult show = RunWithTimeout(
                "winget.exe",
                "show --id " + Q(id) + " --exact --source winget --accept-source-agreements --disable-interactivity",
                null,
                WingetPreflightTimeoutMs);
            if (show.TimedOut)
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("WinGet stopped responding while validating " + id + ".");
                Console.WriteLine("WGDot stopped before starting the elevated install batch.");
                Console.ResetColor();
                return 1;
            }
            if (show.ExitCode != 0)
            {
                string fallbackRepo = GetString(package, "fallbackGitHubRepo");
                string fallbackAssetRegex = GetString(package, "fallbackAssetRegex");
                if (!String.IsNullOrWhiteSpace(fallbackRepo) &&
                    !String.IsNullOrWhiteSpace(fallbackAssetRegex))
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("Exact WinGet ID unavailable; approved upstream fallback will be handled in the elevated batch for " + id + ".");
                    Console.ResetColor();
                    installIds.Add(id);
                    continue;
                }

                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("Unavailable by exact WinGet ID; skipped: " + id);
                Console.ResetColor();
                unavailable++;
                continue;
            }

            installIds.Add(id);
        }

        if (ReadYesNo("Check selected installed packages for upgrades now? [y/N]", false))
        {
            foreach (string id in installedExistingIds)
            {
                ProcResult upgradeCheck = RunWithTimeout(
                    "winget.exe",
                    "list --id " + Q(id) + " --exact --upgrade-available --source winget --accept-source-agreements --disable-interactivity",
                    null,
                    WingetPreflightTimeoutMs);

                if (upgradeCheck.TimedOut)
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("WinGet upgrade check timed out for " + id + "; skipping its upgrade check.");
                    Console.ResetColor();
                    continue;
                }

                bool upgradeAvailable = (upgradeCheck.StdOut ?? "").IndexOf(id, StringComparison.OrdinalIgnoreCase) >= 0;
                if (!upgradeAvailable) continue;

                if (ReadYesNo("Upgrade " + id + "? [y/N]", false))
                    upgradeIds.Add(id);
            }
        }

        List<string> adminTweakIds = selection.Tweaks
            .Where(TweakRunsInElevatedBatch)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        bool firefoxPolicyConfigured = selection.BrowserOptionsConfigured;
        List<string> firefoxInstallUrls = firefoxPolicyConfigured
            ? GetDesiredFirefoxExtensionInstallUrls(manifest, selection)
            : new List<string>();
        bool firefoxPolicyNeedsMutation = false;
        if (firefoxPolicyConfigured)
        {
            try
            {
                firefoxPolicyNeedsMutation =
                    FirefoxExtensionInstallPolicyNeedsMutation(firefoxInstallUrls);
            }
            catch (UnauthorizedAccessException)
            {
                // A policy ACL can deny the normal token even for HKCU.
                // Let the already-bounded elevated worker handle it.
                firefoxPolicyNeedsMutation = true;
            }
        }

        if (installIds.Count > 0 || upgradeIds.Count > 0 || adminTweakIds.Count > 0 || firefoxPolicyNeedsMutation)
        {
            string planPath = Path.Combine(
                StateRoot,
                "software-elevated-" + Guid.NewGuid().ToString("N") + ".json");
            string resultPath = planPath + ".result";
            var plan = new Dictionary<string, object>();
            plan["sourceRevision"] = source.Revision;
            plan["packageIds"] = installIds;
            plan["upgradeIds"] = upgradeIds;
            plan["adminTweakIds"] = adminTweakIds;
            plan["firefoxPolicyConfigured"] = firefoxPolicyConfigured;
            plan["firefoxInstallUrls"] = firefoxInstallUrls;
            WriteJson(planPath, plan);

            Dictionary<string, object> workerResult = null;
            int workerExitCode = 1;
            try
            {
                Console.WriteLine();
                if (!IsAdministrator())
                {
                    Console.ForegroundColor = ConsoleColor.Cyan;
                    Console.WriteLine("WGDot will request administrator approval once for this software batch.");
                    Console.ResetColor();
                }

                workerExitCode = IsAdministrator()
                    ? RunSoftwareElevatedPlan(planPath)
                    : RunElevatedSelfWithExitCode("software-elevated --plan " + Q(planPath));

                workerResult = ReadJson(resultPath);
                if (workerResult == null)
                    throw new Exception("WGDot elevated software worker did not return a result.");
            }
            finally
            {
                SafeDeleteFile(planPath);
                SafeDeleteFile(resultPath);
            }

            List<string> workerInstalled = GetStringList(workerResult, "installedIds");
            installed += workerInstalled.Count;
            already += GetStringList(workerResult, "alreadyIds").Count;
            unavailable += GetStringList(workerResult, "unavailableIds").Count;
            upgraded += GetStringList(workerResult, "upgradedIds").Count;

            int workerFailures =
                GetStringList(workerResult, "failedIds").Count +
                GetStringList(workerResult, "upgradeFailedIds").Count +
                GetStringList(workerResult, "adminTweakFailedIds").Count;
            if (!String.IsNullOrWhiteSpace(GetString(workerResult, "browserPolicyError")))
                workerFailures++;
            if (!String.IsNullOrWhiteSpace(GetString(workerResult, "fatalError")))
                workerFailures++;
            if (workerExitCode != 0 && workerFailures == 0)
                workerFailures++;
            failed += workerFailures;
            failureDetails.AddRange(GetStringList(workerResult, "failureDetails"));

            foreach (string id in workerInstalled)
            {
                Dictionary<string, object> package = FindPackageById(manifest, id);
                if (package != null)
                    RunPackagePostInstall(package);
            }
        }

        foreach (Dictionary<string, object> package in portableGitHubPending)
        {
            string id = GetString(package, "id");
            try
            {
                if (InstallGitHubPortablePackage(package))
                {
                    installed++;
                    RunPackagePostInstall(package);
                }
                else
                {
                    failed++;
                    failureDetails.Add("Official GitHub portable install failed: " + id);
                }
            }
            catch (Exception ex)
            {
                failed++;
                failureDetails.Add("Official GitHub portable install failed for " + id + ": " + ex.Message);
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("Portable install failed for " + id + ": " + ex.Message);
                Console.ResetColor();
            }
        }

        foreach (Dictionary<string, object> package in fontGitHubPending)
        {
            string id = GetString(package, "id");
            try
            {
                if (InstallGitHubFontArchivePackage(package))
                    installed++;
                else
                {
                    failed++;
                    failureDetails.Add("Official GitHub font archive install failed: " + id);
                }
            }
            catch (Exception ex)
            {
                failed++;
                failureDetails.Add("Official GitHub font archive install failed for " + id + ": " + ex.Message);
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("Font install failed for " + id + ": " + ex.Message);
                Console.ResetColor();
            }
        }

        try
        {
            ApplyBrowserConfiguration(manifest, selection, false);
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("Browser configuration failed: " + ex.Message);
            Console.ResetColor();
            failureDetails.Add("Browser configuration: " + ex.Message);
            failed++;
        }

        ApplySelectedInstallTweaks(manifest, selection);
        selection.Tweaks = selection.Tweaks
            .Where(id => !IsActionOnlyTweak(manifest, id))
            .ToList();
        selection.TweaksConfigured = true;
        WriteInstallationSelection(selection);
        ApplyStartupDefaultsForSelection(manifest, selection);

        if (officialPagePending.Count > 0)
        {
            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("Manual official-source applications:");
            Console.ResetColor();

            foreach (Dictionary<string, object> package in officialPagePending)
            {
                string name = GetString(package, "name");
                string url = GetString(package, "officialPageUrl");
                Console.WriteLine("  - " + name + ": WinGet installation is unavailable.");

                if (ReadYesNo("Open the official " + name + " download page now? [y/N]", false))
                {
                    var psi = new ProcessStartInfo();
                    psi.FileName = url;
                    psi.UseShellExecute = true;
                    Process.Start(psi);
                }
            }
        }

        Console.WriteLine();
        Console.WriteLine("Software reconciliation complete.");
        Console.WriteLine("Installed: " + installed.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Already installed: " + already.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Upgraded: " + upgraded.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Unavailable exact IDs: " + unavailable.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Install/setup failures: " + failed.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Manual official installs pending: " + officialPagePending.Count.ToString(CultureInfo.InvariantCulture));

        if (failureDetails.Count > 0)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine();
            Console.WriteLine("Failure details:");
            foreach (string detail in failureDetails.Distinct(StringComparer.OrdinalIgnoreCase))
                Console.WriteLine("  - " + detail);
            Console.ResetColor();
        }

        OfferGpuDriverRecommendations();

        return failed == 0 ? 0 : 1;
    }

    static bool IsContinueInstallationConfirmationKey(ConsoleKey key)
    {
        return
            key == ConsoleKey.N ||
            key == ConsoleKey.Enter ||
            key == ConsoleKey.UpArrow ||
            key == ConsoleKey.DownArrow ||
            key == ConsoleKey.PageUp ||
            key == ConsoleKey.PageDown ||
            key == ConsoleKey.Home ||
            key == ConsoleKey.End;
    }

    static bool ConfirmQuitInstallationSelection()
    {
        WriteTitle("Installation setup");
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine("Quit the installer and discard the current selection changes?");
        Console.ResetColor();
        Console.WriteLine();
        Console.WriteLine("Y: quit");
        Console.WriteLine("N/Enter: keep configuring");
        Console.WriteLine("Up/Down: keep configuring and return to the current menu");
        Console.WriteLine();

        while (true)
        {
            ConsoleKey key = Console.ReadKey(true).Key;
            if (key == ConsoleKey.Y) return true;
            if (IsContinueInstallationConfirmationKey(key)) return false;

            // Deliberately ignore repeated Q/Esc presses. The user must make
            // an explicit Y/N-style decision after reaching the quit guard.
        }
    }

    static InstallationSelection ConfigureInstallationSelection(
        Dictionary<string, object> manifest,
        InstallationSelection existing,
        bool includePackages)
    {
        int scopeIndex = existing != null &&
            String.Equals(existing.Scope, "work", StringComparison.OrdinalIgnoreCase)
            ? 1
            : 0;
        string scope = scopeIndex == 1 ? "work" : "normal";

        int glazeIndex = existing != null
            ? (String.Equals(existing.GlazeProfile, "work", StringComparison.OrdinalIgnoreCase) ? 1 : 0)
            : (scope == "work" ? 1 : 0);

        List<ChoiceItem> componentChoices = null;
        List<ChoiceItem> packageChoices = null;
        List<ChoiceItem> tweakChoices = null;
        Dictionary<string, List<string>> browserOptions = null;

        int step = 0;
        while (true)
        {
            if (step == 0)
            {
                int nextScopeIndex = ReadSingleChoice(
                    "Choose installation profile",
                    new List<string> { "Normal / personal PC", "Work PC" },
                    scopeIndex);

                if (nextScopeIndex < 0)
                {
                    if (ConfirmQuitInstallationSelection()) return null;
                    continue;
                }

                string nextScope = nextScopeIndex == 1 ? "work" : "normal";
                bool scopeChanged = !String.Equals(
                    scope,
                    nextScope,
                    StringComparison.OrdinalIgnoreCase);

                scopeIndex = nextScopeIndex;
                scope = nextScope;

                if (scopeChanged)
                {
                    componentChoices = null;
                    packageChoices = null;
                    tweakChoices = null;
                    browserOptions = null;

                    if (existing == null)
                        glazeIndex = scope == "work" ? 1 : 0;
                }

                step = 1;
                continue;
            }

            if (step == 1)
            {
                int nextGlazeIndex = ReadSingleChoice(
                    "Which GlazeWM config created by dillacorn do you want to use?",
                    new List<string> { "Normal", "Work" },
                    glazeIndex);

                if (nextGlazeIndex < 0)
                {
                    step = 0;
                    continue;
                }

                glazeIndex = nextGlazeIndex;
                step = 2;
                continue;
            }

            if (step == 2)
            {
                if (componentChoices == null)
                    componentChoices = BuildComponentChoices(manifest, scope, existing);

                List<ChoiceItem> editedComponents =
                    ReadMultiChoice("Managed components", componentChoices);
                if (editedComponents == null)
                {
                    step = 1;
                    continue;
                }

                componentChoices = editedComponents;

                if (!includePackages)
                {
                    var result = new InstallationSelection();
                    result.Scope = scope;
                    result.GlazeProfile = glazeIndex == 1 ? "work" : "normal";
                    result.Components = componentChoices
                        .Where(x => x.Selected)
                        .Select(x => x.Id)
                        .ToList();

                    if (existing != null)
                    {
                        result.Packages = new List<string>(existing.Packages);
                        result.BrowserOptions = new Dictionary<string, List<string>>(
                            existing.BrowserOptions,
                            StringComparer.OrdinalIgnoreCase);
                        result.BrowserOptionsConfigured = existing.BrowserOptionsConfigured;
                        result.Tweaks = existing.TweaksConfigured
                            ? new List<string>(existing.Tweaks)
                            : GetDefaultTweakIds(manifest, scope);
                    }
                    else
                    {
                        foreach (ChoiceItem item in BuildPackageChoices(manifest, scope, null))
                            if (item.Selected) result.Packages.Add(item.Id);
                        result.BrowserOptions = BuildBrowserOptionSelection(manifest, scope, null);
                        result.BrowserOptionsConfigured = false;
                        result.Tweaks = GetDefaultTweakIds(manifest, scope);
                    }

                    result.TweaksConfigured = true;
                    return result;
                }

                step = 3;
                continue;
            }

            if (step == 3)
            {
                if (browserOptions == null)
                    browserOptions = BuildBrowserOptionSelection(manifest, scope, existing);
                if (packageChoices == null)
                    packageChoices = BuildPackageChoices(manifest, scope, existing);

                List<ChoiceItem> editedPackages = ReadPackageChoicesByCategory(
                    "Software to install / reconcile",
                    packageChoices,
                    manifest,
                    scope,
                    browserOptions);

                if (editedPackages == null)
                {
                    step = 2;
                    continue;
                }

                packageChoices = editedPackages;
                step = 4;
                continue;
            }

            if (step == 4)
            {
                if (tweakChoices == null)
                    tweakChoices = BuildTweakChoices(manifest, scope, existing, true);

                List<ChoiceItem> editedTweaks =
                    ReadMultiChoice("Windows tweaks / integrations", tweakChoices);
                if (editedTweaks == null)
                {
                    step = 3;
                    continue;
                }

                tweakChoices = editedTweaks;

                var result = new InstallationSelection();
                result.Scope = scope;
                result.GlazeProfile = glazeIndex == 1 ? "work" : "normal";
                result.Components = componentChoices
                    .Where(x => x.Selected)
                    .Select(x => x.Id)
                    .ToList();
                result.Packages = packageChoices
                    .Where(x => x.Selected)
                    .Select(x => x.Id)
                    .ToList();
                result.BrowserOptions = browserOptions;
                result.BrowserOptionsConfigured = true;
                result.Tweaks = tweakChoices
                    .Where(x => x.Selected)
                    .Select(x => x.Id)
                    .ToList();
                result.TweaksConfigured = true;
                return result;
            }

            throw new Exception("Unknown installation selection step.");
        }
    }

    static InstallationSelection ConfigureSoftwareSelection(
        Dictionary<string, object> manifest,
        InstallationSelection existing)
    {
        var result = new InstallationSelection();
        result.Scope = existing.Scope;
        result.GlazeProfile = existing.GlazeProfile;
        result.Components = new List<string>(existing.Components);
        result.Tweaks = existing.TweaksConfigured
            ? new List<string>(existing.Tweaks)
            : GetDefaultTweakIds(manifest, existing.Scope);
        result.TweaksConfigured = true;

        var browserOptions = BuildBrowserOptionSelection(manifest, existing.Scope, existing);
        var choices = BuildPackageChoices(manifest, existing.Scope, existing);

        while (true)
        {
            List<ChoiceItem> edited = ReadPackageChoicesByCategory(
                "Software to install / reconcile",
                choices,
                manifest,
                existing.Scope,
                browserOptions);

            if (edited != null)
            {
                choices = edited;
                result.Packages = choices
                    .Where(x => x.Selected)
                    .Select(x => x.Id)
                    .ToList();
                result.BrowserOptions = browserOptions;
                result.BrowserOptionsConfigured = true;
                return result;
            }

            if (ConfirmQuitInstallationSelection())
                return null;

            // N/Enter/arrow input at the quit guard means the user wants to
            // continue editing. Reopen the same selection with all changes kept.
        }
    }

    static List<ChoiceItem> BuildComponentChoices(
        Dictionary<string, object> manifest,
        string scope,
        InstallationSelection existing)
    {
        var existingSet = existing == null
            ? null
            : new HashSet<string>(existing.Components, StringComparer.OrdinalIgnoreCase);

        var choices = new List<ChoiceItem>();
        foreach (object raw in GetList(manifest, "components"))
        {
            var component = AsDictionary(raw);
            string id = GetString(component, "id");
            bool selected = existingSet != null
                ? existingSet.Contains(id)
                : (scope == "work" ? GetBool(component, "defaultWork") : GetBool(component, "defaultNormal"));

            choices.Add(new ChoiceItem
            {
                Id = id,
                Label = GetString(component, "name"),
                Selected = selected
            });
        }
        return choices;
    }

    static List<ChoiceItem> BuildPackageChoices(
        Dictionary<string, object> manifest,
        string scope,
        InstallationSelection existing)
    {
        var existingSet = existing == null
            ? null
            : new HashSet<string>(existing.Packages, StringComparer.OrdinalIgnoreCase);

        var choices = new List<ChoiceItem>();
        foreach (object raw in GetList(manifest, "packages"))
        {
            var package = AsDictionary(raw);
            string id = GetString(package, "id");
            bool selected = existingSet != null
                ? existingSet.Contains(id)
                : (scope == "work" ? GetBool(package, "defaultWork") : GetBool(package, "defaultNormal"));

            string category = GetString(package, "category");
            string name = GetString(package, "name");
            choices.Add(new ChoiceItem
            {
                Id = id,
                Label = name,
                Category = category,
                Selected = selected
            });
        }
        return choices;
    }

    static InstallationSelection ReadInstallationSelection()
    {
        var state = ReadJson(InstallStatePath);
        if (state == null) return null;

        var result = new InstallationSelection();
        result.Scope = GetString(state, "scope");
        result.GlazeProfile = GetString(state, "glazewmProfile");
        result.Components = GetStringList(state, "components");
        result.Packages = GetStringList(state, "packages");
        result.Tweaks = GetStringList(state, "tweaks");
        // One-time selection migration from retired launcher/audio integrations.
        // Flow Launcher is no longer part of the WGDot software catalog; preserve an
        // existing installation, but stop carrying its package/tweak selections forward.
        result.Packages.RemoveAll(x => String.Equals(x, "Flow-Launcher.Flow-Launcher", StringComparison.OrdinalIgnoreCase));
        result.Tweaks.RemoveAll(x => String.Equals(x, "flow-launcher-alt-p", StringComparison.OrdinalIgnoreCase));
        result.Tweaks.RemoveAll(x =>
            String.Equals(x, "eartrumpet-mixer-alt-v", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(x, "eartrumpet-mixer-super-v", StringComparison.OrdinalIgnoreCase));
        result.TweaksConfigured = state.ContainsKey("tweaks");
        result.BrowserOptions = ReadBrowserOptionsState(state);
        result.BrowserOptionsConfigured = state.ContainsKey("browserOptions");

        if (String.IsNullOrWhiteSpace(result.Scope) ||
            String.IsNullOrWhiteSpace(result.GlazeProfile) ||
            result.Components.Count == 0)
            return null;

        return result;
    }

    static void WriteInstallationSelection(InstallationSelection selection)
    {
        var state = new Dictionary<string, object>();
        state["scope"] = selection.Scope;
        state["glazewmProfile"] = selection.GlazeProfile;
        state["components"] = selection.Components.ToArray();
        state["packages"] = selection.Packages.ToArray();
        state["tweaks"] = selection.Tweaks.ToArray();
        if (selection.BrowserOptionsConfigured)
        {
            var browserOptions = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            foreach (KeyValuePair<string, List<string>> pair in selection.BrowserOptions)
                browserOptions[pair.Key] = pair.Value.ToArray();
            state["browserOptions"] = browserOptions;
        }
        state["configuredAt"] = DateTime.UtcNow.ToString("o");
        WriteJson(InstallStatePath, state);
    }


    static Dictionary<string, List<string>> ReadBrowserOptionsState(Dictionary<string, object> state)
    {
        var result = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
        if (state == null || !state.ContainsKey("browserOptions")) return result;

        Dictionary<string, object> map = GetDictionary(state, "browserOptions");
        foreach (KeyValuePair<string, object> pair in map)
        {
            var wrapper = new Dictionary<string, object>();
            wrapper["items"] = pair.Value;
            result[pair.Key] = GetStringList(wrapper, "items");
        }
        return result;
    }

    static Dictionary<string, object> GetBrowserDefinition(
        Dictionary<string, object> manifest,
        string packageId)
    {
        foreach (object raw in GetList(manifest, "browserOptions"))
        {
            var browser = AsDictionary(raw);
            if (String.Equals(GetString(browser, "packageId"), packageId, StringComparison.OrdinalIgnoreCase))
                return browser;
        }
        return null;
    }

    static Dictionary<string, List<string>> BuildBrowserOptionSelection(
        Dictionary<string, object> manifest,
        string scope,
        InstallationSelection existing)
    {
        var result = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
        if (existing != null && existing.BrowserOptionsConfigured)
        {
            foreach (KeyValuePair<string, List<string>> pair in existing.BrowserOptions)
                result[pair.Key] = new List<string>(pair.Value);
        }

        foreach (object rawBrowser in GetList(manifest, "browserOptions"))
        {
            var browser = AsDictionary(rawBrowser);
            string packageId = GetString(browser, "packageId");
            if (String.IsNullOrWhiteSpace(packageId) || result.ContainsKey(packageId)) continue;

            var defaults = new List<string>();
            foreach (object rawOption in GetList(browser, "options"))
            {
                var option = AsDictionary(rawOption);
                bool selected = scope == "work"
                    ? GetBool(option, "defaultWork")
                    : GetBool(option, "defaultNormal");
                if (selected) defaults.Add(GetString(option, "id"));
            }
            result[packageId] = defaults;
        }

        return result;
    }

    static List<ChoiceItem> BuildTweakChoices(
        Dictionary<string, object> manifest,
        string scope,
        InstallationSelection existing,
        bool includeActionOnly)
    {
        var existingSet = existing != null && existing.TweaksConfigured
            ? new HashSet<string>(existing.Tweaks, StringComparer.OrdinalIgnoreCase)
            : null;

        var choices = new List<ChoiceItem>();
        foreach (object raw in GetList(manifest, "tweaks"))
        {
            var tweak = AsDictionary(raw);
            string id = GetString(tweak, "id");
            bool actionOnly = GetBool(tweak, "actionOnly");
            if (actionOnly && !includeActionOnly) continue;

            bool selected = actionOnly
                ? false
                : (existingSet != null
                    ? existingSet.Contains(id)
                    : (scope == "work" ? GetBool(tweak, "defaultWork") : GetBool(tweak, "defaultNormal")));

            choices.Add(new ChoiceItem
            {
                Id = id,
                Label = GetString(tweak, "name") + " [" + GetString(tweak, "category") + "]",
                Selected = selected
            });
        }
        return choices;
    }

    static List<string> GetDefaultTweakIds(Dictionary<string, object> manifest, string scope)
    {
        var result = new List<string>();
        foreach (object raw in GetList(manifest, "tweaks"))
        {
            var tweak = AsDictionary(raw);
            if (GetBool(tweak, "actionOnly")) continue;
            bool selected = scope == "work" ? GetBool(tweak, "defaultWork") : GetBool(tweak, "defaultNormal");
            if (selected) result.Add(GetString(tweak, "id"));
        }
        return result;
    }

    static bool IsActionOnlyTweak(Dictionary<string, object> manifest, string id)
    {
        foreach (object raw in GetList(manifest, "tweaks"))
        {
            var tweak = AsDictionary(raw);
            if (String.Equals(GetString(tweak, "id"), id, StringComparison.OrdinalIgnoreCase))
                return GetBool(tweak, "actionOnly");
        }
        return false;
    }


    static bool IsSafeMode()
    {
        return !String.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("SAFEBOOT_OPTION"));
    }

    static bool HasPendingGpuSafeModeCleanup()
    {
        var state = ReadJson(GpuStatePath);
        return state != null &&
            String.Equals(GetString(state, "phase"), "safe-mode-pending", StringComparison.OrdinalIgnoreCase);
    }

    static string GpuVendorLabel(string vendor)
    {
        if (String.Equals(vendor, "amd", StringComparison.OrdinalIgnoreCase)) return "AMD";
        if (String.Equals(vendor, "nvidia", StringComparison.OrdinalIgnoreCase)) return "NVIDIA";
        if (String.Equals(vendor, "intel", StringComparison.OrdinalIgnoreCase)) return "Intel";
        return String.IsNullOrWhiteSpace(vendor) ? "Unknown" : vendor;
    }

    static bool IsKnownGpuVendor(string vendor)
    {
        return
            String.Equals(vendor, "amd", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(vendor, "nvidia", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(vendor, "intel", StringComparison.OrdinalIgnoreCase);
    }

    static string ClassifyGpuHardwareVendor(string hardwareId)
    {
        string value = (hardwareId ?? "").ToUpperInvariant();
        if (value.Contains("VEN_1002")) return "amd";
        if (value.Contains("VEN_10DE")) return "nvidia";
        if (value.Contains("VEN_8086")) return "intel";
        return "";
    }

    static string ClassifyGpuDriverProvider(string provider)
    {
        string value = provider ?? "";
        if (value.IndexOf("NVIDIA", StringComparison.OrdinalIgnoreCase) >= 0) return "nvidia";
        if (value.IndexOf("Advanced Micro Devices", StringComparison.OrdinalIgnoreCase) >= 0 ||
            Regex.IsMatch(value, @"(^|\W)AMD(\W|$)", RegexOptions.IgnoreCase))
            return "amd";
        if (value.IndexOf("Intel", StringComparison.OrdinalIgnoreCase) >= 0) return "intel";
        if (value.IndexOf("Microsoft", StringComparison.OrdinalIgnoreCase) >= 0) return "microsoft";
        return "";
    }

    static string ReadSetupDeviceProperty(
        IntPtr deviceInfoSet,
        ref SP_DEVINFO_DATA deviceInfo,
        uint property)
    {
        byte[] buffer = new byte[8192];
        uint regType;
        uint required;
        if (!SetupDiGetDeviceRegistryProperty(
                deviceInfoSet,
                ref deviceInfo,
                property,
                out regType,
                buffer,
                (uint)buffer.Length,
                out required))
            return "";

        int length = (int)Math.Min((uint)buffer.Length, required);
        if (length <= 0) return "";
        string value = Encoding.Unicode.GetString(buffer, 0, length).TrimEnd('\0');
        int separator = value.IndexOf('\0');
        if (separator >= 0) value = value.Substring(0, separator);
        return value.Trim();
    }

    static List<GpuAdapterInfo> DetectGpuAdapters()
    {
        var result = new List<GpuAdapterInfo>();
        Guid displayClass = new Guid("4d36e968-e325-11ce-bfc1-08002be10318");
        IntPtr set = SetupDiGetClassDevs(ref displayClass, null, IntPtr.Zero, DigcfPresent);
        if (set == InvalidHandleValue) return result;

        try
        {
            for (uint index = 0; ; index++)
            {
                var info = new SP_DEVINFO_DATA();
                info.cbSize = Marshal.SizeOf(typeof(SP_DEVINFO_DATA));
                if (!SetupDiEnumDeviceInfo(set, index, ref info))
                    break;

                string hardwareId = ReadSetupDeviceProperty(set, ref info, SpdrpHardwareId);
                string vendor = ClassifyGpuHardwareVendor(hardwareId);
                string name = ReadSetupDeviceProperty(set, ref info, SpdrpFriendlyName);
                if (String.IsNullOrWhiteSpace(name))
                    name = ReadSetupDeviceProperty(set, ref info, SpdrpDeviceDesc);

                string manufacturer = ReadSetupDeviceProperty(set, ref info, SpdrpMfg);
                string driverKey = ReadSetupDeviceProperty(set, ref info, SpdrpDriver);
                string provider = "";
                string version = "";
                string driverDesc = "";

                if (!String.IsNullOrWhiteSpace(driverKey))
                {
                    using (RegistryKey key = Registry.LocalMachine.OpenSubKey(
                        @"SYSTEM\CurrentControlSet\Control\Class\" + driverKey,
                        false))
                    {
                        if (key != null)
                        {
                            provider = Convert.ToString(key.GetValue("ProviderName", ""));
                            version = Convert.ToString(key.GetValue("DriverVersion", ""));
                            driverDesc = Convert.ToString(key.GetValue("DriverDesc", ""));
                        }
                    }
                }

                if (String.IsNullOrWhiteSpace(name)) name = driverDesc;
                if (String.IsNullOrWhiteSpace(name)) name = "(unnamed display adapter)";

                result.Add(new GpuAdapterInfo
                {
                    Vendor = vendor,
                    Name = name,
                    HardwareId = hardwareId,
                    Manufacturer = manufacturer,
                    DriverProvider = provider,
                    DriverVendor = ClassifyGpuDriverProvider(provider),
                    DriverVersion = version,
                    DriverKey = driverKey
                });
            }
        }
        finally
        {
            SetupDiDestroyDeviceInfoList(set);
        }

        return result;
    }

    static HashSet<string> GetPhysicalGpuVendors(List<GpuAdapterInfo> adapters)
    {
        return new HashSet<string>(
            adapters
                .Where(x => IsKnownGpuVendor(x.Vendor))
                .Select(x => x.Vendor),
            StringComparer.OrdinalIgnoreCase);
    }

    static HashSet<string> GetInstalledDisplayDriverPackageVendors()
    {
        var vendors = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        ProcResult result = Run("pnputil.exe", "/enum-drivers /class Display", null);
        if (result.ExitCode != 0) return vendors;

        string text = result.StdOut ?? "";
        if (text.IndexOf("NVIDIA", StringComparison.OrdinalIgnoreCase) >= 0)
            vendors.Add("nvidia");
        if (text.IndexOf("Advanced Micro Devices", StringComparison.OrdinalIgnoreCase) >= 0)
            vendors.Add("amd");
        if (text.IndexOf("Intel Corporation", StringComparison.OrdinalIgnoreCase) >= 0 ||
            text.IndexOf("Intel(R) Corporation", StringComparison.OrdinalIgnoreCase) >= 0)
            vendors.Add("intel");
        return vendors;
    }

    static HashSet<string> GetGpuCleanupCandidates(List<GpuAdapterInfo> adapters)
    {
        HashSet<string> physical = GetPhysicalGpuVendors(adapters);
        HashSet<string> installed = GetInstalledDisplayDriverPackageVendors();
        var result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (string vendor in installed)
            if (!physical.Contains(vendor))
                result.Add(vendor);

        foreach (GpuAdapterInfo adapter in adapters)
        {
            if (!IsKnownGpuVendor(adapter.Vendor)) continue;
            if (!IsKnownGpuVendor(adapter.DriverVendor)) continue;
            if (!String.Equals(adapter.Vendor, adapter.DriverVendor, StringComparison.OrdinalIgnoreCase))
                result.Add(adapter.DriverVendor);
        }

        return result;
    }

    static bool IsGpuVendorDriverHealthy(string vendor, List<GpuAdapterInfo> adapters)
    {
        return adapters.Any(x =>
            String.Equals(x.Vendor, vendor, StringComparison.OrdinalIgnoreCase) &&
            String.Equals(x.DriverVendor, vendor, StringComparison.OrdinalIgnoreCase));
    }

    static void PrintGpuStatus(List<GpuAdapterInfo> adapters)
    {
        if (adapters.Count == 0)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("No present display adapters were returned by Windows SetupAPI.");
            Console.ResetColor();
            return;
        }

        foreach (GpuAdapterInfo adapter in adapters)
        {
            string hardwareVendor = IsKnownGpuVendor(adapter.Vendor)
                ? GpuVendorLabel(adapter.Vendor)
                : "Other/virtual";
            string driver = String.IsNullOrWhiteSpace(adapter.DriverProvider)
                ? "(no provider reported)"
                : adapter.DriverProvider;

            Console.WriteLine(adapter.Name);
            Console.WriteLine("  Hardware vendor: " + hardwareVendor);
            Console.WriteLine("  Driver provider: " + driver);
            if (!String.IsNullOrWhiteSpace(adapter.DriverVersion))
                Console.WriteLine("  Driver version:  " + adapter.DriverVersion);

            if (IsKnownGpuVendor(adapter.Vendor) &&
                String.Equals(adapter.DriverVendor, adapter.Vendor, StringComparison.OrdinalIgnoreCase))
            {
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("  Status: vendor driver detected");
                Console.ResetColor();
            }
            else if (IsKnownGpuVendor(adapter.Vendor) &&
                     String.Equals(adapter.DriverVendor, "microsoft", StringComparison.OrdinalIgnoreCase))
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("  Status: Microsoft/basic driver; vendor driver recommended");
                Console.ResetColor();
            }
            else if (IsKnownGpuVendor(adapter.Vendor) &&
                     IsKnownGpuVendor(adapter.DriverVendor) &&
                     !String.Equals(adapter.DriverVendor, adapter.Vendor, StringComparison.OrdinalIgnoreCase))
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("  Status: driver vendor does not match detected hardware");
                Console.ResetColor();
            }
            else if (IsKnownGpuVendor(adapter.Vendor))
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("  Status: matching vendor driver was not confirmed");
                Console.ResetColor();
            }

            Console.WriteLine();
        }

        HashSet<string> cleanup = GetGpuCleanupCandidates(adapters);
        if (cleanup.Count > 0)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine(
                "Possible stale/mismatched display-driver vendor packages: " +
                String.Join(", ", cleanup.Select(GpuVendorLabel).ToArray()));
            Console.ResetColor();
            Console.WriteLine();
        }
    }

    static string SelectGpuVendor(IEnumerable<string> vendors, string title)
    {
        List<string> ids = vendors
            .Where(IsKnownGpuVendor)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(GpuVendorLabel)
            .ToList();

        if (ids.Count == 0) return "";
        if (ids.Count == 1) return ids[0];

        var labels = ids.Select(GpuVendorLabel).ToList();
        labels.Add("Back");
        int choice = ReadSingleChoice(title, labels, 0);
        if (choice < 0 || choice >= ids.Count) return "";
        return ids[choice];
    }

    static int GpuDriverMaintenance()
    {
        while (true)
        {
            List<GpuAdapterInfo> adapters = DetectGpuAdapters();

            WriteTitle("GPU driver maintenance");
            PrintGpuStatus(adapters);
            Console.WriteLine("DDU cleanup is never automatic. Safe Mode/reboot changes require explicit approval.");
            Console.WriteLine();
            Pause();

            HashSet<string> physical = GetPhysicalGpuVendors(adapters);
            HashSet<string> cleanup = GetGpuCleanupCandidates(adapters);

            var actions = new List<string>
            {
                "Run official auto-detect / driver assistant for detected GPU(s)",
                "Clean reinstall / refresh detected GPU driver with DDU (Safe Mode)"
            };
            bool hasCleanup = cleanup.Count > 0;
            if (hasCleanup)
                actions.Add("Clean stale / mismatched vendor driver with DDU (Safe Mode)");
            actions.Add("Refresh status");
            actions.Add("Back");

            int action = ReadSingleChoice("GPU driver maintenance", actions, 0);
            if (action < 0 || action == actions.Count - 1) return 0;

            if (action == 0)
            {
                if (physical.Count == 0)
                {
                    WriteTitle("GPU driver maintenance");
                    Console.WriteLine("No AMD, NVIDIA, or Intel display adapter was detected.");
                    Pause();
                    continue;
                }

                foreach (string vendor in physical.OrderBy(GpuVendorLabel))
                {
                    InstallGpuVendorDriver(vendor);
                    Console.WriteLine();
                }
                Pause();
            }
            else if (action == 1)
            {
                string vendor = SelectGpuVendor(physical, "Select GPU driver to clean/reinstall");
                if (String.IsNullOrWhiteSpace(vendor))
                {
                    WriteTitle("GPU driver maintenance");
                    Console.WriteLine("No AMD, NVIDIA, or Intel display adapter was detected.");
                    Pause();
                    continue;
                }
                ScheduleGpuDduCleanup(vendor, "refresh");
                return 0;
            }
            else if (hasCleanup && action == 2)
            {
                string vendor = SelectGpuVendor(cleanup, "Select stale/mismatched driver vendor to clean");
                if (!String.IsNullOrWhiteSpace(vendor))
                {
                    ScheduleGpuDduCleanup(vendor, "mismatch");
                    return 0;
                }
            }
        }
    }

    static void OfferGpuDriverRecommendations()
    {
        List<GpuAdapterInfo> adapters = DetectGpuAdapters();
        HashSet<string> physical = GetPhysicalGpuVendors(adapters);
        if (physical.Count == 0) return;

        var missing = physical
            .Where(vendor => !IsGpuVendorDriverHealthy(vendor, adapters))
            .ToList();

        HashSet<string> cleanup = GetGpuCleanupCandidates(adapters);
        if (missing.Count == 0 && cleanup.Count == 0) return;

        WriteTitle("GPU driver check");
        PrintGpuStatus(adapters);

        foreach (string vendor in missing.OrderBy(GpuVendorLabel))
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine(
                GpuVendorLabel(vendor) +
                " hardware is present but a matching active vendor display driver was not confirmed.");
            Console.WriteLine(
                "Launching the official vendor auto-detect / driver assistant automatically.");
            Console.ResetColor();

            InstallGpuVendorDriver(vendor);
            Console.WriteLine();
        }

        if (cleanup.Count > 0)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("WGDot detected possible stale or mismatched GPU-vendor driver packages.");
            Console.WriteLine("Use GPU driver maintenance for the guarded Safe Mode + DDU cleanup workflow.");
            Console.ResetColor();
        }
    }

    static bool ShowGpuPendingNotice()
    {
        var state = ReadJson(GpuStatePath);
        if (state == null) return false;

        string vendor = GetString(state, "targetVendor");
        string phase = GetString(state, "phase");
        if (!IsKnownGpuVendor(vendor)) return false;

        List<GpuAdapterInfo> adapters = DetectGpuAdapters();
        if (IsGpuVendorDriverHealthy(vendor, adapters))
        {
            SafeDeleteFile(GpuStatePath);
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine(
                "WGDot GPU maintenance complete: a matching " +
                GpuVendorLabel(vendor) + " display driver is active.");
            Console.ResetColor();
            return true;
        }

        if (String.Equals(phase, "driver-needed", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(phase, "driver-install-pending", StringComparison.OrdinalIgnoreCase))
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("GPU DRIVER ACTION REQUIRED");
            Console.ResetColor();
            Console.WriteLine(
                "The " + GpuVendorLabel(vendor) +
                " cleanup/reinstall workflow is not finished.");
            Console.WriteLine(
                "A matching " + GpuVendorLabel(vendor) +
                " display driver is not currently detected.");
            Console.WriteLine("Open GPU driver maintenance and install the recommended vendor driver.");
            return true;
        }

        if (String.Equals(phase, "safe-mode-pending", StringComparison.OrdinalIgnoreCase))
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("GPU driver cleanup is staged for " + GpuVendorLabel(vendor) + ".");
            Console.ResetColor();
            return true;
        }

        return false;
    }

    static string DownloadVendorPageText(string page)
    {
        if (ExecutableExists("curl.exe"))
        {
            ProcResult curl = RunWithTimeout(
                "curl.exe",
                "-fL --retry 2 --connect-timeout 15 --max-time 45 " +
                "-A " + Q("Mozilla/5.0 WGDot") + " " + Q(page),
                null,
                50000);
            if (!curl.TimedOut && curl.ExitCode == 0 && !String.IsNullOrWhiteSpace(curl.StdOut))
                return curl.StdOut;
        }

        using (var client = new WebClient())
        {
            client.Headers[HttpRequestHeader.UserAgent] = "Mozilla/5.0 WGDot";
            client.Headers[HttpRequestHeader.Accept] = "text/html,application/xhtml+xml";
            return client.DownloadString(page);
        }
    }

    static string ResolveOfficialGpuInstallerUrl(string vendor)
    {
        if (String.Equals(vendor, "intel", StringComparison.OrdinalIgnoreCase))
            return "https://dsadata.intel.com/installer";

        string pattern;
        string[] pages;
        if (String.Equals(vendor, "amd", StringComparison.OrdinalIgnoreCase))
        {
            // AMD's current support page exposes one vendor auto-detect web
            // installer for supported Radeon/Ryzen hardware. Keep a second
            // official product-family page as a resolver fallback because AMD
            // periodically changes the generic page markup.
            pages = new[]
            {
                "https://www.amd.com/en/support/download/drivers.html",
                "https://www.amd.com/en/support/downloads/drivers.html/graphics/radeon-rx/radeon-rx-7000-series.html"
            };
            pattern =
                @"https://drivers\.amd\.com/[^""'<>\s]+(?:minimalsetup|installer)[^""'<>\s]*_web\.exe";
        }
        else if (String.Equals(vendor, "nvidia", StringComparison.OrdinalIgnoreCase))
        {
            pages = new[] { "https://www.nvidia.com/en-us/software/nvidia-app/" };
            pattern = @"https://us\.download\.nvidia\.com/nvapp/client/[^""'<>\s]+\.exe";
        }
        else
        {
            throw new Exception("Unsupported GPU vendor: " + vendor);
        }

        foreach (string page in pages)
        {
            try
            {
                string html = DownloadVendorPageText(page);
                // AMD/NVIDIA periodically emit download URLs through JSON/script
                // blobs with escaped slashes rather than literal href values.
                // Normalize both forms before matching the vendor-owned host.
                html = WebUtility.HtmlDecode(html ?? "");
                html = html
                    .Replace(@"\/", "/")
                    .Replace(@"\u002F", "/")
                    .Replace(@"\u002f", "/");

                Match match = Regex.Match(html, pattern, RegexOptions.IgnoreCase);
                if (match.Success)
                    return match.Value;
            }
            catch
            {
            }
        }

        throw new Exception(
            "Could not resolve the current official " +
            GpuVendorLabel(vendor) + " installer URL.");
    }

    static void ValidateOfficialGpuInstallerUrl(string vendor, string url)
    {
        Uri uri;
        if (!Uri.TryCreate(url, UriKind.Absolute, out uri) ||
            !String.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
            throw new Exception("GPU installer URL is not valid HTTPS.");

        string host = uri.Host;
        bool valid =
            (String.Equals(vendor, "amd", StringComparison.OrdinalIgnoreCase) &&
             String.Equals(host, "drivers.amd.com", StringComparison.OrdinalIgnoreCase)) ||
            (String.Equals(vendor, "nvidia", StringComparison.OrdinalIgnoreCase) &&
             String.Equals(host, "us.download.nvidia.com", StringComparison.OrdinalIgnoreCase)) ||
            (String.Equals(vendor, "intel", StringComparison.OrdinalIgnoreCase) &&
             String.Equals(host, "dsadata.intel.com", StringComparison.OrdinalIgnoreCase));

        if (!valid)
            throw new Exception("Refusing unexpected " + GpuVendorLabel(vendor) + " installer host: " + host);
    }

    static int InstallGpuVendorDriver(string vendor)
    {
        if (!IsKnownGpuVendor(vendor))
            throw new Exception("Unknown GPU vendor: " + vendor);

        WriteTitle(GpuVendorLabel(vendor) + " driver installer");
        Console.WriteLine("Resolving official vendor installer...");
        string url = ResolveOfficialGpuInstallerUrl(vendor);
        ValidateOfficialGpuInstallerUrl(vendor, url);

        string gpuCache = Path.Combine(CacheRoot, "gpu");
        Directory.CreateDirectory(gpuCache);
        string installer = Path.Combine(
            gpuCache,
            vendor + "-driver-installer.exe");
        SafeDeleteFile(installer);

        Console.WriteLine("Downloading from " + new Uri(url).Host + "...");
        bool downloaded = false;
        if (ExecutableExists("curl.exe"))
        {
            string referer = String.Equals(vendor, "amd", StringComparison.OrdinalIgnoreCase)
                ? "https://www.amd.com/en/support/download/drivers.html"
                : String.Equals(vendor, "nvidia", StringComparison.OrdinalIgnoreCase)
                    ? "https://www.nvidia.com/en-us/software/nvidia-app/"
                    : "";

            string curlArgs =
                "-fL --retry 2 --connect-timeout 15 --max-time 300 " +
                "-A " + Q("Mozilla/5.0 WGDot") + " ";
            if (!String.IsNullOrWhiteSpace(referer))
                curlArgs += "-e " + Q(referer) + " ";
            curlArgs += Q(url) + " -o " + Q(installer);

            ProcResult curl = RunWithTimeout(
                "curl.exe",
                curlArgs,
                null,
                310000);
            downloaded = !curl.TimedOut && curl.ExitCode == 0 && File.Exists(installer);
        }

        if (!downloaded)
        {
            using (var client = new WebClient())
            {
                client.Headers[HttpRequestHeader.UserAgent] = "Mozilla/5.0 WGDot";
                if (String.Equals(vendor, "amd", StringComparison.OrdinalIgnoreCase))
                    client.Headers[HttpRequestHeader.Referer] = "https://www.amd.com/en/support/download/drivers.html";
                client.DownloadFile(url, installer);
            }
        }

        if (!File.Exists(installer) || new FileInfo(installer).Length < 100000)
            throw new Exception("Downloaded GPU installer is unexpectedly small or missing.");

        if (!IsWindowsExecutableFile(installer))
        {
            SafeDeleteFile(installer);

            throw new Exception(
                "Official " + GpuVendorLabel(vendor) +
                " download did not produce a valid Windows executable. " +
                "No third-party fallback was used.");
        }

        var state = ReadJson(GpuStatePath) ?? new Dictionary<string, object>();
        state["phase"] = "driver-install-pending";
        state["targetVendor"] = vendor;
        state["installerUrl"] = url;
        state["installerLaunchedAt"] = DateTime.UtcNow.ToString("o");
        WriteJson(GpuStatePath, state);

        Console.WriteLine("Starting official " + GpuVendorLabel(vendor) + " installer...");
        Console.WriteLine();

        if (String.Equals(vendor, "amd", StringComparison.OrdinalIgnoreCase))
            Console.WriteLine("AMD Auto-Detect will identify the compatible Radeon driver for this PC.");
        else if (String.Equals(vendor, "nvidia", StringComparison.OrdinalIgnoreCase))
            Console.WriteLine("NVIDIA App will identify and install the appropriate Game Ready/Studio driver.");
        else
            Console.WriteLine("Intel Driver & Support Assistant will identify the compatible Intel graphics driver.");

        var psi = new ProcessStartInfo();
        psi.FileName = installer;
        psi.UseShellExecute = true;
        using (Process process = Process.Start(psi))
        {
            if (process != null)
                process.WaitForExit();
        }

        Console.WriteLine();
        Console.WriteLine("WGDot will verify the active display driver on the next run.");
        return 0;
    }

    static int GpuInstallFromArgs(string[] args)
    {
        string vendor = GetOption(args, "--vendor");
        return InstallGpuVendorDriver(vendor);
    }

    static string FindDduExe()
    {
        using (RegistryKey key = Registry.LocalMachine.OpenSubKey(
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Display Driver Uninstaller.exe",
            false))
        {
            if (key != null)
            {
                string path = Convert.ToString(key.GetValue("", ""));
                if (!String.IsNullOrWhiteSpace(path) && File.Exists(path))
                    return path;
            }
        }

        string candidate = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            "Display Driver Uninstaller",
            "Display Driver Uninstaller.exe");
        if (File.Exists(candidate)) return candidate;
        return "";
    }

    static string EnsureDduInstalled()
    {
        string exe = FindDduExe();
        if (!String.IsNullOrWhiteSpace(exe)) return exe;

        EnsureWingetAvailable();
        Console.WriteLine("Installing Display Driver Uninstaller from its exact WinGet package...");
        ProcResult install = RunInteractive(
            "winget.exe",
            "install --id Wagnardsoft.DisplayDriverUninstaller --exact --source winget --accept-source-agreements --accept-package-agreements");

        if (install.ExitCode != 0)
            throw new Exception(
                "Display Driver Uninstaller installation failed with exit " +
                install.ExitCode.ToString(CultureInfo.InvariantCulture) + ".");

        exe = FindDduExe();
        if (String.IsNullOrWhiteSpace(exe))
            throw new Exception("DDU installed, but Display Driver Uninstaller.exe could not be located.");
        return exe;
    }

    static void ScheduleGpuDduCleanup(string vendor, string reason)
    {
        if (!IsKnownGpuVendor(vendor))
            throw new Exception("Unknown GPU vendor: " + vendor);

        WriteTitle("DDU Safe Mode cleanup");
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine("This is an advanced recovery/refresh operation.");
        Console.ResetColor();
        Console.WriteLine();
        Console.WriteLine("Target driver vendor: " + GpuVendorLabel(vendor));
        Console.WriteLine("WGDot will:");
        Console.WriteLine("  1. ensure DDU is installed locally;");
        Console.WriteLine("  2. stage one Safe Mode boot;");
        Console.WriteLine("  3. register a Safe Mode RunOnce handoff;");
        Console.WriteLine("  4. remove forced Safe Mode immediately after login;");
        Console.WriteLine("  5. launch DDU for you to perform the vendor cleanup;");
        Console.WriteLine("  6. remember that the correct vendor driver must be reinstalled.");
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine("Before continuing:");
        Console.WriteLine("  - know your Windows account PASSWORD; Safe Mode may not accept Windows Hello/PIN;");
        Console.WriteLine("  - if BitLocker/device encryption is enabled, have the recovery key available;");
        Console.WriteLine("  - disconnect Ethernet/Wi-Fi before DDU and keep it disconnected until the replacement driver is installed;");
        Console.WriteLine("  - close work; WGDot will reboot the PC.");
        Console.ResetColor();
        Console.WriteLine();

        if (!ReadYesNo("Stage DDU cleanup and reboot into Safe Mode? [y/N]", false))
        {
            Console.WriteLine("GPU cleanup cancelled.");
            return;
        }

        EnsureDduInstalled();

        if (!IsAdministrator())
            RunElevatedSelf("gpu-stage-safe --vendor " + vendor + " --reason " + reason);
        else
            StageGpuSafeMode(vendor, reason);
    }

    static int GpuStageSafeFromArgs(string[] args)
    {
        string vendor = GetOption(args, "--vendor");
        string reason = GetOption(args, "--reason");
        if (String.IsNullOrWhiteSpace(reason)) reason = "refresh";

        if (!IsAdministrator())
        {
            RunElevatedSelf("gpu-stage-safe --vendor " + vendor + " --reason " + reason);
            return 0;
        }

        StageGpuSafeMode(vendor, reason);
        return 0;
    }

    static void StageGpuSafeMode(string vendor, string reason)
    {
        if (!IsKnownGpuVendor(vendor))
            throw new Exception("Unknown GPU vendor: " + vendor);

        string ddu = EnsureDduInstalled();
        string installedExe = Path.Combine(BinRoot, "wgdot.exe");
        if (!File.Exists(installedExe))
            installedExe = Process.GetCurrentProcess().MainModule.FileName;

        var state = new Dictionary<string, object>();
        state["phase"] = "safe-mode-pending";
        state["targetVendor"] = vendor;
        state["reason"] = reason;
        state["dduPath"] = ddu;
        state["stagedAt"] = DateTime.UtcNow.ToString("o");
        WriteJson(GpuStatePath, state);

        string runOncePath = @"SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce";
        using (RegistryKey key = Registry.LocalMachine.CreateSubKey(runOncePath))
        {
            if (key == null)
                throw new Exception("Could not create Safe Mode RunOnce handoff.");

            key.SetValue(
                "*WGDotGpuSafeModeResume",
                "\"" + installedExe + "\" gpu-safe-resume",
                RegistryValueKind.String);
        }

        ProcResult safeBoot = Run("bcdedit.exe", "/set {current} safeboot minimal", null);
        if (safeBoot.ExitCode != 0)
        {
            using (RegistryKey key = Registry.LocalMachine.OpenSubKey(runOncePath, true))
                if (key != null) key.DeleteValue("*WGDotGpuSafeModeResume", false);
            SafeDeleteFile(GpuStatePath);
            throw new Exception(
                "Could not stage Safe Mode: " +
                LastUsefulLine(safeBoot.StdErr + "\n" + safeBoot.StdOut));
        }

        Console.WriteLine("Safe Mode handoff staged. Rebooting in 15 seconds.");
        Console.WriteLine("Use 'shutdown /a' from an elevated terminal only if you must cancel this reboot.");
        Run("shutdown.exe", "/r /t 15 /c " + Q("WGDot GPU driver cleanup - booting once into Safe Mode"), null);
    }

    static bool RemoveForcedSafeBoot()
    {
        ProcResult current = Run("bcdedit.exe", "/deletevalue {current} safeboot", null);
        if (current.ExitCode == 0) return true;

        ProcResult check = Run("bcdedit.exe", "/enum {current}", null);
        if (check.ExitCode == 0 &&
            (check.StdOut ?? "").IndexOf("safeboot", StringComparison.OrdinalIgnoreCase) < 0)
            return true;

        ProcResult fallback = Run("bcdedit.exe", "/deletevalue {default} safeboot", null);
        if (fallback.ExitCode == 0) return true;

        ProcResult fallbackCheck = Run("bcdedit.exe", "/enum {default}", null);
        return fallbackCheck.ExitCode == 0 &&
            (fallbackCheck.StdOut ?? "").IndexOf("safeboot", StringComparison.OrdinalIgnoreCase) < 0;
    }

    static int GpuSafeResume()
    {
        if (!IsAdministrator())
        {
            RunElevatedSelf("gpu-safe-resume");
            return 0;
        }

        var state = ReadJson(GpuStatePath);
        if (state == null)
            throw new Exception("No staged WGDot GPU cleanup state exists.");

        string vendor = GetString(state, "targetVendor");
        if (!IsKnownGpuVendor(vendor))
            throw new Exception("Staged GPU cleanup has an invalid target vendor.");

        // Remove the persistent Safe Mode setting before launching DDU so the
        // next restart returns to normal Windows even if DDU or WGDot is closed.
        if (!RemoveForcedSafeBoot())
            throw new Exception(
                "WGDot could not remove the forced Safe Mode boot flag. DDU was not launched. " +
                "Run 'bcdedit /deletevalue {current} safeboot' from an elevated terminal before rebooting.");

        string ddu = GetString(state, "dduPath");
        if (String.IsNullOrWhiteSpace(ddu) || !File.Exists(ddu))
            ddu = FindDduExe();
        if (String.IsNullOrWhiteSpace(ddu))
            throw new Exception("Display Driver Uninstaller could not be located in Safe Mode.");

        state["phase"] = "driver-needed";
        state["safeModeResumedAt"] = DateTime.UtcNow.ToString("o");
        WriteJson(GpuStatePath, state);

        WriteTitle("DDU Safe Mode cleanup");
        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("Forced Safe Mode has already been removed. Your next restart will be normal Windows.");
        Console.ResetColor();
        Console.WriteLine();
        Console.WriteLine("DDU target: " + GpuVendorLabel(vendor));
        Console.WriteLine("Keep the internet disconnected.");
        Console.WriteLine("In DDU, select " + GpuVendorLabel(vendor) + " and use Clean and restart.");
        Console.WriteLine("After normal Windows returns, run 'wgdot'.");
        Console.WriteLine("WGDot will remind you to install the correct " + GpuVendorLabel(vendor) + " driver.");
        Console.WriteLine();

        var psi = new ProcessStartInfo();
        psi.FileName = ddu;
        psi.UseShellExecute = true;
        Process.Start(psi);
        return 0;
    }

    static void TweakManager()
    {
        SourceContext source = ResolveDefaultSource();
        Dictionary<string, object> manifest = source.Manifest;
        InstallationSelection existing = ReadInstallationSelection();

        if (existing == null)
        {
            WriteTitle("Windows tweaks / integrations");
            Console.WriteLine("No WGDot install profile exists yet.");
            Console.WriteLine("Run Install / reconcile software first so WGDot can remember Normal/Work defaults.");
            Pause();
            return;
        }

        var oldPersistent = existing.TweaksConfigured
            ? new HashSet<string>(existing.Tweaks.Where(id => !IsActionOnlyTweak(manifest, id)), StringComparer.OrdinalIgnoreCase)
            : new HashSet<string>(GetDefaultTweakIds(manifest, existing.Scope), StringComparer.OrdinalIgnoreCase);

        List<ChoiceItem> choices = BuildTweakChoices(manifest, existing.Scope, existing, true);
        choices = ReadMultiChoice("Windows tweaks / integrations", choices);
        if (choices == null) return;

        var requested = new HashSet<string>(
            choices.Where(x => x.Selected).Select(x => x.Id),
            StringComparer.OrdinalIgnoreCase);
        var newPersistent = new HashSet<string>(
            requested.Where(id => !IsActionOnlyTweak(manifest, id)),
            StringComparer.OrdinalIgnoreCase);
        var actions = requested.Where(id => IsActionOnlyTweak(manifest, id)).ToList();

        WriteTitle("Windows tweak review");
        foreach (object raw in GetList(manifest, "tweaks"))
        {
            var tweak = AsDictionary(raw);
            string id = GetString(tweak, "id");
            string name = GetString(tweak, "name");

            if (IsActionOnlyTweak(manifest, id))
            {
                if (actions.Contains(id, StringComparer.OrdinalIgnoreCase))
                    Console.WriteLine("RUN      " + name);
            }
            else if (!oldPersistent.Contains(id) && newPersistent.Contains(id))
            {
                Console.WriteLine("ENABLE   " + name);
            }
            else if (oldPersistent.Contains(id) && !newPersistent.Contains(id))
            {
                Console.WriteLine("DISABLE  " + name);
            }
        }

        if (oldPersistent.SetEquals(newPersistent) && actions.Count == 0)
        {
            Console.WriteLine("No tweak changes selected.");
            Pause();
            return;
        }

        Console.WriteLine();
        if (!ReadYesNo("Apply exactly these tweak changes? [y/N]", false))
            return;

        foreach (string id in oldPersistent.Where(x => !newPersistent.Contains(x)).ToList())
            ApplyTweak(id, false, true);

        foreach (string id in newPersistent.Where(x => !oldPersistent.Contains(x)).ToList())
            ApplyTweak(id, true, true);

        foreach (string id in actions)
            RunActionTweak(id);

        existing.Tweaks = newPersistent.ToList();
        existing.TweaksConfigured = true;
        WriteInstallationSelection(existing);

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("WGDot tweak selection applied.");
        Console.ResetColor();
        Pause();
    }

    static void ApplySelectedInstallTweaks(Dictionary<string, object> manifest, InstallationSelection selection)
    {
        if (selection == null || selection.Tweaks == null || selection.Tweaks.Count == 0) return;

        Console.WriteLine();
        Console.WriteLine("Applying selected Windows tweaks / integrations...");

        foreach (string id in selection.Tweaks.ToList())
        {
            if (TweakRunsInElevatedBatch(id))
                continue;

            if (IsActionOnlyTweak(manifest, id))
                RunActionTweak(id);
            else
                ApplyTweak(id, true, true);
        }
    }

    static int ApplyTweakFromArgs(string[] args)
    {
        string id = GetOption(args, "--id");
        string enabled = GetOption(args, "--enable");
        if (String.IsNullOrWhiteSpace(id) || (enabled != "0" && enabled != "1"))
            throw new Exception("apply-tweak requires --id <id> --enable <0|1>.");

        // Direct tweak commands should match the interactive tweak manager: try
        // the user token first, then request UAC only when Windows denies access.
        ApplyTweak(id, enabled == "1", true);
        return 0;
    }

    static bool TweakNeedsAdministrator(string id)
    {
        return
            String.Equals(id, "automatic-time-and-timezone", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(id, "disable-remote-assistance", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(id, "enable-windows-sudo", StringComparison.OrdinalIgnoreCase);
    }

    static bool TweakRunsInElevatedBatch(string id)
    {
        return
            TweakNeedsAdministrator(id) ||
            String.Equals(id, "clean-taskbar-items", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(id, "disable-printscreen-snipping", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(id, "disable-enhanced-pointer-precision", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(id, "communications-do-nothing", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(id, "disable-snap-assist", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(id, "reduce-visual-effects", StringComparison.OrdinalIgnoreCase) ||
            String.Equals(id, "classic-context-menu", StringComparison.OrdinalIgnoreCase);
    }

    static void ApplyTweak(string id, bool enable, bool allowElevation)
    {
        if (TweakNeedsAdministrator(id) && !IsAdministrator())
        {
            if (!allowElevation)
                throw new Exception("Tweak '" + id + "' requires administrator rights.");

            RunElevatedSelf(
                "apply-tweak --id " + Q(id) + " --enable " + (enable ? "1" : "0"));
            return;
        }

        try
        {
            ApplyTweakCore(id, enable);
        }
        catch (UnauthorizedAccessException)
        {
            if (!allowElevation || IsAdministrator())
                throw;

            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("Windows denied normal-user access for tweak '" + id + "'; retrying it once with administrator approval.");
            Console.ResetColor();
            RunElevatedSelf(
                "apply-tweak --id " + Q(id) + " --enable " + (enable ? "1" : "0"));
            return;
        }

        RefreshShellSettings();
    }

    static void ApplyTweakCore(string id, bool enable)
    {
        if (String.Equals(id, "micro-text-defaults", StringComparison.OrdinalIgnoreCase))
            ApplyMicroTextDefaults(enable);
        else if (String.Equals(id, "disable-windows-shell-hotkeys", StringComparison.OrdinalIgnoreCase))
            ApplyWindowsShellHotkeysPolicy(enable);
        else if (String.Equals(id, "clean-taskbar-items", StringComparison.OrdinalIgnoreCase))
            ApplyCleanTaskbar(enable);
        else if (String.Equals(id, "disable-printscreen-snipping", StringComparison.OrdinalIgnoreCase))
            ApplyPrintScreenSnipping(enable);
        else if (String.Equals(id, "disable-enhanced-pointer-precision", StringComparison.OrdinalIgnoreCase))
            ApplyPointerPrecision(enable);
        else if (String.Equals(id, "communications-do-nothing", StringComparison.OrdinalIgnoreCase))
            ApplyCommunicationsDucking(enable);
        else if (String.Equals(id, "disable-snap-assist", StringComparison.OrdinalIgnoreCase))
            ApplySnapAssist(enable);
        else if (String.Equals(id, "automatic-time-and-timezone", StringComparison.OrdinalIgnoreCase))
            ApplyAutomaticTimeAndTimeZone(enable);
        else if (String.Equals(id, "disable-remote-assistance", StringComparison.OrdinalIgnoreCase))
            ApplyRemoteAssistance(enable);
        else if (String.Equals(id, "enable-windows-sudo", StringComparison.OrdinalIgnoreCase))
            ApplyWindowsSudo(enable);
        else if (String.Equals(id, "reduce-visual-effects", StringComparison.OrdinalIgnoreCase))
            ApplyReducedVisualEffects(enable);
        else if (String.Equals(id, "classic-context-menu", StringComparison.OrdinalIgnoreCase))
            ApplyClassicContextMenu(enable);
        else if (String.Equals(id, "oops-all-links-cursor", StringComparison.OrdinalIgnoreCase))
            ApplyOopsCursor(enable);
        else
            throw new Exception("Unknown WGDot tweak: " + id);
    }

    static void RunActionTweak(string id)
    {
        if (String.Equals(id, "privacy-sexy", StringComparison.OrdinalIgnoreCase))
        {
            RunPrivacySexy();
            return;
        }
        if (String.Equals(id, "restore-clipboard-history", StringComparison.OrdinalIgnoreCase))
        {
            RestorePrivacySexyClipboardHistory();
            return;
        }
        throw new Exception("Unknown WGDot action tweak: " + id);
    }

    static int RestorePrivacySexyClipboardHistory()
    {
        if (!IsAdministrator())
        {
            Console.WriteLine();
            Console.WriteLine("Restoring Windows Clipboard History needs administrator approval for the Windows policy/service changes.");
            int exitCode = RunElevatedSelfWithExitCode("restore-clipboard-history");
            if (exitCode != 0)
                throw new Exception(
                    "Elevated Clipboard History restore failed with exit code " +
                    exitCode.ToString(CultureInfo.InvariantCulture) + ".");
            return 0;
        }

        WriteTitle("Restore Windows Clipboard History");
        bool changed = false;

        changed |= EnableClipboardHistoryUserSetting();
        changed |= RemovePrivacySexyClipboardHistoryPolicy();
        changed |= RestorePrivacySexyClipboardServices();

        RefreshShellSettings();

        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine(changed
            ? "Windows Clipboard History settings were restored."
            : "Windows Clipboard History was not currently disabled by the known privacy.sexy settings.");
        Console.ResetColor();
        Console.WriteLine("Cross-device clipboard sync settings were not changed.");
        Console.WriteLine("If Win+V still shows no history in this session, restart Windows once so cbdhsvc is recreated with its restored startup mode.");
        return 0;
    }

    static bool EnableClipboardHistoryUserSetting()
    {
        const string path = @"Software\Microsoft\Clipboard";
        const string name = "EnableClipboardHistory";

        object current = null;
        using (RegistryKey key = Registry.CurrentUser.OpenSubKey(path, false))
        {
            if (key != null)
                current = key.GetValue(name, null, RegistryValueOptions.DoNotExpandEnvironmentNames);
        }

        if (current != null)
        {
            try
            {
                if (Convert.ToInt32(current, CultureInfo.InvariantCulture) != 0)
                {
                    Console.WriteLine("Preserved HKCU Clipboard History setting because it is already enabled.");
                    return false;
                }
            }
            catch
            {
                Console.WriteLine("Preserved HKCU Clipboard History setting because it is not the expected privacy.sexy DWORD value.");
                return false;
            }
        }

        using (RegistryKey key = OpenRegistryKeyForValueWrite("HKCU", path))
        {
            if (key == null)
                throw new Exception("Could not open HKCU\\" + path + " for Clipboard History restore.");
            key.SetValue(name, 1, RegistryValueKind.DWord);
        }

        Console.WriteLine("Enabled current-user Clipboard History.");
        return true;
    }

    static bool RemovePrivacySexyClipboardHistoryPolicy()
    {
        const string path = @"SOFTWARE\Policies\Microsoft\Windows\System";
        const string name = "AllowClipboardHistory";

        object current = null;
        using (RegistryKey key = Registry.LocalMachine.OpenSubKey(path, false))
        {
            if (key != null)
                current = key.GetValue(name, null, RegistryValueOptions.DoNotExpandEnvironmentNames);
        }

        if (current == null)
        {
            Console.WriteLine("Machine Clipboard History policy is already unset.");
            return false;
        }

        try
        {
            if (Convert.ToInt32(current, CultureInfo.InvariantCulture) != 0)
            {
                Console.WriteLine("Preserved machine Clipboard History policy because its value is not the privacy.sexy disabled value.");
                return false;
            }
        }
        catch
        {
            Console.WriteLine("Preserved machine Clipboard History policy because it is not the expected privacy.sexy DWORD value.");
            return false;
        }

        using (RegistryKey key = OpenRegistryKeyForValueWrite("HKLM", path))
        {
            if (key == null)
                throw new Exception("Could not open HKLM\\" + path + " for Clipboard History restore.");
            key.DeleteValue(name, false);
        }

        Console.WriteLine("Removed privacy.sexy's machine Clipboard History deny policy.");
        return true;
    }

    static bool RestorePrivacySexyClipboardServices()
    {
        const string servicesPath = @"SYSTEM\CurrentControlSet\Services";
        var names = new List<string>();

        using (RegistryKey services = Registry.LocalMachine.OpenSubKey(servicesPath, false))
        {
            if (services == null)
                throw new Exception("Could not inspect Windows services for cbdhsvc.");

            foreach (string name in services.GetSubKeyNames())
            {
                if (String.Equals(name, "cbdhsvc", StringComparison.OrdinalIgnoreCase) ||
                    name.StartsWith("cbdhsvc_", StringComparison.OrdinalIgnoreCase))
                    names.Add(name);
            }
        }

        if (names.Count == 0)
        {
            Console.WriteLine("Clipboard User Service (cbdhsvc) registry entries were not found.");
            return false;
        }

        bool changed = false;
        foreach (string name in names.OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
        {
            string path = servicesPath + "\\" + name;
            using (RegistryKey key = Registry.LocalMachine.OpenSubKey(
                path,
                RegistryKeyPermissionCheck.ReadWriteSubTree,
                RegistryRights.QueryValues | RegistryRights.SetValue))
            {
                if (key == null)
                    throw new Exception("Could not open service registry key: HKLM\\" + path);

                object raw = key.GetValue("Start", null, RegistryValueOptions.DoNotExpandEnvironmentNames);
                int start;
                try
                {
                    start = raw == null ? -1 : Convert.ToInt32(raw, CultureInfo.InvariantCulture);
                }
                catch
                {
                    Console.WriteLine("Preserved " + name + " because its Start value is not a DWORD.");
                    continue;
                }

                if (start != 4)
                {
                    Console.WriteLine("Preserved " + name + " startup mode (not disabled).");
                    continue;
                }

                key.SetValue("Start", 2, RegistryValueKind.DWord);
                Console.WriteLine("Restored " + name + " startup mode from Disabled to Automatic.");
                changed = true;
            }
        }

        return changed;
    }

    static bool IsAdministrator()
    {
        try
        {
            WindowsIdentity identity = WindowsIdentity.GetCurrent();
            WindowsPrincipal principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }
        catch
        {
            return false;
        }
    }

    static int RunElevatedSelfWithExitCode(string arguments)
    {
        var psi = new ProcessStartInfo();
        psi.FileName = Process.GetCurrentProcess().MainModule.FileName;
        psi.Arguments = arguments;
        psi.UseShellExecute = true;
        psi.Verb = "runas";

        using (Process p = Process.Start(psi))
        {
            p.WaitForExit();
            return p.ExitCode;
        }
    }

    static void RunElevatedSelf(string arguments)
    {
        int exitCode = RunElevatedSelfWithExitCode(arguments);
        if (exitCode != 0)
            throw new Exception("Elevated WGDot operation failed with exit code " + exitCode.ToString(CultureInfo.InvariantCulture) + ".");
    }

    static RegistryKey GetRegistryRoot(string hive, bool writable)
    {
        if (String.Equals(hive, "HKCU", StringComparison.OrdinalIgnoreCase))
            return Registry.CurrentUser;
        if (String.Equals(hive, "HKLM", StringComparison.OrdinalIgnoreCase))
            return Registry.LocalMachine;
        throw new Exception("Unknown registry hive: " + hive);
    }

    static string RegistrySnapshotKey(string tweakId, string hive, string path, string name)
    {
        return tweakId + "|" + hive + "|" + path + "|" + name;
    }

    static RegistryKey OpenRegistryKeyForValueWrite(
        string hive,
        string path)
    {
        RegistryKey root = GetRegistryRoot(hive, true);

        RegistryKey existing = root.OpenSubKey(
            path,
            RegistryKeyPermissionCheck.ReadWriteSubTree,
            RegistryRights.QueryValues | RegistryRights.SetValue);
        if (existing != null)
            return existing;

        return root.CreateSubKey(path);
    }

    static void SetRegistryValueWithSnapshot(
        string tweakId,
        string hive,
        string path,
        string name,
        object value,
        RegistryValueKind kind)
    {
        try
        {
            CaptureRegistryOriginal(tweakId, hive, path, name);

            using (RegistryKey key = OpenRegistryKeyForValueWrite(hive, path))
            {
                if (key == null)
                    throw new Exception("Could not open registry key: " + hive + "\\" + path);
                key.SetValue(name, value, kind);
            }
        }
        catch (UnauthorizedAccessException ex)
        {
            throw new UnauthorizedAccessException(
                "Registry access denied: " + hive + "\\" + path + "\\" + name,
                ex);
        }
    }

    static Dictionary<string, object> GetRegistryOriginal(
        string tweakId,
        string hive,
        string path,
        string name)
    {
        var state = ReadJson(TweakStatePath);
        if (state == null) return null;

        string snapshotKey = RegistrySnapshotKey(tweakId, hive, path, name);
        foreach (object raw in GetList(state, "registryOriginals"))
        {
            var record = AsDictionary(raw);
            if (String.Equals(GetString(record, "key"), snapshotKey, StringComparison.Ordinal))
                return record;
        }
        return null;
    }

    static void CaptureRegistryOriginal(string tweakId, string hive, string path, string name)
    {
        var state = ReadJson(TweakStatePath) ?? new Dictionary<string, object>();
        var records = new List<object>(GetList(state, "registryOriginals"));
        string snapshotKey = RegistrySnapshotKey(tweakId, hive, path, name);

        foreach (object raw in records)
        {
            var record = AsDictionary(raw);
            if (String.Equals(GetString(record, "key"), snapshotKey, StringComparison.Ordinal))
                return;
        }

        bool keyExists = false;
        bool exists = false;
        object value = null;
        RegistryValueKind kind = RegistryValueKind.String;

        RegistryKey root = GetRegistryRoot(hive, false);
        using (RegistryKey key = root.OpenSubKey(path, false))
        {
            if (key != null)
            {
                keyExists = true;
                string[] names = key.GetValueNames();
                exists = names.Any(x => String.Equals(x, name, StringComparison.OrdinalIgnoreCase));
                if (exists)
                {
                    value = key.GetValue(name, null, RegistryValueOptions.DoNotExpandEnvironmentNames);
                    kind = key.GetValueKind(name);
                }
            }
        }

        string valueEncoding = "text";
        string serializedValue = "";
        if (value != null)
        {
            if ((kind == RegistryValueKind.Binary || kind == RegistryValueKind.None) && value is byte[])
            {
                valueEncoding = "base64-bytes";
                serializedValue = Convert.ToBase64String((byte[])value);
            }
            else if (kind == RegistryValueKind.MultiString && value is string[])
            {
                valueEncoding = "base64-multisz";
                serializedValue = Convert.ToBase64String(
                    Encoding.UTF8.GetBytes(String.Join("\0", (string[])value)));
            }
            else
            {
                serializedValue = Convert.ToString(value, CultureInfo.InvariantCulture);
            }
        }

        var next = new Dictionary<string, object>();
        next["key"] = snapshotKey;
        next["tweakId"] = tweakId;
        next["hive"] = hive;
        next["path"] = path;
        next["name"] = name;
        next["keyExists"] = keyExists;
        next["exists"] = exists;
        next["kind"] = kind.ToString();
        next["valueEncoding"] = valueEncoding;
        next["value"] = serializedValue;
        records.Add(next);

        state["registryOriginals"] = records.ToArray();
        WriteJson(TweakStatePath, state);
    }

    static void DiscardRegistryOriginalSnapshot(
        string tweakId,
        string hive,
        string path,
        string name)
    {
        var state = ReadJson(TweakStatePath);
        if (state == null) return;

        string snapshotKey = RegistrySnapshotKey(tweakId, hive, path, name);
        List<object> records = GetList(state, "registryOriginals")
            .Where(raw =>
            {
                var record = AsDictionary(raw);
                return !String.Equals(
                    GetString(record, "key"),
                    snapshotKey,
                    StringComparison.Ordinal);
            })
            .Cast<object>()
            .ToList();

        state["registryOriginals"] = records.ToArray();
        WriteJson(TweakStatePath, state);
    }

    static void RestoreRegistryOriginals(string tweakId)
    {
        var state = ReadJson(TweakStatePath);
        if (state == null) return;

        foreach (object raw in GetList(state, "registryOriginals"))
        {
            var record = AsDictionary(raw);
            if (!String.Equals(GetString(record, "tweakId"), tweakId, StringComparison.OrdinalIgnoreCase))
                continue;

            string hive = GetString(record, "hive");
            string path = GetString(record, "path");
            string name = GetString(record, "name");
            bool exists = GetBool(record, "exists");

            using (RegistryKey key = OpenRegistryKeyForValueWrite(hive, path))
            {
                if (key == null) continue;

                if (!exists)
                {
                    try { key.DeleteValue(name, false); } catch { }
                    continue;
                }

                RegistryValueKind kind;
                if (!Enum.TryParse(GetString(record, "kind"), out kind))
                    kind = RegistryValueKind.String;

                string text = GetString(record, "value");
                string valueEncoding = record.ContainsKey("valueEncoding")
                    ? GetString(record, "valueEncoding")
                    : "text";
                object value = text;

                if (kind == RegistryValueKind.DWord)
                {
                    int number;
                    if (Int32.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out number))
                        value = number;
                }
                else if (kind == RegistryValueKind.QWord)
                {
                    long number;
                    if (Int64.TryParse(text, NumberStyles.Integer, CultureInfo.InvariantCulture, out number))
                        value = number;
                }
                else if (kind == RegistryValueKind.Binary || kind == RegistryValueKind.None)
                {
                    if (!String.Equals(valueEncoding, "base64-bytes", StringComparison.Ordinal))
                    {
                        Console.WriteLine("Skipping unsupported legacy binary registry snapshot: " + path + "\\" + name);
                        continue;
                    }
                    value = Convert.FromBase64String(text);
                }
                else if (kind == RegistryValueKind.MultiString)
                {
                    if (!String.Equals(valueEncoding, "base64-multisz", StringComparison.Ordinal))
                    {
                        Console.WriteLine("Skipping unsupported legacy multi-string registry snapshot: " + path + "\\" + name);
                        continue;
                    }

                    string decoded = Encoding.UTF8.GetString(Convert.FromBase64String(text));
                    value = decoded.Length == 0
                        ? new string[0]
                        : decoded.Split(new[] { '\0' }, StringSplitOptions.None);
                }

                key.SetValue(name, value, kind);
            }
        }

        var cleanupPaths = new List<string[]>();
        foreach (object raw in GetList(state, "registryOriginals"))
        {
            var record = AsDictionary(raw);
            if (!String.Equals(GetString(record, "tweakId"), tweakId, StringComparison.OrdinalIgnoreCase) ||
                !record.ContainsKey("keyExists") ||
                GetBool(record, "keyExists"))
                continue;

            string hive = GetString(record, "hive");
            string path = GetString(record, "path");
            if (!cleanupPaths.Any(x =>
                String.Equals(x[0], hive, StringComparison.OrdinalIgnoreCase) &&
                String.Equals(x[1], path, StringComparison.OrdinalIgnoreCase)))
            {
                cleanupPaths.Add(new[] { hive, path });
            }
        }

        foreach (string[] item in cleanupPaths.OrderByDescending(x => x[1].Length))
            DeleteRegistryKeyIfEmpty(item[0], item[1]);
    }

    static bool RegistryKeyWasAbsentInSnapshot(
        string tweakId,
        string hive,
        string path,
        string name)
    {
        var original = GetRegistryOriginal(tweakId, hive, path, name);
        return original != null &&
            original.ContainsKey("keyExists") &&
            !GetBool(original, "keyExists");
    }

    static void DeleteRegistryKeyIfEmpty(string hive, string path)
    {
        int separator = path.LastIndexOf('\\');
        if (separator <= 0 || separator >= path.Length - 1)
            return;

        RegistryKey root = GetRegistryRoot(hive, true);
        using (RegistryKey key = root.OpenSubKey(path, false))
        {
            if (key == null) return;
            if (key.GetValueNames().Length != 0 || key.GetSubKeyNames().Length != 0)
                return;
        }

        string parentPath = path.Substring(0, separator);
        string leaf = path.Substring(separator + 1);
        using (RegistryKey parent = root.OpenSubKey(parentPath, true))
        {
            if (parent == null) return;
            try { parent.DeleteSubKey(leaf, false); } catch { }
        }
    }

    static void DeleteRegistryKeyIfOriginallyAbsentAndEmpty(
        string tweakId,
        string hive,
        string path,
        string name)
    {
        if (RegistryKeyWasAbsentInSnapshot(tweakId, hive, path, name))
            DeleteRegistryKeyIfEmpty(hive, path);
    }

    static void CaptureExternalSettingOriginal(string key, bool exists, string value)
    {
        var state = ReadJson(TweakStatePath) ?? new Dictionary<string, object>();
        var records = new List<object>(GetList(state, "externalOriginals"));

        foreach (object raw in records)
        {
            var record = AsDictionary(raw);
            if (String.Equals(GetString(record, "key"), key, StringComparison.OrdinalIgnoreCase))
                return;
        }

        var next = new Dictionary<string, object>();
        next["key"] = key;
        next["exists"] = exists;
        next["value"] = value ?? "";
        records.Add(next);
        state["externalOriginals"] = records.ToArray();
        WriteJson(TweakStatePath, state);
    }

    static Dictionary<string, object> GetExternalSettingOriginal(string key)
    {
        var state = ReadJson(TweakStatePath);
        if (state == null) return null;

        foreach (object raw in GetList(state, "externalOriginals"))
        {
            var record = AsDictionary(raw);
            if (String.Equals(GetString(record, "key"), key, StringComparison.OrdinalIgnoreCase))
                return record;
        }
        return null;
    }

    static bool StopProcessesByName(string processName)
    {
        bool found = false;
        foreach (Process process in Process.GetProcessesByName(processName))
        {
            found = true;
            try
            {
                process.Kill();
                process.WaitForExit(5000);
            }
            catch
            {
            }
            finally
            {
                process.Dispose();
            }
        }
        return found;
    }

    static YasbTheme FindYasbTheme(string id)
    {
        string normalized = (id ?? "").Trim().Replace("_", "-");
        return YasbThemes.FirstOrDefault(
            x => String.Equals(x.Id, normalized, StringComparison.OrdinalIgnoreCase) ||
                 String.Equals(x.Label, id, StringComparison.OrdinalIgnoreCase));
    }

    static string CurrentYasbThemeId()
    {
        var state = ReadJson(ThemeStatePath);
        string id = state == null ? "" : GetString(state, "id");
        return FindYasbTheme(id) != null ? FindYasbTheme(id).Id : "carbon-night";
    }

    static string YasbThemeCssPath()
    {
        string profileRoot;
        if (!String.IsNullOrWhiteSpace(TestRootOverride))
            profileRoot = Path.Combine(TestRootOverride, "user-profile");
        else
            profileRoot = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

        return Path.Combine(profileRoot, ".config", "yasb", "theme.css");
    }

    static int ThemeManagerFromArgs(string[] args)
    {
        if (args == null || args.Length == 0)
            return ThemeManager();

        if (args.Length != 1)
        {
            Console.Error.WriteLine("Usage: wgdot theme [theme-id]");
            return 2;
        }

        return ApplyYasbTheme(args[0]);
    }

    static int ThemeManager()
    {
        while (true)
        {
            string current = CurrentYasbThemeId();
            var items = new List<string>();
            foreach (YasbTheme theme in YasbThemes)
            {
                bool active = String.Equals(theme.Id, current, StringComparison.OrdinalIgnoreCase);
                items.Add((active ? "* " : "  ") + theme.Label);
            }
            items.Add("Back");

            int currentIndex = YasbThemes.FindIndex(
                x => String.Equals(x.Id, current, StringComparison.OrdinalIgnoreCase));
            if (currentIndex < 0) currentIndex = 0;

            int choice = ReadSingleChoice(
                "Themes - YASB + Windows Terminal; GlazeWM is not reloaded",
                items,
                currentIndex);

            if (choice < 0 || choice >= YasbThemes.Count)
                return 0;

            ApplyYasbTheme(YasbThemes[choice].Id);
        }
    }

    static int ApplyYasbTheme(string id)
    {
        YasbTheme theme = FindYasbTheme(id);
        if (theme == null)
        {
            Console.Error.WriteLine("Unknown YASB theme: " + (id ?? ""));
            Console.Error.WriteLine(
                "Available: " + String.Join(", ", YasbThemes.Select(x => x.Id).ToArray()));
            return 2;
        }

        string cssPath = YasbThemeCssPath();
        WriteTextAtomic(cssPath, BuildYasbThemeCss(theme));

        // YASB v2.0.7 watches imported stylesheets through on_modified.
        // Atomic replacement can surface as a move/create event instead, so
        // finish with a harmless in-place whitespace write to guarantee the
        // live stylesheet watcher sees a modification event.
        File.AppendAllText(cssPath, Environment.NewLine, new UTF8Encoding(false));

        bool terminalSynced = ApplyWindowsTerminalTheme(theme);

        var state = new Dictionary<string, object>();
        state["id"] = theme.Id;
        state["label"] = theme.Label;
        state["appliedAt"] = DateTime.UtcNow.ToString("o");
        state["cssPath"] = cssPath;
        state["terminalSynced"] = terminalSynced;
        state["terminalSettingsPath"] = WindowsTerminalSettingsPath();
        state["glazewmReloaded"] = false;
        WriteJson(ThemeStatePath, state);

        Console.WriteLine("YASB theme applied: " + theme.Label);
        Console.WriteLine(terminalSynced
            ? "Windows Terminal theme applied: " + theme.Label
            : "Windows Terminal settings were not found; terminal theme sync was skipped.");
        Console.WriteLine("GlazeWM was not reloaded; window tiling/layout state is untouched.");
        return 0;
    }




    static System.Windows.Forms.Screen CurrentInteractionScreen()
    {
        IntPtr foreground = GetForegroundWindow();
        if (foreground != IntPtr.Zero)
            return System.Windows.Forms.Screen.FromHandle(foreground);

        POINT cursor;
        if (GetCursorPos(out cursor))
            return System.Windows.Forms.Screen.FromPoint(
                new System.Drawing.Point(cursor.X, cursor.Y));

        return System.Windows.Forms.Screen.PrimaryScreen;
    }

    static void CenterWindowOnScreen(
        IntPtr window,
        System.Windows.Forms.Screen screen)
    {
        if (window == IntPtr.Zero || screen == null)
            return;

        RECT rect;
        if (!GetWindowRect(window, out rect))
            return;

        int width = Math.Max(1, rect.Right - rect.Left);
        int height = Math.Max(1, rect.Bottom - rect.Top);
        System.Drawing.Rectangle work = screen.WorkingArea;
        int x = work.Left + Math.Max(0, (work.Width - width) / 2);
        int y = work.Top + Math.Max(0, (work.Height - height) / 2);

        SetWindowPos(
            window,
            IntPtr.Zero,
            x,
            y,
            0,
            0,
            SwpNoSize | SwpNoZOrder | SwpShowWindow);
    }

    static int LaunchThemeWindow(System.Windows.Forms.Screen targetScreen)
    {
        var psi = new ProcessStartInfo();
        psi.FileName = "wt.exe";
        psi.Arguments =
            "-w new new-tab --title \"Win Glaze Themes\" " +
            "--suppressApplicationTitle wgdot.exe theme";
        psi.UseShellExecute = true;
        Process.Start(psi);

        if (targetScreen != null)
        {
            for (int i = 0; i < 80; i++)
            {
                IntPtr window = FindTopLevelWindowByExactTitle("Win Glaze Themes");
                if (window != IntPtr.Zero)
                {
                    CenterWindowOnScreen(window, targetScreen);
                    SetForegroundWindow(window);
                    break;
                }

                System.Threading.Thread.Sleep(25);
            }
        }

        return 0;
    }

    static int ThemeWindowToggle()
    {
        System.Windows.Forms.Screen targetScreen = CurrentInteractionScreen();
        IntPtr existing = FindTopLevelWindowByExactTitle("Win Glaze Themes");
        if (existing == IntPtr.Zero)
            return LaunchThemeWindow(targetScreen);

        System.Windows.Forms.Screen existingScreen =
            System.Windows.Forms.Screen.FromHandle(existing);

        bool sameVisibleContext =
            targetScreen != null &&
            existingScreen != null &&
            String.Equals(
                targetScreen.DeviceName,
                existingScreen.DeviceName,
                StringComparison.OrdinalIgnoreCase) &&
            IsWindowVisible(existing) &&
            !IsDwmCloaked(existing);

        PostMessage(existing, WmClose, IntPtr.Zero, IntPtr.Zero);

        if (sameVisibleContext)
            return 0;

        for (int i = 0; i < 20 && IsWindow(existing); i++)
            System.Threading.Thread.Sleep(25);

        return LaunchThemeWindow(targetScreen);
    }

    static void SendNativeClipboardHistoryChord()
    {
        keybd_event(VkLwin, 0, 0, UIntPtr.Zero);
        keybd_event(VkV, 0, 0, UIntPtr.Zero);
        keybd_event(VkV, 0, KeyeventfKeyup, UIntPtr.Zero);
        keybd_event(VkLwin, 0, KeyeventfKeyup, UIntPtr.Zero);
    }

    static int ClipboardHistoryOpen()
    {
        // Keyboard Clipboard History stays native on Super+V. This helper exists
        // only for the YASB mouse button, where no user key chord is being held.
        SendNativeClipboardHistoryChord();
        return 0;
    }

    static int LauncherFromArgs(string[] args)
    {
        string source = args != null && args.Length > 0
            ? (args[0] ?? "").Trim().ToLowerInvariant()
            : "hotkey";

        if (!(String.Equals(source, "bar", StringComparison.OrdinalIgnoreCase) ||
              String.Equals(source, "hotkey", StringComparison.OrdinalIgnoreCase)))
            throw new Exception("Usage: wgdot launcher [bar|hotkey]");

        return Launcher(source);
    }

    static bool YasbAutoHideEnabled()
    {
        try
        {
            string profile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            string path = Path.Combine(profile, ".config", "yasb", "config.yaml");
            if (!File.Exists(path)) return false;
            string text = File.ReadAllText(path);
            return Regex.IsMatch(
                text,
                @"(?m)^\s*auto_hide:\s*true\s*$",
                RegexOptions.IgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    static bool ForegroundWindowFillsScreen(IntPtr window, System.Windows.Forms.Screen screen)
    {
        if (window == IntPtr.Zero || screen == null)
            return false;

        try
        {
            System.Windows.Forms.Screen windowScreen = System.Windows.Forms.Screen.FromHandle(window);
            if (!String.Equals(windowScreen.DeviceName, screen.DeviceName, StringComparison.OrdinalIgnoreCase))
                return false;

            RECT rect;
            if (!GetWindowRect(window, out rect))
                return false;

            System.Drawing.Rectangle bounds = screen.Bounds;
            const int tolerance = 3;
            return
                rect.Left <= bounds.Left + tolerance &&
                rect.Top <= bounds.Top + tolerance &&
                rect.Right >= bounds.Right - tolerance &&
                rect.Bottom >= bounds.Bottom - tolerance;
        }
        catch
        {
            return false;
        }
    }

    static System.Drawing.Point ClampLauncherLocation(
        System.Windows.Forms.Screen screen,
        int x,
        int y,
        int width,
        int height)
    {
        System.Drawing.Rectangle bounds = screen.Bounds;
        int minX = bounds.Left + 8;
        int maxX = Math.Max(minX, bounds.Right - width - 8);
        int minY = bounds.Top + 8;
        int maxY = Math.Max(minY, bounds.Bottom - height - 8);

        return new System.Drawing.Point(
            Math.Max(minX, Math.Min(maxX, x)),
            Math.Max(minY, Math.Min(maxY, y)));
    }

    static System.Drawing.Point LauncherLocation(
        string source,
        System.Windows.Forms.Screen screen,
        IntPtr foreground,
        int width,
        int height)
    {
        bool centerScreen =
            YasbAutoHideEnabled() ||
            ForegroundWindowFillsScreen(foreground, screen);

        if (centerScreen)
        {
            return ClampLauncherLocation(
                screen,
                screen.Bounds.Left + ((screen.Bounds.Width - width) / 2),
                screen.Bounds.Top + ((screen.Bounds.Height - height) / 2),
                width,
                height);
        }

        if (String.Equals(source, "bar", StringComparison.OrdinalIgnoreCase))
        {
            return ClampLauncherLocation(
                screen,
                screen.Bounds.Left + 8,
                screen.Bounds.Top + 40,
                width,
                height);
        }

        return ClampLauncherLocation(
            screen,
            screen.Bounds.Left + ((screen.Bounds.Width - width) / 2),
            screen.Bounds.Top + 40,
            width,
            height);
    }

    static string ResolveLauncherShortcutIconPath(string path)
    {
        if (String.IsNullOrWhiteSpace(path))
            return path;

        string extension = Path.GetExtension(path);
        if (String.Equals(extension, ".url", StringComparison.OrdinalIgnoreCase))
        {
            try
            {
                foreach (string rawLine in File.ReadAllLines(path))
                {
                    string line = rawLine.Trim();
                    if (!line.StartsWith("IconFile=", StringComparison.OrdinalIgnoreCase))
                        continue;

                    string iconFile = Environment.ExpandEnvironmentVariables(
                        line.Substring("IconFile=".Length).Trim().Trim('"'));
                    if (File.Exists(iconFile))
                        return iconFile;
                }
            }
            catch
            {
            }

            return path;
        }

        if (!String.Equals(extension, ".lnk", StringComparison.OrdinalIgnoreCase))
            return path;

        object shell = null;
        object shortcut = null;
        try
        {
            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType == null)
                return path;

            shell = Activator.CreateInstance(shellType);
            shortcut = shellType.InvokeMember(
                "CreateShortcut",
                System.Reflection.BindingFlags.InvokeMethod,
                null,
                shell,
                new object[] { path });
            if (shortcut == null)
                return path;

            Type shortcutType = shortcut.GetType();
            string targetPath = Convert.ToString(shortcutType.InvokeMember(
                "TargetPath",
                System.Reflection.BindingFlags.GetProperty,
                null,
                shortcut,
                null));
            if (!String.IsNullOrWhiteSpace(targetPath))
            {
                targetPath = Environment.ExpandEnvironmentVariables(
                    targetPath.Trim().Trim('"'));
                if (File.Exists(targetPath) &&
                    !String.Equals(
                        Path.GetFileName(targetPath),
                        "explorer.exe",
                        StringComparison.OrdinalIgnoreCase))
                    return targetPath;
            }

            string iconLocation = Convert.ToString(shortcutType.InvokeMember(
                "IconLocation",
                System.Reflection.BindingFlags.GetProperty,
                null,
                shortcut,
                null));
            if (!String.IsNullOrWhiteSpace(iconLocation))
            {
                int comma = iconLocation.LastIndexOf(',');
                string iconPath = comma > 1
                    ? iconLocation.Substring(0, comma)
                    : iconLocation;
                iconPath = Environment.ExpandEnvironmentVariables(
                    iconPath.Trim().Trim('"'));
                if (File.Exists(iconPath))
                    return iconPath;
            }
        }
        catch
        {
        }
        finally
        {
            if (shortcut != null && Marshal.IsComObject(shortcut))
            {
                try { Marshal.FinalReleaseComObject(shortcut); } catch { }
            }
            if (shell != null && Marshal.IsComObject(shell))
            {
                try { Marshal.FinalReleaseComObject(shell); } catch { }
            }
        }

        return path;
    }

    static void AddLauncherAppsFromFolder(
        string root,
        Dictionary<string, LauncherApp> byName)
    {
        if (String.IsNullOrWhiteSpace(root) || !Directory.Exists(root))
            return;

        string[] files;
        try
        {
            files = Directory.GetFiles(root, "*.*", SearchOption.AllDirectories);
        }
        catch
        {
            return;
        }

        foreach (string path in files)
        {
            string ext = Path.GetExtension(path);
            if (!(String.Equals(ext, ".lnk", StringComparison.OrdinalIgnoreCase) ||
                  String.Equals(ext, ".url", StringComparison.OrdinalIgnoreCase) ||
                  String.Equals(ext, ".appref-ms", StringComparison.OrdinalIgnoreCase)))
                continue;

            if (path.IndexOf(
                    Path.DirectorySeparatorChar + "Startup" + Path.DirectorySeparatorChar,
                    StringComparison.OrdinalIgnoreCase) >= 0)
                continue;

            string name = Path.GetFileNameWithoutExtension(path);
            if (String.IsNullOrWhiteSpace(name))
                continue;

            LauncherApp existing;
            if (byName.TryGetValue(name, out existing))
                continue;

            byName[name] = new LauncherApp
            {
                Name = name.Trim(),
                Path = path,
                IconPath = ResolveLauncherShortcutIconPath(path)
            };
        }
    }

    static List<LauncherApp> GetLauncherApps()
    {
        var byName = new Dictionary<string, LauncherApp>(StringComparer.OrdinalIgnoreCase);

        AddLauncherAppsFromFolder(
            Environment.GetFolderPath(Environment.SpecialFolder.Programs),
            byName);
        AddLauncherAppsFromFolder(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms),
            byName);

        return byName.Values
            .OrderBy(x => x.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    static int LauncherMatchScore(string name, string query)
    {
        string n = (name ?? "").Trim().ToLowerInvariant();
        string q = (query ?? "").Trim().ToLowerInvariant();

        if (q.Length == 0)
            return 1000 + n.Length;

        if (String.Equals(n, q, StringComparison.OrdinalIgnoreCase))
            return 0;
        if (n.StartsWith(q, StringComparison.OrdinalIgnoreCase))
            return 10 + n.Length;

        string[] tokens = q.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
        int score = 100;
        foreach (string token in tokens)
        {
            int index = n.IndexOf(token, StringComparison.OrdinalIgnoreCase);
            if (index < 0)
                return Int32.MaxValue;
            score += index * 5;
        }

        return score + n.Length;
    }

    static List<LauncherApp> FilterLauncherApps(
        List<LauncherApp> apps,
        string query,
        int maxResults)
    {
        return apps
            .Select(x => new
            {
                App = x,
                Score = LauncherMatchScore(x.Name, query)
            })
            .Where(x => x.Score != Int32.MaxValue)
            .OrderBy(x => x.Score)
            .ThenBy(x => x.App.Name, StringComparer.OrdinalIgnoreCase)
            .Take(maxResults)
            .Select(x => x.App)
            .ToList();
    }

    static System.Drawing.Image GetLauncherAppIcon(LauncherApp app)
    {
        if (app == null)
            return null;

        if (app.IconLoaded)
            return app.IconImage;

        app.IconLoaded = true;
        SHFILEINFO info;
        string iconPath = String.IsNullOrWhiteSpace(app.IconPath)
            ? app.Path
            : app.IconPath;
        IntPtr result = SHGetFileInfo(
            iconPath,
            0,
            out info,
            (uint)Marshal.SizeOf(typeof(SHFILEINFO)),
            ShgfiIcon);

        if (result == IntPtr.Zero || info.hIcon == IntPtr.Zero)
            return null;

        try
        {
            using (System.Drawing.Icon icon =
                (System.Drawing.Icon)System.Drawing.Icon.FromHandle(info.hIcon).Clone())
            {
                app.IconImage = icon.ToBitmap();
            }
        }
        finally
        {
            DestroyIcon(info.hIcon);
        }

        return app.IconImage;
    }

    static void LaunchLauncherApp(
        System.Windows.Forms.Form form,
        LauncherApp app)
    {
        if (app == null || String.IsNullOrWhiteSpace(app.Path))
            return;

        var psi = new ProcessStartInfo();
        psi.FileName = app.Path;
        psi.UseShellExecute = true;
        psi.ErrorDialog = false;

        Process.Start(psi);
        form.Close();
    }

    static int Launcher(string source)
    {
        const string title = "WGDot Launcher";
        IntPtr existing = FindTopLevelWindowByExactTitle(title);
        if (existing != IntPtr.Zero)
        {
            PostMessage(existing, WmClose, IntPtr.Zero, IntPtr.Zero);
            return 0;
        }

        List<LauncherApp> apps = new List<LauncherApp>();

        IntPtr foreground = GetForegroundWindow();
        POINT cursor;
        bool haveCursor = GetCursorPos(out cursor);

        System.Windows.Forms.Screen screen;
        if (String.Equals(source, "bar", StringComparison.OrdinalIgnoreCase) && haveCursor)
            screen = System.Windows.Forms.Screen.FromPoint(new System.Drawing.Point(cursor.X, cursor.Y));
        else if (foreground != IntPtr.Zero)
            screen = System.Windows.Forms.Screen.FromHandle(foreground);
        else if (haveCursor)
            screen = System.Windows.Forms.Screen.FromPoint(new System.Drawing.Point(cursor.X, cursor.Y));
        else
            screen = System.Windows.Forms.Screen.PrimaryScreen;

        YasbTheme theme = FindYasbTheme(CurrentYasbThemeId()) ?? YasbThemes[0];
        System.Drawing.Color background = WgdotDrawingColor(
            theme.Background,
            System.Drawing.Color.FromArgb(25, 25, 25));
        System.Drawing.Color foregroundColor = WgdotDrawingColor(
            theme.Foreground,
            System.Drawing.Color.Gainsboro);
        System.Drawing.Color field = WgdotDrawingColor(
            theme.Active,
            System.Drawing.Color.FromArgb(43, 43, 43));
        System.Drawing.Color hover = WgdotDrawingColor(
            theme.Hover,
            System.Drawing.Color.FromArgb(64, 64, 64));

        const int width = 380;
        const int height = 450;

        var form = new System.Windows.Forms.Form();
        form.Text = title;
        form.FormBorderStyle = System.Windows.Forms.FormBorderStyle.None;
        form.StartPosition = System.Windows.Forms.FormStartPosition.Manual;
        form.Size = new System.Drawing.Size(width, height);
        form.Location = LauncherLocation(source, screen, foreground, width, height);
        form.BackColor = background;
        form.ForeColor = foregroundColor;
        form.ShowInTaskbar = false;
        form.TopMost = true;
        form.KeyPreview = true;
        form.Opacity = 0.98;

        var outer = new System.Windows.Forms.Panel();
        outer.Dock = System.Windows.Forms.DockStyle.Fill;
        outer.Padding = new System.Windows.Forms.Padding(12);
        outer.BackColor = background;

        var searchWrap = new System.Windows.Forms.Panel();
        searchWrap.Dock = System.Windows.Forms.DockStyle.Top;
        searchWrap.Height = 42;
        searchWrap.Padding = new System.Windows.Forms.Padding(10, 7, 10, 6);
        searchWrap.BackColor = field;

        var search = new System.Windows.Forms.TextBox();
        search.Dock = System.Windows.Forms.DockStyle.Fill;
        search.BorderStyle = System.Windows.Forms.BorderStyle.None;
        search.BackColor = field;
        search.ForeColor = foregroundColor;
        search.Font = new System.Drawing.Font(
            "Segoe UI",
            17f,
            System.Drawing.FontStyle.Regular,
            System.Drawing.GraphicsUnit.Pixel);

        var results = new System.Windows.Forms.ListBox();
        results.Dock = System.Windows.Forms.DockStyle.Fill;
        results.BorderStyle = System.Windows.Forms.BorderStyle.None;
        results.BackColor = background;
        results.ForeColor = foregroundColor;
        results.Font = new System.Drawing.Font(
            "Segoe UI",
            15f,
            System.Drawing.FontStyle.Regular,
            System.Drawing.GraphicsUnit.Pixel);
        results.DrawMode = System.Windows.Forms.DrawMode.OwnerDrawFixed;
        results.ItemHeight = 40;
        results.IntegralHeight = false;

        Action refresh = delegate
        {
            List<LauncherApp> filtered = FilterLauncherApps(apps, search.Text, 12);
            results.BeginUpdate();
            try
            {
                results.Items.Clear();
                foreach (LauncherApp app in filtered)
                    results.Items.Add(app);

                if (results.Items.Count > 0)
                    results.SelectedIndex = 0;
            }
            finally
            {
                results.EndUpdate();
            }
        };

        results.DrawItem += delegate(
            object sender,
            System.Windows.Forms.DrawItemEventArgs e)
        {
            if (e.Index < 0 || e.Index >= results.Items.Count)
                return;

            bool selected = (e.State & System.Windows.Forms.DrawItemState.Selected) != 0;
            using (var brush = new System.Drawing.SolidBrush(selected ? hover : background))
                e.Graphics.FillRectangle(brush, e.Bounds);

            LauncherApp app = results.Items[e.Index] as LauncherApp;
            string label = app == null ? "" : app.Name;
            System.Drawing.Image icon = GetLauncherAppIcon(app);
            int textLeft = e.Bounds.Left + 12;
            if (icon != null)
            {
                const int iconSize = 24;
                int iconY = e.Bounds.Top + Math.Max(0, (e.Bounds.Height - iconSize) / 2);
                e.Graphics.DrawImage(
                    icon,
                    new System.Drawing.Rectangle(
                        e.Bounds.Left + 10,
                        iconY,
                        iconSize,
                        iconSize));
                textLeft = e.Bounds.Left + 44;
            }

            System.Drawing.Rectangle textBounds = new System.Drawing.Rectangle(
                textLeft,
                e.Bounds.Top,
                Math.Max(1, e.Bounds.Right - textLeft - 12),
                e.Bounds.Height);

            System.Windows.Forms.TextRenderer.DrawText(
                e.Graphics,
                label,
                results.Font,
                textBounds,
                foregroundColor,
                System.Windows.Forms.TextFormatFlags.Left |
                System.Windows.Forms.TextFormatFlags.VerticalCenter |
                System.Windows.Forms.TextFormatFlags.EndEllipsis);
        };

        Action launchSelected = delegate
        {
            LauncherApp app = results.SelectedItem as LauncherApp;
            if (app == null)
                return;

            try
            {
                LaunchLauncherApp(form, app);
            }
            catch (Exception ex)
            {
                System.Windows.Forms.MessageBox.Show(
                    form,
                    "Could not launch " + app.Name + ".\r\n\r\n" + ex.Message,
                    "WGDot Launcher",
                    System.Windows.Forms.MessageBoxButtons.OK,
                    System.Windows.Forms.MessageBoxIcon.Error);
                search.Focus();
            }
        };

        search.TextChanged += delegate { refresh(); };
        search.KeyDown += delegate(
            object sender,
            System.Windows.Forms.KeyEventArgs e)
        {
            if (e.KeyCode == System.Windows.Forms.Keys.Down)
            {
                if (results.Items.Count > 0)
                    results.SelectedIndex = Math.Min(results.Items.Count - 1, results.SelectedIndex + 1);
                e.Handled = true;
                e.SuppressKeyPress = true;
            }
            else if (e.KeyCode == System.Windows.Forms.Keys.Up)
            {
                if (results.Items.Count > 0)
                    results.SelectedIndex = Math.Max(0, results.SelectedIndex - 1);
                e.Handled = true;
                e.SuppressKeyPress = true;
            }
            else if (e.KeyCode == System.Windows.Forms.Keys.Enter)
            {
                launchSelected();
                e.Handled = true;
                e.SuppressKeyPress = true;
            }
            else if (e.KeyCode == System.Windows.Forms.Keys.Escape)
            {
                form.Close();
                e.Handled = true;
                e.SuppressKeyPress = true;
            }
        };

        results.DoubleClick += delegate { launchSelected(); };
        results.KeyDown += delegate(
            object sender,
            System.Windows.Forms.KeyEventArgs e)
        {
            if (e.KeyCode == System.Windows.Forms.Keys.Enter)
            {
                launchSelected();
                e.Handled = true;
            }
            else if (e.KeyCode == System.Windows.Forms.Keys.Escape)
            {
                form.Close();
                e.Handled = true;
            }
        };

        form.Deactivate += delegate
        {
            if (!form.IsDisposed)
                form.Close();
        };

        searchWrap.Controls.Add(search);
        outer.Controls.Add(results);
        outer.Controls.Add(searchWrap);
        form.Controls.Add(outer);

        form.Shown += delegate
        {
            search.Focus();

            System.Threading.ThreadPool.QueueUserWorkItem(delegate
            {
                List<LauncherApp> loadedApps = GetLauncherApps();
                if (form.IsDisposed)
                    return;

                try
                {
                    form.BeginInvoke((Action)delegate
                    {
                        apps = loadedApps;
                        refresh();
                    });
                }
                catch
                {
                }
            });

        };

        System.Windows.Forms.Application.Run(form);
        return 0;
    }

    static System.Drawing.Color WgdotDrawingColor(string hex, System.Drawing.Color fallback)
    {
        try
        {
            return System.Drawing.ColorTranslator.FromHtml(hex);
        }
        catch
        {
            return fallback;
        }
    }

    static void StartShutdownCommand(string arguments)
    {
        var psi = new ProcessStartInfo();
        psi.FileName = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System),
            "shutdown.exe");
        psi.Arguments = arguments;
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        Process.Start(psi);
    }

    static List<PowerAction> BuildPowerActions()
    {
        return new List<PowerAction>
        {
            new PowerAction('l', "", "Lock (L)", delegate
            {
                if (!LockWorkStation())
                    throw new Exception("Windows lock request failed.");
            }),
            new PowerAction('h', "", "Hibernate (H)", delegate
            {
                StartShutdownCommand("/h");
            }),
            new PowerAction('r', "", "Reboot (R)", delegate
            {
                StartShutdownCommand("/r /t 0");
            }),
            new PowerAction('s', "", "Shutdown (S)", delegate
            {
                StartShutdownCommand("/s /t 0");
            }),
            new PowerAction('o', "", "Sign out (O)", delegate
            {
                StartShutdownCommand("/l");
            }),
            new PowerAction('z', "", "Sleep (Z)", delegate
            {
                if (!SetSuspendState(false, false, false))
                    throw new Exception("Windows sleep request failed.");
            })
        };
    }

    static void StopPowerFadeTimer(System.Windows.Forms.Timer timer)
    {
        if (timer == null) return;
        timer.Stop();
        timer.Dispose();
    }

    static void StartPowerMenuFadeIn(
        System.Windows.Forms.Form form,
        PowerMenuAnimationState state)
    {
        if (form == null || form.IsDisposed || state == null) return;

        StopPowerFadeTimer(state.FadeInTimer);
        state.FadeInTimer = new System.Windows.Forms.Timer();
        state.FadeInTimer.Interval = 15;
        state.FadeInTimer.Tick += delegate
        {
            if (form.IsDisposed || state.FadingOut)
            {
                StopPowerFadeTimer(state.FadeInTimer);
                state.FadeInTimer = null;
                return;
            }

            form.Opacity = Math.Min(0.92, form.Opacity + 0.075);
            if (form.Opacity >= 0.919)
            {
                form.Opacity = 0.92;
                StopPowerFadeTimer(state.FadeInTimer);
                state.FadeInTimer = null;
            }
        };
        state.FadeInTimer.Start();
    }

    static void BeginPowerMenuFadeOut(
        System.Windows.Forms.Form form,
        Action afterClose)
    {
        if (form == null || form.IsDisposed)
        {
            if (afterClose != null) afterClose();
            return;
        }

        PowerMenuAnimationState state = form.Tag as PowerMenuAnimationState;
        if (state == null)
        {
            form.Close();
            if (afterClose != null) afterClose();
            return;
        }

        if (afterClose != null && state.AfterClose == null)
            state.AfterClose = afterClose;

        if (state.FadingOut) return;
        state.FadingOut = true;

        StopPowerFadeTimer(state.FadeInTimer);
        state.FadeInTimer = null;

        state.FadeOutTimer = new System.Windows.Forms.Timer();
        state.FadeOutTimer.Interval = 15;
        state.FadeOutTimer.Tick += delegate
        {
            if (form.IsDisposed)
            {
                StopPowerFadeTimer(state.FadeOutTimer);
                state.FadeOutTimer = null;
                return;
            }

            form.Opacity = Math.Max(0.0, form.Opacity - 0.075);
            if (form.Opacity <= 0.001)
            {
                StopPowerFadeTimer(state.FadeOutTimer);
                state.FadeOutTimer = null;
                state.AllowClose = true;
                form.Close();
            }
        };
        state.FadeOutTimer.Start();
    }

    static void InvokePowerAction(
        System.Windows.Forms.Form form,
        PowerAction action)
    {
        BeginPowerMenuFadeOut(
            form,
            action == null ? null : action.Invoke);
    }

    static System.Windows.Forms.Control CreatePowerTile(
        System.Windows.Forms.Form form,
        PowerAction action,
        System.Drawing.Color foreground,
        System.Drawing.Color background,
        System.Drawing.Color hover)
    {
        var tile = new System.Windows.Forms.Panel();
        tile.Dock = System.Windows.Forms.DockStyle.Fill;
        tile.Margin = new System.Windows.Forms.Padding(8);
        tile.BackColor = background;
        tile.Cursor = System.Windows.Forms.Cursors.Hand;

        var grid = new System.Windows.Forms.TableLayoutPanel();
        grid.Dock = System.Windows.Forms.DockStyle.Fill;
        grid.ColumnCount = 1;
        grid.RowCount = 2;
        grid.Margin = new System.Windows.Forms.Padding(0);
        grid.Padding = new System.Windows.Forms.Padding(0);
        grid.BackColor = System.Drawing.Color.Transparent;
        grid.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 65f));
        grid.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 35f));

        var icon = new System.Windows.Forms.Label();
        icon.Text = action.Icon;
        icon.Dock = System.Windows.Forms.DockStyle.Fill;
        icon.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
        icon.ForeColor = foreground;
        icon.BackColor = System.Drawing.Color.Transparent;
        icon.Font = new System.Drawing.Font(
            "JetBrainsMono NFP",
            42f,
            System.Drawing.FontStyle.Regular,
            System.Drawing.GraphicsUnit.Pixel);
        icon.Cursor = System.Windows.Forms.Cursors.Hand;

        var label = new System.Windows.Forms.Label();
        label.Text = action.Label;
        label.Dock = System.Windows.Forms.DockStyle.Fill;
        label.TextAlign = System.Drawing.ContentAlignment.TopCenter;
        label.ForeColor = foreground;
        label.BackColor = System.Drawing.Color.Transparent;
        label.Font = new System.Drawing.Font(
            "JetBrainsMono NFP",
            17f,
            System.Drawing.FontStyle.Regular,
            System.Drawing.GraphicsUnit.Pixel);
        label.Cursor = System.Windows.Forms.Cursors.Hand;

        grid.Controls.Add(icon, 0, 0);
        grid.Controls.Add(label, 0, 1);
        tile.Controls.Add(grid);

        EventHandler enter = delegate { tile.BackColor = hover; };
        EventHandler leave = delegate { tile.BackColor = background; };
        EventHandler click = delegate { InvokePowerAction(form, action); };

        foreach (System.Windows.Forms.Control control in new System.Windows.Forms.Control[] { tile, grid, icon, label })
        {
            control.MouseEnter += enter;
            control.MouseLeave += leave;
            control.Click += click;
        }

        return tile;
    }

    static int PowerMenu()
    {
        const string title = "WGDot Power Menu";
        IntPtr existing = FindTopLevelWindowByExactTitle(title);
        if (existing != IntPtr.Zero)
        {
            PostMessage(existing, WmClose, IntPtr.Zero, IntPtr.Zero);
            return 0;
        }

        System.Windows.Forms.Application.EnableVisualStyles();

        YasbTheme theme = FindYasbTheme(CurrentYasbThemeId()) ?? YasbThemes[0];
        System.Drawing.Color background = WgdotDrawingColor(
            theme.Background,
            System.Drawing.Color.FromArgb(53, 53, 53));
        System.Drawing.Color foreground = WgdotDrawingColor(
            theme.Foreground,
            System.Drawing.Color.Gainsboro);
        System.Drawing.Color tileBackground = WgdotDrawingColor(
            theme.Active,
            System.Drawing.Color.FromArgb(43, 43, 43));
        System.Drawing.Color tileHover = WgdotDrawingColor(
            theme.Hover,
            System.Drawing.Color.FromArgb(64, 64, 64));

        IntPtr foregroundWindow = GetForegroundWindow();
        System.Windows.Forms.Screen screen = foregroundWindow == IntPtr.Zero
            ? System.Windows.Forms.Screen.PrimaryScreen
            : System.Windows.Forms.Screen.FromHandle(foregroundWindow);

        var state = new PowerMenuAnimationState();
        var form = new System.Windows.Forms.Form();
        form.Text = title;
        form.FormBorderStyle = System.Windows.Forms.FormBorderStyle.None;
        form.StartPosition = System.Windows.Forms.FormStartPosition.Manual;
        form.Bounds = screen.Bounds;
        form.TopMost = true;
        form.ShowInTaskbar = false;
        form.KeyPreview = true;
        form.BackColor = background;
        form.Opacity = 0.0;
        form.Cursor = System.Windows.Forms.Cursors.Default;
        form.Tag = state;

        int gridWidth = Math.Min(1000, Math.Max(690, (int)(screen.Bounds.Width * 0.58)));
        int gridHeight = Math.Min(500, Math.Max(360, (int)(screen.Bounds.Height * 0.43)));

        var grid = new System.Windows.Forms.TableLayoutPanel();
        grid.ColumnCount = 3;
        grid.RowCount = 2;
        grid.Size = new System.Drawing.Size(gridWidth, gridHeight);
        grid.Location = new System.Drawing.Point(
            Math.Max(0, (screen.Bounds.Width - gridWidth) / 2),
            Math.Max(0, (screen.Bounds.Height - gridHeight) / 2));
        grid.BackColor = System.Drawing.Color.Transparent;
        grid.Margin = new System.Windows.Forms.Padding(0);
        grid.Padding = new System.Windows.Forms.Padding(0);

        for (int i = 0; i < 3; i++)
            grid.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(
                System.Windows.Forms.SizeType.Percent,
                33.333f));
        for (int i = 0; i < 2; i++)
            grid.RowStyles.Add(new System.Windows.Forms.RowStyle(
                System.Windows.Forms.SizeType.Percent,
                50f));

        List<PowerAction> actions = BuildPowerActions();
        for (int i = 0; i < actions.Count; i++)
            grid.Controls.Add(
                CreatePowerTile(
                    form,
                    actions[i],
                    foreground,
                    tileBackground,
                    tileHover),
                i % 3,
                i / 3);

        form.Controls.Add(grid);

        form.Shown += delegate
        {
            StartPowerMenuFadeIn(form, state);
        };

        form.FormClosing += delegate(
            object sender,
            System.Windows.Forms.FormClosingEventArgs e)
        {
            if (state.AllowClose) return;
            e.Cancel = true;
            BeginPowerMenuFadeOut(form, null);
        };

        form.FormClosed += delegate
        {
            StopPowerFadeTimer(state.FadeInTimer);
            StopPowerFadeTimer(state.FadeOutTimer);
            state.FadeInTimer = null;
            state.FadeOutTimer = null;

            Action afterClose = state.AfterClose;
            state.AfterClose = null;
            if (afterClose != null)
                afterClose();
        };

        form.KeyDown += delegate(
            object sender,
            System.Windows.Forms.KeyEventArgs e)
        {
            if (e.KeyCode == System.Windows.Forms.Keys.Escape)
            {
                form.Close();
                e.Handled = true;
                return;
            }

            char typed = Char.ToLowerInvariant((char)e.KeyValue);
            PowerAction action = actions.FirstOrDefault(x => x.Key == typed);
            if (action != null)
            {
                e.Handled = true;
                InvokePowerAction(form, action);
            }
        };

        form.MouseDown += delegate
        {
            form.Close();
        };

        System.Windows.Forms.Application.Run(form);
        return 0;
    }

    static string BuildYasbThemeCss(YasbTheme theme)
    {
        int red = Int32.Parse(theme.Foreground.Substring(1, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        int green = Int32.Parse(theme.Foreground.Substring(3, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        int blue = Int32.Parse(theme.Foreground.Substring(5, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);

        var lines = new List<string>();
        lines.Add("/* Generated by WGDot. Active YASB theme: " + theme.Label + " */");
        lines.Add(":root {");
        lines.Add("    --background: " + theme.Background + ";");
        lines.Add("    --foreground: " + theme.Foreground + ";");
        lines.Add("    --hover: " + theme.Hover + ";");
        lines.Add("    --focus: " + theme.Focus + ";");
        lines.Add("    --active: " + theme.Active + ";");
        lines.Add("    --urgent: " + theme.Urgent + ";");
        lines.Add("    --dark: " + theme.Dark + ";");
        lines.Add("    --charging: " + theme.Charging + ";");
        lines.Add("    --critical: " + theme.Critical + ";");
        lines.Add("    --muted: " + theme.Muted + ";");
        lines.Add(String.Format(
            CultureInfo.InvariantCulture,
            "    --subtle-hover: rgba({0}, {1}, {2}, 20);",
            red, green, blue));
        lines.Add(String.Format(
            CultureInfo.InvariantCulture,
            "    --subtle-active: rgba({0}, {1}, {2}, 26);",
            red, green, blue));
        lines.Add("    --strong-hover: rgba(115, 121, 148, 64);");
        lines.Add("}");
        lines.Add("");
        return String.Join("\r\n", lines.ToArray());
    }


    static string WindowsTerminalSettingsPath()
    {
        string localAppData = !String.IsNullOrWhiteSpace(TestRootOverride)
            ? Path.Combine(TestRootOverride, "localappdata")
            : Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);

        return Path.Combine(
            localAppData,
            "Packages",
            "Microsoft.WindowsTerminal_8wekyb3d8bbwe",
            "LocalState",
            "settings.json");
    }

    static double TerminalRelativeLuminance(string hex)
    {
        if (String.IsNullOrWhiteSpace(hex) || !Regex.IsMatch(hex, "^#[0-9A-Fa-f]{6}$"))
            return 0.0;

        Func<int, double> channel = delegate(int value)
        {
            double c = value / 255.0;
            return c <= 0.03928 ? c / 12.92 : Math.Pow((c + 0.055) / 1.055, 2.4);
        };

        int r = Int32.Parse(hex.Substring(1, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        int g = Int32.Parse(hex.Substring(3, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        int b = Int32.Parse(hex.Substring(5, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        return (0.2126 * channel(r)) + (0.7152 * channel(g)) + (0.0722 * channel(b));
    }

    static double TerminalContrastRatio(string a, string b)
    {
        double la = TerminalRelativeLuminance(a);
        double lb = TerminalRelativeLuminance(b);
        return (Math.Max(la, lb) + 0.05) / (Math.Min(la, lb) + 0.05);
    }

    static string BlendTerminalColor(string background, string foreground, double foregroundWeight)
    {
        Func<string, int, int> part = delegate(string value, int start)
        {
            return Int32.Parse(value.Substring(start, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        };

        double backWeight = 1.0 - foregroundWeight;
        int r = (int)Math.Round((part(background, 1) * backWeight) + (part(foreground, 1) * foregroundWeight));
        int g = (int)Math.Round((part(background, 3) * backWeight) + (part(foreground, 3) * foregroundWeight));
        int b = (int)Math.Round((part(background, 5) * backWeight) + (part(foreground, 5) * foregroundWeight));
        return String.Format(CultureInfo.InvariantCulture, "#{0:X2}{1:X2}{2:X2}", r, g, b);
    }

    static string ReadableTerminalColor(string candidate, YasbTheme theme, double minimumContrast, double fallbackForegroundWeight)
    {
        if (TerminalContrastRatio(candidate, theme.Background) >= minimumContrast)
            return candidate;
        return BlendTerminalColor(theme.Background, theme.Foreground, fallbackForegroundWeight);
    }

    static bool IsLightHexColor(string hex)
    {
        if (String.IsNullOrWhiteSpace(hex) ||
            !Regex.IsMatch(hex, "^#[0-9A-Fa-f]{6}$"))
            return false;

        int r = Int32.Parse(hex.Substring(1, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        int g = Int32.Parse(hex.Substring(3, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        int b = Int32.Parse(hex.Substring(5, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        return ((0.2126 * r) + (0.7152 * g) + (0.0722 * b)) >= 155.0;
    }

    static bool ApplyWindowsTerminalTheme(YasbTheme theme)
    {
        string path = WindowsTerminalSettingsPath();
        if (!File.Exists(path)) return false;

        Dictionary<string, object> root;
        try
        {
            root = Json.Deserialize<Dictionary<string, object>>(
                File.ReadAllText(path, Encoding.UTF8));
        }
        catch (Exception ex)
        {
            throw new Exception("Windows Terminal settings.json could not be parsed: " + ex.Message);
        }
        if (root == null) throw new Exception("Windows Terminal settings.json is empty.");

        string schemeName = "WGDot " + theme.Label;
        string uiThemeName = schemeName + " UI";

        Dictionary<string, object> profiles = GetDictionary(root, "profiles");
        Dictionary<string, object> defaults = GetDictionary(profiles, "defaults");
        defaults["colorScheme"] = schemeName;
        profiles["defaults"] = defaults;
        root["profiles"] = profiles;

        List<object> schemes = GetList(root, "schemes")
            .Where(raw => !GetString(AsDictionary(raw), "name")
                .StartsWith("WGDot ", StringComparison.OrdinalIgnoreCase))
            .ToList();

        var scheme = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        scheme["name"] = schemeName;
        scheme["background"] = theme.Background;
        scheme["foreground"] = theme.Foreground;
        scheme["cursorColor"] = theme.Foreground;
        scheme["selectionBackground"] = ReadableTerminalColor(theme.Focus, theme, 1.6, 0.45);
        scheme["black"] = theme.Dark;
        scheme["red"] = ReadableTerminalColor(theme.Urgent, theme, 3.0, 0.72);
        scheme["green"] = ReadableTerminalColor(theme.Charging, theme, 3.0, 0.72);
        scheme["yellow"] = ReadableTerminalColor(theme.Critical, theme, 3.0, 0.72);
        scheme["blue"] = ReadableTerminalColor(theme.Focus, theme, 3.0, 0.72);
        scheme["purple"] = ReadableTerminalColor(theme.Active, theme, 3.0, 0.72);
        scheme["cyan"] = ReadableTerminalColor(theme.Hover, theme, 4.5, 0.82);
        scheme["white"] = theme.Foreground;
        scheme["brightBlack"] = ReadableTerminalColor(theme.Muted, theme, 3.0, 0.60);
        scheme["brightRed"] = ReadableTerminalColor(theme.Urgent, theme, 4.0, 0.82);
        scheme["brightGreen"] = ReadableTerminalColor(theme.Charging, theme, 4.0, 0.82);
        scheme["brightYellow"] = ReadableTerminalColor(theme.Critical, theme, 4.0, 0.82);
        scheme["brightBlue"] = ReadableTerminalColor(theme.Focus, theme, 4.0, 0.82);
        scheme["brightPurple"] = ReadableTerminalColor(theme.Active, theme, 4.0, 0.82);
        scheme["brightCyan"] = ReadableTerminalColor(theme.Hover, theme, 4.5, 0.90);
        scheme["brightWhite"] = theme.Foreground;
        schemes.Add(scheme);
        root["schemes"] = schemes.ToArray();

        List<object> uiThemes = GetList(root, "themes")
            .Where(raw => !GetString(AsDictionary(raw), "name")
                .StartsWith("WGDot ", StringComparison.OrdinalIgnoreCase))
            .ToList();

        var window = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        window["applicationTheme"] = IsLightHexColor(theme.Background) ? "light" : "dark";
        window["useMica"] = false;
        var tab = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        tab["background"] = "terminalBackground";
        tab["unfocusedBackground"] = theme.Background;
        var tabRow = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        tabRow["background"] = theme.Background;
        tabRow["unfocusedBackground"] = theme.Background;
        var uiTheme = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        uiTheme["name"] = uiThemeName;
        uiTheme["window"] = window;
        uiTheme["tab"] = tab;
        uiTheme["tabRow"] = tabRow;
        uiThemes.Add(uiTheme);
        root["themes"] = uiThemes.ToArray();
        root["theme"] = uiThemeName;

        WriteTextAtomic(path, Json.Serialize(root) + Environment.NewLine);
        return true;
    }

    static void SignalIdleInhibitorStop()
    {
        try
        {
            using (var stop = System.Threading.EventWaitHandle.OpenExisting(IdleInhibitorStopEventName))
                stop.Set();
        }
        catch (System.Threading.WaitHandleCannotBeOpenedException) { }
    }

    static int BarAutoHideToggle()
    {
        string profile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        string yasbPath = Path.Combine(profile, ".config", "yasb", "config.yaml");
        string glazePath = Path.Combine(profile, ".glzr", "glazewm", "config.yaml");

        if (!File.Exists(yasbPath))
            throw new Exception("YASB config was not found: " + yasbPath);
        if (!File.Exists(glazePath))
            throw new Exception("GlazeWM config was not found: " + glazePath);

        string yasbOriginal = File.ReadAllText(yasbPath);
        string glazeOriginal = File.ReadAllText(glazePath);

        MatchCollection autoMatches = Regex.Matches(
            yasbOriginal,
            @"(?m)^(\s*)auto_hide:\s*(true|false)\s*$",
            RegexOptions.IgnoreCase);
        if (autoMatches.Count != 1)
            throw new Exception(
                "Expected exactly one YASB auto_hide setting, found " +
                autoMatches.Count.ToString(CultureInfo.InvariantCulture) + ".");

        bool currentAutoHide = String.Equals(
            autoMatches[0].Groups[2].Value,
            "true",
            StringComparison.OrdinalIgnoreCase);
        bool enableAutoHide = !currentAutoHide;

        MatchCollection topGapMatches = Regex.Matches(
            glazeOriginal,
            @"(?m)^(\s*)top:\s*""(5|35)px""\s*$");
        if (topGapMatches.Count != 1)
            throw new Exception(
                "Expected exactly one GlazeWM 5/35 px top gap, found " +
                topGapMatches.Count.ToString(CultureInfo.InvariantCulture) + ".");

        string yasbNext = Regex.Replace(
            yasbOriginal,
            @"(?m)^(\s*)auto_hide:\s*(true|false)\s*$",
            m => m.Groups[1].Value + "auto_hide: " + (enableAutoHide ? "true" : "false"));

        string glazeNext = Regex.Replace(
            glazeOriginal,
            @"(?m)^(\s*)top:\s*""(5|35)px""\s*$",
            m => m.Groups[1].Value + "top: \"" + (enableAutoHide ? "5" : "35") + "px\"");

        try
        {
            WriteTextAtomic(yasbPath, yasbNext);
            WriteTextAtomic(glazePath, glazeNext);

            ProcResult yasbReload = Run("yasbc.exe", "reload -s", null);
            if (yasbReload.ExitCode != 0)
                throw new Exception(
                    "YASB reload failed: " +
                    LastUsefulLine(yasbReload.StdErr + "\n" + yasbReload.StdOut));

            ProcResult glazeReload = Run(RequireGlazeWmExe(), "command wm-reload-config", null);
            if (glazeReload.ExitCode != 0)
                throw new Exception(
                    "GlazeWM reload failed: " +
                    LastUsefulLine(glazeReload.StdErr + "\n" + glazeReload.StdOut));
            // GlazeWM reload clears active binding modes upstream.
            WriteTrackedGlazeBindingMode("");
        }
        catch
        {
            WriteTextAtomic(yasbPath, yasbOriginal);
            WriteTextAtomic(glazePath, glazeOriginal);
            try { Run("yasbc.exe", "reload -s", null); } catch { }
            try { Run("glazewm.exe", "command wm-reload-config", null); } catch { }
            WriteTrackedGlazeBindingMode("");
            throw;
        }

        Console.WriteLine(
            "YASB auto-hide " + (enableAutoHide ? "enabled" : "disabled") +
            "; GlazeWM top gap set to " + (enableAutoHide ? "5px" : "35px") + ".");
        Console.WriteLine("YASB and GlazeWM reloaded.");
        return 0;
    }

    static int RawAccelToggle()
    {
        Process[] running = Process.GetProcessesByName("rawaccel");
        if (running.Length > 0)
        {
            var failures = new List<string>();
            foreach (Process process in running)
            {
                try
                {
                    process.Kill();
                }
                catch (Exception ex)
                {
                    failures.Add(process.Id.ToString(CultureInfo.InvariantCulture) + ": " + ex.Message);
                }
            }

            if (failures.Count > 0)
                throw new Exception("Failed to close RawAccel GUI process(es): " + String.Join("; ", failures.ToArray()));

            return 0;
        }

        var candidates = new List<string>();

        ProcResult where = Run("where.exe", "rawaccel.exe", null);
        if (where.ExitCode == 0)
        {
            foreach (string line in (where.StdOut ?? "").Replace("\r", "").Split('\n'))
            {
                string candidate = line.Trim();
                if (!String.IsNullOrWhiteSpace(candidate))
                    candidates.Add(candidate);
            }
        }

        string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);

        candidates.Add(Path.Combine(localAppData, "RawAccel", "rawaccel.exe"));
        candidates.Add(Path.Combine(localAppData, "Programs", "RawAccel", "rawaccel.exe"));
        if (!String.IsNullOrWhiteSpace(programFiles))
            candidates.Add(Path.Combine(programFiles, "RawAccel", "rawaccel.exe"));

        string exe = candidates.FirstOrDefault(path =>
            !String.IsNullOrWhiteSpace(path) && File.Exists(path));
        if (String.IsNullOrWhiteSpace(exe))
            throw new Exception("RawAccel GUI executable was not found.");

        var psi = new ProcessStartInfo();
        psi.FileName = exe;
        psi.WorkingDirectory = Path.GetDirectoryName(exe);
        psi.UseShellExecute = true;
        Process started = Process.Start(psi);
        if (started == null)
            throw new Exception("RawAccel GUI did not start.");

        return 0;
    }

    sealed class WindowAuditRow
    {
        public string ProcessName;
        public int ProcessId;
        public string Title;
        public string Executable;
    }

    static int WindowAudit()
    {
        var rows = new List<WindowAuditRow>();

        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam)
        {
            if (!IsWindowVisible(hWnd) || IsDwmCloaked(hWnd))
                return true;

            int titleLength = GetWindowTextLength(hWnd);
            if (titleLength <= 0)
                return true;

            var title = new StringBuilder(titleLength + 1);
            GetWindowText(hWnd, title, title.Capacity);
            string titleText = title.ToString().Trim();
            if (String.IsNullOrWhiteSpace(titleText))
                return true;

            uint processId;
            GetWindowThreadProcessId(hWnd, out processId);
            if (processId == 0)
                return true;

            try
            {
                using (Process process = Process.GetProcessById((int)processId))
                {
                    string executable = "";
                    try
                    {
                        executable = process.MainModule == null
                            ? ""
                            : process.MainModule.FileName;
                    }
                    catch
                    {
                    }

                    rows.Add(new WindowAuditRow
                    {
                        ProcessName = process.ProcessName ?? "",
                        ProcessId = (int)processId,
                        Title = titleText,
                        Executable = executable
                    });
                }
            }
            catch
            {
            }

            return true;
        }, IntPtr.Zero);

        rows = rows
            .OrderBy(x => x.ProcessName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(x => x.Title, StringComparer.OrdinalIgnoreCase)
            .ToList();

        Console.WriteLine("Visible top-level windows for GlazeWM rule matching");
        Console.WriteLine("GlazeWM window_process should match PROCESS, not the WinGet package ID.");
        Console.WriteLine();

        foreach (WindowAuditRow row in rows)
        {
            Console.WriteLine(
                "PROCESS: " + row.ProcessName +
                "    PID: " + row.ProcessId.ToString(CultureInfo.InvariantCulture));
            Console.WriteLine("TITLE:   " + row.Title);
            if (!String.IsNullOrWhiteSpace(row.Executable))
                Console.WriteLine("EXE:     " + row.Executable);
            Console.WriteLine();
        }

        return 0;
    }

    static void SignalMouseModeHookStop()
    {
        try
        {
            using (var stop = System.Threading.EventWaitHandle.OpenExisting(MouseModeStopEventName))
                stop.Set();
        }
        catch (System.Threading.WaitHandleCannotBeOpenedException)
        {
        }
    }

    static bool NamedMutexExists(string name)
    {
        try
        {
            using (System.Threading.Mutex mutex = System.Threading.Mutex.OpenExisting(name))
                return true;
        }
        catch (System.Threading.WaitHandleCannotBeOpenedException)
        {
            return false;
        }
    }

    static void WriteTrackedGlazeBindingMode(string mode)
    {
        var state = new Dictionary<string, object>();
        state["mode"] = (mode ?? "").Trim().ToLowerInvariant();
        state["updatedAt"] = DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture);
        WriteJson(GlazeBindingModeStatePath, state);
    }

    static string ReadTrackedGlazeBindingMode()
    {
        Dictionary<string, object> state = ReadJson(GlazeBindingModeStatePath);
        return state == null ? "" : GetString(state, "mode").Trim().ToLowerInvariant();
    }

    static string GetActiveGlazeWmBindingMode()
    {
        ProcResult result = Run(RequireGlazeWmExe(), "query binding-modes", null);
        Dictionary<string, object> response =
            RequireGlazeWmSuccess(result, "GlazeWM binding-mode query");

        object dataObject;
        if (!response.TryGetValue("data", out dataObject) || dataObject == null)
            throw new Exception("GlazeWM binding-mode query returned no data.");

        Dictionary<string, object> data = AsDictionary(dataObject);
        object modesObject;
        if (!data.TryGetValue("bindingModes", out modesObject) || modesObject == null)
            throw new Exception("GlazeWM binding-mode query returned no bindingModes list.");

        IEnumerable modes = modesObject as IEnumerable;
        if (modes == null)
            throw new Exception("GlazeWM binding-mode query returned invalid bindingModes data.");

        foreach (object modeObject in modes)
        {
            Dictionary<string, object> mode = AsDictionary(modeObject);
            object modeName;
            if (mode.TryGetValue("name", out modeName))
                return Convert.ToString(modeName) ?? "";
        }

        return "";
    }

    static bool TryGetActiveGlazeWmBindingMode(out string activeMode)
    {
        // GlazeWM's query returns the full active BindingModeConfig including
        // every keybinding. Large modes can make the CLI IPC client fail to
        // receive that response even though command IPC remains healthy.
        // Retry transient failures, then let toggle logic use command behavior
        // to distinguish "same mode" from "different active mode".
        for (int i = 0; i < 5; i++)
        {
            try
            {
                activeMode = GetActiveGlazeWmBindingMode();
                return true;
            }
            catch
            {
                if (i < 4)
                    System.Threading.Thread.Sleep(50);
            }
        }

        activeMode = "";
        return false;
    }

    static void SetGlazeWmBindingMode(string name, bool enabled)
    {
        string verb = enabled ? "wm-enable-binding-mode" : "wm-disable-binding-mode";
        ProcResult result = Run(
            RequireGlazeWmExe(),
            "command " + verb + " --name " + Q(name),
            null);
        RequireGlazeWmSuccess(
            result,
            "GlazeWM binding mode " + (enabled ? "enable" : "disable") + " '" + name + "'");

        if (enabled)
        {
            WriteTrackedGlazeBindingMode(name);
        }
        else if (String.Equals(
                     ReadTrackedGlazeBindingMode(),
                     name,
                     StringComparison.OrdinalIgnoreCase))
        {
            WriteTrackedGlazeBindingMode("");
        }
    }

    static void RetireLegacyMouseMode(bool disableBindingMode)
    {
        SignalMouseModeHookStop();

        if (!disableBindingMode)
            return;

        try
        {
            SetGlazeWmBindingMode("mouse", false);
        }
        catch
        {
            if (String.Equals(
                    ReadTrackedGlazeBindingMode(),
                    "mouse",
                    StringComparison.OrdinalIgnoreCase))
                WriteTrackedGlazeBindingMode("");
        }
    }

    static int GlazeWmBindingModeToggleFromArgs(string[] args)
    {
        if (args.Length != 1 ||
            !(String.Equals(args[0], "noalt", StringComparison.OrdinalIgnoreCase) ||
              String.Equals(args[0], "vm", StringComparison.OrdinalIgnoreCase)))
            throw new Exception("glazewm-binding-mode-toggle requires exactly one target: noalt or vm.");

        string mode = args[0].ToLowerInvariant();
        string activeMode;
        if (TryGetActiveGlazeWmBindingMode(out activeMode))
            WriteTrackedGlazeBindingMode(activeMode);
        else
            activeMode = ReadTrackedGlazeBindingMode();

        if (String.Equals(activeMode, mode, StringComparison.OrdinalIgnoreCase))
        {
            SetGlazeWmBindingMode(mode, false);
            return 0;
        }

        RetireLegacyMouseMode(
            String.Equals(activeMode, "mouse", StringComparison.OrdinalIgnoreCase) ||
            NamedMutexExists(MouseModeMutexName));

        SetGlazeWmBindingMode(mode, true);
        return 0;
    }

    static int GlazeWmBindingModeSetFromArgs(string[] args)
    {
        if (args.Length != 1)
            throw new Exception("glazewm-binding-mode-set requires exactly one target: normal, noalt, or vm.");

        string mode = args[0].Trim().ToLowerInvariant();
        if (!(mode == "normal" || mode == "noalt" || mode == "vm"))
            throw new Exception("glazewm-binding-mode-set requires exactly one target: normal, noalt, or vm.");

        string tracked = ReadTrackedGlazeBindingMode();

        if (mode == "normal")
        {
            bool legacyMouse =
                String.Equals(tracked, "mouse", StringComparison.OrdinalIgnoreCase) ||
                NamedMutexExists(MouseModeMutexName);
            RetireLegacyMouseMode(legacyMouse);

            if (!legacyMouse)
            {
                if (String.Equals(tracked, "noalt", StringComparison.OrdinalIgnoreCase) ||
                    String.Equals(tracked, "vm", StringComparison.OrdinalIgnoreCase))
                    SetGlazeWmBindingMode(tracked, false);
                else
                {
                    SetGlazeWmBindingMode("noalt", false);
                    SetGlazeWmBindingMode("vm", false);
                }
            }

            WriteTrackedGlazeBindingMode("");
            return 0;
        }

        RetireLegacyMouseMode(
            String.Equals(tracked, "mouse", StringComparison.OrdinalIgnoreCase) ||
            NamedMutexExists(MouseModeMutexName));

        SetGlazeWmBindingMode(mode, true);
        return 0;
    }

    static Dictionary<string, object> RequireGlazeWmSuccess(
        ProcResult result,
        string operation)
    {
        if (result == null)
            throw new Exception(operation + " failed: no GlazeWM process result.");

        if (result.ExitCode != 0)
        {
            string detail = LastUsefulLine((result.StdErr ?? "") + "\n" + (result.StdOut ?? ""));
            throw new Exception(
                operation + " failed with exit " +
                result.ExitCode.ToString(CultureInfo.InvariantCulture) +
                (String.IsNullOrWhiteSpace(detail) ? "." : ": " + detail));
        }

        if (String.IsNullOrWhiteSpace(result.StdOut))
            throw new Exception(operation + " failed: GlazeWM returned no IPC response.");

        Dictionary<string, object> response;
        try
        {
            response = AsDictionary(Json.DeserializeObject(result.StdOut.Trim()));
        }
        catch (Exception ex)
        {
            throw new Exception(operation + " failed: invalid GlazeWM IPC JSON: " + ex.Message);
        }

        object rawSuccess;
        if (!response.TryGetValue("success", out rawSuccess) || !(rawSuccess is bool))
            throw new Exception(operation + " failed: GlazeWM IPC response is missing a boolean success field.");

        if (!(bool)rawSuccess)
        {
            string error = GetString(response, "error");
            if (String.IsNullOrWhiteSpace(error))
                error = GetString(response, "clientMessage");
            if (String.IsNullOrWhiteSpace(error))
                error = "GlazeWM rejected the request.";
            throw new Exception(operation + " failed: " + error);
        }

        return response;
    }

    static void SignalSuperLTestStop()
    {
        try
        {
            using (var stop = System.Threading.EventWaitHandle.OpenExisting(SuperLTestStopEventName))
                stop.Set();
        }
        catch (System.Threading.WaitHandleCannotBeOpenedException)
        {
        }
    }

    static void StartSuperLHookWorker()
    {
        string exe = Process.GetCurrentProcess().MainModule.FileName;
        var psi = new ProcessStartInfo();
        psi.FileName = exe;
        psi.Arguments = "super-l-hook";
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.WindowStyle = ProcessWindowStyle.Hidden;
        psi.EnvironmentVariables["WGDOT_SKIP_RUNTIME_REFRESH"] = "1";

        Process process = Process.Start(psi);
        if (process == null)
            throw new Exception("Failed to start the WGDot Super+L test hook.");
    }

    static int SuperLTestFromArgs(string[] args)
    {
        if (args.Length != 1)
        {
            Console.Error.WriteLine("Usage: wgdot super-l-test <start|stop|status>");
            return 2;
        }

        string action = args[0].Trim().ToLowerInvariant();
        if (action == "status")
        {
            Console.WriteLine(
                "Super+L focus-right test hook: " +
                (NamedMutexExists(SuperLTestMutexName) ? "running" : "stopped"));
            return 0;
        }

        if (action == "stop")
        {
            SignalSuperLTestStop();
            for (int i = 0; i < 20 && NamedMutexExists(SuperLTestMutexName); i++)
                System.Threading.Thread.Sleep(50);
            Console.WriteLine("Super+L focus-right test hook stopped.");
            return 0;
        }

        if (action != "start")
        {
            Console.Error.WriteLine("Usage: wgdot super-l-test <start|stop|status>");
            return 2;
        }

        if (NamedMutexExists(SuperLTestMutexName))
        {
            Console.WriteLine("Super+L focus-right test hook is already running.");
            return 0;
        }

        StartSuperLHookWorker();
        for (int i = 0; i < 30 && !NamedMutexExists(SuperLTestMutexName); i++)
            System.Threading.Thread.Sleep(50);

        if (!NamedMutexExists(SuperLTestMutexName))
            throw new Exception("Super+L focus-right test hook did not start.");

        Console.WriteLine("Super+L focus-right test hook started.");
        Console.WriteLine("Press Super+L with two adjacent tiled windows. It should focus right instead of locking.");
        Console.WriteLine("Stop test: wgdot super-l-test stop");
        return 0;
    }

    static void FocusRightFromSuperL()
    {
        ProcResult result = Run(RequireGlazeWmExe(), "command focus --direction right", null);
        if (result.ExitCode != 0)
            Console.Error.WriteLine(
                "Super+L focus-right command failed: " +
                LastUsefulLine(result.StdErr + "\n" + result.StdOut));
    }

    static IntPtr SuperLHookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode < 0)
            return CallNextHookEx(SuperLHookHandle, nCode, wParam, lParam);

        KBDLLHOOKSTRUCT data =
            (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));

        if ((data.flags & LlKhfInjected) != 0)
            return CallNextHookEx(SuperLHookHandle, nCode, wParam, lParam);

        int message = unchecked((int)wParam.ToInt64());
        bool down = message == WmKeyDown || message == WmSysKeyDown;
        bool up = message == WmKeyUp || message == WmSysKeyUp;

        if (data.vkCode == VkLwin)
        {
            if (down) SuperLLeftWinDown = true;
            if (up) SuperLLeftWinDown = false;
            return CallNextHookEx(SuperLHookHandle, nCode, wParam, lParam);
        }

        if (data.vkCode == VkRwin)
        {
            if (down) SuperLRightWinDown = true;
            if (up) SuperLRightWinDown = false;
            return CallNextHookEx(SuperLHookHandle, nCode, wParam, lParam);
        }

        if (data.vkCode == VkL && down && (SuperLLeftWinDown || SuperLRightWinDown))
        {
            if (!SuperLSuppressKeyUp)
            {
                SuperLSuppressKeyUp = true;
                System.Threading.ThreadPool.QueueUserWorkItem(
                    delegate { FocusRightFromSuperL(); });
            }
            return new IntPtr(1);
        }

        if (data.vkCode == VkL && up && SuperLSuppressKeyUp)
        {
            SuperLSuppressKeyUp = false;
            return new IntPtr(1);
        }

        return CallNextHookEx(SuperLHookHandle, nCode, wParam, lParam);
    }

    static int SuperLHookWorker()
    {
        bool createdNew;
        using (var mutex = new System.Threading.Mutex(true, SuperLTestMutexName, out createdNew))
        {
            if (!createdNew)
                return 0;

            using (var stop = new System.Threading.EventWaitHandle(
                false,
                System.Threading.EventResetMode.ManualReset,
                SuperLTestStopEventName))
            {
                stop.Reset();
                SuperLLeftWinDown = false;
                SuperLRightWinDown = false;
                SuperLSuppressKeyUp = false;

                SuperLHookProc = SuperLHookCallback;
                SuperLHookHandle = SetWindowsHookExKeyboard(
                    WhKeyboardLl,
                    SuperLHookProc,
                    GetModuleHandle(null),
                    0);

                if (SuperLHookHandle == IntPtr.Zero)
                    throw new System.ComponentModel.Win32Exception(
                        Marshal.GetLastWin32Error(),
                        "Failed to install WGDot Super+L test hook.");

                var timer = new System.Windows.Forms.Timer();
                timer.Interval = 250;
                timer.Tick += delegate
                {
                    if (stop.WaitOne(0) || Process.GetProcessesByName("glazewm").Length == 0)
                        System.Windows.Forms.Application.ExitThread();
                };

                try
                {
                    timer.Start();
                    System.Windows.Forms.Application.Run();
                }
                finally
                {
                    timer.Stop();
                    timer.Dispose();
                    if (SuperLHookHandle != IntPtr.Zero)
                    {
                        UnhookWindowsHookEx(SuperLHookHandle);
                        SuperLHookHandle = IntPtr.Zero;
                    }
                    SuperLHookProc = null;
                    SuperLLeftWinDown = false;
                    SuperLRightWinDown = false;
                    SuperLSuppressKeyUp = false;
                }
            }
        }

        return 0;
    }

    static IntPtr FindTopLevelWindowByExactTitle(string title)
    {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam)
        {
            int length = GetWindowTextLength(hWnd);
            if (length <= 0) return true;

            var text = new StringBuilder(length + 1);
            GetWindowText(hWnd, text, text.Capacity);
            if (!String.Equals(text.ToString(), title, StringComparison.Ordinal))
                return true;

            found = hWnd;
            return false;
        }, IntPtr.Zero);
        return found;
    }

    static bool IsDwmCloaked(IntPtr hWnd)
    {
        int cloaked;
        return hWnd != IntPtr.Zero &&
            DwmGetWindowAttribute(hWnd, DwmwaCloaked, out cloaked, sizeof(int)) == 0 &&
            cloaked != 0;
    }

    static string CurrentCursorThemeId()
    {
        Dictionary<string, object> state = ReadJson(CursorStatePath);
        string id = state == null ? "" : GetString(state, "id");
        if (CursorThemeLabels.ContainsKey(id)) return id;

        InstallationSelection selection = ReadInstallationSelection();
        if (selection != null && selection.Tweaks != null &&
            selection.Tweaks.Contains("oops-all-links-cursor", StringComparer.OrdinalIgnoreCase))
            return "oops-all-links";

        return "bibata-modern-ice";
    }

    static void WriteCursorState(string id)
    {
        var state = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        state["id"] = id;
        state["label"] = CursorThemeLabels.ContainsKey(id) ? CursorThemeLabels[id] : id;
        state["appliedAt"] = DateTime.UtcNow.ToString("o");
        WriteJson(CursorStatePath, state);
    }

    static int CursorManagerFromArgs(string[] args)
    {
        if (args == null || args.Length == 0) return CursorManager();
        if (args.Length != 1)
        {
            Console.Error.WriteLine("Usage: wgdot cursor [cursor-id]");
            return 2;
        }
        return ApplyCursorTheme(args[0]);
    }

    static int CursorManager()
    {
        while (true)
        {
            string current = CurrentCursorThemeId();
            var items = new List<string>();
            foreach (string id in CursorThemeIds)
            {
                bool active = String.Equals(id, current, StringComparison.OrdinalIgnoreCase);
                items.Add((active ? "* " : "  ") + CursorThemeLabels[id]);
            }
            items.Add("Back");

            int currentIndex = Array.FindIndex(
                CursorThemeIds,
                x => String.Equals(x, current, StringComparison.OrdinalIgnoreCase));
            if (currentIndex < 0) currentIndex = 0;

            int choice = ReadSingleChoice(
                "Cursor themes - Awtarchy Bibata variants + Oops",
                items,
                currentIndex);
            if (choice < 0 || choice >= CursorThemeIds.Length) return 0;
            ApplyCursorTheme(CursorThemeIds[choice]);
        }
    }

    static Dictionary<string, string> ParseCursorInfStrings(string infPath)
    {
        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        bool inStrings = false;
        foreach (string rawLine in File.ReadAllLines(infPath))
        {
            string line = rawLine.Trim();
            if (line.StartsWith("[", StringComparison.Ordinal) &&
                line.EndsWith("]", StringComparison.Ordinal))
            {
                inStrings = String.Equals(line, "[Strings]", StringComparison.OrdinalIgnoreCase);
                continue;
            }
            if (!inStrings || line.Length == 0 || line.StartsWith(";", StringComparison.Ordinal))
                continue;

            int equals = line.IndexOf('=');
            if (equals <= 0) continue;
            string key = line.Substring(0, equals).Trim();
            string value = line.Substring(equals + 1).Trim();
            if (value.Length >= 2 && value[0] == '"' && value[value.Length - 1] == '"')
                value = value.Substring(1, value.Length - 2);
            if (!String.IsNullOrWhiteSpace(key) && !String.IsNullOrWhiteSpace(value))
                values[key] = value;
        }
        return values;
    }

    static string EnsureBibataCursorFiles(string cursorId)
    {
        string assetStem;
        if (!BibataCursorAssets.TryGetValue(cursorId, out assetStem))
            throw new Exception("Unknown Bibata cursor id: " + cursorId);

        string regularDirectoryName = assetStem + "-Regular-Windows";
        string cursorRoot = Path.Combine(InstallRoot, "cursors");
        string destination = Path.Combine(cursorRoot, regularDirectoryName);
        if (File.Exists(Path.Combine(destination, "install.inf"))) return destination;

        Directory.CreateDirectory(cursorRoot);
        var package = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        package["name"] = assetStem + " cursor";
        package["fallbackGitHubRepo"] = "ful1e5/Bibata_Cursor";
        package["fallbackAssetRegex"] = "^" + Regex.Escape(assetStem + "-Windows.zip") + "$";

        string assetName;
        string zipPath = DownloadOfficialGitHubPackageAsset(package, out assetName);
        using (FileStream stream = File.OpenRead(zipPath))
        {
            if (stream.ReadByte() != 0x50 || stream.ReadByte() != 0x4B)
                throw new Exception("Bibata release asset was not a valid ZIP archive.");
        }

        string extractRoot = Path.Combine(CacheRoot, "bibata-cursor-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(extractRoot);
        try
        {
            ExtractZipToDirectorySafe(zipPath, extractRoot);
            string extracted = Path.Combine(extractRoot, regularDirectoryName);
            if (!Directory.Exists(extracted) ||
                !File.Exists(Path.Combine(extracted, "install.inf")))
                throw new Exception("Bibata archive is missing the expected regular Windows cursor directory.");
            if (Directory.Exists(destination)) Directory.Delete(destination, true);
            Directory.Move(extracted, destination);
        }
        finally { SafeDeleteDirectory(extractRoot); }

        return destination;
    }

    static int ApplyBibataCursor(string cursorId)
    {
        const string snapshotId = "bibata-cursor-theme";
        RestoreRegistryOriginals("oops-all-links-cursor");
        RestoreRegistryOriginals(snapshotId);

        string themeDir = EnsureBibataCursorFiles(cursorId);
        Dictionary<string, string> inf =
            ParseCursorInfStrings(Path.Combine(themeDir, "install.inf"));

        string[,] mappings = new string[,]
        {
            { "Arrow", "pointer" }, { "Help", "help" }, { "AppStarting", "work" },
            { "Wait", "busy" }, { "Crosshair", "cross" }, { "precisionhair", "cross" },
            { "IBeam", "text" }, { "NWPen", "handwriting" }, { "No", "unavailable" },
            { "SizeNS", "vert" }, { "SizeWE", "horz" }, { "SizeNWSE", "dgn1" },
            { "SizeNESW", "dgn2" }, { "Grab", "move" }, { "SizeAll", "move" },
            { "UpArrow", "alternate" }, { "Hand", "link" }, { "Pin", "pin" },
            { "Person", "person" }, { "Pan", "pan" }, { "Grabbing", "grabbing" },
            { "Zoom-in", "zoom-in" }, { "Zoom-out", "zoom-out" }
        };

        var variables = new[]
        {
            "pointer", "help", "work", "busy", "cross", "text", "handwriting",
            "unavailable", "vert", "horz", "dgn1", "dgn2", "move", "alternate",
            "link", "pin", "person", "pan", "grabbing", "zoom-in", "zoom-out"
        };

        for (int i = 0; i < mappings.GetLength(0); i++)
        {
            string fileName;
            if (!inf.TryGetValue(mappings[i, 1], out fileName) ||
                String.IsNullOrWhiteSpace(fileName))
                throw new Exception("Bibata install.inf is missing cursor mapping '" + mappings[i, 1] + "'.");
            string path = Path.Combine(themeDir, fileName);
            if (!File.Exists(path))
                throw new Exception("Bibata cursor archive is missing expected file: " + fileName);
            SetRegistryValueWithSnapshot(
                snapshotId, "HKCU", @"Control Panel\Cursors",
                mappings[i, 0], path, RegistryValueKind.String);
        }

        var schemePaths = new List<string>();
        foreach (string variable in variables)
        {
            string fileName;
            if (!inf.TryGetValue(variable, out fileName) || String.IsNullOrWhiteSpace(fileName))
                throw new Exception("Bibata install.inf is missing scheme mapping '" + variable + "'.");
            schemePaths.Add(Path.Combine(themeDir, fileName));
        }

        string schemeName;
        if (!inf.TryGetValue("SCHEME_NAME", out schemeName) || String.IsNullOrWhiteSpace(schemeName))
            schemeName = CursorThemeLabels[cursorId];

        SetRegistryValueWithSnapshot(
            snapshotId, "HKCU", @"Control Panel\Cursors",
            "", schemeName, RegistryValueKind.String);
        SetRegistryValueWithSnapshot(
            snapshotId, "HKCU", @"Control Panel\Cursors\Schemes",
            schemeName, String.Join(",", schemePaths.ToArray()), RegistryValueKind.String);

        SystemParametersInfo(0x0057, 0, IntPtr.Zero, 0x01 | 0x02);
        WriteCursorState(cursorId);
        Console.WriteLine("Cursor theme applied: " + CursorThemeLabels[cursorId]);
        return 0;
    }

    static int ApplyCursorTheme(string requestedId)
    {
        string id = (requestedId ?? "").Trim().Replace("_", "-").ToLowerInvariant();
        if (id == "default") id = "windows-default";
        if (!CursorThemeLabels.ContainsKey(id))
        {
            Console.Error.WriteLine("Unknown cursor theme: " + requestedId);
            Console.Error.WriteLine("Run 'wgdot cursor' to choose a supported cursor theme.");
            return 2;
        }

        if (id == "windows-default")
        {
            RestoreRegistryOriginals("bibata-cursor-theme");
            RestoreRegistryOriginals("oops-all-links-cursor");
            SystemParametersInfo(0x0057, 0, IntPtr.Zero, 0x01 | 0x02);
            WriteCursorState(id);
            Console.WriteLine("Cursor registry values restored to their pre-WGDot state.");
            return 0;
        }
        if (id == "oops-all-links")
        {
            ApplyOopsCursor(true);
            return 0;
        }
        return ApplyBibataCursor(id);
    }

    static void EnsureCursorTheme()
    {
        if (ApplyCursorTheme(CurrentCursorThemeId()) != 0)
            throw new Exception("Failed to apply the remembered cursor theme.");
    }

    static void SignalDesktopWorkerStop()
    {
        try
        {
            using (var stop = System.Threading.EventWaitHandle.OpenExisting(DesktopWorkerStopEventName))
                stop.Set();
        }
        catch (System.Threading.WaitHandleCannotBeOpenedException)
        {
        }
    }

    static string FindRegisteredAppPath(string fileName)
    {
        string subKey = @"Software\Microsoft\Windows\CurrentVersion\App Paths\" + fileName;
        foreach (RegistryKey root in new[] { Registry.CurrentUser, Registry.LocalMachine })
        {
            try
            {
                using (RegistryKey key = root.OpenSubKey(subKey, false))
                {
                    if (key == null) continue;
                    string registered = Convert.ToString(key.GetValue(null, ""));
                    if (!String.IsNullOrWhiteSpace(registered) && File.Exists(registered))
                        return registered;
                }
            }
            catch
            {
            }
        }
        return "";
    }

    static void ApplyCleanTaskbar(bool enable)
    {
        const string id = "clean-taskbar-items";
        if (!enable)
        {
            RestoreRegistryOriginals(id);
            return;
        }

        SetRegistryValueWithSnapshot(id, "HKCU",
            @"Software\Microsoft\Windows\CurrentVersion\Search",
            "SearchboxTaskbarMode", 0, RegistryValueKind.DWord);
        Console.WriteLine("Taskbar Search hidden.");
        SetRegistryValueWithSnapshot(id, "HKCU",
            @"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
            "ShowTaskViewButton", 0, RegistryValueKind.DWord);
        const string advancedPath =
            @"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";
        try
        {
            SetRegistryValueWithSnapshot(
                id,
                "HKCU",
                advancedPath,
                "TaskbarDa",
                0,
                RegistryValueKind.DWord);
        }
        catch (UnauthorizedAccessException)
        {
            // Some current Windows builds protect TaskbarDa even though the
            // surrounding Explorer\Advanced values remain writable. The
            // failed write made no mutation, so do not retain a rollback
            // snapshot for that value. Use Microsoft's machine policy for
            // Widgets as the bounded elevated fallback instead.
            DiscardRegistryOriginalSnapshot(id, "HKCU", advancedPath, "TaskbarDa");

            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine(
                "Windows protected the TaskbarDa Widgets value; " +
                "using the supported Widgets policy fallback.");
            Console.ResetColor();

            SetRegistryValueWithSnapshot(
                id,
                "HKLM",
                @"SOFTWARE\Policies\Microsoft\Dsh",
                "AllowNewsAndInterests",
                0,
                RegistryValueKind.DWord);
        }
        SetRegistryValueWithSnapshot(id, "HKCU",
            @"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
            "TaskbarMn", 0, RegistryValueKind.DWord);
        SetRegistryValueWithSnapshot(id, "HKCU",
            @"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
            "ShowCopilotButton", 0, RegistryValueKind.DWord);
    }

    static void ApplyPrintScreenSnipping(bool enable)
    {
        const string id = "disable-printscreen-snipping";
        if (!enable)
        {
            RestoreRegistryOriginals(id);
            return;
        }

        SetRegistryValueWithSnapshot(id, "HKCU",
            @"Control Panel\Keyboard",
            "PrintScreenKeyForSnippingEnabled", 0, RegistryValueKind.DWord);
    }

    static void ApplyPointerPrecision(bool enable)
    {
        const string id = "disable-enhanced-pointer-precision";
        if (!enable)
        {
            RestoreRegistryOriginals(id);
            return;
        }

        SetRegistryValueWithSnapshot(id, "HKCU", @"Control Panel\Mouse", "MouseSpeed", "0", RegistryValueKind.String);
        SetRegistryValueWithSnapshot(id, "HKCU", @"Control Panel\Mouse", "MouseThreshold1", "0", RegistryValueKind.String);
        SetRegistryValueWithSnapshot(id, "HKCU", @"Control Panel\Mouse", "MouseThreshold2", "0", RegistryValueKind.String);
    }

    static void ApplyCommunicationsDucking(bool enable)
    {
        const string id = "communications-do-nothing";
        if (!enable)
        {
            RestoreRegistryOriginals(id);
            return;
        }

        SetRegistryValueWithSnapshot(id, "HKCU",
            @"Software\Microsoft\Multimedia\Audio",
            "UserDuckingPreference", 3, RegistryValueKind.DWord);
    }

    static int MigrateLegacyWindowsShellHotkeys(bool allowElevation)
    {
        const string id = "disable-windows-shell-hotkeys";
        const string legacyPath =
            @"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer";
        const string legacyName = "NoWinKeys";

        Dictionary<string, object> original =
            GetRegistryOriginal(id, "HKCU", legacyPath, legacyName);
        if (original == null)
            return 0;

        object currentValue = null;
        bool currentExists = false;
        using (RegistryKey key = Registry.CurrentUser.OpenSubKey(legacyPath, false))
        {
            if (key != null)
            {
                currentExists = key.GetValueNames()
                    .Any(x => String.Equals(x, legacyName, StringComparison.OrdinalIgnoreCase));
                if (currentExists)
                    currentValue = key.GetValue(
                        legacyName,
                        null,
                        RegistryValueOptions.DoNotExpandEnvironmentNames);
            }
        }

        // WGDot's retired implementation wrote exactly DWORD 1. If the value
        // is already gone, just retire the stale ownership snapshot. If it was
        // changed to anything else, preserve the user's newer value and also
        // relinquish WGDot's old ownership instead of overwriting it.
        int currentDword = -1;
        bool isOldManagedValue =
            currentExists &&
            currentValue != null &&
            Int32.TryParse(
                Convert.ToString(currentValue, CultureInfo.InvariantCulture),
                NumberStyles.Integer,
                CultureInfo.InvariantCulture,
                out currentDword) &&
            currentDword == 1;

        if (!isOldManagedValue)
        {
            DiscardRegistryOriginalSnapshot(id, "HKCU", legacyPath, legacyName);
            if (currentExists)
                Console.WriteLine("Preserved user-modified legacy NoWinKeys value and retired old WGDot ownership.");
            return 0;
        }

        // The legacy Policies\Explorer key is protected on the Windows build
        // where WGDot originally created NoWinKeys. Once ownership and the
        // exact old value are proven, elevate before opening it for write
        // instead of relying on the registry API's inconsistent access-denied
        // exception type.
        if (!IsAdministrator())
        {
            if (!allowElevation)
                throw new UnauthorizedAccessException(
                    "Administrator approval is required to restore the retired WGDot NoWinKeys policy.");

            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("Removing WGDot's retired NoWinKeys policy requires administrator approval.");
            Console.ResetColor();
            RunElevatedSelf("migrate-legacy-hotkeys");
            return 0;
        }

        try
        {
            using (RegistryKey key = OpenRegistryKeyForValueWrite("HKCU", legacyPath))
            {
                if (key == null)
                    throw new UnauthorizedAccessException(
                        "Registry access denied: HKCU\\\\" + legacyPath + "\\\\" + legacyName);

                if (!GetBool(original, "exists"))
                {
                    key.DeleteValue(legacyName, false);
                }
                else
                {
                    RegistryValueKind kind;
                    if (!Enum.TryParse(GetString(original, "kind"), out kind))
                        kind = RegistryValueKind.DWord;

                    string text = GetString(original, "value");
                    object value = text;
                    if (kind == RegistryValueKind.DWord)
                    {
                        int number;
                        if (!Int32.TryParse(
                            text,
                            NumberStyles.Integer,
                            CultureInfo.InvariantCulture,
                            out number))
                            throw new Exception("Legacy NoWinKeys snapshot contains an invalid DWORD value.");
                        value = number;
                    }
                    else if (kind == RegistryValueKind.QWord)
                    {
                        long number;
                        if (!Int64.TryParse(
                            text,
                            NumberStyles.Integer,
                            CultureInfo.InvariantCulture,
                            out number))
                            throw new Exception("Legacy NoWinKeys snapshot contains an invalid QWORD value.");
                        value = number;
                    }

                    key.SetValue(legacyName, value, kind);
                }
            }
        }
        catch (UnauthorizedAccessException)
        {
            if (!allowElevation || IsAdministrator())
                throw;

            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("Removing WGDot's retired NoWinKeys policy requires administrator approval.");
            Console.ResetColor();
            RunElevatedSelf("migrate-legacy-hotkeys");
            return 0;
        }

        if (original.ContainsKey("keyExists") && !GetBool(original, "keyExists"))
            DeleteRegistryKeyIfEmpty("HKCU", legacyPath);

        DiscardRegistryOriginalSnapshot(id, "HKCU", legacyPath, legacyName);
        RefreshShellSettings();
        Console.WriteLine("Restored the pre-WGDot NoWinKeys value and retired the legacy policy ownership.");
        Console.WriteLine("Sign out and sign back in if Windows shell shortcuts still reflect the old policy.");
        return 0;
    }

    static void ApplyWindowsShellHotkeysPolicy(bool enable)
    {
        const string id = "disable-windows-shell-hotkeys";
        const string advancedPath =
            @"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced";

        // Before applying the current selective policy, clean up the exact
        // retired NoWinKeys value only when WGDot has an ownership snapshot.
        MigrateLegacyWindowsShellHotkeys(true);

        if (!enable)
        {
            RestoreRegistryOriginals(id);
            Console.WriteLine("Windows shell hotkey filtering restored to its pre-WGDot values.");
            return;
        }

        // NoWinKeys also disables native Win+V and Win+N, which WGDot reuses
        // for Clipboard History and notification-center helpers.
        RestoreRegistryOriginals(id);
        SetRegistryValueWithSnapshot(
            id,
            "HKCU",
            advancedPath,
            "DisabledHotkeys",
            "ABCDEFGHIJKLMOPQRSTUWXYZ0123456789",
            RegistryValueKind.String);

        Console.WriteLine("Selective Windows shell hotkey filtering enabled for the current user.");
        Console.WriteLine("Win+V and Win+N remain available for WGDot helper surfaces.");
        Console.WriteLine("This remains experimental; some Windows shell shortcuts may ignore DisabledHotkeys.");
    }

    static void ApplySnapAssist(bool enable)
    {
        const string id = "disable-snap-assist";
        if (!enable)
        {
            RestoreRegistryOriginals(id);
            return;
        }

        SetRegistryValueWithSnapshot(id, "HKCU",
            @"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
            "SnapAssist", 0, RegistryValueKind.DWord);
        SetRegistryValueWithSnapshot(id, "HKCU",
            @"Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
            "EnableSnapAssistFlyout", 0, RegistryValueKind.DWord);
        SetRegistryValueWithSnapshot(id, "HKCU",
            @"Control Panel\Desktop",
            "WindowArrangementActive", "0", RegistryValueKind.String);
    }

    static void StartWindowsServiceBestEffort(string serviceName)
    {
        ProcResult start = Run("sc.exe", "start " + Q(serviceName), null);
        if (start.ExitCode == 0 || start.ExitCode == 1056)
            return;

        string output = ((start.StdOut ?? "") + " " + (start.StdErr ?? "")).Trim();
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine(
            "Could not start Windows service '" + serviceName + "'" +
            (String.IsNullOrWhiteSpace(output) ? "." : ": " + output));
        Console.ResetColor();
    }

    static void ApplyAutomaticTimeAndTimeZone(bool enable)
    {
        const string id = "automatic-time-and-timezone";
        const string timeServicePath = @"SYSTEM\CurrentControlSet\Services\W32Time";
        const string timeZoneServicePath = @"SYSTEM\CurrentControlSet\Services\tzautoupdate";
        const string locationPath =
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location";

        if (!enable)
        {
            RestoreRegistryOriginals(id);
            Console.WriteLine(
                "Automatic time/time-zone settings restored to their pre-WGDot values. " +
                "The current clock and selected time zone are not rolled backward.");
            return;
        }

        // Keep Windows' normal trigger/manual time service available, enable
        // automatic time-zone detection, and allow the Windows Location service
        // that Microsoft requires for automatic time-zone selection.
        SetRegistryValueWithSnapshot(
            id, "HKLM", timeServicePath, "Start", 3, RegistryValueKind.DWord);
        SetRegistryValueWithSnapshot(
            id, "HKLM", timeZoneServicePath, "Start", 3, RegistryValueKind.DWord);
        SetRegistryValueWithSnapshot(
            id, "HKLM", locationPath, "Value", "Allow", RegistryValueKind.String);

        StartWindowsServiceBestEffort("lfsvc");
        StartWindowsServiceBestEffort("tzautoupdate");
        StartWindowsServiceBestEffort("w32time");

        ProcResult sync = Run("w32tm.exe", "/resync /rediscover", null);
        if (sync.ExitCode == 0)
        {
            Console.WriteLine("Windows time resync requested successfully.");
        }
        else
        {
            string detail = ((sync.StdOut ?? "") + " " + (sync.StdErr ?? "")).Trim();
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine(
                "Windows automatic time is enabled, but the immediate resync did not complete" +
                (String.IsNullOrWhiteSpace(detail) ? "." : ": " + detail));
            Console.ResetColor();
        }

        ProcResult zone = Run("tzutil.exe", "/g", null);
        if (zone.ExitCode == 0 && !String.IsNullOrWhiteSpace(zone.StdOut))
            Console.WriteLine("Current Windows time zone: " + zone.StdOut.Trim());

        Console.WriteLine(
            "Automatic time-zone detection is enabled through Windows Location services. " +
            "Windows may update the zone after location resolves.");
    }

    static void ApplyRemoteAssistance(bool enable)
    {
        const string id = "disable-remote-assistance";
        if (!enable)
        {
            RestoreRegistryOriginals(id);
            return;
        }

        SetRegistryValueWithSnapshot(id, "HKLM",
            @"Software\Policies\Microsoft\Windows NT\Terminal Services",
            "fAllowToGetHelp", 0, RegistryValueKind.DWord);
    }

    static void ApplyWindowsSudo(bool enable)
    {
        const string id = "enable-windows-sudo";
        const string path = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo";

        if (!enable)
        {
            RestoreRegistryOriginals(id);
            Console.WriteLine("Windows sudo setting restored to its pre-WGDot value.");
            return;
        }

        string sudo = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "System32", "sudo.exe");
        if (!File.Exists(sudo))
            throw new Exception("Windows sudo is unavailable. It requires Windows 11 24H2 or newer.");

        SetRegistryValueWithSnapshot(
            id,
            "HKLM",
            path,
            "Enabled",
            1,
            RegistryValueKind.DWord);

        Console.WriteLine("Windows sudo enabled in force-new-window mode.");
    }

    static void ApplyReducedVisualEffects(bool enable)
    {
        const string id = "reduce-visual-effects";
        if (!enable)
        {
            RestoreRegistryOriginals(id);
            return;
        }

        SetRegistryValueWithSnapshot(id, "HKCU",
            @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
            "EnableTransparency", 0, RegistryValueKind.DWord);
        SetRegistryValueWithSnapshot(id, "HKCU",
            @"Control Panel\Desktop\WindowMetrics",
            "MinAnimate", "0", RegistryValueKind.String);
    }

    static void ApplyClassicContextMenu(bool enable)
    {
        const string id = "classic-context-menu";
        string clsid = @"Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}";
        string path = clsid + @"\InprocServer32";

        if (!enable)
        {
            RestoreRegistryOriginals(id);
            DeleteRegistryKeyIfOriginallyAbsentAndEmpty(id, "HKCU", path, "");
            DeleteRegistryKeyIfOriginallyAbsentAndEmpty(id, "HKCU", clsid, "");
            Console.WriteLine("Context-menu registry state restored to its pre-WGDot values. Explorer restart/sign-out may be required.");
            return;
        }

        CaptureRegistryOriginal(id, "HKCU", clsid, "");
        SetRegistryValueWithSnapshot(id, "HKCU", path, "", "", RegistryValueKind.String);
        Console.WriteLine("Classic Windows 11 context menu enabled. Explorer restart/sign-out may be required.");
    }

    static readonly string[] MicroTextExtensions = new[]
    {
        ".txt", ".md", ".markdown", ".log", ".ini", ".cfg", ".conf",
        ".json", ".jsonc", ".yaml", ".yml", ".toml", ".xml", ".csv", ".tsv",
        ".css", ".scss", ".less", ".html", ".htm",
        ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx",
        ".py", ".lua", ".rs", ".go", ".c", ".h", ".cpp", ".hpp",
        ".java", ".kt", ".kts", ".cs", ".sql", ".properties", ".env"
    };

    static void ApplyMicroTextDefaults(bool enable)
    {
        const string id = "micro-text-defaults";
        const string progId = "WGDot.MicroText";
        string launcher = Path.Combine(BinRoot, "open-micro.cmd");
        string handlerPath = @"Software\Classes\" + progId;
        string commandPath = handlerPath + @"\shell\open\command";

        if (!enable)
        {
            bool commandKeyWasAbsent = RegistryKeyWasAbsentInSnapshot(id, "HKCU", commandPath, "");
            RestoreRegistryOriginals(id);

            if (commandKeyWasAbsent)
            {
                DeleteRegistryKeyIfEmpty("HKCU", commandPath);
                DeleteRegistryKeyIfEmpty("HKCU", handlerPath + @"\shell\open");
                DeleteRegistryKeyIfEmpty("HKCU", handlerPath + @"\shell");
            }
            DeleteRegistryKeyIfOriginallyAbsentAndEmpty(id, "HKCU", handlerPath, "");

            SHChangeNotify(0x08000000, 0, IntPtr.Zero, IntPtr.Zero);
            return;
        }

        string command =
            "@echo off\r\n" +
            "start \"\" wt.exe -w new new-tab --title \"Micro\" --suppressApplicationTitle -d \"%~dp1\" micro \"%~1\"\r\n";
        File.WriteAllText(launcher, command, Encoding.ASCII);

        CaptureRegistryOriginal(id, "HKCU", handlerPath, "");
        SetRegistryValueWithSnapshot(
            id,
            "HKCU",
            commandPath,
            "",
            Q(launcher) + " \"%1\"",
            RegistryValueKind.String);

        int protectedDefaults = 0;
        foreach (string extension in MicroTextExtensions)
        {
            SetRegistryValueWithSnapshot(
                id,
                "HKCU",
                @"Software\Classes\" + extension,
                "",
                progId,
                RegistryValueKind.String);

            SetRegistryValueWithSnapshot(
                id,
                "HKCU",
                @"Software\Classes\" + extension + @"\OpenWithProgids",
                progId,
                new byte[0],
                RegistryValueKind.None);

            using (RegistryKey userChoice = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\" + extension + @"\UserChoice",
                false))
            {
                if (userChoice != null) protectedDefaults++;
            }
        }

        SHChangeNotify(0x08000000, 0, IntPtr.Zero, IntPtr.Zero);

        Console.WriteLine("Registered Windows Terminal + Micro for " + MicroTextExtensions.Length +
            " text/code extensions.");
        if (protectedDefaults > 0)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine(
                protectedDefaults + " extensions already have Windows-protected UserChoice defaults. " +
                "WGDot registered Micro as the handler but did not bypass Windows' default-app protection.");
            Console.ResetColor();
        }
    }

    static void ApplyOopsCursor(bool enable)
    {
        const string id = "oops-all-links-cursor";
        if (!enable)
        {
            string current = CurrentCursorThemeId();
            RestoreRegistryOriginals(id);

            if (current.StartsWith("bibata-", StringComparison.OrdinalIgnoreCase))
            {
                ApplyBibataCursor(current);
                Console.WriteLine("Oops-all-links ownership disabled; retained the active Bibata cursor.");
            }
            else
            {
                WriteCursorState("windows-default");
                SystemParametersInfo(0x0057, 0, IntPtr.Zero, 0x01 | 0x02);
                Console.WriteLine("Cursor registry values were restored to their pre-WGDot values.");
            }
            return;
        }

        RestoreRegistryOriginals("bibata-cursor-theme");

        string tempDir = Path.Combine(CacheRoot, "oops-all-links");
        string zipPath = Path.Combine(tempDir, "OopsAllLinkSelects.zip");
        string cursorDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
            "Cursors",
            "OopsAllLinkSelects");

        Directory.CreateDirectory(tempDir);
        SafeDeleteFile(zipPath);

        using (var client = new WebClient())
        {
            client.Headers[HttpRequestHeader.UserAgent] = "wgdot";
            client.DownloadFile(
                "https://www.rw-designer.com/cursor-downloadset.php?id=oops-all-link-selects",
                zipPath);
        }

        using (FileStream stream = File.OpenRead(zipPath))
        {
            if (stream.ReadByte() != 0x50 || stream.ReadByte() != 0x4B)
                throw new Exception("Oops-all-links download was not a valid ZIP archive.");
        }

        if (Directory.Exists(cursorDir))
        {
            CreateBackup(cursorDir, "cursor");
            Directory.Delete(cursorDir, true);
        }
        Directory.CreateDirectory(cursorDir);
        ExtractZipToDirectorySafe(zipPath, cursorDir);

        string[,] mappings = new string[,]
        {
            { "Arrow", "default.cur" },
            { "Help", "help.cur" },
            { "AppStarting", "busy.ani" },
            { "Wait", "busy.ani" },
            { "Crosshair", "precision select.cur" },
            { "IBeam", "handwrite.cur" },
            { "NWPen", "handwrite.cur" },
            { "No", "unavailable.ani" },
            { "SizeNS", "resize vertical.cur" },
            { "SizeWE", "resize horizontal.cur" },
            { "SizeNWSE", "resize backslash.cur" },
            { "SizeNESW", "resize slash.cur" },
            { "SizeAll", "move.cur" },
            { "UpArrow", "alt select.cur" },
            { "Hand", "link select.cur" }
        };

        var values = new List<string>();
        for (int i = 0; i < mappings.GetLength(0); i++)
        {
            string name = mappings[i, 0];
            string path = Path.Combine(cursorDir, mappings[i, 1]);
            if (!File.Exists(path))
                throw new Exception("Cursor archive is missing expected file: " + mappings[i, 1]);

            SetRegistryValueWithSnapshot(
                id, "HKCU", @"Control Panel\Cursors", name, path, RegistryValueKind.String);
            values.Add(path);
        }

        SetRegistryValueWithSnapshot(
            id, "HKCU", @"Control Panel\Cursors", "CursorBaseSize", 48, RegistryValueKind.DWord);
        SetRegistryValueWithSnapshot(
            id, "HKCU", @"Control Panel\Cursors", "", "OopsAllLinkSelects", RegistryValueKind.String);

        SetRegistryValueWithSnapshot(
            id,
            "HKCU",
            @"Control Panel\Cursors\Schemes",
            "OopsAllLinkSelects",
            String.Join(",", values.ToArray()),
            RegistryValueKind.String);

        SystemParametersInfo(0x0057, 0, IntPtr.Zero, 0x01 | 0x02);
        WriteCursorState("oops-all-links");
        Console.WriteLine("Oops-all-links cursor theme installed and applied.");
    }

    static void RunPrivacySexy()
    {
        WriteTitle("privacy.sexy");

        int preset = ReadSingleChoice(
            "Preferred privacy.sexy recommendation level",
            new List<string> { "Standard (repo guide default)", "Strict", "Skip" },
            0);
        if (preset < 0 || preset == 2) return;

        string presetName = preset == 1 ? "Strict" : "Standard";
        Console.WriteLine();
        Console.WriteLine("WGDot will install/update the official privacy.sexy desktop app.");
        Console.WriteLine("Selected recommendation level: " + presetName);
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine(
            "privacy.sexy does not currently expose a supported headless CLI/API for generating " +
            "and executing that recommendation set. WGDot will not fake one, drive private UI internals, " +
            "or disable antivirus.");
        Console.WriteLine(
            "The official app will open so you can select " + presetName +
            " and approve its generated script/run operation.");
        Console.ResetColor();
        Console.WriteLine();

        if (!ReadYesNo("Install/update and open official privacy.sexy now? [y/N]", false))
            return;

        var release = GetJsonUrl("https://api.github.com/repos/undergroundwires/privacy.sexy/releases/latest");
        string installerUrl = "";
        string installerName = "";

        foreach (object rawAsset in GetList(release, "assets"))
        {
            var asset = AsDictionary(rawAsset);
            string name = GetString(asset, "name");
            if (Regex.IsMatch(name, "^privacy\\.sexy-Setup-.*\\.exe$", RegexOptions.IgnoreCase))
            {
                installerName = name;
                installerUrl = GetString(asset, "browser_download_url");
                break;
            }
        }

        if (String.IsNullOrWhiteSpace(installerUrl))
            throw new Exception("Could not locate the official privacy.sexy Windows installer in the latest upstream release.");

        string installerPath = Path.Combine(CacheRoot, installerName);
        using (var client = new WebClient())
        {
            client.Headers[HttpRequestHeader.UserAgent] = "wgdot";
            client.DownloadFile(installerUrl, installerPath);
        }

        if (!IsWindowsExecutableFile(installerPath))
        {
            SafeDeleteFile(installerPath);
            throw new Exception("privacy.sexy download did not return a valid Windows executable.");
        }

        ProcResult installed = RunInteractive(installerPath, "");
        if (installed.ExitCode != 0)
            throw new Exception("privacy.sexy installer exited with code " + installed.ExitCode.ToString(CultureInfo.InvariantCulture) + ".");

        string exe = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Programs",
            "privacy.sexy",
            "privacy.sexy.exe");

        bool appRunning = WaitForProcessToAppear("privacy.sexy", 3000);
        if (!appRunning)
        {
            if (!File.Exists(exe))
                throw new Exception("privacy.sexy installed successfully but its desktop executable was not found.");

            var psi = new ProcessStartInfo();
            psi.FileName = exe;
            psi.UseShellExecute = true;
            Process.Start(psi);

            if (!WaitForProcessToAppear("privacy.sexy", 5000))
                throw new Exception("privacy.sexy did not start after installation.");
        }
        else
        {
            Console.WriteLine("privacy.sexy was already started by its installer; WGDot will not launch a second copy.");
        }

        Console.WriteLine("WGDot will continue after privacy.sexy is closed.");
        WaitForProcessToExit("privacy.sexy");

        var state = ReadJson(TweakStatePath) ?? new Dictionary<string, object>();
        state["privacySexyPreset"] = presetName;
        state["privacySexyLastOpenedAt"] = DateTime.UtcNow.ToString("o");
        state["privacySexyLastClosedAt"] = DateTime.UtcNow.ToString("o");
        WriteJson(TweakStatePath, state);
    }

    static void RefreshShellSettings()
    {
        UIntPtr ignored;
        try
        {
            SendMessageTimeout(
                HwndBroadcast,
                WmSettingChange,
                UIntPtr.Zero,
                null,
                SmtoAbortIfHung,
                2000,
                out ignored);
        }
        catch
        {
        }

        try { SHChangeNotify(0x08000000, 0, IntPtr.Zero, IntPtr.Zero); } catch { }
    }


    static string PrepareGitRuntimeSync(SourceContext source)
    {
        if (source == null ||
            !String.Equals(source.Mode, "git", StringComparison.OrdinalIgnoreCase))
            return "";

        ValidateBranchName(source.Branch);
        if (!Regex.IsMatch(source.Revision ?? "", "^[0-9a-fA-F]{40}$"))
            throw new Exception("Git-testing runtime sync requires an exact 40-character revision.");

        var bootstrap = ReadJson(BootstrapStatePath);
        string installedRef = bootstrap == null ? "" : GetString(bootstrap, "sourceRef");
        string installedRevision = bootstrap == null ? "" : GetString(bootstrap, "sourceRevision");
        if (String.Equals(installedRef, source.Branch, StringComparison.OrdinalIgnoreCase) &&
            String.Equals(installedRevision, source.Revision, StringComparison.OrdinalIgnoreCase))
            return "";

        string sourcePath = Path.Combine(
            source.SourceRoot,
            "wgdot",
            "wgdot-native.cs");
        if (!File.Exists(sourcePath))
            throw new Exception("Git-testing runtime source missing: wgdot/wgdot-native.cs");

        string nextExe = Path.Combine(
            CacheRoot,
            "wgdot-next-" + source.Revision.ToLowerInvariant() + ".exe");
        SafeDeleteFile(nextExe);
        CompileNativeSource(sourcePath, nextExe);

        ProcResult test = Run(nextExe, "self-test", null);
        if (test.ExitCode != 0)
            throw new Exception(
                "Git-testing runtime self-test failed: " +
                LastUsefulLine((test.StdErr ?? "") + "\n" + (test.StdOut ?? "")));

        return nextExe;
    }

    static void ScheduleGitRuntimeSync(SourceContext source, string nextExe)
    {
        if (source == null || String.IsNullOrWhiteSpace(nextExe))
            return;

        var bootstrap = ReadJson(BootstrapStatePath) ?? new Dictionary<string, object>();
        bootstrap["sourceRef"] = source.Branch;
        bootstrap["sourceExplicit"] = true;
        bootstrap["runtimeSyncPendingRevision"] = source.Revision;
        bootstrap["runtimeSyncScheduledAt"] = DateTime.UtcNow.ToString("o");
        WriteJson(BootstrapStatePath, bootstrap);

        string installedExe = Path.Combine(BinRoot, "wgdot.exe");
        string workerState = Path.Combine(
            Path.GetTempPath(),
            "wgdot-worker-state-" + Guid.NewGuid().ToString("N") + ".json");
        string helper = CreateRuntimeSwapHelper(
            nextExe,
            installedExe,
            source.Branch,
            source.Revision,
            workerState);

        var helperInfo = new ProcessStartInfo();
        helperInfo.FileName = "cmd.exe";
        helperInfo.Arguments = "/d /c " + Q(helper);
        helperInfo.UseShellExecute = false;
        helperInfo.CreateNoWindow = true;
        Process.Start(helperInfo);

        Console.WriteLine(
            "WGDot runtime sync scheduled: " +
            source.Branch + " @ " + source.Revision);
    }

    static int ManagedOperation(string mode, SourceContext source)
    {
        if (source == null) throw new Exception("No source was resolved.");
        if (mode != "update" && mode != "reset" && mode != "review")
            throw new Exception("Unknown managed operation mode.");

        InstallationSelection existing = ReadInstallationSelection();
        InstallationSelection selection = existing;
        bool selectionChanged = false;

        if (selection == null || mode == "reset")
        {
            bool includePackages = mode != "review";
            selection = ConfigureInstallationSelection(source.Manifest, existing, includePackages);
            if (selection == null)
            {
                Console.WriteLine("Operation cancelled.");
                return 0;
            }
            selectionChanged = true;
        }

        bool hasBaseline = File.Exists(BaselineIndexPath);
        string effectiveMode = (mode == "reset" || !hasBaseline) ? "reset" : "update";
        List<PlanItem> plan = GetPlan(source.Manifest, source.SourceRoot, selection, effectiveMode);

        ShowPlan(plan);
        ShowMigrations(source.Manifest, selection, true);

        bool reviewOnly = mode == "review";
        if (reviewOnly)
        {
            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.DarkGray;
            Console.WriteLine("Review only. No files, backups, baselines, or selection state were changed.");
            if (!hasBaseline)
                Console.WriteLine("No baseline exists yet, so this first-install review uses reset semantics.");
            Console.ResetColor();
            return 0;
        }

        Console.WriteLine();
        if (!ReadYesNo("Apply exactly this plan? [y/N]", false))
        {
            Console.WriteLine("No changes were applied.");
            return 0;
        }

        string pendingGitRuntime = PrepareGitRuntimeSync(source);
        ApplyPlan(plan, source.Manifest, selection, source);
        RestoreRememberedThemeAfterManagedApply(plan);

        if (selectionChanged)
            WriteInstallationSelection(selection);

        UpdateSourceStateAfterApply(source);
        ScheduleGitRuntimeSync(source, pendingGitRuntime);
        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("WGDot managed configuration applied.");
        Console.ResetColor();
        return 0;
    }

    static List<PlanItem> GetPlan(
        Dictionary<string, object> manifest,
        string sourceRoot,
        InstallationSelection installation,
        string mode)
    {
        var plan = new List<PlanItem>();
        var selectedIds = new HashSet<string>(installation.Components, StringComparer.OrdinalIgnoreCase);

        foreach (object rawComponent in GetList(manifest, "components"))
        {
            var component = AsDictionary(rawComponent);
            string componentId = GetString(component, "id");
            if (!selectedIds.Contains(componentId)) continue;

            foreach (object rawFile in GetList(component, "files"))
            {
                var file = AsDictionary(rawFile);
                string fileId = GetString(file, "id");
                string relativeSource = GetRelativeSourcePath(file, installation.GlazeProfile);
                string target = Path.Combine(sourceRoot, relativeSource.Replace('/', Path.DirectorySeparatorChar));

                if (!File.Exists(target))
                    throw new Exception("Managed source missing: " + relativeSource);

                string destination = Environment.ExpandEnvironmentVariables(GetString(file, "destination"));
                if (!IsSafeManagedDestination(destination))
                    throw new Exception("Unsafe managed destination: " + destination);

                string baseline = GetBaselinePath(fileId);
                string targetHash = Sha256OrNull(target);
                string liveHash = Sha256OrNull(destination);
                string baselineHash = Sha256OrNull(baseline);

                string status;
                string action;

                if (liveHash == null)
                {
                    status = "NEW";
                    action = "APPLY";
                }
                else if (String.Equals(liveHash, targetHash, StringComparison.OrdinalIgnoreCase))
                {
                    status = "CURRENT";
                    action = "NONE";
                }
                else if (String.Equals(mode, "reset", StringComparison.OrdinalIgnoreCase))
                {
                    status = "RESET";
                    action = "REPLACE";
                }
                else if (baselineHash == null)
                {
                    status = "LEGACY";
                    action = "PRESERVE";
                }
                else if (String.Equals(liveHash, baselineHash, StringComparison.OrdinalIgnoreCase) &&
                         !String.Equals(targetHash, baselineHash, StringComparison.OrdinalIgnoreCase))
                {
                    status = "UPSTREAM";
                    action = "REPLACE";
                }
                else if (!String.Equals(liveHash, baselineHash, StringComparison.OrdinalIgnoreCase) &&
                         String.Equals(targetHash, baselineHash, StringComparison.OrdinalIgnoreCase))
                {
                    status = "USER";
                    action = "PRESERVE";
                }
                else
                {
                    status = "BOTH";
                    action = GetBool(file, "merge") ? "MERGE" : "PRESERVE";
                }

                plan.Add(new PlanItem
                {
                    FileId = fileId,
                    Component = componentId,
                    Destination = destination,
                    Target = target,
                    Baseline = baseline,
                    Status = status,
                    Action = action,
                    Merge = GetBool(file, "merge"),
                    CommitTargetBaseline = new[] { "NEW", "CURRENT", "RESET", "UPSTREAM", "USER" }.Contains(status),
                    Validator = GetString(file, "validator")
                });
            }
        }

        AddRemovedUpstreamItems(plan, selectedIds);
        return plan;
    }

    static void AddRemovedUpstreamItems(List<PlanItem> plan, HashSet<string> selectedComponentIds)
    {
        var oldIndex = ReadJson(BaselineIndexPath);
        if (oldIndex == null) return;

        var currentIds = new HashSet<string>(plan.Select(x => x.FileId), StringComparer.OrdinalIgnoreCase);

        foreach (object raw in GetList(oldIndex, "files"))
        {
            var old = AsDictionary(raw);
            string component = GetString(old, "component");
            string fileId = GetString(old, "fileId");
            string destination = GetString(old, "destination");

            if (!selectedComponentIds.Contains(component) || currentIds.Contains(fileId) || !File.Exists(destination))
                continue;

            plan.Add(new PlanItem
            {
                FileId = fileId,
                Component = component,
                Destination = destination,
                Target = null,
                Baseline = GetBaselinePath(fileId),
                Status = "REMOVED-UPSTREAM",
                Action = "PRESERVE",
                Merge = false,
                CommitTargetBaseline = false,
                Validator = ""
            });
        }
    }

    static void ShowPlan(List<PlanItem> plan)
    {
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine("Plan");
        Console.ResetColor();

        foreach (PlanItem item in plan)
        {
            string display = String.Format("{0,-17} {1,-9} {2}", item.Status, item.Action, item.Destination);

            if (item.Action == "PRESERVE" || item.Status == "REMOVED-UPSTREAM")
                Console.ForegroundColor = ConsoleColor.Yellow;
            else if (item.Action == "NONE")
                Console.ForegroundColor = ConsoleColor.DarkGray;

            Console.WriteLine(display);
            Console.ResetColor();
        }

        if (plan.Count == 0) Console.WriteLine("(no managed files selected)");
    }

    static void ApplyPlan(
        List<PlanItem> plan,
        Dictionary<string, object> manifest,
        InstallationSelection selection,
        SourceContext source)
    {
        ApplyPlan(plan, manifest, selection, source, false);
    }

    static void ApplyPlan(
        List<PlanItem> plan,
        Dictionary<string, object> manifest,
        InstallationSelection selection,
        SourceContext source,
        bool dotsOnly)
    {
        foreach (PlanItem item in plan)
        {
            if (item.Action == "NONE" || item.Action == "PRESERVE") continue;

            if (item.Action == "MERGE")
            {
                if (MergeManagedFile(item))
                    item.CommitTargetBaseline = true;
                continue;
            }

            if (item.Action == "REPLACE")
                CreateBackup(item.Destination, "replace");

            AtomicCopy(item.Target, item.Destination, item.Validator);
        }

        if (!dotsOnly)
            ShowMigrations(manifest, selection, false);
        RunPostActions(manifest, selection, dotsOnly);
        CommitBaseline(plan, source, selection);
    }

    static bool MergeManagedFile(PlanItem item)
    {
        if (!ExecutableExists("git.exe"))
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("Git unavailable; preserving user-modified file: " + item.Destination);
            Console.ResetColor();
            return false;
        }

        if (!File.Exists(item.Baseline))
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("Merge baseline missing; preserving user-modified file: " + item.Destination);
            Console.ResetColor();
            return false;
        }

        string tempRoot = Path.Combine(CacheRoot, "merge-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tempRoot);

        string local = Path.Combine(tempRoot, "local");
        string baseline = Path.Combine(tempRoot, "base");
        string remote = Path.Combine(tempRoot, "remote");

        try
        {
            File.Copy(item.Destination, local, true);
            File.Copy(item.Baseline, baseline, true);
            File.Copy(item.Target, remote, true);

            ProcResult merge = Run(
                "git.exe",
                "merge-file -- " + Q(local) + " " + Q(baseline) + " " + Q(remote),
                null);

            if (merge.ExitCode != 0)
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("Merge conflict; preserving local file: " + item.Destination);
                Console.ResetColor();
                return false;
            }

            ValidateFile(local, item.Validator);
            CreateBackup(item.Destination, "merge");
            AtomicCopy(local, item.Destination, item.Validator);
            return true;
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("Merge validation failed; preserving local file: " + item.Destination);
            Console.WriteLine(ex.Message);
            Console.ResetColor();
            return false;
        }
        finally
        {
            SafeDeleteDirectory(tempRoot);
        }
    }

    static void AtomicCopy(string source, string destination, string validator)
    {
        if (String.IsNullOrWhiteSpace(source) || !File.Exists(source))
            throw new Exception("Managed source file is missing: " + source);

        string parent = Path.GetDirectoryName(destination);
        if (String.IsNullOrWhiteSpace(parent)) throw new Exception("Destination has no parent: " + destination);
        Directory.CreateDirectory(parent);

        string temp = Path.Combine(parent, ".wgdot-" + Guid.NewGuid().ToString("N") + ".tmp");
        try
        {
            File.Copy(source, temp, true);
            ValidateFile(temp, validator);

            if (File.Exists(destination))
            {
                try
                {
                    File.Replace(temp, destination, null);
                }
                catch
                {
                    File.Copy(temp, destination, true);
                    SafeDeleteFile(temp);
                }
            }
            else
            {
                File.Move(temp, destination);
            }
        }
        finally
        {
            SafeDeleteFile(temp);
        }
    }

    static void ValidateFile(string path, string validator)
    {
        if (String.IsNullOrWhiteSpace(validator)) return;

        if (String.Equals(validator, "json", StringComparison.OrdinalIgnoreCase))
        {
            Json.DeserializeObject(File.ReadAllText(path));
            return;
        }

        if (String.Equals(validator, "xml", StringComparison.OrdinalIgnoreCase))
        {
            var xml = new XmlDocument();
            xml.Load(path);
            return;
        }

        throw new Exception("Unknown validator '" + validator + "'.");
    }

    static string CreateBackup(string path, string operation)
    {
        if (!File.Exists(path) && !Directory.Exists(path)) return null;

        string backup = path + ".wgdot.backup";
        if (File.Exists(backup) || Directory.Exists(backup))
        {
            string stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture);
            backup = path + ".wgdot.backup." + stamp;
            int n = 1;
            while (File.Exists(backup) || Directory.Exists(backup))
            {
                backup = path + ".wgdot.backup." + stamp + "-" + n.ToString(CultureInfo.InvariantCulture);
                n++;
            }
        }

        if (Directory.Exists(path))
            CopyDirectory(path, backup);
        else
            File.Copy(path, backup);

        AddBackupRecord(path, backup, operation);
        return backup;
    }

    static void CopyDirectory(string source, string destination)
    {
        Directory.CreateDirectory(destination);

        foreach (string file in Directory.GetFiles(source))
            File.Copy(file, Path.Combine(destination, Path.GetFileName(file)), true);

        foreach (string directory in Directory.GetDirectories(source))
            CopyDirectory(directory, Path.Combine(destination, Path.GetFileName(directory)));
    }

    static void AddBackupRecord(string original, string backup, string operation)
    {
        var state = ReadJson(BackupStatePath);
        var records = new List<object>();
        if (state != null) records.AddRange(GetList(state, "records"));

        var record = new Dictionary<string, object>();
        record["original"] = original;
        record["backup"] = backup;
        record["operation"] = operation;
        record["createdAt"] = DateTime.UtcNow.ToString("o");
        records.Add(record);

        var next = new Dictionary<string, object>();
        next["records"] = records.ToArray();
        WriteJson(BackupStatePath, next);
    }

    static int CountRecordedBackups()
    {
        var state = ReadJson(BackupStatePath);
        if (state == null) return 0;
        return GetList(state, "records").Count;
    }

    static void ShowMigrations(
        Dictionary<string, object> manifest,
        InstallationSelection selection,
        bool whatIfOnly)
    {
        var selected = new HashSet<string>(selection.Components, StringComparer.OrdinalIgnoreCase);

        foreach (object rawMigration in GetList(manifest, "migrations"))
        {
            var migration = AsDictionary(rawMigration);
            if (!selected.Contains(GetString(migration, "component"))) continue;

            string path = Environment.ExpandEnvironmentVariables(GetString(migration, "path"));
            if (!File.Exists(path) && !Directory.Exists(path)) continue;

            if (LegacyMigrationMatches(migration))
            {
                Console.WriteLine("MIGRATION matched: " + GetString(migration, "id") + " -> " + path);
                if (!whatIfOnly)
                {
                    string backup = CreateBackup(path, "migration");
                    if (Directory.Exists(path)) Directory.Delete(path, true);
                    else SafeDeleteFile(path);
                    Console.WriteLine("Migration backup: " + backup);
                }
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("Migration target exists but was not positively identified as WGDot-managed; preserving: " + path);
                Console.ResetColor();
            }
        }
    }

    static bool LegacyMigrationMatches(Dictionary<string, object> migration)
    {
        string path = Environment.ExpandEnvironmentVariables(GetString(migration, "path"));
        if (!Directory.Exists(path)) return false;
        if (!String.Equals(GetString(migration, "type"), "git-remote-directory", StringComparison.OrdinalIgnoreCase))
            return false;

        string config = Path.Combine(path, ".git", "config");
        if (!File.Exists(config)) return false;

        string raw = File.ReadAllText(config);
        string fragment = GetString(migration, "expectedRemoteFragment");
        return raw.IndexOf(fragment, StringComparison.OrdinalIgnoreCase) >= 0;
    }

    static bool IsDotsOnlyPostAction(string type)
    {
        // Strict config-only migration copies managed files only. Desktop runtime
        // behavior is implemented by the copied configs/scripts, not WGDot post-actions.
        return false;
    }

    static void RunPostActions(
        Dictionary<string, object> manifest,
        InstallationSelection selection,
        bool dotsOnly)
    {
        var selected = new HashSet<string>(selection.Components, StringComparer.OrdinalIgnoreCase);

        foreach (object rawComponent in GetList(manifest, "components"))
        {
            var component = AsDictionary(rawComponent);
            if (!selected.Contains(GetString(component, "id"))) continue;

            foreach (object rawPost in GetList(component, "postActions"))
            {
                var post = AsDictionary(rawPost);
                string type = GetString(post, "type");

                if (dotsOnly && !IsDotsOnlyPostAction(type))
                {
                    Console.ForegroundColor = ConsoleColor.DarkGray;
                    Console.WriteLine("Dots-only: skipped non-file post-action " + type + ".");
                    Console.ResetColor();
                    continue;
                }

                if (String.Equals(type, "set-yazi-file-one", StringComparison.OrdinalIgnoreCase))
                {
                    string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
                    string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                    string[] candidates =
                    {
                        Path.Combine(programFiles, "Git", "usr", "bin", "file.exe"),
                        Path.Combine(userProfile, "scoop", "apps", "git", "current", "usr", "bin", "file.exe")
                    };

                    string fileExe = candidates.FirstOrDefault(File.Exists);
                    if (!String.IsNullOrWhiteSpace(fileExe))
                    {
                        Environment.SetEnvironmentVariable("YAZI_FILE_ONE", fileExe, EnvironmentVariableTarget.User);
                        BroadcastEnvironmentChange();
                        Console.WriteLine("Set YAZI_FILE_ONE=" + fileExe);
                    }
                    else
                    {
                        Console.ForegroundColor = ConsoleColor.Yellow;
                        Console.WriteLine("Git file.exe not found; Yazi MIME detection may be incomplete.");
                        Console.ResetColor();
                    }
                }
                else if (String.Equals(type, "yazi-package-install", StringComparison.OrdinalIgnoreCase))
                {
                    if (ExecutableExists("ya.exe"))
                    {
                        ProcResult ya = RunInteractive("ya.exe", "pkg install");
                        if (ya.ExitCode != 0)
                        {
                            Console.ForegroundColor = ConsoleColor.Yellow;
                            Console.WriteLine("ya pkg install failed.");
                            Console.ResetColor();
                        }
                    }
                    else
                    {
                        Console.ForegroundColor = ConsoleColor.Yellow;
                        Console.WriteLine("Yazi package helper 'ya' not found; run 'ya pkg install' manually after Yazi is installed.");
                        Console.ResetColor();
                    }
                }
                else if (String.Equals(type, "migrate-legacy-windows-hotkeys", StringComparison.OrdinalIgnoreCase))
                {
                    MigrateLegacyWindowsShellHotkeys(true);
                }
                else if (String.Equals(type, "ensure-cursor-theme", StringComparison.OrdinalIgnoreCase))
                {
                    EnsureCursorTheme();
                }
            }
        }
    }

    static void CommitBaseline(
        List<PlanItem> plan,
        SourceContext source,
        InstallationSelection selection)
    {
        Directory.CreateDirectory(BaselineRoot);
        var index = new List<object>();

        foreach (PlanItem item in plan)
        {
            string baseline = GetBaselinePath(item.FileId);

            if (item.Target != null && item.CommitTargetBaseline)
                File.Copy(item.Target, baseline, true);

            if (File.Exists(baseline))
            {
                var record = new Dictionary<string, object>();
                record["fileId"] = item.FileId;
                record["component"] = item.Component;
                record["destination"] = item.Destination;
                record["sha256"] = Sha256OrNull(baseline);
                index.Add(record);
            }
        }

        var baselineState = new Dictionary<string, object>();
        baselineState["files"] = index.ToArray();
        baselineState["generatedAt"] = DateTime.UtcNow.ToString("o");
        WriteJson(BaselineIndexPath, baselineState);

        if (String.Equals(source.Mode, "stable", StringComparison.OrdinalIgnoreCase))
        {
            var config = new Dictionary<string, object>();
            config["mode"] = "stable";
            config["tag"] = source.Tag;
            config["revision"] = source.Revision;
            config["appliedAt"] = DateTime.UtcNow.ToString("o");
            config["glazewmProfile"] = selection.GlazeProfile;
            WriteJson(ConfigStatePath, config);
        }
    }

    static void UpdateSourceStateAfterApply(SourceContext source)
    {
        if (String.Equals(source.Mode, "git", StringComparison.OrdinalIgnoreCase))
        {
            string previousStable = "";
            var config = ReadJson(ConfigStatePath);
            if (config != null && String.Equals(GetString(config, "mode"), "stable", StringComparison.OrdinalIgnoreCase))
                previousStable = GetString(config, "tag");
            else
            {
                var oldGit = ReadJson(GitStatePath);
                if (oldGit != null) previousStable = GetString(oldGit, "stableRelease");
            }

            var state = new Dictionary<string, object>();
            state["branch"] = source.Branch;
            state["revision"] = source.Revision;
            state["stableRelease"] = previousStable;
            state["testedAt"] = DateTime.UtcNow.ToString("o");
            WriteJson(GitStatePath, state);
        }
        else
        {
            SafeDeleteFile(GitStatePath);
        }
    }

    static void BackupManager()
    {
        var state = ReadJson(BackupStatePath);
        var allRecords = state == null ? new List<object>() : GetList(state, "records");
        var records = allRecords
            .Select(AsDictionary)
            .Where(r =>
            {
                string path = GetString(r, "backup");
                return File.Exists(path) || Directory.Exists(path);
            })
            .ToList();

        WriteTitle("Backup manager");

        if (records.Count == 0)
        {
            Console.WriteLine("No recorded WGDot backups exist.");
            Pause();
            return;
        }

        Console.Write("Only show backups older than N days (blank = all): ");
        string ageText = (Console.ReadLine() ?? "").Trim();
        if (!String.IsNullOrWhiteSpace(ageText))
        {
            int days;
            if (Int32.TryParse(ageText, out days) && days >= 0)
            {
                DateTime cutoff = DateTime.UtcNow.AddDays(-days);
                records = records.Where(r =>
                {
                    DateTime created;
                    return DateTime.TryParse(
                        GetString(r, "createdAt"),
                        CultureInfo.InvariantCulture,
                        DateTimeStyles.RoundtripKind,
                        out created) && created.ToUniversalTime() < cutoff;
                }).ToList();
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("Invalid age filter; showing all backups.");
                Console.ResetColor();
            }
        }

        if (records.Count == 0)
        {
            Console.WriteLine("No WGDot backups match that filter.");
            Pause();
            return;
        }

        var choices = new List<ChoiceItem>();
        for (int i = 0; i < records.Count; i++)
        {
            choices.Add(new ChoiceItem
            {
                Id = i.ToString(CultureInfo.InvariantCulture),
                Label = GetString(records[i], "createdAt") + "  " + GetString(records[i], "backup"),
                Selected = false
            });
        }

        choices = ReadMultiChoice("Select WGDot backups to delete", choices);
        if (choices == null) return;

        var selected = choices.Where(x => x.Selected).ToList();
        if (selected.Count == 0) return;

        WriteTitle("Backup cleanup review");
        foreach (ChoiceItem choice in selected)
        {
            int index = Int32.Parse(choice.Id, CultureInfo.InvariantCulture);
            Console.WriteLine("DELETE  " + GetString(records[index], "backup"));
        }

        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine("Dry-run complete. Nothing has been deleted yet.");
        Console.ResetColor();

        if (!ReadYesNo("Delete exactly these recorded WGDot backups? [y/N]", false))
            return;

        var deleteSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (ChoiceItem choice in selected)
        {
            int index = Int32.Parse(choice.Id, CultureInfo.InvariantCulture);
            string backup = GetString(records[index], "backup");
            deleteSet.Add(backup);

            if (Directory.Exists(backup)) Directory.Delete(backup, true);
            else SafeDeleteFile(backup);
        }

        var remaining = new List<object>();
        foreach (object raw in allRecords)
        {
            var record = AsDictionary(raw);
            if (!deleteSet.Contains(GetString(record, "backup")))
                remaining.Add(record);
        }

        var next = new Dictionary<string, object>();
        next["records"] = remaining.ToArray();
        WriteJson(BackupStatePath, next);

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("Selected WGDot backups deleted.");
        Console.ResetColor();
        Pause();
    }

    static List<string> GetRemoteBranches()
    {
        RequireExecutable("git.exe", "Git is required for WGDot Git-testing mode.");

        Directory.CreateDirectory(CacheRoot);
        string verifyRoot = Path.Combine(CacheRoot, "git-verify");

        if (!Directory.Exists(Path.Combine(verifyRoot, ".git")))
        {
            if (Directory.Exists(verifyRoot)) Directory.Delete(verifyRoot, true);
            ProcResult clone = Run("git.exe", "clone --filter=blob:none --no-checkout " + Q(RepoUrl) + " " + Q(verifyRoot), null);
            if (clone.ExitCode != 0)
                throw new Exception("Could not initialize Git-testing verification clone: " + LastUsefulLine(clone.StdErr));
        }

        ProcResult fetch = Run("git.exe", "-C " + Q(verifyRoot) + " fetch --prune origin \"+refs/heads/*:refs/remotes/origin/*\"", null);
        if (fetch.ExitCode != 0)
            throw new Exception("Could not fetch remote branches: " + LastUsefulLine(fetch.StdErr));

        ProcResult refs = Run(
            "git.exe",
            "-C " + Q(verifyRoot) + " for-each-ref --format=%(refname:strip=3) refs/remotes/origin",
            null);
        if (refs.ExitCode != 0)
            throw new Exception("Could not list remote branches: " + LastUsefulLine(refs.StdErr));

        return (refs.StdOut ?? "")
            .Replace("\r", "")
            .Split('\n')
            .Select(x => x.Trim())
            .Where(x => !String.IsNullOrWhiteSpace(x) && !String.Equals(x, "HEAD", StringComparison.OrdinalIgnoreCase))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => String.Equals(x, GetPreferredGitBranch(), StringComparison.OrdinalIgnoreCase) ? 0 : 1)
            .ThenBy(x => x, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    static string GetPreferredGitBranch()
    {
        var state = ReadJson(BootstrapStatePath);
        if (state != null)
        {
            string sourceRef = GetString(state, "sourceRef");
            if (!String.IsNullOrWhiteSpace(sourceRef) &&
                !String.Equals(sourceRef, "main", StringComparison.OrdinalIgnoreCase))
                return sourceRef;
        }

        return "feature/wgdot-maintenance";
    }

    static string ResolveGitRevision(string branch, string requestedRevision)
    {
        ValidateBranchName(branch);
        RequireExecutable("git.exe", "Git is required for WGDot Git-testing mode.");

        Directory.CreateDirectory(CacheRoot);
        string verifyRoot = Path.Combine(CacheRoot, "git-verify");

        if (!Directory.Exists(Path.Combine(verifyRoot, ".git")))
        {
            if (Directory.Exists(verifyRoot)) Directory.Delete(verifyRoot, true);
            ProcResult clone = Run("git.exe", "clone --filter=blob:none --no-checkout " + Q(RepoUrl) + " " + Q(verifyRoot), null);
            if (clone.ExitCode != 0)
                throw new Exception("Could not initialize Git-testing verification clone: " + LastUsefulLine(clone.StdErr));
        }

        ProcResult fetch = Run("git.exe", "-C " + Q(verifyRoot) + " fetch --prune origin \"+refs/heads/*:refs/remotes/origin/*\"", null);
        if (fetch.ExitCode != 0)
            throw new Exception("Could not fetch remote branches: " + LastUsefulLine(fetch.StdErr));

        string branchRef = "refs/remotes/origin/" + branch;
        ProcResult head = Run("git.exe", "-C " + Q(verifyRoot) + " rev-parse --verify " + Q(branchRef + "^{commit}"), null);
        string headSha = (head.StdOut ?? "").Trim();

        if (head.ExitCode != 0 || !Regex.IsMatch(headSha, "^[0-9a-fA-F]{40}$"))
            throw new Exception("Remote branch '" + branch + "' was not found.");

        if (String.IsNullOrWhiteSpace(requestedRevision))
            return headSha.ToLowerInvariant();

        if (!Regex.IsMatch(requestedRevision, "^[0-9a-fA-F]{40}$"))
            throw new Exception("Exact Git-testing revision must be a full 40-character SHA.");

        ProcResult exists = Run("git.exe", "-C " + Q(verifyRoot) + " cat-file -e " + Q(requestedRevision + "^{commit}"), null);
        if (exists.ExitCode != 0)
            throw new Exception("Commit '" + requestedRevision + "' is unavailable after fetching the repository.");

        ProcResult ancestor = Run("git.exe", "-C " + Q(verifyRoot) + " merge-base --is-ancestor " + Q(requestedRevision) + " " + Q(branchRef), null);
        if (ancestor.ExitCode != 0)
            throw new Exception("Commit '" + requestedRevision + "' does not belong to branch '" + branch + "'.");

        return requestedRevision.ToLowerInvariant();
    }

    static string PrepareGitSource(string revision)
    {
        string verifyRoot = Path.Combine(CacheRoot, "git-verify");

        ProcResult checkout = Run("git.exe", "-C " + Q(verifyRoot) + " checkout --force --detach " + Q(revision), null);
        if (checkout.ExitCode != 0)
            throw new Exception("Could not check out Git-testing revision: " + LastUsefulLine(checkout.StdErr));

        ProcResult clean = Run("git.exe", "-C " + Q(verifyRoot) + " clean -fdx", null);
        if (clean.ExitCode != 0)
            throw new Exception("Could not clean Git-testing source cache.");

        string manifest = Path.Combine(verifyRoot, "wgdot", "manifest.json");
        if (!File.Exists(manifest))
            throw new Exception("Revision " + revision + " is not WGDot-compatible.");

        return verifyRoot;
    }

    static string GetRelativeSourcePath(Dictionary<string, object> file, string glazeProfile)
    {
        object byProfileRaw;
        if (file.TryGetValue("sourceByGlazeProfile", out byProfileRaw) && byProfileRaw != null)
        {
            var byProfile = AsDictionary(byProfileRaw);
            return glazeProfile == "work" ? GetString(byProfile, "work") : GetString(byProfile, "normal");
        }

        return GetString(file, "source");
    }

    static string GetBaselinePath(string fileId)
    {
        string safe = Regex.Replace(fileId ?? "", "[^A-Za-z0-9._-]", "_");
        return Path.Combine(BaselineRoot, safe);
    }

    static bool IsSafeManagedDestination(string destination)
    {
        string full = Path.GetFullPath(Environment.ExpandEnvironmentVariables(destination));
        var roots = new[]
        {
            Environment.GetEnvironmentVariable("USERPROFILE"),
            Environment.GetEnvironmentVariable("APPDATA"),
            Environment.GetEnvironmentVariable("LOCALAPPDATA")
        }
        .Where(x => !String.IsNullOrWhiteSpace(x))
        .Select(Path.GetFullPath)
        .Distinct(StringComparer.OrdinalIgnoreCase);

        foreach (string root in roots)
        {
            string prefix = root.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
            if (full.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                return true;
        }

        return false;
    }

    static bool IsBackKey(ConsoleKey key)
    {
        return key == ConsoleKey.Escape || key == ConsoleKey.Q;
    }

    static int ReadSingleChoice(string title, List<string> items, int initialIndex)
    {
        if (items == null || items.Count == 0) return -1;
        int index = initialIndex >= 0 && initialIndex < items.Count ? initialIndex : 0;
        const int pageSize = 18;

        while (true)
        {
            WriteTitle(title);

            int start = 0;
            if (items.Count > pageSize)
            {
                start = index - pageSize / 2;
                if (start < 0) start = 0;
                int maxStart = items.Count - pageSize;
                if (start > maxStart) start = maxStart;
            }
            int end = Math.Min(items.Count, start + pageSize);

            for (int i = start; i < end; i++)
            {
                if (i == index) Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine((i == index ? "> " : "  ") + items[i]);
                Console.ResetColor();
            }

            if (items.Count > pageSize)
            {
                Console.WriteLine();
                Console.ForegroundColor = ConsoleColor.DarkGray;
                Console.WriteLine("Showing " + (start + 1) + "-" + end + " of " + items.Count);
                Console.ResetColor();
            }

            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.DarkGray;
            Console.WriteLine("Up/Down: move   PgUp/PgDn: page   Enter: select   Q/Esc: back");
            Console.ResetColor();

            ConsoleKey key = Console.ReadKey(true).Key;
            if (key == ConsoleKey.UpArrow) index = (index - 1 + items.Count) % items.Count;
            else if (key == ConsoleKey.DownArrow) index = (index + 1) % items.Count;
            else if (key == ConsoleKey.PageUp) index = Math.Max(0, index - pageSize);
            else if (key == ConsoleKey.PageDown) index = Math.Min(items.Count - 1, index + pageSize);
            else if (key == ConsoleKey.Home) index = 0;
            else if (key == ConsoleKey.End) index = items.Count - 1;
            else if (key == ConsoleKey.Enter) return index;
            else if (IsBackKey(key)) return -1;
        }
    }

    static string PackageCategoryLabel(string category)
    {
        switch ((category ?? "").ToLowerInvariant())
        {
            case "desktop": return "Desktop / WGDot";
            case "runtime": return "Runtimes";
            case "cli": return "CLI / Yazi helpers";
            case "browsers": return "Browsers";
            case "editors": return "Editors";
            case "utilities": return "General utilities";
            case "system": return "System / diagnostics";
            case "networking": return "Networking / remote";
            case "communication": return "Communication";
            case "media": return "Media";
            case "creative": return "Creative";
            case "3d-printing": return "3D printing";
            case "gaming": return "Gaming";
            case "security": return "Security";
            case "development": return "Development";
            case "virtualization": return "Virtualization";
            case "work": return "Work";
            default: return String.IsNullOrWhiteSpace(category) ? "Other" : category;
        }
    }

    static List<ChoiceItem> ReadPackageChoicesByCategory(
        string title,
        List<ChoiceItem> items,
        Dictionary<string, object> manifest,
        string scope,
        Dictionary<string, List<string>> browserOptions)
    {
        if (items == null || items.Count == 0) return items;

        string[] preferredOrder =
        {
            "desktop", "runtime", "cli", "browsers", "editors", "utilities",
            "system", "networking", "communication", "media", "creative",
            "3d-printing", "gaming", "security", "development", "virtualization", "work"
        };

        var categories = new List<string>();
        foreach (string category in preferredOrder)
            if (items.Any(x => String.Equals(x.Category, category, StringComparison.OrdinalIgnoreCase)))
                categories.Add(category);

        foreach (string category in items.Select(x => x.Category ?? "other").Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x))
            if (!categories.Contains(category, StringComparer.OrdinalIgnoreCase))
                categories.Add(category);

        int index = 0;
        while (true)
        {
            WriteTitle(title);

            for (int i = 0; i < categories.Count; i++)
            {
                string category = categories[i];
                List<ChoiceItem> group = items
                    .Where(x => String.Equals(x.Category, category, StringComparison.OrdinalIgnoreCase))
                    .ToList();
                int selected = group.Count(x => x.Selected);

                if (i == index) Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine((i == index ? "> " : "  ") +
                    PackageCategoryLabel(category) +
                    "  [" + selected + "/" + group.Count + "]");
                Console.ResetColor();
            }

            int doneIndex = categories.Count;
            if (index == doneIndex) Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine((index == doneIndex ? "> " : "  ") +
                "Done  [" + items.Count(x => x.Selected) + "/" + items.Count + " selected]");
            Console.ResetColor();

            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.DarkGray;
            Console.WriteLine("Enter: open category / finish   Q/Esc: back");
            Console.ResetColor();

            ConsoleKey key = Console.ReadKey(true).Key;
            int count = categories.Count + 1;
            if (key == ConsoleKey.UpArrow) index = (index - 1 + count) % count;
            else if (key == ConsoleKey.DownArrow) index = (index + 1) % count;
            else if (key == ConsoleKey.Home) index = 0;
            else if (key == ConsoleKey.End) index = doneIndex;
            else if (IsBackKey(key)) return null;
            else if (key == ConsoleKey.Enter)
            {
                if (index == doneIndex) return items;

                string category = categories[index];
                List<ChoiceItem> group = items
                    .Where(x => String.Equals(x.Category, category, StringComparison.OrdinalIgnoreCase))
                    .ToList();

                List<ChoiceItem> edited = String.Equals(category, "browsers", StringComparison.OrdinalIgnoreCase)
                    ? ReadBrowserPackageChoices(
                        PackageCategoryLabel(category),
                        group,
                        manifest,
                        scope,
                        browserOptions)
                    : ReadMultiChoice(PackageCategoryLabel(category), group);
                if (edited == null) continue;
            }
        }
    }

    static bool IsBrowserOptionsKey(ConsoleKey key)
    {
        return key == ConsoleKey.E;
    }

    static string BrowserOptionSummary(
        Dictionary<string, object> manifest,
        string packageId,
        Dictionary<string, List<string>> browserOptions)
    {
        Dictionary<string, object> browser = GetBrowserDefinition(manifest, packageId);
        if (browser == null) return "";

        string mode = GetString(browser, "mode");
        if (String.Equals(mode, "preserve-upstream", StringComparison.OrdinalIgnoreCase))
            return "  [as shipped]";

        int total = GetList(browser, "options").Count;
        List<string> selected;
        if (!browserOptions.TryGetValue(packageId, out selected))
            selected = new List<string>();
        return "  [" + selected.Count.ToString(CultureInfo.InvariantCulture) +
            "/" + total.ToString(CultureInfo.InvariantCulture) + " options]";
    }

    static List<ChoiceItem> ReadBrowserPackageChoices(
        string title,
        List<ChoiceItem> items,
        Dictionary<string, object> manifest,
        string scope,
        Dictionary<string, List<string>> browserOptions)
    {
        if (items == null || items.Count == 0) return items;
        int index = 0;

        while (true)
        {
            WriteTitle(title);

            for (int i = 0; i < items.Count; i++)
            {
                string mark = items[i].Selected ? "[x]" : "[ ]";
                if (i == index) Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine(
                    (i == index ? "> " : "  ") +
                    mark + " " + items[i].Label +
                    BrowserOptionSummary(manifest, items[i].Id, browserOptions));
                Console.ResetColor();
            }

            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.DarkGray;
            Console.WriteLine("Up/Down: move   Space: toggle   E: extensions/options");
            Console.WriteLine("Enter: accept   Q/Esc: back");
            Console.ResetColor();

            ConsoleKey key = Console.ReadKey(true).Key;
            if (key == ConsoleKey.UpArrow) index = (index - 1 + items.Count) % items.Count;
            else if (key == ConsoleKey.DownArrow) index = (index + 1) % items.Count;
            else if (key == ConsoleKey.Home) index = 0;
            else if (key == ConsoleKey.End) index = items.Count - 1;
            else if (key == ConsoleKey.Spacebar) items[index].Selected = !items[index].Selected;
            else if (IsBrowserOptionsKey(key))
                EditBrowserOptions(manifest, scope, items[index].Id, browserOptions);
            else if (key == ConsoleKey.Enter) return items;
            else if (IsBackKey(key)) return null;
        }
    }

    static void EditBrowserOptions(
        Dictionary<string, object> manifest,
        string scope,
        string packageId,
        Dictionary<string, List<string>> browserOptions)
    {
        Dictionary<string, object> browser = GetBrowserDefinition(manifest, packageId);
        if (browser == null) return;

        string browserName = GetString(browser, "name");
        string notice = GetString(browser, "notice");
        List<object> optionDefs = GetList(browser, "options");

        if (optionDefs.Count == 0)
        {
            ShowBrowserNotice(browserName, notice);
            return;
        }

        List<string> selected;
        if (!browserOptions.TryGetValue(packageId, out selected))
        {
            selected = new List<string>();
            foreach (object rawOption in optionDefs)
            {
                var option = AsDictionary(rawOption);
                bool enabled = scope == "work"
                    ? GetBool(option, "defaultWork")
                    : GetBool(option, "defaultNormal");
                if (enabled) selected.Add(GetString(option, "id"));
            }
        }

        var selectedSet = new HashSet<string>(selected, StringComparer.OrdinalIgnoreCase);
        var choices = new List<ChoiceItem>();
        foreach (object rawOption in optionDefs)
        {
            var option = AsDictionary(rawOption);
            string id = GetString(option, "id");
            choices.Add(new ChoiceItem
            {
                Id = id,
                Label = GetString(option, "name"),
                Selected = selectedSet.Contains(id)
            });
        }

        List<ChoiceItem> edited = ReadBrowserOptionChoices(
            browserName + " extensions / options",
            notice,
            choices);

        // Browser-option checkboxes are edited in place. Q/Esc means "back",
        // not "cancel", so preserve the toggles exactly like the package menus do.
        // This matters for default-OFF Firefox options such as Dark Reader and
        // ScrollAnywhere: previously they were silently discarded when the user
        // toggled them and then backed out of the nested options screen.
        if (edited == null) edited = choices;

        browserOptions[packageId] = edited
            .Where(x => x.Selected)
            .Select(x => x.Id)
            .ToList();
    }

    static List<ChoiceItem> ReadBrowserOptionChoices(
        string title,
        string notice,
        List<ChoiceItem> items)
    {
        if (items == null || items.Count == 0) return items;
        int index = 0;
        const int pageSize = 18;

        while (true)
        {
            WriteTitle(title);

            if (!String.IsNullOrWhiteSpace(notice))
            {
                Console.ForegroundColor = ConsoleColor.DarkGray;
                Console.WriteLine(notice);
                Console.ResetColor();
                Console.WriteLine();
            }

            int start = 0;
            if (items.Count > pageSize)
            {
                start = index - pageSize / 2;
                if (start < 0) start = 0;
                int maxStart = items.Count - pageSize;
                if (start > maxStart) start = maxStart;
            }
            int end = Math.Min(items.Count, start + pageSize);

            for (int i = start; i < end; i++)
            {
                string mark = items[i].Selected ? "[x]" : "[ ]";
                if (i == index) Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine((i == index ? "> " : "  ") + mark + " " + items[i].Label);
                Console.ResetColor();
            }

            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.DarkGray;
            Console.WriteLine("Up/Down: move   Space: toggle");
            Console.WriteLine("Enter: accept   Q/Esc: back");
            Console.ResetColor();

            ConsoleKey key = Console.ReadKey(true).Key;
            if (key == ConsoleKey.UpArrow) index = (index - 1 + items.Count) % items.Count;
            else if (key == ConsoleKey.DownArrow) index = (index + 1) % items.Count;
            else if (key == ConsoleKey.PageUp) index = Math.Max(0, index - pageSize);
            else if (key == ConsoleKey.PageDown) index = Math.Min(items.Count - 1, index + pageSize);
            else if (key == ConsoleKey.Home) index = 0;
            else if (key == ConsoleKey.End) index = items.Count - 1;
            else if (key == ConsoleKey.Spacebar) items[index].Selected = !items[index].Selected;
            else if (key == ConsoleKey.Enter) return items;
            else if (IsBackKey(key)) return null;
        }
    }

    static void ShowBrowserNotice(string browserName, string notice)
    {
        while (true)
        {
            WriteTitle(browserName + " browser options");
            Console.WriteLine(notice);
            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.DarkGray;
            Console.WriteLine("Enter/Q/Esc: back");
            Console.ResetColor();

            ConsoleKey key = Console.ReadKey(true).Key;
            if (key == ConsoleKey.Enter || IsBackKey(key)) return;
        }
    }

    static List<ChoiceItem> ReadMultiChoice(string title, List<ChoiceItem> items)
    {
        if (items == null || items.Count == 0) return items;
        int index = 0;
        const int pageSize = 18;

        while (true)
        {
            WriteTitle(title);

            int start = 0;
            if (items.Count > pageSize)
            {
                start = index - pageSize / 2;
                if (start < 0) start = 0;
                int maxStart = items.Count - pageSize;
                if (start > maxStart) start = maxStart;
            }
            int end = Math.Min(items.Count, start + pageSize);

            for (int i = start; i < end; i++)
            {
                string mark = items[i].Selected ? "[x]" : "[ ]";
                if (i == index) Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine((i == index ? "> " : "  ") + mark + " " + items[i].Label);
                Console.ResetColor();
            }

            int selectedCount = items.Count(x => x.Selected);
            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.DarkGray;
            if (items.Count > pageSize)
                Console.WriteLine("Showing " + (start + 1) + "-" + end + " of " + items.Count + "   Selected: " + selectedCount);
            else
                Console.WriteLine("Selected: " + selectedCount);
            Console.WriteLine("Up/Down: move   PgUp/PgDn: page   Space: toggle   A: all   N: none");
            Console.WriteLine("Enter: accept   Q/Esc: back");
            Console.ResetColor();

            ConsoleKey key = Console.ReadKey(true).Key;
            if (key == ConsoleKey.UpArrow) index = (index - 1 + items.Count) % items.Count;
            else if (key == ConsoleKey.DownArrow) index = (index + 1) % items.Count;
            else if (key == ConsoleKey.PageUp) index = Math.Max(0, index - pageSize);
            else if (key == ConsoleKey.PageDown) index = Math.Min(items.Count - 1, index + pageSize);
            else if (key == ConsoleKey.Home) index = 0;
            else if (key == ConsoleKey.End) index = items.Count - 1;
            else if (key == ConsoleKey.Spacebar) items[index].Selected = !items[index].Selected;
            else if (key == ConsoleKey.A) foreach (ChoiceItem item in items) item.Selected = true;
            else if (key == ConsoleKey.N) foreach (ChoiceItem item in items) item.Selected = false;
            else if (key == ConsoleKey.Enter) return items;
            else if (IsBackKey(key)) return null;
        }
    }


    static void ApplyBrowserConfiguration(
        Dictionary<string, object> manifest,
        InstallationSelection selection,
        bool applyFirefoxExtensionPolicy)
    {
        if (selection == null || !selection.BrowserOptionsConfigured)
        {
            Console.WriteLine();
            Console.WriteLine("Browser options are not configured yet; existing browser state is preserved.");
            return;
        }

        var selectedPackages = new HashSet<string>(
            selection.Packages ?? new List<string>(),
            StringComparer.OrdinalIgnoreCase);

        foreach (object rawBrowser in GetList(manifest, "browserOptions"))
        {
            var browser = AsDictionary(rawBrowser);
            string packageId = GetString(browser, "packageId");
            string mode = GetString(browser, "mode");
            bool packageSelected = selectedPackages.Contains(packageId);

            List<string> selectedOptions;
            if (!selection.BrowserOptions.TryGetValue(packageId, out selectedOptions))
                selectedOptions = new List<string>();

            if (String.Equals(mode, "firefox-managed", StringComparison.OrdinalIgnoreCase))
            {
                ApplyFirefoxBrowserOptions(
                    browser,
                    packageSelected ? selectedOptions : new List<string>(),
                    applyFirefoxExtensionPolicy);
            }
            else if (String.Equals(mode, "guided-chrome-web-store", StringComparison.OrdinalIgnoreCase))
            {
                if (packageSelected)
                    ApplyBraveBrowserOptions(browser, selectedOptions);
            }
            else if (String.Equals(mode, "preserve-upstream", StringComparison.OrdinalIgnoreCase))
            {
                if (packageSelected)
                {
                    Console.WriteLine();
                    Console.WriteLine(GetString(browser, "name") + ":");
                    Console.WriteLine(GetString(browser, "notice"));
                }
            }
            else if (!String.IsNullOrWhiteSpace(mode))
            {
                throw new Exception("Unknown browser management mode '" + mode + "'.");
            }
        }
    }

    static void ApplyFirefoxBrowserOptions(
        Dictionary<string, object> browser,
        List<string> selectedOptions,
        bool applyExtensionPolicy)
    {
        var selected = new HashSet<string>(
            selectedOptions ?? new List<string>(),
            StringComparer.OrdinalIgnoreCase);
        var installUrls = new List<string>();
        Dictionary<string, object> betterfoxOption = null;

        foreach (object rawOption in GetList(browser, "options"))
        {
            var option = AsDictionary(rawOption);
            string id = GetString(option, "id");
            string kind = GetString(option, "kind");

            if (String.Equals(kind, "firefox-extension", StringComparison.OrdinalIgnoreCase) &&
                selected.Contains(id))
            {
                string installUrl = GetString(option, "installUrl");
                if (!String.IsNullOrWhiteSpace(installUrl))
                    installUrls.Add(installUrl);
            }
            else if (String.Equals(kind, "betterfox", StringComparison.OrdinalIgnoreCase))
            {
                betterfoxOption = option;
            }
        }

        if (applyExtensionPolicy)
            ApplyFirefoxExtensionInstallPolicy(installUrls);

        bool enableBetterfox =
            betterfoxOption != null &&
            selected.Contains(GetString(betterfoxOption, "id"));
        ApplyBetterfox(betterfoxOption, enableBetterfox, GetFirefoxRoot());
    }

    static List<string> GetDesiredFirefoxExtensionInstallUrls(
        Dictionary<string, object> manifest,
        InstallationSelection selection)
    {
        var result = new List<string>();
        if (selection == null || !selection.BrowserOptionsConfigured)
            return result;

        var selectedPackages = new HashSet<string>(
            selection.Packages ?? new List<string>(),
            StringComparer.OrdinalIgnoreCase);

        foreach (object rawBrowser in GetList(manifest, "browserOptions"))
        {
            var browser = AsDictionary(rawBrowser);
            if (!String.Equals(
                    GetString(browser, "mode"),
                    "firefox-managed",
                    StringComparison.OrdinalIgnoreCase))
                continue;

            string packageId = GetString(browser, "packageId");
            if (!selectedPackages.Contains(packageId))
                return result;

            List<string> selectedOptions;
            if (!selection.BrowserOptions.TryGetValue(packageId, out selectedOptions))
                selectedOptions = new List<string>();

            var selected = new HashSet<string>(
                selectedOptions,
                StringComparer.OrdinalIgnoreCase);

            foreach (object rawOption in GetList(browser, "options"))
            {
                var option = AsDictionary(rawOption);
                if (!String.Equals(
                        GetString(option, "kind"),
                        "firefox-extension",
                        StringComparison.OrdinalIgnoreCase))
                    continue;
                if (!selected.Contains(GetString(option, "id")))
                    continue;

                string url = GetString(option, "installUrl");
                if (!String.IsNullOrWhiteSpace(url) &&
                    !result.Contains(url, StringComparer.OrdinalIgnoreCase))
                    result.Add(url);
            }

            return result;
        }

        return result;
    }

    static string GetFirefoxRoot()
    {
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Mozilla",
            "Firefox");
    }

    static List<string> ReadFirefoxInstallPolicyUrls()
    {
        const string path = @"Software\Policies\Mozilla\Firefox\Extensions\Install";
        var numbered = new List<KeyValuePair<int, string>>();

        using (RegistryKey key = Registry.CurrentUser.OpenSubKey(path, false))
        {
            if (key == null) return new List<string>();

            foreach (string name in key.GetValueNames())
            {
                int number;
                if (!Int32.TryParse(name, NumberStyles.Integer, CultureInfo.InvariantCulture, out number))
                    continue;

                RegistryValueKind kind = key.GetValueKind(name);
                if (kind != RegistryValueKind.String && kind != RegistryValueKind.ExpandString)
                    throw new Exception(
                        "Firefox Extensions.Install policy value '" + name +
                        "' is not a string; WGDot will not rewrite it.");

                object value = key.GetValue(
                    name,
                    null,
                    RegistryValueOptions.DoNotExpandEnvironmentNames);
                string url = value == null ? "" : Convert.ToString(value);
                if (!String.IsNullOrWhiteSpace(url))
                    numbered.Add(new KeyValuePair<int, string>(number, url));
            }
        }

        return numbered
            .OrderBy(x => x.Key)
            .Select(x => x.Value)
            .ToList();
    }

    static List<string> MergeManagedFirefoxInstallUrls(
        IEnumerable<string> current,
        IEnumerable<string> previousOwned,
        IEnumerable<string> desired,
        out List<string> nextOwned)
    {
        var oldOwned = new HashSet<string>(
            previousOwned ?? new string[0],
            StringComparer.OrdinalIgnoreCase);
        var desiredList = (desired ?? new string[0])
            .Where(x => !String.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        var external = new List<string>();
        foreach (string url in current ?? new string[0])
        {
            if (String.IsNullOrWhiteSpace(url) || oldOwned.Contains(url)) continue;
            if (!external.Contains(url, StringComparer.OrdinalIgnoreCase))
                external.Add(url);
        }

        var externalSet = new HashSet<string>(external, StringComparer.OrdinalIgnoreCase);
        var merged = new List<string>(external);
        nextOwned = new List<string>();

        foreach (string url in desiredList)
        {
            if (!merged.Contains(url, StringComparer.OrdinalIgnoreCase))
                merged.Add(url);
            if (!externalSet.Contains(url))
                nextOwned.Add(url);
        }

        return merged;
    }

    static bool FirefoxExtensionInstallPolicyNeedsMutation(List<string> desiredUrls)
    {
        Dictionary<string, object> state =
            ReadJson(BrowserStatePath) ??
            new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        List<string> previousOwned = GetStringList(state, "firefoxOwnedInstallUrls");
        List<string> current = ReadFirefoxInstallPolicyUrls();
        List<string> nextOwned;
        List<string> merged = MergeManagedFirefoxInstallUrls(
            current,
            previousOwned,
            desiredUrls,
            out nextOwned);

        return !current.SequenceEqual(merged, StringComparer.OrdinalIgnoreCase);
    }

    static void ApplyFirefoxExtensionInstallPolicy(List<string> desiredUrls)
    {
        const string path = @"Software\Policies\Mozilla\Firefox\Extensions\Install";

        Dictionary<string, object> state =
            ReadJson(BrowserStatePath) ??
            new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        List<string> previousOwned = GetStringList(state, "firefoxOwnedInstallUrls");
        List<string> current = ReadFirefoxInstallPolicyUrls();
        List<string> nextOwned;
        List<string> merged = MergeManagedFirefoxInstallUrls(
            current,
            previousOwned,
            desiredUrls,
            out nextOwned);

        bool same = current.SequenceEqual(merged, StringComparer.OrdinalIgnoreCase);
        if (!same)
        {
            using (RegistryKey key = Registry.CurrentUser.CreateSubKey(path))
            {
                if (key == null)
                    throw new Exception("Could not open Firefox Extensions.Install policy.");

                foreach (string name in key.GetValueNames())
                {
                    int number;
                    if (Int32.TryParse(name, NumberStyles.Integer, CultureInfo.InvariantCulture, out number))
                        key.DeleteValue(name, false);
                }

                for (int i = 0; i < merged.Count; i++)
                {
                    key.SetValue(
                        (i + 1).ToString(CultureInfo.InvariantCulture),
                        merged[i],
                        RegistryValueKind.String);
                }
            }

            if (merged.Count == 0)
                DeleteRegistryKeyIfEmpty("HKCU", path);
        }

        state["firefoxOwnedInstallUrls"] = nextOwned.ToArray();
        WriteJson(BrowserStatePath, state);

        Console.WriteLine();
        Console.WriteLine(
            "Firefox signed extension install requests: " +
            desiredUrls.Count.ToString(CultureInfo.InvariantCulture) + ".");
        if (previousOwned.Count > 0 && nextOwned.Count == 0)
            Console.WriteLine("WGDot-owned Firefox extension install policy entries were removed.");
    }

    static void ApplyBraveBrowserOptions(
        Dictionary<string, object> browser,
        List<string> selectedOptions)
    {
        var selected = new HashSet<string>(
            selectedOptions ?? new List<string>(),
            StringComparer.OrdinalIgnoreCase);

        Dictionary<string, object> state =
            ReadJson(BrowserStatePath) ??
            new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        var reviewed = new HashSet<string>(
            GetStringList(state, "braveGuidedReviewedOptions"),
            StringComparer.OrdinalIgnoreCase);
        reviewed.IntersectWith(selected);

        var storeOptions = new List<Dictionary<string, object>>();
        var braveSettingsOptions = new List<Dictionary<string, object>>();

        foreach (object rawOption in GetList(browser, "options"))
        {
            var option = AsDictionary(rawOption);
            string id = GetString(option, "id");
            if (!selected.Contains(id) || reviewed.Contains(id)) continue;

            string kind = GetString(option, "kind");
            if (String.Equals(kind, "chrome-web-store", StringComparison.OrdinalIgnoreCase))
                storeOptions.Add(option);
            else if (String.Equals(kind, "brave-mv2-settings", StringComparison.OrdinalIgnoreCase))
                braveSettingsOptions.Add(option);
        }

        if (storeOptions.Count == 0 && braveSettingsOptions.Count == 0)
        {
            state["braveGuidedReviewedOptions"] = reviewed.ToArray();
            WriteJson(BrowserStatePath, state);
            return;
        }

        Console.WriteLine();
        Console.WriteLine(GetString(browser, "notice"));

        if (braveSettingsOptions.Count > 0)
        {
            Console.WriteLine();
            Console.WriteLine("uBlock Origin uses Brave's supported Manifest V2 extension page.");
            if (ReadYesNo(
                "Open Brave's Manifest V2 extension settings for uBlock Origin? [y/N]",
                false))
            {
                foreach (Dictionary<string, object> option in braveSettingsOptions)
                {
                    OpenBraveInternalUrl(GetString(option, "settingsUrl"));
                    reviewed.Add(GetString(option, "id"));
                }
            }
        }

        if (storeOptions.Count > 0)
        {
            Console.WriteLine();
            Console.WriteLine(
                "Selected Brave Chrome Web Store pages: " +
                storeOptions.Count.ToString(CultureInfo.InvariantCulture) + ".");
            if (ReadYesNo(
                "Open the selected official Chrome Web Store pages for manual Add to Brave approval? [y/N]",
                false))
            {
                foreach (Dictionary<string, object> option in storeOptions)
                {
                    OpenUrl(GetString(option, "storeUrl"));
                    reviewed.Add(GetString(option, "id"));
                }
            }
        }

        state["braveGuidedReviewedOptions"] = reviewed.ToArray();
        WriteJson(BrowserStatePath, state);
    }

    static string FindBraveExecutable()
    {
        const string appPath =
            @"Software\Microsoft\Windows\CurrentVersion\App Paths\brave.exe";

        foreach (RegistryKey root in new[] { Registry.CurrentUser, Registry.LocalMachine })
        {
            try
            {
                using (RegistryKey key = root.OpenSubKey(appPath, false))
                {
                    if (key != null)
                    {
                        string registered = Convert.ToString(key.GetValue(null, ""));
                        if (!String.IsNullOrWhiteSpace(registered) && File.Exists(registered))
                            return registered;
                    }
                }
            }
            catch
            {
            }
        }

        string[] roots =
        {
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86)
        };

        foreach (string root in roots
            .Where(x => !String.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.OrdinalIgnoreCase))
        {
            string candidate = Path.Combine(
                root,
                "BraveSoftware",
                "Brave-Browser",
                "Application",
                "brave.exe");
            if (File.Exists(candidate)) return candidate;
        }

        return "";
    }

    static void OpenBraveInternalUrl(string url)
    {
        if (!String.Equals(
            url,
            "brave://settings/extensions/v2",
            StringComparison.OrdinalIgnoreCase))
            throw new Exception("Unsupported Brave internal setup URL.");

        string braveExe = FindBraveExecutable();
        if (String.IsNullOrWhiteSpace(braveExe))
        {
            Console.WriteLine(
                "Brave executable was not found. Open brave://settings/extensions/v2 manually and enable uBlock Origin.");
            return;
        }

        var psi = new ProcessStartInfo();
        psi.FileName = braveExe;
        psi.Arguments = "\"" + url + "\"";
        psi.UseShellExecute = true;
        Process.Start(psi);
    }

    static void OpenUrl(string url)
    {
        if (!Uri.IsWellFormedUriString(url, UriKind.Absolute))
            throw new Exception("Invalid browser URL: " + url);

        Uri uri = new Uri(url);
        if (!String.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
            throw new Exception("WGDot only opens HTTPS browser setup URLs.");

        var psi = new ProcessStartInfo();
        psi.FileName = url;
        psi.UseShellExecute = true;
        Process.Start(psi);
    }

    static List<IniSection> ReadIniSections(string path)
    {
        var sections = new List<IniSection>();
        IniSection current = null;

        if (!File.Exists(path)) return sections;

        foreach (string rawLine in File.ReadAllLines(path))
        {
            string line = rawLine.Trim();
            if (line.Length == 0 || line.StartsWith(";") || line.StartsWith("#"))
                continue;

            if (line.StartsWith("[") && line.EndsWith("]") && line.Length > 2)
            {
                current = new IniSection();
                current.Name = line.Substring(1, line.Length - 2);
                sections.Add(current);
                continue;
            }

            int equals = line.IndexOf('=');
            if (current == null || equals <= 0) continue;

            string key = line.Substring(0, equals).Trim();
            string value = line.Substring(equals + 1).Trim();
            current.Values[key] = value;
        }

        return sections;
    }

    static string SerializeIniSections(List<IniSection> sections)
    {
        var sb = new StringBuilder();
        foreach (IniSection section in sections)
        {
            if (String.IsNullOrWhiteSpace(section.Name)) continue;
            sb.Append('[').Append(section.Name).Append("]\r\n");
            foreach (KeyValuePair<string, string> pair in section.Values)
                sb.Append(pair.Key).Append('=').Append(pair.Value ?? "").Append("\r\n");
            sb.Append("\r\n");
        }
        return sb.ToString();
    }

    static void WriteIniSectionsIfChanged(
        string path,
        List<IniSection> sections,
        string operation)
    {
        string next = SerializeIniSections(sections);
        string current = File.Exists(path) ? File.ReadAllText(path) : "";
        if (String.Equals(current, next, StringComparison.Ordinal)) return;

        if (File.Exists(path))
            CreateBackup(path, operation);

        Directory.CreateDirectory(Path.GetDirectoryName(path));
        File.WriteAllText(path, next, new UTF8Encoding(false));
    }

    static string GetIniDefaultPath(List<IniSection> sections)
    {
        foreach (IniSection section in sections)
        {
            if (!section.Name.StartsWith("Install", StringComparison.OrdinalIgnoreCase))
                continue;
            string value;
            if (section.Values.TryGetValue("Default", out value) &&
                !String.IsNullOrWhiteSpace(value))
                return value;
        }

        foreach (IniSection section in sections)
        {
            if (!section.Name.StartsWith("Profile", StringComparison.OrdinalIgnoreCase))
                continue;

            string isDefault;
            string path;
            if (section.Values.TryGetValue("Default", out isDefault) &&
                String.Equals(isDefault, "1", StringComparison.OrdinalIgnoreCase) &&
                section.Values.TryGetValue("Path", out path) &&
                !String.IsNullOrWhiteSpace(path))
                return path;
        }

        return "";
    }

    static string GetFirefoxDefaultProfilePath(string firefoxRoot)
    {
        string profilesPath = Path.Combine(firefoxRoot, "profiles.ini");
        string installsPath = Path.Combine(firefoxRoot, "installs.ini");

        List<IniSection> profiles = ReadIniSections(profilesPath);
        string fromProfiles = GetIniDefaultPath(profiles);
        if (!String.IsNullOrWhiteSpace(fromProfiles)) return fromProfiles;

        foreach (IniSection section in ReadIniSections(installsPath))
        {
            string value;
            if (section.Values.TryGetValue("Default", out value) &&
                !String.IsNullOrWhiteSpace(value))
                return value;
        }

        return "";
    }

    static bool FirefoxProfileRegistered(string firefoxRoot, string relativePath)
    {
        string profilesPath = Path.Combine(firefoxRoot, "profiles.ini");
        foreach (IniSection section in ReadIniSections(profilesPath))
        {
            if (!section.Name.StartsWith("Profile", StringComparison.OrdinalIgnoreCase))
                continue;

            string path;
            if (section.Values.TryGetValue("Path", out path) &&
                String.Equals(
                    (path ?? "").Replace('\\', '/'),
                    (relativePath ?? "").Replace('\\', '/'),
                    StringComparison.OrdinalIgnoreCase))
                return true;
        }
        return false;
    }

    static bool IsProcessRunning(string processName)
    {
        Process[] processes = Process.GetProcessesByName(processName);
        try
        {
            return processes.Length > 0;
        }
        finally
        {
            foreach (Process process in processes)
                process.Dispose();
        }
    }

    static bool WaitForProcessToAppear(string processName, int timeoutMs)
    {
        Stopwatch stopwatch = Stopwatch.StartNew();
        do
        {
            if (IsProcessRunning(processName))
                return true;
            System.Threading.Thread.Sleep(200);
        }
        while (stopwatch.ElapsedMilliseconds < timeoutMs);

        return IsProcessRunning(processName);
    }

    static void WaitForProcessToExit(string processName)
    {
        int emptyPasses = 0;
        while (emptyPasses < 4)
        {
            if (IsProcessRunning(processName))
                emptyPasses = 0;
            else
                emptyPasses++;

            System.Threading.Thread.Sleep(500);
        }
    }

    static string EnsureWgdotFirefoxProfile(string firefoxRoot)
    {
        const string relativePath = "Profiles/wgdot.betterfox";
        string profilesPath = Path.Combine(firefoxRoot, "profiles.ini");
        Directory.CreateDirectory(firefoxRoot);
        Directory.CreateDirectory(
            Path.Combine(firefoxRoot, relativePath.Replace('/', Path.DirectorySeparatorChar)));

        List<IniSection> sections = ReadIniSections(profilesPath);
        if (sections.Count == 0)
        {
            var general = new IniSection();
            general.Name = "General";
            general.Values["StartWithLastProfile"] = "1";
            general.Values["Version"] = "2";
            sections.Add(general);
        }

        IniSection profile = sections.FirstOrDefault(x =>
        {
            if (!x.Name.StartsWith("Profile", StringComparison.OrdinalIgnoreCase)) return false;
            string path;
            return x.Values.TryGetValue("Path", out path) &&
                String.Equals(
                    path.Replace('\\', '/'),
                    relativePath,
                    StringComparison.OrdinalIgnoreCase);
        });

        if (profile == null)
        {
            int nextIndex = 0;
            foreach (IniSection section in sections)
            {
                if (!section.Name.StartsWith("Profile", StringComparison.OrdinalIgnoreCase))
                    continue;
                int value;
                if (Int32.TryParse(
                    section.Name.Substring("Profile".Length),
                    NumberStyles.Integer,
                    CultureInfo.InvariantCulture,
                    out value))
                    nextIndex = Math.Max(nextIndex, value + 1);
            }

            profile = new IniSection();
            profile.Name = "Profile" + nextIndex.ToString(CultureInfo.InvariantCulture);
            profile.Values["Name"] = "WGDot Betterfox";
            profile.Values["IsRelative"] = "1";
            profile.Values["Path"] = relativePath;
            sections.Add(profile);
            WriteIniSectionsIfChanged(
                profilesPath,
                sections,
                "browser-firefox-profiles");
        }

        return relativePath;
    }

    static void SetFirefoxDefaultProfile(
        string firefoxRoot,
        string targetRelativePath,
        string previousDefault)
    {
        string profilesPath = Path.Combine(firefoxRoot, "profiles.ini");
        List<IniSection> profiles = ReadIniSections(profilesPath);
        bool foundTarget = false;

        foreach (IniSection section in profiles)
        {
            if (!section.Name.StartsWith("Profile", StringComparison.OrdinalIgnoreCase))
                continue;

            string path;
            bool isTarget =
                section.Values.TryGetValue("Path", out path) &&
                String.Equals(
                    path.Replace('\\', '/'),
                    targetRelativePath.Replace('\\', '/'),
                    StringComparison.OrdinalIgnoreCase);
            if (isTarget)
            {
                section.Values["Default"] = "1";
                foundTarget = true;
            }
            else
            {
                section.Values.Remove("Default");
            }
        }

        if (!foundTarget)
            throw new Exception("WGDot Firefox profile is not registered in profiles.ini.");

        List<IniSection> profileInstalls = profiles
            .Where(x => x.Name.StartsWith("Install", StringComparison.OrdinalIgnoreCase))
            .ToList();
        foreach (IniSection section in profileInstalls)
        {
            string current;
            bool matchesPrevious =
                section.Values.TryGetValue("Default", out current) &&
                String.Equals(
                    (current ?? "").Replace('\\', '/'),
                    (previousDefault ?? "").Replace('\\', '/'),
                    StringComparison.OrdinalIgnoreCase);
            if (profileInstalls.Count == 1 || matchesPrevious)
                section.Values["Default"] = targetRelativePath;
        }
        WriteIniSectionsIfChanged(
            profilesPath,
            profiles,
            "browser-firefox-default");

        string installsPath = Path.Combine(firefoxRoot, "installs.ini");
        if (File.Exists(installsPath))
        {
            List<IniSection> installs = ReadIniSections(installsPath);
            foreach (IniSection section in installs)
            {
                string current;
                bool matchesPrevious =
                    section.Values.TryGetValue("Default", out current) &&
                    String.Equals(
                        (current ?? "").Replace('\\', '/'),
                        (previousDefault ?? "").Replace('\\', '/'),
                        StringComparison.OrdinalIgnoreCase);
                if (installs.Count == 1 || matchesPrevious)
                    section.Values["Default"] = targetRelativePath;
            }
            WriteIniSectionsIfChanged(
                installsPath,
                installs,
                "browser-firefox-default");
        }
    }

    static void RestoreFirefoxDefaultProfile(
        string firefoxRoot,
        string previousDefault,
        string wgdotRelativePath)
    {
        string currentDefault = GetFirefoxDefaultProfilePath(firefoxRoot);
        if (!String.Equals(
            (currentDefault ?? "").Replace('\\', '/'),
            (wgdotRelativePath ?? "").Replace('\\', '/'),
            StringComparison.OrdinalIgnoreCase))
        {
            Console.WriteLine(
                "Firefox default profile changed outside WGDot; WGDot will not override the user's newer choice.");
            return;
        }

        string profilesPath = Path.Combine(firefoxRoot, "profiles.ini");
        List<IniSection> profiles = ReadIniSections(profilesPath);

        foreach (IniSection section in profiles)
        {
            if (section.Name.StartsWith("Profile", StringComparison.OrdinalIgnoreCase))
            {
                string path;
                bool isPrevious =
                    !String.IsNullOrWhiteSpace(previousDefault) &&
                    section.Values.TryGetValue("Path", out path) &&
                    String.Equals(
                        path.Replace('\\', '/'),
                        previousDefault.Replace('\\', '/'),
                        StringComparison.OrdinalIgnoreCase);
                if (isPrevious)
                    section.Values["Default"] = "1";
                else
                    section.Values.Remove("Default");
            }
            else if (section.Name.StartsWith("Install", StringComparison.OrdinalIgnoreCase))
            {
                string value;
                if (section.Values.TryGetValue("Default", out value) &&
                    String.Equals(
                        (value ?? "").Replace('\\', '/'),
                        wgdotRelativePath.Replace('\\', '/'),
                        StringComparison.OrdinalIgnoreCase))
                {
                    if (String.IsNullOrWhiteSpace(previousDefault))
                        section.Values.Remove("Default");
                    else
                        section.Values["Default"] = previousDefault;
                }
            }
        }

        WriteIniSectionsIfChanged(
            profilesPath,
            profiles,
            "browser-firefox-default-rollback");

        string installsPath = Path.Combine(firefoxRoot, "installs.ini");
        if (File.Exists(installsPath))
        {
            List<IniSection> installs = ReadIniSections(installsPath);
            foreach (IniSection section in installs)
            {
                string value;
                if (!section.Values.TryGetValue("Default", out value) ||
                    !String.Equals(
                        (value ?? "").Replace('\\', '/'),
                        wgdotRelativePath.Replace('\\', '/'),
                        StringComparison.OrdinalIgnoreCase))
                    continue;

                if (String.IsNullOrWhiteSpace(previousDefault))
                    section.Values.Remove("Default");
                else
                    section.Values["Default"] = previousDefault;
            }
            WriteIniSectionsIfChanged(
                installsPath,
                installs,
                "browser-firefox-default-rollback");
        }
    }

    static void ApplyBetterfox(
        Dictionary<string, object> option,
        bool enable,
        string firefoxRoot)
    {
        const string wgdotRelativePath = "Profiles/wgdot.betterfox";
        Dictionary<string, object> state =
            ReadJson(BrowserStatePath) ??
            new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        Dictionary<string, object> betterfoxState = GetDictionary(state, "betterfox");

        if (!enable)
        {
            if (GetBool(betterfoxState, "defaultChanged"))
            {
                if (IsProcessRunning("firefox"))
                    throw new Exception(
                        "Firefox is running. Close Firefox before WGDot restores the previous default profile.");

                RestoreFirefoxDefaultProfile(
                    firefoxRoot,
                    GetString(betterfoxState, "previousDefaultProfile"),
                    wgdotRelativePath);
                betterfoxState["defaultChanged"] = false;
            }

            string managedProfile = Path.Combine(
                firefoxRoot,
                wgdotRelativePath.Replace('/', Path.DirectorySeparatorChar));
            string managedUserJs = Path.Combine(managedProfile, "user.js");
            string expectedHash = GetString(betterfoxState, "lastUserJsSha256");
            if (File.Exists(managedUserJs) && !String.IsNullOrWhiteSpace(expectedHash))
            {
                string currentHash = Sha256OrNull(managedUserJs);
                if (String.Equals(currentHash, expectedHash, StringComparison.OrdinalIgnoreCase))
                {
                    CreateBackup(managedUserJs, "browser-betterfox-rollback");
                    SafeDeleteFile(managedUserJs);
                    Console.WriteLine("WGDot Betterfox user.js removed; the dedicated profile was preserved.");
                }
                else
                {
                    Console.WriteLine(
                        "WGDot Betterfox user.js was modified after setup; leaving it unchanged.");
                }
            }

            betterfoxState["lastUserJsSha256"] = "";
            betterfoxState["defaultProfileReviewed"] = false;
            state["betterfox"] = betterfoxState;
            WriteJson(BrowserStatePath, state);
            return;
        }

        if (option == null)
            throw new Exception("Betterfox is selected but its manifest definition is missing.");

        string sourceUrl = GetString(option, "sourceUrl");
        Uri sourceUri;
        if (!Uri.TryCreate(sourceUrl, UriKind.Absolute, out sourceUri) ||
            !String.Equals(sourceUri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) ||
            !String.Equals(sourceUri.Host, "raw.githubusercontent.com", StringComparison.OrdinalIgnoreCase))
            throw new Exception("Betterfox source must be the approved upstream GitHub HTTPS URL.");

        if (!FirefoxProfileRegistered(firefoxRoot, wgdotRelativePath) &&
            IsProcessRunning("firefox"))
            throw new Exception(
                "Firefox is running. Close Firefox before WGDot creates the dedicated Betterfox profile.");

        string relativePath = EnsureWgdotFirefoxProfile(firefoxRoot);
        string profilePath = Path.Combine(
            firefoxRoot,
            relativePath.Replace('/', Path.DirectorySeparatorChar));
        string userJs = Path.Combine(profilePath, "user.js");
        Directory.CreateDirectory(profilePath);

        string temp = Path.Combine(
            CacheRoot,
            "betterfox-user-" + Guid.NewGuid().ToString("N") + ".js");
        Directory.CreateDirectory(CacheRoot);
        try
        {
            using (var client = new WebClient())
            {
                client.Headers[HttpRequestHeader.UserAgent] = "wgdot";
                client.DownloadFile(sourceUrl, temp);
            }

            string downloadedHash = Sha256OrNull(temp);
            if (String.IsNullOrWhiteSpace(downloadedHash))
                throw new Exception("Downloaded Betterfox user.js is empty or unreadable.");

            if (!String.Equals(
                Sha256OrNull(userJs),
                downloadedHash,
                StringComparison.OrdinalIgnoreCase))
            {
                if (File.Exists(userJs))
                    CreateBackup(userJs, "browser-betterfox-userjs");
                File.Copy(temp, userJs, true);
            }

            betterfoxState["lastUserJsSha256"] = downloadedHash;
            betterfoxState["profilePath"] = relativePath;
        }
        finally
        {
            SafeDeleteFile(temp);
        }

        bool alreadyManagedDefault = GetBool(betterfoxState, "defaultChanged");
        bool defaultProfileReviewed = GetBool(betterfoxState, "defaultProfileReviewed");
        string currentDefault = GetFirefoxDefaultProfilePath(firefoxRoot);
        bool alreadyDefault = String.Equals(
            (currentDefault ?? "").Replace('\\', '/'),
            relativePath.Replace('\\', '/'),
            StringComparison.OrdinalIgnoreCase);

        if (!alreadyDefault && !alreadyManagedDefault && !defaultProfileReviewed)
        {
            WriteTitle("Firefox Betterfox default-profile review");
            Console.WriteLine("Betterfox is installed only in a dedicated WGDot Firefox profile:");
            Console.WriteLine("  " + relativePath);
            Console.WriteLine();
            Console.WriteLine("Existing Firefox profiles are preserved.");
            Console.WriteLine("Current default: " +
                (String.IsNullOrWhiteSpace(currentDefault) ? "(none detected)" : currentDefault));
            Console.WriteLine();
            if (ReadYesNo("Make the WGDot Betterfox profile the Firefox default? [y/N]", false))
            {
                if (IsProcessRunning("firefox"))
                    throw new Exception(
                        "Firefox is running. Close Firefox before WGDot changes the default Firefox profile.");

                betterfoxState["previousDefaultProfile"] = currentDefault ?? "";
                SetFirefoxDefaultProfile(firefoxRoot, relativePath, currentDefault);
                betterfoxState["defaultChanged"] = true;
                Console.WriteLine("WGDot Betterfox profile is now the Firefox default.");
            }
            else
            {
                Console.WriteLine("WGDot Betterfox profile created, but the Firefox default was not changed.");
            }
            betterfoxState["defaultProfileReviewed"] = true;
        }

        state["betterfox"] = betterfoxState;
        WriteJson(BrowserStatePath, state);
        Console.WriteLine("Betterfox user.js configured in the dedicated WGDot Firefox profile.");
    }

    static bool ReadYesNo(string prompt, bool defaultYes)
    {
        Console.Write(prompt + " ");
        string value = (Console.ReadLine() ?? "").Trim();
        if (String.IsNullOrWhiteSpace(value)) return defaultYes;
        return Regex.IsMatch(value, "^[Yy]$");
    }

    static void WriteTitle(string subtitle)
    {
        try
        {
            if (!Console.IsOutputRedirected) Console.Clear();
        }
        catch
        {
        }

        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine("WGDot");
        Console.ResetColor();

        if (!String.IsNullOrWhiteSpace(subtitle))
        {
            Console.ForegroundColor = ConsoleColor.DarkGray;
            Console.WriteLine(subtitle);
            Console.ResetColor();
        }

        Console.WriteLine();
    }

    static void Pause()
    {
        Console.WriteLine();
        Console.Write("Press any key to continue.");
        try
        {
            if (!Console.IsInputRedirected) Console.ReadKey(true);
        }
        catch
        {
        }
    }

    static void ValidateBranchName(string branch)
    {
        if (String.IsNullOrWhiteSpace(branch) ||
            !Regex.IsMatch(branch, "^[A-Za-z0-9._/-]+$") ||
            branch.Contains("..") ||
            branch.Contains("@{") ||
            branch.StartsWith("/") ||
            branch.EndsWith("/"))
            throw new Exception("Invalid remote branch name.");
    }

    static string GetOption(string[] args, string name)
    {
        for (int i = 0; i < args.Length; i++)
        {
            if (String.Equals(args[i], name, StringComparison.OrdinalIgnoreCase))
            {
                if (i + 1 >= args.Length) throw new Exception("Missing value for " + name + ".");
                return args[i + 1];
            }
        }
        return "";
    }

    static bool ExecutableExists(string name)
    {
        ProcResult where = Run("where.exe", Q(name), null);
        return where.ExitCode == 0;
    }

    static string FindWingetExe()
    {
        if (ExecutableExists("winget.exe"))
            return "winget.exe";

        string alias = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Microsoft",
            "WindowsApps",
            "winget.exe");
        return File.Exists(alias) ? alias : "";
    }

    static void RegisterCurrentUserAppInstaller()
    {
        ProcResult register = Run(
            "powershell.exe",
            "-NoProfile -Command " + Q(
                "$ErrorActionPreference='SilentlyContinue'; " +
                "Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"),
            null);

        // Registration is best-effort here. The subsequent winget probe is
        // authoritative and gives a concrete error if App Installer is absent.
        if (register.ExitCode != 0)
            System.Threading.Thread.Sleep(500);
    }

    static int EnsureWingetAvailable()
    {
        string winget = FindWingetExe();
        if (!String.IsNullOrWhiteSpace(winget))
            return 0;

        WriteTitle("WinGet requirement");
        Console.WriteLine("WinGet is not available. WGDot requires Windows Package Manager.");
        Console.WriteLine("Installing Microsoft's App Installer / WinGet bootstrap automatically...");
        Console.WriteLine();

        if (!IsAdministrator())
        {
            int code = RunElevatedSelfWithExitCode("ensure-winget");
            if (code != 0)
                throw new Exception(
                    "Automatic WinGet bootstrap failed with elevated WGDot exit code " +
                    code.ToString(CultureInfo.InvariantCulture) + ".");

            RegisterCurrentUserAppInstaller();
        }
        else
        {
            string script =
                "$ErrorActionPreference='Stop';" +
                "$ProgressPreference='SilentlyContinue';" +
                "Install-PackageProvider -Name NuGet -Force | Out-Null;" +
                "Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope AllUsers | Out-Null;" +
                "Import-Module Microsoft.WinGet.Client -Force;" +
                "Repair-WinGetPackageManager -Force -Latest;";

            ProcResult repair = RunInteractive(
                "powershell.exe",
                "-NoProfile -Command " + Q(script));

            if (repair.ExitCode != 0)
                throw new Exception(
                    "Microsoft WinGet bootstrap failed with exit " +
                    repair.ExitCode.ToString(CultureInfo.InvariantCulture) + ".");

            RegisterCurrentUserAppInstaller();
        }

        string windowsApps = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Microsoft",
            "WindowsApps");
        string currentPath = Environment.GetEnvironmentVariable("PATH") ?? "";
        if (currentPath.IndexOf(windowsApps, StringComparison.OrdinalIgnoreCase) < 0)
            Environment.SetEnvironmentVariable("PATH", currentPath + ";" + windowsApps);

        for (int i = 0; i < 40; i++)
        {
            winget = FindWingetExe();
            if (!String.IsNullOrWhiteSpace(winget))
            {
                ProcResult version = Run(winget, "--version", null);
                if (version.ExitCode == 0)
                {
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine(
                        "WinGet ready: " +
                        LastUsefulLine(version.StdOut + "\n" + version.StdErr));
                    Console.ResetColor();
                    return 0;
                }
            }
            System.Threading.Thread.Sleep(250);
        }

        throw new Exception(
            "Microsoft App Installer was repaired, but winget.exe is still unavailable for the current user.");
    }

    static void RequireExecutable(string name, string error)
    {
        if (!ExecutableExists(name)) throw new Exception(error);
    }

    static ProcResult Run(string fileName, string arguments, string workingDirectory)
    {
        return RunCaptured(fileName, arguments, workingDirectory, 0);
    }

    static ProcResult RunWithTimeout(
        string fileName,
        string arguments,
        string workingDirectory,
        int timeoutMs)
    {
        if (timeoutMs <= 0) throw new ArgumentOutOfRangeException("timeoutMs");
        return RunCaptured(fileName, arguments, workingDirectory, timeoutMs);
    }

    static ProcResult RunCaptured(
        string fileName,
        string arguments,
        string workingDirectory,
        int timeoutMs)
    {
        var psi = new ProcessStartInfo();
        psi.FileName = fileName;
        psi.Arguments = arguments;
        psi.UseShellExecute = false;
        psi.RedirectStandardOutput = true;
        psi.RedirectStandardError = true;
        psi.CreateNoWindow = true;
        if (!String.IsNullOrWhiteSpace(workingDirectory)) psi.WorkingDirectory = workingDirectory;

        var stdout = new StringBuilder();
        var stderr = new StringBuilder();
        object stdoutLock = new object();
        object stderrLock = new object();

        using (var p = new Process())
        {
            p.StartInfo = psi;
            p.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e)
            {
                if (e.Data == null) return;
                lock (stdoutLock) stdout.AppendLine(e.Data);
            };
            p.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e)
            {
                if (e.Data == null) return;
                lock (stderrLock) stderr.AppendLine(e.Data);
            };

            p.Start();
            p.BeginOutputReadLine();
            p.BeginErrorReadLine();

            bool exited = true;
            if (timeoutMs > 0)
                exited = p.WaitForExit(timeoutMs);
            else
                p.WaitForExit();

            if (!exited)
            {
                try { p.Kill(); } catch { }
                try { p.WaitForExit(5000); } catch { }

                string timedOutStdOut;
                string timedOutStdErr;
                lock (stdoutLock) timedOutStdOut = stdout.ToString();
                lock (stderrLock) timedOutStdErr = stderr.ToString();

                return new ProcResult
                {
                    ExitCode = -1,
                    StdOut = timedOutStdOut,
                    StdErr = timedOutStdErr,
                    TimedOut = true
                };
            }

            // Required by .NET Framework after asynchronous output reads so
            // the final OutputDataReceived/ErrorDataReceived events are flushed.
            p.WaitForExit();

            string capturedStdOut;
            string capturedStdErr;
            lock (stdoutLock) capturedStdOut = stdout.ToString();
            lock (stderrLock) capturedStdErr = stderr.ToString();

            return new ProcResult
            {
                ExitCode = p.ExitCode,
                StdOut = capturedStdOut,
                StdErr = capturedStdErr,
                TimedOut = false
            };
        }
    }

    static ProcResult RunInteractiveStagedRuntime(string fileName, string arguments)
    {
        var psi = new ProcessStartInfo();
        psi.FileName = fileName;
        psi.Arguments = arguments;
        psi.UseShellExecute = false;
        psi.RedirectStandardOutput = false;
        psi.RedirectStandardError = false;
        psi.CreateNoWindow = false;
        psi.EnvironmentVariables["WGDOT_SKIP_RUNTIME_REFRESH"] = "1";

        using (Process p = Process.Start(psi))
        {
            p.WaitForExit();
            return new ProcResult { ExitCode = p.ExitCode, StdOut = "", StdErr = "" };
        }
    }

    static ProcResult RunInteractiveWithTimeout(
        string fileName,
        string arguments,
        int timeoutMs)
    {
        if (timeoutMs <= 0) throw new ArgumentOutOfRangeException("timeoutMs");

        var psi = new ProcessStartInfo();
        psi.FileName = fileName;
        psi.Arguments = arguments;
        psi.UseShellExecute = false;
        psi.RedirectStandardOutput = false;
        psi.RedirectStandardError = false;
        psi.CreateNoWindow = false;

        using (Process p = Process.Start(psi))
        {
            if (p.WaitForExit(timeoutMs))
            {
                return new ProcResult
                {
                    ExitCode = p.ExitCode,
                    StdOut = "",
                    StdErr = "",
                    TimedOut = false
                };
            }

            try
            {
                ProcResult taskkill = Run(
                    "taskkill.exe",
                    "/PID " + p.Id.ToString(CultureInfo.InvariantCulture) + " /T /F",
                    null);
                if (taskkill.ExitCode != 0 && !p.HasExited)
                    p.Kill();
            }
            catch
            {
                try { if (!p.HasExited) p.Kill(); } catch { }
            }

            try { p.WaitForExit(5000); } catch { }

            return new ProcResult
            {
                ExitCode = -1,
                StdOut = "",
                StdErr = "",
                TimedOut = true
            };
        }
    }

    static ProcResult RunInteractiveInDirectory(
        string fileName,
        string arguments,
        string workingDirectory)
    {
        var psi = new ProcessStartInfo();
        psi.FileName = fileName;
        psi.Arguments = arguments;
        psi.WorkingDirectory = workingDirectory;
        psi.UseShellExecute = false;
        psi.RedirectStandardOutput = false;
        psi.RedirectStandardError = false;
        psi.CreateNoWindow = false;

        using (Process p = Process.Start(psi))
        {
            p.WaitForExit();
            return new ProcResult { ExitCode = p.ExitCode, StdOut = "", StdErr = "" };
        }
    }

    static ProcResult RunInteractive(string fileName, string arguments)
    {
        var psi = new ProcessStartInfo();
        psi.FileName = fileName;
        psi.Arguments = arguments;
        psi.UseShellExecute = false;
        psi.RedirectStandardOutput = false;
        psi.RedirectStandardError = false;
        psi.CreateNoWindow = false;

        using (Process p = Process.Start(psi))
        {
            p.WaitForExit();
            return new ProcResult { ExitCode = p.ExitCode, StdOut = "", StdErr = "" };
        }
    }

    static string LastUsefulLine(string value)
    {
        if (String.IsNullOrWhiteSpace(value)) return "unknown error";
        string[] lines = value.Replace("\r", "").Split('\n');
        for (int i = lines.Length - 1; i >= 0; i--)
            if (!String.IsNullOrWhiteSpace(lines[i])) return lines[i].Trim();
        return "unknown error";
    }

    static string Q(string value)
    {
        return "\"" + (value ?? "").Replace("\"", "\\\"") + "\"";
    }

    static int SelfTest()
    {
        string temp = Path.Combine(Path.GetTempPath(), "wgdot-native-test-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(temp);

        try
        {
            string file = Path.Combine(temp, "x.txt");
            File.WriteAllText(file, "wgdot", Encoding.UTF8);
            string hash = Sha256OrNull(file);
            if (String.IsNullOrWhiteSpace(hash) || hash.Length != 64)
                throw new Exception("SHA-256 self-test failed.");

            string expanded = Environment.ExpandEnvironmentVariables("%LOCALAPPDATA%\\wgdot");
            if (String.IsNullOrWhiteSpace(expanded) || expanded.IndexOf("wgdot", StringComparison.OrdinalIgnoreCase) < 0)
                throw new Exception("Environment expansion self-test failed.");


            string runtimeCopySource = Path.Combine(temp, "runtime-copy-source.bin");
            string runtimeCopyDestination = Path.Combine(temp, "runtime-copy-destination.bin");
            File.WriteAllText(runtimeCopySource, "new-runtime", Encoding.ASCII);
            File.WriteAllText(runtimeCopyDestination, "old-runtime", Encoding.ASCII);
            CopyRuntimeWithRetry(runtimeCopySource, runtimeCopyDestination);
            if (!String.Equals(
                    File.ReadAllText(runtimeCopyDestination, Encoding.ASCII),
                    "new-runtime",
                    StringComparison.Ordinal))
                throw new Exception("Runtime replacement helper self-test failed.");

            if (!String.Equals(ClassifyGpuHardwareVendor(@"PCI\VEN_1002&DEV_0000"), "amd", StringComparison.Ordinal) ||
                !String.Equals(ClassifyGpuHardwareVendor(@"PCI\VEN_10DE&DEV_0000"), "nvidia", StringComparison.Ordinal) ||
                !String.Equals(ClassifyGpuHardwareVendor(@"PCI\VEN_8086&DEV_0000"), "intel", StringComparison.Ordinal))
                throw new Exception("GPU PCI vendor classification self-test failed.");

            if (!String.Equals(ClassifyGpuDriverProvider("Advanced Micro Devices, Inc."), "amd", StringComparison.Ordinal) ||
                !String.Equals(ClassifyGpuDriverProvider("NVIDIA"), "nvidia", StringComparison.Ordinal) ||
                !String.Equals(ClassifyGpuDriverProvider("Intel Corporation"), "intel", StringComparison.Ordinal))
                throw new Exception("GPU driver-provider classification self-test failed.");

            ProcResult timeoutProbe = RunWithTimeout(
                "cmd.exe",
                "/d /c ping -n 3 127.0.0.1 >nul",
                null,
                100);
            if (!timeoutProbe.TimedOut)
                throw new Exception("Process timeout self-test failed.");

            var timeoutPackage = new Dictionary<string, object>();
            timeoutPackage["wingetInstallTimeoutSeconds"] = 45;
            if (GetWingetInstallTimeoutMs(timeoutPackage) != 45000)
                throw new Exception("WinGet install timeout manifest self-test failed.");

            if (!TweakRunsInElevatedBatch("clean-taskbar-items") ||
                !TweakRunsInElevatedBatch("disable-snap-assist") ||
                TweakRunsInElevatedBatch("flow-launcher-alt-p"))
                throw new Exception("Elevated tweak batching self-test failed.");

            if (!IsContinueInstallationConfirmationKey(ConsoleKey.UpArrow) ||
                !IsContinueInstallationConfirmationKey(ConsoleKey.DownArrow) ||
                !IsContinueInstallationConfirmationKey(ConsoleKey.N) ||
                IsContinueInstallationConfirmationKey(ConsoleKey.Y))
                throw new Exception("Installation quit confirmation self-test failed.");

            string discardRegistrySelfTestPath =
                @"Software\WGDot\SelfTest\" + Guid.NewGuid().ToString("N");
            CaptureRegistryOriginal(
                "selftest-discard",
                "HKCU",
                discardRegistrySelfTestPath,
                "DiscardMe");
            DiscardRegistryOriginalSnapshot(
                "selftest-discard",
                "HKCU",
                discardRegistrySelfTestPath,
                "DiscardMe");
            Dictionary<string, object> discardState = ReadJson(TweakStatePath);
            if (GetList(discardState, "registryOriginals").Any(raw =>
                String.Equals(
                    GetString(AsDictionary(raw), "tweakId"),
                    "selftest-discard",
                    StringComparison.OrdinalIgnoreCase)))
                throw new Exception("Registry snapshot discard self-test failed.");

            Console.WriteLine("WGDot native runtime self-test passed.");
            return 0;
        }
        finally
        {
            SafeDeleteDirectory(temp);
        }
    }

    static void AddUserPath(string path)
    {
        using (RegistryKey key = Registry.CurrentUser.CreateSubKey("Environment"))
        {
            if (key == null) throw new Exception("Could not open HKCU\\Environment.");

            string current = Convert.ToString(key.GetValue("Path", "", RegistryValueOptions.DoNotExpandEnvironmentNames));
            string[] parts = (current ?? "").Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
            bool present = parts.Any(p => String.Equals(p.Trim().TrimEnd('\\'), path.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase));

            if (!present)
            {
                string next = String.IsNullOrWhiteSpace(current) ? path : current.TrimEnd(';') + ";" + path;
                key.SetValue("Path", next, RegistryValueKind.ExpandString);
            }
        }

        BroadcastEnvironmentChange();
    }

    static void BroadcastEnvironmentChange()
    {
        UIntPtr result;
        SendMessageTimeout(
            HwndBroadcast,
            WmSettingChange,
            UIntPtr.Zero,
            "Environment",
            SmtoAbortIfHung,
            5000,
            out result);
    }

    static string FindRepoRoot(string start)
    {
        DirectoryInfo d = new DirectoryInfo(start);
        for (int i = 0; i < 5 && d != null; i++, d = d.Parent)
        {
            if (File.Exists(Path.Combine(d.FullName, "wgdot", "manifest.json"))) return d.FullName;
        }
        return "";
    }

    static Dictionary<string, object> ReadJson(string path)
    {
        if (!File.Exists(path)) return null;
        string raw = File.ReadAllText(path);
        if (String.IsNullOrWhiteSpace(raw)) return null;
        return AsDictionary(Json.DeserializeObject(raw));
    }

    static void WriteTextAtomic(string path, string value)
    {
        string parent = Path.GetDirectoryName(path);
        if (String.IsNullOrWhiteSpace(parent))
            throw new Exception("Text destination has no parent: " + path);

        Directory.CreateDirectory(parent);
        string tmp = path + ".tmp-" + Guid.NewGuid().ToString("N");
        try
        {
            File.WriteAllText(tmp, value, new UTF8Encoding(false));
            if (File.Exists(path))
            {
                try
                {
                    File.Replace(tmp, path, null);
                    return;
                }
                catch
                {
                    File.Copy(tmp, path, true);
                    SafeDeleteFile(tmp);
                    return;
                }
            }

            File.Move(tmp, path);
        }
        finally
        {
            SafeDeleteFile(tmp);
        }
    }

    static void WriteJson(string path, object value)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        string tmp = path + ".tmp";
        File.WriteAllText(tmp, Json.Serialize(value), new UTF8Encoding(false));

        if (File.Exists(path))
        {
            try
            {
                File.Replace(tmp, path, null);
                return;
            }
            catch
            {
                SafeDeleteFile(path);
            }
        }

        File.Move(tmp, path);
    }

    static Dictionary<string, object> AsDictionary(object value)
    {
        var d = value as Dictionary<string, object>;
        return d ?? new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
    }

    static Dictionary<string, object> GetDictionary(Dictionary<string, object> dictionary, string key)
    {
        object value;
        if (!dictionary.TryGetValue(key, out value) || value == null)
            return new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        return AsDictionary(value);
    }

    static List<object> GetList(Dictionary<string, object> dictionary, string key)
    {
        object value;
        if (!dictionary.TryGetValue(key, out value) || value == null)
            return new List<object>();

        var enumerable = value as IEnumerable;
        if (enumerable == null || value is string)
            return new List<object>();

        var result = new List<object>();
        foreach (object item in enumerable) result.Add(item);
        return result;
    }

    static List<string> GetStringList(Dictionary<string, object> dictionary, string key)
    {
        return GetList(dictionary, key)
            .Where(x => x != null)
            .Select(Convert.ToString)
            .Where(x => !String.IsNullOrWhiteSpace(x))
            .ToList();
    }

    static string GetString(Dictionary<string, object> dictionary, string key)
    {
        object value;
        return dictionary.TryGetValue(key, out value) && value != null ? Convert.ToString(value) : "";
    }

    static int GetInt(Dictionary<string, object> dictionary, string key)
    {
        object value;
        if (!dictionary.TryGetValue(key, out value) || value == null) return 0;
        return Convert.ToInt32(value);
    }

    static bool GetBool(Dictionary<string, object> dictionary, string key)
    {
        object value;
        if (!dictionary.TryGetValue(key, out value) || value == null) return false;
        return Convert.ToBoolean(value);
    }

    static string Sha256OrNull(string path)
    {
        if (!File.Exists(path)) return null;

        using (var sha = SHA256.Create())
        using (var stream = File.OpenRead(path))
        {
            byte[] bytes = sha.ComputeHash(stream);
            var sb = new StringBuilder(bytes.Length * 2);
            foreach (byte b in bytes) sb.Append(b.ToString("x2"));
            return sb.ToString();
        }
    }

    static void SafeDeleteFile(string path)
    {
        try
        {
            if (!String.IsNullOrWhiteSpace(path) && File.Exists(path))
                File.Delete(path);
        }
        catch
        {
        }
    }

    static void SafeDeleteDirectory(string path)
    {
        try
        {
            if (!String.IsNullOrWhiteSpace(path) && Directory.Exists(path))
                Directory.Delete(path, true);
        }
        catch
        {
        }
    }
}
