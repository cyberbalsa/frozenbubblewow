/* Offline frame sink for the reveal functions extracted from CStuff.xs. */
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { XRES = 640, YRES = 480, PIXELS = XRES * YRES };
typedef uint32_t Uint32;
typedef struct { int BytesPerPixel; void *palette; Uint32 Rmask, Gmask, Bmask; int Rshift, Gshift, Bshift; } Format;
typedef struct { void *pixels; int pitch; Format *format; } SDL_Surface;
static int x, y, i, j, step_number, choice1, choice2;
static unsigned char first[PIXELS];
static Uint32 dest[PIXELS], source[PIXELS];

static void fb__out_of_memory(void) { exit(1); }
static int rand_(double n) {
    if (n == 256) return 1 + (int)(n * rand() / (RAND_MAX + 1.0));
    if (n == 3) return choice2;
    return choice1;
}
static void synchro_before(SDL_Surface *s) { (void)s; }
static void synchro_after(SDL_Surface *s) {
    Uint32 *pixels = s->pixels;
    for (int p = 0; p < PIXELS; ++p)
        if (first[p] == 255 && pixels[p]) first[p] = step_number;
    ++step_number;
}

#include "transitions.inc"

int main(int argc, char **argv) {
    if (argc != 3) return 1;
    Format format = {4, NULL, 255, 65280, 16711680, 0, 8, 16};
    SDL_Surface screen = {dest, XRES * 4, &format}, image = {source, XRES * 4, &format};
    memset(first, 255, sizeof(first));
    for (int p = 0; p < PIXELS; ++p) source[p] = 0xff000000;
    const char *kind = argv[1];
    if (!strcmp(kind, "horizontal") || !strcmp(kind, "vertical")) {
        choice1 = !strcmp(kind, "horizontal") ? 1 : 2;
        store_effect(&screen, &image);
    } else if (!strcmp(kind, "bars")) bars_effect(&screen, &image);
    else if (!strcmp(kind, "squares")) squares_effect(&screen, &image);
    else if (!strncmp(kind, "circle-", 7)) {
        choice1 = !strcmp(kind, "circle-out") ? 1 : 2;
        circle_init();
        circle_effect(&screen, &image);
    } else {
        choice1 = 1;
        choice2 = !strcmp(kind, "points") ? 2 : 1;
        if (!strcmp(kind, "light") || !strcmp(kind, "dark")) {
            choice2 = 3;
            choice1 = !strcmp(kind, "light") ? 1 : 2;
            for (int p = 0; p < PIXELS; ++p) {
                unsigned char rgb[3];
                if (fread(rgb, 1, 3, stdin) != 3) return 1;
                source[p] |= rgb[0] | ((Uint32)rgb[1] << 8) | ((Uint32)rgb[2] << 16);
            }
        }
        plasma_init(argv[2]);
        plasma_effect(&screen, &image);
    }
    if (memchr(first, 255, PIXELS)) return 1;
    fputc(step_number, stdout);
    return fwrite(first, 1, PIXELS, stdout) == PIXELS ? 0 : 1;
}
