module out_spike (
    input wire CLK,
    input wire RST_sync,
    input wire [15:0]LIF_neuron_event_out,

    input wire  CTRL_PIPLINE_START,
    input  wire [        7:0] CTRL_NEURMEM_ADDR,

    output reg  [        1023:0] Neuron_Out_Spike
);

// reg  [        N-1:0] Neuron_Out_Spike;
// wire  [15:0] event_out_group;
// assign event_out_group = {LIF_neuron_event_out15,LIF_neuron_event_out14,LIF_neuron_event_out13,LIF_neuron_event_out12,LIF_neuron_event_out11,LIF_neuron_event_out10,LIF_neuron_event_out9,LIF_neuron_event_out8,LIF_neuron_event_out7,LIF_neuron_event_out6,LIF_neuron_event_out5,LIF_neuron_event_out4,LIF_neuron_event_out3,LIF_neuron_event_out2,LIF_neuron_event_out1,LIF_neuron_event_out};

// assign Neuron_Out_Spike_10 = Neuron_Out_Spike[9:0];

parameter Mult_Times = 64;//130
parameter Eight = 16;
genvar i;
generate
    for(i=0;i<Mult_Times;i=i+1)begin
        always@(posedge CLK)begin
            if(RST_sync)begin
                Neuron_Out_Spike[i*Eight+15:i*Eight] <= 16'b0;
            end
            else if((i==CTRL_NEURMEM_ADDR) && (CTRL_PIPLINE_START == 1'b1))begin//||event_out_group && 
                Neuron_Out_Spike[i*Eight+15:i*Eight] <= LIF_neuron_event_out;
            end
            else begin
                Neuron_Out_Spike[i*Eight+15:i*Eight] <= 16'b0;
            end
        end
    end

endgenerate


// assign Neuron_Out_Spike[CTRL_NEURMEM_ADDR<<3 + 3'b111: CTRL_NEURMEM_ADDR<<3] = |event_out_group?event_out_group:8'b0;

endmodule