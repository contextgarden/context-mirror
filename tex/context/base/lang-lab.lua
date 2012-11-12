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
local lpegmatch = lpeg.match

local prtcatcodes = catcodes.numbers.prtcatcodes -- todo: use different method

local trace_labels  = false  trackers.register("languages.labels", function(v) trace_labels = v end)
local report_labels = logs.reporter("languages","labels")

-- trace_labels = true

languages.labels        = languages.labels or { }
local labels            = languages.labels

local variables         = interfaces.variables
local settings_to_array = utilities.parsers.settings_to_array

local splitter = lpeg.splitat(":")

local function split(tag)
    return lpegmatch(splitter,tag)
end

labels.split = split

local contextsprint = context.sprint

local function definelanguagelabels(data,class,tag,rawtag)
    for language, text in next, data.labels do
        if text == "" then
            -- skip
        elseif type(text) == "table" then
            contextsprint(prtcatcodes,"\\setlabeltextpair{",class,"}{",language,"}{",tag,"}{",text[1],"}{",text[2],"}")
            if trace_labels then
                report_labels("language '%s', defining label '%s' as '%s' and '%s'",language,rawtag,text[1],text[2])
            end
        else
            contextsprint(prtcatcodes,"\\setlabeltextpair{",class,"}{",language,"}{",tag,"}{",text,"}{}")
            if trace_labels then
                report_labels("language '%s', defining label '%s' as '%s'",language,rawtag,text)
            end
        end
    end
end

function labels.define(class,name,prefixed)
    local list = languages.data.labels[name]
    if list then
        report_labels("defining label set '%s'",name)
        for tag, data in next, list do
            if data.hidden then
                -- skip
            elseif prefixed then
                local first, second = lpegmatch(splitter,tag)
                if second then
                    if rawget(variables,first) then
                        if rawget(variables,second) then
                            definelanguagelabels(data,class,format("\\v!%s:\\v!%s",first,second),tag)
                        else
                            definelanguagelabels(data,class,format("\\v!%s:%s",first,second),tag)
                        end
                    elseif rawget(variables,second) then
                        definelanguagelabels(data,class,format("%s:\\v!%s",first,second),tag)
                    else
                        definelanguagelabels(data,class,format("%s:%s",first,second),tag)
                    end
                elseif rawget(variables,rawtag) then
                    definelanguagelabels(data,class,format("\\v!%s",tag),tag)
                else
                    definelanguagelabels(data,class,tag,tag)
                end
            else
                definelanguagelabels(data,class,tag,tag)
            end
        end
    else
        report_labels("unknown label set '%s'",name)
    end
end

--~ function labels.check()
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
--~ labels.check()


-- interface

commands.definelabels = labels.define

-- function commands.setstrippedtextprefix(str)
--     context(string.strip(str))
-- end

-- list       : { "a", "b", "c" }
-- separator  : ", "
-- last       : " and "

-- text       : "a,b,c"
-- separators : "{, },{ and }"

function commands.concat(settings) -- it's too easy to forget that this one is there
    local list = settings.list or settings_to_array(settings.text or "")
    local size = #list
    local command = settings.command and context[settings.command] or context
    if size > 1 then
        local separator, last = " ", " "
        if settings.separators then
            local set = settings_to_array(settings.separators)
            separator = set[1] or settings.separator or separator
            last      = set[2] or settings.last      or last
        else
            separator = settings.separator or separator
            last      = settings.last      or last
        end
        context(list[1])
        for i=2,size-1 do
            context(separator)
            command(list[i])
        end
        context(last)
    end
    if size > 0 then
        command(list[size])
    end
end
