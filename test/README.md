# Test Instructions

1. Go to this folder.
2. Run RTL simulation:

```sh
make -B
```

3. The cocotb test checks three key behaviors:
   - PLL output does not toggle while disabled.
   - PLL output toggles after explicit enable.
   - PLL output stops again after explicit disable.
