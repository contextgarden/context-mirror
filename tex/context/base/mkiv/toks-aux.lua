if not modules then modules = { } end modules ['toks-aux'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, tostring = type, tostring
local max = math.max
local formatters, gsub = string.formatters, string.gsub

interfaces.implement {
    name      = "showluatokens",
    public    = true,
    protected = true,
    actions   = function()
        local f0 = formatters["%s: %s"]
        local nl = logs.newline
        local wr = logs.writer
        local t  = token.peek_next() -- local t = token.scan_next() token.put_back(t)
        local n  = ""
        local w  = ""
        local c  = t.cmdname
        if c == "left_brace" then
            w = "given token list"
            t = token.scan_toks(false)
        elseif c == "register_toks" then
            token.scan_next()
            w = "token register"
            n = t.csname or t.index
            t = tex.gettoks(n,true)
        elseif c == "internal_toks" then
            token.scan_next()
            w = "internal token variable"
            n = t.csname or t.index
            t = tex.gettoks(n,true)
        else
            if t.protected then
                w = "protected control sequence"
            else
                w = "control sequence"
            end
            n = token.scan_csname()
            t = token.get_meaning(n,true)
        end
        wr(f0(w,n))
        nl()
        if type(t) == "table" then
            local w1 = 4
            local w2 = 1
            local w3 = 3
            local w4 = 3
            for i=1,#t do
                local ti = t[i]
                w1 = max(w1,#tostring(ti.id))
                w2 = max(w2,#tostring(ti.command))
                w3 = max(w3,#tostring(ti.index))
                w4 = max(w4,#ti.cmdname)
            end
            local f1 = formatters["%" .. w1 .. "i  %" .. w2 .. "i  %" .. w3 .. "i  %-" .. w4 .. "s  %s"]
            local f2 = formatters["%" .. w1 .. "i  %" .. w2 .. "i  %" .. w3 .. "i  %-" .. w4 .. "s"]
            local f3 = formatters["%" .. w1 .. "i  %" .. w2 .. "i  %" .. w3 .. "i  %-" .. w4 .. "s  %C"]
            for i=1,#t do
                local ti = t[i]
                local cs = ti.csname
                local id = ti.id
                local ix = ti.index
                local cd = ti.command
                local cn = gsub(ti.cmdname,"_"," ")
                if cs then
                    wr(f1(id,cd,ix,cn,cs))
                elseif cn == "letter" or cn == "other_char" then
                    wr(f3(id,cd,ix,cn,ix))
                else
                    wr(f2(id,cd,ix,cn))
                    if cn == "end_match" then
                        wr("-------")
                    end
                end
            end
            nl()
        end
    end
}
