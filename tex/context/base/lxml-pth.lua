if not modules then modules = { } end modules ['lxml-pth'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat, remove, insert = table.concat, table.remove, table.insert
local type, next, tonumber, tostring, setmetatable, loadstring = type, next, tonumber, tostring, setmetatable, loadstring
local format, lower, gmatch, gsub, find, rep = string.format, string.lower, string.gmatch, string.gsub, string.find, string.rep

--[[ldx--
<p>This module can be used stand alone but also inside <l n='mkiv'/> in
which case it hooks into the tracker code. Therefore we provide a few
functions that set the tracers. Here we overload a previously defined
function.</p>
--ldx]]--

local trace_lpath = false

if trackers then
    trackers.register("xml.lpath", function(v) trace_lpath = v end)
end

local settrace = xml.settrace -- lxml-tab

function xml.settrace(str,value)
    if str == "lpath" then
        trace_lpath = value or false
    else
        settrace(str,value) -- lxml-tab
    end
end

--[[ldx--
<p>We've now arrived at an intersting part: accessing the tree using a subset
of <l n='xpath'/> and since we're not compatible we call it <l n='lpath'/>. We
will explain more about its usage in other documents.</p>
--ldx]]--

local lpathcalls  = 0 -- statistics
local lpathcached = 0 -- statistics

xml.functions   = xml.functions   or { }
xml.expressions = xml.expressions or { }

local functions   = xml.functions
local expressions = xml.expressions

local actions = {
    [10] = "stay",
    [11] = "parent",
    [12] = "subtree root",
    [13] = "document root",
    [14] = "any",
    [15] = "many",
    [16] = "initial",
    [20] = "match",
    [21] = "match one of",
    [22] = "match and attribute eq",
    [23] = "match and attribute ne",
    [24] = "match one of and attribute eq",
    [25] = "match one of and attribute ne",
    [27] = "has attribute",
    [28] = "has value",
    [29] = "fast match",
    [30] = "select",
    [31] = "expression",
    [40] = "processing instruction",
}

-- a rather dumb lpeg

local P, S, R, C, V, Cc = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc

-- instead of using functions we just parse a few names which saves a call
-- later on

local lp_position  = P("position()") / "ps"
local lp_index     = P("index()")    / "id"
local lp_text      = P("text()")     / "tx"
local lp_name      = P("name()")     / "(ns~='' and ns..':'..tg)" -- "((rt.ns~='' and rt.ns..':'..rt.tg) or '')"
local lp_tag       = P("tag()")      / "tg" -- (rt.tg or '')
local lp_ns        = P("ns()")       / "ns" -- (rt.ns or '')
local lp_noequal   = P("!=")         / "~=" + P("<=") + P(">=") + P("==")
local lp_doequal   = P("=")          / "=="
local lp_attribute = P("@")          / "" * Cc("(at['") * R("az","AZ","--","__")^1 * Cc("'] or '')")

local lp_lua_function  = C(R("az","AZ","--","__")^1 * (P(".") * R("az","AZ","--","__")^1)^1) * P("(") / function(t) -- todo: better . handling
    return t .. "("
end

local lp_function  = C(R("az","AZ","--","__")^1) * P("(") / function(t) -- todo: better . handling
    if expressions[t] then
        return "expressions." .. t .. "("
    else
        return "expressions.error("
    end
end

local lparent  = lpeg.P("(")
local rparent  = lpeg.P(")")
local noparent = 1 - (lparent+rparent)
local nested   = lpeg.P{lparent * (noparent + lpeg.V(1))^0 * rparent}
local value    = lpeg.P(lparent * lpeg.C((noparent + nested)^0) * rparent) -- lpeg.P{"("*C(((1-S("()"))+V(1))^0)*")"}

-- if we use a dedicated namespace then we don't need to pass rt and k

local lp_special = (C(P("name")+P("text")+P("tag"))) * value / function(t,s)
    if expressions[t] then
        if s then
            return "expressions." .. t .. "(r,k," .. s ..")"
        else
            return "expressions." .. t .. "(r,k)"
        end
    else
        return "expressions.error(" .. t .. ")"
    end
end

local converter = lpeg.Cs ( (
    lp_position +
    lp_index +
    lp_text + lp_name + -- fast one
    lp_special +
    lp_noequal + lp_doequal +
    lp_attribute +
    lp_lua_function +
    lp_function +
1 )^1 )

-- expressions,root,rootdt,k,e,edt,ns,tg,idx,hsh[tg] or 1

local template = [[
    return function(expressions,r,d,k,e,dt,ns,tg,id,ps)
        local at, tx = e.at or { }, dt[1] or ""
        return %s
    end
]]

local function make_expression(str)
    str = converter:match(str)
    return str, loadstring(format(template,str))()
end

local map = { }

local space                    = S(' \r\n\t')
local squote                   = S("'")
local dquote                   = S('"')
local lparent                  = P('(')
local rparent                  = P(')')
local atsign                   = P('@')
local lbracket                 = P('[')
local rbracket                 = P(']')
local exclam                   = P('!')
local period                   = P('.')
local eq                       = P('==') + P('=')
local ne                       = P('<>') + P('!=')
local star                     = P('*')
local slash                    = P('/')
local colon                    = P(':')
local bar                      = P('|')
local hat                      = P('^')
local valid                    = R('az', 'AZ', '09') + S('_-')
local name_yes                 = C(valid^1 + star) * colon * C(valid^1 + star) -- permits ns:* *:tg *:*
local name_nop                 = Cc("*") * C(valid^1)
local name                     = name_yes + name_nop
local number                   = C((S('+-')^0 * R('09')^1)) / tonumber
local names                    = (bar^0 * name)^1
local morenames                = name * (bar^0 * name)^1
local instructiontag           = P('pi::')
local spacing                  = C(space^0)
local somespace                = space^1
local optionalspace            = space^0
local text                     = C(valid^0)
local value                    = (squote * C((1 - squote)^0) * squote) + (dquote * C((1 - dquote)^0) * dquote)
local empty                    = 1-slash

local is_eq                    = lbracket * atsign * name * eq * value * rbracket
local is_ne                    = lbracket * atsign * name * ne * value * rbracket
local is_attribute             = lbracket * atsign * name              * rbracket
local is_value                 = lbracket *          value             * rbracket
local is_number                = lbracket *          number            * rbracket

local nobracket                = 1-(lbracket+rbracket)  -- must be improved
local is_expression            = lbracket * C(((C(nobracket^1))/make_expression)) * rbracket

local is_expression            = lbracket * (C(nobracket^1))/make_expression * rbracket

local is_one                   =          name
local is_none                  = exclam * name
local is_one_of                =          ((lparent * names * rparent) + morenames)
local is_none_of               = exclam * ((lparent * names * rparent) + morenames)

local stay                     = (period                )
local parent                   = (period * period       ) / function(   ) map[#map+1] = { 11             } end
local subtreeroot              = (slash + hat           ) / function(   ) map[#map+1] = { 12             } end
local documentroot             = (hat * hat             ) / function(   ) map[#map+1] = { 13             } end
local any                      = (star                  ) / function(   ) map[#map+1] = { 14             } end
local many                     = (star * star           ) / function(   ) map[#map+1] = { 15             } end
local initial                  = (hat * hat * hat       ) / function(   ) map[#map+1] = { 16             } end

local match                    = (is_one                ) / function(...) map[#map+1] = { 20, true , ... } end
local match_one_of             = (is_one_of             ) / function(...) map[#map+1] = { 21, true , ... } end
local dont_match               = (is_none               ) / function(...) map[#map+1] = { 20, false, ... } end
local dont_match_one_of        = (is_none_of            ) / function(...) map[#map+1] = { 21, false, ... } end

local match_and_eq             = (is_one     * is_eq    ) / function(...) map[#map+1] = { 22, true , ... } end
local match_and_ne             = (is_one     * is_ne    ) / function(...) map[#map+1] = { 23, true , ... } end
local dont_match_and_eq        = (is_none    * is_eq    ) / function(...) map[#map+1] = { 22, false, ... } end
local dont_match_and_ne        = (is_none    * is_ne    ) / function(...) map[#map+1] = { 23, false, ... } end

local match_one_of_and_eq      = (is_one_of  * is_eq    ) / function(...) map[#map+1] = { 24, true , ... } end
local match_one_of_and_ne      = (is_one_of  * is_ne    ) / function(...) map[#map+1] = { 25, true , ... } end
local dont_match_one_of_and_eq = (is_none_of * is_eq    ) / function(...) map[#map+1] = { 24, false, ... } end
local dont_match_one_of_and_ne = (is_none_of * is_ne    ) / function(...) map[#map+1] = { 25, false, ... } end

local has_attribute            = (is_one  * is_attribute) / function(...) map[#map+1] = { 27, true , ... } end
local has_value                = (is_one  * is_value    ) / function(...) map[#map+1] = { 28, true , ... } end
local dont_has_attribute       = (is_none * is_attribute) / function(...) map[#map+1] = { 27, false, ... } end
local dont_has_value           = (is_none * is_value    ) / function(...) map[#map+1] = { 28, false, ... } end
local position                 = (is_one  * is_number   ) / function(...) map[#map+1] = { 30, true,  ... } end
local dont_position            = (is_none * is_number   ) / function(...) map[#map+1] = { 30, false, ... } end

local expression               = (is_one  * is_expression)/ function(...) map[#map+1] = { 31, true,  ... } end
local dont_expression          = (is_none * is_expression)/ function(...) map[#map+1] = { 31, false, ... } end

local self_expression          = (         is_expression) / function(...) if #map == 0 then map[#map+1] = { 11 } end
                                                                          map[#map+1] = { 31, true,  "*", "*", ... } end
local dont_self_expression     = (exclam * is_expression) / function(...) if #map == 0 then map[#map+1] = { 11 } end
                                                                          map[#map+1] = { 31, false, "*", "*", ... } end

local instruction              = (instructiontag * text ) / function(...) map[#map+1] = { 40,        ... } end
local nothing                  = (empty                 ) / function(   ) map[#map+1] = { 15             } end -- 15 ?
local crap                     = (1-slash)^1

-- a few ugly goodies:

local docroottag               = P('^^')             / function(   ) map[#map+1] = { 12             } end
local subroottag               = P('^')              / function(   ) map[#map+1] = { 13             } end
local roottag                  = P('root::')         / function(   ) map[#map+1] = { 12             } end
local parenttag                = P('parent::')       / function(   ) map[#map+1] = { 11             } end
local childtag                 = P('child::')
local selftag                  = P('self::')

-- there will be more and order will be optimized

local selector = (
    instruction +
--  many + any + -- brrr, not here !
    parent + stay +
    dont_position + position +
    dont_match_one_of_and_eq + dont_match_one_of_and_ne +
    match_one_of_and_eq + match_one_of_and_ne +
    dont_match_and_eq + dont_match_and_ne +
    match_and_eq + match_and_ne +
    dont_expression + expression +
    dont_self_expression + self_expression +
    has_attribute + has_value +
    dont_match_one_of + match_one_of +
    dont_match + match +
    many + any +
    crap + empty
)

local grammar = P { "startup",
    startup  = (initial + documentroot + subtreeroot + roottag + docroottag + subroottag)^0 * V("followup"),
    followup = ((slash + parenttag + childtag + selftag)^0 * selector)^1,
}

local function compose(str)
    if not str or str == "" then
        -- wildcard
        return true
    elseif str == '/' then
        -- root
        return false
    else
        map = { }
        grammar:match(str)
        if #map == 0 then
            return true
        else
            local m = map[1][1]
            if #map == 1 then
                if m == 14 or m == 15 then
                    -- wildcard
                    return true
                elseif m == 12 then
                    -- root
                    return false
                end
            elseif #map == 2 and m == 12 and map[2][1] == 20 then
            --  return { { 29, map[2][2], map[2][3], map[2][4], map[2][5] } }
                map[2][1] = 29
                return { map[2] }
            end
            if m ~= 11 and m ~= 12 and m ~= 13 and m ~= 14 and m ~= 15 and m ~= 16 then
                insert(map, 1, { 16 })
            end
        --  print(gsub(table.serialize(map),"[ \n]+"," "))
            return map
        end
    end
end

local cache = { }

function xml.lpath(pattern,trace)
    lpathcalls = lpathcalls + 1
    if type(pattern) == "string" then
        local result = cache[pattern]
        if result == nil then -- can be false which is valid -)
            result = compose(pattern)
            cache[pattern] = result
            lpathcached = lpathcached + 1
        end
        if trace or trace_lpath then
            xml.lshow(result)
        end
        return result
    else
        return pattern
    end
end

function xml.cached_patterns()
    return cache
end

--  we run out of locals (limited to 200)
--
--  local fallbackreport = (texio and texio.write) or io.write

function xml.lshow(pattern,report)
--      report = report or fallbackreport
    report = report or (texio and texio.write) or io.write
    local lp = xml.lpath(pattern)
    if lp == false then
        report(" -: root\n")
    elseif lp == true then
        report(" -: wildcard\n")
    else
        if type(pattern) == "string" then
            report(format("pattern: %s\n",pattern))
        end
        for k=1,#lp do
            local v = lp[k]
            if #v > 1 then
                local t = { }
                for i=2,#v do
                    local vv = v[i]
                    if type(vv) == "string" then
                        t[#t+1] = (vv ~= "" and vv) or "#"
                    elseif type(vv) == "boolean" then
                        t[#t+1] = (vv and "==") or "<>"
                    end
                end
                report(format("%2i: %s %s -> %s\n", k,v[1],actions[v[1]],concat(t," ")))
            else
                report(format("%2i: %s %s\n", k,v[1],actions[v[1]]))
            end
        end
    end
end

function xml.xshow(e,...) -- also handy when report is given, use () to isolate first e
    local t = { ... }
--      local report = (type(t[#t]) == "function" and t[#t]) or fallbackreport
    local report = (type(t[#t]) == "function" and t[#t]) or (texio and texio.write) or io.write
    if e == nil then
        report("<!-- no element -->\n")
    elseif type(e) ~= "table" then
        report(tostring(e))
    elseif e.tg then
        report(tostring(e) .. "\n")
    else
        for i=1,#e do
            report(tostring(e[i]) .. "\n")
        end
    end
end

--[[ldx--
<p>An <l n='lpath'/> is converted to a table with instructions for traversing the
tree. Hoever, simple cases are signaled by booleans. Because we don't know in
advance what we want to do with the found element the handle gets three arguments:</p>

<lines>
<t>r</t> : the root element of the data table
<t>d</t> : the data table of the result
<t>t</t> : the index in the data table of the result
</lines>

<p> Access to the root and data table makes it possible to construct insert and delete
functions.</p>
--ldx]]--

local functions   = xml.functions
local expressions = xml.expressions

expressions.contains = string.find
expressions.find     = string.find
expressions.upper    = string.upper
expressions.lower    = string.lower
expressions.number   = tonumber
expressions.boolean  = toboolean

expressions.oneof = function(s,...) -- slow
    local t = {...} for i=1,#t do if s == t[i] then return true end end return false
end

expressions.error = function(str)
    xml.error_handler("unknown function in lpath expression",str or "?")
    return false
end

functions.text = function(root,k,n) -- unchecked, maybe one deeper
    local t = type(t)
    if t == "string" then
        return t
    else -- todo n
        local rdt = root.dt
        return (rdt and rdt[k]) or root[k] or ""
    end
end

functions.name = function(d,k,n) -- ns + tg
    local found = false
    n = n or 0
    if not k then
        -- not found
    elseif n == 0 then
        local dk = d[k]
        found = dk and (type(dk) == "table") and dk
    elseif n < 0 then
        for i=k-1,1,-1 do
            local di = d[i]
            if type(di) == "table" then
                if n == -1 then
                    found = di
                    break
                else
                    n = n + 1
                end
            end
        end
    else
        for i=k+1,#d,1 do
            local di = d[i]
            if type(di) == "table" then
                if n == 1 then
                    found = di
                    break
                else
                    n = n - 1
                end
            end
        end
    end
    if found then
        local ns, tg = found.rn or found.ns or "", found.tg
        if ns ~= "" then
            return ns .. ":" .. tg
        else
            return tg
        end
    else
        return ""
    end
end

functions.tag = function(d,k,n) -- only tg
    local found = false
    n = n or 0
    if not k then
        -- not found
    elseif n == 0 then
        local dk = d[k]
        found = dk and (type(dk) == "table") and dk
    elseif n < 0 then
        for i=k-1,1,-1 do
            local di = d[i]
            if type(di) == "table" then
                if n == -1 then
                    found = di
                    break
                else
                    n = n + 1
                end
            end
        end
    else
        for i=k+1,#d,1 do
            local di = d[i]
            if type(di) == "table" then
                if n == 1 then
                    found = di
                    break
                else
                    n = n - 1
                end
            end
        end
    end
    return (found and found.tg) or ""
end

expressions.text = functions.text
expressions.name = functions.name
expressions.tag  = functions.tag

local function traverse(root,pattern,handle,reverse,index,parent,wildcard) -- multiple only for tags, not for namespaces
    if not root then -- error
        return false
    elseif pattern == false then -- root
        handle(root,root.dt,root.ri)
        return false
    elseif pattern == true then -- wildcard
        local rootdt = root.dt
        if rootdt then
            local start, stop, step = 1, #rootdt, 1
            if reverse then
                start, stop, step = stop, start, -1
            end
            for k=start,stop,step do
                if handle(root,rootdt,root.ri or k)            then return false end
                if not traverse(rootdt[k],true,handle,reverse) then return false end
            end
        end
        return false
    elseif root.dt then
        index = index or 1
        local action = pattern[index]
        local command = action[1]
        if command == 29 then -- fast case /oeps
            local rootdt = root.dt
            for k=1,#rootdt do
                local e = rootdt[k]
                local tg = e.tg
                if e.tg then
                    local ns = e.rn or e.ns
                    local ns_a, tg_a = action[3], action[4]
                    local matched = (ns_a == "*" or ns == ns_a) and (tg_a == "*" or tg == tg_a)
                    if not action[2] then matched = not matched end
                    if matched then
                        if handle(root,rootdt,k) then return false end
                    end
                end
            end
        elseif command == 11 then -- parent
            local ep = root.__p__ or parent
            if index < #pattern then
                if not traverse(ep,pattern,handle,reverse,index+1,root) then return false end
            elseif handle(root,rootdt,k) then
                return false
            end
        else
            if (command == 16 or command == 12) and index == 1 then -- initial
            --  wildcard = true
                wildcard = command == 16 -- ok?
                index = index + 1
                action = pattern[index]
                command = action and action[1] or 0 -- something is wrong
            end
            if command == 11 then -- parent
                local ep = root.__p__ or parent
                if index < #pattern then
                    if not traverse(ep,pattern,handle,reverse,index+1,root) then return false end
                elseif handle(root,rootdt,k) then
                    return false
                end
            else
                local rootdt = root.dt
                local start, stop, step, n, dn = 1, #rootdt, 1, 0, 1
                if command == 30 then
                    if action[5] < 0 then
                        start, stop, step = stop, start, -1
                        dn = -1
                    end
                elseif reverse and index == #pattern then
                    start, stop, step = stop, start, -1
                end
                local idx = 0
                local hsh = { } -- this will slooow down the lot
                for k=start,stop,step do -- we used to have functions for all but a case is faster
                    local e = rootdt[k]
                    local ns, tg = e.rn or e.ns, e.tg
                    if tg then
                     -- we can optimize this for simple searches, but it probably does not pay off
                        hsh[tg] = (hsh[tg] or 0) + 1
                        idx = idx + 1
                        if command == 30 then
                            local ns_a, tg_a = action[3], action[4]
                            if tg == tg_a then
                                matched = ns_a == "*" or ns == ns_a
                            elseif tg_a == '*' then
                                matched, multiple = ns_a == "*" or ns == ns_a, true
                            else
                                matched = false
                            end
                            if not action[2] then matched = not matched end
                            if matched then
                                n = n + dn
                                if n == action[5] then
                                    if index == #pattern then
                                        if handle(root,rootdt,root.ri or k) then return false end
                                    else
                                        if not traverse(e,pattern,handle,reverse,index+1,root) then return false end
                                    end
                                    break
                                end
                            elseif wildcard then
                                if not traverse(e,pattern,handle,reverse,index,root,true) then return false end
                            end
                        else
                            local matched, multiple = false, false
                            if command == 20 then -- match
                                local ns_a, tg_a = action[3], action[4]
                                if tg == tg_a then
                                    matched = ns_a == "*" or ns == ns_a
                                elseif tg_a == '*' then
                                    matched, multiple = ns_a == "*" or ns == ns_a, true
                                else
                                    matched = false
                                end
                                if not action[2] then matched = not matched end
                            elseif command == 21 then -- match one of
                                multiple = true
                                for i=3,#action,2 do
                                    local ns_a, tg_a = action[i], action[i+1]
                                    if (ns_a == "*" or ns == ns_a) and (tg == "*" or tg == tg_a) then
                                        matched = true
                                        break
                                    end
                                end
                                if not action[2] then matched = not matched end
                            elseif command == 22 then -- eq
                                local ns_a, tg_a = action[3], action[4]
                                if tg == tg_a then
                                    matched = ns_a == "*" or ns == ns_a
                                elseif tg_a == '*' then
                                    matched, multiple = ns_a == "*" or ns == ns_a, true
                                else
                                    matched = false
                                end
                                matched = matched and e.at[action[6]] == action[7]
                            elseif command == 23 then -- ne
                                local ns_a, tg_a = action[3], action[4]
                                if tg == tg_a then
                                    matched = ns_a == "*" or ns == ns_a
                                elseif tg_a == '*' then
                                    matched, multiple = ns_a == "*" or ns == ns_a, true
                                else
                                    matched = false
                                end
                                if not action[2] then matched = not matched end
                                matched = mached and e.at[action[6]] ~= action[7]
                            elseif command == 24 then -- one of eq
                                multiple = true
                                for i=3,#action-2,2 do
                                    local ns_a, tg_a = action[i], action[i+1]
                                    if (ns_a == "*" or ns == ns_a) and (tg == "*" or tg == tg_a) then
                                        matched = true
                                        break
                                    end
                                end
                                if not action[2] then matched = not matched end
                                matched = matched and e.at[action[#action-1]] == action[#action]
                            elseif command == 25 then -- one of ne
                                multiple = true
                                for i=3,#action-2,2 do
                                    local ns_a, tg_a = action[i], action[i+1]
                                    if (ns_a == "*" or ns == ns_a) and (tg == "*" or tg == tg_a) then
                                        matched = true
                                        break
                                    end
                                end
                                if not action[2] then matched = not matched end
                                matched = matched and e.at[action[#action-1]] ~= action[#action]
                            elseif command == 27 then -- has attribute
                                local ns_a, tg_a = action[3], action[4]
                                if tg == tg_a then
                                    matched = ns_a == "*" or ns == ns_a
                                elseif tg_a == '*' then
                                    matched, multiple = ns_a == "*" or ns == ns_a, true
                                else
                                    matched = false
                                end
                                if not action[2] then matched = not matched end
                                matched = matched and e.at[action[5]]
                            elseif command == 28 then -- has value
                                local edt, ns_a, tg_a = e.dt, action[3], action[4]
                                if tg == tg_a then
                                    matched = ns_a == "*" or ns == ns_a
                                elseif tg_a == '*' then
                                    matched, multiple = ns_a == "*" or ns == ns_a, true
                                else
                                    matched = false
                                end
                                if not action[2] then matched = not matched end
                                matched = matched and edt and edt[1] == action[5]
                            elseif command == 31 then
                                local edt, ns_a, tg_a = e.dt, action[3], action[4]
                                if tg == tg_a then
                                    matched = ns_a == "*" or ns == ns_a
                                elseif tg_a == '*' then
                                    matched, multiple = ns_a == "*" or ns == ns_a, true
                                else
                                    matched = false
                                end
                                if not action[2] then matched = not matched end
                                if matched then
                                    matched = action[6](expressions,root,rootdt,k,e,edt,ns,tg,idx,hsh[tg] or 1)
                                end
                            end
                            if matched then -- combine tg test and at test
                                if index == #pattern then
                                    if handle(root,rootdt,root.ri or k) then return false end
                                    if wildcard then
                                        if multiple then
                                            if not traverse(e,pattern,handle,reverse,index,root,true) then return false end
                                        else
                                         -- maybe or multiple; anyhow, check on (section|title) vs just section and title in example in lxml
                                            if not traverse(e,pattern,handle,reverse,index,root) then return false end
                                        end
                                    end
                                else
                                    if not traverse(e,pattern,handle,reverse,index+1,root) then return false end
                                end
                            elseif command == 14 then -- any
                                if index == #pattern then
                                    if handle(root,rootdt,root.ri or k) then return false end
                                else
                                    if not traverse(e,pattern,handle,reverse,index+1,root) then return false end
                                end
                            elseif command == 15 then -- many
                                if index == #pattern then
                                    if handle(root,rootdt,root.ri or k) then return false end
                                else
                                    if not traverse(e,pattern,handle,reverse,index+1,root,true) then return false end
                                end
                            -- not here : 11
                            elseif command == 11 then -- parent
                                local ep = e.__p__ or parent
                                if index < #pattern then
                                    if not traverse(ep,pattern,handle,reverse,root,index+1) then return false end
                                elseif handle(root,rootdt,k) then
                                    return false
                                end
                            elseif command == 40 and e.special and tg == "@pi@" then -- pi
                                local pi = action[2]
                                if pi ~= "" then
                                    local pt = e.dt[1]
                                    if pt and pt:find(pi) then
                                        if handle(root,rootdt,k) then
                                            return false
                                        end
                                    end
                                elseif handle(root,rootdt,k) then
                                    return false
                                end
                            elseif wildcard then
                                if not traverse(e,pattern,handle,reverse,index,root,true) then return false end
                            end
                        end
                    else
                        -- not here : 11
                        if command == 11 then -- parent
                            local ep = e.__p__ or parent
                            if index < #pattern then
                                if not traverse(ep,pattern,handle,reverse,index+1,root) then return false end
                            elseif handle(root,rootdt,k) then
                                return false
                            end
                            break -- else loop
                        end
                    end
                end
            end
        end
    end
    return true
end

xml.traverse = traverse

--[[ldx--
<p>Next come all kind of locators and manipulators. The most generic function here
is <t>xml.filter(root,pattern)</t>. All registers functions in the filters namespace
can be path of a search path, as in:</p>

<typing>
local r, d, k = xml.filter(root,"/a/b/c/position(4)"
</typing>
--ldx]]--

local traverse, lpath, convert = xml.traverse, xml.lpath, xml.convert

xml.filters = { }

function xml.filters.default(root,pattern)
    local rt, dt, dk
    traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end)
    return dt and dt[dk], rt, dt, dk
end

function xml.filters.attributes(root,pattern,arguments)
    local rt, dt, dk
    traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk = r, d, k return true end)
    local ekat = (dt and dt[dk] and dt[dk].at) or (rt and rt.at)
    if ekat then
        if arguments then
            return ekat[arguments] or "", rt, dt, dk
        else
            return ekat, rt, dt, dk
        end
    else
        return { }, rt, dt, dk
    end
end

function xml.filters.reverse(root,pattern)
    local rt, dt, dk
    traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end, 'reverse')
    return dt and dt[dk], rt, dt, dk
end

function xml.filters.count(root,pattern,everything)
    local n = 0
    traverse(root, lpath(pattern), function(r,d,t)
        if everything or type(d[t]) == "table" then
            n = n + 1
        end
    end)
    return n
end

function xml.filters.elements(root, pattern) -- == all
    local t = { }
    traverse(root, lpath(pattern), function(r,d,k)
        local e = d[k]
        if e then
            t[#t+1] = e
        end
    end)
    return t
end

function xml.filters.texts(root, pattern)
    local t = { }
    traverse(root, lpath(pattern), function(r,d,k)
        local e = d[k]
        if e and e.dt then
            t[#t+1] = e.dt
        end
    end)
    return t
end

function xml.filters.first(root,pattern)
    local rt, dt, dk
    traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end)
    return dt and dt[dk], rt, dt, dk
end

function xml.filters.last(root,pattern)
    local rt, dt, dk
    traverse(root, lpath(pattern), function(r,d,k) rt,dt,dk = r,d,k return true end, 'reverse')
    return dt and dt[dk], rt, dt, dk
end

function xml.filters.index(root,pattern,arguments)
    local rt, dt, dk, reverse, i = nil, nil, nil, false, tonumber(arguments or '1') or 1
    if i and i ~= 0 then
        if i < 0 then
            reverse, i = true, -i
        end
        traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk, i = r, d, k, i-1 return i == 0 end, reverse)
        if i == 0 then
            return dt and dt[dk], rt, dt, dk
        end
    end
    return nil, nil, nil, nil
end

function xml.filters.attribute(root,pattern,arguments)
    local rt, dt, dk
    traverse(root, lpath(pattern), function(r,d,k) rt, dt, dk = r, d, k return true end)
    local ekat = (dt and dt[dk] and dt[dk].at) or (rt and rt.at)
 -- return (ekat and (ekat[arguments] or ekat[gsub(arguments,"^([\"\'])(.*)%1$","%2")])) or ""
    return (ekat and (ekat[arguments] or (find(arguments,"^[\'\"]") and ekat[sub(arguments,2,-2)]))) or ""
end

function xml.filters.text(root,pattern,arguments) -- ?? why index, tostring slow
    local dtk, rt, dt, dk = xml.filters.index(root,pattern,arguments)
    if dtk then -- n
        local dtkdt = dtk.dt
        if not dtkdt then
            return "", rt, dt, dk
        elseif #dtkdt == 1 and type(dtkdt[1]) == "string" then
            return dtkdt[1], rt, dt, dk
        else
            return xml.tostring(dtkdt), rt, dt, dk
        end
    else
        return "", rt, dt, dk
    end
end

function xml.filters.tag(root,pattern,n)
    local tag = ""
    traverse(root, lpath(pattern), function(r,d,k)
        tag = xml.functions.tag(d,k,n and tonumber(n))
        return true
    end)
    return tag
end

function xml.filters.name(root,pattern,n)
    local tag = ""
    traverse(root, lpath(pattern), function(r,d,k)
        tag = xml.functions.name(d,k,n and tonumber(n))
        return true
    end)
    return tag
end

--[[ldx--
<p>For splitting the filter function from the path specification, we can
use string matching or lpeg matching. Here the difference in speed is
neglectable but the lpeg variant is more robust.</p>
--ldx]]--

--  not faster but hipper ... although ... i can't get rid of the trailing / in the path

local P, S, R, C, V, Cc = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc

local slash     = P('/')
local name      = (R("az","AZ","--","__"))^1
local path      = C(((1-slash)^0 * slash)^1)
local argument  = P { "(" * C(((1 - S("()")) + V(1))^0) * ")" }
local action    = Cc(1) * path * C(name) * argument
local attribute = Cc(2) * path * P('@') * C(name)
local direct    = Cc(3) * Cc("../*") * slash^0 * C(name) * argument

local parser    = direct + action + attribute

local filters          = xml.filters
local attribute_filter = xml.filters.attributes
local default_filter   = xml.filters.default

-- todo: also hash, could be gc'd

function xml.filter(root,pattern)
    local kind, a, b, c = parser:match(pattern)
    if kind == 1 or kind == 3 then
        return (filters[b] or default_filter)(root,a,c)
    elseif kind == 2 then
        return attribute_filter(root,a,b)
    else
        return default_filter(root,pattern)
    end
end

--~     slightly faster, but first we need a proper test file
--~
--~     local hash = { }
--~
--~     function xml.filter(root,pattern)
--~         local h = hash[pattern]
--~         if not h then
--~             local kind, a, b, c = parser:match(pattern)
--~             if kind == 1 then
--~                 h = { kind, filters[b] or default_filter, a, b, c }
--~             elseif kind == 2 then
--~                 h = { kind, attribute_filter, a, b, c }
--~             else
--~                 h = { kind, default_filter, a, b, c }
--~             end
--~             hash[pattern] = h
--~         end
--~         local kind = h[1]
--~         if kind == 1 then
--~             return h[2](root,h[2],h[4])
--~         elseif kind == 2 then
--~             return h[2](root,h[2],h[3])
--~         else
--~             return h[2](root,pattern)
--~         end
--~     end

--[[ldx--
<p>The following functions collect elements and texts.</p>
--ldx]]--

-- still somewhat bugged

function xml.collect_elements(root, pattern, ignorespaces)
    local rr, dd = { }, { }
    traverse(root, lpath(pattern), function(r,d,k)
        local dk = d and d[k]
        if dk then
            if ignorespaces and type(dk) == "string" and dk:find("[^%S]") then
                -- ignore
            else
                local n = #rr+1
                rr[n], dd[n] = r, dk
            end
        end
    end)
    return dd, rr
end

function xml.collect_texts(root, pattern, flatten)
    local t = { } -- no r collector
    traverse(root, lpath(pattern), function(r,d,k)
        if d then
            local ek = d[k]
            local tx = ek and ek.dt
            if flatten then
                if tx then
                    t[#t+1] = xml.tostring(tx) or ""
                else
                    t[#t+1] = ""
                end
            else
                t[#t+1] = tx or ""
            end
        else
            t[#t+1] = ""
        end
    end)
    return t
end

function xml.collect_tags(root, pattern, nonamespace)
    local t = { }
    xml.traverse(root, xml.lpath(pattern), function(r,d,k)
        local dk = d and d[k]
        if dk and type(dk) == "table" then
            local ns, tg = e.ns, e.tg
            if nonamespace then
                t[#t+1] = tg -- if needed we can return an extra table
            elseif ns == "" then
                t[#t+1] = tg
            else
                t[#t+1] = ns .. ":" .. tg
            end
        end
    end)
    return #t > 0 and {}
end

--[[ldx--
<p>Often using an iterators looks nicer in the code than passing handler
functions. The <l n='lua'/> book describes how to use coroutines for that
purpose (<url href='http://www.lua.org/pil/9.3.html'/>). This permits
code like:</p>

<typing>
for r, d, k in xml.elements(xml.load('text.xml'),"title") do
    print(d[k])
end
</typing>

<p>Which will print all the titles in the document. The iterator variant takes
1.5 times the runtime of the function variant which is due to the overhead in
creating the wrapper. So, instead of:</p>

<typing>
function xml.filters.first(root,pattern)
    for rt,dt,dk in xml.elements(root,pattern)
        return dt and dt[dk], rt, dt, dk
    end
    return nil, nil, nil, nil
end
</typing>

<p>We use the function variants in the filters.</p>
--ldx]]--

local wrap, yield = coroutine.wrap, coroutine.yield

function xml.elements(root,pattern,reverse)
    return wrap(function() traverse(root, lpath(pattern), yield, reverse) end)
end

function xml.elements_only(root,pattern,reverse)
    return wrap(function() traverse(root, lpath(pattern), function(r,d,k) yield(d[k]) end, reverse) end)
end

function xml.each_element(root, pattern, handle, reverse)
    local ok
    traverse(root, lpath(pattern), function(r,d,k) ok = true handle(r,d,k) end, reverse)
    return ok
end

function xml.process_elements(root, pattern, handle)
    traverse(root, lpath(pattern), function(r,d,k)
        local dkdt = d[k].dt
        if dkdt then
            for i=1,#dkdt do
                local v = dkdt[i]
                if v.tg then handle(v) end
            end
        end
    end)
end

function xml.process_attributes(root, pattern, handle)
    traverse(root, lpath(pattern), function(r,d,k)
        local ek = d[k]
        local a = ek.at or { }
        handle(a)
        if next(a) then -- next is faster than type (and >0 test)
            ek.at = a
        else
            ek.at = nil
        end
    end)
end

--[[ldx--
<p>We've now arrives at the functions that manipulate the tree.</p>
--ldx]]--

function xml.inject_element(root, pattern, element, prepend)
    if root and element then
        local matches, collect = { }, nil
        if type(element) == "string" then
            element = convert(element,true)
        end
        if element then
            collect = function(r,d,k) matches[#matches+1] = { r, d, k, element } end
            traverse(root, lpath(pattern), collect)
            for i=1,#matches do
                local m = matches[i]
                local r, d, k, element, edt = m[1], m[2], m[3], m[4], nil
                if element.ri then
                    element = element.dt[element.ri].dt
                else
                    element = element.dt
                end
                if r.ri then
                    edt = r.dt[r.ri].dt
                else
                    edt = d and d[k] and d[k].dt
                end
                if edt then
                    local be, af
                    if prepend then
                        be, af = xml.copy(element), edt
                    else
                        be, af = edt, xml.copy(element)
                    end
                    for i=1,#af do
                        be[#be+1] = af[i]
                    end
                    if r.ri then
                        r.dt[r.ri].dt = be
                    else
                        d[k].dt = be
                    end
                else
                 -- r.dt = element.dt -- todo
                end
            end
        end
    end
end

-- todo: copy !

function xml.insert_element(root, pattern, element, before) -- todo: element als functie
    if root and element then
        if pattern == "/" then
            xml.inject_element(root, pattern, element, before)
        else
            local matches, collect = { }, nil
            if type(element) == "string" then
                element = convert(element,true)
            end
            if element and element.ri then
                element = element.dt[element.ri]
            end
            if element then
                collect = function(r,d,k) matches[#matches+1] = { r, d, k, element } end
                traverse(root, lpath(pattern), collect)
                for i=#matches,1,-1 do
                    local m = matches[i]
                    local r, d, k, element = m[1], m[2], m[3], m[4]
                    if not before then k = k + 1 end
                    if element.tg then
                        insert(d,k,element) -- untested
--~                         elseif element.dt then
--~                             for _,v in ipairs(element.dt) do -- i added
--~                                 insert(d,k,v)
--~                                 k = k + 1
--~                             end
--~                         end
                    else
                        local edt = element.dt
                        if edt then
                            for i=1,#edt do
                                insert(d,k,edt[i])
                                k = k + 1
                            end
                        end
                    end
                end
            end
        end
    end
end

xml.insert_element_after  =                 xml.insert_element
xml.insert_element_before = function(r,p,e) xml.insert_element(r,p,e,true) end
xml.inject_element_after  =                 xml.inject_element
xml.inject_element_before = function(r,p,e) xml.inject_element(r,p,e,true) end

function xml.delete_element(root, pattern)
    local matches, deleted = { }, { }
    local collect = function(r,d,k) matches[#matches+1] = { r, d, k } end
    traverse(root, lpath(pattern), collect)
    for i=#matches,1,-1 do
        local m = matches[i]
        deleted[#deleted+1] = remove(m[2],m[3])
    end
    return deleted
end

function xml.replace_element(root, pattern, element)
    if type(element) == "string" then
        element = convert(element,true)
    end
    if element and element.ri then
        element = element.dt[element.ri]
    end
    if element then
        traverse(root, lpath(pattern), function(rm, d, k)
            d[k] = element.dt -- maybe not clever enough
        end)
    end
end

local function load_data(name) -- == io.loaddata
    local f, data = io.open(name), ""
    if f then
        data = f:read("*all",'b') -- 'b' ?
        f:close()
    end
    return data
end

function xml.include(xmldata,pattern,attribute,recursive,loaddata)
    -- parse="text" (default: xml), encoding="" (todo)
    -- attribute = attribute or 'href'
    pattern = pattern or 'include'
    loaddata = loaddata or load_data
    local function include(r,d,k)
        local ek, name = d[k], nil
        if not attribute or attribute == "" then
            local ekdt = ek.dt
            name = (type(ekdt) == "table" and ekdt[1]) or ekdt
        end
        if not name then
            if ek.at then
                for a in gmatch(attribute or "href","([^|]+)") do
                    name = ek.at[a]
                    if name then break end
                end
            end
        end
        local data = (name and name ~= "" and loaddata(name)) or ""
        if data == "" then
            xml.empty(d,k)
        elseif ek.at["parse"] == "text" then -- for the moment hard coded
            d[k] = xml.escaped(data)
        else
            local xi = xml.convert(data)
            if not xi then
                xml.empty(d,k)
            else
                if recursive then
                    xml.include(xi,pattern,attribute,recursive,loaddata)
                end
                xml.assign(d,k,xi)
            end
        end
    end
    xml.each_element(xmldata, pattern, include)
end

function xml.strip_whitespace(root, pattern, nolines) -- strips all leading and trailing space !
    traverse(root, lpath(pattern), function(r,d,k)
        local dkdt = d[k].dt
        if dkdt then -- can be optimized
            local t = { }
            for i=1,#dkdt do
                local str = dkdt[i]
                if type(str) == "string" then
                    if str == "" then
                        -- stripped
                    else
                        if nolines then
                            str = gsub(str,"[ \n\r\t]+"," ")
                        end
                        if str == "" then
                            -- stripped
                        else
                            t[#t+1] = str
                        end
                    end
                else
                    t[#t+1] = str
                end
            end
            d[k].dt = t
        end
    end)
end

local function rename_space(root, oldspace, newspace) -- fast variant
    local ndt = #root.dt
    for i=1,ndt or 0 do
        local e = root[i]
        if type(e) == "table" then
            if e.ns == oldspace then
                e.ns = newspace
                if e.rn then
                    e.rn = newspace
                end
            end
            local edt = e.dt
            if edt then
                rename_space(edt, oldspace, newspace)
            end
        end
    end
end

xml.rename_space = rename_space

function xml.remap_tag(root, pattern, newtg)
    traverse(root, lpath(pattern), function(r,d,k)
        d[k].tg = newtg
    end)
end
function xml.remap_namespace(root, pattern, newns)
    traverse(root, lpath(pattern), function(r,d,k)
        d[k].ns = newns
    end)
end
function xml.check_namespace(root, pattern, newns)
    traverse(root, lpath(pattern), function(r,d,k)
        local dk = d[k]
        if (not dk.rn or dk.rn == "") and dk.ns == "" then
            dk.rn = newns
        end
    end)
end
function xml.remap_name(root, pattern, newtg, newns, newrn)
    traverse(root, lpath(pattern), function(r,d,k)
        local dk = d[k]
        dk.tg = newtg
        dk.ns = newns
        dk.rn = newrn
    end)
end

function xml.filters.found(root,pattern,check_content)
    local found = false
    traverse(root, lpath(pattern), function(r,d,k)
        if check_content then
            local dk = d and d[k]
            found = dk and dk.dt and next(dk.dt) and true
        else
            found = true
        end
        return true
    end)
    return found
end

--[[ldx--
<p>Here are a few synonyms.</p>
--ldx]]--

xml.filters.position = xml.filters.index

xml.count    = xml.filters.count
xml.index    = xml.filters.index
xml.position = xml.filters.index
xml.first    = xml.filters.first
xml.last     = xml.filters.last
xml.found    = xml.filters.found

xml.each     = xml.each_element
xml.process  = xml.process_element
xml.strip    = xml.strip_whitespace
xml.collect  = xml.collect_elements
xml.all      = xml.collect_elements

xml.insert   = xml.insert_element_after
xml.inject   = xml.inject_element_after
xml.after    = xml.insert_element_after
xml.before   = xml.insert_element_before
xml.delete   = xml.delete_element
xml.replace  = xml.replace_element

--[[ldx--
<p>The following helper functions best belong to the <t>lmxl-ini</t>
module. Some are here because we need then in the <t>mk</t>
document and other manuals, others came up when playing with
this module. Since this module is also used in <l n='mtxrun'/> we've
put them here instead of loading mode modules there then needed.</p>
--ldx]]--

function xml.gsub(t,old,new)
    local dt = t.dt
    if dt then
        for k=1,#dt do
            local v = dt[k]
            if type(v) == "string" then
                dt[k] = gsub(v,old,new)
            else
                xml.gsub(v,old,new)
            end
        end
    end
end

function xml.strip_leading_spaces(dk,d,k) -- cosmetic, for manual
    if d and k and d[k-1] and type(d[k-1]) == "string" then
        local s = d[k-1]:match("\n(%s+)")
        xml.gsub(dk,"\n"..rep(" ",#s),"\n")
    end
end

function xml.serialize_path(root,lpath,handle)
    local dk, r, d, k = xml.first(root,lpath)
    dk = xml.copy(dk)
    xml.strip_leading_spaces(dk,d,k)
    xml.serialize(dk,handle)
end

--~ xml.escapes   = { ['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['"'] = '&quot;' }
--~ xml.unescapes = { } for k,v in pairs(xml.escapes) do xml.unescapes[v] = k end

--~ function xml.escaped  (str) return (gsub(str,"(.)"   , xml.escapes  )) end
--~ function xml.unescaped(str) return (gsub(str,"(&.-;)", xml.unescapes)) end
--~ function xml.cleansed (str) return (gsub(str,"<.->"  , ''           )) end -- "%b<>"

local P, S, R, C, V, Cc, Cs = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.V, lpeg.Cc, lpeg.Cs

-- 100 * 2500 * "oeps< oeps> oeps&" : gsub:lpeg|lpeg|lpeg
--
-- 1021:0335:0287:0247

-- 10 * 1000 * "oeps< oeps> oeps& asfjhalskfjh alskfjh alskfjh alskfjh ;al J;LSFDJ"
--
-- 1559:0257:0288:0190 (last one suggested by roberto)

--    escaped = Cs((S("<&>") / xml.escapes + 1)^0)
--    escaped = Cs((S("<")/"&lt;" + S(">")/"&gt;" + S("&")/"&amp;" + 1)^0)
local normal  = (1 - S("<&>"))^0
local special = P("<")/"&lt;" + P(">")/"&gt;" + P("&")/"&amp;"
local escaped = Cs(normal * (special * normal)^0)

-- 100 * 1000 * "oeps&lt; oeps&gt; oeps&amp;" : gsub:lpeg == 0153:0280:0151:0080 (last one by roberto)

--    unescaped = Cs((S("&lt;")/"<" + S("&gt;")/">" + S("&amp;")/"&" + 1)^0)
--    unescaped = Cs((((P("&")/"") * (P("lt")/"<" + P("gt")/">" + P("amp")/"&") * (P(";")/"")) + 1)^0)
local normal    = (1 - S"&")^0
local special   = P("&lt;")/"<" + P("&gt;")/">" + P("&amp;")/"&"
local unescaped = Cs(normal * (special * normal)^0)

-- 100 * 5000 * "oeps <oeps bla='oeps' foo='bar'> oeps </oeps> oeps " : gsub:lpeg == 623:501 msec (short tags, less difference)

local cleansed = Cs(((P("<") * (1-P(">"))^0 * P(">"))/"" + 1)^0)

function xml.escaped  (str) return escaped  :match(str) end
function xml.unescaped(str) return unescaped:match(str) end
function xml.cleansed (str) return cleansed :match(str) end

function xml.join(t,separator,lastseparator)
    if #t > 0 then
        local result = { }
        for k,v in pairs(t) do
            result[k] = xml.tostring(v)
        end
        if lastseparator then
            return concat(result,separator or "",1,#result-1) .. (lastseparator or "") .. result[#result]
        else
            return concat(result,separator)
        end
    else
        return ""
    end
end

function xml.statistics()
    return {
        lpathcalls = lpathcalls,
        lpathcached = lpathcached,
    }
end

--  xml.set_text_cleanup(xml.show_text_entities)
--  xml.set_text_cleanup(xml.resolve_text_entities)

--~ xml.lshow("/../../../a/(b|c)[@d='e']/f")
--~ xml.lshow("/../../../a/!(b|c)[@d='e']/f")
--~ xml.lshow("/../../../a/!b[@d!='e']/f")

--~ x = xml.convert([[
--~     <a>
--~         <b n='01'>01</b>
--~         <b n='02'>02</b>
--~         <b n='03'>03</b>
--~         <b n='04'>OK</b>
--~         <b n='05'>05</b>
--~         <b n='06'>06</b>
--~         <b n='07'>ALSO OK</b>
--~     </a>
--~ ]])

--~ xml.settrace("lpath",true)

--~ xml.xshow(xml.first(x,"b[position() > 2 and position() < 5 and text() == 'ok']"))
--~ xml.xshow(xml.first(x,"b[position() > 2 and position() < 5 and text() == upper('ok')]"))
--~ xml.xshow(xml.first(x,"b[@n=='03' or @n=='08']"))
--~ xml.xshow(xml.all  (x,"b[number(@n)>2 and number(@n)<6]"))
--~ xml.xshow(xml.first(x,"b[find(text(),'ALSO')]"))

--~ str = [[
--~ <?xml version="1.0" encoding="utf-8"?>
--~ <story line='mojca'>
--~     <windows>my secret</mouse>
--~ </story>
--~ ]]

--~ x = xml.convert([[
--~     <a><b n='01'>01</b><b n='02'>02</b><x>xx</x><b n='03'>03</b><b n='04'>OK</b></a>
--~ ]])
--~ xml.xshow(xml.first(x,"b[tag(2) == 'x']"))
--~ xml.xshow(xml.first(x,"b[tag(1) == 'x']"))
--~ xml.xshow(xml.first(x,"b[tag(-1) == 'x']"))
--~ xml.xshow(xml.first(x,"b[tag(-2) == 'x']"))

--~ print(xml.filter(x,"b/tag(2)"))
--~ print(xml.filter(x,"b/tag(1)"))
