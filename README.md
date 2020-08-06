# TTACC
#### Transport Triggered Architecture Combinator Computer, architecture and language specifications and compiler
---

A (WIP) compiler for a  modular [transport triggered architecture](https://en.wikipedia.org/wiki/Transport_triggered_architecture "Wikipedia") based computer built from combinators in Factorio.

---
> Current features:
> - Basic Python script to convert between Factorio blueprint strings and JSON

> Coming Soon<sup>TM</sup>:
> - Documentation describing architecture and compiler
> - Basic implemenation of minimal hardware (core, register, RAM) and instructions (MOVE, JUMP, SLEEP)
> - Compiling to circuit frames for manual programming of computer

---
> Signals:
> - Dot: RESERVED for internal use, external application to the execute line will resilt in an immediate jump to any instruction of index Dot=X, external application to the literal or data lines may result in activation of bus gates on those lines.
> - Info: Alternate instruction indexes.
> - Check: Delay next instruction in ticks.
> - Black: Jump to instruction of index Dot=X with one tick delay.
> - Grey: Jump to instruction of index Dot=X with Check+3 ticks delay.
> - White: Halt state, positive to set, negative to unset.

---

Written in [Lua](lua.org) 5.4.0 with some [Python](python.org) 3.8.3, Lua is required to run the compiler
