#include "asm.h"
#include "memlayout.h"
#include "mmu.h"

# -----------------------------------------------------------------------------
# 启动流程概述：
# 1. BIOS 将本代码从硬盘第一个扇区加载到物理地址 0x7C00
# 2. 在 16 位实模式下初始化段寄存器、开启 A20 地址线
# 3. 加载全局描述符表（GDT），切换到 32 位保护模式
# 4. 设置保护模式下的段寄存器和栈指针
# 5. 跳转到 C 语言编写的 bootmain 函数继续执行
# -----------------------------------------------------------------------------


# Start the first CPU: switch to 32-bit protected mode, jump into C.
# The BIOS loads this code from the first sector of the hard disk into
# memory at physical address 0x7c00 and starts executing in real mode
# with %cs=0 %ip=7c00.

.code16                       # Assemble for 16-bit mode  告诉汇编器生成16位实模式代码
.globl start

# --------------------------
# 1. 实模式初始化
# --------------------------

start:
  cli                         # BIOS enabled interrupts; disable  BIOS默认开启中断，先关闭，方式初始化过程被打断

  # Zero data segment registers DS, ES, and SS.   初始化数据段寄存器（DS, ES, SS）为 0
  xorw    %ax,%ax             # Set %ax to zero  将 AX 寄存器清零
  movw    %ax,%ds             # -> Data Segment  设置数据段（DS）基地址为 0
  movw    %ax,%es             # -> Extra Segment  设置扩展段（ES）基地址为 0
  movw    %ax,%ss             # -> Stack Segment  设置栈段（SS）基地址为 0

  # Physical address line A20 is tied to zero so that the first PCs 
  # with 2 MB would run software that assumed 1 MB.  Undo that.

    # --------------------------
    # 2. 开启 A20 地址线
    # 早期 PC 为了兼容只支持 1MB 内存的软件，默认将第 21 根地址线（A20）拉低
    # 开启 A20 后才能访问 1MB 以上的内存空间
    # --------------------------

seta20.1:
  inb     $0x64,%al               # Wait for not busy
  testb   $0x2,%al
  jnz     seta20.1

  movb    $0xd1,%al               # 0xd1 -> port 0x64
  outb    %al,$0x64

seta20.2:
  inb     $0x64,%al               # Wait for not busy
  testb   $0x2,%al
  jnz     seta20.2

  movb    $0xdf,%al               # 0xdf -> port 0x60
  outb    %al,$0x60

    # --------------------------
    # 3. 切换到 32 位保护模式
    # --------------------------


  # Switch from real to protected mode.  Use a bootstrap GDT that makes
  # virtual addresses map directly to physical addresses so that the
  # effective memory map doesn't change during the transition.
  lgdt    gdtdesc
  movl    %cr0, %eax
  orl     $CR0_PE, %eax
  movl    %eax, %cr0

//PAGEBREAK!
  # Complete the transition to 32-bit protected mode by using a long jmp
  # to reload %cs and %eip.  The segment descriptors are set up with no
  # translation, so that the mapping is still the identity mapping.
  ljmp    $(SEG_KCODE<<3), $start32

# --------------------------
# 4. 32 位保护模式初始化
# --------------------------

.code32  # Tell assembler to generate 32-bit code now.
start32:
  # Set up the protected-mode data segment registers
  movw    $(SEG_KDATA<<3), %ax    # Our data segment selector
  movw    %ax, %ds                # -> DS: Data Segment
  movw    %ax, %es                # -> ES: Extra Segment
  movw    %ax, %ss                # -> SS: Stack Segment
  movw    $0, %ax                 # Zero segments not ready for use
  movw    %ax, %fs                # -> FS
  movw    %ax, %gs                # -> GS

  # Set up the stack pointer and call into C.
  movl    $start, %esp

  # --------------------------
  # 新增：精简版汇编打印
  # --------------------------
  movl    $0xB8000 + 24*80*2, %edx       # VGA 缓冲区地址
  movl    $msg_boot, %esi      # 字符串地址
  movb    $0x07, %ah           # 黑底灰字
print_boot:
  lodsb
  testb   %al, %al
  jz      print_boot_done
  movw    %ax, (%edx)
  addl    $2, %edx
  jmp     print_boot
print_boot_done:

  call    bootmain

  # If bootmain returns (it shouldn't), trigger a Bochs
  # breakpoint if running under Bochs, then loop.
  movw    $0x8a00, %ax            # 0x8a00 -> port 0x8a00
  movw    %ax, %dx
  outw    %ax, %dx
  movw    $0x8ae0, %ax            # 0x8ae0 -> port 0x8a00
  outw    %ax, %dx
spin:
  jmp     spin

# --------------------------
# 5. 全局描述符表（GDT）定义
# --------------------------

# Bootstrap GDT
.p2align 2                                # force 4 byte alignment
gdt:
  SEG_NULLASM                             # null seg
  SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)   # code seg
  SEG_ASM(STA_W, 0x0, 0xffffffff)         # data seg

gdtdesc:
  .word   (gdtdesc - gdt - 1)             # sizeof(gdt) - 1
  .long   gdt                             # address gdt

msg_boot: .asciz "[BOOT] Start"
