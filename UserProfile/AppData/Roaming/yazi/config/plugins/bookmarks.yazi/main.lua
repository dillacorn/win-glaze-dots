local M = {}

local KIND = "@wgdot-yazi-bookmarks"
local MAX_BOOKMARKS = 1000

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

local function state_file() return state_dir() .. "\\wgdot-bookmarks.txt" end
local function collection_dir() return state_dir() .. "\\collections\\Bookmarks" end

local function ensure_state_dir()
    return fs.create("dir_all", Url(state_dir()))
end

local function parse_entry(value)
    if type(value) ~= "string" or value == "" then return nil end
    local kind, path = value:match("^([DFU])\t(.*)$")
    if kind and path and path ~= "" then return kind, path end
    return "U", value
end

local function encode_entry(kind, path)
    if kind ~= "D" and kind ~= "F" then kind = "U" end
    return kind .. "\t" .. path
end

local function normalized(list)
    local out, seen = {}, {}
    if type(list) ~= "table" then return out end
    for _, value in ipairs(list) do
        local kind, path = parse_entry(value)
        if path and not seen[path] then
            seen[path] = true
            out[#out + 1] = encode_entry(kind, path)
            if #out >= MAX_BOOKMARKS then break end
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
    local file = io.open(state_file(), "w")
    if not file then return false end
    for _, value in ipairs(normalized(list)) do file:write(value, "\n") end
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

    local changed = false
    for index, value in ipairs(normalized(list)) do
        local kind, path = parse_entry(value)
        if kind == "U" then
            local cha = fs.cha(Url(path), true)
            if cha then
                kind = cha.is_dir and "D" or "F"
                list[index] = encode_entry(kind, path)
                changed = true
            end
        end

        local marker = root .. "\\" .. marker_name(index, path)
        if kind == "D" then
            local made, make_err = fs.create("dir_all", Url(marker))
            if not made then return false, make_err end
            local wrote, write_err = fs.write(Url(marker .. "\\.wgdot-target"), path)
            if not wrote then return false, write_err end
        else
            local wrote, write_err = fs.write(Url(marker), path)
            if not wrote then return false, write_err end
        end
    end

    if changed then write_state(list) end
    return true
end

local function marker_target(marker)
    local file = io.open(marker, "rb")
    if not file then
        file = io.open(marker .. "\\.wgdot-target", "rb")
    end
    if not file then return nil end
    local target = file:read("*a")
    file:close()
    return target ~= "" and target or nil
end

local function remove_marker(marker)
    local cha = fs.cha(Url(marker), false)
    if not cha then return true end
    if cha.is_dir then
        return fs.remove("dir_all", Url(marker))
    end
    return fs.remove("file", Url(marker))
end

local snapshot = ya.sync(function(self)
    local disk = read_state()
    if #disk > 0 then self.bookmarks = disk else self.bookmarks = normalized(self.bookmarks or {}) end
    return normalized(self.bookmarks)
end)

local toggle = ya.sync(function(self, path, kind)
    local next_bookmarks = {}
    local removed = false
    for _, value in ipairs(read_state()) do
        local _, bookmarked = parse_entry(value)
        if bookmarked == path then removed = true else next_bookmarks[#next_bookmarks + 1] = value end
    end
    if not removed then table.insert(next_bookmarks, 1, encode_entry(kind, path)) end
    self.bookmarks = normalized(next_bookmarks)
    write_state(self.bookmarks)
    ps.pub(KIND, self.bookmarks)
    ps.pub_to(0, KIND, self.bookmarks)
    return not removed
end)

local forget = ya.sync(function(self, targets)
    local forgotten = {}
    for _, target in ipairs(targets) do forgotten[target] = true end
    local next_bookmarks = {}
    for _, value in ipairs(read_state()) do
        local _, path = parse_entry(value)
        if not forgotten[path] then next_bookmarks[#next_bookmarks + 1] = value end
    end
    self.bookmarks = normalized(next_bookmarks)
    write_state(self.bookmarks)
    ps.pub(KIND, self.bookmarks)
    ps.pub_to(0, KIND, self.bookmarks)
end)

local subscribe = ya.sync(function(self)
    self.bookmarks = normalized(read_state())
    pcall(ps.unsub, KIND)
    pcall(ps.unsub_remote, KIND)
    ps.sub(KIND, function(incoming) self.bookmarks = normalized(incoming) end)
    ps.sub_remote(KIND, function(incoming)
        self.bookmarks = normalized(incoming)
        ps.pub(KIND, self.bookmarks)
    end)
end)

local function notify_error(action, err)
    ya.notify {
        title = "Bookmarks",
        content = "Failed to " .. action .. ": " .. tostring(err or "unknown error"),
        timeout = 5,
        level = "error",
    }
end

local function activate(marker, new_tab)
    local target = marker_target(marker)
    if not target then
        return ya.notify { title = "Bookmarks", content = "Bookmark marker is invalid.", timeout = 3, level = "warn" }
    end

    local cha = fs.cha(Url(target), true)
    if not cha then
        local ok, err = ensure_state_dir()
        if not ok then return notify_error("prepare bookmark state", err) end
        forget { target }
        remove_marker(marker)
        ya.emit("refresh", {})
        return ya.notify {
            title = "Bookmarks",
            content = "Target no longer exists; removed stale bookmark.",
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
        if not ok then notify_error("remove bookmark entry", err) end
    end
    ya.emit("refresh", {})
end

function M:setup() subscribe() end

function M:entry(job)
    local command = job.args[1]

    if command == "toggle" then
        local ok, err = ensure_state_dir()
        if not ok then return notify_error("prepare bookmark state", err) end
        local path = job.args[3] and decode_arg(job.args[3]) or decode_arg(job.args[2])
        if not path or path == "" then return end
        local cha = fs.cha(Url(path), true)
        if not cha then
            return ya.notify { title = "Bookmarks", content = "Only existing files or folders can be bookmarked.", timeout = 3, level = "warn" }
        end
        local added = toggle(path, cha.is_dir and "D" or "F")
        return ya.notify {
            title = "Bookmarks",
            content = added and ("Bookmarked: " .. path) or ("Removed bookmark: " .. path),
            timeout = 2,
        }
    elseif command == "activate" then
        local marker = decode_arg(job.args[2])
        local new_tab = decode_arg(job.args[3]) == "1"
        if marker then activate(marker, new_tab) end
        return
    elseif command == "delete" then
        local ok, err = ensure_state_dir()
        if not ok then return notify_error("prepare bookmark state", err) end
        local markers = {}
        for i = 2, #job.args do markers[#markers + 1] = decode_arg(job.args[i]) end
        if #markers > 0 then delete_markers(markers) end
        return
    end

    local list = snapshot()
    local ok, err = materialize(list)
    if not ok then return notify_error("build bookmark folder", err) end
    ya.emit("cd", { Url(collection_dir()), raw = true })
end

return M
