local M = {}

local KIND = "@dillacorn-yazi-recent-files"
local MAX_RECENTS = 35
local KEYS = {
    "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
    "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
    "u", "v", "w", "x", "y", "z",
}

local function state_dir()
    local root = os.getenv("APPDATA") or os.getenv("LOCALAPPDATA") or "."
    return root .. "\\yazi\\state"
end

local function state_file()
    return state_dir() .. "\\wgdot-recent-files.txt"
end

local function ensure_state_dir()
    local dir = state_dir()
    if dir:find('"', 1, true) then
        return false
    end
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
    for line in file:lines() do
        if line ~= "" then out[#out + 1] = line end
    end
    file:close()
    return normalized(out)
end

local function write_state(list)
    ensure_state_dir()
    local file = io.open(state_file(), "w")
    if not file then return false end
    for _, path in ipairs(normalized(list)) do
        file:write(path, "\n")
    end
    file:close()
    return true
end

local snapshot = ya.sync(function(self)
    local disk = read_state()
    if #disk > 0 then
        self.recents = disk
    else
        self.recents = normalized(self.recents or {})
    end
    return normalized(self.recents)
end)

local replace = ya.sync(function(self, paths)
    self.recents = normalized(paths)
    write_state(self.recents)
    ps.pub(KIND, self.recents)
    ps.pub_to(0, KIND, self.recents)
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

    ps.sub(KIND, function(incoming)
        self.recents = normalized(incoming)
    end)
    ps.sub_remote(KIND, function(incoming)
        self.recents = normalized(incoming)
        write_state(self.recents)
        ps.pub(KIND, self.recents)
    end)
end)

function M:setup()
    subscribe()
end

function M:entry(job)
    if job.args[1] == "record" then
        local paths = {}
        for i = 2, #job.args do
            if type(job.args[i]) == "string" and job.args[i] ~= "" then
                paths[#paths + 1] = job.args[i]
            end
        end
        if #paths > 0 then record(paths) end
        return
    end

    local recents = snapshot()
    local files = {}
    for _, path in ipairs(recents) do
        local cha = fs.cha(Url(path), true)
        if cha and not cha.is_dir then files[#files + 1] = path end
    end

    if #files ~= #recents then replace(files) end

    if #files == 0 then
        return ya.notify {
            title = "Recent files",
            content = "No recently opened files.",
            timeout = 3,
        }
    end

    local candidates = {}
    for i, path in ipairs(files) do
        local url = Url(path)
        local name = tostring(url.name or path)
        local parent = url.parent and tostring(url.parent) or ""
        candidates[i] = {
            on = KEYS[i],
            desc = parent ~= "" and (name .. " | " .. parent) or name,
        }
    end

    local choice = ya.which { cands = candidates, silent = false }
    if choice then
        ya.emit("reveal", { Url(files[choice]), raw = true })
    end
end

return M
