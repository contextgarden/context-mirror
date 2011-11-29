if not modules then modules = { } end modules ['lang-lab'] = {
    version   = 1.001,
    comment   = "companion to lang-lab.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--~ local function complete()
--~     local function process(what)
--~         for tag, data in next, what do
--~             for k, v in next, data.labels do
--~                 languages[k] = true
--~             end
--~         end
--~     end
--~     process(languages.labels.data.titles)
--~     process(languages.labels.data.texts)
--~     process(languages.labels.data.functions)
--~     process(languages.labels.data.tags)
--~     local function process(what)
--~         for tag, data in next, what do
--~             local labels = data.labels
--~             for k, v in next, languages do
--~                 if not labels[k] then
--~                     labels[k] = ""
--~                 end
--~             end
--~         end
--~     end
--~     process(languages.data.labels.titles)
--~     process(languages.data.labels.texts)
--~     process(languages.data.labels.functions)
--~     process(languages.data.labels.tags)
--~ end
--~
--~ local function strip(default)
--~     local function process(what)
--~         for tag, data in next, what do
--~             local labels = data.labels
--~             for k, v in next, labels do
--~                 if v == "" then
--~                     labels[k] = default
--~                 end
--~             end
--~         end
--~     end
--~     process(languages.data.labels.titles)
--~     process(languages.data.labels.texts)
--~     process(languages.data.labels.functions)
--~     process(languages.data.labels.tags)
--~ end
--~
--~ complete()
--~ strip(false)
--~ strip()

--~ table.print(languages.data.labels,"languages.data.labels",false,true,true)

-- this will move

local format, find = string.format, string.find
local next, rawget, type = next, rawget, type
local prtcatcodes = tex.prtcatcodes
local lpegmatch = lpeg.match

languages.labels    = languages.labels or { }

local trace_labels  = false  trackers.register("languages.labels", function(v) trace_labels = v end)
local report_labels = logs.reporter("languages","labels")

local variables     = interfaces.variables

local splitter = lpeg.splitat(":")

local function split(tag)
    return lpegmatch(splitter,tag)
end

languages.labels.split = split

local function definelanguagelabels(data,command,tag,rawtag)
    for language, text in next, data.labels do
        if text == "" then
            -- skip
        elseif type(text) == "table" then
            context("\\%s[%s][%s={{%s},{%s}}]",command,language,tag,text[1],text[2])
            if trace_labels then
                report_labels("language '%s', defining label '%s' as '%s' and '%s'",language,rawtag,text[1],text[2])
            end
        else
            context("\\%s[%s][%s={{%s},}]",command,language,tag,text)
            if trace_labels then
                report_labels("language '%s', defining label '%s' as '%s'",language,rawtag,text)
            end
        end
    end
end

function languages.labels.define(command,name,prefixed)
    local list = languages.data.labels[name]
    if list then
        report_labels("defining label set '%s'",name)
        context.pushcatcodes(prtcatcodes) -- context.unprotect
        for tag, data in next, list do
            if data.hidden then
                -- skip
            elseif prefixed then
                local first, second = lpegmatch(splitter,tag)
                if second then
                    if rawget(variables,first) then
                        if rawget(variables,second) then
                            definelanguagelabels(data,command,format("\\v!%s:\\v!%s",first,second),tag)
                        else
                            definelanguagelabels(data,command,format("\\v!%s:%s",first,second),tag)
                        end
                    elseif rawget(variables,second) then
                        definelanguagelabels(data,command,format("%s:\\v!%s",first,second),tag)
                    else
                        definelanguagelabels(data,command,format("%s:%s",first,second),tag)
                    end
                elseif rawget(variables,rawtag) then
                    definelanguagelabels(data,command,format("\\v!%s",tag),tag)
                else
                    definelanguagelabels(data,command,tag,tag)
                end
            else
                definelanguagelabels(data,command,tag,tag)
            end
        end
        context.popcatcodes() -- context.protect
    else
        report_labels("unknown label set '%s'",name)
    end
end

--~ function languages.labels.check()
--~     for category, list in next, languages.data.labels do
--~         for tag, specification in next, list do
--~             for language, text in next, specification.labels do
--~                 if type(text) == "string" and find(text,",") then
--~                     report_labels("label with comma: category '%s', language '%s', tag '%s', text '%s'",
--~                         category, language, tag, text)
--~                 end
--~             end
--~         end
--~     end
--~ end
--~
--~ languages.labels.check()

-- function commands.setstrippedtextprefix(str)
--     context(string.strip(str))
-- end
