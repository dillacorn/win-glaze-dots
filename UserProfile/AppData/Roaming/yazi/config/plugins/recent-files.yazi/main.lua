local M = {}

local KIND = "@dillacorn-yazi-recent-files"
local MAX_RECENTS = 35
local KEYS = {
    "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
    "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
    "u", "v", "w", "x", "y", "z",
}

local function normalized(list)
    local out = {}
    local seen = {}

    if type(list) ~= "table" then
        return out
    end

    for _, path in ipairs(list) do
        if type(path) == "string" and path ~= "" and not seen[path] then
            seen[path] = true
            out[#out + 1] = path
            if #out >= MAX_RECENTS then
                break
            end
        end
    end

    return out
end

local function contains_all(haystack, needles)
    local seen = {}
    for _, path in ipairs(haystack) do
        seen[path] = true
    end
    for _, path in ipairs(needles) do
        if not seen[path] then
            return false
        end
    end
    return true
end

local snapshot = ya.sync(function(self)
    return normalized(self.recents or {})
end)

local record = ya.sync(function(self, paths)
    local next_recents = {}
    local seen = {}

    local function add(path)
        if type(path) == "string" and path ~= "" and not seen[path] and #next_recents < MAX_RECENTS then
            seen[path] = true
            next_recents[#next_recents + 1] = path
        end
    end

    for _, path in ipairs(paths or {}) do
        add(path)
    end
    for _, path in ipairs(self.recents or {}) do
        add(path)
    end

    if #next_recents == 0 then
        return
    end

    self.recents = next_recents
    ps.pub(KIND, self.recents)
    ps.pub_to(0, KIND, self.recents)
end)

local replace = ya.sync(function(self, paths)
    self.recents = normalized(paths)
    ps.pub(KIND, self.recents)
    ps.pub_to(0, KIND, self.recents)
end)

function M:setup()
    self.recents = self.recents or {}

    pcall(ps.unsub, KIND)
    pcall(ps.unsub_remote, KIND)

    ps.sub(KIND, function(incoming)
        self.recents = normalized(incoming)
    end)

    ps.sub_remote(KIND, function(incoming)
        local remote = normalized(incoming)
        local local_before = normalized(self.recents)
        local merged = {}
        local seen = {}

        local function add(path)
            if not seen[path] and #merged < MAX_RECENTS then
                seen[path] = true
                merged[#merged + 1] = path
            end
        end

        for _, path in ipairs(remote) do
            add(path)
        end
        for _, path in ipairs(local_before) do
            add(path)
        end

        self.recents = merged
        ps.pub(KIND, self.recents)

        if not contains_all(remote, local_before) then
            ps.pub_to(0, KIND, self.recents)
        end
    end)
end

function M:entry(job)
    if job.args[1] == "record" then
        local paths = {}
        for i = 2, #job.args do
            paths[#paths + 1] = job.args[i]
        end
        return record(paths)
    end

    local recent = snapshot()
    local files = {}

    for _, path in ipairs(recent) do
        local url = Url(path)
        local cha = fs.cha(url, true)
        if cha and not cha.is_dir then
            files[#files + 1] = path
        end
    end

    if #files ~= #recent then
        replace(files)
    end

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

    local choice = ya.which {
        cands = candidates,
        silent = false,
    }
    if choice then
        ya.emit("reveal", { Url(files[choice]), raw = true })
    end
end

return M
