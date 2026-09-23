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

local WgdotYaziItemActions = {
    { label = "Open / Enter", shortcut = "Enter", action = "smart_open" },
    { label = "Open with...", shortcut = "O", action = "open_with" },
    { label = "Rename", shortcut = "r", action = "rename" },
    { label = "Copy", shortcut = "y", action = "copy" },
    { label = "Cut", shortcut = "Y", action = "cut" },
    { label = "Copy path", shortcut = "cc", action = "copy_path" },
    { label = "Details", shortcut = "Tab", action = "details" },
    { label = "Trash", shortcut = "dd", action = "trash" },
}

local WgdotYaziFolderActions = {
    { label = "New file", shortcut = "a", action = "new_file" },
    { label = "New folder", shortcut = "a /", action = "new_folder" },
    { label = "Paste", shortcut = "p", action = "paste" },
    { label = "Terminal here", shortcut = "t e", action = "terminal" },
}

WgdotYaziContextMenu = {
    _id = "wgdot-yazi-context-menu",
    _visible = false,
    _kind = "item",
    _x = 0,
    _y = 0,
    _area = ui.Rect {},
    _list_area = ui.Rect {},
}

function WgdotYaziContextMenu:show(kind, x, y)
    self._kind = kind
    self._x = x
    self._y = y
    self._visible = true
    ui.render()
end

function WgdotYaziContextMenu:hide()
    if not self._visible then
        return
    end

    self._visible = false
    ui.render()
end

function WgdotYaziContextMenu:actions()
    return self._kind == "background" and WgdotYaziFolderActions or WgdotYaziItemActions
end

function WgdotYaziContextMenu:footer()
    if self._kind == "background" then
        return {
            "Keys: a create | p paste | t e terminal",
            "Folder: choose a, then end the name with /",
        }
    end

    return {
        "Keys: Enter open | O open with | r rename | y/Y copy/cut",
        "More: cc path | Tab info | dd trash",
    }
end

function WgdotYaziContextMenu:new(area)
    self._screen = area
    if not self._visible then
        self._area = ui.Rect {}
        self._list_area = ui.Rect {}
        return self
    end

    local actions = self:actions()
    local width = math.min(56, area.w)
    local height = math.min(#actions + 4, area.h)

    if width < 28 or height < #actions + 4 then
        self._area = ui.Rect {}
        self._list_area = ui.Rect {}
        return self
    end

    local max_x = area.x + area.w - width
    local max_y = area.y + area.h - height
    local x = math.max(area.x, math.min(self._x, max_x))
    local y = math.max(area.y, math.min(self._y, max_y))

    self._area = ui.Rect { x = x, y = y, w = width, h = height }
    self._list_area = ui.Rect {
        x = x + 1,
        y = y + 1,
        w = width - 2,
        h = #actions,
    }
    self._footer_area = ui.Rect {
        x = x + 1,
        y = y + 1 + #actions,
        w = width - 2,
        h = 2,
    }

    return self
end

function WgdotYaziContextMenu:reflow()
    return self._visible and self._area.w > 0 and { self } or {}
end

function WgdotYaziContextMenu:redraw()
    if not self._visible or self._area.w == 0 then
        return {}
    end

    local rows = {}
    local content_width = self._list_area.w
    for _, action in ipairs(self:actions()) do
        local gap = math.max(1, content_width - #action.label - #action.shortcut - 2)
        rows[#rows + 1] = ui.Line {
            ui.Span(" " .. action.label):style(th.help.action),
            ui.Span(string.rep(" ", gap)),
            ui.Span(action.shortcut):style(th.help.chord),
            ui.Span(" "),
        }
    end

    local footer = self:footer()
    return {
        ui.Clear(self._area),
        ui.Border(ui.Edge.ALL)
            :area(self._area)
            :type(ui.Border.ROUNDED)
            :style(th.help.border)
            :title(ui.Line(self._kind == "background" and " Folder actions " or " Item actions ")
                :align(ui.Align.CENTER)),
        ui.List(rows):area(self._list_area),
        ui.Text({
            ui.Line(" " .. footer[1]):style(ui.Style():dim()),
            ui.Line(" " .. footer[2]):style(ui.Style():dim()),
        }):area(self._footer_area),
    }
end

function WgdotYaziContextMenu:run(action)
    self._visible = false
    ui.render()

    if action == "smart_open" then
        WgdotYaziSmartEnter()
    elseif action == "open_with" then
        ya.emit("open", { interactive = true, hovered = true })
    elseif action == "rename" then
        ya.emit("rename", { hovered = true })
    elseif action == "copy" then
        ya.emit("yank", {})
    elseif action == "cut" then
        ya.emit("yank", { cut = true })
    elseif action == "copy_path" then
        ya.emit("copy", { "path", hovered = true })
    elseif action == "details" then
        ya.emit("spot", {})
    elseif action == "trash" then
        ya.emit("remove", {})
    elseif action == "new_file" then
        ya.emit("create", { dir = false })
    elseif action == "new_folder" then
        ya.emit("create", { dir = true })
    elseif action == "paste" then
        ya.emit("paste", {})
    elseif action == "terminal" then
        ya.emit("shell", { "wt.exe -w new new-tab -d .", orphan = true })
    end
end

function WgdotYaziContextMenu:click(event, up)
    if up or not event.is_left then
        return
    end

    local row = event.y - self._list_area.y + 1
    local action = self:actions()[row]
    if action then
        self:run(action.action)
    else
        self:hide()
    end
end

Modal:children_add(WgdotYaziContextMenu, 20)

local WgdotYaziDefaultCurrentClick = Current.click

function Current:click(event, up)
    if not up and event.is_right then
        local row = event.y - self._area.y + 1
        if not self._folder.window[row] then
            WgdotYaziContextMenu:show("background", event.x, event.y)
            return
        end
    elseif not up and event.is_left then
        WgdotYaziContextMenu:hide()
    end

    return WgdotYaziDefaultCurrentClick(self, event, up)
end

function Entity:click(event, up)
    if up then
        return
    elseif not event.is_left and not event.is_right then
        return
    end

    local was_hovered = self._file.is_hovered
    if event.is_right and not self._file:is_selected() then
        ya.emit("toggle_all", { state = "off" })
    end

    ya.emit("reveal", { self._file.url })

    if event.is_right then
        WgdotYaziContextMenu:show("item", event.x, event.y)
    elseif was_hovered and self._file.cha.is_dir then
        WgdotYaziContextMenu:hide()
        ya.emit("enter", {})
    else
        WgdotYaziContextMenu:hide()
    end
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
