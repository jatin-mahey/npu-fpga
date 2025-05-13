`timescale 1ns / 1ps

// NEURON MODULE
// -------------------------------------
module Neuron
#(parameter
    LAYER_NUM    = 0,
    NEURON_NUM   = 0,
    WEIGHT_NUM   = 0,
    DATA_WIDTH   = 16,
    SIGMOID_SIZE = 5,
    WEIGHT_WIDTH = 1,
    ACT_TYPE     = "relu",
    BIAS_FILE    = "",
    WEIGHT_FILE  = ""
)(
    input                       clk_i,
    input                       rst_i,
    input                       myInputValid_i,
    input                       weightValid_i,
    input                       baisValid_i,
    input      [31:0]           weightValue_i,
    input      [31:0]           baisValue_i,
    input      [31:0]           configLayerNumber_i,
    input      [31:0]           configNeuronNumber_i,
    input      [DATA_WIDTH-1:0] myInput_i,
    output     [DATA_WIDTH-1:0] out_o,
    output reg                  outValid_or
);
    parameter ADDRESS_WIDTH = $clog2(WEIGHT_NUM); // log base 2 operation

    reg                      addr_r = 0;
    wire                     ren_w;
    reg                      wen_r;
    reg                      weightValid_r;
    reg                      multValid_r;
    reg                      sigValid_r;
    reg                      muxValidD_r;
    reg                      muxValidF_r;
    wire                     muxValid_w;
    reg  [ADDRESS_WIDTH-1:0] wAddr_r;
    reg  [ADDRESS_WIDTH-1:0] rAddr_r;
    reg  [DATA_WIDTH-1:0]    myInputD_r;
    reg  [DATA_WIDTH-1:0]    wIn_r;
    wire [DATA_WIDTH-1:0]    wOut_w;
    reg  [2*DATA_WIDTH-1:0]  mul_r;
    reg  [2*DATA_WIDTH-1:0]  sum_r;
    reg  [2*DATA_WIDTH-1:0]  bias_r;
    wire [2*DATA_WIDTH:0]    comboAdd_w;
    wire [2*DATA_WIDTH:0]    biasAdd_w;
    reg  [31:0]              biasReg_r [0:0];

    assign ren_w      = myInputValid_i;
    assign muxValid_w = multValid_r;
    assign comboAdd_w = mul_r + sum_r;
    assign biasAdd_w  = bias_r + sum_r;

    // load weights into the memory
    always @(posedge clk_i) begin
        if(rst_i) begin
            wAddr_r <= {ADDRESS_WIDTH{1'b1}}; // init to all 1s'
            wen_r   <= 0;
        end
        else if(weightValid_i &
            (configLayerNumber_i==LAYER_NUM) & (configNeuronNumber_i==NEURON_NUM)) begin
            wIn_r   <= weightValue_i;
            wAddr_r <= wAddr_r + 1;
            wen_r   <= 1;
        end
        else
            wen_r <= 0;
    end

    // multiplying the input with weights
    always @(posedge clk_i) begin
        mul_r <= $signed(myInputD_r) * $signed(wOut_w);
    end

    // mux for whether to add bias or weight to previous sum
    always @(posedge clk_i) begin
        if(rst_i|outValid_or)
            sum_r <= 0;
        // add bias to previous sum
        else if((rAddr_r==WEIGHT_NUM) & muxValidF_r) begin
            // overflow case
            if(!bias_r[2*DATA_WIDTH-1] & !sum_r[2*DATA_WIDTH-1] & biasAdd[2*DATA_WIDTH-1]) begin
                // biggest number possible
                sum_r[2*DATA_WIDTH-1]   <= 1'b0; // make msb 0 to make +ve
                sum_r[2*DATA_WIDTH-2:0] <= {2*DATA_WIDTH-1{1'b1}}; // rest is 1
            end
            // underflow case
            else if(bias_r[2*DATA_WIDTH-1] & sum_r[2*DATA_WIDTH-1] & !biasAdd[2*DATA_WIDTH-1]) begin
                // smallest number possible
                sum_r[2*DATA_WIDTH-1]   <= 1'b1; // make msb 1 to make -ve
                sum_r[2*DATA_WIDTH-2:0] <= {2*DATA_WIDTH-1{1'b0}}; // rest is 0
            end
            // regular case
            else
                sum_r <= biasAdd_w;
        end
        // add weighted input to previous sum
        else if(muxValid_w) begin
            // overflow case
            if(!mul_r[2*DATA_WIDTH-1] & !sum_r[2*DATA_WIDTH-1] & comboAdd[2*DATA_WIDTH-1]) begin
                // biggest number possible
                sum_r[2*DATA_WIDTH-1]   <= 1'b0; // make msb 0 to make +ve
                sum_r[2*DATA_WIDTH-2:0] <= {2*DATA_WIDTH-1{1'b1}}; // rest is 1
            end
            // underflow case
            else if(mul_r[2*DATA_WIDTH-1] & sum_r[2*DATA_WIDTH-1] & !comboAdd[2*DATA_WIDTH-1]) begin
                // smallest number possible
                sum_r[2*DATA_WIDTH-1]   <= 1'b1; // make msb 1 to make -ve
                sum_r[2*DATA_WIDTH-2:0] <= {2*DATA_WIDTH-1{1'b0}}; // rest is 0
            end
            // regular case
            else
                sum_r <= comboAdd_w;
        end
    end

    always @(posedge clk_i) begin
        if(rst_i|outValid_or)
            rAddr_r <= 0;
        else if(myInputValid_i)
            rAddr_r <= rAddr_r +1;
    end

endmodule


// SIGMOID MODULE
// -------------------------------------
module Sigmoid
#(parameter
    INPUT_WIDTH = 10,
    DATA_WIDTH  = 16,
    WEIGHT_FILE = ""
)(
    input                    clk_i,
    input  [INPUT_WIDTH-1:0] x_i,
    output [DATA_WIDTH-1:0]  out_o
);
    reg [DATA_WIDTH-1:0]  mem_r [2**INPUT_WIDTH-1:0];
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


// RELU MODULE
// -------------------------------------
module Relu
#(parameter
    DATA_WIDTH   = 16,
    WEIGHT_WIDTH = 10
)(
    input                          clk_i,
    input      [2*DATA_WIDTH-1:0]  x_i,
    output reg [DATA_WIDTH-1:0]    out_o
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


// WEIGHTS MODULE
// -------------------------------------
module Weights
#(parameter
    WEIGHT_NUM    = 3,
    NEURON_NUM    = 5,
    LAYER_BUM     = 1,
    ADDRESS_WIDTH = 10,
    DATA_WIDTH    = 16,
    WEIGHT_FILE   = ""
)(
    input                          clk_i,
    input                          wen_i,
    input                          ren_i,
    input      [ADDRESS_WIDTH-1:0] wAdd_i,
    input      [ADDRESS_WIDTH-1:0] rAdd_i,
    input      [DATA_WIDTH-1:0]    wIn_i,
    output reg [DATA_WIDTH-1:0]    wOut_ro
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
