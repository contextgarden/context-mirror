if not modules then modules = { } end modules ['task-ini'] = {
    version   = 1.001,
    comment   = "companion to task-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- this is a temporary solution, we need to isolate some modules and then
-- the load order can determine the trickery to be applied to node lists
--
-- we can disable more handlers and enable then when really used (*)

tasks.appendaction("processors", "normalizers", "fonts.collections.process")                 -- todo
tasks.appendaction("processors", "normalizers", "fonts.checkers.missing")                    -- disabled

tasks.appendaction("processors", "characters",  "chars.handle_mirroring")                    -- disabled
tasks.appendaction("processors", "characters",  "chars.handle_casing")                       -- disabled
tasks.appendaction("processors", "characters",  "chars.handle_digits")                       -- disabled
tasks.appendaction("processors", "characters",  "chars.handle_breakpoints")                  -- disabled
tasks.appendaction("processors", "characters",  "scripts.preprocess")

tasks.appendaction("processors", "words",       "kernel.hyphenation")                        -- always on
tasks.appendaction("processors", "words",       "languages.words.check")                     -- disabled

tasks.appendaction("processors", "fonts",       "nodes.process_characters")                  -- maybe todo
tasks.appendaction("processors", "fonts",       "nodes.inject_kerns")                        -- maybe todo
tasks.appendaction("processors", "fonts",       "nodes.protect_glyphs", nil, "nohead")       -- maybe todo
tasks.appendaction("processors", "fonts",       "kernel.ligaturing")                         -- always on
tasks.appendaction("processors", "fonts",       "kernel.kerning")                            -- always on

tasks.appendaction("processors", "lists",       "lists.handle_spacing")                      -- disabled
tasks.appendaction("processors", "lists",       "lists.handle_kerning")                      -- disabled

tasks.appendaction("shipouts",   "normalizers", "nodes.cleanup_page")                        -- maybe todo
tasks.appendaction("shipouts",   "normalizers", "nodes.add_references")                      -- disabled
tasks.appendaction("shipouts",   "normalizers", "nodes.add_destinations")                    -- disabled
tasks.appendaction("shipouts",   "normalizers", "nodes.rules.process")                       -- disabled
tasks.appendaction("shipouts",   "normalizers", "nodes.shifts.process")                      -- disabled

tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_color")                     -- disabled
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_transparency")              -- disabled
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_colorintent")               -- disabled
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_negative")                  -- disabled
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_effect")                    -- disabled
tasks.appendaction("shipouts",   "finishers",   "shipouts.handle_viewerlayer")               -- disabled

tasks.appendaction("math",       "normalizers", "noads.relocate_characters", nil, "nohead")  -- always on
tasks.appendaction("math",       "normalizers", "noads.resize_characters",   nil, "nohead")  -- always on
tasks.appendaction("math",       "normalizers", "noads.respace_characters",  nil, "nohead")  -- always on

tasks.appendaction("math",       "builders",    "noads.mlist_to_hlist")                      -- always on

-- quite experimental

tasks.appendaction("finalizers", "lists",       "nodes.repackage_graphicvadjust")            -- todo

-- rather new

tasks.appendaction("pagebuilders", "normalizers", "nodes.migrate_outwards")
tasks.appendaction("pagebuilders", "normalizers", "nodes.handle_page_spacing") -- last !

tasks.appendaction("vboxbuilders", "normalizers", "nodes.handle_vbox_spacing")

-- speedup: only kick in when used

tasks.disableaction("processors", "fonts.checkers.missing")
tasks.disableaction("processors", "chars.handle_breakpoints")
tasks.disableaction("processors", "chars.handle_casing")
tasks.disableaction("processors", "chars.handle_digits")
tasks.disableaction("processors", "chars.handle_mirroring")
tasks.disableaction("processors", "languages.words.check")
tasks.disableaction("processors", "lists.handle_spacing")
tasks.disableaction("processors", "lists.handle_kerning")

tasks.disableaction("shipouts",   "nodes.rules.process")
tasks.disableaction("shipouts",   "nodes.shifts.process")
tasks.disableaction("shipouts",   "shipouts.handle_color")
tasks.disableaction("shipouts",   "shipouts.handle_transparency")
tasks.disableaction("shipouts",   "shipouts.handle_colorintent")
tasks.disableaction("shipouts",   "shipouts.handle_effect")
tasks.disableaction("shipouts",   "shipouts.handle_negative")
tasks.disableaction("shipouts",   "shipouts.handle_viewerlayer")

tasks.disableaction("shipouts",   "nodes.add_references")
tasks.disableaction("shipouts",   "nodes.add_destinations")

tasks.disableaction("pagebuilders", "nodes.migrate_outwards")

callbacks.freeze("find_.*_file", "find file using resolver")
callbacks.freeze("read_.*_file", "read file at once")
callbacks.freeze("open_.*_file", "open file for reading")
