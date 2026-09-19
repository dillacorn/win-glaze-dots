using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Web.Script.Serialization;
using Microsoft.Win32;

internal static class WgdotNative
{
    const string Version = "native-bootstrap-preview-1";
    static readonly string InstallRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "wgdot");
    static readonly string BinRoot = Path.Combine(InstallRoot, "bin");
    static readonly string StateRoot = Path.Combine(InstallRoot, "state");
    static readonly string InstallStatePath = Path.Combine(StateRoot, "native-bootstrap.json");
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue, RecursionLimit = 100 };

    static int Main(string[] args)
    {
        try
        {
            string command = args.Length == 0 ? "menu" : args[0].ToLowerInvariant();
            if (command == "install") return Install();
            if (command == "status") return Status();
            if (command == "menu") return Menu();
            if (command == "self-test") return SelfTest();
            Console.Error.WriteLine("Unknown WGDot native command: " + command);
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

        string currentExe = Process.GetCurrentProcess().MainModule.FileName;
        string targetExe = Path.Combine(BinRoot, "wgdot.exe");
        string sourceRoot = FindRepoRoot(AppDomain.CurrentDomain.BaseDirectory);

        if (!String.Equals(Path.GetFullPath(currentExe), Path.GetFullPath(targetExe), StringComparison.OrdinalIgnoreCase))
            File.Copy(currentExe, targetExe, true);

        string cmd = "@echo off\r\n\"%~dp0wgdot.exe\" %*\r\n";
        File.WriteAllText(Path.Combine(BinRoot, "wgdot.cmd"), cmd, Encoding.ASCII);
        AddUserPath(BinRoot);

        var state = new Dictionary<string, object>();
        state["version"] = Version;
        state["installedAt"] = DateTime.UtcNow.ToString("o");
        state["sourceRoot"] = sourceRoot;
        state["executionPolicyIndependent"] = true;
        File.WriteAllText(InstallStatePath, Json.Serialize(state), new UTF8Encoding(false));

        Console.WriteLine("WGDot native bootstrap installed to:");
        Console.WriteLine("  " + BinRoot);
        Console.WriteLine();
        Console.WriteLine("It does not change or bypass PowerShell execution policy.");
        Console.WriteLine("Open a new terminal and run: wgdot status");
        return 0;
    }

    static int Status()
    {
        Console.WriteLine("WGDot native bootstrap");
        Console.WriteLine("Version: " + Version);
        Console.WriteLine("Install root: " + InstallRoot);
        Console.WriteLine("Executable: " + Process.GetCurrentProcess().MainModule.FileName);
        Console.WriteLine("PowerShell execution policy required: no");
        if (File.Exists(InstallStatePath))
        {
            var state = AsDictionary(Json.DeserializeObject(File.ReadAllText(InstallStatePath)));
            Console.WriteLine("Source root: " + GetString(state, "sourceRoot"));
            Console.WriteLine("Installed: " + GetString(state, "installedAt"));
        }
        else
        {
            Console.WriteLine("Install state: not installed through native bootstrap");
        }
        return 0;
    }

    static int Menu()
    {
        while (true)
        {
            Console.Clear();
            Console.WriteLine("WGDot");
            Console.WriteLine("Native bootstrap preview");
            Console.WriteLine();
            Console.WriteLine("1. Version / status");
            Console.WriteLine("2. Exit");
            Console.WriteLine();
            Console.Write("Choice: ");
            string choice = Console.ReadLine();
            if (choice == "1")
            {
                Console.Clear();
                Status();
                Console.WriteLine();
                Console.Write("Press Enter to return.");
                Console.ReadLine();
            }
            else if (choice == "2" || String.IsNullOrWhiteSpace(choice))
                return 0;
        }
    }

    static int SelfTest()
    {
        string temp = Path.Combine(Path.GetTempPath(), "wgdot-native-test-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(temp);
        try
        {
            string file = Path.Combine(temp, "x.txt");
            File.WriteAllText(file, "wgdot", Encoding.UTF8);
            string hash = Sha256(file);
            if (String.IsNullOrWhiteSpace(hash) || hash.Length != 64) throw new Exception("SHA-256 self-test failed.");
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
        using (RegistryKey key = Registry.CurrentUser.OpenSubKey("Environment", true))
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

    static Dictionary<string, object> AsDictionary(object value)
    {
        var d = value as Dictionary<string, object>;
        return d ?? new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
    }

    static string GetString(Dictionary<string, object> d, string key)
    {
        object value;
        return d.TryGetValue(key, out value) && value != null ? Convert.ToString(value) : "";
    }

    static string Sha256(string path)
    {
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
