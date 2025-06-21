// TRANSACTION OBJECT //
class apb_transaction;

    // Transaction fields
    rand bit        pwrite;   // 1 = write, 0 = read
    rand bit [15:0] paddr;    // Address
    rand bit [15:0] pwdata;   // Write data
         bit [15:0] prdata;   // Read data (captured during monitor/driver)
         bit        pslverr;  // Optional error flag

    // Constructor
    function new(string name = "apb_transaction");
    endfunction

    // Print method for debug
    function void display();
        $display("[APB TRANS] %s Addr=0x%0h %s Data=0x%0h",
                 (pwrite ? "WRITE" : "READ"),
                 paddr,
                 (pwrite ? "WDATA" : "->RDATA"),
                 (pwrite ? pwdata : prdata));
    endfunction

endclass