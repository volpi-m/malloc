#include <string.h>
#include <strings.h>
#include <stdarg.h>
#include <stdio.h>
#include <unistd.h>

void *my_malloc(size_t size);
void my_free(void *);
int my_align(size_t size, int alignment);
void *grow_heap(size_t size);
void dump_mem(void);
void dump_values(void);
size_t compute_block_size(void *);
void phex(size_t);
void pnbr_base(size_t, int, char *);

struct alloc_s {
    int is_free;
    struct alloc_s *next;
};

void print(char *str, ...)
{
    char buff[60] = {0};
    va_list va;

    va_start(va, str);
    vsprintf(buff, str, va);
    va_end(va);
    write(1, buff, strlen(buff));
}

void my_align_tests()
{
    write(1, "my_align tests:", 15);
    print("%d == 16\n", my_align(15, 8));
    print("%d == 16\n", my_align(16, 8));
    print("%d == 8\n", my_align(1, 8));
    print("%d == 48\n", my_align(45, 8));
    print("%d == 152\n\n", my_align(145, 8));
}

void grow_heap_tests()
{
    void *brk = grow_heap(my_align(7, 8));

    write(1, "grow_heap tests:\n", 17);
    // scanf("%d");
    // print("%lld, %lld\n", sbrk(0), brk);
    print("%lld == 24\n", (void*)sbrk(0) - brk);
    //scanf("%d");
    brk = grow_heap(my_align(45, 8));
    print("%lld == 64\n", (void*)sbrk(0) - brk);
    // print("%p\n", sbrk(0));
}

int main()
{
    //my_align_tests();
    //grow_heap_tests();
    char *hello = my_malloc(6);
    char *world = my_malloc(12);
    memset(hello, 0, 6);
    memset(world, 0, 12);
    strcat(hello, "hello");
    strcat(world, "world");
    print("%s %s\n", hello, world);

    print("%d\n", compute_block_size(hello - 16));
    print("%d\n", compute_block_size(world - 16));

    //pnbr_base(123456, 16, "0123456789ABCDEF");
    // for (int i = 0; i < 30; i++)
    //     my_malloc(i);
    // my_free(hello);
    // my_free(world);
    dump_values();
    dump_mem();

    // str = my_malloc(sizeof(char) * 15);
    // sprintf(buff, "%p\n%p\n%p\n\n", fst_brk, str, sbrk(0));
    // write(1, buff, strlen(buff));
    // bzero(buff, 60);

    // sprintf(buff, "%lld: %x\n\n", fst_brk, *fst_brk);
    // write(1, buff, strlen(buff));
    // bzero(buff, 60);

    // str = my_malloc(sizeof(char) * 31);
    // sprintf(buff, "%p\n%p\n%p\n\n", fst_brk, str, sbrk(0));
    // write(1, buff, strlen(buff));
    // bzero(buff, 60);

    // str = my_malloc(sizeof(char) * 17);
    // sprintf(buff, "%p\n%p\n%p\n\n", fst_brk, str, sbrk(0));
    // write(1, buff, strlen(buff));
    // bzero(buff, 60);

    // dump_mem();

    // sprintf(buff, "%d\n", sizeof(struct alloc_s));
    // write(1, buff, strlen(buff));
    //str = memset(str, 'c', 11);
    //str[11] = 0;
}
