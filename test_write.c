#include "user.h"

int main(void) {
    char msg1[] = "[USER] test_write: calling write syscall\n";
    char msg2[] = "hello from test_write\n";

    // 一次性调用 write 打印整行，而不是逐字符 printf
    write(1, msg1, sizeof(msg1)-1);
    write(1, msg2, sizeof(msg2)-1);

    exit();
}