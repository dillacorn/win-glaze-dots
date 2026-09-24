-- github.com/dillacorn/win-glaze-dots
-- %APPDATA%\yazi\config\init.lua

require("recent-files"):setup()
require("bookmarks"):setup()
require("git"):setup { order = 1500 }

local function WgdotYaziIsCollectionUrl(value)
    local url = tostring(value or "")
    return url:match("^wgdot%-bookmarks://") ~= nil
        or url:match("^wgdot%-recents://") ~= nil
end

local function WgdotYaziCollectionTarget(file)
    if not file or not WgdotYaziIsCollectionUrl(file.url) or not file.link_to then return nil end
    return tostring(file.link_to), file.cha.is_dir
end

local function WgdotYaziCollectionCwd()
    return WgdotYaziIsCollectionUrl(cx.active.current.cwd)
end

local WgdotYaziDefaultEntityHighlights = Entity.highlights
local WgdotYaziDefaultEntitySymlink = Entity.symlink

function Entity:highlights()
    if WgdotYaziIsCollectionUrl(self._file.url) then
        return ui.printable(tostring(self._file.url.name or ""):gsub("^%d+%-%-", ""))
    end
    return WgdotYaziDefaultEntityHighlights(self)
end

function Entity:symlink()
    if WgdotYaziIsCollectionUrl(self._file.url) then return "" end
    return WgdotYaziDefaultEntitySymlink(self)
end

function Linemode:size_and_mtime()
    if WgdotYaziIsCollectionUrl(self._file.url) then return "" end
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

local function WgdotYaziPluginHex(value)
    return (value:gsub(".", function(char)
        return string.format("%02x", string.byte(char))
    end))
end

local function WgdotYaziPluginArgs(command, values)
    local args = { command }
    for _, value in ipairs(values) do
        args[#args + 1] = "hex:" .. WgdotYaziPluginHex(value)
    end
    return table.concat(args, " ")
end

local function WgdotYaziBookmarkTarget(target, is_dir)
    ya.emit("plugin", {
        "bookmarks",
        WgdotYaziPluginArgs("toggle", { is_dir and "D" or "F", target }),
    })
end

local function WgdotYaziNavigateCollection(file, new_tab)
    local target = WgdotYaziCollectionTarget(file)
    if not target then return false end

    local cha = fs.cha(Url(target), true)
    if not cha then
        ya.notify {
            title = "Yazi",
            content = "Target no longer exists; removing stale collection entry.",
            timeout = 3,
            level = "warn",
        }
        ya.emit("remove", { hovered = true, force = true })
        return true
    end

    local is_dir = cha.is_dir
    local url = Url(target)
    if new_tab then
        if is_dir then
            ya.emit("tab_create", { target, raw = true })
        elseif url.parent then
            ya.emit("tab_create", { tostring(url.parent), raw = true })
            ya.emit("reveal", { url, raw = true })
        end
    elseif is_dir then
        ya.emit("cd", { url, raw = true })
    else
        ya.emit("reveal", { url, raw = true })
    end
    return true
end

local function WgdotYaziOpenFiles(interactive, hovered_only)
    local tab = cx.active
    local recent = {}

    if hovered_only then
        local file = tab.current.hovered
        if file and not file.cha.is_dir then
            recent[1] = tostring(file.url)
        end
    elseif #tab.selected > 0 then
        for _, file in pairs(tab.selected) do
            if not file.cha.is_dir then
                recent[#recent + 1] = tostring(file.url)
            end
        end
    elseif tab.current.hovered and not tab.current.hovered.cha.is_dir then
        recent[1] = tostring(tab.current.hovered.url)
    end

    if #recent > 0 then
        ya.emit("plugin", {
            "recent-files",
            WgdotYaziPluginArgs("record", recent),
        })
    end

    local args = {}
    if interactive then
        args.interactive = true
    end
    if hovered_only then
        args.hovered = true
    end
    ya.emit("open", args)
end

function WgdotYaziOpen(interactive)
    WgdotYaziOpenFiles(interactive == true, false)
end

function WgdotYaziSmartEnter()
    local hovered = cx.active.current.hovered
    if WgdotYaziNavigateCollection(hovered, false) then
        return
    elseif hovered and hovered.cha.is_dir then
        ya.emit("enter", {})
    else
        WgdotYaziOpenFiles(false, false)
    end
end

function WgdotYaziRight()
    local hovered = cx.active.current.hovered
    if not hovered then
        return
    elseif WgdotYaziNavigateCollection(hovered, false) then
        return
    elseif hovered.cha.is_dir then
        ya.emit("enter", {})
    elseif not WgdotYaziPreviewMaximized and rt.mgr.ratio[3] > 0 then
        WgdotYaziTogglePreviewMax()
    end
end

function WgdotYaziLeft()
    if WgdotYaziPreviewMaximized then
        WgdotYaziTogglePreviewMax()
    elseif WgdotYaziCollectionCwd() then
        ya.emit("back", {})
    else
        ya.emit("leave", {})
    end
end

WgdotYaziShiftRangeActive = false

function WgdotYaziShiftArrow(step)
    if cx.active.mode.is_normal then
        ya.emit("visual_mode", {})
    end
    WgdotYaziShiftRangeActive = true
    ya.emit("arrow", { step })
end

function WgdotYaziArrow(step)
    if WgdotYaziShiftRangeActive and not cx.active.mode.is_normal then
        ya.emit("escape", { visual = true })
    end
    WgdotYaziShiftRangeActive = false
    ya.emit("arrow", { step })
end

function WgdotYaziConfirmQuit(no_cwd_file)
    ya.async(function()
        local confirmed = ya.confirm {
            pos = { "center", w = 48, h = 8 },
            title = "Quit Yazi?",
            body = ui.Text {
                ui.Line("Quit this Yazi session?"):align(ui.Align.CENTER),
                ui.Line(""),
                ui.Line("Yes: Y / Enter / Space"):align(ui.Align.CENTER),
                ui.Line("No:  N / Esc"):align(ui.Align.CENTER),
            },
        }

        if confirmed then
            ya.emit("quit", { no_cwd_file = no_cwd_file == true })
        end
    end)
end

function WgdotYaziCloseTab()
    if #cx.tabs > 1 then
        ya.emit("close", {})
    else
        WgdotYaziConfirmQuit(false)
    end
end

function WgdotYaziRemoveMenu()
    ya.async(function()
        local choice = ya.which {
            cands = {
                { on = "y", desc = "Move to trash" },
                { on = "D", desc = "Permanently delete..." },
            },
            silent = false,
        }
        if choice == 1 then
            ya.emit("remove", { force = true })
        elseif choice == 2 then
            ya.emit("remove", { permanently = true })
        end
    end)
end

function WgdotYaziSearchMenu()
    ya.async(function()
        local choice = ya.which {
            cands = {
                { on = "n", desc = "Name search" },
                { on = "c", desc = "Content search" },
            },
            silent = false,
        }

        if choice == 1 then
            ya.emit("search", { via = "fd" })
        elseif choice == 2 then
            ya.emit("search", { via = "rg" })
        end
    end)
end

function WgdotYaziToggleBookmark()
    WgdotYaziBookmarkTarget(tostring(cx.active.current.cwd), true)
end

function WgdotYaziOpenHoveredTab()
    local hovered = cx.active.current.hovered
    if WgdotYaziNavigateCollection(hovered, true) then
        return
    elseif hovered and hovered.cha.is_dir then
        ya.emit("tab_create", { tostring(hovered.url), raw = true })
    end
end

local WgdotYaziInitialRatio = nil
local WgdotYaziPreviewHiddenRestore = nil
local WgdotYaziPreviewMaxRestore = nil
WgdotYaziPreviewMaximized = false

local function WgdotYaziRatio()
    local ratio = rt.mgr.ratio
    if not WgdotYaziInitialRatio then
        WgdotYaziInitialRatio = { ratio[1], ratio[2], ratio[3] }
    end
    return { ratio[1], ratio[2], ratio[3] }
end

local function WgdotYaziApplyRatio(ratio, invalidate_cache)
    rt.mgr.ratio = { ratio[1], ratio[2], ratio[3] }
    ya.emit("app:resize", {})

    local hovered = cx.active.current.hovered
    if invalidate_cache and hovered and not hovered.cha.is_dir then
        ya.emit("plugin", {
            "preview-refit",
            WgdotYaziPluginArgs("refit", { tostring(hovered.url) }),
        })
    else
        ya.emit("peek", { force = true })
    end
end

function WgdotYaziTogglePreview()
    local ratio = WgdotYaziRatio()

    if WgdotYaziPreviewMaximized then
        WgdotYaziPreviewMaximized = false
        ratio = WgdotYaziPreviewMaxRestore or ratio
        WgdotYaziPreviewMaxRestore = nil
        WgdotYaziApplyRatio(ratio)
    end

    ratio = WgdotYaziRatio()
    if ratio[3] > 0 then
        WgdotYaziPreviewHiddenRestore = ratio
        WgdotYaziApplyRatio { ratio[1], ratio[2], 0 }
    else
        local restore = WgdotYaziPreviewHiddenRestore or WgdotYaziInitialRatio
        if restore and restore[3] > 0 then
            WgdotYaziApplyRatio(restore)
        end
        WgdotYaziPreviewHiddenRestore = nil
    end
end

function WgdotYaziTogglePreviewMax()
    local ratio = WgdotYaziRatio()
    if WgdotYaziPreviewMaximized then
        WgdotYaziPreviewMaximized = false
        WgdotYaziApplyRatio(WgdotYaziPreviewMaxRestore or WgdotYaziInitialRatio or ratio)
        WgdotYaziPreviewMaxRestore = nil
        return
    end

    WgdotYaziPreviewMaxRestore = ratio
    WgdotYaziPreviewMaximized = true
    WgdotYaziApplyRatio({ 0, 0, 9999 }, true)
end

function WgdotYaziEscape()
    if WgdotYaziPreviewMaximized then
        WgdotYaziPreviewMaximized = false
        WgdotYaziApplyRatio(
            WgdotYaziPreviewMaxRestore
                or WgdotYaziInitialRatio
                or { 1, 4, 3 }
        )
        WgdotYaziPreviewMaxRestore = nil
        return
    end

    ya.emit("escape", {})
end

WgdotYaziPreviewButton = {
    _id = "wgdot-yazi-preview-button",
}

function WgdotYaziPreviewButton:new(area)
    return setmetatable({ _area = area }, { __index = self })
end

function WgdotYaziPreviewButton:reflow()
    return { self }
end

function WgdotYaziPreviewButton:redraw()
    local label = WgdotYaziPreviewMaximized and " 󰘕 " or " 󰹶 "
    return {
        ui.Text(ui.Line(label):style(ui.Style():reverse()))
            :area(self._area)
            :align(ui.Align.RIGHT),
    }
end

function WgdotYaziPreviewButton:click(event, up)
    if up or not event.is_left then
        return
    end
    WgdotYaziTogglePreviewMax()
end

local WgdotYaziDefaultPreviewNew = Preview.new
local WgdotYaziDefaultPreviewRedraw = Preview.redraw

function Preview:new(area, tab)
    local reserve_control_row = area.w >= 3 and area.h >= 2
    local preview_area = reserve_control_row
        and ui.Rect { x = area.x, y = area.y, w = area.w, h = area.h - 1 }
        or area

    local me = WgdotYaziDefaultPreviewNew(self, preview_area, tab)
    if reserve_control_row then
        me._wgdot_preview_button = WgdotYaziPreviewButton:new(ui.Rect {
            x = area.x + area.w - 3,
            y = area.y + area.h - 1,
            w = 3,
            h = 1,
        })
    end
    return me
end

function Preview:reflow()
    local components = { self }
    if self._wgdot_preview_button then
        components[#components + 1] = self._wgdot_preview_button
    end
    return components
end

function Preview:redraw()
    local elements = WgdotYaziDefaultPreviewRedraw(self) or {}
    if self._wgdot_preview_button then
        elements = ya.list_merge(elements, ui.redraw(self._wgdot_preview_button))
    end
    return elements
end

WgdotYaziPreviewToggleButton = { _id = "wgdot-yazi-preview-toggle-button" }

function WgdotYaziPreviewToggleButton:new(area)
    return setmetatable({ _area = area }, { __index = self })
end

function WgdotYaziPreviewToggleButton:reflow()
    return { self }
end

function WgdotYaziPreviewToggleButton:redraw()
    local visible = WgdotYaziRatio()[3] > 0
    local label = visible and " 󰞔 " or " 󰞓 "
    return {
        ui.Text(ui.Line(label):style(ui.Style():reverse()))
            :area(self._area)
            :align(ui.Align.CENTER),
    }
end

function WgdotYaziPreviewToggleButton:click(event, up)
    if up or not event.is_left then
        return
    end
    WgdotYaziTogglePreview()
end

local WgdotYaziDefaultCurrentNew = Current.new
local WgdotYaziDefaultCurrentRedraw = Current.redraw

function Current:new(area, tab)
    local reserve_control_row = area.w >= 3 and area.h >= 2
    local current_area = reserve_control_row
        and ui.Rect { x = area.x, y = area.y, w = area.w, h = area.h - 1 }
        or area

    local me = WgdotYaziDefaultCurrentNew(self, current_area, tab)
    if reserve_control_row then
        me._wgdot_preview_toggle_button = WgdotYaziPreviewToggleButton:new(ui.Rect {
            x = area.x + area.w - 3,
            y = area.y + area.h - 1,
            w = 3,
            h = 1,
        })
    end
    return me
end

function Current:reflow()
    local components = { self }
    if self._wgdot_preview_toggle_button then
        components[#components + 1] = self._wgdot_preview_toggle_button
    end
    return components
end

function Current:redraw()
    local elements = WgdotYaziDefaultCurrentRedraw(self) or {}
    if self._wgdot_preview_toggle_button then
        elements = ya.list_merge(elements, ui.redraw(self._wgdot_preview_toggle_button))
    end
    return elements
end

local function WgdotYaziArchiveSnapshot()
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
end

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
    local snapshot = WgdotYaziArchiveSnapshot()
    ya.async(function()
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
    local snapshot = WgdotYaziSingleZipSnapshot()
    ya.async(function()
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
    local snapshot = WgdotYaziSingleZipSnapshot()
    ya.async(function()
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

local WgdotYaziFileActions = {
    { label = "Open", shortcut = "Enter", action = "smart_open" },
    { label = "Open with...", shortcut = "O", action = "open_with" },
    { label = "Bookmark / unbookmark", shortcut = "g B", action = "bookmark_hovered" },
    { label = "Rename", shortcut = "r", action = "rename" },
    { label = "Copy", shortcut = "Ctrl+C / y", action = "copy" },
    { label = "Cut", shortcut = "Ctrl+X / Y", action = "cut" },
    { label = "Copy path", shortcut = "cc", action = "copy_path" },
    { label = "Compress to ZIP...", shortcut = "c z", action = "compress_zip" },
    { label = "Details", shortcut = "Tab", action = "details" },
    { label = "Trash", shortcut = "dd", action = "trash" },
}

local WgdotYaziDropActions = {
    { label = "Copy to folder", shortcut = "copy", action = "drop_copy" },
    { label = "Move to folder", shortcut = "move", action = "drop_move" },
}

local WgdotYaziDragState = nil

local function WgdotYaziDragSources(file)
    local sources = {}

    if file:is_selected() and #cx.active.selected > 0 then
        for _, selected in pairs(cx.active.selected) do
            sources[#sources + 1] = {
                path = tostring(selected.path),
                name = selected.name,
                is_dir = selected.cha.is_dir,
            }
        end
    else
        sources[1] = {
            path = tostring(file.path),
            name = file.name,
            is_dir = file.cha.is_dir,
        }
    end

    return sources
end

local function WgdotYaziCanDropInto(target, sources)
    local target_url = Url(target)
    for _, source in ipairs(sources) do
        if source.is_dir and target_url:starts_with(Url(source.path)) then
            return false
        end
    end
    return true
end

local function WgdotYaziDropInto(op, target, sources)
    if not target or not sources or #sources == 0 then
        return
    end

    ya.async(function()
        for _, source in ipairs(sources) do
            local from = Url(source.path)
            local to = Url(target):join(source.name)
            ya.task(op, { from = from, to = to }):spawn()
        end
    end)

    ya.notify {
        title = "Yazi",
        content = string.format(
            "%s %d item(s) to %s",
            op == "move" and "Moving" or "Copying",
            (#sources),
            tostring(Url(target).name or target)
        ),
        timeout = 2,
    }
end

local function WgdotYaziStartOutboundDrag(sources)
    local local_app_data = os.getenv("LOCALAPPDATA")
    local temp_dir = os.getenv("TEMP")
    if not local_app_data or local_app_data == "" or not temp_dir or temp_dir == "" then
        return
    end

    local helper = local_app_data .. "\\wgdot\\bin\\wgdotw.exe"
    local probe = io.open(helper, "rb")
    if not probe then
        return
    end
    probe:close()

    local list_path = string.format(
        "%s\\wgdot-yazi-drag-%d-%d.txt",
        temp_dir,
        os.time(),
        math.floor(os.clock() * 1000000)
    )
    local list = io.open(list_path, "wb")
    if not list then
        return
    end
    for _, source in ipairs(sources) do
        list:write(source.path, "\n")
    end
    list:close()

    ya.async(function()
        local status, err = Command(helper):arg({ "yazi-drag", list_path }):status()
        if err or (status and not status.success) then
            os.remove(list_path)
            ya.notify {
                title = "Yazi drag",
                content = "Native Windows drag is unavailable; Yazi itself remains usable.",
                timeout = 4,
                level = "warn",
            }
        end
    end)
end

local WgdotYaziFolderActions = {
    { label = "New file", shortcut = "a", action = "new_file" },
    { label = "New folder", shortcut = "a /", action = "new_folder" },
    { label = "Paste", shortcut = "Ctrl+V / p", action = "paste" },
    { label = "Terminal here", shortcut = "t e", action = "terminal" },
    { label = "Bookmark / unbookmark folder", shortcut = "g B", action = "bookmark_current" },
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
    _drop_target = nil,
    _drop_sources = nil,
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

function WgdotYaziContextMenu:show_drop(target, sources, x, y)
    self._drop_target = tostring(target)
    self._drop_sources = sources
    self:show("drop", x, y, #sources)
end

function WgdotYaziContextMenu:hide()
    if not self._visible then
        return
    end

    self._visible = false
    self._hovered_row = nil
    self._drop_target = nil
    self._drop_sources = nil
    ui.render()
end

function WgdotYaziContextMenu:title()
    if self._kind == "background" then
        return " Folder actions "
    elseif self._kind == "drop" then
        local target = self._drop_target and Url(self._drop_target) or nil
        return " Drop into " .. tostring(target and target.name or "folder") .. " "
    elseif self._selection_count > 1 then
        return " " .. tostring(self._selection_count) .. " selected "
    end

    return " Item actions "
end

function WgdotYaziContextMenu:actions()
    if self._kind == "background" then
        return WgdotYaziFolderActions
    elseif self._kind == "drop" then
        return WgdotYaziDropActions
    end

    local hovered = cx.active.current.hovered
    if self._selection_count > 1 then
        return {
            {
                label = "Rename " .. tostring(self._selection_count) .. " items...",
                shortcut = "r",
                action = "bulk_rename",
            },
            { label = "Copy", shortcut = "Ctrl+C / y", action = "copy" },
            { label = "Cut", shortcut = "Ctrl+X / Y", action = "cut" },
            { label = "Compress to ZIP...", shortcut = "c z", action = "compress_zip" },
            { label = "Trash " .. tostring(self._selection_count) .. " items", shortcut = "dd", action = "trash" },
        }
    end

    if hovered and hovered.cha.is_dir then
        local bookmarked = require("bookmarks"):is_bookmarked(tostring(hovered.url))
        return {
            { label = "Enter folder", shortcut = "Enter / l", action = "smart_open" },
            { label = "Open in new tab", shortcut = "t n", action = "open_new_tab" },
            {
                label = bookmarked and "Remove bookmark" or "Add bookmark",
                shortcut = "g B",
                action = "bookmark_hovered",
            },
            { label = "Rename", shortcut = "r", action = "rename" },
            { label = "Copy", shortcut = "Ctrl+C / y", action = "copy" },
            { label = "Cut", shortcut = "Ctrl+X / Y", action = "cut" },
            { label = "Copy path", shortcut = "cc", action = "copy_path" },
            { label = "Compress to ZIP...", shortcut = "c z", action = "compress_zip" },
            { label = "Details", shortcut = "Tab", action = "details" },
            { label = "Trash", shortcut = "dd", action = "trash" },
        }
    end

    local actions = {}
    for _, action in ipairs(WgdotYaziFileActions) do
        actions[#actions + 1] = action
    end

    if hovered and hovered.name:lower():sub(-4) == ".zip" then
        actions[#actions + 1] = { label = "Extract here", shortcut = "e h", action = "extract_here" }
        actions[#actions + 1] = { label = "Extract to folder", shortcut = "e f", action = "extract_folder" }
    end

    return actions
end

function WgdotYaziContextMenu:footer()
    if self._kind == "background" then
        return {
            "Keys: a create | Ctrl+V/p paste | t e terminal | g B bookmark",
            "Navigate: g b bookmarks | g m drives | Ctrl+F recursive search",
        }
    elseif self._kind == "drop" then
        return {
            "Release chose this folder as the destination",
            "Choose Copy or Move; click elsewhere to cancel",
        }
    elseif self._selection_count > 1 then
        return {
            "Keys: r bulk rename | Ctrl+C/X copy/cut | c z ZIP",
            "Delete: dd trash | Shift+D permanent delete",
        }
    end

    local hovered = cx.active.current.hovered
    if hovered and hovered.cha.is_dir then
        return {
            "Keys: Enter open | t n new tab | g B bookmark | r rename",
            "More: Ctrl+C/X copy/cut | cc path | Tab info | c z ZIP | dd trash",
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
            :type(ui.Border.PLAIN)
            :style(th.help.border)
            :title(ui.Line(self:title()):align(ui.Align.CENTER)),
        ui.List(rows):area(self._list_area),
        ui.Text({
            ui.Line(" " .. footer[1]),
            ui.Line(" " .. footer[2]),
        }):area(self._footer_area),
    }
end

function WgdotYaziContextMenu:run(action)
    local count = self._selection_count > 0 and self._selection_count or 1
    local drop_target = self._drop_target
    local drop_sources = self._drop_sources
    self._visible = false
    self._hovered_row = nil
    self._drop_target = nil
    self._drop_sources = nil
    ui.render()

    if action == "smart_open" then
        WgdotYaziSmartEnter()
    elseif action == "open_new_tab" then
        WgdotYaziOpenHoveredTab()
    elseif action == "open_with" then
        WgdotYaziOpenFiles(true, true)
    elseif action == "rename" then
        ya.emit("rename", { hovered = true })
    elseif action == "bulk_rename" then
        ya.emit("rename", {})
    elseif action == "bookmark_hovered" then
        local hovered = cx.active.current.hovered
        if hovered then
            WgdotYaziBookmarkTarget(tostring(hovered.url), hovered.cha.is_dir)
        end
    elseif action == "bookmark_current" then
        WgdotYaziBookmarkTarget(tostring(cx.active.current.cwd), true)
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
    elseif action == "drop_copy" then
        WgdotYaziDropInto("copy", drop_target, drop_sources)
    elseif action == "drop_move" then
        WgdotYaziDropInto("move", drop_target, drop_sources)
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

local WgdotYaziDefaultHeaderCwd = Header.cwd
local WgdotYaziBreadcrumbTarget = nil

local function WgdotYaziPathIsAncestor(base, target)
    local lhs = base:gsub("\\", "/"):lower()
    local rhs = target:gsub("\\", "/"):lower()
    if lhs == rhs then
        return true
    end
    if lhs:sub(-1) == "/" then
        return rhs:sub(1, #lhs) == lhs
    end
    return rhs:sub(1, #lhs + 1) == lhs .. "/"
end

local function WgdotYaziBreadcrumbSegments(path)
    local normalized = path:gsub("\\", "/")
    local drive, rest = normalized:match("^([A-Za-z]:)/(.*)$")
    if not drive then
        return nil
    end

    local segments = {
        { text = drive .. "/", target = drive .. "\\" },
    }
    local current = drive .. "\\"

    for part in rest:gmatch("[^/]+") do
        if current:sub(-1) == "\\" then
            current = current .. part
        else
            current = current .. "\\" .. part
        end
        segments[#segments + 1] = {
            text = "/" .. part,
            target = current,
        }
    end

    return segments
end

ps.sub("cd", function()
    if not WgdotYaziBreadcrumbTarget then
        return
    end

    local cwd = tostring(cx.active.current.cwd)
    if cwd:lower() == WgdotYaziBreadcrumbTarget:lower()
        or not WgdotYaziPathIsAncestor(cwd, WgdotYaziBreadcrumbTarget)
    then
        WgdotYaziBreadcrumbTarget = nil
    end
end)

function Header:cwd()
    local max = self._area.w - self._right_width
    local cwd = tostring(self._current.cwd)
    local flags = self:flags()

    self._wgdot_breadcrumbs = {}
    if max <= 0 or flags ~= "" then
        return WgdotYaziDefaultHeaderCwd(self)
    end

    local segments = WgdotYaziBreadcrumbSegments(cwd)
    if not segments then
        return WgdotYaziDefaultHeaderCwd(self)
    end

    if WgdotYaziBreadcrumbTarget
        and cwd:lower() ~= WgdotYaziBreadcrumbTarget:lower()
        and WgdotYaziPathIsAncestor(cwd, WgdotYaziBreadcrumbTarget)
    then
        for _, segment in ipairs(WgdotYaziBreadcrumbSegments(WgdotYaziBreadcrumbTarget) or {}) do
            if segment.target:lower() ~= cwd:lower()
                and WgdotYaziPathIsAncestor(cwd, segment.target)
            then
                segment.forward = true
                segments[#segments + 1] = segment
            end
        end
    end

    local total = 0
    for _, segment in ipairs(segments) do
        total = total + ui.Line(segment.text):width()
    end

    local clipped = false
    while total > max and #segments > 1 do
        total = total - ui.Line(segments[1].text):width()
        table.remove(segments, 1)
        clipped = true
    end
    if clipped then total = total + 1 end
    if total > max then return WgdotYaziDefaultHeaderCwd(self) end

    local spans = {}
    local x = self._area.x
    if clipped then
        spans[#spans + 1] = ui.Span("…"):style(ui.Style():dim())
        x = x + 1
    end

    for _, segment in ipairs(segments) do
        local width = ui.Line(segment.text):width()
        local style = segment.forward and ui.Style():dim() or th.mgr.cwd
        spans[#spans + 1] = ui.Span(segment.text):style(style)
        self._wgdot_breadcrumbs[#self._wgdot_breadcrumbs + 1] = {
            x1 = x,
            x2 = x + width - 1,
            target = segment.target,
            forward = segment.forward == true,
        }
        x = x + width
    end

    return ui.Line(spans)
end

function Header:click(event, up)
    if up or (not event.is_left and not event.is_right) then
        return
    end

    local path_width = math.max(0, self._area.w - (self._right_width or 0))
    if event.x >= self._area.x + path_width then
        return
    end

    if event.is_right then
        local cwd = ya.readable_path(tostring(self._current.cwd))
        ya.emit("copy", { "dirpath" })
        ya.notify {
            title = "Clipboard",
            content = "Copied to clipboard: " .. cwd,
            timeout = 2,
        }
        return
    end

    local cwd = tostring(self._current.cwd)
    local segments = WgdotYaziBreadcrumbSegments(cwd) or {}
    if WgdotYaziBreadcrumbTarget
        and cwd:lower() ~= WgdotYaziBreadcrumbTarget:lower()
        and WgdotYaziPathIsAncestor(cwd, WgdotYaziBreadcrumbTarget)
    then
        for _, segment in ipairs(WgdotYaziBreadcrumbSegments(WgdotYaziBreadcrumbTarget) or {}) do
            if segment.target:lower() ~= cwd:lower()
                and WgdotYaziPathIsAncestor(cwd, segment.target)
            then
                segment.forward = true
                segments[#segments + 1] = segment
            end
        end
    end

    local total = 0
    for _, segment in ipairs(segments) do
        total = total + ui.Line(segment.text):width()
    end
    local clipped = false
    while total > path_width and #segments > 1 do
        total = total - ui.Line(segments[1].text):width()
        table.remove(segments, 1)
        clipped = true
    end

    local x = self._area.x + (clipped and 1 or 0)
    for _, segment in ipairs(segments) do
        local width = ui.Line(segment.text):width()
        if event.x >= x and event.x < x + width
            and segment.target:lower() ~= cwd:lower()
        then
            if not segment.forward and WgdotYaziPathIsAncestor(segment.target, cwd) then
                WgdotYaziBreadcrumbTarget = WgdotYaziBreadcrumbTarget or cwd
            end
            ya.emit("cd", { Url(segment.target), raw = true })
            return
        end
        x = x + width
    end
end

local WgdotYaziPendingClick = nil
local WgdotYaziDefaultCurrentDrag = Current.drag

function Current:click(event, up)
    local row = event.y - self._area.y + 1
    local file = self._folder.window[row]

    if file then
        return Entity:new(file):click(event, up)
    end

    if not up and event.is_right then
        WgdotYaziPendingClick = nil
        WgdotYaziContextMenu:show("background", event.x, event.y)
    elseif event.is_left then
        WgdotYaziPendingClick = nil
        if up then
            WgdotYaziDragState = nil
        else
            WgdotYaziContextMenu:hide()
        end
    end
end

function Current:drag(event)
    WgdotYaziPendingClick = nil

    if not WgdotYaziDragState then
        local source = self._folder.hovered
        if source then
            local sources = WgdotYaziDragSources(source)
            if #sources > 0 then
                if not source:is_selected() then
                    ya.emit("toggle_all", { state = "off" })
                    ya.emit("reveal", { source.url })
                end

                WgdotYaziContextMenu:hide()
                WgdotYaziDragState = { sources = sources }
                WgdotYaziStartOutboundDrag(sources)
            end
        end
    end

    return WgdotYaziDefaultCurrentDrag(self, event)
end

function Entity:click(event, up)
    if up then
        if event.is_left and WgdotYaziDragState then
            local drag = WgdotYaziDragState
            WgdotYaziDragState = nil
            WgdotYaziPendingClick = nil

            if self._file.cha.is_dir
                and WgdotYaziCanDropInto(tostring(self._file.url), drag.sources)
            then
                WgdotYaziContextMenu:show_drop(
                    self._file.url,
                    drag.sources,
                    event.x,
                    event.y
                )
            end
            return
        end

        if event.is_left and WgdotYaziPendingClick then
            local pending = WgdotYaziPendingClick
            WgdotYaziPendingClick = nil

            if pending.path == tostring(self._file.url) and pending.was_hovered then
                WgdotYaziContextMenu:hide()
                if WgdotYaziNavigateCollection(self._file, false) then
                    return
                elseif self._file.cha.is_dir then
                    ya.emit("enter", {})
                else
                    WgdotYaziOpenFiles(false, true)
                end
            end
        end
        return
    elseif not event.is_left and not event.is_right and not event.is_middle then
        return
    end

    if event.is_middle then
        WgdotYaziPendingClick = nil
        WgdotYaziContextMenu:hide()
        if WgdotYaziNavigateCollection(self._file, true) then
            return
        elseif self._file.cha.is_dir then
            ya.emit("tab_create", { tostring(self._file.url), raw = true })
        end
        return
    end

    local was_hovered = self._file.is_hovered
    local was_selected = self._file:is_selected()
    local selected_count = #cx.active.selected

    if event.is_right then
        WgdotYaziPendingClick = nil
        if not was_selected then
            ya.emit("toggle_all", { state = "off" })
            selected_count = 1
        else
            selected_count = math.max(1, selected_count)
        end

        ya.emit("reveal", { self._file.url })
        WgdotYaziContextMenu:show("item", event.x, event.y, selected_count)
        return
    end

    WgdotYaziContextMenu:hide()
    WgdotYaziPendingClick = {
        path = tostring(self._file.url),
        was_hovered = was_hovered,
    }
    ya.emit("reveal", { self._file.url })
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
    ui.render()
end

function Status:selected_count()
    local count = #cx.active.selected
    if count < 2 then
        return ""
    end

    return string.format(" %d selected ", count)
end

function Status:task_summary()
    local summary = cx.tasks.summary
    if summary.total == 0 then
        return ""
    end

    local active = math.max(0, summary.total - summary.success)
    if summary.failed > 0 then
        return ui.Span(
            string.format(" %d tasks · %d failed ", active, summary.failed)
        ):style(th.status.progress_error)
    end

    return ui.Span(
        string.format(" %d task%s ", active, active == 1 and "" or "s")
    ):style(th.status.progress_label)
end

local WgdotYaziDefaultStatusClick = Status.click

function Status:click(event, up)
    if not up and event.is_left and cx.tasks.summary.total > 0 then
        ya.emit("tasks:show", {})
        return
    end
    return WgdotYaziDefaultStatusClick(self, event, up)
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
    return self:selected_count()
end, 450, Status.RIGHT)

Status:children_add(function(self)
    return self:task_summary()
end, 400, Status.RIGHT)

Status:children_add(function(self)
    return self:modified_time()
end, 500, Status.RIGHT)
