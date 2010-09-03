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

local tasks = nodes.tasks

tasks.appendaction("processors",   "normalizers", "fonts.collections.process")                         -- todo
tasks.appendaction("processors",   "normalizers", "fonts.checkers.missing")                            -- disabled

tasks.appendaction("processors",   "characters",  "typesetters.directions.handler")                    -- disabled
tasks.appendaction("processors",   "characters",  "typesetters.cases.handler")                         -- disabled
tasks.appendaction("processors",   "characters",  "typesetters.breakpoints.handler")                   -- disabled
tasks.appendaction("processors",   "characters",  "scripts.preprocess")

tasks.appendaction("processors",   "words",       "builders.kernel.hyphenation")                       -- always on
tasks.appendaction("processors",   "words",       "languages.words.check")                             -- disabled

tasks.appendaction("processors",   "fonts",       "builders.paragraphs.solutions.splitters.split")     -- experimental
tasks.appendaction("processors",   "fonts",       "nodes.handlers.characters")                         -- maybe todo
tasks.appendaction("processors",   "fonts",       "nodes.injections.handler")                           -- maybe todo
tasks.appendaction("processors",   "fonts",       "nodes.handlers.protectglyphs", nil, "nohead")       -- maybe todo
tasks.appendaction("processors",   "fonts",       "builders.kernel.ligaturing")                        -- always on
tasks.appendaction("processors",   "fonts",       "builders.kernel.kerning")                           -- always on
tasks.appendaction("processors",   "fonts",       "nodes.handlers.stripping")                          -- disabled (might move)

tasks.appendaction("processors",   "lists",       "typesetters.spacings.handler")                      -- disabled
tasks.appendaction("processors",   "lists",       "typesetters.kerns.handler")                         -- disabled
tasks.appendaction("processors",   "lists",       "typesetters.digits.handler")                        -- disabled (after otf handling)

tasks.appendaction("shipouts",     "normalizers", "nodes.handlers.cleanuppage")                        -- disabled
tasks.appendaction("shipouts",     "normalizers", "nodes.references.handler")                          -- disabled
tasks.appendaction("shipouts",     "normalizers", "nodes.destinations.handler")                        -- disabled
tasks.appendaction("shipouts",     "normalizers", "nodes.rules.handler")                               -- disabled
tasks.appendaction("shipouts",     "normalizers", "nodes.shifts.handler")                              -- disabled
tasks.appendaction("shipouts",     "normalizers", "structures.tags.handler")                           -- disabled
tasks.appendaction("shipouts",     "normalizers", "nodes.handlers.accessibility")                      -- disabled
tasks.appendaction("shipouts",     "normalizers", "nodes.handlers.backgrounds")                        -- disabled

tasks.appendaction("shipouts",     "finishers",   "attributes.colors.handler")                         -- disabled
tasks.appendaction("shipouts",     "finishers",   "attributes.transparencies.handler")                 -- disabled
tasks.appendaction("shipouts",     "finishers",   "attributes.colorintents.handler")                   -- disabled
tasks.appendaction("shipouts",     "finishers",   "attributes.negatives.handler")                      -- disabled
tasks.appendaction("shipouts",     "finishers",   "attributes.effects.handler")                        -- disabled
tasks.appendaction("shipouts",     "finishers",   "attributes.viewerlayers.handler")                   -- disabled

tasks.appendaction("math",         "normalizers", "noads.handlers.relocate", nil, "nohead")            -- always on
tasks.appendaction("math",         "normalizers", "noads.handlers.resize",   nil, "nohead")            -- always on
tasks.appendaction("math",         "normalizers", "noads.handlers.respace",  nil, "nohead")            -- always on
tasks.appendaction("math",         "normalizers", "noads.handlers.check",    nil, "nohead")            -- always on
tasks.appendaction("math",         "normalizers", "noads.handlers.tags",     nil, "nohead")            -- disabled

tasks.appendaction("math",         "builders",    "builders.kernel.mlist_to_hlist")                    -- always on

-- quite experimental

tasks.appendaction("finalizers",   "lists",       "nodes.handlers.graphicvadjust")                     -- todo
tasks.appendaction("finalizers",   "fonts",       "builders.paragraphs.solutions.splitters.optimize")  -- experimental

-- rather new

tasks.appendaction("mvlbuilders",  "normalizers", "nodes.handlers.migrate")                            --
tasks.appendaction("mvlbuilders",  "normalizers", "builders.vspacing.pagehandler")                        -- last !

tasks.appendaction("vboxbuilders", "normalizers", "builders.vspacing.vboxhandler")                        --

-- speedup: only kick in when used

tasks.disableaction("processors",  "fonts.checkers.missing")
tasks.disableaction("processors",  "chars.handle_breakpoints")
tasks.disableaction("processors",  "typesetters.cases.handler")
tasks.disableaction("processors",  "typesetters.digits.handler")
tasks.disableaction("processors",  "typesetters.breakpoints.handler")
tasks.disableaction("processors",  "typesetters.directions.handler")
tasks.disableaction("processors",  "languages.words.check")
tasks.disableaction("processors",  "typesetters.spacings.handler")
tasks.disableaction("processors",  "typesetters.kerns.handler")
tasks.disableaction("processors",  "nodes.handlers.stripping")

tasks.disableaction("shipouts",    "nodes.rules.handler")
tasks.disableaction("shipouts",    "nodes.shifts.handler")
tasks.disableaction("shipouts",    "attributes.colors.handler")
tasks.disableaction("shipouts",    "attributes.transparencies.handler")
tasks.disableaction("shipouts",    "attributes.colorintents.handler")
tasks.disableaction("shipouts",    "attributes.effects.handler")
tasks.disableaction("shipouts",    "attributes.negatives.handler")
tasks.disableaction("shipouts",    "attributes.viewerlayers.handler")
tasks.disableaction("shipouts",    "structures.tags.handler")
tasks.disableaction("shipouts",    "nodes.handlers.accessibility")
tasks.disableaction("shipouts",    "nodes.handlers.backgrounds")
tasks.disableaction("shipouts",    "nodes.handlers.cleanuppage")

tasks.disableaction("shipouts",    "nodes.references.handler")
tasks.disableaction("shipouts",    "nodes.destinations.handler")

tasks.disableaction("mvlbuilders", "nodes.handlers.migrate")

tasks.disableaction("processors",  "builders.paragraphs.solutions.splitters.split")
tasks.disableaction("finalizers",  "builders.paragraphs.solutions.splitters.optimize")

tasks.disableaction("math",        "noads.handlers.tags")

callbacks.freeze("find_.*_file", "find file using resolver")
callbacks.freeze("read_.*_file", "read file at once")
callbacks.freeze("open_.*_file", "open file for reading")
