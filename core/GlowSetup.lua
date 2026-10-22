local _, NS = ...
-- core/GlowSetup.lua — NS.GlowLib from LibKa0s-Glow-1.0: the stateless LibCustomGlow-1.0 driver seam
-- (library-stack-§7).
--
-- modules/Glow.lua starts and stops the icon and button glows through it under its two keys; the
-- driver maps the knob table to LibCustomGlow-1.0's arguments and resolves that library at every
-- call. An absent major means no glow, the same as an absent LibCustomGlow-1.0: the stub's Start
-- answers false and its Stop does nothing, and the caller still records its decision on the button.

local G = LibStub and LibStub("LibKa0s-Glow-1.0", true)

NS.GlowLib = G or { Start = function() return false end, Stop = function() end }
