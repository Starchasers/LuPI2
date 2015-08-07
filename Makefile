CC=gcc
CFLAGS=-g
SRCDIR=src/c/

OBJ=$(SRCDIR)main.o

lupi: $(OBJ)
	$(CC) $(LFLAGS) $^ -o $@

$(OBJ): %.o: %.c
	$(CC) -c $(CFLAGS) $< -o $@
