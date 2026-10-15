-- Deterministic Yazi plugin behavioral smoke test.
-- Run with: lua5.4 tests/test-yazi-tab-workspaces.lua
-- No Windows files, shell commands, or actual Yazi instance are touched.
local native_open = io.open
local FS_FILES, FS_DIRS = {}, {}
local ROOT = [[C:\Unit\AppData\Roaming\yazi\state]]
local GROUPS = ROOT .. [[\collections\Tab Groups]]
local PIN_DIR = ROOT .. [[\pins]]
local PINS = GROUPS .. [[\Pinned Tabs]]
local notifications = {}
local inputs = {}
local confirmations = {}
local events = {}
local subscriptions = {}
local published = {}
local state = {}
local next_id = 1
local inject_pin_attach_navigation = false

local function assert_true(value, message)
    if not value then error(message, 2) end
end

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function normalize(path) return tostring(path):gsub("/", "\\") end
local function parent(path) return normalize(path):match("^(.*)\\[^\\]+$") end
local function name(path) return normalize(path):match("([^\\]+)$") end
local function url(path)
    path = normalize(path)
    return setmetatable({ name = name(path), path = path }, {
        __tostring = function(self) return self.path end,
    })
end
Url = url

local function create_dir(path)
    path = normalize(path)
    local p = parent(path)
    if p and p ~= path and p:find("\\", 1, true) and not FS_DIRS[p] then create_dir(p) end
    FS_DIRS[path] = true
end
create_dir([[C:\Safe]])
create_dir([[C:\Drafting]])
create_dir([[C:\Downloads]])
create_dir([[C:\Other]])
create_dir([[C:\Extra]])

local function children(path)
    local out = {}
    for dir in pairs(FS_DIRS) do
        if parent(dir) == path then out[#out + 1] = { url = url(dir), cha = { is_dir = true } } end
    end
    for file in pairs(FS_FILES) do
        if parent(file) == path then out[#out + 1] = { url = url(file), cha = { is_dir = false } } end
    end
    return out
end

fs = {
    cha = function(path)
        path = normalize(path)
        if FS_DIRS[path] then return { is_dir = true } end
        if FS_FILES[path] ~= nil then return { is_dir = false } end
        return nil
    end,
    create = function(kind, path)
        assert_eq(kind, "dir_all", "expected safe directory creation")
        create_dir(path)
        return true
    end,
    write = function(path, value)
        path = normalize(path)
        if not FS_DIRS[parent(path)] then return false, "Parent does not exist" end
        FS_FILES[path] = value
        return true
    end,
    read_dir = function(path)
        path = normalize(path)
        if not FS_DIRS[path] then return nil, "Directory missing" end
        return children(path)
    end,
    rename = function(source, dest)
        source, dest = normalize(source), normalize(dest)
        if FS_FILES[source] ~= nil then
            if FS_FILES[dest] ~= nil or not FS_DIRS[parent(dest)] then return false, "Destination exists or parent missing" end
            FS_FILES[dest], FS_FILES[source] = FS_FILES[source], nil
            return true
        end
        if FS_DIRS[source] then
            if FS_DIRS[dest] or not FS_DIRS[parent(dest)] then return false, "Destination exists or parent missing" end
            for path in pairs(FS_DIRS) do
                if path == source or path:sub(1, #source + 1) == source .. "\\" then
                    FS_DIRS[dest .. path:sub(#source + 1)] = true
                    FS_DIRS[path] = nil
                end
            end
            for path, value in pairs(FS_FILES) do
                if path:sub(1, #source + 1) == source .. "\\" then
                    FS_FILES[dest .. path:sub(#source + 1)] = value
                    FS_FILES[path] = nil
                end
            end
            return true
        end
        return false, "Source missing"
    end,
    remove = function(kind, source)
        source = normalize(source)
        if kind == "file" then
            if FS_FILES[source] == nil then return false, "File missing" end
            FS_FILES[source] = nil
            return true
        elseif kind == "dir" then
            if not FS_DIRS[source] or #children(source) > 0 then return false, "Directory not empty" end
            FS_DIRS[source] = nil
            return true
        end
        error("Unsafe remove requested: " .. tostring(kind))
    end,
}
io.open = function(path, mode)
    assert_eq(mode, "rb", "read-only mocked state access")
    local value = FS_FILES[normalize(path)]
    if value == nil then return nil end
    return { read = function(_, readmode) assert_eq(readmode, "*a", "read file content"); return value end,
        close = function() end }
end

-- Native Yazi exposes tab IDs as userdata objects with a stable .value,
-- but tostring(tab.id) shows a fresh userdata pointer. Simulate that hazard:
-- each field access returns a new wrapper with a different string address.
local pointer_seq = 0
local function make_tab(path, custom_name)
    local id = next_id
    next_id = next_id + 1
    return setmetatable({
        native_id = id,
        current = { cwd = url(path) },
        pref = { name = custom_name or "" },
    }, {
        __index = function(tab, key)
            if key ~= "id" then return nil end
            pointer_seq = pointer_seq + 1
            return setmetatable({ value = tab.native_id }, {
                __tostring = function()
                    return string.format("%016X", 0x210573EF568 + pointer_seq)
                end,
            })
        end,
    })
end
cx = { tabs = {} }
local function focus(index)
    cx.tabs.idx = index
    cx.active = cx.tabs[index]
end
local function set_tabs(tabs, active)
    cx.tabs = {}
    for _, tab in ipairs(tabs) do
        cx.tabs[#cx.tabs + 1] = make_tab(tab[1], tab[2])
    end
    focus(active or 1)
end

local function drain()
    while #events > 0 do
        local event = table.remove(events, 1)
        local command, args = event[1], event[2]
        if command == "tab_close" then
            local target = (args[1] or (cx.tabs.idx - 1)) + 1
            if #cx.tabs > 1 then
                table.remove(cx.tabs, target)
                focus(math.max(1, math.min(cx.tabs.idx, #cx.tabs)))
            end
        elseif command == "tab_create" then
            local target = args[1]
            table.insert(cx.tabs, cx.tabs.idx + 1, make_tab(target))
            focus(cx.tabs.idx + 1)
        elseif command == "tab_rename" then
            -- Native Yazi routes actions with a 'tab' field to that stable ID,
            -- rather than whichever tab happens to be active on dispatch.
            local target = args.tab == nil and cx.active or nil
            if args.tab ~= nil then
                for _, candidate in ipairs(cx.tabs) do
                    if tostring(candidate.id.value) == tostring(args.tab) then
                        target = candidate
                        break
                    end
                end
            end
            if target then target.pref.name = args[1] end
        elseif command == "tab_switch" then
            focus(args[1] + 1)
        elseif command == "cd" then
            cx.active.current.cwd = args[1]
        elseif command == "refresh" then
            -- No visual layer in this simulated test.
        else
            error("Unexpected Yazi action " .. tostring(command))
        end
    end
end

ya = {
    sync = function(fn)
        return function(...)
            local args = { ... }
            -- Simulate Yazi changing a new tab's cwd/name between the
            -- successful create verification and the pin-ID association.
            if inject_pin_attach_navigation and #args == 2
                and type(args[1]) == "table" and type(args[1].id) == "string"
                and type(args[2]) == "string" then
                inject_pin_attach_navigation = false
                cx.active.current.cwd = url([[C:\Other]])
                cx.active.pref.name = "Navigation while restoring"
            end
            return fn(state, ...)
        end
    end,
    emit = function(command, args)
        events[#events + 1] = {command, args}
    end,
    sleep = function() drain() end,
    input = function()
        local input = table.remove(inputs, 1)
        assert_true(input ~= nil, "Unexpected input prompt")
        if type(input) == "table" then
            if input.on_prompt then input.on_prompt() end
            return input.value, input.event
        end
        return input, 1
    end,
    confirm = function()
        local answer = table.remove(confirmations, 1)
        assert_true(answer ~= nil, "Unexpected confirmation")
        return answer
    end,
    notify = function(n) notifications[#notifications + 1] = n end,
    async = function(fn) return fn() end,
}
ui = { render = function() end, Text = function(v) return v end }
ps = {
    sub = function(event, fn) subscriptions[event] = fn end,
    pub = function(event, value) published[event] = value end,
}

os.getenv = (function(previous)
    return function(key)
        if key == "APPDATA" then return [[C:\Unit\AppData\Roaming]] end
        return previous(key)
    end
end)(os.getenv)

local plugin_file = [[UserProfile/AppData/Roaming/yazi/config/plugins/tab-workspaces.yazi/main.lua]]
local module = dofile(plugin_file)
module:setup()

-- Save two unpinned tabs with a custom name and an active second tab.
set_tabs({ { [[C:\Safe]], "Survey" }, { [[C:\Drafting]], "" } }, 2)
inputs[#inputs + 1] = "Survey Group"
module:entry { args = { "save" } }
local real_group_file = GROUPS .. [[\Survey Group\.wgdot-tabs]]
assert_true(FS_FILES[real_group_file] ~= nil, "Group persisted to user state")
assert_true(FS_FILES[real_group_file]:find("WGDTABS1", 1, true) ~= nil, "Group format header present")

-- Enter collection should create a visible pinned folder.
module:entry { args = { "open" } }
drain()
assert_true(FS_DIRS[PINS], "Pinned Tabs subcollection exists")

-- Restore group safely with an unrelated live tab initially active.
set_tabs({ { [[C:\Other]], "" } })
module:entry { args = { "load", GROUPS .. [[\Survey Group]] } }
drain()
assert_eq(#cx.tabs, 2, "Restored tab count")
assert_eq(tostring(cx.tabs[1].current.cwd), [[C:\Safe]], "First tab restored")
assert_eq(cx.tabs[1].pref.name, "Survey", "Custom name restored")
assert_eq(tostring(cx.tabs[2].current.cwd), [[C:\Drafting]], "Second tab restored")
assert_eq(cx.tabs.idx, 2, "Active index restored")

-- A colliding user-created directory must never be adopted or overwritten.
local collision = GROUPS .. [[\Personal]]
create_dir(collision)
FS_FILES[collision .. [[\keep.txt]]] = "user data"
inputs[#inputs + 1] = "Personal"
module:entry { args = { "save" } }
assert_eq(FS_FILES[collision .. [[\keep.txt]]], "user data", "Unrelated file preserved on save collision")
assert_true(FS_FILES[collision .. [[\.wgdot-tabs]]] == nil, "Collision did not create state")

-- Deletion must touch only .wgdot-tabs and keep unrelated files/folders.
FS_FILES[GROUPS .. [[\Survey Group\user-note.txt]]] = "preserve"
module:entry { args = { "delete-groups", GROUPS .. [[\Survey Group]] } }
assert_true(FS_FILES[real_group_file] == nil, "Removed saved group configuration")
assert_eq(FS_FILES[GROUPS .. [[\Survey Group\user-note.txt]]], "preserve", "Preserved unrelated group-directory file")
assert_true(FS_DIRS[GROUPS .. [[\Survey Group]]], "Preserved nonempty group directory")

-- This matches Yazi's plugin action contract: the plugin name is the
-- first action argument, while all command words must be encoded in the
-- *single* second argument. Hex payloads survive shell tokenization.
local function encoded_plugin_arg(value)
    return "hex:" .. tostring(value):gsub(".", function(char)
        return string.format("%02x", string.byte(char))
    end)
end

-- Pin records are separate files so other pins cannot be overwritten.
set_tabs({ { [[C:\Safe]], "Persistent" }, { [[C:\Drafting]], "" } })
module:entry { args = { "pin" } }
local pinned_count = 0
for path in pairs(FS_FILES) do
    if parent(path) == PIN_DIR and path:match("%.pin$") then pinned_count = pinned_count + 1 end
end
assert_eq(pinned_count, 1, "First pin persisted")
-- Mouse middle-click must pin the hovered nonfocused tab by stable ID.
local focused_before = cx.tabs.idx
local inactive_id = tostring(cx.tabs[2].id.value)
local focused_id = tostring(cx.tabs[1].id.value)
module:entry { args = { "pin", encoded_plugin_arg(inactive_id) } }
assert_eq(cx.tabs.idx, focused_before, "Pinning another tab does not change focus")
assert_true(published["wgdot-yazi-pins"][inactive_id], "Inactive hovered tab is now pinned")
assert_true(published["wgdot-yazi-pins"][focused_id], "Previously focused pin remains intact")
pinned_count = 0
for path in pairs(FS_FILES) do
    if parent(path) == PIN_DIR and path:match("%.pin$") then pinned_count = pinned_count + 1 end
end
assert_eq(pinned_count, 2, "Second pin is independent")
-- Repeating middle-click on the same inactive tab must unpin that tab only.
module:entry { args = { "pin", encoded_plugin_arg(inactive_id) } }
assert_eq(cx.tabs.idx, focused_before, "Unpinning another tab also preserves focus")
assert_true(not published["wgdot-yazi-pins"][inactive_id], "Inactive tab unpinned")
assert_true(published["wgdot-yazi-pins"][focused_id], "Focused tab pin unaffected")
module:entry { args = { "pin", encoded_plugin_arg(inactive_id) } }
assert_true(published["wgdot-yazi-pins"][inactive_id], "Inactive tab re-pinned after second toggle")
-- A stale middle-click target must not silently fall back to the focused tab.
module:entry { args = { "pin", encoded_plugin_arg("999999999") } }
assert_true(published["wgdot-yazi-pins"][focused_id], "Unknown hovered tab never toggles focused pin")
assert_true(published["wgdot-yazi-pins"][inactive_id], "Unknown hovered tab never toggles another pin")


-- Native rename must keep focus on the current tab while targeting the
-- inactive tab's stable ID, and preserve its independent on-disk pin record.
local inactive_pin_file = PIN_DIR .. "\\" .. state.live[inactive_id] .. ".pin"
local focused_pin_file = PIN_DIR .. "\\" .. state.live[focused_id] .. ".pin"
local before_focused_pin = FS_FILES[focused_pin_file]
inputs[#inputs + 1] = "Inactive Renamed"
module:entry { args = { "rename-tab", encoded_plugin_arg(inactive_id) } }
assert_eq(cx.tabs.idx, focused_before, "Right-click rename does not change focus")
assert_eq(events[#events][1], "tab_rename", "Right-click queues native tab rename")
assert_eq(tostring(events[#events][2].tab), inactive_id, "Native rename receives hovered stable ID")
drain()
assert_eq(cx.tabs[2].pref.name, "Inactive Renamed", "Right-click names inactive tab")
assert_eq(cx.tabs[1].pref.name, "Persistent", "Right-click leaves active tab name intact")
assert_eq(FS_FILES[focused_pin_file], before_focused_pin, "Renaming another tab preserves active pin")
assert_true(FS_FILES[inactive_pin_file]:find(encoded_plugin_arg("Inactive Renamed"):sub(5), 1, true) ~= nil,
    "Renaming pinned inactive tab updates durable pin name")

local prior_name = cx.tabs[2].pref.name
local prior_record = FS_FILES[inactive_pin_file]
inputs[#inputs + 1] = { value = "Must Not Apply", event = 0 }
local before_events = #events
module:entry { args = { "rename-tab", encoded_plugin_arg(inactive_id) } }
assert_eq(#events, before_events, "Canceled rename emits no native action")
assert_eq(cx.tabs[2].pref.name, prior_name, "Canceled rename preserves tab label")
assert_eq(FS_FILES[inactive_pin_file], prior_record, "Canceled rename preserves persistent pin")

-- Keyboard t r must still target its original focused tab, including if
-- the active index changes while the asynchronous dialog is open.
inputs[#inputs + 1] = { value = "Focused Renamed", event = 1, on_prompt = function()
    focus(2)
end }
module:entry { args = { "rename-tab" } }
assert_eq(tostring(events[#events][2].tab), focused_id, "Keyboard t r snapshots original native ID")
drain()
assert_eq(cx.tabs[1].pref.name, "Focused Renamed", "Keyboard t r renames original active tab")
assert_eq(cx.tabs[2].pref.name, prior_name, "Keyboard t r does not rename newly focused tab")
assert_true(FS_FILES[focused_pin_file]:find(encoded_plugin_arg("Focused Renamed"):sub(5), 1, true) ~= nil,
    "Keyboard rename updates persistent pin name")

-- Reordering between prompt and submit must not redirect the rename.
focus(1)
inputs[#inputs + 1] = { value = "Moved Target", event = 1, on_prompt = function()
    local moved = table.remove(cx.tabs, 2)
    table.insert(cx.tabs, 1, moved)
    focus(2)
end }
module:entry { args = { "rename-tab", encoded_plugin_arg(inactive_id) } }
assert_eq(tostring(events[#events][2].tab), inactive_id, "Reordered rename keeps stable tab ID")
drain()
assert_eq(cx.tabs[1].pref.name, "Moved Target", "Rename follows tab across index reorder")
assert_eq(cx.tabs[2].pref.name, "Focused Renamed", "Reorder leaves other tab intact")

-- If the tab disappears during the dialog, the replacement must not be
-- renamed and the previous pin record must not be overwritten.
local record_before_close = FS_FILES[inactive_pin_file]
inputs[#inputs + 1] = { value = "Wrong Replacement", event = 1, on_prompt = function()
    table.remove(cx.tabs, 1)
    table.insert(cx.tabs, 1, make_tab([[C:\Other]], "Replacement"))
    focus(2)
end }
before_events = #events
module:entry { args = { "rename-tab", encoded_plugin_arg(inactive_id) } }
assert_eq(#events, before_events, "Stale rename ID cannot enqueue another-tab rename")
assert_eq(cx.tabs[1].pref.name, "Replacement", "Stale rename leaves new tab unchanged")
assert_eq(FS_FILES[inactive_pin_file], record_before_close, "Stale rename preserves pin record")


-- Suspended pin inventory can always be opened and unpinned without
-- removing the directory referenced by the pin.
module:entry { args = { "open-pins" } }
drain()
local marker
for path, data in pairs(FS_FILES) do
    if parent(path) == PINS and data:find("%-") then marker = path; break end
end
assert_true(marker ~= nil, "Pinned marker materialized")
module:entry { args = { "unpin-markers", marker } }
assert_true(FS_DIRS["C:\\Safe"] and FS_DIRS["C:\\Drafting"], "Unpin did not delete real dirs")

-- Eight group tabs take precedence over three pins; overflow pins must
-- survive exclusively in state, with no more than nine live native tabs.
local big = {}
for i = 1, 8 do
    local folder = "C:\\Group" .. tostring(i)
    create_dir(folder)
    big[#big + 1] = { folder, i == 4 and "Custom" or "" }
end
set_tabs(big, 4)
inputs[#inputs + 1] = "Eight Tabs"
module:entry { args = { "save" } }
assert_true(FS_FILES[GROUPS .. [[\Eight Tabs\.wgdot-tabs]]] ~= nil, "Eight-tab group saved")

set_tabs({ { [[C:\Other]], "Pinned Other" }, { [[C:\Extra]], "Pinned Extra" } })
module:entry { args = { "pin" } }
local second_pin_id = tostring(cx.tabs[2].id.value)
module:entry { args = { "pin", encoded_plugin_arg(second_pin_id) } }
assert_eq(cx.tabs.idx, 1, "Pinning second tab by mouse does not focus it")

local pin_records = 0
for path in pairs(FS_FILES) do
    if parent(path) == PIN_DIR and path:match("%.pin$") then pin_records = pin_records + 1 end
end
assert_eq(pin_records, 3, "Independent pins are all persisted")
module:entry { args = { "load", GROUPS .. [[\Eight Tabs]] } }
drain()
assert_eq(#cx.tabs, 9, "Nine-tab capacity respected with group priority")
assert_eq(tostring(cx.tabs[1].current.cwd), [[C:\Group1]], "Group occupies first tab")
assert_eq(cx.tabs[4].pref.name, "Custom", "Saved group custom name survived overflow")
assert_eq(cx.tabs.idx, 4, "Active tab restored in full group")
local live_pin_count = 0
for _, is_pin in pairs(published["wgdot-yazi-pins"] or {}) do
    if is_pin then live_pin_count = live_pin_count + 1 end
end
assert_eq(live_pin_count, 1, "Only one pinned tab fits after eight group tabs")
pin_records = 0
for path in pairs(FS_FILES) do
    if parent(path) == PIN_DIR and path:match("%.pin$") then pin_records = pin_records + 1 end
end
assert_eq(pin_records, 3, "Suspended pin state survived tab capacity pressure")

-- Unpin-and-close must persist removal before closing the specific tab.
local visible_pin_id
for tabid in pairs(published["wgdot-yazi-pins"] or {}) do
    visible_pin_id = tabid
end
assert_true(visible_pin_id ~= nil, "Visible pin has a stable tab ID")
module:entry { args = { "unpin-and-close", encoded_plugin_arg(visible_pin_id) } }
drain()
assert_eq(#cx.tabs, 8, "Pinned tab closes only after unpin succeeds")
local retained_pins = 0
for path in pairs(FS_FILES) do
    if parent(path) == PIN_DIR and path:match("%.pin$") then retained_pins = retained_pins + 1 end
end
assert_eq(retained_pins, 2, "Only targeted pin was removed")

-- A fresh Yazi window starts in its requested directory while restoring
-- the remaining saved pins in available slots.
set_tabs({ { [[C:\Downloads]], "" } })
-- A new Yazi process has new in-memory mappings, but reuses the same
-- persistent disk records.
state.live = {}
module:entry { args = { "restore" } }
drain()
assert_eq(#cx.tabs, 3, "Fresh session retains launch tab and both saved pins")
assert_eq(tostring(cx.tabs[1].current.cwd), [[C:\Downloads]], "Launch directory preserved")
local restored_pin_count = 0
for _, is_pin in pairs(published["wgdot-yazi-pins"] or {}) do
    if is_pin then restored_pin_count = restored_pin_count + 1 end
end
assert_eq(restored_pin_count, 2, "Fresh session reattaches saved pin identities")

-- If the startup directory itself was pinned, reuse its existing tab
-- rather than creating a duplicate. Still restore the other saved pins.
set_tabs({ { [[C:\Safe]], "Reused Startup" } })
module:entry { args = { "pin" } }
local saved_pin_count = 0
for path in pairs(FS_FILES) do
    if parent(path) == PIN_DIR and path:match("%.pin$") then
        saved_pin_count = saved_pin_count + 1
    end
end
assert_eq(saved_pin_count, 3, "A startup-directory pin is saved independently")
set_tabs({ { [[C:\Safe]], "Reused Startup" } })
local opening_id = tostring(cx.tabs[1].id.value)
assert_true(tostring(cx.tabs[1].id) ~= tostring(cx.tabs[1].id),
    "Opaque Yazi tab.id string addresses differ between reads")
state.live = {}
module:entry { args = { "restore" } }
drain()
assert_eq(#cx.tabs, 3, "Reusing the launch tab avoids a fourth duplicate")
assert_eq(tostring(cx.tabs[1].id.value), opening_id, "Pin restoration did not rebuild the opening tab")
local current_pins = published["wgdot-yazi-pins"] or {}
assert_true(current_pins[opening_id], "The reused opening tab displays as pinned")

-- Regression: pin identity must be attached by native tab ID even if
-- cwd/name change after native tab_create is already confirmed.
set_tabs({ { [[C:\Downloads]], "" } })
state.live = {}
inject_pin_attach_navigation = true
module:entry { args = { "restore" } }
drain()
assert_true(not inject_pin_attach_navigation, "Navigation race was exercised")
local live_after_race = published["wgdot-yazi-pins"] or {}
local race_link_count = 0
for _, is_pin in pairs(live_after_race) do
    if is_pin then race_link_count = race_link_count + 1 end
end
assert_eq(race_link_count, 3, "Restored pin IDs survive a concurrent cwd/name change")


-- Exercise the actual tab mouse handler in isolation with a fake native UI,
-- so button dispatch, 2-position plugin arguments and left-click behavior
-- cannot drift from the behavior tested above.
local init_file = native_open([[UserProfile/AppData/Roaming/yazi/config/init.lua]], "rb")
assert_true(init_file ~= nil, "Yazi init.lua available for mouse behavior test")
local init_text = init_file:read("*a")
init_file:close()
local click_body = init_text:match("(function Tabs:click%(event, up%).-\nend)")
assert_true(click_body ~= nil, "Native Tabs:click handler exists")
Tabs = {}
WgdotYaziTabIndexAtX = function(_, x) return x == 10 and 1 or x == 20 and 2 or nil end
WgdotYaziFinishTabDrag = function() end
WgdotYaziPluginArgs = function(verb, values)
    return verb .. " " .. encoded_plugin_arg(values[1])
end
assert(load(click_body))()
set_tabs({ { [[C:\Safe]], "First" }, { [[C:\Drafting]], "Second" } })
state.live = {}

local function mouse_action(button, x, up)
    Tabs:click({
        x = x,
        is_left = button == "left",
        is_middle = button == "middle",
        is_right = button == "right",
    }, up or false)
end

local function dispatched_mouse_plugin(verb, x)
    mouse_action(verb == "pin" and "middle" or "right", x)
    local emitted = table.remove(events)
    assert_true(emitted ~= nil, "Mouse tab action emitted a plugin request")
    assert_eq(emitted[1], "plugin", "Mouse tab action uses native plugin event")
    assert_eq(#emitted[2], 2, "Tab action sends exactly two positional plugin arguments")
    assert_eq(emitted[2][1], "tab-workspaces", "Mouse tab action targets tab-workspaces")
    local action, value = emitted[2][2]:match("^(%S+) (%S+)$")
    assert_eq(action, verb, "Mouse button maps to expected tab action")
    local id = x == 10 and tostring(cx.tabs[1].id.value) or tostring(cx.tabs[2].id.value)
    assert_eq(value, encoded_plugin_arg(id), "Mouse tab action serializes hovered native ID")
    module:entry { args = { action, value } }
end

local original_focus = cx.tabs.idx
dispatched_mouse_plugin("pin", 10)
assert_true(published["wgdot-yazi-pins"][tostring(cx.tabs[1].id.value)],
    "Middle-click pins focused tab")
dispatched_mouse_plugin("pin", 10)
assert_true(not published["wgdot-yazi-pins"][tostring(cx.tabs[1].id.value)],
    "Middle-click unpins focused tab")
dispatched_mouse_plugin("pin", 20)
assert_eq(cx.tabs.idx, original_focus, "Middle-click inactive tab preserves focus")
assert_true(published["wgdot-yazi-pins"][tostring(cx.tabs[2].id.value)],
    "Middle-click pins inactive tab")
dispatched_mouse_plugin("pin", 20)
assert_true(not published["wgdot-yazi-pins"][tostring(cx.tabs[2].id.value)],
    "Middle-click unpins inactive tab")

inputs[#inputs + 1] = "Mouse Renamed"
dispatched_mouse_plugin("rename-tab", 20)
assert_eq(cx.tabs.idx, original_focus, "Right-click inactive tab preserves focus")
assert_eq(tostring(events[#events][2].tab), tostring(cx.tabs[2].id.value),
    "Right-click passes inactive target to native rename")
drain()
assert_eq(cx.tabs[2].pref.name, "Mouse Renamed", "Right-click renames hovered tab")
assert_eq(cx.tabs[1].pref.name, "First", "Right-click never renames focused tab")

mouse_action("left", 20, false)
assert_eq(events[#events][1], "tab_switch", "Left-click still switches tabs")
drain()
assert_eq(cx.tabs.idx, 2, "Left-click selects hovered tab")
mouse_action("left", 20, true)
assert_eq(#events, 0, "Left-click release does not perform another tab action")
print("Yazi tab mouse interaction smoke test passed")

io.open = native_open
print("Yazi tab-workspaces behavioral smoke test passed")
