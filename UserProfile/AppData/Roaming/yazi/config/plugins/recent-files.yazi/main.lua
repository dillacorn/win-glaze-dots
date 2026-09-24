local M = {}

local KIND = "@dillacorn-yazi-recent-files"
local MAX_RECENTS = 1000

local function decode_arg(value)
    if type(value) ~= "string" then return value end
    local hex = value:match("^hex:([0-9a-fA-F]+)$")
    if not hex or #hex % 2 ~= 0 then return value end
    return (hex:gsub("..", function(byte) return string.char(tonumber(byte, 16)) end))
end

local function state_dir()
    local root = os.getenv("APPDATA") or os.getenv("LOCALAPPDATA") or "."
    return root .. "\\yazi\\state"
end

local function state_file() return state_dir() .. "\\wgdot-recent-files.txt" end
local function collection_dir() return state_dir() .. "\\collections\\Recently Opened" end

local function ensure_state_dir()
    local dir = state_dir()
    if dir:find('"', 1, true) then return false end
    os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '" >nul 2>nul')
    return true
end

local function normalized(list)
    local out, seen = {}, {}
    if type(list) ~= "table" then return out end
    for _, path in ipairs(list) do
        if type(path) == "string" and path ~= "" and not seen[path] then
            seen[path] = true
            out[#out + 1] = path
            if #out >= MAX_RECENTS then break end
        end
    end
    return out
end

local function read_state()
    local file = io.open(state_file(), "r")
    if not file then return {} end
    local out = {}
    for line in file:lines() do if line ~= "" then out[#out + 1] = line end end
    file:close()
    return normalized(out)
end

local function write_state(list)
    ensure_state_dir()
    local file = io.open(state_file(), "w")
    if not file then return false end
    for _, path in ipairs(normalized(list)) do file:write(path, "\n") end
    file:close()
    return true
end

local function safe_name(path)
    local p = path:gsub("\\", "/"):gsub("/+$", "")
    local name = p:match("([^/]+)$") or p
    if name == "" then name = "item" end
    name = name:gsub('[<>:"/\\|%?%*%c]', "_"):gsub("[%. ]+$", "")
    return name ~= "" and name or "item"
end

local function marker_name(index, path)
    return string.format("%04d--%s", index, safe_name(path))
end

local function clear_collection(root)
    local ok, err = fs.create("dir_all", Url(root))
    if not ok then return false, err end
    local files, read_err = fs.read_dir(Url(root), { resolve = true })
    if not files then return false, read_err end
    for _, file in ipairs(files) do
        local removed, remove_err
        if file.cha.is_dir then
            removed, remove_err = fs.remove("dir_all", file.url)
        else
            removed, remove_err = fs.remove("file", file.url)
        end
        if not removed then return false, remove_err end
    end
    return true
end

local function materialize(list)
    local root = collection_dir()
    local ok, err = clear_collection(root)
    if not ok then return false, err end

    for index, path in ipairs(normalized(list)) do
        local marker = root .. "\\" .. marker_name(index, path)
        local wrote, write_err = fs.write(Url(marker), path)
        if not wrote then return false, write_err end
    end
    return true
end

local function marker_target(marker)
    local file = io.open(marker, "rb")
    if not file then return nil end
    local target = file:read("*a")
    file:close()
    return target ~= "" and target or nil
end

local snapshot = ya.sync(function(self)
    local disk = read_state()
    if #disk > 0 then self.recents = disk else self.recents = normalized(self.recents or {}) end
    return normalized(self.recents)
end)

local record = ya.sync(function(self, paths)
    local next_recents = {}
    for _, path in ipairs(paths) do next_recents[#next_recents + 1] = path end
    for _, path in ipairs(read_state()) do next_recents[#next_recents + 1] = path end
    self.recents = normalized(next_recents)
    write_state(self.recents)
    ps.pub(KIND, self.recents)
    ps.pub_to(0, KIND, self.recents)
end)

local forget = ya.sync(function(self, targets)
    local forgotten = {}
    for _, target in ipairs(targets) do forgotten[target] = true end
    local next_recents = {}
    for _, path in ipairs(read_state()) do
        if not forgotten[path] then next_recents[#next_recents + 1] = path end
    end
    self.recents = normalized(next_recents)
    write_state(self.recents)
    ps.pub(KIND, self.recents)
    ps.pub_to(0, KIND, self.recents)
end)

local subscribe = ya.sync(function(self)
    self.recents = normalized(read_state())
    pcall(ps.unsub, KIND)
    pcall(ps.unsub_remote, KIND)
    ps.sub(KIND, function(incoming) self.recents = normalized(incoming) end)
    ps.sub_remote(KIND, function(incoming)
        self.recents = normalized(incoming)
        write_state(self.recents)
        ps.pub(KIND, self.recents)
    end)
end)

local function notify_error(action, err)
    ya.notify {
        title = "Recent files",
        content = "Failed to " .. action .. ": " .. tostring(err or "unknown error"),
        timeout = 5,
        level = "error",
    }
end

local function remove_marker(marker)
    local ok, err = fs.remove("file", Url(marker))
    if not ok and fs.cha(Url(marker), false) then return false, err end
    return true
end

local function activate(marker, new_tab)
    local target = marker_target(marker)
    if not target then
        return ya.notify { title = "Recent files", content = "Recent-file marker is invalid.", timeout = 3, level = "warn" }
    end

    local cha = fs.cha(Url(target), true)
    if not cha then
        forget { target }
        remove_marker(marker)
        ya.emit("refresh", {})
        return ya.notify {
            title = "Recent files",
            content = "Target no longer exists; removed stale recent entry.",
            timeout = 3,
            level = "warn",
        }
    end

    local url = Url(target)
    if new_tab then
        if cha.is_dir then
            ya.emit("tab_create", { target, raw = true })
        elseif url.parent then
            ya.emit("tab_create", { tostring(url.parent), raw = true })
            ya.sleep(25)
            ya.emit("reveal", { url, raw = true })
        end
    elseif cha.is_dir then
        ya.emit("cd", { url, raw = true })
    else
        ya.emit("reveal", { url, raw = true })
    end
end

local function delete_markers(markers)
    local targets = {}
    for _, marker in ipairs(markers) do
        local target = marker_target(marker)
        if target then targets[#targets + 1] = target end
    end
    if #targets > 0 then forget(targets) end
    for _, marker in ipairs(markers) do
        local ok, err = remove_marker(marker)
        if not ok then notify_error("remove recent entry", err) end
    end
    ya.emit("refresh", {})
end

function M:setup() subscribe() end

function M:entry(job)
    local command = job.args[1]

    if command == "record" then
        local paths = {}
        for i = 2, #job.args do
            if type(job.args[i]) == "string" and job.args[i] ~= "" then paths[#paths + 1] = decode_arg(job.args[i]) end
        end
        if #paths > 0 then record(paths) end
        return
    elseif command == "activate" then
        local marker = decode_arg(job.args[2])
        local new_tab = decode_arg(job.args[3]) == "1"
        if marker then activate(marker, new_tab) end
        return
    elseif command == "delete" then
        local markers = {}
        for i = 2, #job.args do markers[#markers + 1] = decode_arg(job.args[i]) end
        if #markers > 0 then delete_markers(markers) end
        return
    end

    local list = snapshot()
    local ok, err = materialize(list)
    if not ok then return notify_error("build recent-files folder", err) end
    ya.emit("cd", { Url(collection_dir()), raw = true })
end

return M
