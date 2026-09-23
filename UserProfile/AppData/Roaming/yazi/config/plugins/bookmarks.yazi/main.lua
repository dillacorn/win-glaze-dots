local M = { cache = {} }

local KIND = "@wgdot-yazi-bookmarks"
local MAX_BOOKMARKS = 35
local KEYS = {
    "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
    "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
    "u", "v", "w", "x", "y", "z",
}

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

local function update_cache(list)
    M.cache = normalized(list)
end

local function publish_state(self)
    update_cache(self.bookmarks or {})
    ps.pub(KIND, self.bookmarks or {})
    ps.pub_to(0, KIND, self.bookmarks or {})
end

function M:is_bookmarked(path)
    for _, bookmarked in ipairs(self.cache or {}) do
        if bookmarked == path then return true end
    end
    return false
end

local snapshot = ya.sync(function(self)
    return normalized(self.bookmarks or {})
end)

local toggle = ya.sync(function(self, path)
    local next_bookmarks, removed = {}, false
    for _, bookmarked in ipairs(self.bookmarks or {}) do
        if bookmarked == path then
            removed = true
        else
            next_bookmarks[#next_bookmarks + 1] = bookmarked
        end
    end
    if not removed then table.insert(next_bookmarks, 1, path) end

    self.bookmarks = normalized(next_bookmarks)
    publish_state(self)
    return not removed
end)

local replace = ya.sync(function(self, paths)
    self.bookmarks = normalized(paths)
    publish_state(self)
end)

local subscribe = ya.sync(function(self)
    self.bookmarks = self.bookmarks or {}
    update_cache(self.bookmarks)

    pcall(ps.unsub, KIND)
    pcall(ps.unsub_remote, KIND)

    ps.sub(KIND, function(incoming)
        self.bookmarks = normalized(incoming)
        update_cache(self.bookmarks)
    end)

    ps.sub_remote(KIND, function(incoming)
        self.bookmarks = normalized(incoming)
        update_cache(self.bookmarks)
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
        if not cha or not cha.is_dir then
            return ya.notify {
                title = "Bookmarks",
                content = "Only existing directories can be bookmarked.",
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
    local directories = {}
    for _, path in ipairs(bookmarks) do
        local cha = fs.cha(Url(path), true)
        if cha and cha.is_dir then directories[#directories + 1] = path end
    end

    if #directories ~= #bookmarks then replace(directories) end
    if #directories == 0 then
        return ya.notify {
            title = "Bookmarks",
            content = "No bookmarked folders.",
            timeout = 3,
        }
    end

    local candidates = {}
    for i, path in ipairs(directories) do
        local url = Url(path)
        local name = tostring(url.name or path)
        local parent = url.parent and tostring(url.parent) or ""
        candidates[i] = {
            on = KEYS[i],
            desc = parent ~= "" and (name .. " | " .. parent) or name,
        }
    end

    local choice = ya.which { cands = candidates, silent = false }
    if choice then ya.emit("cd", { Url(directories[choice]), raw = true }) end
end

return M
