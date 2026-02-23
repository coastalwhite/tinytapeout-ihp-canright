/*
 * Copyright (c) 2026 Gijs Burghoorn
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_coastalwhite_canright_sbox (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
	wire [7:0] sbox_out;

	reg [7:0] data_i, key, data_o;
	reg trigger;

	always @ (posedge clk) begin
		if (!rst_n) begin
			data_i  <= 0;
			key     <= 0;
			trigger <= 0;
			data_o  <= 0;
		end else begin
			case (uio_in[1:0])
				2'b00: ;
				2'b01: data_i  <= ui_in;
				2'b10: key     <= ui_in;
				2'b11: begin
					trigger <= 1;
					data_o  <= sbox_out;
				end
			endcase
		end
	end

	sbox_fwd sbox(
		.data_i({8{trigger}} & (data_i ^ key)),
		.data_o(sbox_out)
	);

  assign uo_out  = data_o;
  assign uio_out = 0;
  assign uio_oe  = 0;
endmodule

`define A2X 64'hFF_A9_81_09_48_F2_F3_98
`define X2A 64'h60_DE_29_68_8C_6E_78_64
`define X2S 64'h24_03_04_DC_0B_9E_2D_58
`define S2X 64'h53_51_04_12_EB_05_79_8C

module sbox_fwd(data_i, data_o);
    input [7:0]  data_i;
    output [7:0] data_o;

    wire [7:0] data_basis_x;
    wire [7:0] data_inverse;
    wire [7:0] data_basis_s;

    assign data_o = data_basis_s ^ 8'h63;

    aes_mvn           a2x( .vec(data_i),          .mat(`A2X), .data_o(data_basis_x) );
    aes_inverse_gf2p8 inv( .data_i(data_basis_x),             .data_o(data_inverse) );
    aes_mvn           x2s( .vec(data_inverse),    .mat(`X2S), .data_o(data_basis_s) );
endmodule

module aes_mvn(vec, mat, data_o);
    input  [7:0] vec;
    input [63:0] mat;
    output [7:0] data_o;

    wire  [7:0] c0, c1, c2, c3, c4, c5, c6, c7;

    integer j;
    always @* begin
		for (j = 0; j < 8; j = j + 1) begin
			c0[j] = mat[j*8+0] & vec[7 - j];
			c1[j] = mat[j*8+1] & vec[7 - j];
			c2[j] = mat[j*8+2] & vec[7 - j];
			c3[j] = mat[j*8+3] & vec[7 - j];
			c4[j] = mat[j*8+4] & vec[7 - j];
			c5[j] = mat[j*8+5] & vec[7 - j];
			c6[j] = mat[j*8+6] & vec[7 - j];
			c7[j] = mat[j*8+7] & vec[7 - j];
		end
		data_o = { ^c7, ^c6, ^c5, ^c4, ^c3, ^c2, ^c1, ^c0 };
    end
endmodule

module aes_inverse_gf2p8(data_i, data_o);
    input [7:0]  data_i;
    output [7:0] data_o;

    wire [3:0] a, b, c, d;

    assign a = data_i[7:4] ^ data_i[3:0];

    aes_mul_gf2p4                  m1( .gamma(data_i[7:4]), .delta(data_i[3:0]), .theta(b)           );
    aes_square_scale_gf2p4_gf2p2 sqsc( .gamma(a),           .delta(c)                                );
    aes_inverse_gf2p4             inv( .data_i(c ^ b),      .data_o(d)                               );
    aes_mul_gf2p4                  m2( .gamma(d),           .delta(data_i[3:0]), .theta(data_o[7:4]) );
    aes_mul_gf2p4                  m3( .gamma(d),           .delta(data_i[7:4]), .theta(data_o[3:0]) );
endmodule

module aes_mul_gf2p2(a_i, b_i, z_o);
    input [1:0]  a_i;
    input [1:0]  b_i;
    output [1:0] z_o;

    wire a, b, c;

    assign a = a_i[1] & b_i[1];
    assign b = ^a_i & ^b_i;
    assign c = a_i[0] & b_i[0];

    assign z_o = { a ^ b, c ^ b };
endmodule

module aes_square_scale_gf2p4_gf2p2(gamma, delta);
    input  [3:0] gamma;
    output [3:0] delta;

    wire [1:0] a, b, t1, t2;

    assign a = gamma[3:2] ^ gamma[1:0];
    assign delta = { t1, t2 };

    aes_square_gf2p2      sq1( .data_i(gamma[1:0]), .data_o(b)  );
    aes_square_gf2p2      sq2( .data_i(a),          .data_o(t1) );
    aes_scale_omega_gf2p2 sc ( .data_i(b),          .data_o(t2) );
endmodule

module aes_scale_omega_gf2p2(data_i, data_o);
    input  [1:0] data_i;
    output [1:0] data_o;

    assign data_o = { ^data_i, data_i[1] };
endmodule

module aes_mul_gf2p4(gamma, delta, theta);
    input [3:0]  gamma;
    input [3:0]  delta;
    output [3:0] theta;

    wire [1:0] a, b, c, t;

    aes_mul_gf2p2           m1( .a_i(gamma[3:2]), .b_i(delta[3:2]), .z_o(a) );
    aes_mul_gf2p2           m2( .a_i(gamma[3:2] ^ gamma[1:0]), .b_i(delta[3:2] ^ delta[1:0]), .z_o(b) );
    aes_mul_gf2p2           m3( .a_i(gamma[1:0]), .b_i(delta[1:0]), .z_o(c) );
    aes_scale_omega2_gf2p2 sc1( .data_i(b), .data_o(t)                      );
    
    assign theta = { a ^ t, c ^ t };
endmodule


module aes_inverse_gf2p4(data_i, data_o);
    input  [3:0] data_i;
    output [3:0] data_o;

    wire [1:0] a, b, c, c1, d;

    assign a = data_i[3:2] ^ data_i[1:0];

    aes_mul_gf2p2            m1( .a_i(data_i[3:2]), .b_i(data_i[1:0]), .z_o(b)     );
    aes_square_gf2p2       sqc1( .data_i(a),                           .data_o(c1) );
    aes_scale_omega2_gf2p2   sc( .data_i(c1),                          .data_o(c)  );
    aes_square_gf2p2        inv( .data_i(c ^ b),                       .data_o(d)  );

    aes_mul_gf2p2          m2( .a_i(d), .b_i(data_i[1:0]), .z_o(data_o[3:2]) );
    aes_mul_gf2p2          m3( .a_i(d), .b_i(data_i[3:2]), .z_o(data_o[1:0]) );
endmodule

module aes_scale_omega2_gf2p2(data_i, data_o);
    input  [1:0] data_i;
    output [1:0] data_o;

    assign data_o = { data_i[0], ^data_i };
endmodule

module aes_square_gf2p2(data_i, data_o);
    input  [1:0] data_i;
    output [1:0] data_o;

    assign data_o = { data_i[0], data_i[1] };
endmodule
