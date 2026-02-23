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
	wire [7:0] sbox_out, masked_sbox_out, mask_out;

	reg [7:0] data_i, mask_i, key, data_o;
    reg [17:0] prd_i;

	wire trigger        = uio_in[7];
	wire trigger_masked = uio_in[6];

	always @ (posedge clk) begin
		if (!rst_n) begin
			data_i  <= 0;
			key     <= 0;
			data_o  <= 0;
		end else begin
			case (uio_in[3:0])
				4'b0001: data_i  <= ui_in;
				4'b0010: key     <= ui_in;

                4'b0011: mask_i       <= ui_in;
                4'b0100: prd_i[ 7: 0] <= ui_in;
                4'b0101: prd_i[15: 8] <= ui_in;
                4'b0111: prd_i[17:16] <= ui_in[1:0];

                4'b1000: data_o  <= sbox_out;
                4'b1001: data_o  <= masked_sbox_out;
                4'b1010: data_o  <= mask_out;

                default: ;
			endcase
		end
	end

	sbox_fwd sbox(
		.data_i({8{trigger}} & (data_i ^ key)),
		.data_o(sbox_out)
	);
	sbox_masked_fwd sbox_masked(
		.data_i({8{trigger_masked}} & (data_i ^ key)),
		.mask_i({8{trigger_masked}} & mask_i),
		.prd_i({18{trigger_masked}} & prd_i),
		.data_o(masked_sbox_out),
        .mask_o(mask_out)
	);

  assign uo_out  = data_o;
  assign uio_out = 0;
  assign uio_oe  = 0;

  wire _unused = &{uio_in[5:4], ena, 1'b0};
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

module sbox_masked_fwd(
    input [7:0]  data_i,
    input [7:0]  mask_i,
    input [17:0] prd_i,

    output [7:0] mask_o,
    output [7:0] data_o
);
    wire [7:0] in_data_basis_x, out_data_basis_x,
               in_mask_basis_x, out_mask_basis_x;
    wire [7:0] data_o_x2s;

    assign data_o = data_o_x2s ^ 8'h63;
    assign mask_o = prd_i[7:0];

    aes_mvn data_a2x( .vec(data_i), .mat(`A2X), .data_o(in_data_basis_x)  );
    aes_mvn mask_a2x( .vec(mask_i), .mat(`A2X), .data_o(in_mask_basis_x)  );
    aes_mvn mask_s2x( .vec(mask_o), .mat(`S2X), .data_o(out_mask_basis_x) );

    aes_masked_inverse_gf2p8_noreuse inv(
        .a(in_data_basis_x),
        .m(in_mask_basis_x),
        .n(out_mask_basis_x),
        .prd(prd_i[17:8]),
        .a_inv(out_data_basis_x)
    );

    aes_mvn x2s( .vec(out_data_basis_x), .mat(`X2S), .data_o(data_o_x2s) );
endmodule

module aes_mvn(vec, mat, data_o);
    input  [7:0] vec;
    input [63:0] mat;
    output reg [7:0] data_o;

    reg  [7:0] c0, c1, c2, c3, c4, c5, c6, c7;

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

module aes_masked_inverse_gf2p8_noreuse(
    input  [7:0] a,
    input  [7:0] m,
    input  [7:0] n,
    input  [9:0] prd,
    output [7:0] a_inv
);
    wire [3:0] a1, a0, m1, m0;
    assign a1 = a[7:4];
    assign a0 = a[3:0];
    assign m1 = m[7:4];
    assign m0 = m[3:0];

    wire [1:0] r;
    wire [3:0] q, t, s1, s0;
    assign r = prd[1:0];
    assign q = prd[5:2];
    assign t = prd[9:6];
    assign s1 = n[7:4];
    assign s0 = n[3:0];

    wire [3:0] ss_a1_a0, ss_m1_m0;
    aes_square_scale_gf2p4_gf2p2 blk0_sqsc0(.gamma(a1 ^ a0), .delta(ss_a1_a0));
    aes_square_scale_gf2p4_gf2p2 blk0_sqsc1(.gamma(m1 ^ m0), .delta(ss_m1_m0));

    wire [3:0] mul_a1_a0, mul_a1_m0, mul_a0_m1, mul_m0_m1;
    aes_mul_gf2p4 blk1_m0(.gamma(a1), .delta(a0), .theta(mul_a1_a0));
    aes_mul_gf2p4 blk1_m1(.gamma(a1), .delta(m0), .theta(mul_a1_m0));
    aes_mul_gf2p4 blk1_m2(.gamma(a0), .delta(m1), .theta(mul_a0_m1));
    aes_mul_gf2p4 blk1_m3(.gamma(m0), .delta(m1), .theta(mul_m0_m1));

    wire [3:0] b [5:0];
    assign b[0] = q ^ ss_a1_a0; // q does not depend on a1, a0.
    assign b[1] = b[0] ^ ss_m1_m0; // b[0] does not depend on m1, m0.
    assign b[2] = b[1] ^ mul_a1_a0;
    assign b[3] = b[2] ^ mul_a1_m0;
    assign b[4] = b[3] ^ mul_a0_m1;
    assign b[5] = b[4] ^ mul_m0_m1;

    wire [3:0] b_inv;
    aes_masked_inverse_gf2p4_noreuse blk2_inv(.b(b[5]), .q(q), .r(r), .t(t), .b_inv(b_inv));

    wire [3:0] mul_a0_b_inv, mul_a0_t, mul_m0_b_inv, mul_m0_t, mul_a1_b_inv, mul_a1_t, mul_m1_b_inv, mul_m1_t;
    aes_mul_gf2p4 blk3_m0(.gamma(a0), .delta(b_inv), .theta(mul_a0_b_inv));
    aes_mul_gf2p4 blk3_m1(.gamma(a0), .delta(t    ), .theta(mul_a0_t    ));
    aes_mul_gf2p4 blk3_m2(.gamma(m0), .delta(b_inv), .theta(mul_m0_b_inv));
    aes_mul_gf2p4 blk3_m3(.gamma(m0), .delta(t    ), .theta(mul_m0_t    ));
    aes_mul_gf2p4 blk3_m4(.gamma(a1), .delta(b_inv), .theta(mul_a1_b_inv));
    aes_mul_gf2p4 blk3_m5(.gamma(a1), .delta(t    ), .theta(mul_a1_t    ));
    aes_mul_gf2p4 blk3_m6(.gamma(m1), .delta(b_inv), .theta(mul_m1_b_inv));
    aes_mul_gf2p4 blk3_m7(.gamma(m1), .delta(t    ), .theta(mul_m1_t    ));

    wire [3:0] a1_inv [3:0], a0_inv [3:0];
    assign a1_inv[0] = s1 ^ mul_a0_b_inv;
    assign a1_inv[1] = a1_inv[0] ^ mul_a0_t;
    assign a1_inv[2] = a1_inv[1] ^ mul_m0_b_inv;
    assign a1_inv[3] = a1_inv[2] ^ mul_m0_t;
    assign a0_inv[0] = s0 ^ mul_a1_b_inv;
    assign a0_inv[1] = a0_inv[0] ^ mul_a1_t;
    assign a0_inv[2] = a0_inv[1] ^ mul_m1_b_inv;
    assign a0_inv[3] = a0_inv[2] ^ mul_m1_t;

    assign a_inv = { a1_inv[3], a0_inv[3] };
endmodule

module aes_masked_inverse_gf2p4_noreuse(
    input  [3:0] b,
    input  [3:0] q,
    input  [1:0] r,
    input  [3:0] t,
    output [3:0] b_inv
);
    wire [1:0] b1, b0, q1, q0, t1, t0;

    assign b1 = b[3:2];
    assign b0 = b[1:0];
    assign q1 = q[3:2];
    assign q0 = q[1:0];
    assign t1 = t[3:2];
    assign t0 = t[1:0];

    wire [1:0] scale_omega2_b, scale_omega2_q;
    wire [1:0] blk0_t0, blk0_t1;
    wire [1:0] mul_b1_b0, mul_b1_q0, mul_b0_q1, mul_q1_q0;

    // scale_omega2_b = aes_scale_omega2_gf2p2(aes_square_gf2p2(b1 ^ b0));
    aes_square_gf2p2         blk0_sq0(.data_i(b1 ^ b0), .data_o(blk0_t0));
    aes_scale_omega2_gf2p2 blk0_scom0(.data_i(blk0_t0), .data_o(scale_omega2_b));
    // scale_omega2_q = aes_scale_omega2_gf2p2(aes_square_gf2p2(q1 ^ q0));
    aes_square_gf2p2         blk0_sq1(.data_i(q1 ^ q0), .data_o(blk0_t1));
    aes_scale_omega2_gf2p2 blk0_scom1(.data_i(blk0_t1), .data_o(scale_omega2_q));
    aes_mul_gf2p2 blk0_m0(.a_i(b1), .b_i(b0), .z_o(mul_b1_b0));
    aes_mul_gf2p2 blk0_m1(.a_i(b1), .b_i(q0), .z_o(mul_b1_q0));
    aes_mul_gf2p2 blk0_m2(.a_i(b0), .b_i(q1), .z_o(mul_b0_q1));
    aes_mul_gf2p2 blk0_m3(.a_i(q1), .b_i(q0), .z_o(mul_q1_q0));

    wire [1:0] c [5:0];
    assign c[0] = r ^ scale_omega2_b;
    assign c[1] = c[0] ^ scale_omega2_q;
    assign c[2] = c[1] ^ mul_b1_b0;
    assign c[3] = c[2] ^ mul_b1_q0;
    assign c[4] = c[3] ^ mul_b0_q1;
    assign c[5] = c[4] ^ mul_q1_q0;

    wire [1:0] c_inv, r_sq;
    aes_square_gf2p2 blk2_sq0(.data_i(c[5]), .data_o(c_inv));
    aes_square_gf2p2 blk2_sq1(.data_i(r),    .data_o(r_sq ));

    wire [1:0] mul_b0_r_sq, mul_q0_c_inv, mul_q0_r_sq, mul_b1_r_sq, mul_q1_c_inv, mul_q1_r_sq;
    aes_mul_gf2p2 blk3_m0(.a_i(b0), .b_i(r_sq ), .z_o(mul_b0_r_sq ));
    aes_mul_gf2p2 blk3_m1(.a_i(q0), .b_i(c_inv), .z_o(mul_q0_c_inv));
    aes_mul_gf2p2 blk3_m2(.a_i(q0), .b_i(r_sq ), .z_o(mul_q0_r_sq ));
    aes_mul_gf2p2 blk3_m3(.a_i(b1), .b_i(r_sq ), .z_o(mul_b1_r_sq ));
    aes_mul_gf2p2 blk3_m4(.a_i(q1), .b_i(c_inv), .z_o(mul_q1_c_inv));
    aes_mul_gf2p2 blk3_m5(.a_i(q1), .b_i(r_sq ), .z_o(mul_q1_r_sq ));

    wire [1:0] b1_inv [3:0], b0_inv [3:0];
    wire [1:0] blk4_t0, blk4_t1;
    aes_mul_gf2p2 blk4_m0(.a_i(b0), .b_i(c_inv), .z_o(blk4_t0));
    assign b1_inv[0] = t1 ^ blk4_t0; // t1 does not depend on b0, c_inv.
    assign b1_inv[1] = b1_inv[0] ^ mul_b0_r_sq;
    assign b1_inv[2] = b1_inv[1] ^ mul_q0_c_inv;
    assign b1_inv[3] = b1_inv[2] ^ mul_q0_r_sq;
    aes_mul_gf2p2 blk4_m1(.a_i(b1), .b_i(c_inv), .z_o(blk4_t1));
    assign b0_inv[0] = t0 ^ blk4_t1; // t0 does not depend on b1, c_inv.
    assign b0_inv[1] = b0_inv[0] ^ mul_b1_r_sq;
    assign b0_inv[2] = b0_inv[1] ^ mul_q1_c_inv;
    assign b0_inv[3] = b0_inv[2] ^ mul_q1_r_sq;

    assign b_inv = { b1_inv[3], b0_inv[3] };
endmodule
