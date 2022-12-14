local spawn = require("awful.spawn")
local gtimer = require("gears.timer")

local lua_executable = os.getenv("LUA")
if lua_executable == nil or lua_executable == "" then
    lua_executable = "lua"
end

-- This file provide a simple, yet flexible, test client.
-- It is used to test the `ruled.client`

local test_client_source = [[
pcall(require, 'luarocks.loader')
local lgi  = require 'lgi'
local GLib = lgi.require('GLib')
local Gdk  = lgi.require('Gdk')
local Gtk  = lgi.require('Gtk', '3.0')
local Gio  = lgi.require('Gio')
Gtk.init()

local function open_window(class, title, options)
    local window = Gtk.Window {
        default_width  = options.default_width  or 100,
        default_height = options.default_height or 100,
        title          = title
    }
    if options.gravity then
        window:set_gravity(tonumber(options.gravity))
    end
    if options.snid and options.snid ~= "" then
        window:set_startup_id(options.snid)
    end
    if options.resize_increment then
        -- This requires Gtk3, but fails with an obscure message with Gtk2.
        -- Produce a better error message instead.
        assert(tonumber(require("lgi").Gtk._version) >= 3, "Gtk 3 required, but not found")
        local geom = Gdk.Geometry {
            width_inc = 200,
            height_inc = 200,
        }
        window:set_geometry_hints(nil, geom, Gdk.WindowHints.RESIZE_INC)
    end
    if options.maximize_before then
        window:maximize()
    elseif options.unminimize_after then
        window:iconify()
    end
    window:set_wmclass(class, class)
    window:show_all()
    if options.maximize_after then
        window:maximize()
    elseif options.unmaximize_after then
        window:unmaximize()
    elseif options.minimize_after then
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, function()
            window:iconify()
        end)
    elseif options.unminimize_after then
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, function()
            window:deiconify()
        end)
    end
    if options.resize_after_width and options.resize_after_height then
       window:resize(
           tonumber(options.resize_after_width), tonumber(options.resize_after_height)
       )
    end
end

local function parse_options(options)
    local result = {}
    for word in string.gmatch(options, "([^,]+)") do
        local key, value = string.match(word, "([^=]+)=?(.*)")
        result[key] = value
    end
    return result
end

-- Start a coroutine for nicer input handling
local coro = coroutine.wrap(function()
    while true do
        local class = coroutine.yield()
        local title = coroutine.yield()
        local options = coroutine.yield()
        open_window(class, title, parse_options(options))
    end
end)
coro()

-- Read lines from stdin and feed them to the coroutine
local stdin = Gio.UnixInputStream.new(0, false)
stdin = Gio.DataInputStream.new(stdin)

local read_start, read_finish
read_start = function()
    stdin:read_line_async(0, nil, read_finish)
end
read_finish = function(...)
    local line, length = stdin.read_line_finish(...)
    if type(length) ~= "number" then
        error("Error reading line: " .. tostring(length))
    end

    local eof = not line -- Behaviour of up-to-date LGI
            or (tostring(line) == "" and #line ~= length) -- (Ab)use uninitialized variable
    if eof then
        Gtk.main_quit()
    else
        coro(tostring(line)) -- tostring() needed for older LGI versions
        read_start()
    end
end

read_start()
Gtk:main{...}
]]

local lgi = require("lgi")
local Gio = lgi.require("Gio")

local initialized = false
local pipe, pid

local function init()
    if initialized then return end
    initialized = true
    local cmd = { lua_executable, "-e", test_client_source }
    local _pid, _, stdin, stdout, stderr = awesome.spawn(cmd, false, true, true, true)
    pipe =  Gio.UnixOutputStream.new(stdin, true)
    pid = _pid
    stdout = Gio.UnixInputStream.new(stdout, true)
    stderr = Gio.UnixInputStream.new(stderr, true)
    spawn.read_lines(stdout, function(...) print("_client", ...) end)
    spawn.read_lines(stderr, function(...) print("_client", ...) end)
end

-- Hack needed for awesome's Startup Notification machinery
local function get_snid(sn_rules, callback)
    local success, snid = spawn({ "/bin/true" }, sn_rules, callback)
    assert(success)
    assert(snid)
    return snid
end

local module = {}

function module.terminate()
    if not initialized then return end

    for _, c in ipairs(client.get()) do
        c:kill()
    end

    pipe:close()
    initialized, pipe = false, nil

    -- Make a copy to avoid the re-initialized race condition.
    local original_pid = pid

    gtimer.delayed_call(function()
        awesome.kill(original_pid, 9)
    end)

    return true
end

local function new(_, class, title, sn_rules, callback, resize_increment, args)
    args  = args or {}
    class = class or "test_app"
    title = title or "Awesome test client"

    init()
    local options = ""
    local snid
    if sn_rules or callback then
        snid = get_snid(sn_rules, callback)
        options = options .. "snid=" .. snid .. ","
    end
    if resize_increment then
        options = options .. "resize_increment,"
    end
    if args.maximize_before then
        options = options .. "maximize_before,"
    end
    if args.maximize_after then
        options = options .. "maximize_after,"
    end
    if args.unmaximize_after then
        options = options .. "unmaximize_after,"
    end
    if args.unminimize_after then
        options = options .. "unminimize_after,"
    end
    if args.minimize_after then
        options = options .. "minimize_after,"
    end

    if args.size then
        options = table.concat {
            options,
            "default_width=",
            args.size.width, ",",
            "default_height=",
            args.size.height, ","
        }
    end
    if args.resize then
        options = table.concat {
            options,
            "resize_after_width=",
            args.resize.width, ",",
            "resize_after_height=",
            args.resize.height, ","
        }
    end
    if args.gravity then
        assert(type(args.gravity)=="number","Use `lgi.Gdk.Gravity.NORTH_WEST`")
        options = options .. "gravity=" .. args.gravity .. ","
    end

    local data = class .. "\n" .. title .. "\n" .. options .. "\n"
    local success, msg = pipe:write_all(data)
    assert(success, tostring(msg))

    return snid
end

return setmetatable(module, {__call = new })

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
