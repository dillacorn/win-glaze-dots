using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;
using System.Xml;
using Microsoft.Win32;

internal static class WgdotNative
{
    const string Version = "native-preview-9";
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

    sealed class SourceContext
    {
        public string Mode;
        public string Tag;
        public string Revision;
        public string Branch;
        public string SourceRoot;
        public Dictionary<string, object> Manifest;
    }

    static int Main(string[] args)
    {
        try
        {
            ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
            EnsureStateDirectories();
            string command = args.Length == 0 ? "menu" : args[0].ToLowerInvariant();

            if (command == "install") return Install();
            if (command == "status") return Status();
            if (command == "menu") return Menu();
            if (command == "self-test") return SelfTest();
            if (command == "git-review") return GitReviewFromArgs(args.Skip(1).ToArray());
            if (command == "maintenance-self-test") return MaintenanceSelfTest();
            if (command == "software") return SoftwareReconcile();
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
    }

    static void EnsureStateDirectories()
    {
        Directory.CreateDirectory(InstallRoot);
        Directory.CreateDirectory(BinRoot);
        Directory.CreateDirectory(StateRoot);
        Directory.CreateDirectory(CacheRoot);
        Directory.CreateDirectory(BaselineRoot);
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
        return 0;
    }

    static int Menu()
    {
        try
        {
            if (TryRefreshRuntimeAndRun())
                return 0;
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("WGDot runtime refresh check failed; continuing installed runtime.");
            Console.WriteLine(ex.Message);
            Console.ResetColor();
            Console.WriteLine();
        }

        var items = new List<string>
        {
            "Update managed dots",
            "Install / reconcile software",
            "Reset / reconfigure managed dots",
            "Review changes without applying",
            "Backup manager",
            "Manual PowerShell fallback",
            "Version / status",
            "Advanced / Git testing",
            "Exit"
        };

        while (true)
        {
            int choice = ReadSingleChoice("Maintenance", items, 0);
            if (choice < 0 || choice == 8) return 0;

            try
            {
                if (choice == 0)
                {
                    ManagedOperation("update", ResolveDefaultSource());
                    Pause();
                }
                else if (choice == 1)
                {
                    SoftwareReconcile();
                    Pause();
                }
                else if (choice == 2)
                {
                    ManagedOperation("reset", ResolveDefaultSource());
                    Pause();
                }
                else if (choice == 3)
                {
                    ManagedOperation("review", ResolveDefaultSource());
                    Pause();
                }
                else if (choice == 4)
                {
                    BackupManager();
                }
                else if (choice == 5)
                {
                    ShowManualFallback();
                    Pause();
                }
                else if (choice == 6)
                {
                    WriteTitle("Version / status");
                    Status();
                    Pause();
                }
                else if (choice == 7)
                {
                    ShowGitMenu();
                }
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

    static bool TryRefreshRuntimeAndRun()
    {
        var state = ReadJson(BootstrapStatePath);
        if (state == null) return false;

        string sourceRef = GetString(state, "sourceRef");
        if (String.IsNullOrWhiteSpace(sourceRef)) sourceRef = "main";
        ValidateBranchName(sourceRef);

        string installedRevision = GetString(state, "sourceRevision");
        string remoteRevision = ResolveBranchHeadViaApi(sourceRef);

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

        state["sourceRef"] = sourceRef;
        state["sourceRevision"] = remoteRevision;
        state["refreshedAt"] = DateTime.UtcNow.ToString("o");
        WriteJson(BootstrapStatePath, state);

        string installedExe = Path.Combine(BinRoot, "wgdot.exe");
        string helper = CreateRuntimeSwapHelper(nextExe, installedExe);

        var helperInfo = new ProcessStartInfo();
        helperInfo.FileName = "cmd.exe";
        helperInfo.Arguments = "/d /c " + Q(helper);
        helperInfo.UseShellExecute = false;
        helperInfo.CreateNoWindow = true;
        Process.Start(helperInfo);

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("Runtime refreshed. Starting the new WGDot runtime...");
        Console.ResetColor();
        Console.WriteLine();

        RunInteractive(nextExe, "menu");
        return true;
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

    static string GetCscPath()
    {
        string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        string x64 = Path.Combine(windows, "Microsoft.NET", "Framework64", "v4.0.30319", "csc.exe");
        if (File.Exists(x64)) return x64;

        string x86 = Path.Combine(windows, "Microsoft.NET", "Framework", "v4.0.30319", "csc.exe");
        return File.Exists(x86) ? x86 : "";
    }

    static string CreateRuntimeSwapHelper(string sourceExe, string destinationExe)
    {
        string helper = Path.Combine(Path.GetTempPath(), "wgdot-swap-" + Guid.NewGuid().ToString("N") + ".cmd");
        var lines = new List<string>();
        lines.Add("@echo off");
        lines.Add("setlocal EnableExtensions");
        lines.Add("set \"SRC=" + sourceExe + "\"");
        lines.Add("set \"DST=" + destinationExe + "\"");
        lines.Add("set /a TRIES=0");
        lines.Add(":retry");
        lines.Add("set /a TRIES+=1");
        lines.Add("copy /Y \"%SRC%\" \"%DST%\" >nul 2>&1");
        lines.Add("if not errorlevel 1 goto done");
        lines.Add("if %TRIES% GEQ 30 goto failed");
        lines.Add("ping 127.0.0.1 -n 2 >nul");
        lines.Add("goto retry");
        lines.Add(":done");
        lines.Add("del /q \"%SRC%\" >nul 2>&1");
        lines.Add("del /q \"%~f0\" >nul 2>&1");
        lines.Add("exit /b 0");
        lines.Add(":failed");
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

    static int GitReviewFromArgs(string[] args)
    {
        string branch = GetOption(args, "--branch");
        string revision = GetOption(args, "--revision");

        if (String.IsNullOrWhiteSpace(branch))
            throw new Exception("git-review requires --branch <remote-branch>.");

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
        return ManagedOperation("review", context);
    }

    static SourceContext ResolveDefaultSource()
    {
        var bootstrap = ReadJson(BootstrapStatePath);
        if (bootstrap != null)
        {
            string sourceRef = GetString(bootstrap, "sourceRef");
            if (!String.IsNullOrWhiteSpace(sourceRef) &&
                !String.Equals(sourceRef, "main", StringComparison.OrdinalIgnoreCase))
            {
                string revision = ResolveBranchHeadViaApi(sourceRef);
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
            string raw = client.DownloadString(url);
            return AsDictionary(Json.DeserializeObject(raw));
        }
    }

    static string PrepareRevisionArchive(string revision)
    {
        if (!Regex.IsMatch(revision ?? "", "^[0-9a-fA-F]{40}$"))
            throw new Exception("Source revision must be a full 40-character SHA.");

        revision = revision.ToLowerInvariant();
        string revisionRoot = Path.Combine(CacheRoot, "revision-" + revision);
        string marker = Path.Combine(revisionRoot, ".wgdot-source");

        if (File.Exists(marker))
        {
            string cached = File.ReadAllText(marker).Trim();
            if (Directory.Exists(cached) && File.Exists(Path.Combine(cached, "wgdot", "manifest.json")))
                return cached;
        }

        string zipPath = Path.Combine(CacheRoot, revision + ".zip");
        string extractRoot = Path.Combine(CacheRoot, "extract-" + revision);

        SafeDeleteFile(zipPath);
        SafeDeleteDirectory(extractRoot);
        SafeDeleteDirectory(revisionRoot);
        Directory.CreateDirectory(extractRoot);

        string url = "https://github.com/" + RepoFullName + "/archive/" + revision + ".zip";
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
            File.WriteAllText(mergeTarget, "upstream\r\nbase\r\nthree\r\n", new UTF8Encoding(false));
            File.WriteAllText(mergeLive, "one\r\nlocal\r\nthree\r\n", new UTF8Encoding(false));
            string mergeBaseline = GetBaselinePath("selftest-merge");
            File.WriteAllText(mergeBaseline, "one\r\nbase\r\nthree\r\n", new UTF8Encoding(false));

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
            if (merged.IndexOf("upstream", StringComparison.Ordinal) < 0 ||
                merged.IndexOf("local", StringComparison.Ordinal) < 0)
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

            Console.WriteLine("WGDot native maintenance self-test passed.");
            return 0;
        }
        finally
        {
            SafeDeleteDirectory(root);
            SafeDeleteDirectory(InstallRoot);
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
        Console.WriteLine();
        Console.WriteLine("Only missing packages will be installed.");
        Console.WriteLine("Exact WinGet IDs are validated before install.");
        Console.WriteLine("No global upgrade command is used.");
        Console.WriteLine();

        if (!ReadYesNo("Install/reconcile this software selection? [y/N]", false))
        {
            Console.WriteLine("No software changes were made.");
            return 0;
        }

        WriteInstallationSelection(selection);
        RequireExecutable("winget.exe", "WinGet was not found.");

        var wanted = new HashSet<string>(selection.Packages, StringComparer.OrdinalIgnoreCase);
        int installed = 0;
        int already = 0;
        int unavailable = 0;
        int failed = 0;

        foreach (object rawPackage in GetList(manifest, "packages"))
        {
            var package = AsDictionary(rawPackage);
            string id = GetString(package, "id");
            if (!wanted.Contains(id)) continue;

            Console.WriteLine();
            Console.WriteLine("Checking " + id + "...");

            ProcResult show = Run(
                "winget.exe",
                "show --id " + Q(id) + " --exact --source winget --accept-source-agreements",
                null);
            if (show.ExitCode != 0)
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("Unavailable by exact WinGet ID; skipped: " + id);
                Console.ResetColor();
                unavailable++;
                continue;
            }

            ProcResult list = Run(
                "winget.exe",
                "list --id " + Q(id) + " --exact --source winget --accept-source-agreements",
                null);

            bool isInstalled = (list.StdOut ?? "").IndexOf(id, StringComparison.OrdinalIgnoreCase) >= 0;
            if (isInstalled)
            {
                Console.WriteLine("Already installed.");
                already++;
                continue;
            }

            Console.WriteLine("Installing " + id + "...");
            ProcResult install = RunInteractive(
                "winget.exe",
                "install --id " + Q(id) + " --exact --source winget --accept-source-agreements --accept-package-agreements");

            if (install.ExitCode == 0)
            {
                installed++;
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("Install failed: " + id + " (exit " + install.ExitCode.ToString(CultureInfo.InvariantCulture) + ")");
                Console.ResetColor();
                failed++;
            }
        }

        Console.WriteLine();
        Console.WriteLine("Software reconciliation complete.");
        Console.WriteLine("Installed: " + installed.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Already installed: " + already.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Unavailable exact IDs: " + unavailable.ToString(CultureInfo.InvariantCulture));
        Console.WriteLine("Install failures: " + failed.ToString(CultureInfo.InvariantCulture));

        if (ReadYesNo("Check selected packages for upgrades now? [y/N]", false))
        {
            foreach (object rawPackage in GetList(manifest, "packages"))
            {
                var package = AsDictionary(rawPackage);
                string id = GetString(package, "id");
                if (!wanted.Contains(id)) continue;

                ProcResult upgradeCheck = Run(
                    "winget.exe",
                    "list --id " + Q(id) + " --exact --upgrade-available --source winget --accept-source-agreements",
                    null);

                bool upgradeAvailable = (upgradeCheck.StdOut ?? "").IndexOf(id, StringComparison.OrdinalIgnoreCase) >= 0;
                if (!upgradeAvailable) continue;

                if (!ReadYesNo("Upgrade " + id + "? [y/N]", false)) continue;

                ProcResult upgrade = RunInteractive(
                    "winget.exe",
                    "upgrade --id " + Q(id) + " --exact --source winget --accept-source-agreements --accept-package-agreements");

                if (upgrade.ExitCode != 0)
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("Upgrade failed: " + id + " (exit " + upgrade.ExitCode.ToString(CultureInfo.InvariantCulture) + ")");
                    Console.ResetColor();
                }
            }
        }

        return failed == 0 ? 0 : 1;
    }

    static InstallationSelection ConfigureInstallationSelection(
        Dictionary<string, object> manifest,
        InstallationSelection existing,
        bool includePackages)
    {
        int initialScope = existing != null && String.Equals(existing.Scope, "work", StringComparison.OrdinalIgnoreCase) ? 1 : 0;
        int scopeIndex = ReadSingleChoice(
            "Choose installation profile",
            new List<string> { "Normal / personal PC", "Work PC" },
            initialScope);
        if (scopeIndex < 0) return null;

        string scope = scopeIndex == 1 ? "work" : "normal";

        int initialGlaze = existing != null
            ? (String.Equals(existing.GlazeProfile, "work", StringComparison.OrdinalIgnoreCase) ? 1 : 0)
            : (scope == "work" ? 1 : 0);

        int glazeIndex = ReadSingleChoice(
            "Which GlazeWM config created by dillacorn do you want to use?",
            new List<string> { "Normal", "Work" },
            initialGlaze);
        if (glazeIndex < 0) return null;

        string glazeProfile = glazeIndex == 1 ? "work" : "normal";

        var componentChoices = BuildComponentChoices(manifest, scope, existing);
        componentChoices = ReadMultiChoice("Managed components", componentChoices);
        if (componentChoices == null) return null;

        var result = new InstallationSelection();
        result.Scope = scope;
        result.GlazeProfile = glazeProfile;
        result.Components = componentChoices.Where(x => x.Selected).Select(x => x.Id).ToList();

        if (includePackages)
        {
            var packageChoices = BuildPackageChoices(manifest, scope, existing);
            packageChoices = ReadMultiChoice("Software to install / reconcile", packageChoices);
            if (packageChoices == null) return null;
            result.Packages = packageChoices.Where(x => x.Selected).Select(x => x.Id).ToList();
        }
        else if (existing != null)
        {
            result.Packages = new List<string>(existing.Packages);
        }
        else
        {
            foreach (ChoiceItem item in BuildPackageChoices(manifest, scope, null))
                if (item.Selected) result.Packages.Add(item.Id);
        }

        return result;
    }

    static InstallationSelection ConfigureSoftwareSelection(
        Dictionary<string, object> manifest,
        InstallationSelection existing)
    {
        var result = new InstallationSelection();
        result.Scope = existing.Scope;
        result.GlazeProfile = existing.GlazeProfile;
        result.Components = new List<string>(existing.Components);

        var choices = BuildPackageChoices(manifest, existing.Scope, existing);
        choices = ReadMultiChoice("Software to install / reconcile", choices);
        if (choices == null) return null;

        result.Packages = choices.Where(x => x.Selected).Select(x => x.Id).ToList();
        return result;
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
                Label = name + " [" + category + "]",
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
        state["configuredAt"] = DateTime.UtcNow.ToString("o");
        WriteJson(InstallStatePath, state);
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

        ApplyPlan(plan, source.Manifest, selection, source);

        if (selectionChanged)
            WriteInstallationSelection(selection);

        UpdateSourceStateAfterApply(source);
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

        ShowMigrations(manifest, selection, false);
        RunPostActions(manifest, selection);
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

    static void RunPostActions(Dictionary<string, object> manifest, InstallationSelection selection)
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
            Console.WriteLine("Up/Down: move   PgUp/PgDn: page   Enter: select   Esc: cancel");
            Console.ResetColor();

            ConsoleKey key = Console.ReadKey(true).Key;
            if (key == ConsoleKey.UpArrow) index = (index - 1 + items.Count) % items.Count;
            else if (key == ConsoleKey.DownArrow) index = (index + 1) % items.Count;
            else if (key == ConsoleKey.PageUp) index = Math.Max(0, index - pageSize);
            else if (key == ConsoleKey.PageDown) index = Math.Min(items.Count - 1, index + pageSize);
            else if (key == ConsoleKey.Home) index = 0;
            else if (key == ConsoleKey.End) index = items.Count - 1;
            else if (key == ConsoleKey.Enter) return index;
            else if (key == ConsoleKey.Escape) return -1;
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
            Console.WriteLine("Enter: accept   Esc: cancel");
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
            else if (key == ConsoleKey.Escape) return null;
        }
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

    static void RequireExecutable(string name, string error)
    {
        if (!ExecutableExists(name)) throw new Exception(error);
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
