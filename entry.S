# The xv6 kernel starts executing in this file. This file is linked with
# the kernel C code, so it can refer to kernel symbols such as main().
# The boot block (bootasm.S and bootmain.c) jumps to entry below.
        
# Multiboot header, for multiboot boot loaders like GNU Grub.
# http://www.gnu.org/software/grub/manual/multiboot/multiboot.html
#
 # Using GRUB 2, you can boot xv6 from a file stored in a
# Linux file system by copying kernel or kernelmemfs to /boot
# and then adding this menu entry:
#
# menuentry "xv6" {
# 	insmod ext2
# 	set root='(hd0,msdos1)'
# 	set kernel='/boot/kernel'
# 	echo "Loading ${kernel}..."
# 	multiboot ${kernel} ${kernel}
# 	boot
# }

# -----------------------------------------------------------------------------
# xv6 内核的汇编入口点，负责开启分页、设置栈，并跳转到 C 语言编写的 main()
# 这个文件和内核 C 代码链接在一起，所以可以直接引用 main() 等符号
# -----------------------------------------------------------------------------

#include "asm.h"
#include "memlayout.h"
#include "mmu.h"
#include "param.h"

# -----------------------------------------------------------------------------
# Multiboot 头部：给 GRUB 等 Multiboot 引导加载器识别
# 遵循 Multiboot 规范，让引导加载器正确加载 xv6 内核
# -----------------------------------------------------------------------------

# Multiboot header.  Data to direct multiboot loader.
.p2align 2  #强制4字节对齐
.text
.globl multiboot_header
multiboot_header:
  #define magic 0x1badb002
  #define flags 0
  .long magic
  .long flags
  .long (-magic-flags)

# -----------------------------------------------------------------------------
# ELF 入口点定义
# _start 是 ELF 文件默认的入口符号，这里指向 entry 的物理地址
# 因为此时虚拟内存还没开启，所以必须用物理地址
# -----------------------------------------------------------------------------

# By convention, the _start symbol specifies the ELF entry point.
# Since we haven't set up virtual memory yet, our entry point is
# the physical address of 'entry'.
.globl _start
_start = V2P_WO(entry)   #虚拟地址转换成物理地址

# Entering xv6 on boot processor, with paging off.

# -----------------------------------------------------------------------------
# 内核真正的入口：在 BSP（启动处理器）上执行，分页初始为关闭状态
# -----------------------------------------------------------------------------

.globl entry
entry:
  # Turn on page size extension for 4Mbyte pages

  # --------------------------
  # 汇编打印：直接操作 VGA 缓冲区
  # --------------------------
  movl    $0xB8000, %edx       # VGA 文本缓冲区物理地址
  movl    $str_entry, %esi     # 字符串地址
  movb    $0x07, %ah           # 字符属性（黑底灰字）
print_loop:
  lodsb                       # 从 esi 读取一个字符到 al
  testb   %al, %al            # 判断是否为字符串结束符
  jz      print_done          # 结束则退出
  movw    %ax, (%edx)         # 写入字符和属性到 VGA 缓冲区
  addl    $2, %edx            # 移动到下一个字符位置
  jmp     print_loop
print_done:

  movl    %cr4, %eax
  orl     $(CR4_PSE), %eax
  movl    %eax, %cr4
  # Set page directory
  movl    $(V2P_WO(entrypgdir)), %eax
  movl    %eax, %cr3
  # Turn on paging.
  movl    %cr0, %eax
  orl     $(CR0_PG|CR0_WP), %eax
  movl    %eax, %cr0

  # Set up the stack pointer.
  movl $(stack + KSTACKSIZE), %esp

  # Jump to main(), and switch to executing at
  # high addresses. The indirect call is needed because
  # the assembler produces a PC-relative instruction
  # for a direct jump.
  mov $main, %eax
  jmp *%eax

.comm stack, KSTACKSIZE

.section .rodata
str_entry:
    .asciz "[ENTRY] entering kernel entry\n"
