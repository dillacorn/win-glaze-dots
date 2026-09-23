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

    local time = math.floor(self._file.cha.mtime or 0)
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

function WgdotYaziSmartEnter()
    local hovered = cx.active.current.hovered
    ya.emit(hovered and hovered.cha.is_dir and "enter" or "open", {})
end

WgdotYaziTimeFormat = "24h"

ps.sub("@wgdot-yazi-time-format", function(value)
    if value == "12h" or value == "24h" then
        WgdotYaziTimeFormat = value
    end
end)

function WgdotYaziToggleTimeFormat()
    local next_format = WgdotYaziTimeFormat == "24h" and "12h" or "24h"
    WgdotYaziTimeFormat = next_format
    ps.pub("@wgdot-yazi-time-format", next_format)
end

function Status:modified_time()
    local hovered = self._current.hovered
    if not hovered then
        return ""
    end

    local time = math.floor(hovered.cha.mtime or 0)
    if time <= 0 then
        return ""
    end

    local parts = os.date("*t", time)

    if WgdotYaziTimeFormat == "12h" then
        local hour = parts.hour % 12
        if hour == 0 then
            hour = 12
        end

        local meridiem = parts.hour < 12 and "AM" or "PM"
        return string.format(
            " Modified: %d/%d/%02d %d:%02d %s ",
            parts.month,
            parts.day,
            parts.year % 100,
            hour,
            parts.min,
            meridiem
        )
    end

    return string.format(
        " Modified: %d/%d/%02d %02d:%02d ",
        parts.month,
        parts.day,
        parts.year % 100,
        parts.hour,
        parts.min
    )
end

Status:children_add(function(self)
    return self:modified_time()
end, 500, Status.RIGHT)
