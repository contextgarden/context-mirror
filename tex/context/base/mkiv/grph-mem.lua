if not modules then modules = { } end modules ['grph-mem'] = {
    version   = 1.001,
    comment   = "companion to grph-inc.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- very experimental and likely to change
--
-- \startluacode
--     figures.setmemstream("whatever",io.loaddata("t:/sources/cow.pdf"))
-- \stopluacode
--
-- \externalfigure[memstream:///t:/sources/cow.pdf]
-- \externalfigure[memstream:///whatever]

local gsub = string.gsub

local report = logs.reporter("memstream")
local trace  = false  trackers.register  ("graphics.memstreams", function(v) trace = v end)
local data   = { }
local opened = { }

local function setmemstream(name,stream,once)
    if once and data[name] then
        if trace then
            report("not overloading %a",name) --
        end
        return data[name]
    end
    local memstream, identifier = epdf.openMemStream(stream,#stream,name)
    if not identifier then
        report("no valid stream %a",name)
        identifier = "invalid-memstream"
    elseif trace then
        report("setting %a with identifier %a",name,identifier)
    end
    data  [name] = identifier
    opened[name] = memstream
    return identifier
end

resolvers.setmemstream = setmemstream

function resolvers.finders.memstream(specification)
    local name       = specification.path
    local identifier = data[name]
    if identifier then
        if trace then
            report("reusing %a with identifier %a",name,identifier)
        end
        return identifier
    end
    local stream = io.loaddata(name)
    if not stream or stream == "" then
        if trace then
            report("no valid file %a",name)
        end
        return resolvers.finders.notfound()
    else
        return setmemstream(name,stream)
    end
end

local flush = { }

function resolvers.resetmemstream(name,afterpage)
    if afterpage then
        flush[#flush+1] = name
    else
        opened[name] = nil
    end
end

luatex.registerpageactions(function()
    if #flush > 0 then
        for i=1,#flush do
            opened[flush[i]] = nil -- we keep of course data[name] because of reuse
        end
        flush = { }
    end
end)

figures.identifiers.list[#figures.identifiers.list+1] = function(specification)
    local name = specification.request.name
    if name then
        local base = gsub(name,"^memstream:///","")
        if base ~= name then
            local identifier = data[base]
            if identifier then
                if trace then
                    report("requested %a has identifier %s",name,identifier)
                end
                specification.status.status = 1
                specification.used.fullname = name
            else
                if trace then
                    report("requested %a is not found",name)
                end
            end
        end
    end
end

figures.setmemstream = resolvers.setmemstream
