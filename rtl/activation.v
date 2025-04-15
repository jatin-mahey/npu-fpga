`timescale 1ns / 1ps
// ===================================================================================
// SIGMOID MODULE
// -----------------------------------------------------------------------------------
module Sigmoid
#(parameter
    INPUT_WIDTH = 10,
    DATA_WIDTH  = 16,
    WEIGHT_FILE = ""
) (
    input  clk_i,
    input  [INPUT_WIDTH-1:0] x_i,
    output [DATA_WIDTH-1:0] out_o
);

reg [DATA_WIDTH-1:0] mem_r [2**INPUT_WIDTH-1:0];
reg [INPUT_WIDTH-1:0] y_r;


assign out_o = mem_r[y_r];


initial begin
    $readmemb(WEIGHT_FILE, mem_r);
end


always @(posedge clk_i) begin
    if($signed(x_i) >= 0)
        y_r <= x_i + (2**(INPUT_WIDTH-1));
    else
        y_r <= x_i - (2**(INPUT_WIDTH-1));
end


endmodule
// -----------------------------------------------------------------------------------
// END SIGMOID
// ===================================================================================
// RELU MODULE
// -----------------------------------------------------------------------------------
module Relu
#(parameter
    DATA_WIDTH  = 16,
    WEIGHT_WIDTH = 10
) (
    input clk_i,
    input [2*DATA_WIDTH-1:0] x_i,
    output reg [DATA_WIDTH-1:0] out_o
);


always @(posedge clk_i) begin
    if($signed(x_i) >= 0) begin
        // detect overflow
        if(|x_i[2*DATA_WIDTH-1-:WEIGHT_WIDTH+1])
            out_o <= {1'b0, {(DATA_WIDTH-1){1'b1}}};
        else
            out_o <= x_i[2*DATA_WIDTH-1-WEIGHT_WIDTH-:DATA_WIDTH];
    end
    else
        out_o <= 0;
end


endmodule
// -----------------------------------------------------------------------------------
// END RELU
// ===================================================================================

