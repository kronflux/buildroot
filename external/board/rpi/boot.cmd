saveenv
fdt addr ${fdt_addr} && fdt get value bootargs /chosen bootargs
if env exists bootpart;then echo Booting from mmcblk0p${bootpart};else setenv bootpart 2;echo bootpart not set, default to ${bootpart};fi
fatload mmc 0:1 ${kernel_addr_r} Image
setenv bootargs "${bootargs} root=/dev/mmcblk0p${bootpart}"
booti ${kernel_addr_r} - ${fdt_addr}
