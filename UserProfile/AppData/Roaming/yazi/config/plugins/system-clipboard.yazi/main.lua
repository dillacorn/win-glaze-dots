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

  local local_app_data = os.getenv("LOCALAPPDATA")
  local temp_dir = os.getenv("TEMP")
  if not local_app_data or local_app_data == "" or not temp_dir or temp_dir == "" then
    notify_error("WGDot clipboard helper environment is unavailable.")
    return
  end

  local helper = local_app_data .. "\\wgdot\\bin\\wgdotw.exe"
  local probe = io.open(helper, "rb")
  if not probe then
    notify_error("WGDot clipboard helper is not installed or approved.")
    return
  end
  probe:close()

  local list_path = string.format(
    "%s\\wgdot-yazi-copy-%d-%d.txt",
    temp_dir,
    os.time(),
    math.floor(os.clock() * 1000000)
  )
  local file = io.open(list_path, "wb")
  if not file then
    notify_error("Could not prepare the Windows clipboard selection.")
    return
  end

  for _, path in ipairs(paths) do
    file:write(path, "\n")
  end
  file:close()

  local status, err = Command(helper):arg({ "yazi-copy", list_path }):status()
  if err or (status and not status.success) then
    os.remove(list_path)
    notify_error("Yazi copy succeeded, but the Windows clipboard mirror is unavailable.")
  end
end

return M
