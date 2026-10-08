-- github.com/dillacorn/win-glaze-dots
-- %APPDATA%\yazi\config\init.lua

require("recent-files"):setup()
require("bookmarks"):setup()
require("git"):setup { order = 1500 }

local function WgdotYaziNormalizeFsPath(value)
    local path = tostring(value or ""):gsub("\\", "/"):gsub("/+$", "")
    return path:lower()
end

local function WgdotYaziStateDir()
    local root = os.getenv("APPDATA") or os.getenv("LOCALAPPDATA") or "."
    return root .. "\\yazi\\state"
end

local WgdotYaziCollectionRoots = {
    bookmarks = WgdotYaziNormalizeFsPath(WgdotYaziStateDir() .. "\\collections\\Bookmarks"),
    recents = WgdotYaziNormalizeFsPath(WgdotYaziStateDir() .. "\\collections\\Recently Opened"),
}

local function WgdotYaziCollectionKind(value)
    local path = WgdotYaziNormalizeFsPath(value)
    if path == WgdotYaziCollectionRoots.bookmarks then return "bookmarks" end
    if path == WgdotYaziCollectionRoots.recents then return "recents" end
    return nil
end

local function WgdotYaziIsCollectionItemUrl(value)
    local path = WgdotYaziNormalizeFsPath(value)
    for _, root in pairs(WgdotYaziCollectionRoots) do
        local prefix = root .. "/"
        if path:sub(1, #prefix) == prefix then
            local rest = path:sub(#prefix + 1)
            return rest ~= "" and rest:find("/", 1, true) == nil
        end
    end
    return false
end

local function WgdotYaziCollectionCwd()
    return WgdotYaziCollectionKind(cx.active.current.cwd)
end

local WgdotYaziCollectionReturns = {}

local function WgdotYaziCollectionReturnState()
    local tab_key = tostring(cx.active.id)
    local state = WgdotYaziCollectionReturns[tab_key]
    if not state then
        state = {}
        WgdotYaziCollectionReturns[tab_key] = state
    end
    return state
end

local function WgdotYaziOpenCollection(kind)
    local plugin = kind == "bookmarks" and "bookmarks" or "recent-files"
    local state = WgdotYaziCollectionReturnState()

    if WgdotYaziCollectionCwd() ~= kind then
        state[kind] = tostring(cx.active.current.cwd)
    end

    ya.emit("plugin", { plugin })
end

local function WgdotYaziToggleCollection(kind)
    local state = WgdotYaziCollectionReturnState()

    if WgdotYaziCollectionCwd() == kind then
        local target = state[kind]
        state[kind] = nil
        if target and target ~= "" then
            ya.emit("cd", { Url(target), raw = true })
        else
            ya.emit("back", {})
        end
        return
    end

    WgdotYaziOpenCollection(kind)
end

function WgdotYaziGoBookmarks()
    WgdotYaziOpenCollection("bookmarks")
end

function WgdotYaziToggleBookmarks()
    WgdotYaziToggleCollection("bookmarks")
end

function WgdotYaziGoRecents()
    WgdotYaziOpenCollection("recents")
end

function WgdotYaziToggleRecents()
    WgdotYaziToggleCollection("recents")
end

local WgdotYaziDefaultEntityHighlights = Entity.highlights
local WgdotYaziDefaultEntitySymlink = Entity.symlink

function Entity:highlights()
    if WgdotYaziIsCollectionItemUrl(self._file.url) then
        return ui.printable(tostring(self._file.url.name or ""):gsub("^%d+%-%-", ""))
    end
    return WgdotYaziDefaultEntityHighlights(self)
end

function Entity:symlink()
    if WgdotYaziIsCollectionItemUrl(self._file.url) then return "" end
    return WgdotYaziDefaultEntitySymlink(self)
end

function Linemode:size_and_mtime()
    if WgdotYaziIsCollectionItemUrl(self._file.url) then return "" end
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
    local kind = WgdotYaziCollectionCwd()
    if not kind or not file or not WgdotYaziIsCollectionItemUrl(file.url) then return false end

    local plugin = kind == "bookmarks" and "bookmarks" or "recent-files"
    ya.emit("plugin", {
        plugin,
        WgdotYaziPluginArgs("activate", { tostring(file.url), new_tab and "1" or "0" }),
    })
    return true
end

local function WgdotYaziCollectionSelection()
    local kind = WgdotYaziCollectionCwd()
    if not kind then return nil, {} end

    local tab = cx.active
    local markers = {}
    if #tab.selected > 0 then
        for _, file in pairs(tab.selected) do
            if WgdotYaziIsCollectionItemUrl(file.url) then
                markers[#markers + 1] = tostring(file.url)
            end
        end
    elseif tab.current.hovered and WgdotYaziIsCollectionItemUrl(tab.current.hovered.url) then
        markers[1] = tostring(tab.current.hovered.url)
    end
    return kind, markers
end

local function WgdotYaziDeleteCollectionSelection()
    local kind, markers = WgdotYaziCollectionSelection()
    if not kind or #markers == 0 then return false end

    local plugin = kind == "bookmarks" and "bookmarks" or "recent-files"
    ya.emit("plugin", {
        plugin,
        WgdotYaziPluginArgs("delete", markers),
    })
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
    if WgdotYaziDeleteMenu and WgdotYaziDeleteMenu._visible then
        WgdotYaziDeleteMenu:submit()
        return
    end
    if WgdotYaziContextMenu and WgdotYaziContextMenu._visible
        and WgdotYaziContextMenu._kind == "drop"
    then
        WgdotYaziContextMenu:choose()
        return
    end

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

-- Shift+Up/Down previews a contiguous range without selecting anything.
-- Space commits it through Yazi's native visual-selection engine; Esc cancels.
-- Shift+Up/Down is a reversible preview; only Space commits selection.
-- Use the documented tab index and ipairs(fs::Files), not an undocumented
-- tab id or guessed indices into Yazi's file-list userdata.
local WgdotYaziRangePreview = nil

local function WgdotYaziRangeValid()
    local range = WgdotYaziRangePreview
    if not range then return false end

    local folder = cx.active.current
    return cx.active.mode.is_normal
        and range.tab == cx.tabs.idx
        and range.cwd == tostring(folder.cwd)
        and range.count == #folder.files
end

local function WgdotYaziRangeDiscard()
    if not WgdotYaziRangePreview then return false end
    WgdotYaziRangePreview = nil
    ui.render()
    return true
end

-- Yazi's file list is a Lua userdata supporting ipairs. Materialize the
-- ordered URLs once per Shift keypress so all indices are Lua 1-based.
local function WgdotYaziRangeFiles(folder)
    local files = {}
    for _, file in ipairs(folder.files) do
        files[#files + 1] = tostring(file.url)
    end
    return files
end

local function WgdotYaziRangeFind(files, url)
    for i, path in ipairs(files) do
        if path == url then return i end
    end
    return nil
end

local function WgdotYaziRangeRebuild(range, files)
    range.paths = {}
    for i = math.min(range.anchor, range.last), math.max(range.anchor, range.last) do
        range.paths[files[i]] = true
    end
end

function WgdotYaziShiftArrow(step)
    if not cx.active.mode.is_normal then
        ya.emit("arrow", { step })
        return
    end

    local folder = cx.active.current
    local hovered = folder.hovered
    if not hovered or #folder.files == 0 then
        WgdotYaziRangeDiscard()
        return
    end

    local files = WgdotYaziRangeFiles(folder)
    local hovered_url = tostring(hovered.url)
    local current = WgdotYaziRangeFind(files, hovered_url)
    if not current then
        WgdotYaziRangeDiscard()
        return
    end

    local range = WgdotYaziRangePreview
    if not WgdotYaziRangeValid() or not range or range.last_url ~= hovered_url
        or files[range.anchor] ~= range.anchor_url
        or files[range.last] ~= range.last_url
    then
        range = {
            tab = cx.tabs.idx,
            cwd = tostring(folder.cwd),
            count = #files,
            anchor = current,
            anchor_url = hovered_url,
            last = current,
            last_url = hovered_url,
        }
        WgdotYaziRangePreview = range
    end

    local target = math.max(1, math.min(#files, current + step))
    if target == current then
        if not range.paths then
            WgdotYaziRangeRebuild(range, files)
            ui.render()
        end
        return
    end

    range.last = target
    range.last_url = files[target]
    WgdotYaziRangeRebuild(range, files)
    ya.emit("arrow", { step })
    ui.render()
end

function WgdotYaziSpace()
    if WgdotYaziRangeValid() then
        local range = WgdotYaziRangePreview
        local hovered = cx.active.current.hovered
        local files = WgdotYaziRangeFiles(cx.active.current)
        if hovered and tostring(hovered.url) == range.last_url
            and files[range.anchor] == range.anchor_url
            and files[range.last] == range.last_url
        then
            -- Preview never changed the selected set. Commit with Yazi's
            -- own visual mode only when Space is actually pressed.
            WgdotYaziRangePreview = nil
            ya.emit("reveal", { Url(range.anchor_url) })
            ya.emit("visual_mode", {})
            ya.emit("arrow", { range.last - range.anchor })
            ya.emit("escape", { visual = true })
            ya.emit("reveal", { Url(range.last_url) })
            ui.render()
            return
        end
    end

    WgdotYaziRangeDiscard()
    ya.emit("toggle", {})
end

function WgdotYaziArrow(step)
    if WgdotYaziDeleteMenu and WgdotYaziDeleteMenu._visible then
        WgdotYaziDeleteMenu:move(step)
        return
    end
    if WgdotYaziContextMenu and WgdotYaziContextMenu._visible
        and WgdotYaziContextMenu._kind == "drop"
    then
        WgdotYaziContextMenu:move_keyboard(step)
        return
    end

    WgdotYaziRangeDiscard()
    ya.emit("arrow", { step < 0 and "prev" or "next" })
end

local WgdotYaziDefaultEntityStyle = Entity.style
function Entity:style()
    local style = WgdotYaziDefaultEntityStyle(self)
    local range = WgdotYaziRangePreview
    if self._file.in_current and range and WgdotYaziRangeValid()
        and range.paths and range.paths[tostring(self._file.url)]
    then
        return style:patch(ui.Style():reverse():underline())
    end
    return style
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

local WgdotYaziTabDrag = nil

local function WgdotYaziTabIndexAtX(tabs, x)
    for i = #cx.tabs, 1, -1 do
        local offset = tabs._offsets[i]
        if offset and x >= offset then
            return i
        end
    end
    return nil
end

local function WgdotYaziFinishTabDrag()
    local drag = WgdotYaziTabDrag
    WgdotYaziTabDrag = nil
    if drag and drag.moved then
        ui.render()
    end
end

local WgdotYaziDefaultTabsStyle = Tabs.style

function Tabs:style()
    local styles = WgdotYaziDefaultTabsStyle(self)
    if WgdotYaziTabDrag and WgdotYaziTabDrag.moved then
        -- A single terminal row cannot lift a tab physically; emphasize the dragged block.
        styles.active = styles.active:patch(ui.Style():bold():underline():reverse())
    end
    return styles
end

local function WgdotYaziMoveActiveTabTo(current, target)
    if not current or not target or current == target then
        return
    end

    local step = target > current and 1 or -1
    for _ = 1, math.abs(target - current) do
        ya.emit("tab_swap", { step })
    end
end

function Tabs:click(event, up)
    local index = WgdotYaziTabIndexAtX(self, event.x)
    if not index then
        WgdotYaziFinishTabDrag()
        return
    end

    if event.is_right then
        if up then
            return
        end
        WgdotYaziFinishTabDrag()
        ya.emit("tab_switch", { index - 1 })
        ya.emit("tab_rename", { interactive = true })
        return
    elseif not event.is_left then
        return
    end

    if not up then
        WgdotYaziTabDrag = {
            target = index,
            last_x = event.x,
            moved = false,
        }
        ya.emit("tab_switch", { index - 1 })
        return
    end

    WgdotYaziFinishTabDrag()
end

local function WgdotYaziTabMidpoint(tabs, index)
    local first = tabs._offsets[index]
    if not first then return nil end
    local next_offset = tabs._offsets[index + 1]
    -- The last tab ends at its rendered label, not at the terminal edge.
    -- Using the whole remaining tab-bar width makes the rightmost slot
    -- unreachable when there is unused space to the right of the tabs.
    local last = next_offset
    if not last then
        local max = math.floor(tabs:inner_width() / #cx.tabs)
        local name = ui.truncate(
            string.format(" %d %s ", index, cx.tabs[index].name),
            { max = max }
        )
        last = first + ui.width(name)
    end
    return math.floor((first + last) / 2)
end

function Tabs:drag(event)
    local drag = WgdotYaziTabDrag
    if not drag or not event.x then return end

    if not drag.moved then
        drag.moved = true
        ui.render()
    end

    -- Swap only after crossing the adjacent tab's midpoint, rather than
    -- reacting to its moving edge. Require mouse travel after a swap too,
    -- preventing a reflow at a stationary cursor from ping-ponging tabs.
    if drag.last_swap_x and math.abs(event.x - drag.last_swap_x) < 3 then
        return
    end

    local target = drag.target
    local margin = 1
    if event.x > (drag.last_x or event.x) then
        while target < #cx.tabs do
            local midpoint = WgdotYaziTabMidpoint(self, target + 1)
            if not midpoint or event.x < midpoint + margin then break end
            target = target + 1
        end
    elseif event.x < (drag.last_x or event.x) then
        while target > 1 do
            local midpoint = WgdotYaziTabMidpoint(self, target - 1)
            if not midpoint or event.x > midpoint - margin then break end
            target = target - 1
        end
    end

    drag.last_x = event.x
    if target ~= drag.target then
        WgdotYaziMoveActiveTabTo(drag.target, target)
        drag.target = target
        drag.last_swap_x = event.x
    end
end

WgdotYaziDeleteMenu = {
    _id = "wgdot-yazi-delete-menu",
    _visible = false,
    _selected = 1,
    _area = ui.Rect {},
    _list_area = ui.Rect {},
}

function WgdotYaziDeleteMenu:show()
    self._selected = 1
    self._visible = true
    ui.render()
end

function WgdotYaziDeleteMenu:hide()
    if not self._visible then
        return
    end
    self._visible = false
    ui.render()
end

function WgdotYaziDeleteMenu:move(step)
    self._selected = ((self._selected - 1 + step) % 2) + 1
    ui.render()
end

function WgdotYaziDeleteMenu:submit(choice)
    local selected = choice or self._selected
    self._visible = false
    ui.render()

    if WgdotYaziDeleteCollectionSelection() then
        return
    elseif selected == 1 then
        ya.emit("remove", { force = true })
    elseif selected == 2 then
        ya.emit("remove", { permanently = true })
    end
end

function WgdotYaziDeleteMenu:new(area)
    if not self._visible then
        self._area = ui.Rect {}
        self._list_area = ui.Rect {}
        return self
    end

    local width = math.min(50, area.w)
    local height = math.min(6, area.h)
    if width < 34 or height < 6 then
        self._area = ui.Rect {}
        self._list_area = ui.Rect {}
        return self
    end

    local x = area.x + math.floor((area.w - width) / 2)
    local y = area.y + math.floor((area.h - height) / 2)
    self._area = ui.Rect { x = x, y = y, w = width, h = height }
    self._list_area = ui.Rect { x = x + 1, y = y + 1, w = width - 2, h = 2 }
    self._footer_area = ui.Rect { x = x + 1, y = y + 4, w = width - 2, h = 1 }
    return self
end

function WgdotYaziDeleteMenu:reflow()
    return self._visible and self._area.w > 0 and { self } or {}
end

function WgdotYaziDeleteMenu:redraw()
    if not self._visible or self._area.w == 0 then
        return {}
    end

    local actions = {
        { label = "Move to trash", shortcut = "y / Enter" },
        { label = "Permanently delete...", shortcut = "D" },
    }
    local rows = {}
    for i, action in ipairs(actions) do
        local gap = math.max(1, self._list_area.w - #action.label - #action.shortcut - 2)
        local row = ui.Line {
            ui.Span(" " .. action.label):style(th.help.action),
            ui.Span(string.rep(" ", gap)),
            ui.Span(action.shortcut):style(th.help.chord),
            ui.Span(" "),
        }
        if i == self._selected then
            row:style(th.help.hovered)
        end
        rows[#rows + 1] = row
    end

    return {
        ui.Clear(self._area),
        ui.Border(ui.Edge.ALL)
            :area(self._area)
            :type(ui.Border.PLAIN)
            :style(th.help.border)
            :title(ui.Line(" Delete "):align(ui.Align.CENTER)),
        ui.List(rows):area(self._list_area),
        ui.Text(ui.Line(" ↑/↓ choose   Enter confirm   Esc cancel "):align(ui.Align.CENTER))
            :area(self._footer_area),
    }
end

Modal:children_add(WgdotYaziDeleteMenu, 30)

function WgdotYaziRemoveMenu()
    WgdotYaziDeleteMenu:show()
end

function WgdotYaziYank()
    if WgdotYaziDeleteMenu._visible then
        WgdotYaziDeleteMenu:submit(1)
    else
        ya.emit("yank", {})
    end
end

function WgdotYaziPermanentDelete()
    if WgdotYaziDeleteMenu._visible then
        WgdotYaziDeleteMenu:submit(2)
    elseif WgdotYaziDeleteCollectionSelection() then
        return
    else
        ya.emit("remove", { permanently = true })
    end
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

function WgdotYaziBookmarkHovered()
    if WgdotYaziContextMenu
        and WgdotYaziContextMenu._visible
        and WgdotYaziContextMenu._kind == "background"
    then
        WgdotYaziBookmarkTarget(tostring(cx.active.current.cwd), true)
        return
    end

    local hovered = cx.active.current.hovered
    if not hovered or WgdotYaziIsCollectionItemUrl(hovered.url) then
        return
    end

    WgdotYaziBookmarkTarget(tostring(hovered.url), hovered.cha.is_dir)
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

local function WgdotYaziApplyRatio(ratio)
    rt.mgr.ratio = { ratio[1], ratio[2], ratio[3] }
    ya.emit("app:resize", {})
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
    WgdotYaziApplyRatio({ 0, 0, 9999 })
end

local WgdotYaziTextExtensions = {
    txt = true, md = true, markdown = true, log = true, csv = true, tsv = true,
    json = true, jsonc = true, yaml = true, yml = true, toml = true,
    ini = true, conf = true, cfg = true, xml = true, html = true, htm = true,
    css = true, scss = true, less = true, js = true, jsx = true, ts = true,
    tsx = true, lua = true, py = true, rb = true, rs = true, go = true,
    c = true, cc = true, cpp = true, h = true, hpp = true, cs = true,
    java = true, kt = true, kts = true, sh = true, bash = true, zsh = true,
    fish = true, ps1 = true, bat = true, cmd = true, sql = true, env = true,
}

local WgdotYaziTextNames = {
    dockerfile = true,
    makefile = true,
    readme = true,
    [".gitignore"] = true,
    [".gitattributes"] = true,
    [".editorconfig"] = true,
}

local function WgdotYaziHoveredTextFile()
    local hovered = cx.active.current.hovered
    if not hovered or hovered.cha.is_dir then return nil end

    local mime = hovered:mime() or ""
    if mime:match("^text/")
        or mime == "application/json"
        or mime == "application/xml"
        or mime == "application/javascript"
        or mime == "application/x-javascript"
        or mime == "application/x-shellscript"
    then
        return hovered
    end

    local name = tostring(hovered.url.name or ""):lower()
    if WgdotYaziTextNames[name] then return hovered end

    local ext = name:match("%.([^%.]+)$")
    if ext and WgdotYaziTextExtensions[ext] then return hovered end
    return nil
end

local function WgdotYaziPreviewTextSelectable()
    return WgdotYaziPreviewMaximized and WgdotYaziHoveredTextFile() ~= nil
end

local function WgdotYaziPowerShellQuote(value)
    return "'" .. tostring(value):gsub("'", "''") .. "'"
end

local function WgdotYaziUtf16Le(value)
    local out = {}
    for _, code in utf8.codes(value) do
        if code <= 0xFFFF then
            out[#out + 1] = string.char(code % 256, math.floor(code / 256))
        else
            code = code - 0x10000
            local high = 0xD800 + math.floor(code / 0x400)
            local low = 0xDC00 + (code % 0x400)
            out[#out + 1] = string.char(high % 256, math.floor(high / 256))
            out[#out + 1] = string.char(low % 256, math.floor(low / 256))
        end
    end
    return table.concat(out)
end

local function WgdotYaziBase64(value)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    return ((value:gsub(".", function(char)
        local bits = ""
        local byte = char:byte()
        for i = 8, 1, -1 do
            bits = bits .. (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and "1" or "0")
        end
        return bits
    end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(bits)
        if #bits < 6 then return "" end
        local value6 = 0
        for i = 1, 6 do
            if bits:sub(i, i) == "1" then value6 = value6 + 2 ^ (6 - i) end
        end
        return alphabet:sub(value6 + 1, value6 + 1)
    end) .. ({ "", "==", "=" })[#value % 3 + 1])
end

function WgdotYaziSelectPreviewText()
    local hovered = WgdotYaziHoveredTextFile()
    if not hovered then
        ya.notify {
            title = "Select text",
            content = "The highlighted item is not recognized as a text file.",
            timeout = 3,
            level = "warn",
        }
        return
    end

    local script = "$p=" .. WgdotYaziPowerShellQuote(tostring(hovered.url)) .. "; " ..
        "Clear-Host; " ..
        "Get-Content -LiteralPath $p; " ..
        "Write-Host ''; " ..
        "Write-Host 'Select text with the mouse; it copies automatically. Press Enter or Esc to return to Yazi'; " ..
        "do { $k = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } while ($k.VirtualKeyCode -ne 13 -and $k.VirtualKeyCode -ne 27)"

    local encoded = WgdotYaziBase64(WgdotYaziUtf16Le(script))
    local command = "powershell.exe -NoLogo -NoProfile -EncodedCommand " .. encoded
    ya.emit("shell", { run = command, block = true })
end

-- Shared gesture state must be in scope for Esc as well as pane mouse events.
local WgdotYaziDragState = nil
local WgdotYaziDragPending = nil
local WgdotYaziPendingClick = nil

function WgdotYaziEscape()
    -- Keyboard cancellation must erase the ghost and never start a file task.
    if WgdotYaziDragState or WgdotYaziDragPending then
        WgdotYaziDragState = nil
        WgdotYaziDragPending = nil
        WgdotYaziPendingClick = nil
        ui.render()
        return
    end

    if WgdotYaziDeleteMenu and WgdotYaziDeleteMenu._visible then
        WgdotYaziDeleteMenu:hide()
        return
    end

    -- Close Copy/Move (or other context) actions without changing selection.
    if WgdotYaziContextMenu and WgdotYaziContextMenu._visible then
        WgdotYaziContextMenu:hide()
        return
    end

    -- Esc discards a Shift+arrow preview. Native selected files stay selected.
    if WgdotYaziRangeDiscard() then return end

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
    local label = WgdotYaziPreviewMaximized and " 󰘕 [m x] " or " 󰹶 [m x] "
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

WgdotYaziTextSelectButton = {
    _id = "wgdot-yazi-text-select-button",
}

function WgdotYaziTextSelectButton:new(area)
    return setmetatable({ _area = area }, { __index = self })
end

function WgdotYaziTextSelectButton:reflow()
    return { self }
end

function WgdotYaziTextSelectButton:redraw()
    if not WgdotYaziPreviewTextSelectable() then return {} end
    return {
        ui.Text(ui.Line(" Select text [m c] "):style(ui.Style():reverse()))
            :area(self._area)
            :align(ui.Align.LEFT),
    }
end

function WgdotYaziTextSelectButton:click(event, up)
    if up or not event.is_left or not WgdotYaziPreviewTextSelectable() then return end
    WgdotYaziSelectPreviewText()
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
        local preview_button_width = math.min(10, area.w)
        me._wgdot_text_select_button = WgdotYaziTextSelectButton:new(ui.Rect {
            x = area.x,
            y = area.y + area.h - 1,
            w = math.min(19, math.max(0, area.w - preview_button_width)),
            h = 1,
        })
        me._wgdot_preview_button = WgdotYaziPreviewButton:new(ui.Rect {
            x = area.x + area.w - preview_button_width,
            y = area.y + area.h - 1,
            w = preview_button_width,
            h = 1,
        })
    end
    return me
end

function Preview:reflow()
    local components = { self }
    if self._wgdot_text_select_button then
        components[#components + 1] = self._wgdot_text_select_button
    end
    if self._wgdot_preview_button then
        components[#components + 1] = self._wgdot_preview_button
    end
    return components
end

function Preview:redraw()
    local elements = WgdotYaziDefaultPreviewRedraw(self) or {}
    if self._wgdot_text_select_button then
        elements = ya.list_merge(elements, ui.redraw(self._wgdot_text_select_button))
    end
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
    local label = visible and " 󰞔 [m v] " or " 󰞓 [m v] "
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
local WgdotYaziDefaultParentRedraw = Parent.redraw
-- Defined below, after the mouse drag state. Keep native pane rendering.
local WgdotYaziDragGhostRedraw = function() return {}, {} end

function Parent:redraw()
    local cleanup, ghost = WgdotYaziDragGhostRedraw(self._area, "parent")
    local elements = ya.list_merge(cleanup, WgdotYaziDefaultParentRedraw(self) or {})
    return ya.list_merge(elements, ghost)
end

function Current:new(area, tab)
    local reserve_control_row = area.w >= 3 and area.h >= 2
    local current_area = reserve_control_row
        and ui.Rect { x = area.x, y = area.y, w = area.w, h = area.h - 1 }
        or area

    local me = WgdotYaziDefaultCurrentNew(self, current_area, tab)
    if reserve_control_row then
        local preview_toggle_width = math.min(10, area.w)
        me._wgdot_preview_toggle_button = WgdotYaziPreviewToggleButton:new(ui.Rect {
            x = area.x + area.w - preview_toggle_width,
            y = area.y + area.h - 1,
            w = preview_toggle_width,
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
    -- Drop a preview whenever tab, directory, sort order, or mode changed.
    if WgdotYaziRangePreview and not WgdotYaziRangeValid() then
        WgdotYaziRangePreview = nil
    end
    local cleanup, ghost = WgdotYaziDragGhostRedraw(self._area, "current")
    local elements = ya.list_merge(cleanup, WgdotYaziDefaultCurrentRedraw(self) or {})
    if self._wgdot_preview_toggle_button then
        elements = ya.list_merge(elements, ui.redraw(self._wgdot_preview_toggle_button))
    end
    return ya.list_merge(elements, ghost)
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
    { label = "Open", action = "smart_open" },
    { label = "Open with...", action = "open_with" },
    { label = "Bookmark / unbookmark", action = "bookmark_hovered" },
    { label = "Rename", action = "rename" },
    { label = "Drag out...", action = "drag_out" },
    { label = "Copy", action = "copy" },
    { label = "Cut", action = "cut" },
    { label = "Copy path", action = "copy_path" },
    { label = "Compress to ZIP...", action = "compress_zip" },
    { label = "Details", action = "details" },
    { label = "Trash", action = "trash" },
}

-- Terminal-native ghost, clipped to the pane under the pointer.
-- Clear its previous rectangle *before* native rows redraw so a ghost
-- never remains painted on the list after release, Esc, or leaving the pane.
local WgdotYaziDragGhostPrevious = {}
WgdotYaziDragGhostRedraw = function(area, pane)
    local cleanup = {}
    local previous = WgdotYaziDragGhostPrevious[pane]
    if previous then cleanup[1] = ui.Clear(previous) end
    WgdotYaziDragGhostPrevious[pane] = nil

    local drag = WgdotYaziDragState
    if not drag or not drag.x or not drag.y or area.w < 8 or area.h < 2
        or drag.x < area.x or drag.x >= area.x + area.w
        or drag.y < area.y or drag.y >= area.y + area.h
    then
        return cleanup, {}
    end

    local count = #drag.sources
    if count == 0 then return cleanup, {} end

    local label = count == 1
        and (" " .. tostring(drag.sources[1].name or "item") .. " ")
        or string.format(" %d items ", count)
    local line = ui.truncate(ui.printable(label), { max = math.min(36, area.w) })
    local width = ui.width(line)
    if width < 1 then return cleanup, {} end

    local x = math.max(area.x, math.min(drag.x + 2, area.x + area.w - width))
    local y = drag.y + 1 < area.y + area.h and drag.y + 1 or drag.y - 1
    y = math.max(area.y, math.min(y, area.y + area.h - 1))
    local rect = ui.Rect { x = x, y = y, w = width, h = 1 }
    WgdotYaziDragGhostPrevious[pane] = rect

    return cleanup, {
        ui.Text(ui.Line(line):style(ui.Style():fg("gray"):bg("darkgray")))
            :area(rect),
    }
end

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
        local source_url = Url(source.path)
        -- Moving or copying an item into its existing folder is a no-op
        -- (or a same-path collision); do not offer it as a drop destination.
        if WgdotYaziNormalizeFsPath(target_url) == WgdotYaziNormalizeFsPath(source_url.parent)
            or (source.is_dir and target_url:starts_with(source_url))
        then
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
    if not sources or #sources == 0 then
        return
    end

    local local_app_data = os.getenv("LOCALAPPDATA")
    local temp_dir = os.getenv("TEMP")
    if not local_app_data or local_app_data == "" or not temp_dir or temp_dir == "" then
        ya.notify {
            title = "Yazi drag",
            content = "Windows drag helper environment is unavailable.",
            timeout = 4,
            level = "warn",
        }
        return
    end

    local helper = local_app_data .. "\\wgdot\\bin\\wgdotw.exe"
    local probe = io.open(helper, "rb")
    if not probe then
        ya.notify {
            title = "Yazi drag",
            content = "WGDot drag helper is not installed.",
            timeout = 4,
            level = "warn",
        }
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
        ya.notify {
            title = "Yazi drag",
            content = "Could not prepare the Windows drag selection.",
            timeout = 4,
            level = "warn",
        }
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
                content = "WGDot drag window could not be opened.",
                timeout = 4,
                level = "warn",
            }
        end
    end)
end

function WgdotYaziDragOut()
    local hovered = cx.active.current.hovered
    if not hovered then
        return
    end

    WgdotYaziStartOutboundDrag(WgdotYaziDragSources(hovered))
end

local WgdotYaziFolderActions = {
    { label = "New file", action = "new_file" },
    { label = "New folder", action = "new_folder" },
    { label = "Paste", action = "paste" },
    { label = "Terminal here", action = "terminal" },
    { label = "Bookmark / unbookmark folder", action = "bookmark_current" },
}

local function WgdotYaziContextActions(actions)
    local result = {}
    for _, action in ipairs(actions) do
        result[#result + 1] = action
    end
    result[#result + 1] = { label = "Copy current directory path", action = "copy_dirpath" }
    result[#result + 1] = { label = "Open File Explorer here", action = "explorer_here" }
    result[#result + 1] = { label = "Help", action = "help" }
    return result
end

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
    -- Copy is highlighted by default, but no action executes until a click,
    -- Enter, or the explicit copy/move mnemonic.
    self._hovered_row = kind == "drop" and 1 or nil
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
        return " Copy / move "
    elseif self._selection_count > 1 then
        return " " .. tostring(self._selection_count) .. " selected "
    end

    return " Item actions "
end

function WgdotYaziContextMenu:actions()
    if self._kind == "background" then
        return WgdotYaziContextActions(WgdotYaziFolderActions)
    elseif self._kind == "drop" then
        local url = self._drop_target and Url(self._drop_target) or nil
        local folder = url and tostring(url.name or url) or "folder"
        local label = ui.truncate(ui.printable(folder), { max = 30 })
        return {
            { label = "Copy to " .. label, action = "drop_copy" },
            { label = "Move to " .. label, action = "drop_move" },
        }
    end

    local hovered = cx.active.current.hovered
    if self._selection_count > 1 then
        return WgdotYaziContextActions {
            {
                label = "Rename " .. tostring(self._selection_count) .. " items...",
                action = "bulk_rename",
            },
            { label = "Drag out...", action = "drag_out" },
            { label = "Copy", action = "copy" },
            { label = "Cut", action = "cut" },
            { label = "Compress to ZIP...", action = "compress_zip" },
            { label = "Trash " .. tostring(self._selection_count) .. " items", action = "trash" },
        }
    end

    if hovered and hovered.cha.is_dir then
        return WgdotYaziContextActions {
            { label = "Enter folder", action = "smart_open" },
            { label = "Open in new tab", action = "open_new_tab" },
            {
                label = "Bookmark / unbookmark",
                action = "bookmark_hovered",
            },
            { label = "Rename", action = "rename" },
            { label = "Drag out...", action = "drag_out" },
            { label = "Copy", action = "copy" },
            { label = "Cut", action = "cut" },
            { label = "Copy path", action = "copy_path" },
            { label = "Compress to ZIP...", action = "compress_zip" },
            { label = "Details", action = "details" },
            { label = "Trash", action = "trash" },
        }
    end

    local actions = {}
    for _, action in ipairs(WgdotYaziFileActions) do
        actions[#actions + 1] = action
    end

    if hovered and hovered.name:lower():sub(-4) == ".zip" then
        actions[#actions + 1] = { label = "Extract here", action = "extract_here" }
        actions[#actions + 1] = { label = "Extract to folder", action = "extract_folder" }
    end

    return WgdotYaziContextActions(actions)
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
    local height = math.min(#actions + 2, area.h)

    if width < 28 or height < #actions + 2 then
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
    for i, action in ipairs(self:actions()) do
        local row = ui.Line(" " .. action.label .. " "):style(th.help.action)
        if i == self._hovered_row then
            row:style(th.help.hovered)
        end
        rows[#rows + 1] = row
    end

    return {
        ui.Clear(self._area),
        ui.Border(ui.Edge.ALL)
            :area(self._area)
            :type(ui.Border.PLAIN)
            :style(th.help.border)
            :title(ui.Line(self:title()):align(ui.Align.CENTER)),
        ui.List(rows):area(self._list_area),
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
    elseif action == "drag_out" then
        WgdotYaziDragOut()
    elseif action == "bookmark_hovered" then
        local hovered = cx.active.current.hovered
        if hovered then
            WgdotYaziBookmarkTarget(tostring(hovered.url), hovered.cha.is_dir)
        end
    elseif action == "bookmark_current" then
        WgdotYaziBookmarkTarget(tostring(cx.active.current.cwd), true)
    elseif action == "copy_dirpath" then
        -- Snapshot the exact current directory, not selected files' parents.
        local cwd = tostring(cx.active.current.cwd)
        ya.async(function()
            ya.clipboard(cwd)
            ya.notify {
                title = "Clipboard",
                content = "Copied current directory path",
                timeout = 2,
            }
        end)
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
        WgdotYaziRemoveMenu()
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
    elseif action == "explorer_here" then
        ya.emit("shell", { "explorer.exe .", orphan = true })
    elseif action == "help" then
        ya.emit("help", {})
    elseif action == "drop_copy" then
        WgdotYaziDropInto("copy", drop_target, drop_sources)
    elseif action == "drop_move" then
        WgdotYaziDropInto("move", drop_target, drop_sources)
    end
end

function WgdotYaziContextMenu:move_keyboard(step)
    if not self._visible or self._kind ~= "drop" then return end
    local total = #self:actions()
    self._hovered_row = ((self._hovered_row or 1) - 1 + step) % total + 1
    ui.render()
end

function WgdotYaziContextMenu:choose()
    if not self._visible or self._kind ~= "drop" then return end
    local actions = self:actions()
    local selected = actions[self._hovered_row or 1]
    if selected then self:run(selected.action) end
end

function WgdotYaziDropToParent()
    local target = cx.active.current.cwd.parent
    if not target then return end

    local sources = {}
    if #cx.active.selected > 0 then
        for _, file in pairs(cx.active.selected) do
            sources[#sources + 1] = {
                path = tostring(file.path),
                name = file.name,
                is_dir = file.cha.is_dir,
            }
        end
    elseif cx.active.current.hovered then
        sources = WgdotYaziDragSources(cx.active.current.hovered)
    end

    if #sources == 0 or not WgdotYaziCanDropInto(tostring(target), sources) then
        ya.notify {
            title = "Yazi",
            content = "No files can be sent to the parent folder from here.",
            level = "warn",
            timeout = 3,
        }
        return
    end

    local area = WgdotYaziContextMenu._screen
    local x = area and area.x + math.floor(area.w / 2) or 0
    local y = area and area.y + math.floor(area.h / 2) or 0
    WgdotYaziContextMenu:show_drop(target, sources, x, y)
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
local WgdotYaziDefaultRootScroll = Root.scroll

function Root:move(event)
    -- Ordinary mouse movement follows release; in-progress Mouse1 holds use
    -- drag events. Clear a released ghost even if it ended outside Current.
    if WgdotYaziDragState then
        WgdotYaziDragState = nil
        WgdotYaziDragPending = nil
        ui.render()
    end
    if WgdotYaziTabDrag then
        WgdotYaziFinishTabDrag()
    end
    if WgdotYaziContextMenu._visible then
        return WgdotYaziContextMenu:move(event)
    end
    return WgdotYaziDefaultRootMove(self, event)
end

function Root:scroll(event, step)
    if tostring(cx.layer) == "help" then
        ya.emit("help:arrow", { step })
        return
    end
    return WgdotYaziDefaultRootScroll(self, event, step)
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

local function WgdotYaziApplyFolderSort()
    local cwd = WgdotYaziNormalizeFsPath(cx.active.current.cwd)
    local home = WgdotYaziNormalizeFsPath(os.getenv("USERPROFILE"))

    if home ~= "" and cwd == home .. "/downloads" then
        ya.emit("sort", { "mtime", reverse = true, dir_first = true })
    else
        ya.emit("sort", { "natural", reverse = false, dir_first = true })
    end
end

ps.sub("cd", function()
    WgdotYaziApplyFolderSort()

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

local function WgdotYaziHeaderFallback(max, cwd, flags)
    if max <= 0 then
        return ""
    end

    local flag_width = ui.Line(flags):width()
    if flags ~= "" and flag_width >= max then
        return ui.Span(ui.truncate(flags, { max = max, rtl = true }))
            :style(th.mgr.find_keyword)
    end

    local path_max = math.max(0, max - flag_width)
    local path = ui.truncate(ya.readable_path(cwd), { max = path_max, rtl = true })
    local spans = { ui.Span(path):style(th.mgr.cwd) }
    if flags ~= "" then
        spans[#spans + 1] = ui.Span(flags):style(th.mgr.find_keyword)
    end
    return ui.Line(spans)
end

function Header:cwd()
    local max = self._area.w - self._right_width
    local cwd = tostring(self._current.cwd)
    local flags = self:flags()
    local flag_width = ui.Line(flags):width()
    local path_max = math.max(0, max - flag_width)

    self._wgdot_breadcrumbs = {}
    if max <= 0 then
        return ""
    end

    local segments = WgdotYaziBreadcrumbSegments(cwd)
    if not segments then
        return WgdotYaziHeaderFallback(max, cwd, flags)
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
    while total > path_max and #segments > 1 do
        total = total - ui.Line(segments[1].text):width()
        table.remove(segments, 1)
        clipped = true
    end
    if clipped then total = total + 1 end
    if total > path_max then
        return WgdotYaziHeaderFallback(max, cwd, flags)
    end

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

    if flags ~= "" then
        spans[#spans + 1] = ui.Span(flags):style(th.mgr.find_keyword)
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

local WgdotYaziDefaultCurrentDrag = Current.drag
local WgdotYaziDefaultParentClick = Parent.click

local function WgdotYaziParentDropTarget(parent, event)
    -- The left pane lists the parent directory. Releasing over a file
    -- targets its containing parent directory, never the file itself.
    -- A folder row remains an explicit folder destination.
    local row = event.y - parent._area.y + 1
    local folder = parent._folder
    local file = folder and folder.window[row] or nil
    if file then
        if WgdotYaziIsCollectionItemUrl(file.url) then return nil end
        return file.cha.is_dir and file.url or file.url.parent
    end
    return cx.active.current.cwd.parent
end

function Parent:click(event, up)
    if up and event.is_left and WgdotYaziDragState then
        local drag = WgdotYaziDragState
        WgdotYaziDragState = nil
        WgdotYaziDragPending = nil
        WgdotYaziPendingClick = nil

        local target = WgdotYaziParentDropTarget(self, event)
        if target and WgdotYaziCanDropInto(tostring(target), drag.sources) then
            WgdotYaziContextMenu:show_drop(target, drag.sources, event.x, event.y)
        else
            ui.render()
        end
        return
    end

    return WgdotYaziDefaultParentClick(self, event, up)
end

function Current:click(event, up)
    if not up and (event.is_left or event.is_right) then
        WgdotYaziRangeDiscard()
    end
    local row = event.y - self._area.y + 1
    local file = self._folder.window[row]

    if file then
        return Entity:new(file):click(event, up)
    end

    if not up and event.is_right then
        WgdotYaziDragPending = nil
        WgdotYaziPendingClick = nil
        WgdotYaziContextMenu:show("background", event.x, event.y)
    elseif event.is_left then
        WgdotYaziDragPending = nil
        WgdotYaziPendingClick = nil
        if up then
            local was_dragging = WgdotYaziDragState ~= nil
            WgdotYaziDragState = nil
            if was_dragging then ui.render() end
        else
            WgdotYaziContextMenu:hide()
        end
    end
end

function Current:drag(event)
    WgdotYaziPendingClick = nil

    -- Use the file(s) captured at Mouse1 down, never the hovered destination.
    -- Mouse gestures have coordinates; OSC 72 offers do not trigger this UI.
    if event.x and event.y then
        if not WgdotYaziDragState and WgdotYaziDragPending then
            WgdotYaziContextMenu:hide()
            WgdotYaziDragState = { sources = WgdotYaziDragPending.sources }
            WgdotYaziDragPending = nil
        end

        if WgdotYaziDragState
            and (WgdotYaziDragState.x ~= event.x or WgdotYaziDragState.y ~= event.y)
        then
            WgdotYaziDragState.x = event.x
            WgdotYaziDragState.y = event.y
            ui.render()
        end
    end

    return WgdotYaziDefaultCurrentDrag(self, event)
end

function Entity:click(event, up)
    if not up then WgdotYaziRangeDiscard() end
    if up then
        WgdotYaziDragPending = nil
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
            else
                -- Invalid release cancels; clear the ghost without a file operation.
                ui.render()
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
        WgdotYaziDragPending = nil
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
        WgdotYaziDragPending = nil
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
    -- An unselected file drags alone; a selected item drags the selected group.
    -- No Space press is needed for a single file. Nothing moves until menu choice.
    WgdotYaziDragPending = { sources = WgdotYaziDragSources(self._file) }
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
