#include <asm.h>

.set	AR_DMA_CNT,			0xCC005028

.set	OSReport,			0xC0001860
.set	AR_DBG,				0x930028A0

.set	AR_MRAM_TO_ARAM,	0
.set	AR_ARAM_TO_MRAM,	1

#in
#	r3	u32 type
#	r4	u32 mainmem_addr
#	r5	u32 aram_addr
#	r6	u32 length

#out
#	none

ARStartDMA:
#	lis		%r7,	OSReport@h
#	ori		%r7,	%r7,	OSReport@l
#	stw		%r4,	4(%r7)
#	stw		%r5,	8(%r7)
#	stw		%r6,	12(%r7)

#	lis		%r8,	AR_DBG@h
#	ori		%r8,	%r8,	AR_DBG@l
#	stw		%r8,	0(%r7)
#repeatprint:
#	lwz		%r0,	0(%r7)
#	cmpw	%r0,	%r8
#	beq		repeatprint

	cmpwi	%r6,	0
	beq		FakeTransfer

	#adjust ARAM address for safety
	rlwinm	%r5,	%r5,	0,		6,		26 # 0x03ffffe0
	oris	%r5,	%r5,	0x9000

	add		%r0,	%r5,	%r6
	#ARAM Max Address to ensure no overwriting 
	lis		%r7,	0x9100
	cmplw	%r0,	%r7
	#Out of Memory Bounds, dont do anything
	bgt		FakeTransfer

	#adjust MEM1 address for safety
	rlwinm	%r4,	%r4,	0,		7,		26 # 0x01ffffe0
	oris	%r4,	%r4,	0x8000

	cmpwi	%r3,	AR_MRAM_TO_ARAM
	beq		memcpy32prep		#we dont need to invalidate main mem

ARAM_TO_MRAM:
	mr		%r0,	%r4
	mr		%r4,	%r5
	mr		%r5,	%r0

	addi	%r0,	%r6,	0x1F
	srwi	%r0,	%r0,	5
	mtctr	%r0
	mr		%r7,	%r4

	li		%r0,	0
DCInvalidateRange:
	dcbi	%r0,	%r7
	addi	%r7,	%r7,	0x20
	bdnz	DCInvalidateRange
	sync

memcpy32prep:
	li		%r7,	0
	cmplwi	%r6,	3
	ble		memcpy16prep
	srwi	%r0,	%r6,	2	#32bit
	mtctr	%r0
memcpy32:
	lwzx	%r0,	%r4,	%r7
	stwx	%r0,	%r5,	%r7
	addi	%r7,	%r7,	4
	bdnz	memcpy32

memcpy16prep:
	subf	%r0,	%r7,	%r6
	cmpwi	%r0,	1
	ble		memcpy8prep
memcpy16:
	lhzx	%r0,	%r4,	%r7
	sthx	%r0,	%r5,	%r7
	addi	%r7,	%r7,	2

memcpy8prep:
	subf	%r0,	%r7,	%r6
	cmpwi	%r0,	0
	ble		DCFlushRangePrep
memcpy8:
	lbzx	%r0,	%r4,	%r7
	stbx	%r0,	%r5,	%r7

DCFlushRangePrep:
	addi	%r0,	%r6,	0x1F
	srwi	%r0,	%r0,	5
	mtctr	%r0

	li		%r0,	0
DCFlushRange:
	dcbf	%r0,	%r5
	addi	%r5,	%r5,	0x20
	bdnz	DCFlushRange
	sync

	li		%r6,	0
FakeTransfer:
	lis		%r3,	AR_DMA_CNT@h
	stw		%r6,	AR_DMA_CNT@l(%r3)

	blr
