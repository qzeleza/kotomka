TARGET = @APP_NAME
CC = gcc
CFLAGS = -Wall
LDFLAGS =

.PHONY: all clean

all: clean $(TARGET)

DEPS = $(wildcard *.h)
SRC = $(wildcard *.c)
OBJ = $(patsubst %.c, %.o, $(SRC))

$(TARGET): $(OBJ)
	$(CC) -o $@ $^ $(LDFLAGS)

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)

clean:
	rm -rf $(TARGET) $(OBJ)
