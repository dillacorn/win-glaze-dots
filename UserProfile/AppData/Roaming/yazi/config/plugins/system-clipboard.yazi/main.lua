local M = {}

local function notify_error(message)
  ya.notify({
    title = "System Clipboard",
    content = message,
    timeout = 6.5,
    level = "error",
  })
end

local function utf16le(value)
  local out = {}
  for _, code in utf8.codes(value) do
    if code <= 0xFFFF then
      out[#out + 1] = string.char(code % 256, math.floor(code / 256))
    else
      code = code - 0x10000
      local high = 0xD800 + math.floor(code / 0x400)
      local low = 0xDC00 + (code % 0x400)
      out[#out + 1] = string.char(high % 256, math.floor(high / 256))
      out[#out + 1] = string.char(low % 256, math.floor(low / 256))
    end
  end
  return table.concat(out)
end

local function base64(value)
  local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  return ((value:gsub(".", function(char)
    local bits = ""
    local byte = string.byte(char)
    for i = 8, 1, -1 do
      bits = bits .. (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and "1" or "0")
    end
    return bits
  end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(bits)
    if #bits < 6 then return "" end
    local value6 = 0
    for i = 1, 6 do
      if bits:sub(i, i) == "1" then
        value6 = value6 + 2 ^ (6 - i)
      end
    end
    return alphabet:sub(value6 + 1, value6 + 1)
  end) .. ({ "", "==", "=" })[#value % 3 + 1])
end

local function read_all(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local value = file:read("*a")
  file:close()
  return value
end

function M.copy(paths)
  if ya.target_os() ~= "windows" then
    notify_error("This clipboard helper is for Windows.")
    return
  end
  if not paths or #paths == 0 then
    notify_error("No files to copy.")
    return
  end

  local temp_dir = os.getenv("TEMP")
  if not temp_dir or temp_dir == "" then
    notify_error("TEMP is unavailable.")
    return
  end

  local nonce = string.format("%d-%d", os.time(), math.floor(os.clock() * 1000000))
  local list_path = temp_dir .. "\\yazi-system-clipboard-" .. nonce .. ".txt"
  local result_path = temp_dir .. "\\yazi-system-clipboard-" .. nonce .. ".result"

  local file = io.open(list_path, "wb")
  if not file then
    notify_error("Could not prepare the Windows clipboard selection.")
    return
  end
  file:write(table.concat(paths, "\n"))
  file:close()

  local escaped_list = list_path:gsub("'", "''")
  local escaped_result = result_path:gsub("'", "''")
  local script = string.format([[
$ErrorActionPreference = 'Stop'
$list = '%s'
$result = '%s'
try {
  Add-Type -AssemblyName System.Windows.Forms
  $files = [System.Collections.Specialized.StringCollection]::new()
  Get-Content -LiteralPath $list -Encoding UTF8 | ForEach-Object {
    if ($_.Length -gt 0) {
      $null = $files.Add($_)
    }
  }
  [System.Windows.Forms.Clipboard]::SetFileDropList($files)
  [System.IO.File]::WriteAllText($result, 'OK', [System.Text.Encoding]::ASCII)
}
catch {
  [System.IO.File]::WriteAllText($result, $_.Exception.Message, [System.Text.Encoding]::UTF8)
}
finally {
  Remove-Item -LiteralPath $list -Force -ErrorAction SilentlyContinue
}
]], escaped_list, escaped_result)

  local encoded = base64(utf16le(script))
  local status, err = Command("powershell.exe")
    :arg({
      "-NoLogo",
      "-NoProfile",
      "-NonInteractive",
      "-Sta",
      "-WindowStyle", "Hidden",
      "-EncodedCommand", encoded,
    })
    :status()

  if err or not status or not status.success then
    os.remove(list_path)
    os.remove(result_path)
    notify_error("Could not start the Windows clipboard mirror.")
    return
  end

  for _ = 1, 60 do
    local result = read_all(result_path)
    if result then
      os.remove(result_path)
      if result ~= "OK" then
        notify_error("Windows clipboard mirror failed: " .. result)
      end
      return
    end
    ya.sleep(0.05)
  end

  notify_error("Windows clipboard mirror timed out.")
end

return M
