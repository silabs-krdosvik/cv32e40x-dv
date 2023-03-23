// Copyright 2023 Silicon Labs, Inc.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License"); you may
// not use this file except in compliance with the License, or, at your option,
// the Apache License version 2.0.
//
// You may obtain a copy of the License at
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//
// See the License for the specific language governing permissions and
// limitations under the License.


`default_nettype none


module  uvmt_cv32e40s_pma_cov
  import uvmt_cv32e40s_pkg::*;
#(
  parameter int  PMA_NUM_REGIONS,
  parameter bit  IS_INSTR_SIDE
)(
  input wire  clk,
  input wire  rst_n,

  input wire  core_trans_ready_o,
  input wire  core_trans_valid_i,
  input wire  misaligned_access_i,
  input wire  load_access,
  input wire  core_trans_pushpop_i,

  input wire pma_status_t  pma_status_i,

  uvma_rvfi_instr_if  rvfi_if
);


  // Helper Logic - Match Info

  wire logic [31:0]  num_matches;
  assign  num_matches = $countones(pma_status_i.match_list);

  let  have_match = pma_status_i.have_match;
  let  match_idx  = pma_status_i.match_idx;


  // Helper Logic - MPU Activation

  wire logic  is_mpu_activated;
  assign  is_mpu_activated = (core_trans_ready_o && core_trans_valid_i);


  // MPU Coverage Definition

  covergroup cg_mpu @(posedge clk);
    option.per_instance = 1;
    option.detect_overlap = 1;

    // vplan:"Valid number of regions"
    cp_numregions: coverpoint  PMA_NUM_REGIONS {
      bins zero = {0}      with (PMA_NUM_REGIONS == 0);
      bins mid  = {[1:15]} with ((0 < PMA_NUM_REGIONS) && (PMA_NUM_REGIONS < 16));
      bins max  = {16}     with (PMA_NUM_REGIONS == 16);
    }

    // vplan:"Overlapping PMA Regions"
    cp_multimatch: coverpoint  num_matches  iff (is_mpu_activated) {
      bins zero = {0};
      bins one  = {1}                   with (0 < PMA_NUM_REGIONS);
      bins many = {[2:PMA_NUM_REGIONS]} with (1 < PMA_NUM_REGIONS);
    }

    // vplan:TODO
    cp_matchregion: coverpoint  match_idx  iff (is_mpu_activated) {
      bins           regions[] = {[0:PMA_NUM_REGIONS-1]}  iff (have_match == 1);
      wildcard bins  nomatch   = {'X}                     iff (have_match == 0);
    }

    // vplan:TODO
    cp_aligned: coverpoint  misaligned_access_i  iff (is_mpu_activated) {
      bins          misaligned = {1} with (!IS_INSTR_SIDE);
      illegal_bins  illegal    = {1} with ( IS_INSTR_SIDE);
      bins          aligned    = {0};
    }

    // vplan:TODO
    cp_loadstoreexec: coverpoint  load_access  iff (is_mpu_activated) {
      bins           load  = {1}  with (!IS_INSTR_SIDE);
      bins           store = {0}  with (!IS_INSTR_SIDE);
      wildcard bins  exec  = {'X} with ( IS_INSTR_SIDE);
    }

    // vplan:TODO
    cp_allow:       coverpoint  pma_status_i.allow       iff (is_mpu_activated) {
      bins allow    = {1};
      bins disallow = {0};
    }
    cp_main:        coverpoint  pma_status_i.main        iff (is_mpu_activated);
    cp_bufferable:  coverpoint  pma_status_i.bufferable  iff (is_mpu_activated) {
      bins          bufferable    = {1} with (!IS_INSTR_SIDE);
      illegal_bins  illegal       = {1} with ( IS_INSTR_SIDE);
      bins          nonbufferable = {0};
    }
    cp_cacheable:  coverpoint  pma_status_i.cacheable    iff (is_mpu_activated);
    cp_integrity:  coverpoint  pma_status_i.integrity    iff (is_mpu_activated);
    cp_overridedm: coverpoint  pma_status_i.override_dm  iff (is_mpu_activated);

    // vplan:TODO
    cp_pushpop: coverpoint  core_trans_pushpop_i  iff (is_mpu_activated) {
      bins          pushpop = {1} with (!IS_INSTR_SIDE);
      illegal_bins  illegal = {1} with ( IS_INSTR_SIDE);
      bins          no      = {0};
    }

    // vplan:DebugRange
    cp_dmregion: coverpoint  pma_status_i.accesses_dmregion  iff (is_mpu_activated) {
      bins in  = {1};
      bins out = {0};
    }
    cp_dmode: coverpoint  core_trans_i.dbg  iff (is_mpu_activated) {
      bins dmode = {1};
      bins no    = {0};
    }

    x_multimatch_aligned_loadstoreexec: cross  cp_multimatch, cp_aligned, cp_loadstoreexec;
    x_multimatch_allow_loadstoreexec:   cross  cp_multimatch, cp_allow, cp_loadstoreexec {
      illegal_bins illegal =
        binsof(cp_multimatch.zero) && binsof(cp_allow.allow) && binsof(cp_loadstoreexec.exec);
      //TODO:ERROR:silabs-robin how to solve this?
    }
    x_multimatch_main:                  cross  cp_multimatch, cp_main;
    x_multimatch_bufferable:            cross  cp_multimatch, cp_bufferable;
    x_multimatch_cacheable:             cross  cp_multimatch, cp_cacheable;
    x_multimatch_integrity:             cross  cp_multimatch, cp_integrity;
    x_multimatch_overridedm:            cross  cp_multimatch, cp_overridedm;

    x_aligned_allow:              cross  cp_aligned, cp_allow;
    x_aligned_main_loadstoreexec: cross  cp_aligned, cp_main, cp_loadstoreexec;
    x_aligned_bufferable:         cross  cp_aligned, cp_bufferable;
    x_aligned_cacheable:          cross  cp_aligned, cp_cacheable;
    x_aligned_integrity:          cross  cp_aligned, cp_integrity;
    x_aligned_overridedm:         cross  cp_aligned, cp_overridedm;

    x_loadstoreexec_allow_main:   cross  cp_loadstoreexec, cp_allow, cp_main;
    x_loadstoreexec_main_pushpop: cross  cp_loadstoreexec, cp_main, cp_pushpop;
    x_loadstoreexec_bufferable:   cross  cp_loadstoreexec, cp_bufferable;
    x_loadstoreexec_cacheable:    cross  cp_loadstoreexec, cp_cacheable;
    x_loadstoreexec_integrity:    cross  cp_loadstoreexec, cp_integrity;
    x_loadstoreexec_overridedm:   cross  cp_loadstoreexec, cp_overridedm;

    x_allow_main:       cross  cp_allow, cp_main;
    x_allow_bufferable: cross  cp_allow, cp_bufferable;
    x_allow_cacheable:  cross  cp_allow, cp_cacheable;
    x_allow_integrity:  cross  cp_allow, cp_integrity;
    x_allow_overridedm: cross  cp_allow, cp_overridedm;

    x_dmregion_dmode: cross  cp_dmregion, cp_dmode;

    //TODO:INFO:silabs-robin more crosses are possible, but bordering on impractical/infeasible
  endgroup

  cg_mpu  mpu_cg = new;


  // RVFI Coverage Definition

  covergroup cg_rvfi @(posedge clk);
    option.per_instance = 1;
    option.detect_overlap = 1;

    cp_aligned: coverpoint  rvfi_if.is_split_datatrans()  iff (rvfi_if.rvfi_valid) {
      bins  misaligned = {1};
      bins  aligned    = {0};
    }

    cp_pmafault: coverpoint  rvfi_if.is_pma_fault()  iff (rvfi_if.rvfi_valid) {
      bins  fault = {1};
      bins  no    = {0};
    }

    cp_loadstore: coverpoint  rvfi_if.rvfi_mem_wmask  iff (rvfi_if.is_mem_act()) {
      bins  load  = {0};
      bins  store = rvfi_if.rvfi_mem_wmask with (item != 0);
    }
  endgroup

  if (!IS_INSTR_SIDE) begin: gen_rvfi_cg
    cg_rvfi  rvfi_cg = new;
    // RVFI is 1 interface, so we don't need an exact duplicate at both MPUs.
  end


endmodule : uvmt_cv32e40s_pma_cov


`default_nettype wire
