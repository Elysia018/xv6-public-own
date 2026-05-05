#include "types.h"
#include "defs.h"
#include "syscall.h"


int sys_hello(void)
{
  cprintf("hello xv6\n");
  return 0;
}