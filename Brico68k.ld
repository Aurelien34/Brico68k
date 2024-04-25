MEMORY {
	VECTORS: org=0xc00000, len=0x80
	ROM: org=0xc00080, len=0x7f80
}

SECTIONS {
	.vectors: {
		*(vectors)
	} >VECTORS

	.rom: {
		*(text)
	} >ROM
}
