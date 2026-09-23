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

local WgdotYaziArchiveSnapshot = ya.sync(function()
    local tab = cx.active
    local files = {}

    if #tab.selected > 0 then
        for _, file in pairs(tab.selected) do
            files[#files + 1] = {
                path = tostring(file.path),
                name = file.name,
                stem = file.url.stem or file.name,
                parent = file.url.parent and tostring(file.url.parent) or "",
                is_dir = file.cha.is_dir,
            }
        end
    elseif tab.current.hovered then
        local file = tab.current.hovered
        files[1] = {
            path = tostring(file.path),
            name = file.name,
            stem = file.url.stem or file.name,
            parent = file.url.parent and tostring(file.url.parent) or "",
            is_dir = file.cha.is_dir,
        }
    end

    return {
        cwd = tostring(tab.current.cwd),
        files = files,
    }
end)

local function WgdotYaziArchiveNotify(content, level)
    ya.notify {
        title = "Archive",
        content = content,
        timeout = 4,
        level = level,
    }
end

local function WgdotYaziRun7z(args, cwd)
    local commands = ya.target_os() == "windows"
        and { "7z.exe", "7zz.exe", "7z" }
        or { "7zz", "7z" }
    local last_error = nil

    for _, command in ipairs(commands) do
        local output, err = Command(command):arg(args):cwd(cwd):output()
        if output then
            return output, nil
        end
        last_error = err
    end

    return nil, last_error
end

local function WgdotYaziUniqueZip(cwd, requested)
    local name = requested
    if name:lower():sub(-4) ~= ".zip" then
        name = name .. ".zip"
    end

    local stem = name:sub(1, -5)
    local index = 1
    while true do
        local candidate = index == 1
            and name
            or string.format("%s (%d).zip", stem, index)
        local url = Url(cwd):join(candidate)
        local cha = fs.cha(url)
        if not cha then
            return url
        end
        index = index + 1
    end
end

function WgdotYaziCompressSelection()
    ya.async(function()
        local snapshot = WgdotYaziArchiveSnapshot()
        if #snapshot.files == 0 then
            return WgdotYaziArchiveNotify("Nothing selected.", "warn")
        end

        for _, file in ipairs(snapshot.files) do
            if file.parent ~= snapshot.cwd then
                return WgdotYaziArchiveNotify(
                    "ZIP creation currently requires all selected items to be in the current directory.",
                    "warn"
                )
            end
        end

        local default_name
        if #snapshot.files == 1 then
            default_name = (snapshot.files[1].stem ~= "" and snapshot.files[1].stem or snapshot.files[1].name) .. ".zip"
        else
            default_name = "Archive.zip"
        end

        local requested, event = ya.input {
            pos = { "center", w = 52 },
            title = "Compress to ZIP:",
            value = default_name,
        }
        if event ~= 1 or not requested then
            return
        end

        requested = requested:match("^%s*(.-)%s*$") or ""
        if requested == "" then
            return WgdotYaziArchiveNotify("Archive name cannot be empty.", "warn")
        elseif requested == "." or requested == ".."
            or requested:find("[/\\]")
            or requested:find(":", 1, true)
        then
            return WgdotYaziArchiveNotify("Enter a file name, not a path.", "warn")
        end

        local target = WgdotYaziUniqueZip(snapshot.cwd, requested)
        local args = { "a", "-tzip", tostring(target), "--" }
        for _, file in ipairs(snapshot.files) do
            args[#args + 1] = file.name
        end

        local output, err = WgdotYaziRun7z(args, snapshot.cwd)
        if not output then
            return WgdotYaziArchiveNotify(
                "7-Zip is unavailable. Install 7-Zip/7zip to use ZIP actions.",
                "error"
            )
        elseif not output.status.success then
            local detail = output.stderr ~= "" and output.stderr or tostring(err or "7-Zip failed")
            return WgdotYaziArchiveNotify(detail, "error")
        end

        WgdotYaziArchiveNotify("Created " .. tostring(target.name or target), "info")
        ya.emit("reveal", { target })
    end)
end

local function WgdotYaziSingleZipSnapshot()
    local snapshot = WgdotYaziArchiveSnapshot()
    if #snapshot.files ~= 1 or snapshot.files[1].name:lower():sub(-4) ~= ".zip" then
        return nil
    end
    return snapshot
end

function WgdotYaziExtractZipHere()
    ya.async(function()
        local snapshot = WgdotYaziSingleZipSnapshot()
        if not snapshot then
            return WgdotYaziArchiveNotify("Select one .zip file to extract.", "warn")
        end

        local zip = snapshot.files[1]
        local output = WgdotYaziRun7z(
            { "x", "-y", "-aou", zip.path, "-o" .. snapshot.cwd },
            snapshot.cwd
        )
        if not output then
            return WgdotYaziArchiveNotify(
                "7-Zip is unavailable. Install 7-Zip/7zip to use ZIP actions.",
                "error"
            )
        elseif not output.status.success then
            return WgdotYaziArchiveNotify(output.stderr ~= "" and output.stderr or "Extraction failed.", "error")
        end

        WgdotYaziArchiveNotify("Extracted into current directory.", "info")
        ya.emit("refresh", {})
    end)
end

function WgdotYaziExtractZipFolder()
    ya.async(function()
        local snapshot = WgdotYaziSingleZipSnapshot()
        if not snapshot then
            return WgdotYaziArchiveNotify("Select one .zip file to extract.", "warn")
        end

        local zip = snapshot.files[1]
        local base = zip.stem ~= "" and zip.stem or "Extracted"
        local index = 1
        local target

        while true do
            local name = index == 1 and base or string.format("%s (%d)", base, index)
            local candidate = Url(snapshot.cwd):join(name)
            if not fs.cha(candidate) then
                target = candidate
                break
            end
            index = index + 1
        end

        local ok, mkdir_err = fs.create("dir", target)
        if not ok then
            return WgdotYaziArchiveNotify("Could not create extraction folder: " .. tostring(mkdir_err), "error")
        end

        local output = WgdotYaziRun7z(
            { "x", "-y", zip.path, "-o" .. tostring(target) },
            snapshot.cwd
        )
        if not output then
            return WgdotYaziArchiveNotify(
                "7-Zip is unavailable. Install 7-Zip/7zip to use ZIP actions.",
                "error"
            )
        elseif not output.status.success then
            return WgdotYaziArchiveNotify(output.stderr ~= "" and output.stderr or "Extraction failed.", "error")
        end

        WgdotYaziArchiveNotify("Extracted to " .. tostring(target.name or target), "info")
        ya.emit("refresh", {})
        ya.emit("reveal", { target })
    end)
end

local WgdotYaziItemActions = {
    { label = "Open / Enter", shortcut = "Enter", action = "smart_open" },
    { label = "Open with...", shortcut = "O", action = "open_with" },
    { label = "Rename", shortcut = "r", action = "rename" },
    { label = "Copy", shortcut = "Ctrl+C / y", action = "copy" },
    { label = "Cut", shortcut = "Ctrl+X / Y", action = "cut" },
    { label = "Copy path", shortcut = "cc", action = "copy_path" },
    { label = "Compress to ZIP...", shortcut = "c z", action = "compress_zip" },
    { label = "Details", shortcut = "Tab", action = "details" },
    { label = "Trash", shortcut = "dd", action = "trash" },
}

local WgdotYaziFolderActions = {
    { label = "New file", shortcut = "a", action = "new_file" },
    { label = "New folder", shortcut = "a /", action = "new_folder" },
    { label = "Paste", shortcut = "Ctrl+V / p", action = "paste" },
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
    _hovered_row = nil,
    _selection_count = 0,
}

function WgdotYaziContextMenu:show(kind, x, y, selection_count)
    self._kind = kind
    self._x = x
    self._y = y
    self._selection_count = selection_count or 0
    self._hovered_row = nil
    self._visible = true
    ui.render()
end

function WgdotYaziContextMenu:hide()
    if not self._visible then
        return
    end

    self._visible = false
    self._hovered_row = nil
    ui.render()
end

function WgdotYaziContextMenu:title()
    if self._kind == "background" then
        return " Folder actions "
    elseif self._selection_count > 1 then
        return " " .. tostring(self._selection_count) .. " selected "
    end

    return " Item actions "
end

function WgdotYaziContextMenu:actions()
    if self._kind == "background" then
        return WgdotYaziFolderActions
    end

    local actions = {}
    for _, action in ipairs(WgdotYaziItemActions) do
        actions[#actions + 1] = action
    end

    local hovered = cx.active.current.hovered
    if self._selection_count <= 1
        and hovered
        and hovered.name:lower():sub(-4) == ".zip"
    then
        actions[#actions + 1] = { label = "Extract here", shortcut = "e h", action = "extract_here" }
        actions[#actions + 1] = { label = "Extract to folder", shortcut = "e f", action = "extract_folder" }
    end

    return actions
end

function WgdotYaziContextMenu:footer()
    if self._kind == "background" then
        return {
            "Keys: a create | Ctrl+V/p paste | t e terminal",
            "Right-click items for file and archive actions",
        }
    end

    return {
        "Keys: Enter open | r rename | Ctrl+C/X copy/cut | c z ZIP",
        "More: cc path | Tab info | dd trash | e h/e f extract ZIP",
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
    for i, action in ipairs(self:actions()) do
        local gap = math.max(1, content_width - #action.label - #action.shortcut - 2)
        local row = ui.Line {
            ui.Span(" " .. action.label):style(th.help.action),
            ui.Span(string.rep(" ", gap)),
            ui.Span(action.shortcut):style(th.help.chord),
            ui.Span(" "),
        }
        if i == self._hovered_row then
            row:style(th.help.hovered)
        end
        rows[#rows + 1] = row
    end

    local footer = self:footer()
    return {
        ui.Clear(self._area),
        ui.Border(ui.Edge.ALL)
            :area(self._area)
            :type(ui.Border.ROUNDED)
            :style(th.help.border)
            :title(ui.Line(self:title()):align(ui.Align.CENTER)),
        ui.List(rows):area(self._list_area),
        ui.Text({
            ui.Line(" " .. footer[1]):style(ui.Style():dim()),
            ui.Line(" " .. footer[2]):style(ui.Style():dim()),
        }):area(self._footer_area),
    }
end

function WgdotYaziContextMenu:run(action)
    local count = self._selection_count > 0 and self._selection_count or 1
    self._visible = false
    self._hovered_row = nil
    ui.render()

    if action == "smart_open" then
        WgdotYaziSmartEnter()
    elseif action == "open_with" then
        ya.emit("open", { interactive = true, hovered = true })
    elseif action == "rename" then
        ya.emit("rename", { hovered = true })
    elseif action == "copy" then
        ya.emit("yank", {})
        ya.notify { title = "Yazi", content = "Copied " .. tostring(count) .. " item(s)", timeout = 2 }
    elseif action == "cut" then
        ya.emit("yank", { cut = true })
        ya.notify { title = "Yazi", content = "Cut " .. tostring(count) .. " item(s)", timeout = 2 }
    elseif action == "copy_path" then
        ya.emit("copy", { "path", hovered = true })
        ya.notify { title = "Clipboard", content = "Path copied", timeout = 2 }
    elseif action == "compress_zip" then
        WgdotYaziCompressSelection()
    elseif action == "extract_here" then
        WgdotYaziExtractZipHere()
    elseif action == "extract_folder" then
        WgdotYaziExtractZipFolder()
    elseif action == "details" then
        ya.emit("spot", {})
    elseif action == "trash" then
        ya.emit("remove", {})
    elseif action == "new_file" then
        ya.emit("create", { dir = false })
    elseif action == "new_folder" then
        ya.emit("create", { dir = true })
    elseif action == "paste" then
        local yanked = #cx.yanked
        ya.emit("paste", {})
        if yanked > 0 then
            ya.notify { title = "Yazi", content = "Pasting " .. tostring(yanked) .. " item(s)...", timeout = 2 }
        end
    elseif action == "terminal" then
        ya.emit("shell", { "wt.exe -w new new-tab -d .", orphan = true })
    end
end

function WgdotYaziContextMenu:move(event)
    local row = nil
    if event.x >= self._list_area.x
        and event.x < self._list_area.x + self._list_area.w
        and event.y >= self._list_area.y
        and event.y < self._list_area.y + self._list_area.h
    then
        local candidate = event.y - self._list_area.y + 1
        if self:actions()[candidate] then
            row = candidate
        end
    end

    if row ~= self._hovered_row then
        self._hovered_row = row
        ui.render()
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

local WgdotYaziDefaultRootMove = Root.move

function Root:move(event)
    if WgdotYaziContextMenu._visible then
        return WgdotYaziContextMenu:move(event)
    end
    return WgdotYaziDefaultRootMove(self, event)
end

function Header:click(event, up)
    if up or (not event.is_left and not event.is_right) then
        return
    end

    local path_width = math.max(0, self._area.w - (self._right_width or 0))
    if event.x >= self._area.x + path_width then
        return
    end

    local cwd = ya.readable_path(tostring(self._current.cwd))
    ya.emit("copy", { "dirpath" })
    ya.notify {
        title = "Clipboard",
        content = "Copied to clipboard: " .. cwd,
        timeout = 2,
    }
end

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
    elseif not event.is_left and not event.is_right and not event.is_middle then
        return
    end

    if event.is_middle then
        WgdotYaziContextMenu:hide()
        if self._file.cha.is_dir then
            ya.emit("tab_create", { tostring(self._file.url) })
        end
        return
    end

    local was_hovered = self._file.is_hovered
    local was_selected = self._file:is_selected()
    local selected_count = #cx.active.selected

    if event.is_right and not was_selected then
        ya.emit("toggle_all", { state = "off" })
        selected_count = 1
    elseif event.is_right then
        selected_count = math.max(1, selected_count)
    end

    ya.emit("reveal", { self._file.url })

    if event.is_right then
        WgdotYaziContextMenu:show("item", event.x, event.y, selected_count)
    elseif was_hovered then
        WgdotYaziContextMenu:hide()
        if self._file.cha.is_dir then
            ya.emit("enter", {})
        else
            ya.emit("open", { hovered = true })
        end
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
