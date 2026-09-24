local M = {}

local KIND = "@wgdot-yazi-bookmarks"
local ROOT = "wgdot-bookmarks://collection/"
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

local function ensure_state_dir()
    local dir = state_dir()
    if dir:find('"', 1, true) then return false end
    os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '" >nul 2>nul')
    return true
end

local function parse_entry(value)
    if type(value) ~= "string" or value == "" then return nil end
    local kind, path = value:match("^([DF])\t(.*)$")
    if kind and path and path ~= "" then return kind, path end
    local cha = fs.cha(Url(value), true)
    return cha and cha.is_dir and "D" or "F", value
end

local function encode_entry(kind, path) return (kind == "D" and "D" or "F") .. "\t" .. path end

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
    ensure_state_dir()
    local file = io.open(state_file(), "w")
    if not file then return false end
    for _, value in ipairs(normalized(list)) do file:write(value, "\n") end
    file:close()
    return true
end

local function publish(list)
    local clean = normalized(list)
    write_state(clean)
    pcall(ps.pub_to, 0, KIND, clean)
end

function M:is_bookmarked(path)
    for _, value in ipairs(read_state()) do
        local _, bookmarked = parse_entry(value)
        if bookmarked == path then return true end
    end
    return false
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

local subscribe = ya.sync(function(self)
    self.bookmarks = normalized(read_state())
    pcall(ps.unsub, KIND)
    pcall(ps.unsub_remote, KIND)
    ps.sub(KIND, function(incoming) self.bookmarks = normalized(incoming) end)
    ps.sub_remote(KIND, function(incoming)
        self.bookmarks = normalized(incoming)
        write_state(self.bookmarks)
        ps.pub(KIND, self.bookmarks)
        if tostring(cx.active.current.cwd):match("^wgdot%-bookmarks://") then ya.emit("refresh", {}) end
    end)
end)

local function basename(path)
    local p = path:gsub("\\", "/"):gsub("/+$", "")
    local name = p:match("([^/]+)$") or p
    if name == "" then name = "item" end
    return name:gsub("[:/\\]", "_")
end

local function items()
    local out = {}
    for i, value in ipairs(read_state()) do
        local kind, path = parse_entry(value)
        out[#out + 1] = { kind = kind, path = path, name = string.format("%04d--%s", i, basename(path)) }
    end
    return out
end

local function item_cha(kind) return Cha { mode = tonumber(kind == "D" and "40755" or "100644", 8) } end

local function virtual_file(url, item)
    local cha = item_cha(item.kind)
    return File { url = url, cha = cha, link_to = Path.os(item.path) }, cha
end

local function find_item(url)
    local name = tostring(url.name or "")
    for _, item in ipairs(items()) do if item.name == name then return item end end
end

local function remove_url(url)
    local name = tostring(url.name or "")
    local current = read_state()
    for i, item in ipairs(items()) do
        if item.name == name then
            table.remove(current, i)
            publish(current)
            return true
        end
    end
    return true
end

function M:Capabilities()
    return { symlink = false, hard_link = false, trash = true, copy_progressive = false }
end

function M:ReadDir(job)
    local out = {}
    for _, item in ipairs(items()) do
        local file, cha = virtual_file(job.url:join(Path.os(item.name)), item)
        out[#out + 1] = { file = file, cha = cha }
    end
    return out
end

function M:File(job)
    local item = find_item(job.url)
    if item then
        local file = virtual_file(job.url, item)
        return file
    end
    local cha = item_cha("D")
    return File { url = job.url, cha = cha }
end

function M:Metadata(job) local file = self:File(job); return file and file.cha end
function M:SymlinkMetadata(job) return self:Metadata(job) end
function M:Revalidate() return nil end
function M:Canonicalize(job) return job.url end
function M:Absolute(job) return job.url end
function M:Casefold(job) return job.url end
function M:Trash(job) return remove_url(job.url) end
function M:RemoveFile(job) return remove_url(job.url) end
function M:RemoveDir(job) return remove_url(job.url) end

function M:provide(job)
    local handler = self[job.op]
    if not handler then
        return nil, Error.fs { kind = "Other", message = "Unsupported bookmarks VFS operation: " .. tostring(job.op) }
    end
    return handler(self, job)
end

function M:setup() subscribe() end

function M:entry(job)
    if job.args[1] == "toggle" then
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
    end
    snapshot()
    ya.emit("cd", { Url(ROOT) })
end

return M
