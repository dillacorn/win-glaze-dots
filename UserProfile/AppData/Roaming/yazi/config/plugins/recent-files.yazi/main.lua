local M = {}

local KIND = "@dillacorn-yazi-recent-files"
local ROOT = "wgdot-recents://collection/@/"
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

local function publish(list)
    local clean = normalized(list)
    write_state(clean)
    pcall(ps.pub_to, 0, KIND, clean)
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

local subscribe = ya.sync(function(self)
    self.recents = normalized(read_state())
    pcall(ps.unsub, KIND)
    pcall(ps.unsub_remote, KIND)
    ps.sub(KIND, function(incoming) self.recents = normalized(incoming) end)
    ps.sub_remote(KIND, function(incoming)
        self.recents = normalized(incoming)
        write_state(self.recents)
        ps.pub(KIND, self.recents)
        if tostring(cx.active.current.cwd):match("^wgdot%-recents://") then ya.emit("refresh", {}) end
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
    for i, path in ipairs(read_state()) do
        out[#out + 1] = { path = path, name = string.format("%04d--%s", i, basename(path)) }
    end
    return out
end

local function file_cha() return Cha { mode = tonumber("100644", 8) } end
local function dir_cha() return Cha { mode = tonumber("40755", 8) } end

local function virtual_file(url, item)
    local cha = file_cha()
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
    local cha = dir_cha()
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
        return nil, Error.fs { kind = "Other", message = "Unsupported recent-files VFS operation: " .. tostring(job.op) }
    end
    return handler(self, job)
end

function M:setup() subscribe() end

function M:entry(job)
    if job.args[1] == "record" then
        local paths = {}
        for i = 2, #job.args do
            if type(job.args[i]) == "string" and job.args[i] ~= "" then paths[#paths + 1] = decode_arg(job.args[i]) end
        end
        if #paths > 0 then record(paths) end
        return
    end
    snapshot()
    ya.emit("cd", { Url(ROOT) })
end

return M
