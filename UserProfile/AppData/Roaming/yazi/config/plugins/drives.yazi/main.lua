local M = {}

local KEYS = {
    "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
    "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
    "u", "v", "w", "x", "y", "z",
}

local function describe(partition)
    local dist = partition.dist and tostring(partition.dist) or ""
    local label = partition.label and tostring(partition.label) or ""
    local fstype = partition.fstype and tostring(partition.fstype) or ""
    local parts = { dist ~= "" and dist or tostring(partition.src or "Drive") }

    if label ~= "" then parts[#parts + 1] = label end
    if fstype ~= "" then parts[#parts + 1] = fstype end
    if partition.removable then
        parts[#parts + 1] = "removable"
    elseif partition.external then
        parts[#parts + 1] = "external"
    end
    if (partition.capacity or 0) > 0 then
        parts[#parts + 1] = ya.readable_size(partition.capacity)
    end

    return table.concat(parts, " | ")
end

function M:entry()
    if ya.target_os() ~= "windows" then
        return ya.notify {
            title = "Drives",
            content = "Windows drive picker is available on Windows only.",
            timeout = 3,
            level = "warn",
        }
    end

    local drives = {}
    for _, partition in ipairs(fs.partitions()) do
        local dist = partition.dist and tostring(partition.dist) or ""
        if dist ~= "" then drives[#drives + 1] = partition end
    end

    table.sort(drives, function(a, b)
        return tostring(a.dist) < tostring(b.dist)
    end)

    if #drives == 0 then
        return ya.notify {
            title = "Drives",
            content = "No drives are currently available.",
            timeout = 3,
            level = "warn",
        }
    end

    local candidates = {}
    for i, drive in ipairs(drives) do
        if not KEYS[i] then break end
        candidates[i] = { on = KEYS[i], desc = describe(drive) }
    end

    local choice = ya.which { cands = candidates, silent = false }
    local drive = choice and drives[choice] or nil
    if drive and drive.dist then
        ya.emit("cd", { Url(tostring(drive.dist)), raw = true })
    end
end

return M
