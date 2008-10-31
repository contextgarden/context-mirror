if not modules then modules = { } end modules ['core-ref'] = {
    version   = 1.001,
    comment   = "companion to core-ref.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, texsprint = string.format, tex.sprint

-- beware, this is a first step in the rewrite (just getting rid of
-- the tuo file); later all access and parsing will also move to lua

jobreferences           = jobreferences or { }
jobreferences.tobesaved = jobreferences.tobesaved or { }
jobreferences.collected = jobreferences.collected or { }

local tobesaved, collected = jobreferences.tobesaved, jobreferences.collected

local function initializer()
    tobesaved, collected = jobreferences.tobesaved, jobreferences.collected
    -- hack, just the old way
    texsprint(tex.ctxcatcodes,"\\bgroup\\the\\everyreference")
    for prefix, list in pairs(collected) do
        for tag, data in pairs(list) do
            texsprint(tex.ctxcatcodes,format("\\dosetjobreference{%s}{%s}{%s}{%s}{%s}",prefix,tag,data[1],data[2],data[3]))
        end
    end
    texsprint(tex.ctxcatcodes,"\\egroup")
end

if job then
    job.register('jobreferences.collected', jobreferences.tobesaved, initializer)
end

function jobreferences.set(prefix,tag,page,realpage,text)
    for ref in tag:gmatch("[^,]+") do
        local p, r = ref:match("^(%-):(.-)$")
        if p and r then
            prefix, ref = "", r
        end
        if ref ~= "" then
            local pd = tobesaved[prefix]
            if not pd then
                pd = { }
                tobesaved[prefix] = pd
            end
            pd[ref] = { page, realpage, text }
        end
    end
end

function jobreferences.with(tag)
    for ref in tag:gmatch("[^,]+") do
        texsprint(tex.ctxcatcodes,format("\\dowithjobreference{%s}",ref:gsub("^(%-):","")))
    end
end

-- this reference parser is just an lpeg version of the tex based one

local result = { }

local lparent, rparent, lbrace, rbrace, dcolon = lpeg.P("("), lpeg.P(")"), lpeg.P("{"), lpeg.P("}"), lpeg.P("::")

local reset     = lpeg.P("")                          / function (s) result           = { } end
local outer     = (1-dcolon-lparent-lbrace        )^1 / function (s) result.outer     = s   end
local operation = (1-rparent-rbrace-lparent-lbrace)^1 / function (s) result.operation = s   end
local arguments = (1-rbrace                       )^0 / function (s) result.arguments = s   end
local special   = (1-lparent-lbrace-lparent-lbrace)^1 / function (s) result.special   = s   end
local inner     = (1-lparent-lbrace               )^1 / function (s) result.inner     = s   end

local outer_reference    = (outer * dcolon)^0

operation = outer_reference * operation -- special case: page(file::1) and file::page(1)

local optional_arguments = (lbrace  * arguments * rbrace)^0
local inner_reference    = inner * optional_arguments
local special_reference  = special * lparent * (operation * optional_arguments + operation^0) * rparent


local scanner = (reset * outer_reference * (special_reference + inner_reference)^-1 * -1) / function() return result end

function jobreferences.analyse(str)
    return scanner:match(str)
end

local template = "\\setreferencevariables{%s}{%s}{%s}{%s}{%s}"

function jobreferences.split(str)
    local t = scanner:match(str)
    texsprint(tex.ctxcatcodes,format(template,t.special or "",t.operation or "",t.arguments or "",t.outer or "",t.inner or ""))
end

--~ print(table.serialize(jobreferences.analyse("")))
--~ print(table.serialize(jobreferences.analyse("inner")))
--~ print(table.serialize(jobreferences.analyse("special(operation{argument,argument})")))
--~ print(table.serialize(jobreferences.analyse("special(operation)")))
--~ print(table.serialize(jobreferences.analyse("special()")))
--~ print(table.serialize(jobreferences.analyse("inner{argument}")))
--~ print(table.serialize(jobreferences.analyse("outer::")))
--~ print(table.serialize(jobreferences.analyse("outer::inner")))
--~ print(table.serialize(jobreferences.analyse("outer::special(operation{argument,argument})")))
--~ print(table.serialize(jobreferences.analyse("outer::special(operation)")))
--~ print(table.serialize(jobreferences.analyse("outer::special()")))
--~ print(table.serialize(jobreferences.analyse("outer::inner{argument}")))
--~ print(table.serialize(jobreferences.analyse("special(outer::operation)")))
