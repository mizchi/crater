#include <stdio.h>
#include <stdlib.h>

int moonbit_read_file_size(const char* path) {
    FILE* f = fopen(path, "rb");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    int size = (int)ftell(f);
    fclose(f);
    return size;
}

int moonbit_read_file_data(const char* path, char* buf, int buf_size) {
    FILE* f = fopen(path, "rb");
    if (!f) return -1;
    int read = (int)fread(buf, 1, buf_size, f);
    fclose(f);
    return read;
}
