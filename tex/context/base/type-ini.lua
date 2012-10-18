if not modules then modules = { } end modules ['type-ini'] = {
    version   = 1.001,
    comment   = "companion to type-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- more code will move here

local gsub = string.gsub

local report_typescripts = logs.reporter("fonts","typescripts")

local patterns = { "type-imp-%s.mkiv", "type-imp-%s.tex", "type-%s.mkiv", "type-%s.tex" } -- this will be imp only

local function action(name,foundname)
    context.startreadingfile()
    context.pushendofline()
    context.unprotect()
    context.input(foundname)
    context.protect()
    context.popendofline()
    context.stopreadingfile()
end

local name_one, name_two

local function failure_two(name)
    report_typescripts("unknown: library '%s' or '%s'",name_one,name_two)
end

local function failure_one(name)
    name_two = gsub(name,"%-.*$","")
    if name_two == name then
        report_typescripts("unknown: library '%s'",name_one)
    else
        commands.uselibrary {
            name     = name_two,
            patterns = patterns,
            action   = action,
            failure  = failure_two,
            onlyonce = false, -- will become true
        }
    end
end

function commands.doprocesstypescriptfile(name)
    name_one = gsub(name,"^type%-","")
    commands.uselibrary {
        name     = name_one,
        patterns = patterns,
        action   = action,
        failure  = failure_one,
        onlyonce = false, -- will become true
    }
end

local patterns = { "type-imp-%s.mkiv", "type-imp-%s.tex" }

local function failure(name)
    report_typescripts("unknown: library '%s'",name)
end

function commands.loadtypescriptfile(name) -- a more specific name
    commands.uselibrary {
        name     = gsub(name,"^type%-",""),
        patterns = patterns,
        action   = action,
        failure  = failure,
        onlyonce = false, -- will become true
    }
end
