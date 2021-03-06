#!/usr/bin/perl

# This file is part of AjarDSP
#
# Copyright (c) 2010, 2011 Markus Lavin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of the <ORGANIZATION> nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

$workdir = "workdir";
$rtldir  = "../../rtl/verilog/";
$crt_file = "../tools/crt.s";

$cflags = " -Os -O3 -fno-inline -minsert-nops -fdump-rtl-all";

$asm_pass_cnt = 0;
$asm_fail_cnt = 0;
$sim_pass_cnt = 0;
$sim_fail_cnt = 0;
$ver_pass_cnt = 0;
$ver_fail_cnt = 0;


$debug = 0;
$target = 0;
$verbose = 0;
$iverilog = 0;

foreach $arg (@ARGV) {
    if ($arg =~ /-debug/) {
        $debug = 1;
    }
    elsif ($arg =~ /-target/) {
        $target = 1;
        die "\n!!! -target is no longer supported for AjarDSP-SoC. Use wb_debug instead !!!\n";
    }
    elsif ($arg =~ /-iverilog/) {
        $iverilog = 1;
    }
    elsif ($arg =~ /-verbose/) {
        $verbose = 1;
    }
    else {
        push(@input_files, $arg);
    }
}

if ($iverilog) {
    $incdir_opt = "-I";
    $define_opt = "-D";
    $sim_command_base = "iverilog $incdir_opt$rtldir $rtldir/testbench.v $rtldir/ajardsp_top.v $rtldir/vliwfetch.v $rtldir/vliwdec.v $rtldir/pcu.v $rtldir/lsu.v $rtldir/sp.v $rtldir/ptrrf.v $rtldir/dmem.v $rtldir/imem.v $rtldir/accrf.v $rtldir/cu.v $rtldir/bmu.v $rtldir/curegs.v $rtldir/int_addsub.v $rtldir/int_mul.v $rtldir/pred.v -o $workdir/ajardsp.vvp";
}
else {
    $incdir_opt = "+incdir+";
    $define_opt = "+define+";
    $sim_command_base = "cver $incdir_opt$rtldir $rtldir/testbench.v $rtldir/ajardsp_top.v $rtldir/vliwfetch.v $rtldir/vliwdec.v $rtldir/pcu.v $rtldir/lsu.v $rtldir/sp.v $rtldir/ptrrf.v $rtldir/dmem.v $rtldir/imem.v $rtldir/accrf.v $rtldir/cu.v $rtldir/bmu.v $rtldir/curegs.v $rtldir/int_addsub.v $rtldir/int_mul.v $rtldir/pred.v";
}


if ($debug) {
    $sim_command_base = $sim_command_base . " +loadvpi=../tools/simdebug/debug.so:vpi_bootstrap ";
}

system("mkdir $workdir 2> /dev/null");

if (!defined(@input_files)) {
    @input_files = glob("*.asm");
}

foreach $input_file (@input_files) {

    print "\n";

    if ($input_file =~ /\.c$/) {
        $input_file =~ /([^.]+)\.c/;
        $base_name = $1;

        # Before we do anything make sure that we start clean
        system("rm -f $workdir/$base_name.*");

        $intermediate_asm_file = "$workdir/$base_name.s";

        $asm_file = $workdir . "/" . $base_name . ".asm";

        if (0 == system("ajardsp-gcc -S -o $intermediate_asm_file $input_file $cflags > /dev/null 2> /dev/null")) {
            printf("%-64s [PASSED]\n", "Compiling '$input_file'");
        }
        else {
            printf("%-64s [FAILED]\n", "Compiling '$input_file'");
            next;
        }
        system("cat $crt_file $intermediate_asm_file > $asm_file") && die "Failed to prepend $crt_file\n";

        # Avoid comparing the stack area as it is likely to change
        $mem_match_size = 0x1000/2;
    }
    elsif ($input_file =~ /\.asm$/) {
        $input_file =~ /([^.]+)\.asm/;
        $base_name = $1;

        # Before we do anything make sure that we start clean
        system("rm -f $workdir/$base_name.*");

        $asm_file = $input_file;
        $mem_match_size = 0x10000;
    }
    else {
        die "Unknown file format for $input_file\n";
    }

    $asm_command = "../tools/asm/ajardsp-asm -o=$workdir/$base_name $asm_file";

    $sim_command_def = " $define_opt"."SIMULATION "
        . " $define_opt"."SIMULATION_IMEM "
        . " $define_opt"."SIMULATION_DMEM "
        . "$define_opt"."IMEM_FILE=\\\"$workdir/$base_name.imem\\\" "
        . "$define_opt"."DMEM_IN_FILE=\\\"$workdir/$base_name.dmem\\\" "
        . "$define_opt"."DMEM_OUT_FILE=\\\"$workdir/$base_name.res\\\" ";

    $sim_command = $sim_command_base . $sim_command_def;

    #### Assemble - begin ####
    if (0 == system($asm_command)) {
        printf("%-64s [PASSED]\n", "Assembling '$asm_file'");
        $asm_pass_cnt++;
        system("rm verilog.dump 2> /dev/null");
        system("rm verilog.log 2> /dev/null");
        system("rm $workdir/$base_name.res 2> /dev/null");
    }
    else {
        printf("%-64s [->FAILED<-]\n", "Assembling '$asm_file'");
        $asm_fail_cnt++;
        next;
    }
    #### Assemble - end ####

    if ($target) {
        #### Target - begin ####
        if (0 == system("../tools/target/targetmon $workdir/$base_name.imem $workdir/$base_name.dmem $workdir/$base_name.res")) {
            printf("%-64s [PASSED]\n", "Executing on target '$asm_file'");
        }
        else {
            printf("%-64s [->FAILED<-]\n", "Executing on target '$asm_file'");
            next;
        }
        #### Target - end ####
    }
    else {

        #### Simulation - begin ####
        print "Sim command: $sim_command\n" if $verbose;

        @ENV{"AJARDSP_SIMDEBUG_ASM_PATH"}    = $asm_file;
        @ENV{"AJARDSP_SIMDEBUG_LINENO_PATH"} = "$workdir/$base_name.lineno";

        if ($iverilog) {
            $sim_errors = 0;
            $sim_warnings = 0;
            $sim_infos = 0;
            $sim_cycles = 0;
            system("$sim_command 2> /dev/null > /dev/null") == 0 or $sim_errors = 1;
            if ($debug) {
                open(SIM_CMD, "vvp -m../tools/simdebug/debug.vpi $workdir/ajardsp.vvp |") or $sim_errors = 1;
            }
            else {
                open(SIM_CMD, "vvp $workdir/ajardsp.vvp |") or $sim_errors = 1;
            }
        }
        else {

            open(SIM_CMD, "$sim_command |") or die "Can't run simulation command: $sim_command\n";
            @sim_stdout = <SIM_CMD>;

            $sim_errors = 1;

            if ($sim_stdout[$#sim_stdout] =~
                m/^  There were ([0-9]+) error\(s\), ([0-9]+) warning\(s\), and ([0-9]+) inform\(s\)\./) {

                $sim_errors = $1;
                $sim_warnings = $2;
                $sim_infos = $3;
            }
            $sim_cycles = -1;

            if ($sim_stdout[$#sim_stdout - 1] =~ m/time ([0-9]+) from call to \$finish.$/) {

                $sim_cycles = $1/2;
            }

            system("mv verilog.dump $workdir/$base_name.verilog.dump");
            system("mv verilog.log $workdir/$base_name.verilog.log");
        }

        if ($sim_errors == 0) {
            printf("%-51s cycles=%-5d [PASSED]\n", "Simulation (RTL) with input '$asm_file'", $sim_cycles);
            $sim_pass_cnt++;
        }
        else {
            printf("%-64s [->FAILED<-]\n", "Simulation (RTL) with input '$asm_file'");
            $sim_fail_cnt++;
            next;
        }
        #### Simulation - end ####
    }

    #### Verify - begin ####
    $ref_file = $base_name . ".ref";
    $ref_file_comp = $ref_file . ".gz";

    if (-e $ref_file || -e $ref_file_comp) {
        if (-e $ref_file_comp) {
            $ref_file = "$workdir/$ref_file";
            system("zcat $ref_file_comp > $ref_file");
        }
#        if (0 == system("diff $ref_file $workdir/$base_name.res > /dev/null")) {
        if (mems_match($ref_file, "$workdir/$base_name.res", $mem_match_size)) {
            printf("%-64s [PASSED]\n", "Verifying DMEM contents ($mem_match_size words) after '$asm_file'");
            $ver_pass_cnt++;
        }
        else {
            printf("%-64s [->FAILED<-]\n", "Verifying DMEM contents ($mem_match_size words) after '$asm_file'");
            $ver_fail_cnt++;
            next;
        }
    }
    #### Verify - end ####
}


printf("\nStatistics:\n" .
       "Assembler    %3d passed, %3d failed\n" .
       "Simulation   %3d passed, %3d failed\n" .
       "Verification %3d passed, %3d failed\n\n",
       $asm_pass_cnt, $asm_fail_cnt,
       $sim_pass_cnt, $sim_fail_cnt,
       $ver_pass_cnt, $ver_fail_cnt);


sub mems_match {
    $file_0 = $_[0];
    $file_1 = $_[1];
    $lines_to_cmp = $_[2];

    open FILE_0, $file_0 or return 0;
    open FILE_1, $file_1 or return 0;

    @lines_0 = <FILE_0>;
    @lines_1 = <FILE_1>;

    for ($i = 0; $i < $lines_to_cmp; $i++) {
        if ($lines_0[$i] != $lines_1[$i]) {
            return 0;
        }
    }

    return 1;
}
