# c3d-workspace-guard.ps1
# Minimizes Civil 3D (acad.exe) unless target workspace is currently displayed.
# Uses GlazeWM IPC websocket (ws://localhost:6123). :contentReference[oaicite:2]{index=2}

[CmdletBinding()]
param(
  [string]$TargetWorkspace = "2",
  [string[]]$ProcessNames = @("acad", "acadlt"),
  [int]$Port = 6123,
  [int]$ReconnectDelayMs = 2000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class Win32 {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

  [DllImport("user32.dll")]
  public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

  [DllImport("user32.dll")]
  public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

  [DllImport("user32.dll")]
  public static extern bool IsWindowVisible(IntPtr hWnd);

  [DllImport("user32.dll")]
  public static extern bool IsIconic(IntPtr hWnd);

  [DllImport("user32.dll")]
  public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr hWnd);

  [DllImport("user32.dll")]
  public static extern bool BringWindowToTop(IntPtr hWnd);
}
"@ | Out-Null

$SW_MINIMIZE = 6
$SW_RESTORE  = 9

function Get-TopLevelWindowHandlesForPid {
  param([int]$Pid)

  $handles = New-Object System.Collections.Generic.List[System.IntPtr]
  [Win32]::EnumWindows(
    {
      param([IntPtr]$hWnd, [IntPtr]$lParam)

      if (-not [Win32]::IsWindowVisible($hWnd)) { return $true }

      [uint32]$wpid = 0
      [void][Win32]::GetWindowThreadProcessId($hWnd, [ref]$wpid)
      if ($wpid -eq [uint32]$Pid) {
        $handles.Add($hWnd) | Out-Null
      }
      return $true
    },
    [IntPtr]::Zero
  ) | Out-Null

  return $handles
}

function Get-C3DHandles {
  $all = New-Object System.Collections.Generic.List[System.IntPtr]

  foreach ($name in $ProcessNames) {
    $procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
    foreach ($p in $procs) {
      if ($p.Id -le 0) { continue }
      $hs = Get-TopLevelWindowHandlesForPid -Pid $p.Id
      foreach ($h in $hs) { $all.Add($h) | Out-Null }
    }
  }

  # De-dupe
  $uniq = $all | Select-Object -Unique
  return @($uniq)
}

function Minimize-C3D {
  $handles = Get-C3DHandles
  foreach ($h in $handles) {
    if (-not [Win32]::IsIconic($h)) {
      [void][Win32]::ShowWindowAsync($h, $SW_MINIMIZE)
    }
  }
}

function Restore-C3D {
  $handles = Get-C3DHandles
  if ($handles.Count -eq 0) { return }

  foreach ($h in $handles) {
    if ([Win32]::IsIconic($h)) {
      [void][Win32]::ShowWindowAsync($h, $SW_RESTORE)
    }
  }

  # Try to bring one to the foreground (Windows may refuse sometimes).
  $first = $handles[0]
  [void][Win32]::BringWindowToTop($first)
  [void][Win32]::SetForegroundWindow($first)
}

function Receive-TextMessage {
  param(
    [Parameter(Mandatory=$true)][System.Net.WebSockets.ClientWebSocket]$Ws
  )

  $buffer = New-Object byte[] 65536
  $segment = New-Object System.ArraySegment[byte] -ArgumentList $buffer
  $sb = New-Object System.Text.StringBuilder

  while ($true) {
    $result = $Ws.ReceiveAsync($segment, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
      throw "WebSocket closed by server."
    }

    if ($result.Count -gt 0) {
      $text = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Count)
      [void]$sb.Append($text)
    }

    if ($result.EndOfMessage) { break }
  }

  return $sb.ToString()
}

function Send-TextMessage {
  param(
    [Parameter(Mandatory=$true)][System.Net.WebSockets.ClientWebSocket]$Ws,
    [Parameter(Mandatory=$true)][string]$Text
  )

  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  $seg = New-Object System.ArraySegment[byte] -ArgumentList (, $bytes)
  $Ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
}

function Query-WorkspacesDisplayed {
  param(
    [Parameter(Mandatory=$true)][System.Net.WebSockets.ClientWebSocket]$Ws,
    [string]$WorkspaceName
  )

  $query = "query workspaces"
  Send-TextMessage -Ws $Ws -Text $query

  while ($true) {
    $raw = Receive-TextMessage -Ws $Ws
    $msg = $raw | ConvertFrom-Json

    if ($msg.messageType -eq "client_response" -and $msg.clientMessage -eq $query) {
      if (-not $msg.success) { throw "GlazeWM query failed: $($msg.error)" }

      $workspaces = @($msg.data.workspaces)
      $target = $workspaces | Where-Object { $_.name -eq $WorkspaceName }

      # Any monitor displaying workspace 2 => visible.
      $isDisplayed = $false
      foreach ($wsObj in $target) {
        if ($wsObj.isDisplayed -eq $true) { $isDisplayed = $true; break }
      }
      return $isDisplayed
    }

    # Ignore subscription/event frames here. The outer loop will get more events anyway.
  }
}

function Apply-Visibility {
  param(
    [Parameter(Mandatory=$true)][System.Net.WebSockets.ClientWebSocket]$Ws
  )

  $wantVisible = Query-WorkspacesDisplayed -Ws $Ws -WorkspaceName $TargetWorkspace
  if ($wantVisible) { Restore-C3D } else { Minimize-C3D }
}

# Subscribe to workspace + monitor events, then re-evaluate display state each time.
# Event names come directly from GlazeWM-js WmEventType. :contentReference[oaicite:3]{index=3}
$events = @(
  "workspace_activated",
  "workspace_deactivated",
  "workspace_updated",
  "monitor_updated"
)

while ($true) {
  $ws = New-Object System.Net.WebSockets.ClientWebSocket
  try {
    $uri = [Uri]("ws://localhost:$Port")
    $ws.ConnectAsync($uri, [Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null

    # Subscribe
    $subCmd = "sub --events " + ($events -join " ")
    Send-TextMessage -Ws $ws -Text $subCmd

    # Wait for subscribe response to get subscriptionId
    $subscriptionId = $null
    while (-not $subscriptionId) {
      $raw = Receive-TextMessage -Ws $ws
      $msg = $raw | ConvertFrom-Json
      if ($msg.messageType -eq "client_response" -and $msg.clientMessage -eq $subCmd) {
        if (-not $msg.success) { throw "GlazeWM sub failed: $($msg.error)" }
        $subscriptionId = $msg.data.subscriptionId
      }
    }

    # Initial state
    Apply-Visibility -Ws $ws

    # Event loop
    while ($true) {
      $raw = Receive-TextMessage -Ws $ws
      $msg = $raw | ConvertFrom-Json

      if ($msg.messageType -eq "event_subscription" -and $msg.subscriptionId -eq $subscriptionId) {
        Apply-Visibility -Ws $ws
      }
    }
  }
  catch {
    try { $ws.Dispose() } catch {}
    Start-Sleep -Milliseconds $ReconnectDelayMs
  }
}
