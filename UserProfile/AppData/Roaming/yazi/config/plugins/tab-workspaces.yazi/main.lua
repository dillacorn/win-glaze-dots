-- WGDot Yazi saved tab groups and persistent pins.
-- Files live under the user's Yazi state directory, never in managed config.
local M = {}
local MAX_TABS = 9
local PIN_EVENT = "@wgdot-yazi-pins"

local function decode_arg(value)
    if type(value) ~= "string" then return value end
    local encoded = value:match("^hex:([%da-fA-F]*)$")
    return encoded and (encoded:gsub("..", function(pair) return string.char(tonumber(pair, 16)) end)) or value
end

local function state_dir()
    return (os.getenv("APPDATA") or os.getenv("LOCALAPPDATA") or ".") .. "\\yazi\\state"
end

local function groups_dir()
    return state_dir() .. "\\collections\\Tab Groups"
end

local function pinned_dir()
    return groups_dir() .. "\\Pinned Tabs"
end

local function pin_dir()
    return state_dir() .. "\\pins"
end

local function hex(value)
    return tostring(value or ""):gsub(".", function(c) return string.format("%02x", c:byte()) end)
end

local function unhex(value)
    if type(value) ~= "string" or #value % 2 ~= 0 or value:find("[^%da-fA-F]") then return nil end
    return (value:gsub("..", function(pair) return string.char(tonumber(pair, 16)) end))
end

local function safe_name(value)
    value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #value == 0 or #value > 80 or value == "." or value == ".." or value:lower() == "pinned tabs" then return nil end
    if value:find('[<>:"/\\|%?%*%c]') or value:find("[%. ]$") then return nil end
    local basename = value:upper():match("^([^.]+)")
    if basename == "CON" or basename == "PRN" or basename == "AUX" or basename == "NUL"
        or (basename and basename:match("^COM[1-9]$"))
        or (basename and basename:match("^LPT[1-9]$")) then return nil end
    return value
end

local function marker_name(path)
    local normalized = tostring(path or ""):gsub("/", "\\")
    local parent, name = normalized:match("^(.*)\\([^\\]+)$")
    if not parent or parent:lower() ~= groups_dir():lower() then return nil end
    return safe_name(name)
end

local function pin_marker_id(path)
    local normalized = tostring(path or ""):gsub("/", "\\")
    local parent = normalized:match("^(.*)\\[^\\]+$")
    if not parent or parent:lower() ~= pinned_dir():lower() then return nil end
    return normalized
end

local function marker_path(name)
    return groups_dir() .. "\\" .. name
end

local function group_file(name)
    return marker_path(name) .. "\\.wgdot-tabs"
end

local function notify(message, level)
    ya.notify { title = "Yazi Tab Groups", content = message, timeout = 4, level = level or "info" }
end

local function ensure_dir(path)
    return fs.create("dir_all", Url(path))
end

-- Write staged data on the same volume; retain the old file until the stage
-- is complete. A failure to replace rolls back the old file if possible.
local function replace_file(path, data)
    local stage = path .. ".new-" .. tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
    local backup = stage .. ".old"
    local ok, err = fs.write(Url(stage), data)
    if not ok then return false, err end
    local had_old = fs.cha(Url(path), false) ~= nil
    if had_old then
        ok, err = fs.rename(Url(path), Url(backup))
        if not ok then
            fs.remove("file", Url(stage))
            return false, err
        end
    end
    ok, err = fs.rename(Url(stage), Url(path))
    if not ok then
        if had_old then
            local restored = fs.rename(Url(backup), Url(path))
            if not restored then
                return false, "Replacement failed, old data retained at " .. backup .. ": " .. tostring(err)
            end
        end
        fs.remove("file", Url(stage))
        return false, err
    end
    if had_old then fs.remove("file", Url(backup)) end
    return true
end

local function read_text(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function encode_tabs(tabs, active)
    local out = { "WGDTABS1\t" .. tostring(active or 1) }
    for _, tab in ipairs(tabs) do
        out[#out + 1] = hex(tab.cwd) .. "\t" .. hex(tab.name or "")
    end
    return table.concat(out, "\n") .. "\n"
end

local function decode_tabs(data)
    if type(data) ~= "string" then return nil, "No saved group data" end
    local lines = {}
    for line in data:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
    local active = tonumber((lines[1] or ""):match("^WGDTABS1\t(%d+)$"))
    if not active or #lines < 2 or #lines > MAX_TABS + 1 then return nil, "Invalid group header or tab count" end
    local tabs = {}
    for index = 2, #lines do
        local a, b = lines[index]:match("^([%da-fA-F]+)\t([%da-fA-F]*)$")
        local cwd, name = a and unhex(a), b and unhex(b)
        if not cwd or cwd == "" or not name then return nil, "Invalid saved tab path or name" end
        tabs[#tabs + 1] = { cwd = cwd, name = name }
    end
    if active < 1 or active > #tabs then return nil, "Invalid active tab" end
    return { tabs = tabs, active = active }
end

-- One file per pin prevents separate Yazi windows from overwriting other
-- pins while changing a single entry. Pin IDs are stable across sessions.
local function read_pins()
    local pins, seen = {}, {}
    local files = fs.read_dir(Url(pin_dir()), { resolve = true })
    if not files then return pins end
    for _, file in ipairs(files) do
        if not file.cha.is_dir then
            local id = tostring(file.url.name or ""):match("^([%w%-]+)%.pin$")
            if id and not seen[id] then
                local data = read_text(tostring(file.url))
                local a, b = data and data:match("^([%da-fA-F]+)\t([%da-fA-F]*)%s*$")
                local cwd, name = a and unhex(a), b and unhex(b)
                if cwd and cwd ~= "" and name then
                    pins[#pins + 1] = { id = id, cwd = cwd, name = name }
                    seen[id] = true
                end
            end
        end
    end
    table.sort(pins, function(a, b) return a.id < b.id end)
    return pins
end

local function merge_pin(pin, remove)
    local ok, err = ensure_dir(pin_dir())
    if not ok then return false, err end
    local path = pin_dir() .. "\\" .. pin.id .. ".pin"
    if remove then
        if not fs.cha(Url(path), false) then return true end
        return fs.remove("file", Url(path))
    end
    return replace_file(path, hex(pin.cwd) .. "\t" .. hex(pin.name or "") .. "\n")
end

local function tab_data(tab)
    return { cwd = tostring(tab.current.cwd), name = tostring(tab.pref and tab.pref.name or "") }
end

local initialize = ya.sync(function(st)
    st.live = st.live or {}
    st.restoring = false
end)

local snapshot_group = ya.sync(function(st)
    local tabs, active = {}, 1
    for i, tab in ipairs(cx.tabs) do
        if not st.live[tostring(tab.id)] then
            tabs[#tabs + 1] = tab_data(tab)
            if i == cx.tabs.idx then active = #tabs end
        end
    end
    return { tabs = tabs, active = active }
end)

local function pin_ids(st)
    local ids = {}
    for tabid in pairs(st.live) do ids[tabid] = true end
    return ids
end

local publish_pins = ya.sync(function(st)
    ps.pub(PIN_EVENT, pin_ids(st))
    ui.render()
end)

local toggle_pin = ya.sync(function(st, index)
    local tab = cx.tabs[index or cx.tabs.idx]
    if not tab then return nil end
    local tabid = tostring(tab.id)
    local id = st.live[tabid]
    if id then
        st.live[tabid] = nil
        return { remove = true, pin = { id = id } }
    end
    st.serial = (st.serial or 0) + 1
    local pin = tab_data(tab)
    pin.id = tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999)) .. "-" .. tostring(st.serial)
    st.live[tabid] = pin.id
    return { remove = false, pin = pin }
end)

local function capture_pinned_tab(st, tab)
    local id = st.live[tostring(tab.id)]
    if not id then return nil end
    local result = tab_data(tab)
    result.id = id
    return result
end

local capture_active_pin = ya.sync(function(st)
    if st.restoring then return nil end
    return capture_pinned_tab(st, cx.active)
end)

local capture_all_pins = ya.sync(function(st)
    local changed = {}
    for _, tab in ipairs(cx.tabs) do
        local pin = capture_pinned_tab(st, tab)
        if pin then changed[#changed + 1] = pin end
    end
    return changed
end)

local fresh_session = ya.sync(function()
    return cx and #cx.tabs == 1
end)

local current_tab_name = ya.sync(function()
    return tostring(cx.active.pref and cx.active.pref.name or "")
end)

local restore_failed_pin_toggle = ya.sync(function(st, changed, index)
    local tab = cx.tabs[index or cx.tabs.idx]
    if tab then
        st.live[tostring(tab.id)] = changed.remove and changed.pin.id or nil
    end
end)

local rename_active_tab = ya.sync(function(st, name)
    local tab = cx.active
    local id = st.live[tostring(tab.id)]
    ya.emit("tab_rename", { name })
    if not id then return nil end
    return { id = id, cwd = tostring(tab.current.cwd), name = name }
end)

local function valid_tabs(tabs)
    if #tabs == 0 or #tabs > MAX_TABS then return false, "Group exceeds the 9-tab limit or is empty" end
    for _, tab in ipairs(tabs) do
        local info = fs.cha(Url(tab.cwd), true)
        if not info or not info.is_dir then return false, "Missing directory: " .. tab.cwd end
    end
    return true
end

local rebuild = ya.sync(function(st, project, pins)
    if not cx or not cx.tabs then return false end
    st.restoring = true
    st.live = {}

    -- First restore the group, then fill any spare slots with saved pins.
    -- Extra pins stay exclusively on disk; they are not discarded.
    local entries = {}
    for _, tab in ipairs(project.tabs) do
        entries[#entries + 1] = { cwd = tab.cwd, name = tab.name }
    end
    for _, pin in ipairs(pins) do
        local duplicate = false
        for _, entry in ipairs(entries) do
            if entry.cwd:lower() == pin.cwd:lower() and entry.name == pin.name then
                duplicate = true
                entry.pin_id = pin.id
                break
            end
        end
        if not duplicate and #entries < MAX_TABS then
            entries[#entries + 1] = { cwd = pin.cwd, name = pin.name, pin_id = pin.id }
        end
    end
    if #entries == 0 then st.restoring = false; return false end

    for _ = 1, #cx.tabs - 1 do ya.emit("tab_close", { 0 }) end
    for index, entry in ipairs(entries) do
        ya.emit("tab_create", { entry.cwd, raw = true })
        if entry.name ~= "" then ya.emit("tab_rename", { entry.name }) end
        if index == 1 then ya.emit("tab_close", { 0 }) end
    end
    local selected = #project.tabs > 0 and math.min(project.active, #project.tabs) or 1
    ya.emit("tab_switch", { selected - 1 })
    -- These actions are queued. Never read cx.active.id here to attribute
    -- newly created tabs; wait until the native tab actions have settled.
    return entries
end)

local finish_rebuild = ya.sync(function(st, entries)
    if not cx or #cx.tabs ~= #entries then return false end
    for index, entry in ipairs(entries) do
        local tab = cx.tabs[index]
        if not tab or tostring(tab.current.cwd):gsub("\\", "/"):lower() ~=
            entry.cwd:gsub("\\", "/"):lower() then return false end
        if tostring(tab.pref and tab.pref.name or "") ~= entry.name then return false end
    end
    st.live = {}
    for index, entry in ipairs(entries) do
        if entry.pin_id then st.live[tostring(cx.tabs[index].id)] = entry.pin_id end
    end
    st.restoring = false
    ps.pub(PIN_EVENT, pin_ids(st))
    ui.render()
    return true
end)

local cancel_restore_state = ya.sync(function(st)
    st.restoring = false
end)

local function rebuild_and_wait(project, pins)
    local entries = rebuild(project, pins)
    if not entries then return false end
    for _ = 1, 12 do
        ya.sleep(25)
        if finish_rebuild(entries) then return true end
    end
    cancel_restore_state()
    return false
end

local clear_live_pin = ya.sync(function(st, id)
    for tabid, linked in pairs(st.live) do
        if linked == id then st.live[tabid] = nil end
    end
    ps.pub(PIN_EVENT, pin_ids(st))
    ui.render()
end)

local activate_pin = ya.sync(function(st, pin)
    for index, tab in ipairs(cx.tabs) do
        if st.live[tostring(tab.id)] == pin.id then
            ya.emit("tab_switch", { index - 1 })
            return "existing"
        end
    end
    if #cx.tabs >= MAX_TABS then return "full" end
    ya.emit("tab_create", { pin.cwd, raw = true })
    if pin.name ~= "" then ya.emit("tab_rename", { pin.name }) end
    return "queued"
end)

local finish_pin_activation = ya.sync(function(st, pin)
    for _, tab in ipairs(cx.tabs) do
        local tabid = tostring(tab.id)
        if not st.live[tabid] and tostring(tab.current.cwd):gsub("\\", "/"):lower() ==
            pin.cwd:gsub("\\", "/"):lower() and
            tostring(tab.pref and tab.pref.name or "") == pin.name then
            st.live[tabid] = pin.id
            ps.pub(PIN_EVENT, pin_ids(st))
            ui.render()
            return true
        end
    end
    return false
end)

local function materialize_pins()
    local root = pinned_dir()
    local ok, err = ensure_dir(root)
    if not ok then return false, err end
    local files, read_err = fs.read_dir(Url(root), { resolve = true })
    if not files then return false, read_err end
    for _, file in ipairs(files) do
        -- Only remove generated markers, never unrelated files a user may
        -- have placed in the browsable collection.
        if not file.cha.is_dir and
            tostring(file.url.name or ""):match("^%d%d%d%d%-%-") then
            ok, err = fs.remove("file", file.url)
            if not ok then return false, err end
        end
    end
    for index, pin in ipairs(read_pins()) do
        local title = (pin.name ~= "" and pin.name or pin.cwd):gsub("[<>:\"/\\|%?%*%c]", "_")
        title = title:gsub("[%. ]+$", ""):sub(1, 65)
        local filename = string.format("%04d--%s", index, title ~= "" and title or "Pinned")
        ok, err = fs.write(Url(root .. "\\" .. filename), pin.id)
        if not ok then return false, err end
    end
    return true
end

local function pin_from_marker(path)
    local marker = pin_marker_id(path)
    if not marker then return nil end
    local id = read_text(marker)
    if not id or not id:match("^[%w%-]+$") then return nil end
    for _, pin in ipairs(read_pins()) do
        if pin.id == id then return pin end
    end
    return nil
end

local function require_group_marker(value)
    local name = marker_name(value)
    if not name then notify("Invalid saved group target", "warn") end
    return name
end

function M:setup()
    initialize()
    -- Yazi emits cd for native navigation; refresh only the active pinned tab.
    -- The pinned state itself survives ordinary tab closes and group changes.
    ps.sub("cd", function()
        local pin = capture_active_pin()
        if pin then
            ya.async(function()
                local ok, err = merge_pin(pin, false)
                if not ok then notify("Could not update pin: " .. tostring(err), "error") end
            end)
        end
    end)
end

function M:entry(job)
    local command = job.args[1]

    if command == "open-pins" then
        local ok, err = materialize_pins()
        if not ok then return notify("Could not display pinned tabs: " .. tostring(err), "error") end
        ya.emit("cd", { Url(pinned_dir()), raw = true })
        return
    end

    if command == "activate-pin" then
        local pin = pin_from_marker(decode_arg(job.args[2]))
        if not pin then return notify("Pinned tab marker is invalid", "warn") end
        local info = fs.cha(Url(pin.cwd), true)
        if not info or not info.is_dir then return notify("Pinned directory no longer exists", "warn") end
        local result = activate_pin(pin)
        if result == "full" then return notify("Nine tabs are already open; close one to activate this pin.", "warn") end
        if result == "queued" then
            local applied = false
            for _ = 1, 12 do
                ya.sleep(25)
                if finish_pin_activation(pin) then applied = true; break end
            end
            if not applied then return notify("Pin was opened but its identity could not be confirmed.", "error") end
        end
        return
    end

    if command == "unpin-markers" then
        for i = 2, #job.args do
            local pin = pin_from_marker(decode_arg(job.args[i]))
            if pin then
                local ok, err = merge_pin(pin, true)
                if not ok then return notify("Could not unpin: " .. tostring(err), "error") end
                clear_live_pin(pin.id)
            end
        end
        local ok, err = materialize_pins()
        if not ok then return notify("Pins saved but list refresh failed: " .. tostring(err), "warn") end
        ya.emit("refresh", {})
        return notify("Selected tab pin(s) removed")
    end

    if command == "open" then
        local ok, err = ensure_dir(groups_dir())
        if not ok then return notify("Cannot create groups directory: " .. tostring(err), "error") end
        ok, err = ensure_dir(pinned_dir())
        if not ok then return notify("Cannot create pinned-tabs folder: " .. tostring(err), "error") end
        ya.emit("cd", { Url(groups_dir()), raw = true })
        return
    end

    if command == "save" then
        local project = snapshot_group()
        if #project.tabs == 0 then return notify("All tabs are pinned. No unpinned tabs to save.", "warn") end
        local name, event = ya.input { pos = { "center", w = 48 }, title = "Save Tab Group as:" }
        if event ~= 1 then return end
        name = safe_name(name)
        if not name then return notify("Use a valid folder name (maximum 80 characters).", "warn") end
        local path = group_file(name)
        if fs.cha(Url(path), false) then
            local yes = ya.confirm {
                pos = { "center", w = 46, h = 7 },
                title = "Replace Tab Group?",
                body = ui.Text("Overwrite saved group '" .. name .. "'?"),
            }
            if not yes then return end
        end
        local ok, err = ensure_dir(marker_path(name))
        if not ok then return notify("Cannot create group: " .. tostring(err), "error") end
        ok, err = replace_file(path, encode_tabs(project.tabs, project.active))
        if not ok then return notify("Save failed: " .. tostring(err), "error") end
        notify("Saved: " .. name)
        ya.emit("refresh", {})
        return
    end

    if command == "load" then
        local name = require_group_marker(decode_arg(job.args[2]))
        if not name then return end
        local project, err = decode_tabs(read_text(group_file(name)))
        if not project then return notify(err, "error") end
        local ok
        ok, err = valid_tabs(project.tabs)
        if not ok then return notify(err, "warn") end
        local updated = capture_all_pins()
        for _, pin in ipairs(updated) do
            ok, err = merge_pin(pin, false)
            if not ok then return notify("Cannot preserve pinned tab before load: " .. tostring(err), "error") end
        end
        local pins = read_pins()
        -- Stale pin destinations remain in saved state; skip them for this load.
        local valid_pins = {}
        for _, pin in ipairs(pins) do
            local info = fs.cha(Url(pin.cwd), true)
            if info and info.is_dir then valid_pins[#valid_pins + 1] = pin end
        end
        if not rebuild_and_wait(project, valid_pins) then return notify("Unable to verify restored group tabs", "error") end
        notify("Loaded: " .. name)
        return
    end

    if command == "rename-group" then
        local old = require_group_marker(decode_arg(job.args[2]))
        if not old then return end
        local value, event = ya.input { pos = { "center", w = 48 }, title = "Rename Tab Group:", value = old }
        if event ~= 1 then return end
        local name = safe_name(value)
        if not name then return notify("Invalid group name", "warn") end
        if name == old then return end
        if fs.cha(Url(marker_path(name)), false) then return notify("That group already exists", "warn") end
        local ok, err = fs.rename(Url(marker_path(old)), Url(marker_path(name)))
        if not ok then return notify("Rename failed: " .. tostring(err), "error") end
        ya.emit("refresh", {})
        return notify("Renamed to: " .. name)
    end

    if command == "delete-groups" then
        for i = 2, #job.args do
            local name = marker_name(decode_arg(job.args[i]))
            if name then
                -- Only remove directories that contain a valid saved group.
                local project = decode_tabs(read_text(group_file(name)))
                if not project then return notify("Invalid group entry: " .. name, "warn") end
                local ok, err = fs.remove("dir_all", Url(marker_path(name)))
                if not ok then return notify("Delete failed: " .. tostring(err), "error") end
            end
        end
        ya.emit("refresh", {})
        return notify("Removed saved group configuration(s)")
    end

    if command == "pin" then
        local changed = toggle_pin(tonumber(job.args[2]))
        if not changed then return end
        local ok, err = merge_pin(changed.pin, changed.remove)
        if not ok then
            -- Revert the in-memory change after a persistence failure.
            restore_failed_pin_toggle(changed, tonumber(job.args[2]))
            return notify("Could not persist pin: " .. tostring(err), "error")
        end
        publish_pins()
        return notify(changed.remove and "Tab unpinned" or "Tab pinned")
    end

    if command == "rename-tab" then
        local current = current_tab_name()
        local value, event = ya.input { pos = { "center", w = 48 }, title = "Rename Tab (empty = automatic):", value = current }
        if event ~= 1 then return end
        local pin = rename_active_tab(value)
        if pin then
            local ok, err = merge_pin(pin, false)
            if not ok then notify("Tab renamed, but pin update failed: " .. tostring(err), "error") end
        end
        return
    end

    if command == "restore" then
        local pins = read_pins()
        local valid = {}
        for _, pin in ipairs(pins) do
            local info = fs.cha(Url(pin.cwd), true)
            if info and info.is_dir then valid[#valid + 1] = pin end
        end
        if #valid == 0 then return end
        local is_fresh = fresh_session()
        if is_fresh and not rebuild_and_wait({ tabs = {}, active = 1 }, valid) then
            notify("Could not verify pinned tabs on startup", "error")
        end
        return
    end
end

return M
