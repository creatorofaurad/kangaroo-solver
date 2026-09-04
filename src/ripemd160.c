
#include <stdint.h>
#include <string.h>

#define ROL(x, n) (((x) << (n)) | ((x) >> (32 - (n))))

#define F1(x, y, z) ((x) ^ (y) ^ (z))
#define F2(x, y, z) (((x) & (y)) | (~(x) & (z)))
#define F3(x, y, z) (((x) | ~(y)) ^ (z))
#define F4(x, y, z) (((x) & (z)) | ((y) & ~(z)))
#define F5(x, y, z) ((x) ^ ((y) | ~(z)))

#define FF(a, b, c, d, e, x, s) {     (a) += F1((b), (c), (d)) + (x);     (a) = ROL((a), (s)) + (e);     (c) = ROL((c), 10); }
#define GG(a, b, c, d, e, x, s) {     (a) += F2((b), (c), (d)) + (x) + 0x5A827999UL;     (a) = ROL((a), (s)) + (e);     (c) = ROL((c), 10); }
#define HH(a, b, c, d, e, x, s) {     (a) += F3((b), (c), (d)) + (x) + 0x6ED9EBA1UL;     (a) = ROL((a), (s)) + (e);     (c) = ROL((c), 10); }
#define II(a, b, c, d, e, x, s) {     (a) += F4((b), (c), (d)) + (x) + 0x8F1BBCDCUL;     (a) = ROL((a), (s)) + (e);     (c) = ROL((c), 10); }
#define JJ(a, b, c, d, e, x, s) {     (a) += F5((b), (c), (d)) + (x) + 0xA953FD4EUL;     (a) = ROL((a), (s)) + (e);     (c) = ROL((c), 10); }

#define FFF(a, b, c, d, e, x, s) {     (a) += F5((b), (c), (d)) + (x) + 0x50A28BE6UL;     (a) = ROL((a), (s)) + (e);     (c) = ROL((c), 10); }
#define GGG(a, b, c, d, e, x, s) {     (a) += F4((b), (c), (d)) + (x) + 0x5C4DD124UL;     (a) = ROL((a), (s)) + (e);     (c) = ROL((c), 10); }
#define HHH(a, b, c, d, e, x, s) {     (a) += F3((b), (c), (d)) + (x) + 0x6D703EF3UL;     (a) = ROL((a), (s)) + (e);     (c) = ROL((c), 10); }
#define III(a, b, c, d, e, x, s) {     (a) += F2((b), (c), (d)) + (x) + 0x7A6D76E9UL;     (a) = ROL((a), (s)) + (e);     (c) = ROL((c), 10); }
#define JJJ(a, b, c, d, e, x, s) {     (a) += F1((b), (c), (d)) + (x);     (a) = ROL((a), (s)) + (e);     (c) = ROL((c), 10); }

void ripemd160_c(const uint8_t *msg, uint32_t len, uint8_t *out) {
    uint32_t h0 = 0x67452301UL, h1 = 0xEFCDAB89UL, h2 = 0x98BADCFEUL, h3 = 0x10325476UL, h4 = 0xC3D2E1F0UL;
    uint8_t buf[64] = {0};
    memcpy(buf, msg, len);
    buf[len] = 0x80;
    uint64_t bit_len = (uint64_t)len * 8;
    memcpy(buf + 56, &bit_len, 8);

    uint32_t x[16];
    for (int i = 0; i < 16; i++) {
        x[i] = (uint32_t)buf[i*4] | ((uint32_t)buf[i*4+1]<<8) | ((uint32_t)buf[i*4+2]<<16) | ((uint32_t)buf[i*4+3]<<24);
    }

    uint32_t a = h0, b = h1, c = h2, d = h3, e = h4;
    uint32_t aa = h0, bb = h1, cc = h2, dd = h3, ee = h4;

    /* Round 1 */
    FF(a, b, c, d, e, x[0], 11);
    FF(e, a, b, c, d, x[1], 14);
    FF(d, e, a, b, c, x[2], 15);
    FF(c, d, e, a, b, x[3], 12);
    FF(b, c, d, e, a, x[4], 5);
    FF(a, b, c, d, e, x[5], 8);
    FF(e, a, b, c, d, x[6], 7);
    FF(d, e, a, b, c, x[7], 9);
    FF(c, d, e, a, b, x[8], 11);
    FF(b, c, d, e, a, x[9], 13);
    FF(a, b, c, d, e, x[10], 14);
    FF(e, a, b, c, d, x[11], 15);
    FF(d, e, a, b, c, x[12], 6);
    FF(c, d, e, a, b, x[13], 7);
    FF(b, c, d, e, a, x[14], 9);
    FF(a, b, c, d, e, x[15], 8);

    /* Round 2 */
    GG(e, a, b, c, d, x[7], 7);
    GG(d, e, a, b, c, x[4], 6);
    GG(c, d, e, a, b, x[13], 8);
    GG(b, c, d, e, a, x[1], 13);
    GG(a, b, c, d, e, x[10], 11);
    GG(e, a, b, c, d, x[6], 9);
    GG(d, e, a, b, c, x[15], 7);
    GG(c, d, e, a, b, x[3], 15);
    GG(b, c, d, e, a, x[12], 7);
    GG(a, b, c, d, e, x[0], 12);
    GG(e, a, b, c, d, x[9], 15);
    GG(d, e, a, b, c, x[5], 9);
    GG(c, d, e, a, b, x[2], 11);
    GG(b, c, d, e, a, x[14], 7);
    GG(a, b, c, d, e, x[11], 13);
    GG(e, a, b, c, d, x[8], 12);

    /* Round 3 */
    HH(d, e, a, b, c, x[3], 11);
    HH(c, d, e, a, b, x[10], 13);
    HH(b, c, d, e, a, x[14], 6);
    HH(a, b, c, d, e, x[4], 7);
    HH(e, a, b, c, d, x[9], 14);
    HH(d, e, a, b, c, x[15], 9);
    HH(c, d, e, a, b, x[8], 13);
    HH(b, c, d, e, a, x[1], 15);
    HH(a, b, c, d, e, x[2], 14);
    HH(e, a, b, c, d, x[7], 8);
    HH(d, e, a, b, c, x[0], 13);
    HH(c, d, e, a, b, x[6], 6);
    HH(b, c, d, e, a, x[13], 5);
    HH(a, b, c, d, e, x[11], 12);
    HH(e, a, b, c, d, x[5], 7);
    HH(d, e, a, b, c, x[12], 5);

    /* Round 4 */
    II(c, d, e, a, b, x[1], 11);
    II(b, c, d, e, a, x[9], 12);
    II(a, b, c, d, e, x[11], 14);
    II(e, a, b, c, d, x[10], 15);
    II(d, e, a, b, c, x[0], 14);
    II(c, d, e, a, b, x[8], 15);
    II(b, c, d, e, a, x[12], 9);
    II(a, b, c, d, e, x[4], 8);
    II(e, a, b, c, d, x[13], 9);
    II(d, e, a, b, c, x[3], 14);
    II(c, d, e, a, b, x[7], 5);
    II(b, c, d, e, a, x[15], 6);
    II(a, b, c, d, e, x[14], 8);
    II(e, a, b, c, d, x[5], 6);
    II(d, e, a, b, c, x[6], 5);
    II(c, d, e, a, b, x[2], 12);

    /* Round 5 */
    JJ(b, c, d, e, a, x[4], 9);
    JJ(a, b, c, d, e, x[0], 15);
    JJ(e, a, b, c, d, x[5], 5);
    JJ(d, e, a, b, c, x[9], 11);
    JJ(c, d, e, a, b, x[7], 6);
    JJ(b, c, d, e, a, x[12], 8);
    JJ(a, b, c, d, e, x[2], 13);
    JJ(e, a, b, c, d, x[10], 12);
    JJ(d, e, a, b, c, x[14], 5);
    JJ(c, d, e, a, b, x[1], 12);
    JJ(b, c, d, e, a, x[3], 13);
    JJ(a, b, c, d, e, x[8], 14);
    JJ(e, a, b, c, d, x[11], 11);
    JJ(d, e, a, b, c, x[6], 8);
    JJ(c, d, e, a, b, x[15], 5);
    JJ(b, c, d, e, a, x[13], 6);

    /* Parallel Round 1 */
    FFF(aa, bb, cc, dd, ee, x[5], 8);
    FFF(ee, aa, bb, cc, dd, x[14], 9);
    FFF(dd, ee, aa, bb, cc, x[7], 9);
    FFF(cc, dd, ee, aa, bb, x[0], 11);
    FFF(bb, cc, dd, ee, aa, x[9], 13);
    FFF(aa, bb, cc, dd, ee, x[2], 15);
    FFF(ee, aa, bb, cc, dd, x[11], 15);
    FFF(dd, ee, aa, bb, cc, x[4], 5);
    FFF(cc, dd, ee, aa, bb, x[13], 7);
    FFF(bb, cc, dd, ee, aa, x[6], 7);
    FFF(aa, bb, cc, dd, ee, x[15], 8);
    FFF(ee, aa, bb, cc, dd, x[8], 11);
    FFF(dd, ee, aa, bb, cc, x[1], 14);
    FFF(cc, dd, ee, aa, bb, x[10], 14);
    FFF(bb, cc, dd, ee, aa, x[3], 12);
    FFF(aa, bb, cc, dd, ee, x[12], 6);

    /* Parallel Round 2 */
    GGG(ee, aa, bb, cc, dd, x[6], 9);
    GGG(dd, ee, aa, bb, cc, x[11], 13);
    GGG(cc, dd, ee, aa, bb, x[3], 15);
    GGG(bb, cc, dd, ee, aa, x[7], 7);
    GGG(aa, bb, cc, dd, ee, x[0], 12);
    GGG(ee, aa, bb, cc, dd, x[13], 8);
    GGG(dd, ee, aa, bb, cc, x[5], 9);
    GGG(cc, dd, ee, aa, bb, x[10], 11);
    GGG(bb, cc, dd, ee, aa, x[14], 7);
    GGG(aa, bb, cc, dd, ee, x[15], 7);
    GGG(ee, aa, bb, cc, dd, x[8], 12);
    GGG(dd, ee, aa, bb, cc, x[12], 7);
    GGG(cc, dd, ee, aa, bb, x[4], 6);
    GGG(bb, cc, dd, ee, aa, x[9], 15);
    GGG(aa, bb, cc, dd, ee, x[1], 13);
    GGG(ee, aa, bb, cc, dd, x[2], 11);

    /* Parallel Round 3 */
    HHH(dd, ee, aa, bb, cc, x[15], 9);
    HHH(cc, dd, ee, aa, bb, x[5], 7);
    HHH(bb, cc, dd, ee, aa, x[1], 15);
    HHH(aa, bb, cc, dd, ee, x[3], 11);
    HHH(ee, aa, bb, cc, dd, x[7], 8);
    HHH(dd, ee, aa, bb, cc, x[14], 6);
    HHH(cc, dd, ee, aa, bb, x[6], 6);
    HHH(bb, cc, dd, ee, aa, x[9], 14);
    HHH(aa, bb, cc, dd, ee, x[11], 12);
    HHH(ee, aa, bb, cc, dd, x[8], 13);
    HHH(dd, ee, aa, bb, cc, x[12], 5);
    HHH(cc, dd, ee, aa, bb, x[2], 14);
    HHH(bb, cc, dd, ee, aa, x[10], 13);
    HHH(aa, bb, cc, dd, ee, x[0], 13);
    HHH(ee, aa, bb, cc, dd, x[4], 7);
    HHH(dd, ee, aa, bb, cc, x[13], 5);

    /* Parallel Round 4 */
    III(cc, dd, ee, aa, bb, x[8], 15);
    III(bb, cc, dd, ee, aa, x[6], 5);
    III(aa, bb, cc, dd, ee, x[4], 8);
    III(ee, aa, bb, cc, dd, x[1], 11);
    III(dd, ee, aa, bb, cc, x[3], 14);
    III(cc, dd, ee, aa, bb, x[11], 14);
    III(bb, cc, dd, ee, aa, x[15], 6);
    III(aa, bb, cc, dd, ee, x[0], 14);
    III(ee, aa, bb, cc, dd, x[5], 6);
    III(dd, ee, aa, bb, cc, x[12], 9);
    III(cc, dd, ee, aa, bb, x[2], 12);
    III(bb, cc, dd, ee, aa, x[13], 9);
    III(aa, bb, cc, dd, ee, x[9], 12);
    III(ee, aa, bb, cc, dd, x[7], 5);
    III(dd, ee, aa, bb, cc, x[10], 15);
    III(cc, dd, ee, aa, bb, x[14], 8);

    /* Parallel Round 5 */
    JJJ(bb, cc, dd, ee, aa, x[12], 8);
    JJJ(aa, bb, cc, dd, ee, x[15], 5);
    JJJ(ee, aa, bb, cc, dd, x[10], 12);
    JJJ(dd, ee, aa, bb, cc, x[4], 9);
    JJJ(cc, dd, ee, aa, bb, x[1], 12);
    JJJ(bb, cc, dd, ee, aa, x[5], 5);
    JJJ(aa, bb, cc, dd, ee, x[8], 14);
    JJJ(ee, aa, bb, cc, dd, x[7], 6);
    JJJ(dd, ee, aa, bb, cc, x[6], 8);
    JJJ(cc, dd, ee, aa, bb, x[2], 13);
    JJJ(bb, cc, dd, ee, aa, x[13], 6);
    JJJ(aa, bb, cc, dd, ee, x[14], 5);
    JJJ(ee, aa, bb, cc, dd, x[0], 15);
    JJJ(dd, ee, aa, bb, cc, x[3], 13);
    JJJ(cc, dd, ee, aa, bb, x[9], 11);
    JJJ(bb, cc, dd, ee, aa, x[11], 11);

    uint32_t t = h1 + c + dd;
    h1 = h2 + d + ee;
    h2 = h3 + e + aa;
    h3 = h4 + a + bb;
    h4 = h0 + b + cc;
    h0 = t;

    memcpy(out, &h0, 4);
    memcpy(out + 4, &h1, 4);
    memcpy(out + 8, &h2, 4);
    memcpy(out + 12, &h3, 4);
    memcpy(out + 16, &h4, 4);
}
