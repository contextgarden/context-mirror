if not modules then modules = { } end modules ['lxml-pth'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- e.ni is only valid after a filter run

local concat, remove, insert = table.concat, table.remove, table.insert
local type, next, tonumber, tostring, setmetatable, loadstring = type, next, tonumber, tostring, setmetatable, loadstring
local format, upper, lower, gmatch, gsub, find, rep = string.format, string.upper, string.lower, string.gmatch, string.gsub, string.find, string.rep

--[[ldx--
<p>This module can be used stand alone but also inside <l n='mkiv'/> in
which case it hooks into the tracker code. Therefore we provide a few
functions that set the tracers. Here we overload a previously defined
function.</p>
<p>If I can get in the mood I will make a variant that is XSLT compliant
but I wonder if it makes sense.</P>
--ldx]]--

--[[ldx--
<p>Expecially the lpath code is experimental, we will support some of xpath, but
only things that make sense for us; as compensation it is possible to hook in your
own functions. Apart from preprocessing content for <l n='context'/> we also need
this module for process management, like handling <l n='ctx'/> and <l n='rlx'/>
files.</p>

<typing>
a/b/c /*/c
a/b/c/first() a/b/c/last() a/b/c/index(n) a/b/c/index(-n)
a/b/c/text() a/b/c/text(1) a/b/c/text(-1) a/b/c/text(n)
</typing>
--ldx]]--

local trace_lpath    = false  if trackers then trackers.register("xml.path",    function(v) trace_lpath  = v end) end
local trace_lparse   = false  if trackers then trackers.register("xml.parse",   function(v) trace_lparse = v end) end
local trace_lprofile = false  if trackers then trackers.register("xml.profile", function(v) trace_lpath  = v trace_lparse = v trace_lprofile = v end) end

--[[ldx--
<p>We've now arrived at an interesting part: accessing the tree using a subset
of <l n='xpath'/> and since we're not compatible we call it <l n='lpath'/>. We
will explain more about its usage in other documents.</p>
--ldx]]--

local lpathcalls  = 0  function xml.lpathcalls () return lpathcalls  end
local lpathcached = 0  function xml.lpathcached() return lpathcached end

xml.functions      = xml.functions      or { } -- internal
xml.expressions    = xml.expressions    or { } -- in expressions
xml.finalizers     = xml.finalizers     or { } -- fast do-with ... (with return value other than collection)
xml.specialhandler = xml.specialhandler or { }

local functions   = xml.functions
local expressions = xml.expressions
local finalizers  = xml.finalizers

finalizers.xml = finalizers.xml or { }
finalizers.tex = finalizers.tex or { }

local function fallback (t, name)
    local fn = finalizers[name]
    if fn then
        t[name] = fn
    else
        logs.report("xml","unknown sub finalizer '%s'",tostring(name))
        fn = function() end
    end
    return fn
end

setmetatable(finalizers.xml, { __index = fallback })
setmetatable(finalizers.tex, { __index = fallback })

xml.defaultprotocol = "xml"

-- as xsl does not follow xpath completely here we will also
-- be more liberal especially with regards to the use of | and
-- the rootpath:
--
-- test    : all 'test' under current
-- /test   : 'test' relative to current
-- a|b|c   : set of names
-- (a|b|c) : idem
-- !       : not
--
-- after all, we're not doing transformations but filtering. in
-- addition we provide filter functions (last bit)
--
-- todo: optimizer
--
-- .. : parent
-- *  : all kids
-- /  : anchor here
-- // : /**/
-- ** : all in between
--
-- so far we had (more practical as we don't transform)
--
-- {/test}   : kids 'test' under current node
-- {test}    : any kid with tag 'test'
-- {//test}  : same as above

-- evaluator (needs to be redone, for the moment copied)

-- todo: apply_axis(list,notable) and collection vs single

local apply_axis = { }

apply_axis['root'] = function(list)
    local collected = { }
    for l=1,#list do
        local ll = list[l]
        local rt = ll
        while ll do
            ll = ll.__p__
            if ll then
                rt = ll
            end
        end
        collected[#collected+1] = rt
    end
    return collected
end

apply_axis['self'] = function(list)
--~     local collected = { }
--~     for l=1,#list do
--~         collected[#collected+1] = list[l]
--~     end
--~     return collected
    return list
end

apply_axis['child'] = function(list)
    local collected = { }
    for l=1,#list do
        local dt = list[l].dt
        for k=1,#dt do
            local dk = dt[k]
            if dk.tg then
                collected[#collected+1] = dk
                dk.ni = k -- refresh
            end
        end
    end
    return collected
end

local function collect(list,collected)
    local dt = list.dt
    if dt then
        for k=1,#dt do
            local dk = dt[k]
            if dk.tg then
                collected[#collected+1] = dk
                dk.ni = k -- refresh
                collect(dk,collected)
            end
        end
    end
end
apply_axis['descendant'] = function(list)
    local collected = { }
    for l=1,#list do
        collect(list[l],collected)
    end
    return collected
end

local function collect(list,collected)
    local dt = list.dt
    if dt then
        for k=1,#dt do
            local dk = dt[k]
            if dk.tg then
                collected[#collected+1] = dk
                dk.ni = k -- refresh
                collect(dk,collected)
            end
        end
    end
end
apply_axis['descendant-or-self'] = function(list)
    local collected = { }
    for l=1,#list do
        local ll = list[l]
if ll.special ~= true then -- catch double root
        collected[#collected+1] = ll
end
        collect(ll,collected)
    end
    return collected
end

apply_axis['ancestor'] = function(list)
    local collected = { }
    for l=1,#list do
        local ll = list[l]
        while ll do
            ll = ll.__p__
            if ll then
                collected[#collected+1] = ll
            end
        end
    end
    return collected
end

apply_axis['ancestor-or-self'] = function(list)
    local collected = { }
    for l=1,#list do
        local ll = list[l]
        collected[#collected+1] = ll
        while ll do
            ll = ll.__p__
            if ll then
                collected[#collected+1] = ll
            end
        end
    end
    return collected
end

apply_axis['parent'] = function(list)
    local collected = { }
    for l=1,#list do
        local pl = list[l].__p__
        if pl then
            collected[#collected+1] = pl
        end
    end
    return collected
end

apply_axis['attribute'] = function(list)
    return { }
end

apply_axis['following'] = function(list)
    return { }
end

apply_axis['following-sibling'] = function(list)
    return { }
end

apply_axis['namespace'] = function(list)
    return { }
end

apply_axis['preceding'] = function(list)
    return { }
end

apply_axis['preceding-sibling'] = function(list)
    return { }
end

apply_axis['auto-descendant-or-self'] = apply_axis['descendant-or-self']
apply_axis['auto-descendant']         = apply_axis['descendant']
apply_axis['auto-child']              = apply_axis['child']
apply_axis['auto-self']               = apply_axis['self']
apply_axis['initial-child']           = apply_axis['child']

local function apply_nodes(list,directive,nodes)
    -- todo: nodes[1] etc ... negated node name in set ... when needed
    -- ... currently ignored
    local maxn = #nodes
    if maxn == 3 then --optimized loop
        local nns, ntg = nodes[2], nodes[3]
        if not nns and not ntg then -- wildcard
            if directive then
                return list
            else
                return { }
            end
        else
            local collected = { }
            if not nns then -- only check tag
                for l=1,#list do
                    local ll = list[l]
                    local ltg = ll.tg
                    if ltg then
                        if directive then
                            if ntg == ltg then
                                collected[#collected+1] = ll
                            end
                        elseif ntg ~= ltg then
                            collected[#collected+1] = ll
                        end
                    end
                end
            elseif not ntg then -- only check namespace
                for l=1,#list do
                    local ll = list[l]
                    local lns = ll.rn or ll.ns
                    if lns then
                        if directive then
                            if lns == nns then
                                collected[#collected+1] = ll
                            end
                        elseif lns ~= nns then
                            collected[#collected+1] = ll
                        end
                    end
                end
            else -- check both
                for l=1,#list do
                    local ll = list[l]
                    local ltg = ll.tg
                    if ltg then
                        local lns = ll.rn or ll.ns
                        local ok = ltg == ntg and lns == nns
                        if directive then
                            if ok then
                                collected[#collected+1] = ll
                            end
                        elseif not ok then
                            collected[#collected+1] = ll
                        end
                    end
                end
            end
            return collected
        end
    else
        local collected = { }
        for l=1,#list do
            local ll = list[l]
            local ltg = ll.tg
            if ltg then
                local lns = ll.rn or ll.ns
                local ok = false
                for n=1,maxn,3 do
                    local nns, ntg = nodes[n+1], nodes[n+2]
                    ok = (not ntg or ltg == ntg) and (not nns or lns == nns)
                    if ok then
                        break
                    end
                end
                if directive then
                    if ok then
                        collected[#collected+1] = ll
                    end
                elseif not ok then
                    collected[#collected+1] = ll
                end
            end
        end
        return collected
    end
end

local function apply_expression(list,expression,order)
    local collected = { }
    for l=1,#list do
        local ll = list[l]
        if expression(list,ll,l,order) then -- nasty, alleen valid als n=1
            collected[#collected+1] = ll
        end
    end
    return collected
end

local P, V, C, Cs, Cc, Ct, R, S, Cg, Cb = lpeg.P, lpeg.V, lpeg.C, lpeg.Cs, lpeg.Cc, lpeg.Ct, lpeg.R, lpeg.S, lpeg.Cg, lpeg.Cb

local spaces       = S(" \n\r\t\f")^0

local lp_space     = S(" \n\r\t\f")
local lp_any       = P(1)

local lp_noequal   = P("!=") / "~=" + P("<=") + P(">=") + P("==")
local lp_doequal   = P("=")  / "=="
local lp_or        = P("|")  / " or "
local lp_and       = P("&")  / " and "

local lp_builtin = P (
        P("first")        / "1" +
        P("last")         / "#list" +
        P("position")     / "l" +
        P("rootposition") / "order" +
        P("index")        / "ll.ni" +
        P("text")         / "(ll.dt[1] or '')" +
        P("name")         / "(ll.ns~='' and ll.ns..':'..ll.tg)" +
        P("tag")          / "ll.tg" +
        P("ns")           / "ll.ns"
    ) * ((spaces * P("(") * spaces * P(")"))/"")

local lp_attribute    = (P("@") + P("attribute::"))    / "" * Cc("ll.at['") * R("az","AZ","--","__")^1 * Cc("']")
local lp_fastpos      = ((R("09","--","++")^1 * P(-1)) / function(s) return "l==" .. s end)

local lp_reserved  = C("and") + C("or") + C("not") + C("div") + C("mod") + C("true") + C("false")

local lp_lua_function  = C(R("az","AZ","__")^1 * (P(".") * R("az","AZ","__")^1)^1) * ("(") / function(t) -- todo: better . handling
    return t .. "("
end

local lp_function  = C(R("az","AZ","__")^1) * P("(") / function(t) -- todo: better . handling
    if expressions[t] then
        return "expr." .. t .. "("
    else
        return "expr.error("
    end
end

local lparent  = lpeg.P("(")
local rparent  = lpeg.P(")")
local noparent = 1 - (lparent+rparent)
local nested   = lpeg.P{lparent * (noparent + lpeg.V(1))^0 * rparent}
local value    = lpeg.P(lparent * lpeg.C((noparent + nested)^0) * rparent) -- lpeg.P{"("*C(((1-S("()"))+V(1))^0)*")"}

local lp_child  = Cc("expr.child(e,'") * R("az","AZ","--","__")^1 * Cc("')")
local lp_string = Cc("'") * R("az","AZ","--","__")^1 * Cc("'")
local lp_content= (P("'") * (1-P("'"))^0 * P("'") + P('"') * (1-P('"'))^0 * P('"'))

local cleaner

local lp_special = (C(P("name")+P("text")+P("tag")+P("count")+P("child"))) * value / function(t,s)
    if expressions[t] then
        s = s and s ~= "" and cleaner:match(s)
        if s and s ~= "" then
            return "expr." .. t .. "(e," .. s ..")"
        else
            return "expr." .. t .. "(e)"
        end
    else
        return "expr.error(" .. t .. ")"
    end
end

local content =
    lp_builtin +
    lp_attribute +
    lp_special +
    lp_noequal + lp_doequal +
    lp_or + lp_and +
    lp_reserved +
    lp_lua_function + lp_function +
    lp_content + -- too fragile
    lp_child +
    lp_any

local converter = lpeg.Cs (
    lp_fastpos + (lpeg.P { lparent * (lpeg.V(1))^0 * rparent + content } )^0
)

cleaner = lpeg.Cs ( (
--~     lp_fastpos +
    lp_reserved +
    lp_string +
1 )^1 )

--~ expr

local template_e = [[
    local expr = xml.expressions
    return function(list,ll,l,root)
        return %s
    end
]]

local template_f_y = [[
    local finalizer = xml.finalizers['%s']['%s']
    return function(collection)
        return finalizer(collection,%s)
    end
]]

local template_f_n = [[
    return xml.finalizers['%s']['%s']
]]

--

local function errorrunner_e(str,cnv)
    logs.report("lpath","error in expression: %s => %s",str,cnv)
    return false
end
local function errorrunner_f(str,arg)
    logs.report("lpath","error in finalizer: %s(%s)",str,arg or "")
    return false
end

local function register_nodes(nodetest,nodes)
    return { kind = "nodes", nodetest = nodetest, nodes = nodes }
end

local function register_expression(expression)
    local converted = converter:match(expression)
    local runner = loadstring(format(template_e,converted))
    runner = (runner and runner()) or function() errorrunner_e(expression,converted) end
    return { kind = "expression", expression = expression, converted = converted, evaluator = runner }
end

local function register_finalizer(protocol,name,arguments)
    local runner
    if arguments and arguments ~= "" then
        runner = loadstring(format(template_f_y,protocol or xml.defaultprotocol,name,arguments))
    else
        runner = loadstring(format(template_f_n,protocol or xml.defaultprotocol,name))
    end
    runner = (runner and runner()) or function() errorrunner_f(name,arguments) end
    return { kind = "finalizer", name = name, arguments = arguments, finalizer = runner }
end

local expression = P { "ex",
    ex = "[" * C((V("sq") + V("dq") + (1 - S("[]")) + V("ex"))^0) * "]",
    sq = "'" * (1 - S("'"))^0 * "'",
    dq = '"' * (1 - S('"'))^0 * '"',
}

local arguments = P { "ar",
    ar = "(" * Cs((V("sq") + V("dq") + V("nq") + P(1-P(")")))^0) * ")",
    nq = ((1 - S("),'\""))^1) / function(s) return format("%q",s) end,
    sq = P("'") * (1 - P("'"))^0 * P("'"),
    dq = P('"') * (1 - P('"'))^0 * P('"'),
}

-- todo: better arg parser

local register_self                    = { kind = "axis", axis = "self"                    } -- , apply = apply_axis["self"]               }
local register_parent                  = { kind = "axis", axis = "parent"                  } -- , apply = apply_axis["parent"]             }
local register_descendant              = { kind = "axis", axis = "descendant"              } -- , apply = apply_axis["descendant"]         }
local register_child                   = { kind = "axis", axis = "child"                   } -- , apply = apply_axis["child"]              }
local register_descendant_or_self      = { kind = "axis", axis = "descendant-or-self"      } -- , apply = apply_axis["descendant-or-self"] }
local register_root                    = { kind = "axis", axis = "root"                    } -- , apply = apply_axis["root"]               }
local register_ancestor                = { kind = "axis", axis = "ancestor"                } -- , apply = apply_axis["ancestor"]           }
local register_ancestor_or_self        = { kind = "axis", axis = "ancestor-or-self"        } -- , apply = apply_axis["ancestor-or-self"]   }
local register_attribute               = { kind = "axis", axis = "attribute"               } -- , apply = apply_axis["attribute"]          }
local register_namespace               = { kind = "axis", axis = "namespace"               } -- , apply = apply_axis["namespace"]          }
local register_following               = { kind = "axis", axis = "following"               } -- , apply = apply_axis["following"]          }
local register_following_sibling       = { kind = "axis", axis = "following-sibling"       } -- , apply = apply_axis["following-sibling"]  }
local register_preceding               = { kind = "axis", axis = "preceding"               } -- , apply = apply_axis["preceding"]          }
local register_preceding_sibling       = { kind = "axis", axis = "preceding-sibling"       } -- , apply = apply_axis["preceding-sibling"]  }

local register_auto_descendant_or_self = { kind = "axis", axis = "auto-descendant-or-self" } -- , apply = apply_axis["auto-descendant-or-self"] }
local register_auto_descendant         = { kind = "axis", axis = "auto-descendant"         } -- , apply = apply_axis["auto-descendant"] }
local register_auto_self               = { kind = "axis", axis = "auto-self"               } -- , apply = apply_axis["auto-self"] }
local register_auto_child              = { kind = "axis", axis = "auto-child"              } -- , apply = apply_axis["auto-child"] }

local register_initial_child           = { kind = "axis", axis = "initial-child"           } -- , apply = apply_axis["initial-child"] }

local register_all_nodes               = { kind = "nodes", nodetest = true, nodes = { true, false, false } }

local function register_error(str)
    return { kind = "error", comment = format("unparsed: %s",str) }
end

local parser = Ct { "patterns", -- can be made a bit faster by moving pattern outside

    patterns             = spaces * V("protocol") * spaces * V("initial") * spaces * V("step") * spaces *
                           (P("/") * spaces * V("step") * spaces)^0,

    protocol             = Cg(V("letters"),"protocol") * P("://") + Cg(Cc(nil),"protocol"),

    step                 = (V("shortcuts") + V("axis") * spaces * V("nodes")^0 + V("error")) * spaces * V("expressions")^0 * spaces * V("finalizer")^0,

    axis                 = V("descendant") + V("child") + V("parent") + V("self") + V("root") + V("ancestor") +
                           V("descendant_or_self") + V("following") + V("following_sibling") +
                           V("preceding") + V("preceding_sibling") + V("ancestor_or_self") +
                           #(1-P(-1)) * Cc(register_auto_child),

    initial              = (P("/") * spaces * Cc(register_initial_child))^-1,

    error                = (P(1)^1) / register_error,

    shortcuts_a          = V("s_descendant_or_self") + V("s_descendant") + V("s_child") + V("s_parent") + V("s_self") + V("s_root") + V("s_ancestor"),

    shortcuts            = V("shortcuts_a") * (spaces * "/" * spaces * V("shortcuts_a"))^0,

    s_descendant_or_self = P("/")  * Cc(register_descendant_or_self),
    s_descendant         = P("**") * Cc(register_descendant),
    s_child              = P("*")  * Cc(register_child     ),
    s_parent             = P("..") * Cc(register_parent    ),
    s_self               = P("." ) * Cc(register_self      ),
    s_root               = P("^^") * Cc(register_root      ),
    s_ancestor           = P("^")  * Cc(register_ancestor  ),

    descendant           = P("descendant::")         * Cc(register_descendant         ),
    child                = P("child::")              * Cc(register_child              ),
    parent               = P("parent::")             * Cc(register_parent             ),
    self                 = P("self::")               * Cc(register_self               ),
    root                 = P('root::')               * Cc(register_root               ),
    ancestor             = P('ancestor::')           * Cc(register_ancestor           ),
    descendant_or_self   = P('descendant-or-self::') * Cc(register_descendant_or_self ),
    ancestor_or_self     = P('ancestor-or-self::')   * Cc(register_ancestor_or_self   ),
 -- attribute            = P('attribute::')          * Cc(register_attribute          ),
 -- namespace            = P('namespace::')          * Cc(register_namespace          ),
    following            = P('following::')          * Cc(register_following          ),
    following_sibling    = P('following-sibling::')  * Cc(register_following_sibling  ),
    preceding            = P('preceding::')          * Cc(register_preceding          ),
    preceding_sibling    = P('preceding-sibling::')  * Cc(register_preceding_sibling  ),

    nodes                = (V("nodefunction") * spaces * P("(") * V("nodeset") * P(")") + V("nodetest") * V("nodeset")) / register_nodes,

    expressions          = expression / register_expression,

    letters              = R("az")^1,
    name                 = (1-lpeg.S("/[]()|:*!"))^1,
    negate               = P("!") * Cc(false),

    nodefunction         = V("negate") + P("not") * Cc(false) + Cc(true),
    nodetest             = V("negate") + Cc(true),
    nodename             = (V("negate") + Cc(true)) * spaces * ((V("wildnodename") * P(":") * V("wildnodename")) + (Cc(false) * V("wildnodename"))),
    wildnodename         = (C(V("name")) + P("*") * Cc(false)) * #(1-P("(")),
    nodeset              = spaces * Ct(V("nodename") * (spaces * P("|") * spaces * V("nodename"))^0) * spaces,

    finalizer            = (Cb("protocol") * P("/")^-1 * C(V("name")) * arguments * P(-1)) / register_finalizer,

}

local cache = { }

local function nodesettostring(set,nodetest)
    local t = { }
    for i=1,#set,3 do
        local directive, ns, tg = set[i], set[i+1], set[i+2]
        if not ns or ns == "" then ns = "*" end
        if not tg or tg == "" then tg = "*" end
        tg = (tg == "@rt@" and "[root]") or format("%s:%s",ns,tg)
        t[#t+1] = (directive and tg) or format("not(%s)",tg)
    end
    if nodetest == false then
        return format("not(%s)",concat(t,"|"))
    else
        return concat(t,"|")
    end
end

local function tagstostring(list)
    if #list == 0 then
        return "no elements"
    else
        local t = { }
        for i=1, #list do
            local li = list[i]
            local ns, tg = li.ns, li.tg
            if not ns or ns == "" then ns = "*" end
            if not tg or tg == "" then tg = "*" end
            t[#t+1] = (tg == "@rt@" and "[root]") or format("%s:%s",ns,tg)
        end
        return concat(t," ")
    end
end

xml.nodesettostring = nodesettostring

local function lshow(parsed)
    if type(parsed) == "string" then
        parsed = parse_pattern(parsed)
    end
    local s = table.serialize_functions -- ugly
    table.serialize_functions = false -- ugly
    logs.report("lpath","%s://%s => %s",parsed.protocol or xml.defaultprotocol,parsed.pattern,table.serialize(parsed,false))
    table.serialize_functions = s -- ugly
end

xml.lshow = lshow

local function parse_pattern(pattern) -- the gain of caching is rather minimal
    lpathcalls = lpathcalls + 1
    if type(pattern) == "table" then
        return pattern
    else
        local parsed = cache[pattern]
        if parsed then
            lpathcached = lpathcached + 1
        else
            parsed = parser:match(pattern)
            if parsed then
                parsed.pattern = pattern
                local np = #parsed
                if np == 0 then
                    parsed = { pattern = pattern, register_self, state = "parsing error" }
                    logs.report("lpath","parsing error in '%s'",pattern)
                    lshow(parsed)
                else
                    -- we could have done this with a more complex parsed but this
                    -- is cleaner
                    local pi = parsed[1]
                    if pi.axis == "auto-child" then
                        parsed.comment = "auto-child replaced by auto-descendant-or-self"
                        parsed[1] = register_auto_descendant_or_self
                    --~ parsed.comment = "auto-child replaced by auto-descendant"
                    --~ parsed[1] = register_auto_descendant
                    elseif pi.axis == "initial-child" and np > 1 and parsed[2].axis then
                        parsed.comment = "initial-child removed" -- we could also make it a auto-self
                        remove(parsed,1)
                    end
                end
            else
                parsed = { pattern = pattern }
            end
            cache[pattern] = parsed
            if trace_lparse and not trace_lprofile then
                lshow(parsed)
            end
        end
        return parsed
    end
end

-- we can move all calls inline and then merge the trace back
-- technically we can combine axis and the next nodes which is
-- what we did before but this a bit cleaner (but slower too)
-- but interesting is that it's not that much faster when we
-- go inline
--
-- beware: we need to return a collection even when we filter
-- else the (simple) cache gets messed up

-- caching found lookups saves not that much (max .1 sec on a 8 sec run)
-- and it also messes up finalizers

local profiled = { }  xml.profiled = profiled

local function profiled_apply(list,parsed,nofparsed)
    local p = profiled[parsed.pattern]
    if p then
        p.tested = p.tested + 1
    else
        p = { tested = 1, matched = 0, finalized = 0 }
        profiled[parsed.pattern] = p
    end
    local collected = list
    for i=1,nofparsed do
        local pi = parsed[i]
        local kind = pi.kind
        if kind == "axis" then
            collected = apply_axis[pi.axis](collected)
        elseif kind == "nodes" then
            collected = apply_nodes(collected,pi.nodetest,pi.nodes)
        elseif kind == "expression" then
            collected = apply_expression(collected,pi.evaluator,i)
        elseif kind == "finalizer" then
            collected = pi.finalizer(collected)
            p.matched = p.matched + 1
            p.finalized = p.finalized + 1
            return collected
        end
        if not collected or #collected == 0 then
            return nil
        end
    end
    if collected then
        p.matched = p.matched + 1
    end
    return collected
end

local function traced_apply(list,parsed,nofparsed)
    if trace_lparse then
        lshow(parsed)
    end
    logs.report("lpath", "collecting : %s",parsed.pattern)
    logs.report("lpath", " root tags : %s",tagstostring(list))
    local collected = list
    for i=1,nofparsed do
        local pi = parsed[i]
        local kind = pi.kind
        if kind == "axis" then
            collected = apply_axis[pi.axis](collected)
            logs.report("lpath", "% 10i : ax : %s",(collected and #collected) or 0,pi.axis)
        elseif kind == "nodes" then
            collected = apply_nodes(collected,pi.nodetest,pi.nodes)
            logs.report("lpath", "% 10i : ns : %s",(collected and #collected) or 0,nodesettostring(pi.nodes,pi.nodetest))
        elseif kind == "expression" then
            collected = apply_expression(collected,pi.evaluator,i)
            logs.report("lpath", "% 10i : ex : %s",(collected and #collected) or 0,pi.expression)
        elseif kind == "finalizer" then
            collected = pi.finalizer(collected)
            logs.report("lpath", "% 10i : fi : %s : %s(%s)",(collected and #collected) or 0,parsed.protocol or xml.defaultprotocol,pi.name,pi.arguments or "")
            return collected
        end
        if not collected or #collected == 0 then
            return nil
        end
    end
    return collected
end

local function parse_apply(list,pattern)
    -- we avoid an extra call
    local parsed = cache[pattern]
    if parsed then
        lpathcalls = lpathcalls + 1
        lpathcached = lpathcached + 1
    elseif type(pattern) == "table" then
        lpathcalls = lpathcalls + 1
        parsed = pattern
    else
        parsed = parse_pattern(pattern) or pattern
    end
    if not parsed then
        return
    end
    local nofparsed = #parsed
    if nofparsed == 0 then
        -- something is wrong
    elseif not trace_lpath then
        -- normal apply, inline, no self
        local collected = list
        for i=1,nofparsed do
            local pi = parsed[i]
            local kind = pi.kind
            if kind == "axis" then
                local axis = pi.axis
                if axis ~= "self" then
                    collected = apply_axis[axis](collected)
                end
            elseif kind == "nodes" then
                collected = apply_nodes(collected,pi.nodetest,pi.nodes)
            elseif kind == "expression" then
                collected = apply_expression(collected,pi.evaluator,i)
            elseif kind == "finalizer" then
                return pi.finalizer(collected)
            end
            if not collected or #collected == 0 then
                return nil
            end
        end
        return collected
    elseif trace_lprofile then
        return profiled_apply(list,parsed,nofparsed)
    else -- trace_lpath
        return traced_apply(list,parsed,nofparsed)
    end
end

-- internal (parsed)

expressions.child = function(e,pattern)
    return parse_apply({ e },pattern) -- todo: cache
end
expressions.count = function(e,pattern)
    local collected = parse_apply({ e },pattern) -- todo: cache
    return (collected and #collected) or 0
end

-- external

expressions.oneof = function(s,...) -- slow
    local t = {...} for i=1,#t do if s == t[i] then return true end end return false
end
expressions.error = function(str)
    xml.error_handler("unknown function in lpath expression",tostring(str or "?"))
    return false
end
expressions.undefined = function(s)
    return s == nil
end

expressions.contains  = find
expressions.find      = find
expressions.upper     = upper
expressions.lower     = lower
expressions.number    = tonumber
expressions.boolean   = toboolean

-- user interface

local function traverse(root,pattern,handle)
    logs.report("xml","use 'xml.selection' instead for '%s'",pattern)
    local collected = parse_apply({ root },pattern)
    if collected then
        for c=1,#collected do
            local e = collected[c]
            local r = e.__p__
            handle(r,r.dt,e.ni)
        end
    end
end

local function selection(root,pattern,handle)
    local collected = parse_apply({ root },pattern)
    if collected then
        if handle then
            for c=1,#collected do
                handle(collected[c])
            end
        else
            return collected
        end
    end
end

xml.parse_parser  = parser
xml.parse_pattern = parse_pattern
xml.parse_apply   = parse_apply
xml.traverse      = traverse           -- old method, r, d, k
xml.selection     = selection          -- new method, simple handle

local lpath = parse_pattern

xml.lpath = lpath

function xml.cached_patterns()
    return cache
end

-- generic function finalizer (independant namespace)

local function dofunction(collected,fnc)
    if collected then
        local f = functions[fnc]
        if f then
            for c=1,#collected do
                f(collected[c])
            end
        else
            logs.report("xml","unknown function '%s'",fnc)
        end
    end
end

xml.finalizers.xml["function"] = dofunction
xml.finalizers.tex["function"] = dofunction

-- functions

expressions.text = function(e,n)
    local rdt = e.__p__.dt
    return (rdt and rdt[n]) or ""
end

expressions.name = function(e,n) -- ns + tg
    local found = false
    n = tonumber(n) or 0
    if n == 0 then
        found = type(e) == "table" and e
    elseif n < 0 then
        local d, k = e.__p__.dt, e.ni
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
        local d, k = e.__p__.dt, e.ni
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

expressions.tag = function(e,n) -- only tg
    local found = false
    n = tonumber(n) or 0
    if n == 0 then
        found = (type(e) == "table") and e -- seems to fail
    elseif n < 0 then
        local d, k = e.__p__.dt, e.ni
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
        local d, k = e.__p__.dt, e.ni
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

--[[ldx--
<p>This is the main filter function. It returns whatever is asked for.</p>
--ldx]]--

function xml.filter(root,pattern) -- no longer funny attribute handling here
    return parse_apply({ root },pattern)
end

--[[ldx--
<p>Often using an iterators looks nicer in the code than passing handler
functions. The <l n='lua'/> book describes how to use coroutines for that
purpose (<url href='http://www.lua.org/pil/9.3.html'/>). This permits
code like:</p>

<typing>
for r, d, k in xml.elements(xml.load('text.xml'),"title") do
    print(d[k]) -- old method
end
for e in xml.collected(xml.load('text.xml'),"title") do
    print(e) -- new one
end
</typing>
--ldx]]--

local wrap, yield = coroutine.wrap, coroutine.yield

function xml.elements(root,pattern,reverse) -- r, d, k
    local collected = parse_apply({ root },pattern)
    if collected then
        if reverse then
            return wrap(function() for c=#collected,1,-1 do
                local e = collected[c] local r = e.__p__ yield(r,r.dt,e.ni)
            end end)
        else
            return wrap(function() for c=1,#collected    do
                local e = collected[c] local r = e.__p__ yield(r,r.dt,e.ni)
            end end)
        end
    end
    return wrap(function() end)
end

function xml.collected(root,pattern,reverse) -- e
    local collected = parse_apply({ root },pattern)
    if collected then
        if reverse then
            return wrap(function() for c=#collected,1,-1 do yield(collected[c]) end end)
        else
            return wrap(function() for c=1,#collected    do yield(collected[c]) end end)
        end
    end
    return wrap(function() end)
end
