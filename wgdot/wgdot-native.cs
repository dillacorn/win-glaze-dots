using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;
using Microsoft.Win32;

internal static class WgdotNative
{
    const string Version = "native-bootstrap-preview-5";
    const string RepoUrl = "https://github.com/dillacorn/win-glaze-dots.git";

    static readonly string InstallRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "wgdot");
    static readonly string BinRoot = Path.Combine(InstallRoot, "bin");
    static readonly string StateRoot = Path.Combine(InstallRoot, "state");
    static readonly string CacheRoot = Path.Combine(InstallRoot, "cache");
    static readonly string BaselineRoot = Path.Combine(StateRoot, "baseline");
    static readonly string InstallStatePath = Path.Combine(StateRoot, "installation.json");
    static readonly string BootstrapStatePath = Path.Combine(StateRoot, "native-bootstrap.json");
    static readonly string BaselineIndexPath = Path.Combine(BaselineRoot, "index.json");
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

    sealed class ChoiceItem
    {
        public string Id;
        public string Label;
        public bool Selected;
    }

    sealed class InstallationSelection
    {
        public string Scope;
        public string GlazeProfile;
        public List<string> Components = new List<string>();
        public List<string> Packages = new List<string>();
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
    }

    static int Main(string[] args)
    {
        try
        {
            string command = args.Length == 0 ? "menu" : args[0].ToLowerInvariant();

            if (command == "install") return Install();
            if (command == "status") return Status();
            if (command == "menu") return Menu();
            if (command == "self-test") return SelfTest();
            if (command == "git-review") return GitReviewFromArgs(args.Skip(1).ToArray());

            Console.Error.WriteLine("Unknown WGDot native command: " + command);
            Console.Error.WriteLine("Run wgdot with no arguments for the menu.");
            return 2;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("WGDot native error: " + ex.Message);
            return 1;
        }
    }

    static int Install()
    {
        Directory.CreateDirectory(BinRoot);
        Directory.CreateDirectory(StateRoot);
        Directory.CreateDirectory(CacheRoot);
        Directory.CreateDirectory(BaselineRoot);

        string currentExe = Process.GetCurrentProcess().MainModule.FileName;
        string targetExe = Path.Combine(BinRoot, "wgdot.exe");
        string sourceRoot = Environment.GetEnvironmentVariable("WGDOT_SOURCE_ROOT");
        if (String.IsNullOrWhiteSpace(sourceRoot)) sourceRoot = FindRepoRoot(AppDomain.CurrentDomain.BaseDirectory);
        if (!String.IsNullOrWhiteSpace(sourceRoot)) sourceRoot = Path.GetFullPath(sourceRoot);
        string sourceRef = Environment.GetEnvironmentVariable("WGDOT_SOURCE_REF") ?? "";
        string sourceRevision = Environment.GetEnvironmentVariable("WGDOT_SOURCE_REVISION") ?? "";

        if (!String.Equals(Path.GetFullPath(currentExe), Path.GetFullPath(targetExe), StringComparison.OrdinalIgnoreCase))
            File.Copy(currentExe, targetExe, true);

        string cmd = "@echo off\r\n\"%~dp0wgdot.exe\" %*\r\n";
        File.WriteAllText(Path.Combine(BinRoot, "wgdot.cmd"), cmd, Encoding.ASCII);
        AddUserPath(BinRoot);

        var state = new Dictionary<string, object>();
        state["version"] = Version;
        state["installedAt"] = DateTime.UtcNow.ToString("o");
        state["sourceRoot"] = sourceRoot;
        state["sourceRef"] = sourceRef;
        state["sourceRevision"] = sourceRevision;
        state["executionPolicyIndependent"] = true;
        WriteJson(BootstrapStatePath, state);

        Console.WriteLine("WGDot native bootstrap installed to:");
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
            if (!String.IsNullOrWhiteSpace(sourceRoot)) Console.WriteLine("Source root: " + sourceRoot);
            if (!String.IsNullOrWhiteSpace(sourceRef)) Console.WriteLine("Source ref: " + sourceRef);
            if (!String.IsNullOrWhiteSpace(sourceRevision)) Console.WriteLine("Source revision: " + sourceRevision);
            Console.WriteLine("Installed: " + GetString(state, "installedAt"));
        }
        else
        {
            Console.WriteLine("Install state: not installed through native bootstrap");
        }

        Console.WriteLine("Managed selection: " + (File.Exists(InstallStatePath) ? "configured" : "not configured"));
        Console.WriteLine("Baseline: " + (File.Exists(BaselineIndexPath) ? "present" : "not initialized"));
        return 0;
    }

    static int Menu()
    {
        var items = new List<string>
        {
            "Update managed dots [not yet ported]",
            "Install / reconcile software [not yet ported]",
            "Reset / reconfigure managed dots [not yet ported]",
            "Review changes without applying [stable path not yet ported]",
            "Backup manager [not yet ported]",
            "Manual PowerShell commands [not yet ported]",
            "Version / status",
            "Advanced / Git testing",
            "Exit"
        };

        while (true)
        {
            int choice = ReadSingleChoice("Maintenance", items, 0);
            if (choice < 0 || choice == 8) return 0;

            if (choice == 6)
            {
                WriteTitle("Version / status");
                Status();
                Pause();
            }
            else if (choice == 7)
            {
                ShowGitMenu();
            }
            else
            {
                WriteTitle("Native port in progress");
                Console.WriteLine("This operation has not been ported to the native runtime yet.");
                Console.WriteLine("No changes were made.");
                Pause();
            }
        }
    }

    static void ShowGitMenu()
    {
        var items = new List<string>
        {
            "Review branch / commit without applying",
            "Back"
        };

        while (true)
        {
            int choice = ReadSingleChoice("Advanced / Git testing", items, 0);
            if (choice < 0 || choice == 1) return;

            try
            {
                List<string> branches = GetRemoteBranches();
                if (branches.Count == 0)
                    throw new Exception("No remote branches were found.");

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

                string revision = "";
                if (revisionMode == 1)
                {
                    WriteTitle("Exact Git-testing revision");
                    Console.Write("Exact 40-character commit: ");
                    revision = (Console.ReadLine() ?? "").Trim();
                    if (String.IsNullOrWhiteSpace(revision)) continue;
                }

                GitReview(branch, revision);
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

    static int GitReviewFromArgs(string[] args)
    {
        string branch = GetOption(args, "--branch");
        string revision = GetOption(args, "--revision");

        if (String.IsNullOrWhiteSpace(branch))
            throw new Exception("git-review requires --branch <remote-branch>.");

        GitReview(branch, revision);
        return 0;
    }

    static void GitReview(string branch, string requestedRevision)
    {
        WriteTitle("Git testing / Review");

        string revision = ResolveGitRevision(branch, requestedRevision);
        string sourceRoot = PrepareGitSource(revision);
        var manifest = ReadManifest(sourceRoot);

        Console.WriteLine("Branch:   " + branch);
        Console.WriteLine("Revision: " + revision);
        Console.WriteLine();

        InstallationSelection installation = ReadInstallationSelection();
        if (installation == null)
            installation = NewInstallationSelection(manifest);

        if (installation == null)
        {
            Console.WriteLine("Review cancelled.");
            return;
        }

        bool hasBaseline = File.Exists(BaselineIndexPath);
        string effectiveMode = hasBaseline ? "update" : "reset";
        var plan = GetPlan(manifest, sourceRoot, installation, effectiveMode);

        ShowPlan(plan);
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.DarkGray;
        Console.WriteLine("Review only. No files, backups, baselines, or selection state were changed.");
        if (!hasBaseline)
            Console.WriteLine("No baseline exists yet, so this first-install review uses reset semantics.");
        Console.ResetColor();
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

    static InstallationSelection ReadInstallationSelection()
    {
        var state = ReadJson(InstallStatePath);
        if (state == null) return null;

        var result = new InstallationSelection();
        result.Scope = GetString(state, "scope");
        result.GlazeProfile = GetString(state, "glazewmProfile");
        result.Components = GetStringList(state, "components");
        result.Packages = GetStringList(state, "packages");

        if (String.IsNullOrWhiteSpace(result.Scope) ||
            String.IsNullOrWhiteSpace(result.GlazeProfile) ||
            result.Components.Count == 0)
            return null;

        return result;
    }

    static InstallationSelection NewInstallationSelection(Dictionary<string, object> manifest)
    {
        int scopeIndex = ReadSingleChoice(
            "Choose installation profile",
            new List<string> { "Normal / personal PC", "Work PC" },
            0);
        if (scopeIndex < 0) return null;

        string scope = scopeIndex == 1 ? "work" : "normal";

        int glazeIndex = ReadSingleChoice(
            "Which GlazeWM config created by dillacorn do you want to use?",
            new List<string> { "Normal", "Work" },
            scope == "work" ? 1 : 0);
        if (glazeIndex < 0) return null;

        string glazeProfile = glazeIndex == 1 ? "work" : "normal";

        var componentChoices = new List<ChoiceItem>();
        foreach (object raw in GetList(manifest, "components"))
        {
            var component = AsDictionary(raw);
            componentChoices.Add(new ChoiceItem
            {
                Id = GetString(component, "id"),
                Label = GetString(component, "name"),
                Selected = scope == "work" ? GetBool(component, "defaultWork") : GetBool(component, "defaultNormal")
            });
        }

        componentChoices = ReadMultiChoice("Managed components", componentChoices);
        if (componentChoices == null) return null;

        var result = new InstallationSelection();
        result.Scope = scope;
        result.GlazeProfile = glazeProfile;
        result.Components = componentChoices.Where(x => x.Selected).Select(x => x.Id).ToList();

        foreach (object raw in GetList(manifest, "packages"))
        {
            var package = AsDictionary(raw);
            bool selected = scope == "work" ? GetBool(package, "defaultWork") : GetBool(package, "defaultNormal");
            if (selected) result.Packages.Add(GetString(package, "id"));
        }

        return result;
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

        if (plan.Count == 0)
            Console.WriteLine("(no managed files selected)");
    }

    static int ReadSingleChoice(string title, List<string> items, int initialIndex)
    {
        if (items == null || items.Count == 0) return -1;
        int index = initialIndex >= 0 && initialIndex < items.Count ? initialIndex : 0;

        while (true)
        {
            WriteTitle(title);

            for (int i = 0; i < items.Count; i++)
            {
                if (i == index) Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine((i == index ? "> " : "  ") + items[i]);
                Console.ResetColor();
            }

            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.DarkGray;
            Console.WriteLine("Up/Down: move   Enter: select   Esc: cancel");
            Console.ResetColor();

            ConsoleKey key = Console.ReadKey(true).Key;
            if (key == ConsoleKey.UpArrow) index = (index - 1 + items.Count) % items.Count;
            else if (key == ConsoleKey.DownArrow) index = (index + 1) % items.Count;
            else if (key == ConsoleKey.Enter) return index;
            else if (key == ConsoleKey.Escape) return -1;
        }
    }

    static List<ChoiceItem> ReadMultiChoice(string title, List<ChoiceItem> items)
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
                Console.WriteLine((i == index ? "> " : "  ") + mark + " " + items[i].Label);
                Console.ResetColor();
            }

            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.DarkGray;
            Console.WriteLine("Up/Down: move   Space: toggle   Enter: accept   Esc: cancel");
            Console.ResetColor();

            ConsoleKey key = Console.ReadKey(true).Key;
            if (key == ConsoleKey.UpArrow) index = (index - 1 + items.Count) % items.Count;
            else if (key == ConsoleKey.DownArrow) index = (index + 1) % items.Count;
            else if (key == ConsoleKey.Spacebar) items[index].Selected = !items[index].Selected;
            else if (key == ConsoleKey.Enter) return items;
            else if (key == ConsoleKey.Escape) return null;
        }
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
        Console.ReadKey(true);
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

    static void RequireExecutable(string name, string error)
    {
        ProcResult where = Run("where.exe", Q(name), null);
        if (where.ExitCode != 0) throw new Exception(error);
    }

    static ProcResult Run(string fileName, string arguments, string workingDirectory)
    {
        var psi = new ProcessStartInfo();
        psi.FileName = fileName;
        psi.Arguments = arguments;
        psi.UseShellExecute = false;
        psi.RedirectStandardOutput = true;
        psi.RedirectStandardError = true;
        psi.CreateNoWindow = true;
        if (!String.IsNullOrWhiteSpace(workingDirectory)) psi.WorkingDirectory = workingDirectory;

        using (Process p = Process.Start(psi))
        {
            string stdout = p.StandardOutput.ReadToEnd();
            string stderr = p.StandardError.ReadToEnd();
            p.WaitForExit();
            return new ProcResult { ExitCode = p.ExitCode, StdOut = stdout, StdErr = stderr };
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

            Console.WriteLine("WGDot native bootstrap self-test passed.");
            return 0;
        }
        finally
        {
            try { Directory.Delete(temp, true); } catch { }
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

    static void WriteJson(string path, object value)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        string tmp = path + ".tmp";
        File.WriteAllText(tmp, Json.Serialize(value), new UTF8Encoding(false));
        if (File.Exists(path)) File.Delete(path);
        File.Move(tmp, path);
    }

    static Dictionary<string, object> AsDictionary(object value)
    {
        var d = value as Dictionary<string, object>;
        return d ?? new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
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
}
