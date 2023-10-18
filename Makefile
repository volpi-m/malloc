NAME		=		libmy_malloc.so

SRC			=		src/my_malloc.asm		\
					src/print.asm

DEBUG_SRC	=		src/main.c

OBJ			=		$(SRC:.asm=.o)

DEBUG_OBJ	=		$(DEBUG_SRC:.c=.o)

CFLAGS		+=		-W -Wall -Wextra -g -Iinclude

ASMFLAGS	=		-f elf64

all:				$(NAME)

%.o:				%.asm
					nasm $(ASMFLAGS) -o $@ $<

%.o:				%.c
					gcc -c --no-builtin -o $@ $< $(CFLAGS)

$(NAME):			$(OBJ)
					ld -o $(NAME) -shared $(OBJ)

debug:				$(OBJ) $(DEBUG_OBJ)
					gcc -o debug $(OBJ) $(DEBUG_OBJ) $(CFLAGS)
#					gdb debug

clean:
					rm -f $(OBJ)
					rm -f $(DEBUG_OBJ)

fclean:				clean
					rm -f $(NAME)
					rm -f debug

re:					fclean clean all

.PHONY:				re all fclean clean
