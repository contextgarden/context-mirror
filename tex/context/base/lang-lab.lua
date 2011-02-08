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
local texsprint = tex.sprint
local prtcatcodes = tex.prtcatcodes

languages.labels = languages.labels or { }
languages.data   = languages.data   or { }

local trace_labels = false  trackers.register("languages.labels", function(v) trace_labels = v end)

local report_labels = logs.reporter("languages","labels")

function languages.labels.define()
    local variables = interfaces.variables
    local data = languages.data.labels
    local function define(command,list,prefixed)
        if list then
            for tag, data in next, list do
                if data.hidden then
                    -- skip
                else
                    for language, text in next, data.labels do
                        if text == "" then
                            -- skip
                        elseif prefixed and rawget(variables,tag) then
                            if type(text) == "table" then
                                texsprint(prtcatcodes,format("\\%s[%s][\\v!%s={{%s},{%s}}]",command,language,tag,text[1],text[2]))
                            else
                                texsprint(prtcatcodes,format("\\%s[%s][\\v!%s={{%s},}]",command,language,tag,text))
                            end
                        else
                            if type(text) == "table" then
                                texsprint(prtcatcodes,format("\\%s[%s][%s={{%s},{%s}}]",command,language,tag,text[1],text[2]))
                            else
                                texsprint(prtcatcodes,format("\\%s[%s][%s={{%s},}]",command,language,tag,text))
                            end
                        end
                        if trace_labels then
                            if type(text) == "table" then
                                report_labels("language '%s', defining label '%s' as '%s' and '%s'",language,tag,text[1],text[2])
                            else
                                report_labels("language '%s', defining label '%s' as '%s'",language,tag,text)
                            end
                        end
                    end
                end
            end
        end
    end
    define("setupheadtext", data.titles, true)
    define("setuplabeltext", data.texts, true)
    define("setupmathlabeltext", data.functions)
    define("setuptaglabeltext", data.tags)
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

