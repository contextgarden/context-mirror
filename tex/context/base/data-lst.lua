if not modules then modules = { } end modules ['data-lst'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- used in mtxrun

local find, concat, upper, format = string.find, table.concat, string.upper, string.format

resolvers.listers = resolvers.listers or { }

local resolvers = resolvers

local function tabstr(str)
    if type(str) == 'table' then
        return concat(str," | ")
    else
        return str
    end
end

local function list(list,report,pattern)
    pattern = pattern and pattern ~= "" and upper(pattern) or ""
    local instance = resolvers.instance
    local report = report or texio.write_nl
    local sorted = table.sortedkeys(list)
    local result = { }
    for i=1,#sorted do
        local key = sorted[i]
        if key ~= "" and (pattern == "" or find(upper(key),pattern)) then
            local raw = tabstr(rawget(list,key))
            local val = tabstr(list[key])
            local res = resolvers.resolve(val)
            if raw and raw ~= "" then
                if raw == val then
                    if val == res then
                        result[#result+1] = { key, raw }
                    else
                        result[#result+1] = { key, format('%s => %s',raw,res) }
                    end
                else
                    if val == res then
                        result[#result+1] = { key, format('%s => %s',raw,val) }
                    else
                        result[#result+1] = { key, format('%s => %s => %s',raw,val,res) }
                    end
                end
            else
                result[#result+1] = { key, "unset" }
            end
        end
    end
    utilities.formatters.formatcolumns(result)
    for i=1,#result do
        report(result[i])
    end
end

function resolvers.listers.variables (report,pattern) list(resolvers.instance.variables, report,pattern) end
function resolvers.listers.expansions(report,pattern) list(resolvers.instance.expansions,report,pattern) end

function resolvers.listers.configurations(report)
    local configurations = resolvers.instance.specification
    local report = report or texio.write_nl
    for i=1,#configurations do
        report(configurations[i])
    end
end
