# Waveform Analysis — Synchronous FIFO

## Tool: EDA Playground EPWave
## Date: 2026-07-01

---

## Signals Observed

| Signal | Type | Description |
|--------|------|-------------|
| clk | input | 100 MHz system clock |
| rst_n | input | Active-low reset |
| wr_en | input | Write enable |
| rd_en | input | Read enable |
| wr_data[7:0] | input | Data written in |
| rd_data[7:0] | output | Data read out (combinational) |
| wr_ptr[3:0] | internal | Write pointer (0-15) |
| rd_ptr[3:0] | internal | Read pointer (0-15) |
| count[4:0] | internal | Fill level (0-16) |
| full | output | FIFO full flag |
| empty | output | FIFO empty flag |
| overflow | output | Illegal write flag |
| underflow | output | Illegal read flag |

---

## Phase-by-Phase Analysis

### Phase 1: Reset (t = 0 to ~50ns)

```
rst_n:   0 ───────────────────► 1
count:   X ───────────────────► 00
empty:   X ───────────────────► 1
wr_ptr:  X ───────────────────► 0
rd_ptr:  X ───────────────────► 0
```

**Observation:** All signals show X (unknown) before reset. After rst_n goes high,
count resets to 0 and empty asserts immediately. Correct behavior. ✅

---

### Phase 2: Test 2 — Write 5 Values

```
wr_data sequence: 0x0A → 0x14 → 0x1E → 0x28 → 0x32
                  (10)    (20)    (30)    (40)    (50)

count:   00 → 01 → 02 → 03 → 04 → 05
wr_ptr:   0 →  1 →  2 →  3 →  4 →  5
empty:    0 (de-asserts on first write)
full:     0 (only 5 of 16 slots used)
```

**Observation:** count increments by 1 on each valid write. wr_ptr advances
correctly. empty de-asserts after first write. full stays low. ✅

---

### Phase 3: Test 2 — Read 5 Values (FIFO Order Check)

```
rd_data sequence: 0x0A → 0x14 → 0x1E → 0x28 → 0x32
                  (10)    (20)    (30)    (40)    (50)
                   ↑ Same order as written — FIFO confirmed!

count:   05 → 04 → 03 → 02 → 01 → 00
rd_ptr:   0 →  1 →  2 →  3 →  4 →  5
empty:  asserts when count hits 00
```

**Observation:** Data comes out in exact write order. rd_data is combinational —
it changes IMMEDIATELY when rd_ptr advances (no extra clock needed). ✅

---

### Phase 4: Test 3 — Fill to Full (16 Writes)

```
count:  00→01→02→03→04→05→06→07→08→09→0A→0B→0C→0D→0E→0F→10
                                                            ↑
                                                      full asserts here!
wr_ptr: 0→1→2→3→4→5→6→7→8→9→A→B→C→D→E→F→0
                                           ↑
                                    WRAP-AROUND (F→0)
full:   _______________________________________/‾‾‾‾\
```

**Key observation:** wr_ptr wraps from 0xF to 0x0 naturally (4-bit overflow).
full flag asserts exactly when count = 0x10 = 16 decimal. ✅

---

### Phase 5: Test 4 — Overflow Detection

```
full:      ‾‾‾‾‾‾‾‾‾‾‾‾‾
wr_en:     __/‾\_________
overflow:  __/‾\_________  ← 1-cycle pulse only!

count:     stays at 0x10 (data dropped safely)
wr_ptr:    does NOT advance (write blocked)
```

**Observation:** overflow fires for exactly 1 clock cycle when wr_en=1 and
full=1. Memory is NOT corrupted — wr_ptr does not advance. ✅

---

### Phase 6: Test 5 — Drain to Empty (16 Reads)

```
rd_data: 01→02→03→04→05→06→07→08→09→0A→0B→0C→0D→0E→0F→10
          (1→2→3→4→5→6→7→8→9→10→11→12→13→14→15→16 decimal)
          ↑ Correct FIFO order confirmed again!

count:  10→0F→0E→0D→...→02→01→00
rd_ptr:  0→ 1→ 2→ 3→...→ E→ F→ 0  ← wraps back to 0!
empty:  asserts when count = 00
```

**Observation:** Both pointers (wr_ptr and rd_ptr) have wrapped through the full
circular buffer. FIFO ordering verified across full depth. ✅

---

### Phase 7: Test 6 — Underflow Detection

```
empty:      ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
rd_en:      __/‾\___________
underflow:  __/‾\___________  ← 1-cycle pulse

rd_ptr: does NOT advance (read blocked)
rd_data: holds last valid value (no garbage)
```

**Observation:** underflow fires for 1 cycle when rd_en=1 and empty=1.
rd_ptr does not advance — design is safe. ✅

---

### Phase 8: Tests 7 & 8 — Simultaneous R+W and Corner Cases

```
Test 7 — Half-fill then simultaneous R+W:
  wr_data: 05→0A→0F→14→19→1E→23→28 (8 writes, count=8)
  Then wr_en=1, rd_en=1 simultaneously:
    count: STAYS SAME (one in, one out = net zero)
    wr_ptr advances by 1
    rd_ptr advances by 1

Test 8 — Almost-full corner case (15/16 filled):
  wr_data: 01→02→...→0F (15 writes)
  Then simultaneous R+W at count=15:
    count stays at 15 (not full, not empty)
    wr_ptr and rd_ptr both advance ✅
```

---

## Summary — All Behaviors Verified

| Test | Behavior | Waveform Evidence | Result |
|------|----------|------------------|--------|
| 1 | Reset | count=0, empty=1 after rst_n | ✅ PASS |
| 2 | Write + Read order | rd_data matches wr_data sequence | ✅ PASS |
| 3 | Full flag | full=1 at count=16 (0x10) | ✅ PASS |
| 4 | Overflow | 1-cycle pulse when wr_en+full | ✅ PASS |
| 5 | Drain empty | empty=1 at count=0 | ✅ PASS |
| 6 | Underflow | 1-cycle pulse when rd_en+empty | ✅ PASS |
| 7 | Simultaneous R+W | count stable during both asserted | ✅ PASS |
| 8 | Corner case | almost-full R+W handled correctly | ✅ PASS |

## Additional Waveform Observations

1. **X-state propagation:** All signals correctly show X before reset — 
   no accidental initialization in RTL (good practice) ✅

2. **Pointer wrap-around:** Both wr_ptr and rd_ptr visible wrapping 
   F→0 in the waveform — circular buffer working correctly ✅

3. **Combinational rd_data:** rd_data changes without waiting for a 
   clock edge — zero-latency read confirmed ✅

4. **count[4:0]:** 5th bit (bit[4]) goes high only at count=16 — 
   confirms 5-bit width was necessary ✅

5. **Flag timing:** full and empty flags are purely combinational — 
   they assert and de-assert within the same clock cycle as count changes ✅
