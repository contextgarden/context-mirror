if not modules then modules = { } end modules ['trac-fil'] = {
    version   = 1.001,
    comment   = "for the moment for myself",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local rawset, tonumber = rawset, tonumber
local format, concat = string.format, table.concat
local openfile = io.open
local date = os.date
local sortedpairs = table.sortedpairs

local P, C, Cc, Cg, Cf, Ct, Cs, lpegmatch = lpeg.P, lpeg.C, lpeg.Cc, lpeg.Cg, lpeg.Cf, lpeg.Ct, lpeg.Cs, lpeg.match

local patterns   = lpeg.patterns
local cardinal   = patterns.cardinal
local whitespace = patterns.whitespace^0

local timestamp = Cf(Ct("") * (
      Cg (Cc("year")    * (cardinal/tonumber)) * P("-")
    * Cg (Cc("month")   * (cardinal/tonumber)) * P("-")
    * Cg (Cc("day")     * (cardinal/tonumber)) * P(" ")
    * Cg (Cc("hour")    * (cardinal/tonumber)) * P(":")
    * Cg (Cc("minute")  * (cardinal/tonumber)) * P(":")
    * Cg (Cc("second")  * (cardinal/tonumber)) * P("+")
    * Cg (Cc("thour")   * (cardinal/tonumber)) * P(":")
    * Cg (Cc("tminute") * (cardinal/tonumber))
)^0, rawset)

local keysvalues = Cf(Ct("") * (
    Cg(C(patterns.letter^0) * whitespace * "=" * whitespace * Cs(patterns.unquoted) * whitespace)
)^0, rawset)

local statusline = Cf(Ct("") * (
      whitespace * P("[") * Cg(Cc("timestamp") * timestamp ) * P("]")
    * whitespace *          Cg(Cc("status"   ) * keysvalues)
),rawset)

patterns.keysvalues = keysvalues
patterns.statusline = statusline
patterns.timestamp  = timestamp

loggers = loggers or { }

local tz = os.timezone(true)

local bugged = { }

function loggers.message(filename,t)
    if not bugged[filename] then
        local f = openfile(filename,"a+")
        if not f then
            dir.mkdirs(file.dirname(filename))
            f = openfile(filename,"a+")
        end
        if f then
            -- if needed we can speed this up with a concat
            f:write("[",date("!%Y-%m-%d %H:%M:%S"),tz,"]")
            for k, v in sortedpairs(t) do
                f:write(format(" %s=%q",k,v))
            end
            f:write("\n")
            f:close()
        else
            bugged[filename] = true
        end
    end
end

function loggers.collect(filename,result)
    if lfs.isfile(filename) then
        local r = lpegmatch(Ct(statusline^0),io.loaddata(filename))
        if result then -- append
            local nofresult = #result
            for i=1,#r do
                nofresult = nofresult + 1
                result[nofresult] = r[i]
            end
            return result
        else
            return r
        end
    else
        return result or { }
    end
end

--~ local template = [[
--~     <table>
--~     <tr>%s</tr>
--~     %s
--~     </table>
--~     ]]

--~ function loggers.tohtml(entries,fields)
--~     if not fields or #fields == 0 then
--~         return ""
--~     end
--~     if type(entries) == "string" then
--~         entries = loggers.collect(entries)
--~     end
--~     local scratch, lines = { }, { }
--~     for i=1,#entries do
--~         local entry = entries[i]
--~         local status = entry.status
--~         for i=1,#fields do
--~             local field = fields[i]
--~             local v = status[field.name]
--~             if v ~= nil then
--~                 v = tostring(v)
--~                 local f = field.format
--~                 if f then v = format(f,v) end
--~                 scratch[i] = format("<td nowrap='nowrap' align='%s'>%s</td>",field.align or "left",v)
--~             else
--~                 scratch[i] = "<td/>"
--~             end
--~         end
--~         lines[i] = "<tr>" .. concat(scratch) .. "</tr>"
--~     end
--~     for i=1,#fields do
--~         local field = fields[i]
--~         scratch[i] = format("<th nowrap='nowrap' align='left'>%s</th>", field.label or field.name)
--~     end
--~     local result = format(template,concat(scratch),concat(lines,"\n"))
--~     return result, entries
--~ end

--~ -- loggers.message("test.log","name","whatever","more",123)

--~ local fields = {
--~ --  { name = "id",             align = "left" },
--~ --  { name = "timestamp",      align = "left" },
--~     { name = "assessment",     align = "left" },
--~     { name = "assessmentname", align = "left" },
--~ --  { name = "category",       align = "left" },
--~     { name = "filesize",       align = "right" },
--~     { name = "nofimages",      align = "center" },
--~ --  { name = "product",        align = "left" },
--~     { name = "resultsize",     align = "right" },
--~     { name = "fetchtime",      align = "right", format = "%2.3f" },
--~     { name = "runtime",        align = "right", format = "%2.3f" },
--~     { name = "organization",   align = "left" },
--~ --  { name = "username",       align = "left" },
--~ }
