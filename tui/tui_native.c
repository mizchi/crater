// TUI native C stub for terminal I/O
// Provides raw mode, terminal size, and non-blocking I/O

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <errno.h>

// Store original terminal settings for restoration
static struct termios orig_termios;
static int raw_mode_enabled = 0;

// Enable raw mode for character-by-character input
int tui_enable_raw_mode(void) {
    if (raw_mode_enabled) return 0;

    if (!isatty(STDIN_FILENO)) return -1;

    if (tcgetattr(STDIN_FILENO, &orig_termios) == -1) return -1;

    struct termios raw = orig_termios;
    // Input: no break, no CR to NL, no parity check, no strip, no flow control
    raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
    // Output: disable post processing
    raw.c_oflag &= ~(OPOST);
    // Control: set 8 bit chars
    raw.c_cflag |= (CS8);
    // Local: no echo, no canonical, no extended, no signal chars
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
    // Return each byte, no timeout
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 1; // 100ms timeout

    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == -1) return -1;

    raw_mode_enabled = 1;
    return 0;
}

// Disable raw mode and restore original settings
int tui_disable_raw_mode(void) {
    if (!raw_mode_enabled) return 0;

    if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios) == -1) return -1;

    raw_mode_enabled = 0;
    return 0;
}

// Check if raw mode is enabled
int tui_is_raw_mode(void) {
    return raw_mode_enabled;
}

// Get terminal size (columns, rows)
int tui_get_terminal_cols(void) {
    struct winsize ws;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == -1 || ws.ws_col == 0) {
        return 80; // default
    }
    return ws.ws_col;
}

int tui_get_terminal_rows(void) {
    struct winsize ws;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == -1 || ws.ws_row == 0) {
        return 24; // default
    }
    return ws.ws_row;
}

// Read a single byte from stdin (non-blocking in raw mode)
// Returns -1 if no data available, or the byte value (0-255)
int tui_read_byte(void) {
    unsigned char c;
    ssize_t n = read(STDIN_FILENO, &c, 1);
    if (n <= 0) return -1;
    return (int)c;
}

// Read up to max_len bytes into buffer
// Returns number of bytes read, or -1 on error
int tui_read_bytes(unsigned char* buf, int max_len) {
    ssize_t n = read(STDIN_FILENO, buf, max_len);
    if (n < 0) return -1;
    return (int)n;
}

// Write string to stdout without newline
void tui_print_raw(const char* str, int len) {
    write(STDOUT_FILENO, str, len);
}

// Flush stdout
void tui_flush(void) {
    fflush(stdout);
}

// Check if stdin is a TTY
int tui_is_tty(void) {
    return isatty(STDIN_FILENO);
}

// Sleep for milliseconds
void tui_sleep_ms(int ms) {
    usleep(ms * 1000);
}
