if not modules then modules = { } end modules ['trac-lmx'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local gsub, format, concat = string.gsub, string.format, table.concat

-- we can now use l-xml, and we can also use lpeg

lmx = lmx or { }

lmx.escapes = {
    ['&'] = '&amp;',
    ['<'] = '&lt;',
    ['>'] = '&gt;',
    ['"'] = '&quot;'
}

-- local function p -> ends up in lmx.p, so we need to cast

lmx.variables = { }

lmx.variables['title-default'] = 'LMX File'
lmx.variables['title']         = lmx.variables['title-default']

-- demonstrates: local, *all, gsub using tables, nil or value, loadstring

function lmx.loadedfile(filename)
    return io.loaddata(resolvers.find_file(filename))
end

lmx.converting = false

local templates = { }

function lmx.convert(template,result) -- todo: use lpeg instead
    if not lmx.converting then -- else, if error then again tex error and loop
        local data = templates[template]
        if not data then
            data = lmx.loadedfile(template)
            templates[template] = data
        end
        local text = { }
        function lmx.print(...)
            text[#text+1] = concat({...})
        end
        function lmx.variable(str)
            return lmx.variables[str] or ""
        end
        function lmx.escape(str)
            str = tostring(str)
            str = gsub(str,'&','&amp;')
            str = gsub(str,'[<>"]',lmx.escapes)
            return str
        end
        function lmx.type(str)
            if str then lmx.print("<tt>" .. lmx.escape(str) .. "</tt>") end
        end
        function lmx.pv(str)
            lmx.print(lmx.variable(str))
        end
        function lmx.tv(str)
            lmx.type(lmx.variable(str))
        end
        data = gsub(data,"<%?lmx%-include%s+(.-)%s-%?>", function(filename)
            return lmx.loadedfile(filename)
        end)
        local definitions =  { }
        data = gsub(data,"<%?lmx%-define%-begin%s+(%S-)%s-%?>(.-)<%?lmx%-define%-end%s-%?>", function(tag,content)
            definitions[tag] = content
            return ""
        end)
        data = gsub(data,"<%?lmx%-resolve%s+(%S-)%s-%?>", function(tag)
            return definitions[tag] or ""
        end)
        data = gsub(data,"%c%s-(<%?lua .-%?>)%s-%c", function(lua)
            return "\n" .. lua .. " "
        end)
        data = gsub(data .. "<?lua ?>","(.-)<%?lua%s+(.-)%?>", function(txt, lua)
            txt = gsub(txt,"%c+", "\\n")
            txt = gsub(txt,'"'  , '\\"')
            txt = gsub(txt,"'"  , "\\'")
         -- txt = gsub(txt,"([\'\"])", { ["'"] = '\\"', ['"'] = "\\'" } )
            return "p(\"" .. txt .. "\")\n" .. lua .. "\n"
        end)
        lmx.converting = true
        data = "local p,v,e,t,pv,tv = lmx.print,lmx.variable,lmx.escape,lmx.type,lmx.pv,lmx.tv " .. data
        assert(loadstring(data))()
        lmx.converting = false
        text = concat(text)
        if result then
            io.savedata(result,text)
        else
            return text
        end
    end
end

-- these can be overloaded; we assume that the os handles filename associations

lmx.lmxfile = function(filename) return filename end
lmx.htmfile = function(filename) return filename end

if os.platform == "windows" then
    lmx.popupfile = function(filename) os.execute("start " .. filename) end
else
    lmx.popupfile = function(filename) os.execute(filename) end
end

function lmx.make(name)
    local lmxfile = lmx.lmxfile(name)
    local htmfile = lmx.htmfile(name)
    if lmxfile == htmfile then
        htmfile = gsub(lmxfile, "%.%a+$", "html")
    end
    lmx.convert(lmxfile, htmfile)
    return htmfile
end

function lmx.show(name)
    local htmfile = lmx.make(name)
    lmx.popupfile(htmfile)
    return htmfile
end

-- kind of private

lmx.restorables = { }

function lmx.set(key, value)
    if not lmx.restorables[key] then
        table.insert(lmx.restorables, key)
        lmx.variables['@@' .. key] = lmx.variables[key]
    end
    lmx.variables[key] = value
end

function lmx.get(key)
    return lmx.variables[key] or ""
end

function lmx.restore()
    for _,key in pairs(lmx.restorables) do
        lmx.variables[key] = lmx.variables['@@' .. key]
    end
    lmx.restorables = { }
end

-- command line

if arg then
    if     arg[1] == "--show"    then if arg[2] then lmx.show   (arg[2])                        end
    elseif arg[1] == "--convert" then if arg[2] then lmx.convert(arg[2], arg[3] or "temp.html") end
    end
end
