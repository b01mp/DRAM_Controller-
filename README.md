# SDRAM Controller with FIFO Implementation and UVM Testbench

## Project Overview

This project implements a **SDRAM Controller** with **FIFO buffering** and **UVM-based testbench** for the MT48LC8M16A2 SDRAM device. The controller bridges an AMBA APB interface with SDRAM hardware, providing efficient memory access with proper timing compliance.

## Controller Architecture

The SDR SDRAM Controller is a modular digital logic system that bridges the host processor and the physical SDRAM device. Its architecture partitions complex memory control into manageable submodules, ensuring maintainability, scalability, and reusability.

### High-Level Block Diagram

```
+-------------------+      +-------------------+      +-------------------+
|   AMBA 3 APB      | ---> | SDRAM Controller  | ---> |  MT48LC8M16A2     |
|   Interface       |      |                   |      |  SDRAM Memory     |
+-------------------+      +-------------------+      +-------------------+
```

**Key signals:**
- APB: pclk, preset, pselect, penable, pwrite, paddr, pwdata, prdata, pready
- SDRAM: sdr_A, sdr_BA, sdr_CKE, sdr_CSn, sdr_RASn, sdr_CASn, sdr_WEn, sdr_DQM, sdr_D

### Module Breakdown

The controller consists of four main modules, all instantiated in `sdr_ctrl_top.sv`:
1. **Main Control Module (`sdr_ctrl_main.sv`)**: Manages two primary operational phases—Initialization and Command Execution—using dual FSMs.
2. **Signal Generation Module (`sdr_ctrl_sig.sv`)**: Generates SDRAM command and address signals based on the controller’s current state.
3. **Data Transfer Module (`sdr_ctrl_data.sv`)**: Handles data latching and transfer between the APB interface and SDRAM.
4. **FIFO Module (`sdr_ctrl_fifo.sv`)**: Buffers commands, decoupling the fast SoC from the slower SDRAM to prevent data loss and ensure high-throughput communication.

### FSM-Based Microarchitecture

#### Initialization FSM (iState)
- **i_NOP**: Waits for power stabilization (100 μs delay)
- **i_PRE**: Issues PRECHARGE ALL
- **i_AR1/i_AR2**: Issues two AUTO REFRESH commands
- **i_MRS**: Programs SDRAM mode register
- **i_ready**: Indicates initialization complete
- **Delay States**: Enforce JEDEC timing (tRP, tRFC, tMRD)

#### Command FSM (cState)
- **c_idle**: Waits for APB transaction or refresh request
- **c_ACTIVE**: Issues ACTIVE command
- **c_READA/c_WRITEA**: Issues READ/WRITE with autoprecharge
- **c_cl/c_rdata/c_wdata**: Handles CAS latency, data read/write
- **c_AR**: Issues AUTO REFRESH
- **Delay States**: Enforce tRCD, tDAL, tRFC

### Signal and Data Flow
- **Command Encoding**: sdr_CSn, sdr_RASn, sdr_CASn, sdr_WEn form a 4-bit command vector
- **Address Mapping**: APB address mapped to SDRAM bank/row/column
- **Mode Register Programming**: Configures CAS latency, burst type/length
- **Bidirectional Data Path**: Tri-state buffers control sdr_DQ for read/write
- **FIFO Buffering**: Commands are pushed/popped to/from FIFO for decoupling

### Timing Management
- All SDRAM timing parameters (tRP, tRFC, tRCD, tMRD, CAS Latency, tDAL) are enforced using a parameterized clock counter and macros in `sdr_parameters.sv`.

---

## FPGA Implementation

The SDR SDRAM controller was implemented and validated on a Xilinx Nexys 4 Artix-7 FPGA board. The design flow included simulation, synthesis, and hardware testing, addressing several practical challenges:

### Hardware Challenges
- **I/O Constraints**: The controller’s full APB interface (16-bit address/data, multiple control signals) exceeded the number of available switches and buttons on the Nexys 4 board.
- **Memory Interface Mismatch**: The SoC’s low-speed APB bus could not reliably interface with the board’s high-speed DDR SDRAM. To overcome this, a behavioral, synthesizable model of the target SDR SDRAM (MT48LC8M16A2) was implemented for functional testing.

### Mode-Based Testing Architecture
A top-level test module (`top_test.sv`) multiplexed the board’s limited I/O resources across different operational modes, enabling comprehensive testing:
- **Address Input Mode**: Switches used to input memory addresses; center button latches the value.
- **Data Input Mode**: Switches used for data input; center button latches the value.
- **Read Output Mode**: LEDs display data read from SDRAM.
- **Status Mode**: LEDs and 7-segment displays show controller status and APB transaction states.
- **Automatic Test Mode**: Runs automated test sequences for functional validation.

### Behavioral SDRAM Model Integration
A fully synthesizable behavioral SDRAM model, based on the MT48LC8M16A2 datasheet, was integrated into the FPGA design. This model emulates timing, command sequences, and data handling, supporting all standard SDRAM operations (init, refresh, read, write, precharge). It enables realistic, hardware-validated controller testing under actual device timing constraints.

### Resource Utilization
- **With top_test module**: Higher resource usage due to additional test logic and I/O multiplexing.
- **Controller only**: Minimal logic and area, demonstrating good efficiency for SoC integration.

| Resource | Utilization (Controller+Test) | Utilization (Controller Only) |
|----------|-------------------------------|-------------------------------|
| LUT      | 7527 / 63400 (11.87%)         | 192 / 63400 (0.30%)           |
| LUTRAM   | 5632 / 19000 (29.64%)         | -                             |
| FF       | 708 / 126800 (0.56%)          | 404 / 126800 (0.32%)          |
| IO       | 91 / 210 (43.33%)             | 90 / 210 (42.86%)             |
| BUFG     | 1 / 32 (3.13%)                | 1 / 32 (3.13%)                |

This approach enabled robust, user-friendly hardware validation and demonstrated the controller’s suitability for embedded SoC memory management.

---

## Key Features

- **FIFO-based Command Buffering**: Decouples SoC command rate from SDRAM timing constraints
- **APB Protocol Compliance**: Full AMBA APB 3.0 protocol implementation
- **SDRAM Initialization**: JEDEC-compliant initialization sequence
- **UVM Testbench**: Comprehensive verification environment with scoreboard
- **Timing Compliance**: Meets all SDRAM timing requirements (tRCD, tRP, tRFC, etc.)

## FIFO Implementation

### Why FIFO in SDRAM Controller?

1. **SDRAM Command Cycle Consumption**
   - ACTIVATE: Opens a row for access (tRCD: Row to Column Delay)
   - READ/WRITE: Data transfer starts after CAS latency (CL) delay
   - PRECHARGE: Closes the row (tRP: Row Precharge Time)
   - REFRESH: Periodically required (tRFC: Refresh Cycle Time)

2. **Minimum Delay Between Commands**
   - 80ns minimum delay required between consecutive commands
   - Maximum command frequency: 12.5MHz
   - SoC can operate at higher frequencies (50MHz, 100MHz+)

3. **FIFO Solution**
   - Buffers incoming commands from SoC
   - Issues commands to SDRAM at proper timing
   - Prevents data loss and maximizes throughput

### FIFO Configuration

- **Depth**: 8 entries (configurable via `parameter depth = 8`)
- **Width**: 33 bits per entry
- **Command Format**: `{pwrite, paddr[15:0], pwdata[15:0]}`

| Bit Range | Field   | Description                    |
|-----------|---------|--------------------------------|
| [32]      | pwrite  | 1 = write, 0 = read           |
| [31:16]   | paddr   | SDRAM address                  |
| [15:0]    | pwdata  | Write data (ignored for reads) |

## SDRAM Specifications

### MT48LC8M16A2 Device
- **Capacity**: 128-Megabit (32KB usable)
- **Organization**: 2 Meg × 16 bits × 4 banks
- **Data Width**: 16 bits
- **Address Lines**: 13-bit multiplexed (row/column)
- **Bank Address**: 2 bits (4 banks)

### Timing Parameters
| Parameter | Value | Description                    |
|-----------|-------|--------------------------------|
| tCK       | 20ns  | Clock cycle time (50MHz)       |
| tRCD      | 15ns  | Row to Column Delay            |
| tRP       | 15ns  | Row Precharge time             |
| tRFC      | 66ns  | Refresh cycle time             |
| tWR       | 27ns  | Write recovery time            |
| CAS Latency| 2     | Clock cycles to valid data     |

## UVM Testbench Architecture

### Components
- **apb_transaction**: Encapsulates APB transaction data
- **apb_generator**: Generates test stimuli
- **apb_driver**: Drives APB signals to DUT
- **apb_monitor**: Observes APB interface signals
- **apb_scoreboard**: Verifies transaction correctness
- **apb_env**: Orchestrates all UVM components

### Test Scenarios
1. **Initialization Test**: Verifies SDRAM initialization sequence
2. **Read/Write Test**: Tests basic read/write operations
3. **FIFO Stress Test**: Tests FIFO full/empty conditions

## Project Structure

```
DRAM_Controller-/
├── Design/                        # RTL Design Files
│   ├── sdr_ctrl_data.sv           # Data path controller
│   ├── sdr_ctrl_fifo.sv           # FIFO buffering module
│   ├── sdr_ctrl_main.sv           # Main controller FSM
│   ├── sdr_ctrl_sig.sv            # SDRAM signal generation
│   ├── sdr_ctrl_top.sv            # Top-level controller module
│   └── sdr_parameters.sv          # Timing and configuration parameters
├── FPGA_Implementation/           # FPGA-specific implementation
│   └── top_test.sv                # Top-level FPGA test module
├── Model/                         # SDRAM Behavioral Model
│   ├── sdr.v                      # SDRAM behavioral model (MT48LC8M16A2)
│   └── sdr_syth.v                 # Synthesizable SDRAM model
├── Testbench/                     # Testbench and Verification
│   ├── apb_driver.sv              # APB protocol driver
│   ├── apb_env.sv                 # Test environment
│   ├── apb_generator.sv           # Stimulus generator
│   ├── apb_if.sv                  # APB interface definition
│   ├── apb_monitor.sv             # Transaction monitor
│   ├── apb_scoreboard.sv          # Scoreboard for checking
│   ├── apb_test_rw_init.sv        # Read/Write/Init test scenarios
│   ├── apb_transaction.sv         # Transaction class
│   ├── fifo_tb.sv                 # FIFO testbench
│   └── testbench.sv               # Top-level testbench
├── images/                        # Output images and waveforms
│   └── output.jpg                 # Example output waveform
├── output_log/                    # Output logs
│   ├── output-log                 # Log file
│   └── Untitled Document 1        # Additional log file
├── output_log.zip                 # Zipped log files
└── README.md                      # Project documentation
```


### 3. Configuration Options
```systemverilog
// FIFO depth (in sdr_ctrl_top.sv)
parameter depth = 8;  // Adjust based on requirements

// SDRAM timing (in sdr_parameters.sv)
parameter tCK = 20;   // Clock period in ns
parameter tRCD = 15;  // Row to Column Delay
parameter tRP = 15;   // Row Precharge time
```

## Example Operation Sequence: FIFO Command Buffering in Action

This section demonstrates how the controller and FIFO buffer handle a sequence of write and read operations, showcasing command storage and execution order.

### Example Sequence

1. **Write to Address 0x0010 with Data 0xCAFE**
2. **Read from Address 0x0010**
3. **Write to Address 0x0030 with Data 0x1234**
4. **Write to Address 0x0040 with Data 0xABCD**
5. **Read from Address 0x0030**

### Command Timeline and FIFO Behavior

| Step | Command         | Address | Data   | FIFO Action         |
|------|----------------|---------|--------|---------------------|
| 1    | WRITE          | 0x0010  | 0xCAFE | Stored in FIFO      |
| 2    | READ           | 0x0010  |   -    | Stored in FIFO      |
| 3    | WRITE          | 0x0030  | 0x1234 | Stored in FIFO      |
| 4    | WRITE          | 0x0040  | 0xABCD | Stored in FIFO      |
| 5    | READ           | 0x0030  |   -    | Stored in FIFO      |

- **FIFO Storage**: Each command is pushed into the FIFO as soon as it is issued by the APB interface, regardless of SDRAM timing constraints.
- **Command Execution**: The controller fetches commands from the FIFO and issues them to the SDRAM only when timing requirements (tRCD, tRP, etc.) are met, ensuring correct operation.
- **Order Preservation**: FIFO ensures that commands are executed in the order they were received, maintaining data integrity.

### Example Waveform (Conceptual)

```
APB Commands Issued:   |WRITE|READ |WRITE|WRITE|READ |
FIFO State (entries):  |  1  |  2  |  3  |  4  |  5  |
SDRAM Execution:       |---->|---->|---->|---->|---->|
```

- The FIFO may temporarily hold multiple commands if the SDRAM is busy or timing windows are not met.
- As soon as the SDRAM is ready, commands are dequeued and executed in order.

This example illustrates how the FIFO decouples the APB command rate from SDRAM timing, allowing for efficient and reliable memory operations even under bursty or back-to-back command scenarios.

## Performance Characteristics

### FIFO Performance
- **Maximum Command Rate**: 12.5 MHz (limited by 80ns SDRAM timing)
- **FIFO Throughput**: 8 commands buffered simultaneously
- **Latency**: 2-4 clock cycles per command

### SDRAM Performance
- **Access Time**: ~60ns (ACTIVATE + tRCD + CAS latency)
- **Bandwidth**: 16-bit data bus at 50MHz
- **Refresh**: Auto-refresh every 1ms

## Design Considerations

### 1. FIFO Depth Selection
- **Too Small**: May cause command loss under high load
- **Too Large**: Increases latency and resource usage
- **Optimal**: 8 entries for this application

### 2. Timing Compliance
- All SDRAM commands respect minimum timing
- FIFO prevents timing violations
- Controller handles refresh automatically

### 3. Resource Optimization
- Minimal logic for FIFO implementation
- Efficient state machine design
- Optimized memory addressing

## Verification Features

### 1. Timing Verification
- SDRAM timing compliance checking
- FIFO flow control validation
- APB protocol timing verification

### 2. Functional Verification
- Read/write data integrity
- FIFO command ordering
- SDRAM initialization sequence

### 3. Coverage Metrics
- APB transaction coverage
- FIFO state coverage
- SDRAM command coverage

## References

### Standards
- **JEDEC SDRAM Standard**: JESD79
- **AMBA APB Protocol**: ARM IHI 0024B
- **SDRAM Timing**: MT48LC8M16A2 datasheet

### Key Concepts
- **FIFO Buffering**: Command rate decoupling
- **SDRAM Timing**: Row/column addressing and timing constraints
- **APB Protocol**: AMBA peripheral bus interface
- **UVM Methodology**: Universal Verification Methodology

---

*This project demonstrates advanced digital design concepts including FIFO implementation, SDRAM controller design, UVM testbench development, and APB protocol implementation.* 

![Example Output Waveform](images/output)

*Figure: Output waveform showing FIFO command buffering and execution for the described operation sequence.* 