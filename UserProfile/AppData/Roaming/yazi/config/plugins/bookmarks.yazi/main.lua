local M = {}

local KIND = "@wgdot-yazi-bookmarks"
local MAX_BOOKMARKS = 35
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
    return state_dir() .. "\\wgdot-bookmarks.txt"
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
            if #out >= MAX_BOOKMARKS then break end
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

function M:is_bookmarked(path)
    for _, bookmarked in ipairs(read_state()) do
        if bookmarked == path then return true end
    end
    return false
end

local snapshot = ya.sync(function(self)
    local disk = read_state()
    if #disk > 0 then
        self.bookmarks = disk
    else
        self.bookmarks = normalized(self.bookmarks or {})
    end
    return normalized(self.bookmarks)
end)

local replace = ya.sync(function(self, paths)
    self.bookmarks = normalized(paths)
    write_state(self.bookmarks)
    ps.pub(KIND, self.bookmarks)
    ps.pub_to(0, KIND, self.bookmarks)
end)

local toggle = ya.sync(function(self, path)
    local next_bookmarks = {}
    local removed = false

    for _, bookmarked in ipairs(read_state()) do
        if bookmarked == path then
            removed = true
        else
            next_bookmarks[#next_bookmarks + 1] = bookmarked
        end
    end

    if not removed then table.insert(next_bookmarks, 1, path) end

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

    ps.sub(KIND, function(incoming)
        self.bookmarks = normalized(incoming)
    end)
    ps.sub_remote(KIND, function(incoming)
        self.bookmarks = normalized(incoming)
        write_state(self.bookmarks)
        ps.pub(KIND, self.bookmarks)
    end)
end)

function M:setup()
    subscribe()
end

function M:entry(job)
    if job.args[1] == "toggle" then
        local path = job.args[2]
        if not path or path == "" then return end

        local cha = fs.cha(Url(path), true)
        if not cha then
            return ya.notify {
                title = "Bookmarks",
                content = "Only existing files or folders can be bookmarked.",
                timeout = 3,
                level = "warn",
            }
        end

        local added = toggle(path)
        return ya.notify {
            title = "Bookmarks",
            content = added and ("Bookmarked: " .. path) or ("Removed bookmark: " .. path),
            timeout = 2,
        }
    end

    local bookmarks = snapshot()
    local items = {}
    for _, path in ipairs(bookmarks) do
        local cha = fs.cha(Url(path), true)
        if cha then
            items[#items + 1] = { path = path, is_dir = cha.is_dir }
        end
    end

    if #items ~= #bookmarks then
        local valid = {}
        for _, item in ipairs(items) do
            valid[#valid + 1] = item.path
        end
        replace(valid)
    end

    if #items == 0 then
        return ya.notify {
            title = "Bookmarks",
            content = "No bookmarked items.",
            timeout = 3,
        }
    end

    local candidates = {}
    for i, item in ipairs(items) do
        local url = Url(item.path)
        local name = tostring(url.name or item.path)
        local parent = url.parent and tostring(url.parent) or ""
        candidates[i] = {
            on = KEYS[i],
            desc = parent ~= "" and (name .. " | " .. parent) or name,
        }
    end

    local choice = ya.which { cands = candidates, silent = false }
    local item = choice and items[choice] or nil
    if item then
        if item.is_dir then
            ya.emit("cd", { Url(item.path), raw = true })
        else
            ya.emit("reveal", { Url(item.path), raw = true })
        end
    end
end

return M
