
source /opt/Xilinx/Vivado/2018.3/.settings64-Vivado.sh
source /opt/Xilinx/SDx/2018.3/.settings64-SDx.sh
source /opt/Xilinx/DocNav/.settings64-DocNav.sh
source /opt/Xilinx/SDK/2018.3/.settings64-SDK_Core_Tools.sh
source /opt/xilinx/xrt/setup.sh


TARGET=hw_emu
DEVICE=xilinx_vcu1525_xdma_201830_1


export XCL_EMULATION_MODE=$TARGET

# Generate emconfig.json
if [ ! -f ./emconfig.json ]
then
	emconfigutil --platform $DEVICE --od ./
fi

# Run
./ethash_test 0 Xilinx ./xclbin/ethash.$TARGET.$DEVICE.xclbin

