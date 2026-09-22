-- github.com/dillacorn/win-glaze-dots
-- %APPDATA%\yazi\config\init.lua

function Linemode:size_and_mtime()
    local size = self._file:size()
    local size_text

    if size then
        size_text = ya.readable_size(size)
    else
        local folder = cx.active:history(self._file.url)
        size_text = folder and tostring(#folder.files) or "-"
    end

    local time = math.floor(self._file.stat.mtime or 0)
    local date_text = "-"

    if time > 0 then
        local parts = os.date("*t", time)
        date_text = string.format(
            "%d/%d/%02d",
            parts.month,
            parts.day,
            parts.year % 100
        )
    end

    return string.format("%9s  %8s", size_text, date_text)
end
