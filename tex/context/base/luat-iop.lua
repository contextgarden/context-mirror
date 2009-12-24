if not modules then modules = { } end modules ['luat-iop'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this paranoid stuff in web2c ... we cannot hook checks into the
-- input functions because one can always change the callback but
-- we can feed back specific patterns and paths into the next
-- mechanism

if not io.inp then io.inp = { } end
if not io.out then io.out = { } end

io.inp.blocked      = { }
io.out.blocked      = { }
io.inp.permitted    = { }
io.out.permitted    = { }
io.inp.modes        = { } -- functions
io.out.modes        = { } -- functions

io.blocked_openers  = { } -- *.open(name,method)

function io.inp.inhibit  (name) table.insert(io.inp.blocked,   name) end
function io.out.inhibit  (name) table.insert(io.out.blocked,   name) end
function io.inp.permit   (name) table.insert(io.inp.permitted, name) end
function io.out.permit   (name) table.insert(io.out.permitted, name) end

function io.register_opener(func) table.insert(io.blocked_openers,   func) end

function io.finalize_openers(func)
    if (#io.out.blocked > 0) or (#io.inp.blocked > 0) then
        do
            local open          = func
            local out_permitted = io.out.permitted
            local inp_permitted = io.inp.permitted
            local out_blocked   = io.out.blocked
            local inp_blocked   = io.inp.blocked
            return function(name,method)
                local function checked(blocked, permitted)
                    local n = string.lower(name)
                    for _,b in pairs(blocked) do
                        if string.find(n,b) then
                            for _,p in pairs(permitted) do
                                if string.find(n,p) then
                                    return true
                                end
                            end
                            return false
                        end
                    end
                    return true
                end
                if method and string.find(method,'[wa]') then
                    if #out.blocked > 0 then
                        if not checked(out_blocked, out_permitted) then
                            -- print("writing to " .. name .. " is not permitted")
                            return nil
                        end
                    end
                else
                    if #inp.blocked > 0 then
                        if not checked(inp_blocked, inp_permitted) then
                            -- print("reading from " .. name .. " is not permitted")
                            return nil
                        end
                    end
                end
                return open(name,method)
            end
        end
    else
        return func
    end
end

--~ io.inp.inhibit('^%.')
--~ io.inp.inhibit('^/etc')
--~ io.inp.inhibit('/windows/')
--~ io.inp.inhibit('/winnt/')
--~ io.inp.permit('c:/windows/wmsetup.log')

--~ io.open = io.finalize_openers(io.open)

--~ f = io.open('.tex')                   print(f)
--~ f = io.open('tufte.tex')              print(f)
--~ f = io.open('t:/sources/tufte.tex')   print(f)
--~ f = io.open('/etc/passwd')            print(f)
--~ f = io.open('c:/windows/crap.log')    print(f)
--~ f = io.open('c:/windows/wmsetup.log') print(f)

function io.set_opener_modes(i,o)
    for _,v in pairs({'inp','out'}) do
        if io[v][i] then
            io[v][i]()
        elseif io[v][string.sub(i,1,1)] then
            io[v][string.sub(i,1,1)]()
        end
    end
    io.open = io.finalize_openers(io.open)
end

function io.set_opener_modes(i,o)
    local f
    for _,v in pairs({'inp','out'}) do
        f = io[v][i] or io[v][string.sub(i,1,1)]
        if f then f() end
    end
    io.open = io.finalize_openers(io.open)
end

-- restricted

function io.inp.modes.restricted()
    io.inp.inhibit('^%.[%a]')
end
function io.out.modes.restricted()
    io.out.inhibit('^%.[%a]')
end

-- paranoid

function io.inp.modes.paranoid()
    io.inp.inhibit('.*')
    io.inp.inhibit('%.%.')
    io.inp.permit('^%./')
    io.inp.permit('[^/]')
    resolvers.do_with_path('TEXMF',io.inp.permit)
end
function io.out.modes.paranoid()
    io.out.inhibit('.*')
    resolvers.do_with_path('TEXMFOUTPUT',io.out.permit)
end

-- handy

function io.inp.modes.handy()
    io.inp.inhibit('%.%.')
    if os.type == 'windows' then
        io.inp.inhibit('/windows/')
        io.inp.inhibit('/winnt/')
    else
        io.inp.inhibit('^/etc')
    end
end
function io.out.modes.handy()
    io.out.inhibit('.*')
    io.out.permit('%./')
    io.out.permit('^%./')
    io.out.permit('[^/]')
end

--~ io.set_opener_modes('p','p')
--~ io.set_opener_modes('r','r')
--~ io.set_opener_modes('h','h')
