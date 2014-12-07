//======================================================================
//
// modexp.v
// --------
// Modular exponentiation core for implementing public key algorithms
// such as RSA, DH, ElGamal etc.
//
// The core calculates the following function:
//
//   C = M ** e mod N
//
//   M is a message with a length of n bits
//   e is the exponent with a length of at most 32 bits
//   N is the modulus  with a length of n bits
//   n is can be 32 and up to and including 8192 bits in steps
//   of 32 bits.
//
// The core has a 32-bit memory like interface, but provides
// status signals to inform the system that a given operation
// has is done. Additionally, any errors will also be asserted.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2014, Secworks Sweden AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module modexp(
              input wire           clk,
              input wire           reset_n,

              input wire           cs,
              input wire           we,

              input wire  [11 : 0] address,
              input wire  [31 : 0] write_data,
              output wire [31 : 0] read_data,

              output wire          done,
              output wire          error
             );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter GENERAL_PREFIX     = 4'h0;
  parameter ADDR_NAME0         = 8'h00;
  parameter ADDR_NAME1         = 8'h01;
  parameter ADDR_VERSION       = 8'h02;

  parameter ADDR_KEYSIZE       = 8'h10;
  parameter ADDR_EXPONENT      = 8'h20;

  parameter MODULUS_PREFIX     = 4'h1;
  parameter ADDR_MODULUS_START = 8'h00;
  parameter ADDR_MODULUS_END   = 8'hff;

  parameter MESSAGE_PREFIX     = 4'h2;
  parameter MESSAGE_START      = 8'h00;
  parameter MESSAGE_END        = 8'hff;

  parameter CORE_NAME0         = 32'h72736120; // "rsa "
  parameter CORE_NAME1         = 32'h38313932; // "8192"
  parameter CORE_VERSION       = 32'h302e3031; // "0.01"

  parameter DEFAULT_KEYSIZE    = 8'h80;

  parameter DECIPHER_MODE      = 1'b0;
  parameter ENCIPHER_MODE      = 1'b1;

  parameter CTRL_IDLE          = 3'h0;
  parameter CTRL_START         = 3'h1;
  parameter CTRL_INIT          = 3'h2;
  parameter CTRL_RESIDUE0      = 3'h3;
  parameter CTRL_ITERATE       = 3'h4;
  parameter CTRL_RESIDUE1      = 3'h5;
  parameter CTRL_DONE          = 3'h6;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [31 : 0] modulus_mem [0 : 255];
  reg          modulus_mem_we;
  reg [31 : 0] modulus_data;

  reg [31 : 0] message_mem [0 : 255];
  reg          message_mem_we;
  reg [31 : 0] message_data;

  reg [31 : 0] exponent_reg;
  reg [31 : 0] exponent_new;
  reg          exponent_we;

  reg [7 : 0]  keysize_reg;
  reg [7 : 0]  keysize_new;
  reg          keysize_we;

  reg [7 : 0]  modulus_rd_ptr_reg;
  reg [7 : 0]  modulus_rd_ptr_new;
  reg          modulus_rd_ptr_we;

  reg [7 : 0]  message_rd_ptr_reg;
  reg [7 : 0]  message_rd_ptr_new;
  reg          message_rd_ptr_we;

  reg          encdec_reg;
  reg          encdec_new;
  reg          encdec_we;

  reg          start_reg;
  reg          start_new;
  reg          start_we;

  reg          done_reg;
  reg          done_new;
  reg          done_we;

  reg [2 : 0]  rsa_ctrl_reg;
  reg [2 : 0]  rsa_ctrl_new;
  reg          rsa_ctrl_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [31 : 0] tmp_read_data;
  reg          tmp_error;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign read_data = tmp_read_data;
  assign done      = done_reg;
  assign error     = tmp_error;


  //----------------------------------------------------------------
  // core instantiation.
  //----------------------------------------------------------------


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          exponent_reg       <= 32'h00000000;
          modulus_rd_ptr_reg <= 8'h00;
          message_rd_ptr_reg <= 8'h00;
          keysize_reg        <= DEFAULT_KEYSIZE;
          encdec_reg         <= ENCIPHER_MODE;
          start_reg          <= 1'b0;
          done_reg           <= 1'b0;
          rsa_ctrl_reg       <= CTRL_IDLE;
        end
      else
        begin
          modulus_data <= modulus_mem[modulus_rd_ptr_reg];
          message_data <= message_mem[message_rd_ptr_reg];

          if (modulus_mem_we)
            begin
              modulus_mem[address[7 : 0]] <= write_data;
            end

          if (message_mem_we)
            begin
              message_mem[address[7 : 0]] <= write_data;
            end

          if (exponent_we)
            begin
              exponent_reg <= write_data;
            end

          if (keysize_we)
            begin
              keysize_reg <= write[7 : 0];
            end

          if (modulus_rd_ptr_we)
            begin
              modulus_rd_ptr_reg <= modulus_rd_ptr_new;
            end

          if (message_rd_ptr_we)
            begin
              message_rd_ptr_reg <= message_rd_ptr_new;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // api
  //
  // The interface command decoding logic.
  //----------------------------------------------------------------
  always @*
    begin : api
      keysize_new     = 4'h0;
      keysize_we      = 0;
      tmp_read_data   = 32'h00000000;
      tmp_error       = 0;
      modulus_mem_we  = 0;
      priv_exp_mem_we = 0;

      if (cs)
        begin
          case (address[11 : 8])
            GENERAL_PREFIX:
              begin
                if (we)
                  begin
                    case (address)
                      // Write operations.
                      ADDR_KEYSIZE:
                        begin
                          keysize_new = write_data[3 : 0];
                          keysize_we  = 0;
                        end

                      default:
                        begin
                          tmp_error = 1;
                        end
                    endcase // case (addr)
                  end // if (write_read)
                else
                  begin
                    case (address)
                      // Read operations.
                      ADDR_NAME0:
                        begin
                          tmp_read_data = CORE_NAME0;
                        end

                      ADDR_NAME1:
                        begin
                          tmp_read_data = CORE_NAME1;
                        end

                      ADDR_VERSION:
                        begin
                          tmp_read_data = CORE_VERSION;
                        end

                      ADDR_KEYSIZE:
                        begin
                          tmp_read_data = {28'h0000000, keysize_reg};
                        end

                      default:
                        begin
                          tmp_error = 1;
                        end
                    endcase // case (addr)
                  end
              end

            MODULUS_PREFIX:
              begin
                if (we)
                  begin
                    modulus_mem_we = we;
                  end
                else
                  begin
                    tmp_read_data = modulus_mem[address[7 : 0]];
                  end
              end

            D_EXP_PREFIX:
              begin
                if (we)
                  begin
                    priv_exp_mem_we = 1;
                  end
                else
                  begin
                    tmp_read_data = priv_exp_mem[address[7 : 0]];
                  end
              end

            default:
              begin

              end
          endcase // case (address[11 : 8])
        end // if (cs)
    end // addr_decoder
endmodule // modexp

//======================================================================
// EOF modexp.v
//======================================================================
