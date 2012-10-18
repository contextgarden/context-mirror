if not modules then modules = { } end modules ['l-string'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local string = string
local sub, gsub, find, match, gmatch, format, char, byte, rep, lower = string.sub, string.gsub, string.find, string.match, string.gmatch, string.format, string.char, string.byte, string.rep, string.lower
local lpegmatch, S, C, Ct = lpeg.match, lpeg.S, lpeg.C, lpeg.Ct

-- some functions may disappear as they are not used anywhere

if not string.split then

    -- this will be overloaded by a faster lpeg variant

    function string.split(str,pattern)
        local t = { }
        if #str > 0 then
            local n = 1
            for s in gmatch(str..pattern,"(.-)"..pattern) do
                t[n] = s
                n = n + 1
            end
        end
        return t
    end

end

function string.unquoted(str)
    return (gsub(str,"^([\"\'])(.*)%1$","%2"))
end

--~ function stringunquoted(str)
--~     if find(str,"^[\'\"]") then
--~         return sub(str,2,-2)
--~     else
--~         return str
--~     end
--~ end

function string.quoted(str)
    return format("%q",str) -- always "
end

function string.count(str,pattern) -- variant 3
    local n = 0
    for _ in gmatch(str,pattern) do -- not for utf
        n = n + 1
    end
    return n
end

function string.limit(str,n,sentinel) -- not utf proof
    if #str > n then
        sentinel = sentinel or "..."
        return sub(str,1,(n-#sentinel)) .. sentinel
    else
        return str
    end
end

local space    = S(" \t\v\n")
local nospace  = 1 - space
local stripper = space^0 * C((space^0 * nospace^1)^0) -- roberto's code

function string.strip(str)
    return lpegmatch(stripper,str) or ""
end

function string.is_empty(str)
    return not find(str,"%S")
end

local patterns_escapes = {
    ["%"] = "%%",
    ["."] = "%.",
    ["+"] = "%+", ["-"] = "%-", ["*"] = "%*",
    ["["] = "%[", ["]"] = "%]",
    ["("] = "%(", [")"] = "%)",
 -- ["{"] = "%{", ["}"] = "%}"
 -- ["^"] = "%^", ["$"] = "%$",
}

local simple_escapes = {
    ["-"] = "%-",
    ["."] = "%.",
    ["?"] = ".",
    ["*"] = ".*",
}

function string.escapedpattern(str,simple)
    return (gsub(str,".",simple and simple_escapes or patterns_escapes))
end

function string.topattern(str,lowercase,strict)
    if str == "" then
        return ".*"
    else
        str = gsub(str,".",simple_escapes)
        if lowercase then
            str = lower(str)
        end
        if strict then
            return "^" .. str .. "$"
        else
            return str
        end
    end
end


function string.valid(str,default)
    return (type(str) == "string" and str ~= "" and str) or default or nil
end

-- obsolete names:

string.quote   = string.quoted
string.unquote = string.unquoted

-- handy fallback

string.itself  = function(s) return s end

-- also handy (see utf variant)

local pattern = Ct(C(1)^0)

function string.totable(str)
    return lpegmatch(pattern,str)
end
