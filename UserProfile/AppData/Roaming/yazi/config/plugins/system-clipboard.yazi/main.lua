local M = {}

local get_yanked_paths = ya.sync(function()
  local paths = {}
  for _, item in pairs(cx.yanked) do
    local url = item.url or item
    local is_regular = url.spec and url.spec.is_regular or url.is_regular
    if is_regular then
      table.insert(paths, tostring(url))
    end
  end
  return paths
end)

local function notify_error(message)
  ya.notify({
    title = "System Clipboard",
    content = message,
    timeout = 6.5,
    level = "error",
  })
end

function M:entry()
  if ya.target_os() ~= "windows" then
    notify_error("This clipboard helper is for Windows.")
    return
  end

  local paths = get_yanked_paths()
  if #paths == 0 then
    notify_error("No files to copy.")
    return
  end

  local temp_dir = os.getenv("TEMP")
  if not temp_dir or temp_dir == "" then
    notify_error("TEMP is unavailable.")
    return
  end

  local list_path = temp_dir .. "\\yazi_system_clipboard_" .. os.time() .. ".txt"
  local file = io.open(list_path, "w")
  if not file then
    notify_error("Could not create temporary clipboard file.")
    return
  end

  file:write(table.concat(paths, "\n"))
  file:close()

  local escaped = list_path:gsub("'", "''")
  local script = string.format([[
Add-Type -AssemblyName System.Windows.Forms
$files = [System.Collections.Specialized.StringCollection]::new()
Get-Content -LiteralPath '%s' -Encoding UTF8 | ForEach-Object {
  if ($_.Length -gt 0) {
    $null = $files.Add($_)
  }
}
Remove-Item -LiteralPath '%s' -ErrorAction SilentlyContinue
[System.Windows.Forms.Clipboard]::SetFileDropList($files)
]], escaped, escaped)

  local output, err = Command("powershell.exe")
    :arg({ "-NoProfile", "-NonInteractive", "-Sta", "-Command", script })
    :output()

  if err then
    notify_error("PowerShell clipboard command failed: " .. tostring(err))
    return
  end
  if not output.status.success then
    notify_error("PowerShell clipboard command exited with code " .. tostring(output.status.code))
  end
end

return M
