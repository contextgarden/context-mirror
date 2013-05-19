if not modules then modules = { } end modules ["page-inj"] = {
    version   = 1.000,
    comment   = "Page injections",
    author    = "Wolfgang Schuster & Hans Hagen",
    copyright = "Wolfgang Schuster & Hans Hagen",
    license   = "see context related readme files",
}

-- Adapted a bit by HH: numbered states, tracking, delayed, order, etc.

local injections        = pagebuilders.injections or { }
pagebuilders.injections = injections

local report            = logs.reporter("pagebuilder","injections")
local trace             = false  trackers.register("pagebuilder.injections",function(v) trace = v end)

local variables         = interfaces.variables

local v_yes             = variables.yes
local v_previous        = variables.previous
local v_next            = variables.next

local order             = 0
local cache             = { }

function injections.save(specification) -- maybe not public, just commands.*
    order = order + 1
    cache[#cache+1] = {
        order      = order,
        name       = specification.name,
        state      = tonumber(specification.state) or specification.state,
        parameters = specification.userdata,
    }
    tex.setcount("global","c_page_boxes_flush_n",#cache)
end

function injections.flushbefore() -- maybe not public, just commands.*
    if #cache > 0 then
        local delayed = { }
        context.unprotect()
        for i=1,#cache do
            local c = cache[i]
            local oldstate = c.state
            if oldstate == v_previous then
                if trace then
                    report("entry %a, order %a, flushing due to state %a",i,c.order,oldstate)
                end
                context.page_injections_flush_saved(c.name,c.parameters)
            elseif type(oldstate) == "number" and oldstate < 0 then
                local newstate = oldstate + 1
                if newstate >= 0 then
                    newstate = v_previous
                end
                if trace then
                    report("entry %a, order %a, changing state from %a to %a",i,c.order,oldstate,newstate)
                end
                c.state = newstate
                delayed[#delayed+1] = c
            else
                delayed[#delayed+1] = c
            end
        end
        context.unprotect()
        cache = delayed
        tex.setcount("global","c_page_boxes_flush_n",#cache)
    end
end

function injections.flushafter() -- maybe not public, just commands.*
    if #cache > 0 then
        local delayed = { }
        context.unprotect()
        for i=1,#cache do
            local c = cache[i]
            local oldstate = c.state
            if oldstate == v_next then
                if trace then
                    report("entry %a, order %a, flushing due to state %a",i,c.order,oldstate)
                end
                context.page_injections_flush_saved(c.name,c.parameters)
            elseif type(oldstate) == "number" and oldstate> 0 then
                local newstate = oldstate- 1
                if newstate <= 0 then
                    newstate = v_next
                end
                if trace then
                    report("entry %a, order %a, changing state from %a to %a",i,c.order,oldstate,newstate)
                end
                c.state = newstate
                delayed[#delayed+1] = c
            end
        end
        context.protect()
        cache = delayed
        tex.setcount("global","c_page_boxes_flush_n",#cache)
    end
end

commands.page_injections_save         = injections.save
commands.page_injections_flush_after  = injections.flushafter
commands.page_injections_flush_before = injections.flushbefore
