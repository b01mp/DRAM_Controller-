# SDRAM Controller with FIFO Implementation and UVM Testbench

## Project Overview

This project implements a **SDRAM Controller** with **FIFO buffering** and **UVM-based testbench** for the MT48LC8M16A2 SDRAM device. The controller bridges an AMBA APB interface with SDRAM hardware, providing efficient memory access with proper timing compliance.

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
│   ├── sdr_ctrl_top.sv           # Top-level module with FIFO
│   ├── sdr_ctrl_main.sv          # Main controller FSM
│   ├── sdr_ctrl_sig.sv           # SDRAM signal generation
│   ├── sdr_ctrl_data.sv          # Data path controller
│   └── sdr_parameters.sv         # Timing and configuration parameters
├── Model/                         # SDRAM Behavioral Model
│   └── sdr.v                     # SDRAM behavioral model
├── Testbench/                     # UVM Testbench Files
│   ├── testbench.sv              # Top-level testbench
│   ├── apb_if.sv                 # APB interface definition
│   ├── apb_transaction.sv        # Transaction class
│   ├── apb_generator.sv          # Stimulus generator
│   ├── apb_driver.sv             # APB protocol driver
│   ├── apb_monitor.sv            # Transaction monitor
│   ├── apb_scoreboard.sv         # Verification component
│   ├── apb_env.sv                # Test environment
│   ├── apb_test_rw_init.sv       # Test scenarios
│   └── fifo_tb.sv                # FIFO testbench
└── README.md                      # Project documentation
```

## Usage Instructions

### 1. Setup Environment
```bash
cd new_bhavesh
vivado new_bhavesh.xpr
```

### 2. Run Simulation
```bash
# In Vivado Tcl console
launch_simulation
run all
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