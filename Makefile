.PHONY: help

help::
	$(ECHO) "Makefile Usage:"
	$(ECHO) "  make all TARGET=<sw_emu/hw_emu/hw> DEVICE=<FPGA platform>"
	$(ECHO) "      Command to generate the design for specified Target and Device."
	$(ECHO) ""
	$(ECHO) "  make clean "
	$(ECHO) "      Command to remove the generated non-hardware files."
	$(ECHO) ""
	$(ECHO) "  make cleanall"
	$(ECHO) "      Command to remove all the generated files."
	$(ECHO) ""
	$(ECHO) "  make check TARGET=<sw_emu/hw_emu/hw> DEVICE=<FPGA platform>"
	$(ECHO) "      Command to run application in emulation."
	$(ECHO) ""
	$(ECHO) "  make build TARGET=<sw_emu/hw_emu/hw> DEVICE=<FPGA platform>"
	$(ECHO) "      Command to build xclbin application."
	$(ECHO) ""
	$(ECHO) "  make run_nimbix DEVICE=<FPGA platform>"
	$(ECHO) "      Command to run application on Nimbix Cloud."
	$(ECHO) ""
	$(ECHO) "  make aws_build DEVICE=<FPGA platform>"
	$(ECHO) "      Command to build AWS xclbin application on AWS Cloud."
	$(ECHO) ""

# Points to Utility Directory
COMMON_REPO = ./
ABS_COMMON_REPO = $(shell readlink -f $(COMMON_REPO))

TARGETS := hw
TARGET := $(TARGETS)
DEVICE := $(DEVICES)
XCLBIN := ./xclbin

include ./utils.mk

DSA := $(call device2dsa, $(DEVICE))
BUILD_DIR := ./_x.$(TARGET).$(DSA)

BUILD_DIR_krnl_nearest = $(BUILD_DIR)/ethash

CXX := $(XILINX_SDX)/bin/xcpp
XOCC := $(XILINX_SDX)/bin/xocc
CP = cp -rf

################
# Host sources
################

EXECUTABLE = ethash_test

#Include Libraries
include $(ABS_COMMON_REPO)/libs/opencl/opencl.mk
include $(ABS_COMMON_REPO)/libs/xcl2/xcl2.mk
CXXFLAGS += $(xcl2_CXXFLAGS)
LDFLAGS += $(xcl2_LDFLAGS)
HOST_SRCS += $(xcl2_SRCS)
CXXFLAGS += $(opencl_CXXFLAGS) -Wall -O0 -g -std=c++14
LDFLAGS += $(opencl_LDFLAGS)

CXXFLAGS += -fmessage-length=0
LDFLAGS += -lrt -lstdc++ 

HOST_SRCS += ./src/host.cpp
HOST_SRCS += ./src/main.cpp

# ethash lib
CXXFLAGS += -I./src/lib/ethash -I./src/lib/ethash/include
HOST_SRCS += ./src/lib/ethash/lib/ethash/ethash.cpp
HOST_SRCS += ./src/lib/ethash/lib/ethash/managed.cpp
HOST_SRCS += ./src/lib/ethash/lib/ethash/primes.c
HOST_SRCS += ./src/lib/ethash/lib/keccak/keccak.c

#################
# Kernel sources
#################

KERNEL_NAME = ethash

# Kernel compiler global settings
CLFLAGS += -t $(TARGET) --platform $(DEVICE) --save-temps 
CLFLAGS +=  -DXILINX -DMAX_OUTPUTS=4 -DWORKSIZE=128 -DACCESSES=64 -DLEGACY

CMD_ARGS = $(XCLBIN)/$(KERNEL_NAME).$(TARGET).$(DSA).xclbin 

EMCONFIG_DIR = $(XCLBIN)/$(DSA)

BINARY_CONTAINERS += $(XCLBIN)/$(KERNEL_NAME).$(TARGET).$(DSA).xclbin
BINARY_CONTAINER_OBJS += $(XCLBIN)/search.$(TARGET).$(DSA).xo
BINARY_CONTAINER_OBJS += $(XCLBIN)/GenerateDAG.$(TARGET).$(DSA).xo


.PHONY: all clean cleanall docs emconfig
all: check-devices $(EXECUTABLE) $(BINARY_CONTAINERS) emconfig

.PHONY: exe
exe: $(EXECUTABLE)

.PHONY: build
build: $(BINARY_CONTAINERS)

##################
# Building kernel
##################
$(XCLBIN)/search.$(TARGET).$(DSA).xo: kernel/ethash.cl
	mkdir -p $(XCLBIN)
	$(XOCC) $(CLFLAGS) --temp_dir $(BUILD_DIR_krnl_nearest) -c -k search -I'$(<D)' -o'$@' '$<'

$(XCLBIN)/GenerateDAG.$(TARGET).$(DSA).xo: kernel/ethash.cl
	mkdir -p $(XCLBIN)
	$(XOCC) $(CLFLAGS) --temp_dir $(BUILD_DIR_krnl_nearest) -c -k GenerateDAG -I'$(<D)' -o'$@' '$<'

$(XCLBIN)/$(KERNEL_NAME).$(TARGET).$(DSA).xclbin: $(BINARY_CONTAINER_OBJS)
	mkdir -p $(XCLBIN)
	$(XOCC) $(CLFLAGS) --temp_dir $(BUILD_DIR_krnl_nearest) -l $(LDCLFLAGS) --nk search:1 --nk GenerateDAG:1 -o'$@' $(+)

################
# Building Host
################
$(EXECUTABLE): check-xrt $(HOST_SRCS) $(HOST_HDRS)
	$(CXX) $(CXXFLAGS) $(HOST_SRCS) $(HOST_HDRS) -o '$@' $(LDFLAGS)

emconfig:$(EMCONFIG_DIR)/emconfig.json
$(EMCONFIG_DIR)/emconfig.json:
	emconfigutil --platform $(DEVICE) --od $(EMCONFIG_DIR)

check: all
ifeq ($(TARGET),$(filter $(TARGET),sw_emu hw_emu))
	$(CP) $(EMCONFIG_DIR)/emconfig.json .
	XCL_EMULATION_MODE=$(TARGET) ./$(EXECUTABLE) 0 Xilinx $(XCLBIN)/$(KERNEL_NAME).$(TARGET).$(DSA).xclbin 
else
	 ./$(EXECUTABLE) 0 Xilinx $(XCLBIN)/$(KERNEL_NAME).$(TARGET).$(DSA).xclbin 
endif
	sdx_analyze profile -i profile_summary.csv -f html

run_nimbix: all
	$(COMMON_REPO)/utility/nimbix/run_nimbix.py $(EXECUTABLE) $(CMD_ARGS) $(DSA)

aws_build: check-aws_repo $(BINARY_CONTAINERS)
	$(COMMON_REPO)/utility/aws/run_aws.py $(BINARY_CONTAINERS)

# Cleaning stuff
clean:
	-$(RMDIR) $(EXECUTABLE) $(XCLBIN)/{*sw_emu*,*hw_emu*} 
	-$(RMDIR) profile_* TempConfig system_estimate.xtxt *.rpt *.csv 
	-$(RMDIR) src/*.ll _xocc_* .Xil emconfig.json dltmp* xmltmp* *.log *.jou *.wcfg *.wdb

cleanall: clean
	-$(RMDIR) $(XCLBIN)
	-$(RMDIR) _x.*

