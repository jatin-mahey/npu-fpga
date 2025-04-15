`timescale 1ns / 1ps
// ===================================================================================
// WEIGHTS MODULE
// -----------------------------------------------------------------------------------
module Weights
#(parameter
    WEIGHT_NUM = 3,
    NEURON_NUM = 5,
    LAYER_BUM = 1,
    ADDRESS_WIDTH = 10,
    DATA_WIDTH = 16,
    WEIGHT_FILE=""
)(
    input clk_i,
    input wen_i,
    input ren_i,
    input [ADDRESS_WIDTH-1:0] wAdd_i,
    input [ADDRESS_WIDTH-1:0] rAdd_i,
    input [DATA_WIDTH-1:0] wIn_i,
    output reg [DATA_WIDTH-1:0] wOut_ro
);

reg [DATA_WIDTH-1:0] mem_r [WEIGHT_NUM-1:0];


// write from file into block ram
`ifdef pretrained
    initial begin
        $readmemb(WEIGHT_FILE, mem_r)
    end
`else
    always @(posedge clk_i) begin
        if(wen_i) begin
            mem_r[wAdd_i] <= wIn_i
        end
    end
`endif


// read from block ram
always @(posedge clk_i) begin
    if(ren_i) begin
        wOut_ro <= mem_r[rAdd_i]
    end
end


endmodule
// ===================================================================================
// END WEIGHTS
// -----------------------------------------------------------------------------------
