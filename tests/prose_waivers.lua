-- tests/prose_waivers.lua — the British spellings the prose gate (localization-§5) is told to leave.
--
-- Per FILE and per WORD, never per file alone. Every entry below is in docs/brainstorm/, the
-- pre-scaffold brainstorm and research record. The owner keeps it verbatim as history (the phase
-- 0-1 plan, Task 1: "keep docs/brainstorm/ as it is"); it is loaded by nothing and .pkgmeta keeps
-- docs/ out of the package. Anything written after the scaffold is US English and is not waived:
-- a new British spelling in these files, or any spelling in a new file, still turns the gate red.

return {
    waived = {
        ["docs/brainstorm/02-research-ux-prior-art.md"] = {
            ["favour"] = true, ["centre"] = true, ["analogue"] = true, ["colour"] = true, ["grey"] = true,
        },
        ["docs/brainstorm/03-research-ka0s-fit.md"] = {
            ["grey"] = true,
        },
        ["docs/brainstorm/04-brainstorm.md"] = {
            ["centre"] = true, ["favour"] = true, ["colour"] = true, ["behaviour"] = true,
            ["labelled"] = true,
        },
    },
}
