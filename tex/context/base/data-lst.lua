if not modules then modules = { } end modules ['data-lst'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- used in mtxrun, can be loaded later .. todo

local find, concat, upper, format = string.find, table.concat, string.upper, string.format

resolvers.listers = resolvers.listers or { }

local resolvers = resolvers

local report_lists = logs.reporter("resolvers","lists")

local function tabstr(str)
    if type(str) == 'table' then
        return concat(str," | ")
    else
        return str
    end
end

function resolvers.listers.variables(pattern)
    local instance    = resolvers.instance
    local environment = instance.environment
    local variables   = instance.variables
    local expansions  = instance.expansions
    local pattern     = upper(pattern or "")
    local configured  = { }
    local order       = instance.order
    for i=1,#order do
        for k, v in next, order[i] do
            if v ~= nil and configured[k] == nil then
                configured[k] = v
            end
        end
    end
    local env = table.fastcopy(environment)
    local var = table.fastcopy(variables)
    local exp = table.fastcopy(expansions)
    for key, value in table.sortedpairs(configured) do
        if key ~= "" and (pattern == "" or find(upper(key),pattern)) then
            report_lists(key)
            report_lists("  env: %s",tabstr(rawget(environment,key))    or "unset")
            report_lists("  var: %s",tabstr(configured[key])            or "unset")
            report_lists("  exp: %s",tabstr(expansions[key])            or "unset")
            report_lists("  res: %s",resolvers.resolve(expansions[key]) or "unset")
        end
    end
    instance.environment = table.fastcopy(env)
    instance.variables   = table.fastcopy(var)
    instance.expansions  = table.fastcopy(exp)
end

function resolvers.listers.configurations(report)
    local configurations = resolvers.instance.specification
    local report = report or texio.write_nl
    for i=1,#configurations do
        report(resolvers.resolve(configurations[i]))
    end
end
