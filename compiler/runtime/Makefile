BIN = inference
SRC = main.c models/alexnet.c lib/onnc-runtime.c $(wildcard lib/operator/*.c)

CPPFLAGS = -I lib -I lib/operator
CFLAGS = -Wall -Wextra -std=c11
LDLIBS = -lm

INPUT = data/input.bin
WEIGHT = models/alexnet.bin

all: $(BIN)

run: $(BIN) $(INPUT) $(WEIGHT)
	./$^

$(BIN): $(SRC)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LDLIBS)

clean:
	$(RM) $(BIN)
