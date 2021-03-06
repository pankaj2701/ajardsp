// This file is part of AjarDSP
//
// Copyright (c) 2010, Markus Lavin
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// 3. Neither the name of the <ORGANIZATION> nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

`include "config.v"

module predbits(clk,
                rst,

                rd_0_idx_i,
                rd_0_bit_o,

                rd_1_idx_i,
                rd_1_bit_o,

                rd_2_idx_i,
                rd_2_bit_o,

                rd_3_idx_i,
                rd_3_bit_o,

                rd_4_idx_i,
                rd_4_bit_o,

                rd_5_idx_i,
                rd_5_bit_o,

                wr_0_idx_i,
                wr_0_wen_i,
                wr_0_bit_i,

                wr_1_idx_i,
                wr_1_wen_i,
                wr_1_bit_i,

                spec_regs_raddr_i,
                spec_regs_waddr_i,
                spec_regs_ren_i,
                spec_regs_wen_i,
                spec_regs_data_i,
                spec_regs_data_o
                );

`include "specregs.v"

   input   clk;
   input   rst;

   input [1:0] rd_0_idx_i;
   output      rd_0_bit_o;

   input [1:0] rd_1_idx_i;
   output      rd_1_bit_o;

   input [1:0] rd_2_idx_i;
   output      rd_2_bit_o;

   input [1:0] rd_3_idx_i;
   output      rd_3_bit_o;

   input [1:0] rd_4_idx_i;
   output      rd_4_bit_o;

   input [1:0] rd_5_idx_i;
   output      rd_5_bit_o;

   input [1:0] wr_0_idx_i;
   input       wr_0_wen_i;
   input       wr_0_bit_i;

   input [1:0] wr_1_idx_i;
   input       wr_1_wen_i;
   input       wr_1_bit_i;

   input [5:0]   spec_regs_raddr_i;
   input [5:0]   spec_regs_waddr_i;
   input         spec_regs_ren_i;
   input         spec_regs_wen_i;
   input  [15:0] spec_regs_data_i;
   output [15:0] spec_regs_data_o;

   reg  [3:0]  pred_reg_r, pred_reg_2_r;
   wire [3:0]  pred_reg_w;

`ifdef AJARDSP_CONFIG_ENABLE_PRED_BYPASS

   integer     i, j;

   reg         pred_2_r[0:3];
   wire [3:0]  pred_2_w;

   reg [1:0]   wr_idx_w[0:1];
   reg         wr_en_w[0:1];
   reg         wr_bit_w[0:1];

   assign pred_reg_w = {pred_2_w[3:1], 1'b1};

   assign pred_2_w = {pred_2_r[3], pred_2_r[2], pred_2_r[1], pred_2_r[0]};

   always @(wr_0_idx_i   or wr_1_idx_i   or
            wr_0_wen_i   or wr_1_wen_i   or
            wr_0_bit_i   or wr_1_bit_i)
     begin

        wr_idx_w[0] = wr_0_idx_i;
        wr_idx_w[1] = wr_1_idx_i;

        wr_en_w[0] = wr_0_wen_i;
        wr_en_w[1] = wr_1_wen_i;

        wr_bit_w[0] = wr_0_bit_i;
        wr_bit_w[1] = wr_1_bit_i;

        for (i = 0; i < 4; i = i + 1)
          begin
             pred_2_r[i] = pred_reg_r[i];

             for (j = 0; j < 2; j = j + 1)
               begin
                  if (wr_en_w[j] && i == wr_idx_w[j])
                    begin
                       pred_2_r[i] = wr_bit_w[j];
                    end
               end
          end
     end

`else

   assign pred_reg_w = {pred_reg_r[3:1], 1'b1};

`endif

   assign rd_0_bit_o = pred_reg_w[rd_0_idx_i];
   assign rd_1_bit_o = pred_reg_w[rd_1_idx_i];
   assign rd_2_bit_o = pred_reg_w[rd_2_idx_i];
   assign rd_3_bit_o = pred_reg_w[rd_3_idx_i];
   assign rd_4_bit_o = pred_reg_w[rd_4_idx_i];
   assign rd_5_bit_o = pred_reg_w[rd_5_idx_i];

   assign spec_regs_data_o = (spec_regs_ren_i && spec_regs_raddr_i == SPEC_REGS_ADDR_PRED)
     ? pred_reg_r : 16'hzzzz;

   always @(posedge clk)
     begin
        if (rst)
          begin
             pred_reg_r <= 1;
          end
        else
          begin
             if (spec_regs_wen_i && spec_regs_waddr_i == SPEC_REGS_ADDR_PRED)
               begin
                  pred_reg_r <= spec_regs_data_i;
               end
             else
               begin
                  if (wr_0_wen_i)
                    begin
                       pred_reg_r[wr_0_idx_i] <= wr_0_bit_i;
                    end

                  if (wr_1_wen_i)
                    begin
                       pred_reg_r[wr_1_idx_i] <= wr_1_bit_i;
                    end
               end
          end // else: !if(rst)
     end // always @ (posedge clk)

endmodule // predbits
