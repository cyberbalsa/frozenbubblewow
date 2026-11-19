/* Offline adapter for Frozen Bubble's CStuff.xs rotate_bicubic_ routine.
 * Supply the tightly packed 32-bit RGBA surfaces that its SDL calls access. */
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef uint8_t Uint8;
typedef uint32_t Uint32;
typedef struct { int BytesPerPixel; } PixelFormat;
typedef struct { int w, h; Uint32 *pixels; PixelFormat *format; } SDL_Surface;
#define CLAMP(x, lo, hi) ((x) > (hi) ? (hi) : ((x) < (lo) ? (lo) : (x)))
#define myLockSurface(surface) ((void)0)
#define myUnlockSurface(surface) ((void)0)
static int x, y;

static void SDL_GetRGBA(Uint32 pixel, PixelFormat *format, Uint8 *r, Uint8 *g, Uint8 *b, Uint8 *a) {
    const Uint8 *bytes = (const Uint8 *)&pixel;
    *r = bytes[0]; *g = bytes[1]; *b = bytes[2]; *a = bytes[3];
}

static void set_pixel(SDL_Surface *surface, int px, int py, Uint8 r, Uint8 g, Uint8 b, Uint8 a) {
    const Uint8 bytes[4] = {r, g, b, a};
    memcpy(&surface->pixels[py * surface->w + px], bytes, sizeof(bytes));
}

#include "rotation.inc"

#ifndef CANNON_WIDTH
#define CANNON_WIDTH 100
#endif

int main(void) {
    enum { width = CANNON_WIDTH, count = width * width };
    PixelFormat format = {4};
    Uint32 input[count], output[count];
    SDL_Surface source = {width, width, input, &format}, dest = {width, width, output, &format};
    if (fread(input, sizeof(Uint32), count, stdin) != count) return 1;
    for (int angle = -100; angle <= 100; angle++) {
        rotate_bicubic_(&dest, &source, angle * (acos(-1.0) / 2.0) / 100.0);
        if (fwrite(output, sizeof(Uint32), count, stdout) != count) return 1;
    }
    return 0;
}
