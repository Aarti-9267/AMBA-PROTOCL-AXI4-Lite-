`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/04/2024 05:52:55 PM
// Design Name: 
// Module Name: axi4_lite_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: AXI4-Lite Top Module (Verilog version)
// 
// Dependencies: axi4_lite_master.v , axi4_lite_slave.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module axi4_lite_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDRESS    = 32
)(
    input                       ACLK,
    input                       ARESETN,
    input                       read_s,
    input                       write_s,
    input      [ADDRESS-1:0]    address,
    input      [DATA_WIDTH-1:0] W_data
);

    // Internal AXI channel wires between Master and Slave
    wire                       M_ARREADY;
    wire                       S_RVALID;
    wire                       M_ARVALID;
    wire                       M_RREADY;
    wire                       S_AWREADY;
    wire                       S_BVALID;
    wire                       M_AWVALID;
    wire                       M_BREADY;
    wire                       M_WVALID;
    wire                       S_WREADY;

    wire [ADDRESS-1:0]         M_ARADDR;
    wire [ADDRESS-1:0]         M_AWADDR;
    wire [DATA_WIDTH-1:0]      M_WDATA;
    wire [DATA_WIDTH-1:0]      S_RDATA;
    wire [3:0]                 M_WSTRB;
    wire [1:0]                 S_RRESP;
    wire [1:0]                 S_BRESP;

    // Master Instance
    axi4_lite_master u_axi4_lite_master0 (
        .ACLK(ACLK),
        .ARESETN(ARESETN),
        .START_READ(read_s),
        .address(address),
        .W_data(W_data),

        // Read Address Channel
        .M_ARREADY(M_ARREADY),
        .M_ARADDR(M_ARADDR),
        .M_ARVALID(M_ARVALID),

        // Read Data Channel
        .M_RDATA(S_RDATA),
        .M_RRESP(S_RRESP),
        .M_RVALID(S_RVALID),
        .M_RREADY(M_RREADY),

        // Write Address Channel
        .START_WRITE(write_s),
        .M_AWREADY(S_AWREADY),
        .M_AWADDR(M_AWADDR),
        .M_AWVALID(M_AWVALID),

        // Write Data Channel
        .M_WVALID(M_WVALID),
        .M_WREADY(S_WREADY),
        .M_WDATA(M_WDATA),
        .M_WSTRB(M_WSTRB),

        // Write Response Channel
        .M_BRESP(S_BRESP),
        .M_BVALID(S_BVALID),
        .M_BREADY(M_BREADY)
    );

    // Slave Instance
    axi4_lite_slave u_axi4_lite_slave0 (
        .ACLK(ACLK),
        .ARESETN(ARESETN),

        // Read Address Channel
        .S_ARADDR(M_ARADDR),
        .S_ARVALID(M_ARVALID),
        .S_ARREADY(M_ARREADY),

        // Read Data Channel
        .S_RDATA(S_RDATA),
        .S_RRESP(S_RRESP),
        .S_RVALID(S_RVALID),
        .S_RREADY(M_RREADY),

        // Write Address Channel
        .S_AWADDR(M_AWADDR),
        .S_AWVALID(M_AWVALID),
        .S_AWREADY(S_AWREADY),

        // Write Data Channel
        .S_WDATA(M_WDATA),
        .S_WSTRB(M_WSTRB),
        .S_WVALID(M_WVALID),
        .S_WREADY(S_WREADY),

        // Write Response Channel
        .S_BRESP(S_BRESP),
        .S_BVALID(S_BVALID),
        .S_BREADY(M_BREADY)
    );

endmodule
