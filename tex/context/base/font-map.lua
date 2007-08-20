if not modules then modules = { } end modules ['font-map'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Eventually this code will disappear because map files are kind
of obsolete. Some code may move to runtime or auxiliary modules.</p>
--ldx]]--

fonts               = fonts               or { }
fonts.map           = fonts.map           or { }
fonts.map.data      = fonts.map.data      or { }
fonts.map.encodings = fonts.map.encodings or { }
fonts.map.done      = fonts.map.done      or { }
fonts.map.loaded    = fonts.map.loaded    or { }
fonts.map.direct    = fonts.map.direct    or { }
fonts.map.line      = fonts.map.line      or { }

function fonts.map.line.pdfmapline(tag,str)
    return "\\loadmapline[" .. tag .. "][" .. str .. "]"
end

function fonts.map.line.pdftex(e) -- so far no combination of slant and stretch
    if e.name and e.fontfile then
        local fullname = e.fullname or ""
        if e.slant and e.slant ~= 0 then
            if e.encoding then
                return fonts.map.line.pdfmapline("=",string.format('%s %s "%g SlantFont" <%s <%s',e.name,fullname,e.slant,e.encoding,e.fontfile))
            else
                return fonts.map.line.pdfmapline("=",string.format('%s %s "%g SlantFont" <%s',e.name,fullname,e.slant,e.fontfile))
            end
        elseif e.stretch and e.stretch ~= 1 and e.stretch ~= 0 then
            if e.encoding then
                return fonts.map.line.pdfmapline("=",string.format('%s %s "%g ExtendFont" <%s <%s',e.name,fullname,e.stretch,e.encoding,e.fontfile))
            else
                return fonts.map.line.pdfmapline("=",string.format('%s %s "%g ExtendFont" <%s',e.name,fullname,e.stretch,e.fontfile))
            end
        else
            if e.encoding then
                return fonts.map.line.pdfmapline("=",string.format('%s %s <%s <%s',e.name,fullname,e.encoding,e.fontfile))
            else
                return fonts.map.line.pdfmapline("=",string.format('%s %s <%s',e.name,fullname,e.fontfile))
            end
        end
    else
        return nil
    end
end

function fonts.map.flush(backend) -- will also erase the accumulated data
    local flushline = fonts.map.line[backend or "pdftex"] or fonts.map.line.pdftex
    for _, e in pairs(fonts.map.data) do
        tex.sprint(tex.ctxcatcodes,flushline(e))
    end
    fonts.map.data = { }
end

fonts.map.line.dvips     = fonts.map.line.pdftex
fonts.map.line.dvipdfmx  = function() end

function fonts.map.convert_entries(filename)
    if not fonts.map.loaded[filename] then
        fonts.map.data, fonts.map.encodings = fonts.map.load_file(filename,fonts.map.data, fonts.map.encodings)
        fonts.map.loaded[filename] = true
    end
end

function fonts.map.load_file(filename, entries, encodings)
    entries   = entries   or { }
    encodings = encodings or { }
    local f = io.open(filename)
    if f then
        local data = f:read("*a")
        if data then
            for line in data:gmatch("(.-)[\n\t]") do
                if line:find("^[%#%%%s]") then
                    -- print(line)
                else
                    local stretch, slant, name, fullname, fontfile, encoding
                    line = line:gsub('"(.+)"', function(s)
                        stretch = s:find('"([^"]+) ExtendFont"')
                        slant = s:find('"([^"]+) SlantFont"')
                        return ""
                    end)
                    if not name then
                        -- name fullname encoding fontfile
                        name, fullname, encoding, fontfile = line:match("^(%S+)%s+(%S*)[%s<]+(%S*)[%s<]+(%S*)%s*$")
                    end
                    if not name then
                        -- name fullname (flag) fontfile encoding
                        name, fullname, fontfile, encoding = line:match("^(%S+)%s+(%S*)[%d%s<]+(%S*)[%s<]+(%S*)%s*$")
                    end
                    if not name then
                        -- name fontfile
                        name, fontfile = line:match("^(%S+)%s+[%d%s<]+(%S*)%s*$")
                    end
                    if name then
                        if encoding == "" then encoding = nil end
                        entries[name] = {
                            name     = name, -- handy
                            fullname = fullname,
                            encoding = encoding,
                            fontfile = fontfile,
                            slant    = tonumber(slant),
                            stretch  = tonumber(stretch)
                        }
                        encodings[name] = encoding
                    elseif line ~= "" then
                    --  print(line)
                    end
                end
            end
        end
        f:close()
    end
    return entries, encodings
end
