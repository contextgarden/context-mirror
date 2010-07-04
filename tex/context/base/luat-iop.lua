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

local lower, find, sub = string.lower, string.find, string.sub

local ioinp = io.inp if not ioinp then ioinp = { } io.inp = ioinp end
local ioout = io.out if not ioout then ioout = { } io.out = ioout end

ioinp.modes, ioout.modes = { }, { }  -- functions

local inp_blocked, inp_permitted = { }, { }
local out_blocked, out_permitted = { }, { }

local function i_inhibit(name) inp_blocked  [#inp_blocked  +1] = name end
local function o_inhibit(name) out_blocked  [#out_blocked  +1] = name end
local function i_permit (name) inp_permitted[#inp_permitted+1] = name end
local function o_permit (name) out_permitted[#out_permitted+1] = name end

ioinp.inhibit, ioinp.permit = i_inhibit, o_permit
ioout.inhibit, ioout.permit = o_inhibit, o_permit

local blocked_openers = { } -- *.open(name,method)

function io.register_opener(func)
    blocked_openers[#blocked_openers+1] = func
end

local function checked(name,blocked,permitted)
    local n = lower(name)
    for _,b in next, blocked do
        if find(n,b) then
            for _,p in next, permitted do
                if find(n,p) then
                    return true
                end
            end
            return false
        end
    end
    return true
end

function io.finalize_openers(func)
    if #out_blocked > 0 or #inp_blocked > 0 then
        local open = func -- why not directly?
        return function(name,method)
            if method and find(method,'[wa]') then
                if #out_blocked > 0 and not checked(name,out_blocked,out_permitted) then
                    -- print("writing to " .. name .. " is not permitted")
                    return nil
                end
            else
                if #inp_blocked > 0 and not checked(name,inp_blocked,inp_permitted) then
                    -- print("reading from " .. name .. " is not permitted")
                    return nil
                end
            end
            return open(name,method)
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

local inpout = { 'inp', 'out' }

function io.set_opener_modes(i,o)
    local first = sub(i,1,1)
    for k=1,#inpout do
        local iov = io[inpout[k]]
        local f = iov[i] or iov[first]
        if f then f() end
    end
    io.open = io.finalize_openers(io.open)
end

-- restricted

function ioinp.modes.restricted()
    i_inhibit('^%.[%a]')
end

function ioout.modes.restricted()
    o_inhibit('^%.[%a]')
end

-- paranoid

function ioinp.modes.paranoid()
    i_inhibit('.*')
    i_inhibit('%.%.')
    i_permit('^%./')
    i_permit('[^/]')
    resolvers.do_with_path('TEXMF',i_permit)
end

function ioout.modes.paranoid()
    o_inhibit('.*')
    resolvers.do_with_path('TEXMFOUTPUT',o_permit)
end

-- handy

function ioinp.modes.handy()
    i_inhibit('%.%.')
    if os.type == 'windows' then
        i_inhibit('/windows/')
        i_inhibit('/winnt/')
    else
        i_inhibit('^/etc')
    end
end

function ioout.modes.handy()
    o_inhibit('.*')
    o_permit('%./')
    o_permit('^%./')
    o_permit('[^/]')
end

--~ io.set_opener_modes('p','p')
--~ io.set_opener_modes('r','r')
--~ io.set_opener_modes('h','h')
