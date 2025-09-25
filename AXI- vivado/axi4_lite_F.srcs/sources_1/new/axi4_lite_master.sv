`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.09.2025 21:29:21
// Design Name: 
// Module Name: axi4_lite_master
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//////////////////////////////////////////////////////////////////////////////////


module axi4_lite_master #(
parameter ADDRESS = 32,         //Parameters make the module reusable with different bus sizes.
parameter DATA_WIDTH = 32)
(
input ACLK,                    //global signal
input ARESETN,                 // Active-low reset. When 0, resets the FSM and outputs.

input  START_READ,            //Triggers a single read or write transaction from the master.
input  START_WRITE,

input [ADDRESS-1:0] address,
input [DATA_WIDTH-1:0] W_data,

// channel inputs//

// Read address channel input
input M_ARREADY,

//READ DATA CHANNEL INPUT
input [DATA_WIDTH-1:0] M_RDATA,
input [1:0] M_RRESP,
input M_RVALID,

//WRITE ADDRESS AND DATA CHANNEL INPUT
input M_AWREADY,
input M_WREADY,

//WRITE RESPONSE CHANNEL INPUT
input [1:0] M_BRESP,
input M_BVALID,

 // OUTPUS
 
// Read Address Channel OUTPUTS
    output reg [ADDRESS-1:0]    M_ARADDR,
    output reg                  M_ARVALID,
// Read Data Channel OUTPUTS
    output reg                  M_RREADY,
// Write Address Channel OUTPUTS
    output reg [ADDRESS-1:0]    M_AWADDR,
    output reg                  M_AWVALID,
// Write Data  Channel OUTPUTS
    output reg [DATA_WIDTH-1:0] M_WDATA,
    output reg [3:0]            M_WSTRB,
    output reg                  M_WVALID,
// Write Response Channel OUTPUTS
    output reg                  M_BREADY
 
    );
   
// Internal flags
    reg read_start; // Internal registers to sample START_READ/START_WRITE to avoid metastability.
    reg write_start;
    
always@(posedge ACLK) begin
    if(!ARESETN)
       state<=IDLE;       // reset-----> IDLE
    else
       state<=next_state;  // otherwise ---->advance to next state
end


wire write_addr;
wire write_data;

    assign write_addr = M_AWVALID & M_AWREADY; // high when address handshake completes
    assign write_data = M_WVALID  & M_WREADY; // high when data handshake completes
 
 
    
 // FSM state encoding
localparam [2:0] IDLE          = 3'd0, // WAITING FOR START SIGNAL
                 WRITE_CHANNEL = 3'd1, // SENDING ADDRESS/DATA --> write address and data can be send paralley within same cycle
                 WRESP_CHANNEL = 3'd2, // WAITING FOR WRITE RESPONSE
                 RADDR_CHANNEL = 3'd3, // SENDING READ ADDRESS
                 RDATA_CHANNEL = 3'd4; // WAITING FOR READ DATA
                     
reg [2:0]state,next_state; // current FSM state, and computes next FSM state

always @(posedge ACLK) begin

      if (!ARESETN) begin
            read_start  <= 1'b0; // set to 0 on reset
            write_start <= 1'b0;
            
      end else begin
            read_start  <= START_READ; //register that start signals on clock edge
            write_start <= START_WRITE; //avoid glitches from asynch start signals
      end
end

//Determines next FSM state based on current state and handshake signals

    always @(*) begin
        case (state)
            IDLE: begin
                if (write_start)
                    next_state = WRITE_CHANNEL; 
                    /*
                    There's no WADDR_CHANNEL state because AXI4-Lite allows issuing write address + data in parallel, so they're combined into WRITE_CHANNEL.
                    In IDLE, write_start goes directly to WRITE_CHANNEL, since that state already handles both the write address and data handshakes.
                    Reads are split into two states (RADDR and RDATA) because the slave returns read data later, in a separate channel.
                    */
                else if (read_start)
                    next_state = RADDR_CHANNEL;
                else
                    next_state = IDLE;
            end
            RADDR_CHANNEL: begin
                if (M_ARVALID && M_ARREADY)
                    next_state = RDATA_CHANNEL;
                else
                    next_state = RADDR_CHANNEL;
            end
            RDATA_CHANNEL: begin
                if (M_RVALID && M_RREADY)
                    next_state = IDLE;
                else
                    next_state = RDATA_CHANNEL;
            end
            WRITE_CHANNEL: begin
                if (write_addr && write_data)
                    next_state = WRESP_CHANNEL;
                else
                    next_state = WRITE_CHANNEL;
            end
            WRESP_CHANNEL: begin
                if (M_BVALID && M_BREADY)
                    next_state = IDLE;
                else
                    next_state = WRESP_CHANNEL;
            end
            default: next_state = IDLE;
        endcase
    end

always @(*) begin
        // Initialize outputs to safe values (default zero)
        M_ARADDR  = {ADDRESS{1'b0}};
        M_ARVALID = 1'b0;
        M_RREADY  = 1'b0;
        M_AWADDR  = {ADDRESS{1'b0}};
        M_AWVALID = 1'b0;
        M_WDATA   = {DATA_WIDTH{1'b0}};
        M_WSTRB   = 4'b0000;
        M_WVALID  = 1'b0;
        M_BREADY  = 1'b0;
 
         case (state)
            RADDR_CHANNEL: begin
                M_ARADDR  = address; //This tells the slave which location to read from.
                M_ARVALID = 1'b1;   // This tells the slave: "I have a valid read address for you, please take it when you're ready."
                M_RREADY  = 1'b1; // The master asserts readiness for read data before the slave provides it.
            end
            RDATA_CHANNEL: begin
                M_RREADY  = 1'b1;  //(Notice we don't need to re-drive ARADDR or ARVALID here - address phase is already done in the previous state.)
            end
            WRITE_CHANNEL: begin
                M_AWADDR  = address; //→ Tells the slave where to write the data.
                M_AWVALID = 1'b1;  //Handshake occurs when slave asserts M_AWREADY=1
                M_WDATA   = W_data; //Place the write data onto the write data bus
                M_WSTRB   = 4'b1111; // Byte strobe signals - here 1111 means all 4 bytes of the 32-bit word are valid.
                M_WVALID  = 1'b1; //Assert data valid for the write channel.
                M_BREADY  = 1'b1; //The master already declares it is ready to accept a write response (BRESP).
            end
            WRESP_CHANNEL: begin
                M_BREADY  = 1'b1; //The master continues to signal readiness to accept the write response
            end
        endcase
    end
    
        
endmodule

