-- filename : l-set.lua
-- author   : Hans Hagen, PRAGMA-ADE, Hasselt NL
-- copyright: PRAGMA ADE / ConTeXt Development Team
-- license  : see context related readme files

if not versions then versions = { } end versions['l-set'] = 1.001

if not set then set = { } end

do

    local nums   = { }
    local tabs   = { }
    local concat = table.concat

    set.create = table.tohash

    function set.tonumber(t)
        if next(t) then
            local s = ""
        --  we could save mem by sorting, but it slows down
            for k, v in pairs(t) do
                if v then
                --  why bother about the leading space
                    s = s .. " " .. k
                end
            end
            if not nums[s] then
                tabs[#tabs+1] = t
                nums[s] = #tabs
            end
            return nums[s]
        else
            return 0
        end
    end

    function set.totable(n)
        if n == 0 then
            return { }
        else
            return tabs[n] or { }
        end
    end

    function set.contains(n,s)
        if type(n) == "table" then
            return n[s]
        elseif n == 0 then
            return false
        else
            local t = tabs[n]
            return t and t[s]
        end
    end

end

--~ local c = set.create{'aap','noot','mies'}
--~ local s = set.tonumber(c)
--~ local t = set.totable(s)
--~ print(t['aap'])
--~ local c = set.create{'zus','wim','jet'}
--~ local s = set.tonumber(c)
--~ local t = set.totable(s)
--~ print(t['aap'])
--~ print(t['jet'])
--~ print(set.contains(t,'jet'))
--~ print(set.contains(t,'aap'))

