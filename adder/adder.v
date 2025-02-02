`timescale 1ns/100ps
`include "../utils/32bit_mul.v"

module potential_adder (
    input wire clk,
    input wire rst,        
    input wire time_step,      
    input wire [31:0] input_weight, 
    input wire [31:0] decayed_potential,
    input wire [1:0] model,
    input wire [2:0] init_mode,
    input wire load,
    
    output reg [31:0] final_potential, 
    output reg done,
    output reg spike
);

    // Common Signals
    reg [31:0] weight_added;
    reg [31:0] u;

    // Internal Signals for Izhikevich Model
    reg [31:0] bv, bv_u, a_bv_u;
    reg [31:0] a, b, c, d, v_threshold;
    
    reg bv_start, abv_start;
    wire bv_done, abv_done;

    multiplier_32bit multIzhiBV (
        .clk(clk),
        .rst(time_step),
        .start(bv_start),
        .A(b),
        .B(decayed_potential),
        .result(bv),
        .done(bv_done)
    );

    multiplier_32bit multIzhiaBVu (
        .clk(clk),
        .rst(time_step),
        .start(abv_start),
        .A(a),
        .B(bv_u),
        .result(a_bv_u),
        .done(abv_done)
    );

    assign bv_u = bv - u;

    always @(posedge bv_done) begin
        bv_start <= 0;
        #10 abv_start <= 1;
    end

    always @(posedge load) begin
        if (init_mode == `A) begin
            a <= input_weight;
        end else if (init_mode == `B) begin
            b <= input_weight;
        end else if (init_mode == `C) begin
            c <= input_weight;
        end else if (init_mode == `D) begin
            d <= input_weight;
        end else if (init_mode == `VT) begin
            v_threshold <= input_weight;
        end else if (init_mode == `U) begin
            u <= input_weight;
        end
    end

    always @(posedge time_step) begin
        done <= 0;
        if (init_mode == `DEFAULT) begin
            if (model == `LIF) begin
                weight_added <= input_weight + decayed_potential;
            end else if (model == `IZHI) begin
                weight_added <= weight_added - u;
                bv <= 0;
                bv_u <= 0;
                a_bv_u <= 0;
                bv_start <= 1;
                abv_start <= 0;
            end else if (model == `QLIF) begin
                weight_added <= input_weight + decayed_potential;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            final_potential <= 0;
            done <= 0;
            spike <= 0;
            a <= 0;
            b <= 0;
            c <= 0;
            d <= 0;
            v_threshold <= 0;
            u <= 0;
        end else if (init_mode == `DEFAULT) begin
            if(model == `LIF) begin
                spike <= (weight_added > v_threshold);
                final_potential <= (weight_added > v_threshold) ? (weight_added - v_threshold) : weight_added;
                done <= 1;
            end else if (model == `IZHI) begin
                if(abv_done) begin
                    spike <= (weight_added > v_threshold);
                    final_potential <= (weight_added > v_threshold) ? c : weight_added;
                    u <= (weight_added > v_threshold) ? u + d : a_bv_u;
                    done <= 1;
                end
            end else if (model == `QLIF) begin
                spike <= (weight_added > v_threshold);
                final_potential <= (weight_added > v_threshold) ? (weight_added - v_threshold) : weight_added;
                done <= 1;
            end
        end
    end

    always @(posedge) begin
        
    end

    
endmodule
