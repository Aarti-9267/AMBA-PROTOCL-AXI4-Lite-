# AMBA-PROTOCL-AXI4-Lite-

1. Built a master–slave system with clean FSMs and VALID/READY handshakes.
2. Designed 5 unidirectional channels (AW, W, B, AR, R) with robust AXI4‑Lite-compliant logic.
3. Implemented a 32-word slave register file and parameterized master, verified end-to-end with testbench & waveforms.
4. Scenario-driven verification covering writes & reads at 0x04, 0x08, 0x0C, 0x10 with data patterns 0xDEADBEEF, 0xCAFEBABE, 0x12345678, 0x87654321.
