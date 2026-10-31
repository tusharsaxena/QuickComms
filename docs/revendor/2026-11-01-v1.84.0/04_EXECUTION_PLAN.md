# 04 — Execution plan

1. **`QC-RV`:** the copy, the provenance line, the `H.PositionBlock` stub and this bundle, in one commit.
2. **`QC-ADOPT`:** the Position block of the Pads and Dials Layout tabs. A characterization test comes
   first and passes on the hand-built block: widget types, order, labels, tooltips, typed writes,
   refusals and Reset. The block then goes through `O.PositionBlock`, and the test must not move. The
   offsets stay typed boxes (the library's slider would be a visible change), so each composed row is
   stamped `type = "string"`, `dialogControl = "EditBox"` and bound to the point.
3. **`QC-67`:** each group a selector picks moves to `shownWhen`, with a test that it drops and returns.
   `Settings.ShownIconRows` and the structural repaint behind it go.
4. **LibKa0s#68:** no change if the computation holds for the pad strip.
