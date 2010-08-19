if not modules then modules = { } end modules ['trac-lmx'] = {
    version   = 1.002,
    comment   = "companion to trac-lmx.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: use lpeg instead (although not really needed)

local gsub, format, concat, byte = string.gsub, string.format, table.concat, string.byte

lmx                = lmx or { }
local lmx          = lmx

lmx.variables      = lmx.variables or { } -- global, shared
local lmxvariables = lmx.variables

local escapes = {
    ['&'] = '&amp;',
    ['<'] = '&lt;',
    ['>'] = '&gt;',
    ['"'] = '&quot;'
}

-- variables

lmxvariables['title-default']           = 'ConTeXt LMX File'
lmxvariables['title']                   = lmx.variables['title-default']
lmxvariables['color-background-green']  = '#4F6F6F'
lmxvariables['color-background-blue']   = '#6F6F8F'
lmxvariables['color-background-yellow'] = '#8F8F6F'
lmxvariables['color-background-purple'] = '#8F6F8F'
lmxvariables['color-background-body']   = '#808080'
lmxvariables['color-background-main']   = '#3F3F3F'
lmxvariables['color-background-one']    = lmxvariables['color-background-green']
lmxvariables['color-background-two']    = lmxvariables['color-background-blue']

function lmx.set(key, value)
    lmxvariables[key] = value
end

function lmx.get(key)
    return lmxvariables[key] or ""
end

-- helpers

local variables, result = { } -- we assume no nesting

local function do_print(one,two,...)
    if two then
        result[#result+1] = concat { one, two, ... }
    else
        result[#result+1] = one
    end
end

local function do_escape(str)
    str = tostring(str)
    str = gsub(str,'&','&amp;')
    str = gsub(str,'[<>"]',escapes)
    return str
end

local function do_urlescaped(str)
    return (gsub(str,"[^%a%d]",format("%%0x",byte("%1"))))
end

local function do_type(str)
    if str then do_print("<tt>" .. do_escape(str) .. "</tt>") end
end

local function do_variable(str)
    return variables[str] or lmxvariables[str] -- or format("<!-- unset lmx instance variable: %s -->",str or "?")
end

function lmx.loadedfile(name)
    name = (resolvers and resolvers.find_file and resolvers.find_file(name)) or name
    return io.loaddata(name)
end

local function do_include(filename)
    local stylepath = do_variable('includepath')
    local data = lmx.loadedfile(filename)
    if (not data or data == "") and stylepath ~= "" then
        data = lmx.loadedfile(file.join(stylepath,filename))
    end
    if not data or data == "" then
        data = format("<!-- unknown lmx include file: %s -->",filename)
    end
    return data
end

lmx.print     = do_print
lmx.type      = do_type
lmx.escape    = do_escape
lmx.urlescape = do_escape
lmx.variable  = do_variable
lmx.include   = do_include

function lmx.pv(str)
    do_print(do_variable(str) or "")
end

function lmx.tv(str)
    lmx.type(do_variable(str) or "")
end

local template = [[
    local definitions = { }
    local p, v, e, t, pv, tv = lmx.print, lmx.variable, lmx.escape, lmx.type, lmx.pv, lmx.tv
    %s
]]

local cache = { }

local trace = false

function lmx.new(data,variables)
    data = data or ""
    local known = cache[data]
    if not known then
        local definitions = { }
        data = gsub(data,"<%?lmx%-include%s+(.-)%s-%?>", function(filename)
            return lmx.include(filename)
        end)
        local definitions =  { }
        data = gsub(data,"<%?lmx%-define%-begin%s+(%S-)%s-%?>(.-)<%?lmx%-define%-end%s-%?>", function(tag,content)
            definitions[tag] = content
            return ""
        end)
        data = gsub(data,"<%?lmx%-resolve%s+(%S-)%s-%?>", function(tag)
            return definitions[tag] or ""
        end)
        data = gsub(data .. "<?lua ?>","(.-)<%?lua%s+(.-)%s*%?>", function(txt,lua)
            txt = gsub(txt,"%c+","\n")
            return format("p(%q)%s ",txt,lua) -- nb! space
        end)
        data = format(template,data)
        known = {
            data = trace and data,
            variables = variables or { },
            converter = loadstring(data),
        }
    elseif variables then
        known.variables = variables
    end
    return known, known.variables
end

function lmx.reset(self)
    self.variables = { }
end

function lmx.result(self)
    if trace then
        return self.data
    else
        variables, result = self.variables, { }
        self.converter()
        return concat(result)
    end
end

-- file converter

local loaded = { }

function lmx.convert(templatefile,resultfile,variables)
    local data = loaded[templatefile]
    if not data then
        data = lmx.new(lmx.loadedfile(templatefile),variables)
        loaded[template] = data
    elseif variables then
        data.variables = variables
    end
    local result = lmx.result(data)
    if resultfile then
        io.savedata(resultfile,result)
    else
        return lmx.result(data,result)
    end
end

-- these can be overloaded; we assume that the os handles filename associations

lmx.lmxfile = function(filename) return filename end -- beware, these can be set!
lmx.htmfile = function(filename) return filename end -- beware, these can be set!

if os.type == "windows" then
    lmx.popupfile = function(filename) os.execute("start " .. filename) end
else
    lmx.popupfile = function(filename) os.execute(filename) end
end

function lmx.make(name,variables)
    local lmxfile = lmx.lmxfile(name)
    local htmfile = lmx.htmfile(name)
    if lmxfile == htmfile then
        htmfile = gsub(lmxfile, "%.%a+$", "html")
    end
    lmx.convert(lmxfile,htmfile,variables)
    return htmfile
end

function lmx.show(name,variables)
    local htmfile = lmx.make(name,variables)
    lmx.popupfile(htmfile)
    return htmfile
end

-- test

--~ print(lmx.result(lmx.new(io.loaddata("t:/sources/context-timing.lmx"))))

-- command line

if arg then
    if     arg[1] == "--show"    then if arg[2] then lmx.show   (arg[2])                        end
    elseif arg[1] == "--convert" then if arg[2] then lmx.convert(arg[2], arg[3] or "temp.html") end
    end
end
