#include "../common/stdio.h"

int main()
{
        int fd = 0;

        for (fd = 0; fd <= 1; ++fd) {
                fprintf(fd, "Hello %s\n", "world!");
                fprintf(fd, "Hex: 0x%3x\n", 0x1234);
                fprintf(fd, "Int: %d\n", 1234);
                fprintf(fd, "Int: %d\n", -1234);
                fprintf(fd, "Int: %d\n", 0);
        }
}
