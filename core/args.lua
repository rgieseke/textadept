-- Copyright 2007-2020 Mitchell mitchell.att.foicica.com. See LICENSE.

local M = {}

--[[ This comment is for LuaDoc.
---
-- Processes command line arguments for Textadept.
-- @field _G.events.ARG_NONE (string)
--   Emitted when no command line arguments are passed to Textadept on startup.
module('args')]]

events.ARG_NONE = 'arg_none'

-- Contains registered command line switches.
-- @class table
-- @name switches
local switches = {}

---
-- Registers a command line switch with short and long versions *short* and
-- *long*, respectively. *narg* is the number of arguments the switch accepts,
-- *f* is the function called when the switch is tripped, and *description* is
-- the switch's description when displaying help.
-- @param short The string short version of the switch.
-- @param long The string long version of the switch.
-- @param narg The number of expected parameters for the switch.
-- @param f The Lua function to run when the switch is tripped. It is passed
--   *narg* string arguments.
-- @param description The string description of the switch for command line
--   help.
-- @name register
function M.register(short, long, narg, f, description)
  local switch = {
    narg = assert_type(narg, 'number', 3), f = assert_type(f, 'function', 4),
    description = assert_type(description, 'string', 5)
  }
  switches[assert_type(short, 'string', 1)] = switch
  switches[assert_type(long, 'string', 2)] = switch
end

-- Processes command line argument table *arg*, handling switches previously
-- defined using `args.register()` and treating unrecognized arguments as
-- filenames to open.
-- Emits an `ARG_NONE` event when no arguments are present unless
-- *no_emit_arg_none* is `true`.
-- @param arg Argument table.
-- @see register
-- @see _G.events
local function process(arg, no_emit_arg_none)
  local no_args = true
  local i = 1
  while i <= #arg do
    local switch = switches[arg[i]]
    if switch then
      switch.f(table.unpack(arg, i + 1, i + switch.narg))
      i = i + switch.narg
    else
      local filename = lfs.abspath(arg[i], arg[-1] or lfs.currentdir())
      if lfs.attributes(filename, 'mode') ~= 'directory' then
        io.open_file(filename)
      else
        lfs.chdir(filename)
      end
      no_args = false
    end
    i = i + 1
  end
  if no_args and not no_emit_arg_none then events.emit(events.ARG_NONE) end
end
events.connect(events.INITIALIZED, function() if arg then process(arg) end end)
-- Undocumented, single-instance event handler for forwarding arguments.
events.connect('command_line', function(arg) process(arg, true) end)

if not CURSES then
  -- Shows all registered command line switches on the command line.
  M.register('-h', '--help', 0, function()
    print('Usage: textadept [args] [filenames]')
    local list = {}
    for name in pairs(switches) do list[#list + 1] = name end
    table.sort(
      list, function(a, b) return a:match('[^-]+') < b:match('[^-]+') end)
    for _, name in ipairs(list) do
      local switch = switches[name]
      print(string.format(
        '  %s [%d args]: %s', name, switch.narg, switch.description))
    end
    os.exit()
  end, 'Shows this')
  -- Shows Textadept version and copyright on the command line.
  M.register('-v', '--version', 0, function()
    print(_RELEASE .. '\n' .. _COPYRIGHT)
    quit()
  end, 'Prints Textadept version and copyright')
  -- After Textadept finishes initializing and processes arguments, remove the
  -- help and version switches in order to prevent another instance from sending
  -- '-h', '--help', '-v', and '--version' to the first instance, killing the
  -- latter.
  events.connect(events.INITIALIZED, function()
    switches['-h'], switches['--help'] = nil, nil
    switches['-v'], switches['--version'] = nil, nil
  end)
end

-- Set `_G._USERHOME`.
-- This needs to be set as soon as possible since the processing of arguments is
-- positional.
_USERHOME = os.getenv(not WIN32 and 'HOME' or 'USERPROFILE') .. '/.textadept'
for i, switch in ipairs(arg) do
  if (switch == '-u' or switch == '--userhome') and arg[i + 1] then
    _USERHOME = arg[i + 1]
    break
  end
end
local mode = lfs.attributes(_USERHOME, 'mode')
assert(not mode or mode == 'directory', '"%s" is not a directory', _USERHOME)
if not mode then
  assert(lfs.mkdir(_USERHOME), 'cannot create "%s"', _USERHOME)
end
local user_init = _USERHOME .. '/init.lua'
mode = lfs.attributes(user_init, 'mode')
assert(not mode or mode == 'file', '"%s" is not a file (%s)', user_init, mode)
if not mode then
  assert(io.open(user_init, 'w'), 'unable to create "%s"', user_init):close()
end

-- Placeholders.
M.register('-u', '--userhome', 1, function() end, 'Sets alternate _USERHOME')
M.register('-f', '--force', 0, function() end, 'Forces unique instance')

-- Run unit tests.
-- Note: have them run after the last `events.INITIALIZED` handler so everything
-- is completely initialized (e.g. menus, macro module, etc.).
M.register('-t', '--test', 1, function(patterns)
  events.connect(events.INITIALIZED, function()
    local arg = {}
    for patt in (patterns or ''):gmatch('[^,]+') do arg[#arg + 1] = patt end
    local env = setmetatable({arg = arg}, {__index = _G})
    assert(loadfile(_HOME..'/test/test.lua', 't', env))()
  end)
end, 'Runs unit tests indicated by comma-separated list of patterns (or all)')

return M
