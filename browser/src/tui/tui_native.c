// Native terminal helpers for crater-browser TUI.
// Raw mode and tty probing are handled here; higher-level line I/O stays in MoonBit via mizchi/x/stdio.

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

static struct termios orig_termios;
static int raw_mode_enabled = 0;
static int tty_fd = -1;
static int tty_fd_opened = 0;

static int get_tty_fd(void) {
  if (tty_fd >= 0) return tty_fd;
  if (isatty(STDIN_FILENO)) {
    tty_fd = STDIN_FILENO;
    tty_fd_opened = 0;
  } else {
    tty_fd = open("/dev/tty", O_RDONLY);
    if (tty_fd >= 0) tty_fd_opened = 1;
  }
  return tty_fd;
}

int tui_enable_raw_mode(void) {
  if (raw_mode_enabled) return 0;
  int fd = get_tty_fd();
  if (fd < 0) return -1;
  if (tcgetattr(fd, &orig_termios) == -1) return -1;
  struct termios raw = orig_termios;
  raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
  raw.c_oflag &= ~(OPOST);
  raw.c_cflag |= CS8;
  raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
  raw.c_cc[VMIN] = 0;
  raw.c_cc[VTIME] = 1;
  if (tcsetattr(fd, TCSADRAIN, &raw) == -1) return -1;
  raw_mode_enabled = 1;
  return 0;
}

int tui_disable_raw_mode(void) {
  if (!raw_mode_enabled) return 0;
  int fd = get_tty_fd();
  if (fd >= 0) {
    tcsetattr(fd, TCSADRAIN, &orig_termios);
  }
  if (tty_fd_opened && tty_fd >= 0) {
    close(tty_fd);
    tty_fd = -1;
    tty_fd_opened = 0;
  }
  raw_mode_enabled = 0;
  return 0;
}

int tui_is_raw_mode(void) {
  return raw_mode_enabled;
}

int tui_get_terminal_cols(void) {
  struct winsize ws;
  if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == -1 || ws.ws_col == 0) return 80;
  return ws.ws_col;
}

int tui_get_terminal_rows(void) {
  struct winsize ws;
  if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == -1 || ws.ws_row == 0) return 24;
  return ws.ws_row;
}

int tui_read_byte(void) {
  int fd = get_tty_fd();
  if (fd < 0) return -1;
  unsigned char c;
  ssize_t n = read(fd, &c, 1);
  if (n <= 0) return -1;
  return (int)c;
}

void tui_write_bytes(const unsigned char* buf, int len) {
  write(STDOUT_FILENO, buf, len);
}

void tui_flush(void) {
  fflush(stdout);
}

int tui_is_tty(void) {
  if (isatty(STDIN_FILENO)) return 1;
  int fd = open("/dev/tty", O_RDONLY);
  if (fd >= 0) {
    close(fd);
    return 1;
  }
  return 0;
}

void tui_sleep_ms(int ms) {
  usleep(ms * 1000);
}
