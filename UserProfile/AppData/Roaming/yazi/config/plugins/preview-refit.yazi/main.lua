local M = {}

local function decode_arg(value)
    if type(value) ~= "string" then return value end
    local hex = value:match("^hex:([0-9a-fA-F]+)$")
    if not hex or #hex % 2 ~= 0 then return value end
    return (hex:gsub("..", function(byte) return string.char(tonumber(byte, 16)) end))
end

function M:entry(job)
    local path = decode_arg(job.args[2] or job.args[1])
    if path and path ~= "" then
        local file = fs.file(Url(path))
        if file then
            local cache = ya.file_cache { file = file, skip = 0 }
            if cache and fs.cha(cache) then pcall(fs.remove, "file", cache) end
        end
    end
    ya.emit("peek", { force = true })
end

return M
