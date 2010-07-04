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

local function list(list,report)
    local instance = resolvers.instance
    local pat = upper(pattern or "","")
    local report = report or texio.write_nl
    local sorted = table.sortedkeys(list)
    for i=1,#sorted do
        local key = sorted[i]
        if instance.pattern == "" or find(upper(key),pat) then
            if instance.kpseonly then
                if instance.kpsevars[key] then
                    report(format("%s=%s",key,tabstr(list[key])))
                end
            else
                report(format('%s %s=%s',(instance.kpsevars[key] and 'K') or 'E',key,tabstr(list[key])))
            end
        end
    end
end

function resolvers.listers.variables () list(resolvers.instance.variables ) end
function resolvers.listers.expansions() list(resolvers.instance.expansions) end

function resolvers.listers.configurations(report)
    local report = report or texio.write_nl
    local instance = resolvers.instance
    local sorted = table.sortedkeys(instance.kpsevars)
    for i=1,#sorted do
        local key = sorted[i]
        if not instance.pattern or (instance.pattern=="") or find(key,instance.pattern) then
            report(format("%s\n",key))
            local order = instance.order
            for i=1,#order do
                local str = order[i][key]
                if str then
                    report(format("\t%s\t%s",i,str))
                end
            end
            report("")
        end
    end
end
