if not modules then modules = { } end modules ['mult-clm'] = {
    version   = 1.001,
    comment   = "companion to mult-clm.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- another experiment
-- needs upgrading
-- needs checking
-- todo: multilingual

local texsprint, ctxcatcodes, vrbcatcodes = tex.sprint, tex.ctxcatcodes, tex.vrbcatcodes
local format, insert, remove, concat = string.format, table.insert, table.remove, table.concat
local unpack = unpack or table.unpack

local trace_define = false  trackers.register("context.define", function(v) trace_define = v end)

interfaces = interfaces or { }

_clmh_ = utilities.parsers.settings_to_array
_clma_ = utilities.parsers.settings_to_array

local starters, stoppers, macros, stack = { }, { }, { }, { }

local checkers = {
    "\\dosingleempty",
    "\\dodoubleempty",
    "\\dotripleempty",
    "\\doquadrupleempty",
    "\\doquintupleempty",
    "\\dosixtupleempty",
}

function _clmm_(name,...)
    macros[name](...)
end

function _clmb_(name,...)
    local sn = stack[name]
    insert(sn,{...})
    starters[name](...)
end

function _clme_(name)
    local sn = stack[name]
    local sv = remove(sn)
    if sv then
        stoppers[name](unpack(sv))
    else
        -- nesting error
    end
end

_clmn_ = tonumber

function interfaces.definecommand(name,specification) -- name is optional
    if type(name) == "table" then
        specification = name
        name = specification.name
    end
    if name and specification then
        local arguments = specification.arguments
        local na = (arguments and #arguments) or 0
        local environment = specification.environment
        if na == 0 then
            if environment then
                texsprint(ctxcatcodes,"\\clmb{",name,"}{\\ctxlua{_clmb_('",name,"')}}")
                texsprint(ctxcatcodes,"\\clme{",name,"}{\\ctxlua{_clme_('",name,"')}}")
            else
                texsprint(ctxcatcodes,"\\clmm{",name,"}{\\ctxlua{_clmm_('",name,"')}}")
            end
        else
            stack[name] = { }
            local opt, done = 0, false
            local mkivdo = "\\mkivdo" .. name -- maybe clddo
            texsprint(ctxcatcodes,"\\def",mkivdo)
            for i=1,na do
                local a = arguments[i]
                local variant = a[1]
                if variant == "option" then
                    texsprint(ctxcatcodes,"[#",i,"]")
                    if not done then
                        opt = opt + 1
                    end
                else
                    done = true -- no more optional checking after this
                    texsprint(ctxcatcodes,"#",i)
                end
            end
            if environment then
                texsprint(ctxcatcodes,"{\\ctxlua{_clmb_('",name,"'")
            else
                texsprint(ctxcatcodes,"{\\ctxlua{_clmm_('",name,"'")
            end
            for i=1,na do
                local a = arguments[i]
                local variant = a[2]
                if variant == "list" then
                    texsprint(ctxcatcodes,",_clma_([[#",i,"]])")
                elseif variant == "hash" then
                    texsprint(ctxcatcodes,",_clmh_([[#",i,"]])")
                elseif variant == "number" then
                    texsprint(ctxcatcodes,",_clmn_([[#",i,"]])")
                else
                    texsprint(ctxcatcodes,",[[#",i,"]]")
                end
            end
            texsprint(ctxcatcodes,")}}")
            if environment then
                texsprint(ctxcatcodes,"\\clme{",name,"}{\\ctxlua{_clme_('",name,"')}}")
                texsprint(ctxcatcodes,"\\clmb{",name,"}{",checkers[opt],mkivdo,"}")
            else
                texsprint(ctxcatcodes,"\\clmm{",name,"}{",checkers[opt],mkivdo,"}")
            end
        end
        if environment then
            starters[name] = specification.starter
            stoppers[name] = specification.stopper
        else
            macros[name] = specification.macro
        end
    end
end

function interfaces.tolist(t)
    local r = { }
    for i=1,#t do
        r[i] = t[i]
    end
    local n = #r
    for k,v in table.sortedhash(t) do
        if type(k) ~= "number" then
            n = n + 1
            r[n] = k .. "=" .. v
        end
    end
    return concat(r,", ")
end

--~ \startluacode
--~ function test(opt_1, opt_2, arg_1)
--~     context.startnarrower()
--~     context("options 1: %s",interfaces.tolist(opt_1))
--~     context.par()
--~     context("options 2: %s",interfaces.tolist(opt_2))
--~     context.par()
--~     context("argument 1: %s",arg_1)
--~     context.stopnarrower()
--~ end

--~ interfaces.definecommand {
--~     name = "test",
--~     arguments = {
--~         { "option", "list" },
--~         { "option", "hash" },
--~         { "content", "string" },
--~     },
--~     macro = test,
--~ }
--~ \stopluacode

--~ test: \test[1][a=3]{whatever}

--~ \startluacode
--~ local function startmore(opt_1)
--~     context.startnarrower()
--~     context("start more, options: %s",interfaces.tolist(opt_1))
--~     context.startnarrower()
--~ end

--~ local function stopmore(opt_1)
--~     context.stopnarrower()
--~     context("stop more, options: %s",interfaces.tolist(opt_1))
--~     context.stopnarrower()
--~ end

--~ interfaces.definecommand ( "more", {
--~     environment = true,
--~     arguments = {
--~         { "option", "list" },
--~     },
--~     starter = startmore,
--~     stopper = stopmore,
--~ } )
--~ \stopluacode

--~ more: \startmore[1] one \startmore[2] two \stopmore one \stopmore
