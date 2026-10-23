# I²C Master–Slave Controller Using Verilog HDL

A Verilog-based implementation of an I²C master–slave communication system, developed and simulated using AMD Xilinx Vivado. This project demonstrates serial communication, finite-state-machine (FSM) design, open-drain signaling, and simulation-based functional verification.

## Overview

The design consists of one I²C master and one I²C slave communicating over a shared Serial Data (SDA) line and Serial Clock (SCL) line.

The master initiates communication, generates the serial clock, transmits the slave address and write data, and receives data during read transactions. The slave recognizes its configured address and supports single-byte read and write operations.

A self-checking Verilog testbench is used to verify data transfers and address NACK detection.

## Features

- I²C master and slave implemented in Verilog HDL
- 7-bit slave addressing
- 100 kHz SCL target frequency from a 100 MHz system clock
- START and STOP condition generation
- Address ACK/NACK detection by the master
- Single-byte write and read transactions
- Open-drain SDA signaling using tri-state assignments
- FSM-based master and slave control logic
- Self-checking behavioral testbench
- Simulation using AMD Xilinx Vivado (XSim)

## Design Architecture

The system consists of three main modules.

### 1. I²C Master

The master controls the communication process. Its responsibilities include:

- Generating START and STOP conditions
- Generating SCL using a configurable clock divider
- Transmitting the 7-bit slave address and R/W bit
- Checking the slave's address acknowledgment
- Transmitting a data byte during write operations
- Receiving a data byte during read operations
- Indicating transaction activity through the `busy` signal

### 2. I²C Slave

The slave monitors the shared SDA and SCL lines and responds to transactions addressed to it.

Its responsibilities include:

- Detecting START and STOP conditions
- Receiving and checking the slave address
- Acknowledging a matching address
- Receiving and storing a data byte during a write operation
- Transmitting the stored data during a read operation

The slave address is configurable through the `SLAVE_ADDRESS` parameter. The default address is `1010111`.

### 3. Testbench

The testbench generates the system clock and reset, initiates transactions, and compares the received data against the expected values.

It also tests the master's response to an incorrect slave address and reports the final test results.

## I²C Communication Protocol

I²C is a synchronous, two-wire serial communication protocol.

- **SDA (Serial Data):** Carries addresses, data, and acknowledgment bits.
- **SCL (Serial Clock):** Provides synchronization for communication.
- **START condition:** SDA transitions from high to low while SCL is high.
- **STOP condition:** SDA transitions from low to high while SCL is high.
- **ACK:** The receiver pulls SDA low during the acknowledgment clock.
- **NACK:** SDA remains high during the acknowledgment clock.

The master transmits the 7-bit slave address followed by the R/W bit, which selects the read or write operation.

For a single-byte transfer, eight data bits are transmitted or received, followed by the corresponding acknowledgment phase.

## Clock Configuration

The design uses a 100 MHz system clock with a period of 10 ns.

The master generates SCL using the `HALF_PERIOD` parameter.

The target SCL frequency is calculated as:

\[
f_{\mathrm{SCL}}=\frac{f_{\mathrm{clk}}}{2N}
\]

where:

- \(f_{\mathrm{clk}}\) is the system clock frequency.
- \(N\) is the `HALF_PERIOD` value.

For `HALF_PERIOD = 500`:

\[
f_{\mathrm{SCL}}=\frac{100\,\mathrm{MHz}}{2\times500}
=100\,\mathrm{kHz}
\]

This corresponds to the standard-mode I²C clock frequency.

## SDA Open-Drain Signaling

The SDA line is implemented using tri-state behavior. The master and slave can pull the line low or release it to high impedance.

```verilog
assign sda = sda_drive_low ? 1'b0 : 1'bz;
```

A pull-up is modeled in the testbench using:

```verilog
tri1 sda;
```

This allows the bus to resolve to logic high when neither device pulls SDA low.

## Verification and Test Results

The self-checking testbench performs five tests.

| Test | Operation | Expected result |
|---|---|---|
| 1 | Write and read back `0xAA` | Data matches |
| 2 | Write and read back `0x3C` | Data matches |
| 3 | Write and read back `0x55` | Data matches |
| 4 | Write and read back `0x00` | Data matches |
| 5 | Send an incorrect slave address | Master detects NACK |

### Simulation Summary

The reported Vivado behavioral simulation completed successfully.

| Metric | Result |
|---|---:|
| Tests passed | 5 |
| Tests failed | 0 |
| Overall result | PASS |

The four data-transfer tests verify write/read behavior for the selected byte patterns. The fifth test verifies address NACK detection when the transmitted address does not match the configured slave address.

These results demonstrate the functionality covered by the testbench; they do not establish complete compliance with every I²C protocol requirement.

## Tools and Technologies

- **Hardware Description Language:** Verilog HDL
- **Design and Simulation:** AMD Xilinx Vivado
- **Simulator:** Vivado XSim
- **Verification:** Self-checking behavioral testbench

## Current Scope and Limitations

The implementation focuses on a single-master, single-slave system with 7-bit addressing and single-byte read/write transactions.

The following features are outside the current scope:

- Multi-master arbitration
- Clock stretching
- 10-bit addressing
- Repeated START conditions
- Multi-byte burst transfers
- Multiple physical slaves
- Fast-mode and higher-speed operation

## Future Improvements

Potential extensions include:

- Expanded verification of reset behavior and error conditions
- Explicit checks for START, STOP, ACK, and NACK timing
- Multi-byte read/write support
- Repeated START support
- Configurable clock modes with additional timing verification

## Conclusion

This project demonstrates the design and behavioral verification of an I²C master–slave controller using Verilog HDL. It covers FSM-based control, serial data transfer, clock generation, open-drain signaling, and address acknowledgment handling.

The implementation successfully passed the five test cases included in the current self-checking testbench, providing a foundation for further development of digital communication controllers.
