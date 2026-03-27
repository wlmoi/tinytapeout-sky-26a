# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
import os
from cocotb.triggers import Timer

def read_bit(vector_handle, bit_index):
    try:
        value = int(vector_handle.value)
    except ValueError:
        return None
    return (value >> bit_index) & 1

async def detect_rising_bit_within_time(vector_handle, bit_index, window_ns, sample_step_ns=20):
    prev_bit = read_bit(vector_handle, bit_index)
    steps = max(1, int(window_ns // sample_step_ns))
    for _ in range(steps):
        await Timer(sample_step_ns, unit="ns")
        curr_bit = read_bit(vector_handle, bit_index)
        if prev_bit == 0 and curr_bit == 1:
            return True
        prev_bit = curr_bit
    return False

def is_gate_level_run():
    value = os.getenv("GATES", "").strip().lower()
    return value in ("yes", "1", "true", "on")

@cocotb.test()
async def test_project(dut):
    gates = is_gate_level_run()
    dut._log.info("Start PLL enable/disable behavior test")

    dut._log.info("Apply reset and keep PLL disabled")
    dut.ena.value = 1
