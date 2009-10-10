//author :gurenliang
//Email: gurenliang@gmail.com
//note: if there are some errors, you are welcome to contact me. It would be the best appreciation to me.

//version 0.3, create this file to be a common included one for future use to config the IP core
//This file used to define some macro-varibles which can be used by all other files

//NOTE!!! Olny one of the following two definitions can be open
`define frameIDfromRx			//frameID comes from Rxmodule
//`define frameIDcount			//frameID counts for itself by adding one every frame

`define Preamble	64'hd555_5555_5555_5555

//The MAC address of this MAC IP core and the other terminal on the Ethernet, can be changed!
`define MAC_ADD		48'h0100_0000_0000	//mac address: 0x00-00-00-00-00-01
`define PC_MAC_ADD	48'hffff_ffff_ffff	//mac address of the other terminal