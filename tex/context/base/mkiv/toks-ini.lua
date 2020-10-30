if not modules then modules = { } end modules ['toks-ini'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

tokens = tokens or { }

local tokens     = tokens
local token      = token -- the built in one
local next       = next
local tonumber   = tonumber
local tostring   = tostring
local utfchar    = utf.char
local char       = string.char
local printtable = table.print
local concat     = table.concat
local format     = string.format

local commands  = token.commands()
tokens.commands = utilities.storage.allocate(table.swapped(commands,commands))
tokens.values   = { }

local scan_toks        = token.scan_toks
local scan_string      = token.scan_string
local scan_argument    = token.scan_argument
local scan_delimited   = token.scan_delimited
local scan_tokenlist   = token.scan_tokenlist or scan_string
local scan_integer     = token.scan_integer or token.scan_int
local scan_cardinal    = token.scan_cardinal
local scan_code        = token.scan_code
local scan_token_code  = token.scan_token_code
local scan_dimen       = token.scan_dimen
local scan_glue        = token.scan_glue
local scan_skip        = token.scan_skip
local scan_keyword     = token.scan_keyword
local scan_keyword_cs  = token.scan_keyword_cs or scan_keyword
local scan_token       = token.scan_token
local scan_box         = token.scan_box
local scan_word        = token.scan_word
local scan_letters     = token.scan_letters or scan_word -- lmtx
local scan_key         = token.scan_key
local scan_value       = token.scan_value
local scan_char        = token.scan_char
local scan_number      = token.scan_number -- not defined
local scan_csname      = token.scan_csname
local scan_real        = token.scan_real
local scan_float       = token.scan_float
local scan_luanumber   = token.scan_luanumber   or scan_float    -- only lmtx
local scan_luainteger  = token.scan_luainteger  or scan_integer  -- only lmtx
local scan_luacardinal = token.scan_luacardinal or scan_cardinal -- only lmtx

local set_macro        = token.set_macro
local set_char         = token.set_char
local set_lua          = token.set_lua

local create_token     = token.create
local new_token        = token.new
local is_defined       = token.is_defined
local is_token         = token.is_token

tokens.new             = new_token
tokens.create          = create_token
tokens.istoken         = is_token
tokens.isdefined       = is_defined
tokens.defined         = is_defined

local bits = {
    escape      = 0x00000001, -- 2^00
    begingroup  = 0x00000002, -- 2^01
    endgroup    = 0x00000004, -- 2^02
    mathshift   = 0x00000008, -- 2^03
    alignment   = 0x00000010, -- 2^04
    endofline   = 0x00000020, -- 2^05
    parameter   = 0x00000040, -- 2^06
    superscript = 0x00000080, -- 2^07
    subscript   = 0x00000100, -- 2^08
    ignore      = 0x00000200, -- 2^09
    space       = 0x00000400, -- 2^10 -- 1024
    letter      = 0x00000800, -- 2^11
    other       = 0x00001000, -- 2^12
    active      = 0x00002000, -- 2^13
    comment     = 0x00004000, -- 2^14
    invalid     = 0x00008000, -- 2^15
    --
    character   = 0x00001800, -- 2^11 + 2^12
    whitespace  = 0x00002400, -- 2^13 + 2^10 --    / needs more checking
    --
    open        = 0x00000402, -- 2^10 + 2^01 -- space + begingroup
    close       = 0x00000404, -- 2^10 + 2^02 -- space + endgroup
}

-- for k, v in next, bits do bits[v] = k end

tokens.bits = bits

-- words are space or \relax terminated and the trailing space is gobbled; a word
-- can contain any non-space letter/other (see archive for implementation in lua)

if not scan_number then

    scan_number = function(base)
        local s = scan_word()
        if not s then
            return nil
        elseif base then
            return tonumber(s,base)
        else
            return tonumber(s)
        end
    end

end

local function scan_boolean()
    local kw = scan_word()
    if kw == "true" then
        return true
    elseif kw == "false" then
        return false
    else
        return nil
    end
end

local function scan_verbatim()
    return scan_argument(false)
end

if not scan_box then

    local scan_list = token.scan_list
    local put_next  = token.put_next

    scan_box = function(s)
        if s == "hbox" or s == "vbox" or s == "vtop" then
            put_next(create_token(s))
        end
        return scan_list()
    end

    token.scan_box = scan_box

end

tokens.scanners = { -- these expand
    token          = scan_token,
    toks           = scan_toks,
    tokens         = scan_toks,
    box            = scan_box,
    hbox           = function() return scan_box("hbox") end,
    vbox           = function() return scan_box("vbox") end,
    vtop           = function() return scan_box("vtop") end,
    dimen          = scan_dimen,
    dimension      = scan_dimen,
    glue           = scan_glue,
    gluevalues     = function() return scan_glue(false,false,true) end,
    gluespec       = scan_skip,
    integer        = scan_integer,
    cardinal       = scan_cardinal,
    real           = scan_real,
    float          = scan_float,
    luanumber      = scan_luanumber,
    luainteger     = scan_luainteger,
    luacardinal    = scan_luacardinal,
    count          = scan_integer,
    string         = scan_string,
    argument       = scan_argument,
    delimited      = scan_delimited,
    tokenlist      = scan_tokenlist,
    verbatim       = scan_verbatim, -- detokenize
    code           = scan_code,
    tokencode      = scan_token_code,
    word           = scan_word,
    letters        = scan_letters,
    key            = scan_key,
    value          = scan_value,
    char           = scan_char,
    number         = scan_number,
    boolean        = scan_boolean,
    keyword        = scan_keyword,
    keywordcs      = scan_keyword_cs,
    csname         = scan_csname,

    next           = token.scan_next,
    nextexpanded   = token.scan_next_expanded,

    peek           = token.peek_next,
    peekexpanded   = token.peek_next_expanded,
    peekchar       = token.peek_next_char,

    skip           = token.skip_next,
    skipexpanded   = token.skip_next_expanded,

    cmdchr         = token.scan_cmdchr,
    cmdchrexpanded = token.scan_cmdchr_expanded,

    ischar         = token.is_next_char,
}

tokens.getters = { -- these don't expand
    meaning = token.get_meaning,
    macro   = token.get_macro,
    token   = token.scan_next or token.get_next, -- not here, use scanners.next or token
    cstoken = token.get_cstoken,
    count   = tex.getcount,
    dimen   = tex.getdimen,
    skip    = tex.getglue,
    glue    = tex.getglue,
    skip    = tex.getmuglue,
    glue    = tex.getmuglue,
    box     = tex.getbox,
}

tokens.setters = {
    macro = set_macro,
    char  = set_char,
    lua   = set_lua,
    count = tex.setcount,
    dimen = tex.setdimen,
    skip  = tex.setglue,
    glue  = tex.setglue,
    skip  = tex.setmuglue,
    glue  = tex.setmuglue,
    box   = tex.setbox,
}

token.accessors = {
    command    = token.get_command,
    cmd        = token.get_command,
    cmdname    = token.get_cmdname,
    name       = token.get_cmdname,
    csname     = token.get_csname,
    index      = token.get_index,
    active     = token.get_active,
    frozen     = token.get_frozen,
    protected  = token.get_protected,
    expandable = token.get_protected,
    user       = token.get_user,
    cmdchrcs   = token.get_cmdchrcs,
    active     = token.get_active,
    range      = token.get_range,
}

-- static int run_scan_token(lua_State * L)
-- {
--     saved_tex_scanner texstate;
--     save_tex_scanner(texstate);
--     get_x_token();
--     make_new_token(L, cur_cmd, cur_chr, cur_cs);
--     unsave_tex_scanner(texstate);
--     return 1;
-- }
--
-- static int run_get_future(lua_State * L)
-- {
--  /* saved_tex_scanner texstate; */
--  /* save_tex_scanner(texstate); */
--     get_token();
--     make_new_token(L, cur_cmd, cur_chr, cur_cs);
--     back_input();
--  /* unsave_tex_scanner(texstate); */
--     return 1;
-- }

if setinspector then

    local simple = { letter = "letter", other_char = "other" }

    local astable = function(t)
        if t and is_token(t) then
            local cmdname = t.cmdname
            local simple  = simple[cmdname]
            if simple then
                return {
                    id         = t.id,
                    category   = simple,
                    character  = utfchar(t.mode) or nil,
                }
            else
                return {
                    command    = t.command,
                    id         = t.id,
                    tok        = t.tok,
                    csname     = t.csname,
                    active     = t.active,
                    expandable = t.expandable,
                    protected  = t.protected,
                    frozen     = t.frozen,
                    mode       = t.mode,
                    index      = t.index,
                    user       = t.user,
                    cmdname    = cmdname,
                }
            end
        end
    end

    tokens.astable = astable

    setinspector("token",function(v) local t = astable(v) if t then printtable(t,tostring(v)) return true end end)

end

tokens.cache = table.setmetatableindex(function(t,k)
    if not is_defined(k) then
        set_macro(k,"","global")
    end
    local v = create_token(k)
    t[k] = v
    return v
end)

if LUATEXVERSION < 114 then

    local d = tokens.defined
    local c = tokens.create

    function tokens.defined(s,b)
        if b then
            return d(s)
        else
            return c(s).cmd_name == "undefined_cmd"
        end
    end

end
