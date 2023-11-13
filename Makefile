# Keep it simple
all:
	@gcc -o priv/sniff c_src/sniff.c -lpcap -lpthread
	@echo "Compiling 1 file (.c)"
clean:
	@rm -rf priv/*

.PHONY: all clean
