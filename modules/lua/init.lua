-- Copyright 2007-2020 Mitchell mitchell.att.foicica.com. See LICENSE.

local M = {}

--[[ This comment is for LuaDoc.
---
-- The lua module.
-- It provides utilities for editing Lua code.
module('_M.lua')]]

-- Autocompletion and documentation.

-- Returns a function that, when called from a Textadept Lua file or the Lua
-- command entry, returns the given Textadept tags or API file for use in
-- autocompletion and documentation.
-- @param filename Textadept tags or api file to return.
local function ta_api(filename)
  return function()
    if (buffer.filename or ''):find('^'.._HOME:gsub('%p', '%%%0')) or
       (buffer.filename or ''):find('^'.._USERHOME:gsub('%p', '%%%0')) or
       buffer == ui.command_entry then
      return filename
    end
  end
end

---
-- List of "fake" ctags files (or functions that return such files) to use for
-- autocompletion.
-- The kind 'm' is recognized as a module, 'f' as a function, 't' as a table and
-- 'F' as a module or table field.
-- The *modules/lua/tadoc.lua* script can generate *tags* and
-- [*api*](#textadept.editing.api_files) files for Lua modules via LuaDoc.
-- @class table
-- @name tags
M.tags = {
  _HOME..'/modules/lua/tags', _USERHOME..'/modules/lua/tags',
  ta_api(_HOME..'/modules/lua/ta_tags')
}

---
-- Map of expression patterns to their types.
-- Used for type-hinting when showing autocompletions for variables.
-- Expressions are expected to match after the '=' sign of a statement.
-- @class table
-- @name expr_types
-- @usage _M.lua.expr_types['^spawn%b()%s*$'] = 'proc'
M.expr_types = {['^[\'"]'] = 'string', ['^io%.p?open%s*%b()%s*$'] = 'file'}

local XPM = textadept.editing.XPM_IMAGES
local xpms = {m = XPM.CLASS, f = XPM.METHOD, F = XPM.VARIABLE, t = XPM.TYPEDEF}

textadept.editing.autocompleters.lua = function()
  local list = {}
  -- Retrieve the symbol behind the caret.
  local line, pos = buffer:get_cur_line()
  local symbol, op, part = line:sub(1, pos):match('([%w_%.]-)([%.:]?)([%w_]*)$')
  if symbol == '' and part == '' then return nil end -- nothing to complete
  symbol, part = symbol:gsub('^_G%.?', ''), part ~= '_G' and part or ''
  -- Attempt to identify string type and file type symbols.
  local buffer = buffer
  local assignment = '%f[%w_]'..symbol:gsub('(%p)', '%%%1')..'%s*=%s*(.*)$'
  for i = buffer:line_from_position(buffer.current_pos) - 1, 0, -1 do
    local expr = buffer:get_line(i):match(assignment)
    if expr then
      for patt, type in pairs(M.expr_types) do
        if expr:find(patt) then symbol = type break end
      end
    end
  end
  -- Search through ctags for completions for that symbol.
  local name_patt = '^'..part
  local sep = string.char(buffer.auto_c_type_separator)
  for i = 1, #M.tags do
    local file = M.tags[i]
    if type(file) == 'function' then file = file() end
    if file and lfs.attributes(file) then
      for tag_line in io.lines(file) do
        local name = tag_line:match('^%S+')
        if name:find(name_patt) and not list[name] then
          local fields = tag_line:match(';"\t(.*)$')
          local k, class = fields:sub(1, 1), fields:match('class:(%S+)') or ''
          if class == symbol and (op ~= ':' or k == 'f') then
            list[#list + 1] = string.format('%s%s%d', name, sep, xpms[k])
            list[name] = true
          end
        end
      end
    end
  end
  if #list == 1 and list[1]:find(name_patt..'%?') then return nil end
  return #part, list
end

textadept.editing.api_files.lua = {
  _HOME..'/modules/lua/api', _USERHOME..'/modules/lua/api',
  ta_api(_HOME..'/modules/lua/ta_api')
}

-- Commands.

---
-- Container for Lua-specific key bindings.
-- @class table
-- @name _G.keys.lua
keys.lua = {}

-- Snippets.

if type(snippets) == 'table' then
---
-- Container for Lua-specific snippets.
-- @class table
-- @name _G.snippets.lua
  snippets.lua = {
    func = 'function %1(name)(%2(args))\n\t%0\nend',
    ['if'] = 'if %1 then\n\t%0\nend',
    eif = 'elseif %1 then\n\t',
    ['for'] = 'for %1(i) = %2(1), %3(10)%4(, %5(-1)) do\n\t%0\nend',
    forp = 'for %1(k), %2(v) in pairs(%3(t)) do\n\t%0\nend',
    fori = 'for %1(i), %2(v) in ipairs(%3(t)) do\n\t%0\nend',
    ['while'] = 'while %1 do\n\t%0\nend',
    ['repeat'] = 'repeat\n\t%0\nuntil %1',
    ['do'] = 'do\n\t%0\nend',
  }
end

return M
