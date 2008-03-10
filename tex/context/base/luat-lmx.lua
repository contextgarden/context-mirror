-- filename : luat-lmx.lua
-- comment  : companion to luat-lmx.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['luat-mlx'] = 1.001

-- we can now use l-xml, and we can also use lpeg

lmx = { }

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
    return input.texdatablob(texmf.instance, filename)
end

lmx.converting = false

function lmx.convert(template,result) -- todo: use lpeg instead
    if not lmx.converting then -- else, if error then again tex error and loop
        local data = input.texdatablob(texmf.instance, template)
        local f = false
        if result then
            f = io.open(result,"w")
            function lmx.print(str) f:write(str) end
        else
            lmx.print = io.write
        end
        function lmx.variable(str)
            return lmx.variables[str] or ""
        end
        function lmx.escape(str)
            return string.gsub(str:gsub('&','&amp;'),'[<>"]',lmx.escapes)
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
        data = data:gsub("<%?lmx%-include%s+(.-)%s-%?>", function(filename)
            return lmx.loadedfile(filename)
        end)
        local definitions =  { }
        data = data:gsub("<%?lmx%-define%-begin%s+(%S-)%s-%?>(.-)<%?lmx%-define%-end%s-%?>", function(tag,content)
            definitions[tag] = content
            return ""
        end)
        data = data:gsub("<%?lmx%-resolve%s+(%S-)%s-%?>", function(tag)
            return definitions[tag] or ""
        end)
        data = data:gsub("%c%s-(<%?lua .-%?>)%s-%c", function(lua)
            return "\n" .. lua .. " "
        end)
        data = string.gsub(data .. "<?lua ?>","(.-)<%?lua%s+(.-)%?>", function(txt, lua)
            txt = txt:gsub("%c+", "\\n")
            txt = txt:gsub('"'  , '\\"')
            txt = txt:gsub("'"  , "\\'")
         -- txt = string.gsub(txt, "([\'\"])", { ["'"] = '\\"', ['"'] = "\\'" } )
            return "p(\"" .. txt .. "\")\n" .. lua .. "\n"
        end)
        lmx.converting = true
        data = "local p,v,e,t,pv,tv = lmx.print,lmx.variable,lmx.escape,lmx.type,lmx.pv,lmx.tv " .. data
        assert(loadstring(data))()
        lmx.converting = false
        if f then
            f:close()
        end
    end
end

-- these can be overloaded; we assume that the os handles filename associations

lmx.lmxfile   = function(filename)     return filename  end
lmx.htmfile   = function(filename)     return filename  end

if environment.platform == "windows" then
    lmx.popupfile = function(filename) os.execute("start " .. filename) end
else
    lmx.popupfile = function(filename) os.execute(filename) end
end

function lmx.show(name)
    local lmxfile = lmx.lmxfile(name)
    local htmfile = lmx.htmfile(name)
    if lmxfile == htmfile then
        htmfile = string.gsub(lmxfile, "%.%a+$", "html")
    end
    lmx.convert(lmxfile, htmfile)
    lmx.popupfile(htmfile)
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
