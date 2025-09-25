`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/04/2024 05:52:55 PM
// Design Name: 
// Module Name: axi4_lite_slave
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: AXI4-Lite Slave (basic)
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module axi4_lite_slave #(
    parameter ADDRESS = 32,
    parameter DATA_WIDTH = 32
    )
    (
        // Global Signals
        input                           ACLK,
        input                           ARESETN,

        //// Read Address Channel INPUTS
        input      [ADDRESS-1:0]        S_ARADDR,
        input                           S_ARVALID,
        // Read Data Channel INPUTS
        input                           S_RREADY,
        // Write Address Channel INPUTS
        input      [ADDRESS-1:0]        S_AWADDR,
        input                           S_AWVALID,
        // Write Data  Channel INPUTS
        input      [DATA_WIDTH-1:0]     S_WDATA,
        input      [3:0]                S_WSTRB,
        input                           S_WVALID,
        // Write Response Channel INPUTS
        input                           S_BREADY,	

        // Read Address Channel OUTPUTS
        output reg                      S_ARREADY,
        // Read Data Channel OUTPUTS
        output reg [DATA_WIDTH-1:0]     S_RDATA,
        output reg [1:0]                S_RRESP,
        output reg                      S_RVALID,
        // Write Address Channel OUTPUTS
        output reg                      S_AWREADY,
        output reg                      S_WREADY,
        // Write Response Channel OUTPUTS
        output reg [1:0]                S_BRESP,
        output reg                      S_BVALID
    );

    localparam no_of_registers = 32;

    reg [DATA_WIDTH-1 : 0] register_file [0:no_of_registers-1];
    reg [ADDRESS-1 : 0]    addr;
    
    wire                   write_addr;
    wire                   write_data;

    // State machine
    localparam IDLE            = 3'b000,
               WRITE_CHANNEL   = 3'b001,
               WRESP__CHANNEL  = 3'b010,
               RADDR_CHANNEL   = 3'b011,
               RDATA__CHANNEL  = 3'b100;

    reg [2:0] state, next_state;

    // Handshake logic
    assign write_addr = S_AWVALID & S_AWREADY;
    assign write_data = S_WVALID & S_WREADY;

    integer i;

    // Sequential: register file & address latch
    always @(posedge ACLK) begin
        if (~ARESETN) begin
            for (i = 0; i < no_of_registers; i = i + 1) begin
                register_file[i] <= {DATA_WIDTH{1'b0}};
            end
        end
        else begin
            if (state == WRITE_CHANNEL) begin
                register_file[S_AWADDR] <= S_WDATA;
            end
            else if (state == RADDR_CHANNEL) begin
                addr <= S_ARADDR;
            end
        end
    end

    // Sequential: state update
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    // Combinational: next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (S_AWVALID)
                    next_state = WRITE_CHANNEL;
                else if (S_ARVALID)
                    next_state = RADDR_CHANNEL;
                else
                    next_state = IDLE;
            end

            RADDR_CHANNEL:
                if (S_ARVALID && S_ARREADY)
                    next_state = RDATA__CHANNEL;
                else
                    next_state = RADDR_CHANNEL;

            RDATA__CHANNEL:
                if (S_RVALID && S_RREADY)
                    next_state = IDLE;
                else
                    next_state = RDATA__CHANNEL;

            WRITE_CHANNEL:
                if (write_addr && write_data)
                    next_state = WRESP__CHANNEL;
                else
                    next_state = WRITE_CHANNEL;

            WRESP__CHANNEL:
                if (S_BVALID && S_BREADY)
                    next_state = IDLE;
                else
                    next_state = WRESP__CHANNEL;

            default: next_state = IDLE;
        endcase
    end

    // Combinational: output logic
    always @(*) begin
        // Defaults
        S_ARREADY = 0;
        S_RVALID  = 0;
        S_RDATA   = 0;
        S_RRESP   = 0;
        S_AWREADY = 0;
        S_WREADY  = 0;
        S_BVALID  = 0;
        S_BRESP   = 0;

        case (state)
            RADDR_CHANNEL: begin
                S_ARREADY = 1;
            end

            RDATA__CHANNEL: begin
                S_RVALID = 1;
                S_RDATA  = register_file[addr];
                S_RRESP  = 2'b00;  // OKAY
            end

            WRITE_CHANNEL: begin
                S_AWREADY = 1;
                S_WREADY  = 1;
            end

            WRESP__CHANNEL: begin
                S_BVALID = 1;
                S_BRESP  = 2'b00;  // OKAY
            end
        endcase
    end

endmodule

