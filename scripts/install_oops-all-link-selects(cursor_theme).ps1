# Define variables
$repoURL = "http://www.rw-designer.com/cursor-downloadset.php?id=oops-all-link-selects"
$tempDir = "$env:TEMP\OopsAllLinkSelects"
$zipFile = "$tempDir\OopsAllLinkSelects.zip"
$cursorDir = "$env:USERPROFILE\Documents\Cursors\OopsAllLinkSelects"

# Step 1: Create temporary directory and clear any previous downloads
if (!(Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

# Step 2: Download the ZIP file
Write-Host "Downloading the cursor theme..."
try {
    Invoke-WebRequest -Uri $repoURL -OutFile $zipFile -UseBasicParsing
    if (!(Test-Path $zipFile)) {
        throw "Download failed"
    }
    
    # Verify it's actually a ZIP file
    $fileHeader = Get-Content $zipFile -Encoding Byte -TotalCount 4
    if ($fileHeader[0] -ne 0x50 -or $fileHeader[1] -ne 0x4B) {
        throw "Downloaded file is not a valid ZIP archive"
    }
    
    Write-Host "ZIP file downloaded and verified successfully"
} catch {
    Write-Host "Failed to download the cursor theme: $_"
    exit 1
}

# Step 4: Extract ZIP directly to cursor scheme directory
Write-Host "Installing the cursor theme..."
if (!(Test-Path $cursorDir)) {
    New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
}

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $cursorDir)
    
    # Verify cursor files were extracted
    $cursorFiles = Get-ChildItem -Path $cursorDir -Include "*.cur", "*.ani" -Recurse
    if ($cursorFiles.Count -eq 0) {
        throw "No cursor files found in extracted ZIP"
    }
    
    Write-Host "Extracted $($cursorFiles.Count) cursor files to scheme directory"
} catch {
    Write-Host "Failed to extract cursor files: $_"
    exit 1
}

# Step 5: Create cursor scheme registry entry
Write-Host "Creating cursor scheme..."
$schemesPath = "HKCU:\Control Panel\Cursors\Schemes"
$schemeName = "OopsAllLinkSelects"

# Registry mappings for cursor files
$cursorMappings = @{
    "Arrow" = "$cursorDir\default.cur"
    "Help" = "$cursorDir\help.cur"
    "AppStarting" = "$cursorDir\busy.ani"
    "Wait" = "$cursorDir\busy.ani"
    "Crosshair" = "$cursorDir\precision select.cur"
    "IBeam" = "$cursorDir\handwrite.cur"
    "NWPen" = "$cursorDir\handwrite.cur"
    "No" = "$cursorDir\unavailable.ani"
    "SizeNS" = "$cursorDir\resize vertical.cur"
    "SizeWE" = "$cursorDir\resize horizontal.cur"
    "SizeNWSE" = "$cursorDir\resize backslash.cur"
    "SizeNESW" = "$cursorDir\resize slash.cur"
    "SizeAll" = "$cursorDir\move.cur"
    "UpArrow" = "$cursorDir\alt select.cur"
    "Hand" = "$cursorDir\link select.cur"
}

try {
    # Create schemes registry key if it doesn't exist
    if (!(Test-Path $schemesPath)) {
        New-Item -Path $schemesPath -Force | Out-Null
    }
    
    # Build scheme value string (comma-separated cursor paths)
    $schemeValue = @(
        $cursorMappings["Arrow"],
        $cursorMappings["Help"],
        $cursorMappings["AppStarting"],
        $cursorMappings["Wait"],
        $cursorMappings["Crosshair"],
        $cursorMappings["IBeam"],
        $cursorMappings["NWPen"],
        $cursorMappings["No"],
        $cursorMappings["SizeNS"],
        $cursorMappings["SizeWE"],
        $cursorMappings["SizeNWSE"],
        $cursorMappings["SizeNESW"],
        $cursorMappings["SizeAll"],
        $cursorMappings["UpArrow"],
        $cursorMappings["Hand"]
    ) -join ","
    
    # Create the scheme entry
    Set-ItemProperty -Path $schemesPath -Name $schemeName -Value $schemeValue -Type String
    
    # Step 6: Apply the scheme by setting individual cursor registry values
    Write-Host "Applying cursor scheme..."
    $registryPath = "HKCU:\Control Panel\Cursors"
    
    foreach ($cursor in $cursorMappings.GetEnumerator()) {
        Set-ItemProperty -Path $registryPath -Name $cursor.Key -Value $cursor.Value -Type String
    }
    
    # Set cursor size to 48
    Write-Host "Setting cursor size..."
    Set-ItemProperty -Path $registryPath -Name "CursorBaseSize" -Value 48 -Type DWord
    
    # Set the current scheme name
    Set-ItemProperty -Path $registryPath -Name "" -Value $schemeName -Type String
    
} catch {
    Write-Host "Failed to create or apply cursor scheme: $_"
    exit 1
}

# Step 7: Refresh the system to apply changes
Write-Host "Applying changes..."
try {
    # Force cursor refresh
    Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        public class Win32 {
            [DllImport("user32.dll", SetLastError = true)]
            public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
        }
"@
    [Win32]::SystemParametersInfo(0x0057, 0, [IntPtr]::Zero, 0x01 -bor 0x02) | Out-Null
} catch {
    Write-Host "Warning: Could not refresh cursors automatically. You may need to log off and back on."
}

Write-Host "Cursor scheme 'OopsAllLinkSelects' created and applied successfully!"
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")