local M = {}

local KIND = "@dillacorn-yazi-recent-files"
local MAX_RECENTS = 35
local KEYS = {
    "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
    "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
    "u", "v", "w", "x", "y", "z",
}

local recents = {}
local setup_done = false

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

local function publish()
    ps.pub_to(0, KIND, recents)
end

local function merge_remote(incoming)
    local remote = normalized(incoming)
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
    for _, path in ipairs(recents) do
        add(path)
    end

    local needs_republish = not contains_all(remote, recents)
    recents = merged

    if needs_republish then
        publish()
    end
end

function M:setup()
    if setup_done then
        return
    end

    setup_done = true
    ps.sub_remote(KIND, merge_remote)
end

function M:record(paths)
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
    for _, path in ipairs(recents) do
        add(path)
    end

    if #next_recents == 0 then
        return
    end

    recents = next_recents
    publish()
end

function M:entry()
    local files = {}

    for _, path in ipairs(recents) do
        local url = Url(path)
        local cha = fs.cha(url, true)
        if cha and not cha.is_dir then
            files[#files + 1] = path
        end
    end

    if #files == 0 then
        return ya.notify {
            title = "Recent files",
            content = "No recently opened Yazi files yet.",
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
