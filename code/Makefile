TARGET = plato
CC = g++
CFLAGS = -Wall
LDFLAGS =

.PHONY: all clean

all: clean $(TARGET)

DEPS = $(wildcard *.h)
SRC = $(wildcard *.cpp)
OBJ = $(patsubst %.cpp, %.o, $(SRC))

$(TARGET): $(OBJ)
	$(CC) -o $@ $^ $(LDFLAGS)

%.o: %.cpp $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)

clean:
	rm -rf $(TARGET) $(OBJ)
