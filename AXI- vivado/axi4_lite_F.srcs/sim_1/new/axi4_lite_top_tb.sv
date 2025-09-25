`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Enhanced Testbench for AXI4-Lite Top Module
// Transaction sequence: idle > write > write > read > write > read > write
// Enhanced monitoring with read data capture and verification
//////////////////////////////////////////////////////////////////////////////////

module tb_axi4_lite_top;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDRESS = 32;
    parameter CLOCK_PERIOD = 10; // 10ns clock period (100MHz)

    // Testbench signals
    reg                       ACLK;
    reg                       ARESETN;
    reg                       read_s;
    reg                       write_s;
    reg  [ADDRESS-1:0]        address;
    reg  [DATA_WIDTH-1:0]     W_data;

    // Read data capture signals
    reg  [DATA_WIDTH-1:0]     captured_read_data;
    reg                       read_data_valid;
    reg  [DATA_WIDTH-1:0]     expected_read_data;

    // Instantiate the DUT (Device Under Test)
    axi4_lite_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDRESS(ADDRESS)
    ) uut (
        .ACLK(ACLK),
        .ARESETN(ARESETN),
        .read_s(read_s),
        .write_s(write_s),
        .address(address),
        .W_data(W_data)
    );

    // Clock generation
    initial begin
        ACLK = 0;
        forever #(CLOCK_PERIOD/2) ACLK = ~ACLK;
    end

    // Test stimulus and monitoring
    initial begin
        // Initialize VCD dump for waveform analysis
        $dumpfile("axi4_lite_test.vcd");
        $dumpvars(0, tb_axi4_lite_top);

        // Add specific signals to VCD for better visibility
        $dumpvars(1, captured_read_data);
        $dumpvars(1, read_data_valid);
        $dumpvars(1, expected_read_data);

        // Initialize signals
        ARESETN = 0;
        read_s = 0;
        write_s = 0;
        address = 0;
        W_data = 0;
        captured_read_data = 0;
        read_data_valid = 0;
        expected_read_data = 0;

        // Reset phase
        $display("\n=== AXI4-Lite Enhanced Testbench Started ===");
        $display("Time: %0t - Applying Reset", $time);
        #(CLOCK_PERIOD * 2);
        ARESETN = 1;
        #(CLOCK_PERIOD);
        $display("Time: %0t - Reset Released", $time);

        // Transaction Sequence: idle > write > write > read > write > read > write

        // 1. IDLE phase
        $display("\n--- IDLE Phase ---");
        #(CLOCK_PERIOD * 2);

        // 2. First WRITE transaction
        $display("\n--- First WRITE Transaction ---");
        $display("Time: %0t - Writing 0xDEADBEEF to address 0x00000004", $time);
        write_transaction(32'h00000004, 32'hDEADBEEF);

        // 3. Second WRITE transaction
        $display("\n--- Second WRITE Transaction ---");
        $display("Time: %0t - Writing 0xCAFEBABE to address 0x00000008", $time);
        write_transaction(32'h00000008, 32'hCAFEBABE);

        // 4. First READ transaction - expect 0xDEADBEEF
        $display("\n--- First READ Transaction ---");
        $display("Time: %0t - Reading from address 0x00000004 (expecting 0xDEADBEEF)", $time);
        read_transaction_with_check(32'h00000004, 32'hDEADBEEF);

        // 5. Third WRITE transaction
        $display("\n--- Third WRITE Transaction ---");
        $display("Time: %0t - Writing 0x12345678 to address 0x0000000C", $time);
        write_transaction(32'h0000000C, 32'h12345678);

        // 6. Second READ transaction - expect 0xCAFEBABE
        $display("\n--- Second READ Transaction ---");
        $display("Time: %0t - Reading from address 0x00000008 (expecting 0xCAFEBABE)", $time);
        read_transaction_with_check(32'h00000008, 32'hCAFEBABE);

        // 7. Fourth WRITE transaction
        $display("\n--- Fourth WRITE Transaction ---");
        $display("Time: %0t - Writing 0x87654321 to address 0x00000010", $time);
        write_transaction(32'h00000010, 32'h87654321);

        // Final idle period
        $display("\n--- Final IDLE Phase ---");
        #(CLOCK_PERIOD * 5);

        $display("\n=== All Transactions Completed ===");
        $display("Total simulation time: %0t", $time);
        $finish;
    end

    // Task for write transaction
    task write_transaction;
        input [ADDRESS-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            @(posedge ACLK);
            address = addr;
            W_data = data;
            write_s = 1;
            @(posedge ACLK);
            write_s = 0;

            // Wait for write transaction to complete
            wait_for_write_complete();
            $display("Time: %0t - Write completed: Addr=0x%h, Data=0x%h", $time, addr, data);
        end
    endtask

    // Enhanced task for read transaction with data verification
    task read_transaction_with_check;
        input [ADDRESS-1:0] addr;
        input [DATA_WIDTH-1:0] expected_data;
        begin
            expected_read_data = expected_data;
            @(posedge ACLK);
            address = addr;
            read_s = 1;
            @(posedge ACLK);
            read_s = 0;

            // Wait for read data to be available and capture it
            wait_for_read_data();

            // Verify read data
            if (captured_read_data === expected_data) begin
                $display("Time: %0t - ✓ READ PASS: Addr=0x%h, Expected=0x%h, Actual=0x%h", 
                    $time, addr, expected_data, captured_read_data);
            end else begin
                $display("Time: %0t - ✗ READ FAIL: Addr=0x%h, Expected=0x%h, Actual=0x%h", 
                    $time, addr, expected_data, captured_read_data);
            end
        end
    endtask

    // Original read transaction task (for compatibility)
    task read_transaction;
        input [ADDRESS-1:0] addr;
        begin
            read_transaction_with_check(addr, 32'h00000000); // No specific expectation
        end
    endtask

    // Task to wait for write transaction completion
    task wait_for_write_complete;
        begin
            // Wait for write response handshake
            wait(uut.S_BVALID && uut.M_BREADY);
            @(posedge ACLK);
            // Ensure master returns to IDLE
            wait(uut.u_axi4_lite_master0.state == 3'd0);
        end
    endtask

    // Task to wait for read data and capture it
    task wait_for_read_data;
        begin
            // Wait for read data handshake and capture the data
            wait(uut.S_RVALID && uut.M_RREADY);
            captured_read_data = uut.S_RDATA;
            read_data_valid = 1;
            @(posedge ACLK);
            read_data_valid = 0;
            // Ensure master returns to IDLE
            wait(uut.u_axi4_lite_master0.state == 3'd0);
        end
    endtask

    // Task to wait for any transaction completion (legacy)
    task wait_for_transaction_complete;
        begin
            // Wait until master returns to IDLE state
            wait(uut.u_axi4_lite_master0.state == 3'd0); // IDLE = 3'd0
            @(posedge ACLK);
        end
    endtask

    // Continuous monitoring of all internal signals
    always @(posedge ACLK) begin
        if (ARESETN) begin
            monitor_signals();
        end
    end

    // Task to monitor and display important signals
    task monitor_signals;
        begin
            // Only display when there's activity (not in idle state)
            if (uut.u_axi4_lite_master0.state != 3'd0 || uut.u_axi4_lite_slave0.state != 3'd0) begin
                $display("\n--- Signal Monitor at Time: %0t ---", $time);

                // Master state and control signals
                $display("MASTER STATE: %0d (%s)", 
                    uut.u_axi4_lite_master0.state, 
                    get_master_state_name(uut.u_axi4_lite_master0.state));

                // Slave state
                $display("SLAVE STATE:  %0d (%s)", 
                    uut.u_axi4_lite_slave0.state, 
                    get_slave_state_name(uut.u_axi4_lite_slave0.state));

                // AXI Channel signals
                display_axi_channels();

                // Read data monitoring
                if (uut.u_axi4_lite_master0.state == 3'd4) begin // RDATA_CHANNEL
                    $display("  READ DATA MONITOR: RDATA=0x%h, RVALID=%b, RREADY=%b", 
                        uut.S_RDATA, uut.S_RVALID, uut.M_RREADY);
                end
            end
        end
    endtask

    // Function to get master state name
    function [127:0] get_master_state_name;
        input [2:0] state;
        begin
            case(state)
                3'd0: get_master_state_name = "IDLE";
                3'd1: get_master_state_name = "WRITE_CHANNEL";
                3'd2: get_master_state_name = "WRESP_CHANNEL";
                3'd3: get_master_state_name = "RADDR_CHANNEL";
                3'd4: get_master_state_name = "RDATA_CHANNEL";
                default: get_master_state_name = "UNKNOWN";
            endcase
        end
    endfunction

    // Function to get slave state name
    function [127:0] get_slave_state_name;
        input [2:0] state;
        begin
            case(state)
                3'd0: get_slave_state_name = "IDLE";
                3'd1: get_slave_state_name = "WRITE_CHANNEL";
                3'd2: get_slave_state_name = "WRESP_CHANNEL";
                3'd3: get_slave_state_name = "RADDR_CHANNEL";
                3'd4: get_slave_state_name = "RDATA_CHANNEL";
                default: get_slave_state_name = "UNKNOWN";
            endcase
        end
    endfunction

    // Task to display AXI channel signals
    task display_axi_channels;
        begin
            // Write Address Channel
            if (uut.M_AWVALID || uut.S_AWREADY)
                $display("  WRITE ADDR:   AWVALID=%b, AWREADY=%b, AWADDR=0x%h", 
                    uut.M_AWVALID, uut.S_AWREADY, uut.M_AWADDR);

            // Write Data Channel
            if (uut.M_WVALID || uut.S_WREADY)
                $display("  WRITE DATA:   WVALID=%b, WREADY=%b, WDATA=0x%h, WSTRB=%b", 
                    uut.M_WVALID, uut.S_WREADY, uut.M_WDATA, uut.M_WSTRB);

            // Write Response Channel
            if (uut.S_BVALID || uut.M_BREADY)
                $display("  WRITE RESP:   BVALID=%b, BREADY=%b, BRESP=%b", 
                    uut.S_BVALID, uut.M_BREADY, uut.S_BRESP);

            // Read Address Channel
            if (uut.M_ARVALID || uut.M_ARREADY)
                $display("  READ ADDR:    ARVALID=%b, ARREADY=%b, ARADDR=0x%h", 
                    uut.M_ARVALID, uut.M_ARREADY, uut.M_ARADDR);

            // Enhanced Read Data Channel monitoring
            if (uut.S_RVALID || uut.M_RREADY)
                $display("  READ DATA:    RVALID=%b, RREADY=%b, RDATA=0x%h, RRESP=%b", 
                    uut.S_RVALID, uut.M_RREADY, uut.S_RDATA, uut.S_RRESP);
        end
    endtask

    // Enhanced handshake monitoring with read data capture
    always @(posedge ACLK) begin
        if (ARESETN) begin
            // Write Address Handshake
            if (uut.M_AWVALID && uut.S_AWREADY)
                $display("Time: %0t - WRITE ADDRESS HANDSHAKE: Addr=0x%h", $time, uut.M_AWADDR);

            // Write Data Handshake
            if (uut.M_WVALID && uut.S_WREADY)
                $display("Time: %0t - WRITE DATA HANDSHAKE: Data=0x%h", $time, uut.M_WDATA);

            // Write Response Handshake
            if (uut.S_BVALID && uut.M_BREADY)
                $display("Time: %0t - WRITE RESPONSE HANDSHAKE: BRESP=%b", $time, uut.S_BRESP);

            // Read Address Handshake
            if (uut.M_ARVALID && uut.M_ARREADY)
                $display("Time: %0t - READ ADDRESS HANDSHAKE: Addr=0x%h", $time, uut.M_ARADDR);

            // Enhanced Read Data Handshake with data capture
            if (uut.S_RVALID && uut.M_RREADY) begin
                $display("Time: %0t - READ DATA HANDSHAKE: Addr=0x%h, Data=0x%h, RRESP=%b", 
                    $time, uut.M_ARADDR, uut.S_RDATA, uut.S_RRESP);
            end
        end
    end

    // Dedicated read data monitoring block
    always @(posedge ACLK) begin
        if (ARESETN) begin
            // Monitor read data availability
            if (uut.S_RVALID) begin
                $display("Time: %0t - READ DATA AVAILABLE: RDATA=0x%h, RVALID=%b, RREADY=%b", 
                    $time, uut.S_RDATA, uut.S_RVALID, uut.M_RREADY);
            end

            // Monitor slave memory during read operations
            if (uut.u_axi4_lite_slave0.state == 3'd4) begin // RDATA_CHANNEL
                $display("Time: %0t - SLAVE MEMORY READ: register_file[%0d] = 0x%h", 
                    $time, uut.u_axi4_lite_slave0.addr[6:2], 
                    uut.u_axi4_lite_slave0.register_file[uut.u_axi4_lite_slave0.addr[6:2]]);
            end
        end
    end

    // Error checking
    always @(posedge ACLK) begin
        if (ARESETN) begin
            // Check for protocol violations
            if (uut.S_RRESP !== 2'b00 && uut.S_RVALID)
                $display("ERROR: Read response error at time %0t: RRESP=%b", $time, uut.S_RRESP);

            if (uut.S_BRESP !== 2'b00 && uut.S_BVALID)
                $display("ERROR: Write response error at time %0t: BRESP=%b", $time, uut.S_BRESP);
        end
    end

    // Summary at end
    final begin
        $display("\n=== Enhanced Simulation Summary ===");
        $display("Testbench completed successfully");
        $display("Check waveform file: axi4_lite_test.vcd");
        $display("All AXI4-Lite transactions executed as per sequence:");
        $display("  1. IDLE");
        $display("  2. WRITE (0xDEADBEEF to 0x04)");
        $display("  3. WRITE (0xCAFEBABE to 0x08)"); 
        $display("  4. READ (from 0x04) - with verification");
        $display("  5. WRITE (0x12345678 to 0x0C)");
        $display("  6. READ (from 0x08) - with verification");
        $display("  7. WRITE (0x87654321 to 0x10)");
        $display("\nEnhanced features:");
        $display("  - Read data capture and verification");
        $display("  - Memory content monitoring");
        $display("  - Improved waveform signals for read transactions");
    end

endmodule
