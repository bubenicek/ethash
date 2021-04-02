
source /opt/Xilinx/Vivado/2018.3/.settings64-Vivado.sh
source /opt/Xilinx/SDx/2018.3/.settings64-SDx.sh
source /opt/Xilinx/DocNav/.settings64-DocNav.sh
source /opt/Xilinx/SDK/2018.3/.settings64-SDK_Core_Tools.sh

export PATH=$PATH:/opt/xilinx/xrt/bin
export XILINX_XRT=/opt/xilinx/xrt

# sw_emu|hw_emu|hw
TARGET=sw_emu
DEVICE=xilinx_vcu1525_xdma_201830_1

# Build host 
make exe

# Build kernel
make build TARGET=$TARGET DEVICE=$DEVICE -j


