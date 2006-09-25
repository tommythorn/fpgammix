#include <stdio.h>
int main(int argc, char **argv)
{
	int ch;
        int i = 0;
        printf("unsigned char blob[] = {\n\t");
        while ((ch = getchar()) >= 0)
                printf("0x%02x,%s", (unsigned char) ch, ++i == 16 ? i = 0, "\n\t" : "");
        printf("%s};\n", i != 0 ? "\n" : "");
        return 0;
}
