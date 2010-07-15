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
    for i=1,#sorted do
        local key = sorted[i]
        if pattern == "" or find(upper(key),pattern) then
            report(format('%s  %s=%s',instance.origins[key] or "---",key,tabstr(list[key])))
        end
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
