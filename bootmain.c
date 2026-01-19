// Boot loader.
//
// Part of the boot block, along with bootasm.S, which calls bootmain().
// bootasm.S has put the processor into protected 32-bit mode.
// bootmain() loads an ELF kernel image from the disk starting at
// sector 1 and then jumps to the kernel entry routine.

#include "types.h"
#include "elf.h"
#include "x86.h"
#include "memlayout.h"


#include "param.h"
#include "mmu.h"
#include "proc.h"//my own addtion

#define SECTSIZE  512

void readseg(uchar*, uint, uint);

// -----------------------------------------------------------------------------
// bootmain：bootasm.S 跳转到的 C 语言入口，负责加载内核
// -----------------------------------------------------------------------------

void
bootmain(void)
{
  struct elfhdr *elf;  // ELF 文件头指针
  struct proghdr *ph, *eph;  //ELF程序段头指针
  void (*entry)(void);  //内核入口函数指针
  uchar* pa;            //物理地址指针

  // 1.  初始化ELF文件头指针，指向物理地址0x10000（临时缓冲区）
  elf = (struct elfhdr*)0x10000;  // scratch space

  // 2.  Read 1st page off disk   从磁盘读取ELF文件的4096字节（一页）搭配缓冲区
  readseg((uchar*)elf, 4096, 0);

  // 3.  Is this an ELF executable?   检查是否为合法的ELF可执行文件
  if(elf->magic != ELF_MAGIC)
    return;  // let bootasm.S handle error  不是ELF文件，返回让bootasm.S进入死循环

  // 4.  Load each program segment (ignores ph flags).  遍历所有ELF程序段，加载到内存
  ph = (struct proghdr*)((uchar*)elf + elf->phoff);  //程序段头表起始地址
  eph = ph + elf->phnum;                             //程序段头表结束地址
  for(; ph < eph; ph++){
    pa = (uchar*)ph->paddr;                          //段加载到的物理地址
    readseg(pa, ph->filesz, ph->off);                //读取段的文件内容到内存
    if(ph->memsz > ph->filesz)    //如果段的内存大小 > 文件大小，用0填充剩余部分
      stosb(pa + ph->filesz, 0, ph->memsz - ph->filesz);
  }

 // 5. 跳转到内核入口点

  // Call the entry point from the ELF header.
  // Does not return!

  entry = (void(*)(void))(elf->entry);  //从ELF头中获取入口地址
  entry();                              //调用内核入口，不会返回
}

// -----------------------------------------------------------------------------
// waitdisk：等待磁盘准备就绪
// -----------------------------------------------------------------------------

void
waitdisk(void)
{
  // Wait for disk ready.   读取磁盘状态端口 0x1F7，直到状态为 0x40（就绪）
  while((inb(0x1F7) & 0xC0) != 0x40)
    ;
}

// -----------------------------------------------------------------------------
// readsect：从磁盘读取一个扇区到指定内存地址
// -----------------------------------------------------------------------------

// Read a single sector at offset into dst.
void
readsect(void *dst, uint offset)
{
  // Issue command.  // 1. 发送读扇区命令到磁盘控制器
  waitdisk();
  outb(0x1F2, 1);   // count = 1  读取扇区数量：1
  outb(0x1F3, offset);
  outb(0x1F4, offset >> 8);
  outb(0x1F5, offset >> 16);
  outb(0x1F6, (offset >> 24) | 0xE0);
  outb(0x1F7, 0x20);  // cmd 0x20 - read sectors  0x20表示“读扇区”命令

  // Read data.  读取扇区数据到内存
  waitdisk();
  insl(0x1F0, dst, SECTSIZE/4);  //一次读4字节，共512/4=128次
}

// -----------------------------------------------------------------------------
// readseg：从磁盘读取 count 字节到物理地址 pa，从 offset 开始
// -----------------------------------------------------------------------------

// Read 'count' bytes at 'offset' from kernel into physical address 'pa'.
// Might copy more than asked.
void
readseg(uchar* pa, uint count, uint offset)
{
  uchar* epa;

  epa = pa + count;  //读取结束地址

  // Round down to sector boundary.   1.将起始地址向下对齐到扇区边界
  pa -= offset % SECTSIZE;

  // Translate from bytes to sectors; kernel starts at sector 1.   2.将字节偏移转换为扇区号（内核从扇区1开始）
  offset = (offset / SECTSIZE) + 1;

  //逐扇区读取，直到覆盖整个目标区域
  // If this is too slow, we could read lots of sectors at a time.
  // We'd write more to memory than asked, but it doesn't matter --
  // we load in increasing order.
  for(; pa < epa; pa += SECTSIZE, offset++)
    readsect(pa, offset);
}
