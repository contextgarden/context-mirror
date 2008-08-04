-- filename : meta-pdf.lua
-- comment  : companion to meta-pdf.tex
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

-- This is the third version. Version 1 converted to Lua code,
-- version 2 gsubbed the file into TeX code, and version 3 uses
-- the new lpeg functionality and streams the result into TeX.

-- We will move old stuff to edu.

--~                         old           lpeg 0.4       lpeg 0.5
--~ 100 times test graphic  2.45 (T:1.07) 0.72 (T:0.24)  0.580  (0.560  no table) -- 0.54 optimized for one space (T:0.19)
--~ 100 times big  graphic 10.44          4.30/3.35 nogb 2.914  (2.050  no table) -- 1.99 optimized for one space (T:0.85)
--~ 500 times test graphic                T:1.29         T:1.16 (T:1.10 no table) -- T:1.10

if not versions then versions = { } end versions['meta-pdf'] = 1.003

mptopdf         = { }
mptopdf.parsers = { }
mptopdf.parser  = 'none'

function mptopdf.reset()
    mptopdf.data      = ""
    mptopdf.path      = { }
    mptopdf.stack     = { }
    mptopdf.texts     = { }
    mptopdf.version   = 0
    mptopdf.shortcuts = false
    mptopdf.resetpath()
end

function mptopdf.resetpath()
    mptopdf.stack.close   = false
    mptopdf.stack.path    = { }
    mptopdf.stack.concat  = nil
    mptopdf.stack.special = false
end

mptopdf.reset()

function mptopdf.parsers.none()
    -- no parser set
end

function mptopdf.parse()
    mptopdf.parsers[mptopdf.parser]()
end

-- old code

mptopdf.steps = { }

mptopdf.descapes = {
    ['('] = "\\\\char40 ",
    [')'] = "\\\\char41 ",
    ['"'] = "\\\\char92 "
}

function mptopdf.descape(str)
    str = str:gsub("\\(%d%d%d)",function(n)
        return "\\char" .. tonumber(n,8) .. " "
    end)
    return str:gsub("\\([%(%)\\])",mptopdf.descapes)
end

function mptopdf.steps.descape(str)
    str = str:gsub("\\(%d%d%d)",function(n)
        return "\\\\char" .. tonumber(n,8) .. " "
    end)
    return str:gsub("\\([%(%)\\])",mptopdf.descapes)
end

function mptopdf.steps.strip() -- .3 per expr
    mptopdf.data = mptopdf.data:gsub("^(.-)%%+Page:.-%c+(.*)%s+%a+%s+%%+EOF.*$", function(preamble, graphic)
        local bbox = "0 0 0 0"
        for b in preamble:gmatch("%%%%%a+oundingBox: +(.-)%c+") do
            bbox = b
        end
        local name, version = preamble:gmatch("%%%%Creator: +(.-) +(.-) ")
        mptopdf.version = tostring(version or "0")
        if preamble:find("/hlw{0 dtransform") then
            mptopdf.shortcuts = true
        end
        -- the boundingbox specification needs to come before data, well, not really
        return bbox .. " boundingbox\n" .. "\nbegindata\n" .. graphic .. "\nenddata\n"
    end, 1)
    mptopdf.data = mptopdf.data:gsub("%%%%MetaPostSpecials: +(.-)%c+", "%1 specials\n", 1)
    mptopdf.data = mptopdf.data:gsub("%%%%MetaPostSpecial: +(.-)%c+", "%1 special\n")
    mptopdf.data = mptopdf.data:gsub("%%.-%c+", "")
end

function mptopdf.steps.cleanup()
    if not mptopdf.shortcuts then
        mptopdf.data = mptopdf.data:gsub("gsave%s+fill%s+grestore%s+stroke", "both")
        mptopdf.data = mptopdf.data:gsub("([%d%.]+)%s+([%d%.]+)%s+dtransform%s+exch%s+truncate%s+exch%s+idtransform%s+pop%s+setlinewidth", function(wx,wy)
            if tonumber(wx) > 0 then return wx .. " setlinewidth" else return wy .. " setlinewidth"  end
        end)
        mptopdf.data = mptopdf.data:gsub("([%d%.]+)%s+([%d%.]+)%s+dtransform%s+truncate%s+idtransform%s+setlinewidth%s+pop", function(wx,wy)
            if tonumber(wx) > 0 then return wx .. " setlinewidth" else return wy .. " setlinewidth"  end
        end)
    end
end

function mptopdf.steps.convert()
    mptopdf.data = mptopdf.data:gsub("%c%((.-)%) (.-) (.-) fshow", function(str,font,scale)
        mptopdf.texts[mptopdf.texts+1] = {mptopdf.steps.descape(str), font, scale}
        return "\n" .. #mptopdf.texts .. " textext"
    end)
    mptopdf.data = mptopdf.data:gsub("%[%s*(.-)%s*%]", function(str)
        return str:gsub("%s+"," ")
    end)
    local t
    mptopdf.data = mptopdf.data:gsub("%s*([^%a]-)%s*(%a+)", function(args,cmd)
        if cmd == "textext" then
            t = mptopdf.texts[tonumber(args)]
            return "mps.textext(" ..  "\"" .. t[2] .. "\"," .. t[3] .. ",\"" .. t[1] .. "\")\n"
        else
            return "mps." .. cmd .. "(" .. args:gsub(" +",",") .. ")\n"
        end
    end)
end

function mptopdf.steps.process()
    assert(loadstring(mptopdf.data))() -- () runs the loaded chunk
end

function mptopdf.parsers.gsub()
    mptopdf.steps.strip()
    mptopdf.steps.cleanup()
    mptopdf.steps.convert()
    mptopdf.steps.process()
end

-- end of old code

-- from lua to tex

function mptopdf.pdfcode(str)
    tex.sprint(tex.ctxcatcodes,"\\PDFcode{" .. str .. "}")
end

function mptopdf.texcode(str)
    tex.sprint(tex.ctxcatcodes,str)
end

-- auxiliary functions

function mptopdf.flushconcat()
    if mptopdf.stack.concat then
        mptopdf.pdfcode(table.concat(mptopdf.stack.concat," ") .. " cm")
        mptopdf.stack.concat = nil
    end
end

function mptopdf.flushpath(cmd)
    if #mptopdf.stack.path > 0 then
        local path = { }
        if mptopdf.stack.concat then
            local sx, sy = mptopdf.stack.concat[1], mptopdf.stack.concat[4]
            local rx, ry = mptopdf.stack.concat[2], mptopdf.stack.concat[3]
            local tx, ty = mptopdf.stack.concat[5], mptopdf.stack.concat[6]
            local d = (sx*sy) - (rx*ry)
            local function concat(px, py)
                return (sy*(px-tx)-ry*(py-ty))/d, (sx*(py-ty)-rx*(px-tx))/d
            end
            for _,v in ipairs(mptopdf.stack.path) do
                v[1],v[2] = concat(v[1],v[2])
                if #v == 7 then
                    v[3],v[4] = concat(v[3],v[4])
                    v[5],v[6] = concat(v[5],v[6])
                end
                path[#path+1] = table.concat(v," ")
            end
        else
            for _,v in ipairs(mptopdf.stack.path) do
                path[#path+1] = table.concat(v," ")
            end
        end
        mptopdf.flushconcat()
        mptopdf.texcode("\\MPSpath{" .. table.concat(path," ") .. "}")
        if mptopdf.stack.close then
            mptopdf.texcode("\\MPScode{h " .. cmd .. "}")
        else
            mptopdf.texcode("\\MPScode{" .. cmd .."}")
        end
    end
    mptopdf.resetpath()
end

if input and input.instance then
    function mptopdf.loaded(name)
        local ok, n
        mptopdf.reset()
        ok, mptopdf.data, n = input.loadbinfile(name, 'tex') -- we need a binary load !
        return ok
    end
else
    function mptopdf.loaded(name)
        local f = io.open(name, 'rb')
        if f then
            mptopdf.reset()
            mptopdf.data = f:read('*all')
            f:close()
            return true
        else
            return false
        end
    end
end

if not mptopdf.parse then
    function mptopdf.parse() end -- forward declaration
end

function mptopdf.convertmpstopdf(name)
    if mptopdf.loaded(name) then
        garbagecollector.push()
        input.starttiming(mptopdf)
        mptopdf.parse()
        mptopdf.reset()
        input.stoptiming(mptopdf)
        garbagecollector.pop()
    else
        tex.print("file " .. name .. " not found")
    end
end

-- mp interface

mps = mps or { }

function mps.creator(a, b, c)
    mptopdf.version = tonumber(b)
end

function mps.creationdate(a)
    mptopdf.date= a
end

function mps.newpath()
    mptopdf.stack.path = { }
end

function mps.boundingbox(llx, lly, urx, ury)
    mptopdf.texcode("\\MPSboundingbox{" .. llx .. "}{" .. lly .. "}{" .. urx .. "}{" .. ury .. "}")
end

function mps.moveto(x,y)
    mptopdf.stack.path[#mptopdf.stack.path+1] = {x,y,"m"}
end

function mps.curveto(ax, ay, bx, by, cx, cy)
    mptopdf.stack.path[#mptopdf.stack.path+1] = {ax,ay,bx,by,cx,cy,"c"}
end

function mps.lineto(x,y)
    mptopdf.stack.path[#mptopdf.stack.path+1] = {x,y,"l"}
end

function mps.rlineto(x,y)
    local dx, dy = 0, 0
    if #mptopdf.stack.path > 0 then
        dx, dy = mptopdf.stack.path[#mptopdf.stack.path][1], mptopdf.stack.path[#mptopdf.stack.path][2]
    end
    mptopdf.stack.path[#mptopdf.stack.path+1] = {dx,dy,"l"}
end

function mps.translate(tx,ty)
    mptopdf.pdfcode("1 0 0 0 1 " .. tx .. " " .. ty .. " cm")
end

function mps.scale(sx,sy)
    mptopdf.stack.concat = {sx,0,0,sy,0,0}
end

function mps.concat(sx, rx, ry, sy, tx, ty)
    mptopdf.stack.concat = {sx,rx,ry,sy,tx,ty}
end

function mps.setlinejoin(d)
    mptopdf.pdfcode(d .. " j")
end

function mps.setlinecap(d)
    mptopdf.pdfcode(d .. " J")
end

function mps.setmiterlimit(d)
    mptopdf.pdfcode(d .. " M")
end

function mps.gsave()
    mptopdf.pdfcode("q")
end

function mps.grestore()
    mptopdf.pdfcode("Q")
end

function mps.setdash(...)
    local n = select("#",...)
    mptopdf.pdfcode("[" .. table.concat({...}," ",1,n-1) .. "] " .. select(n,...) .. " d")
end

function mps.resetdash()
    mptopdf.pdfcode("[ ] 0 d")
end

function mps.setlinewidth(d)
    mptopdf.pdfcode(d .. " w")
end

function mps.closepath()
    mptopdf.stack.close = true
end

function mps.fill()
    mptopdf.flushpath('f')
end

function mps.stroke()
    mptopdf.flushpath('S')
end

function mps.both()
    mptopdf.flushpath('B')
end

function mps.clip()
    mptopdf.flushpath('W n')
end

function mps.textext(font, scale, str) -- old parser
    local dx, dy = 0, 0
    if #mptopdf.stack.path > 0 then
        dx, dy = mptopdf.stack.path[1][1], mptopdf.stack.path[1][2]
    end
    mptopdf.flushconcat()
    mptopdf.texcode("\\MPStextext{"..font.."}{"..scale.."}{"..str.."}{"..dx.."}{"..dy.."}")
    mptopdf.resetpath()
end

--~ function mps.handletext(font,scale.str,dx,dy)
--~     local one, two = string.match(str, "^(%d+)::::(%d+)")
--~     if one and two then
--~         mptopdf.texcode("\\MPTOPDFtextext{"..font.."}{"..scale.."}{"..one.."}{"..two.."}{"..dx.."}{"..dy.."}")
--~     else
--~         mptopdf.texcode("\\MPTOPDFtexcode{"..font.."}{"..scale.."}{"..str.."}{"..dx.."}{"..dy.."}")
--~     end
--~ end

if false and ctx and ctx.aux and ctx.aux.definecolor then

    logs.report("mptopdf", "using attribute based mps colors")

    -- does not work due to Q-q mess-up

    function mps.setrgbcolor(r,g,b) -- extra check
        r, g, b = tonumber(r), tonumber(g), tonumber(b) -- needed when we use lpeg
        if r == 0.0123 and g < 0.1 then -- g is extra check
            mptopdf.texcode("\\doresetattribute{transparency}\\MPSspecial{" .. g*10000 .. "}{" .. b*10000 .. "}")
        elseif r == 0.123 and g < 0.1 then -- g is extra check
            mptopdf.texcode("\\doresetattribute{transparency}\\MPSspecial{" .. g* 1000 .. "}{" .. b* 1000 .. "}")
        else
            mptopdf.texcode("\\doresetattribute{transparency}\\dosetattribute{color}{" .. colors.register('color',nil,'rgb',r,g,b) .. "}")
        end
    end

    function mps.setcmykcolor(c,m,y,k)
        mptopdf.texcode("\\doresetattribute{transparency}\\dosetattribute{color}{" .. colors.register('color',nil,'cmyk',tonumber(c),tonumber(m),tonumber(y),tonumber(k)) .. "}")
    end

    function mps.setgray(s)
        mptopdf.texcode("\\doresetattribute{transparency}\\dosetattribute{color}{" .. colors.register('color',nil,'gray',tonumber(s)) .. "}")
    end

else

    function mps.setrgbcolor(r,g,b) -- extra check
        r, g = tonumber(r), tonumber(g) -- needed when we use lpeg
        if r == 0.0123 and g < 0.1 then
            mptopdf.texcode("\\MPSspecial{" .. g*10000 .. "}{" .. b*10000 .. "}")
        elseif r == 0.123 and g < 0.1 then
            mptopdf.texcode("\\MPSspecial{" .. g* 1000 .. "}{" .. b* 1000 .. "}")
        else
            mptopdf.texcode("\\MPSrgb{" .. r .. "}{" .. g .. "}{" .. b .. "}")
        end
    end

    function mps.setcmykcolor(c,m,y,k)
        mptopdf.texcode("\\MPScmyk{" .. c .. "}{" .. m .. "}{" .. y .. "}{" .. k .. "}")
    end

    function mps.setgray(s)
        mptopdf.texcode("\\MPSgray{" .. s .. "}")
    end

end

function mps.specials(version,signal,factor) -- 2.0 123 1000
end

function mps.special(...) -- 7 1 0.5 1 0 0 1 3
    local n = select("#",...)
    mptopdf.texcode("\\MPSbegin\\MPSset{" .. table.concat({...},"}\\MPSset{",2,n) .. "}\\MPSend")
end

function mps.begindata()
end

function mps.enddata()
end

function mps.showpage()
end

mps.n   = mps.newpath       -- n
mps.p   = mps.closepath     -- h
mps.l   = mps.lineto        -- l
mps.r   = mps.rlineto       -- r
mps.m   = mps.moveto        -- m
mps.c   = mps.curveto       -- c
mps.hlw = mps.setlinewidth
mps.vlw = mps.setlinewidth

mps.C   = mps.setcmykcolor  -- k
mps.G   = mps.setgray       -- g
mps.R   = mps.setrgbcolor   -- rg

mps.lj  = mps.setlinejoin   -- j
mps.ml  = mps.setmiterlimit -- M
mps.lc  = mps.setlinecap    -- J
mps.sd  = mps.setdash       -- d
mps.rd  = mps.resetdash

mps.S   = mps.stroke        -- S
mps.F   = mps.fill          -- f
mps.B   = mps.both          -- B
mps.W   = mps.clip          -- W

mps.q   = mps.gsave         -- q
mps.Q   = mps.grestore      -- Q

mps.s   = mps.scale         -- (not in pdf)
mps.t   = mps.concat        -- (not the same as pdf anyway)

mps.P   = mps.showpage

-- experimental

function mps.attribute(id,value)
    mptopdf.texcode("\\attribute " .. id .. "=" .. value .. " ")
--  mptopdf.texcode("\\dompattribute{" .. id .. "}{" .. value .. "}")
end

-- lpeg parser

-- The lpeg based parser is rather optimized for the kind of output
-- that MetaPost produces. It's my first real lpeg code, which may
-- show. Because the parser binds to functions, we define it last.

do -- assumes \let\c\char

    local byte = string.byte
    local digit = lpeg.R("09")
    local spec = digit^2 * lpeg.P("::::") * digit^2
    local text = lpeg.Cc("{") * (
        lpeg.P("\\") * ( (digit * digit * digit) / function(n) return "c" .. tonumber(n,8) end) +
                          lpeg.P(" ")            / function(n) return "\\c32" end + -- never in new mp
                          lpeg.P(1)              / function(n) return "\\c" .. byte(n) end
    ) * lpeg.Cc("}")
    local package = lpeg.Cs(spec + text^0)

    function mps.fshow(str,font,scale) -- lpeg parser
        mps.textext(font,scale,package:match(str))
    end

end

do

    local eol      = lpeg.S('\r\n')^1
    local sp       = lpeg.P(' ')^1
    local space    = lpeg.S(' \r\n')^1
    local number   = lpeg.S('0123456789.-+')^1
    local nonspace = lpeg.P(1-lpeg.S(' \r\n'))^1

    local cnumber = lpeg.C(number)
    local cstring = lpeg.C(nonspace)

    local specials           = (lpeg.P("%%MetaPostSpecials:") * sp * (cstring * sp^0)^0 * eol) / mps.specials
    local special            = (lpeg.P("%%MetaPostSpecial:")  * sp * (cstring * sp^0)^0 * eol) / mps.special
    local boundingbox        = (lpeg.P("%%BoundingBox:")      * sp * (cnumber * sp^0)^4 * eol) / mps.boundingbox
    local highresboundingbox = (lpeg.P("%%HiResBoundingBox:") * sp * (cnumber * sp^0)^4 * eol) / mps.boundingbox

    local setup              = lpeg.P("%%BeginSetup")  * (1 - lpeg.P("%%EndSetup") )^1
    local prolog             = lpeg.P("%%BeginProlog") * (1 - lpeg.P("%%EndProlog"))^1
    local comment            = lpeg.P('%')^1 * (1 - eol)^1

    local curveto            = ((cnumber * sp)^6 * lpeg.P("curveto")            ) / mps.curveto
    local lineto             = ((cnumber * sp)^2 * lpeg.P("lineto")             ) / mps.lineto
    local rlineto            = ((cnumber * sp)^2 * lpeg.P("rlineto")            ) / mps.rlineto
    local moveto             = ((cnumber * sp)^2 * lpeg.P("moveto")             ) / mps.moveto
    local setrgbcolor        = ((cnumber * sp)^3 * lpeg.P("setrgbcolor")        ) / mps.setrgbcolor
    local setcmykcolor       = ((cnumber * sp)^4 * lpeg.P("setcmykcolor")       ) / mps.setcmykcolor
    local setgray            = ((cnumber * sp)^1 * lpeg.P("setgray")            ) / mps.setgray
    local newpath            = (                   lpeg.P("newpath")            ) / mps.newpath
    local closepath          = (                   lpeg.P("closepath")          ) / mps.closepath
    local fill               = (                   lpeg.P("fill")               ) / mps.fill
    local stroke             = (                   lpeg.P("stroke")             ) / mps.stroke
    local clip               = (                   lpeg.P("clip")               ) / mps.clip
    local both               = (                   lpeg.P("gsave fill grestore")) / mps.both
    local showpage           = (                   lpeg.P("showpage")           )
    local setlinejoin        = ((cnumber * sp)^1 * lpeg.P("setlinejoin")        ) / mps.setlinejoin
    local setlinecap         = ((cnumber * sp)^1 * lpeg.P("setlinecap")         ) / mps.setlinecap
    local setmiterlimit      = ((cnumber * sp)^1 * lpeg.P("setmiterlimit")      ) / mps.setmiterlimit
    local gsave              = (                   lpeg.P("gsave")              ) / mps.gsave
    local grestore           = (                   lpeg.P("grestore")           ) / mps.grestore

    local setdash            = (lpeg.P("[") * (cnumber * sp^0)^0 * lpeg.P("]") * sp * cnumber * sp * lpeg.P("setdash")) / mps.setdash
    local concat             = (lpeg.P("[") * (cnumber * sp^0)^6 * lpeg.P("]")                * sp * lpeg.P("concat") ) / mps.concat
    local scale              = (              (cnumber * sp^0)^6                              * sp * lpeg.P("concat") ) / mps.concat

    local fshow              = (lpeg.P("(") * lpeg.C((1-lpeg.P(")"))^1) * lpeg.P(")") * space * cstring * space * cnumber * space * lpeg.P("fshow")) / mps.fshow
    local fshow              = (lpeg.P("(") *
                                    lpeg.Cs( ( lpeg.P("\\(")/"\\050" + lpeg.P("\\)")/"\\051" + (1-lpeg.P(")")) )^1 )
                                * lpeg.P(")") * space * cstring * space * cnumber * space * lpeg.P("fshow")) / mps.fshow

    local setlinewidth_x     = (lpeg.P("0") * sp * cnumber * sp * lpeg.P("dtransform truncate idtransform setlinewidth pop")) / mps.setlinewidth
    local setlinewidth_y     = (cnumber * sp * lpeg.P("0 dtransform exch truncate exch idtransform pop setlinewidth")  ) / mps.setlinewidth

    local c   = ((cnumber * sp)^6 * lpeg.P("c")  ) / mps.curveto -- ^6 very inefficient, ^1 ok too
    local l   = ((cnumber * sp)^2 * lpeg.P("l")  ) / mps.lineto
    local r   = ((cnumber * sp)^2 * lpeg.P("r")  ) / mps.rlineto
    local m   = ((cnumber * sp)^2 * lpeg.P("m")  ) / mps.moveto
    local vlw = ((cnumber * sp)^1 * lpeg.P("vlw")) / mps.setlinewidth
    local hlw = ((cnumber * sp)^1 * lpeg.P("hlw")) / mps.setlinewidth

    local R   = ((cnumber * sp)^3 * lpeg.P("R")  ) / mps.setrgbcolor
    local C   = ((cnumber * sp)^4 * lpeg.P("C")  ) / mps.setcmykcolor
    local G   = ((cnumber * sp)^1 * lpeg.P("G")  ) / mps.setgray

    local lj  = ((cnumber * sp)^1 * lpeg.P("lj") ) / mps.setlinejoin
    local ml  = ((cnumber * sp)^1 * lpeg.P("ml") ) / mps.setmiterlimit
    local lc  = ((cnumber * sp)^1 * lpeg.P("lc") ) / mps.setlinecap

    local n   = lpeg.P("n") / mps.newpath
    local p   = lpeg.P("p") / mps.closepath
    local S   = lpeg.P("S") / mps.stroke
    local F   = lpeg.P("F") / mps.fill
    local B   = lpeg.P("B") / mps.both
    local W   = lpeg.P("W") / mps.clip
    local P   = lpeg.P("P") / mps.showpage

    local q   = lpeg.P("q") / mps.gsave
    local Q   = lpeg.P("Q") / mps.grestore

    local sd  = (lpeg.P("[") * (cnumber * sp^0)^0 * lpeg.P("]") * sp * cnumber * sp * lpeg.P("sd")) / mps.setdash
    local rd  = (                                                                     lpeg.P("rd")) / mps.resetdash

    local s   = (              (cnumber * sp^0)^2                    * lpeg.P("s") ) / mps.scale
    local t   = (lpeg.P("[") * (cnumber * sp^0)^6 * lpeg.P("]") * sp * lpeg.P("t") ) / mps.concat

    -- experimental

    local attribute = ((cnumber * sp)^2 * lpeg.P("attribute")) / mps.attribute
    local A         = ((cnumber * sp)^2 * lpeg.P("A"))         / mps.attribute

    local preamble = (
        prolog + setup +
        boundingbox + highresboundingbox + specials + special +
        comment
    )

    local procset = (
        lj + ml + lc +
        c + l + m + n + p + r +
        A  +
        R + C + G +
        S + F + B + W +
        vlw + hlw +
        Q + q +
        sd + rd +
        t + s +
        fshow +
        P
    )

    local verbose = (
        curveto + lineto + moveto + newpath + closepath + rlineto +
        setrgbcolor + setcmykcolor + setgray +
        attribute +
        setlinejoin + setmiterlimit + setlinecap +
        stroke + fill + clip + both +
        setlinewidth_x + setlinewidth_y +
        gsave + grestore +
        concat + scale +
        fshow +
        setdash + -- no resetdash
        showpage
    )

    -- order matters in terms of speed / we could check for procset first

    local captures_old = ( space + verbose + preamble           )^0
    local captures_new = ( space + procset + preamble + verbose )^0

    function mptopdf.parsers.lpeg()
        if mptopdf.data:find("%%%%BeginResource: procset mpost") then
            captures_new:match(mptopdf.data)
        else
            captures_old:match(mptopdf.data)
        end
    end

end

mptopdf.parser = 'lpeg'
