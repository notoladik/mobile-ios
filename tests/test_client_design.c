#include <assert.h>
#include <math.h>
#include <stdio.h>
#include "../Classes/Services/VKClientDesignGeometry.h"

static int cases;
static void pass(const char *name) { ++cases; printf("PASS %s\n", name); }
int main(void) {
    for (int i = -20; i <= 20; ++i) if (i < 0 || i > 2) assert(VKClientValidFirstTab(i) == 0);
    pass("invalid stored tab falls back to profile");
    for (int i = 0; i < 3; ++i) assert(VKClientValidFirstTab(i) == i);
    pass("all three starting tabs preserved");
    double bad[] = {NAN, INFINITY, -INFINITY, -1, 0, 12, 20, 1000};
    for (unsigned i = 0; i < sizeof(bad)/sizeof(*bad); ++i) assert(VKClientValidMessageFont(bad[i]) == 15);
    pass("invalid stored font is sanitized");
    double fonts[] = {13, 15, 17, 19};
    for (unsigned i = 0; i < sizeof(fonts)/sizeof(*fonts); ++i) assert(VKClientValidMessageFont(fonts[i]) == fonts[i]);
    pass("all offered font sizes supported");
    double widths[] = {240, 320, 375, 390, 414, 568, 667, 768};
    for (unsigned i = 0; i < sizeof(widths)/sizeof(*widths); ++i) {
        double w = widths[i], t = VKClientHeaderTitleWidth(w);
        assert(t >= 0 && 14 + t <= w - 132 - 6);
    }
    pass("title does not collide with three 44pt controls");
    for (unsigned i = 0; i < sizeof(widths)/sizeof(*widths); ++i) for (int a = 0; a <= 1; ++a)
        for (int g = 0; g <= 1; ++g) for (int s = 0; s <= 1; ++s) {
            double w = widths[i], text = VKClientMessageTextWidth(w, a, g, s);
            double avatar = a ? 58 : (g ? 46 : 10);
            assert(text >= 40 && text + avatar + 50 + (s ? 32 : 0) <= w);
        }
    pass("message width fits across screen sizes, avatars and selection modes");
    for (unsigned i = 0; i < sizeof(widths)/sizeof(*widths); ++i) for (int a = 0; a <= 1; ++a)
        assert(VKClientMessageTextWidth(widths[i], a, 0, 0) - VKClientMessageTextWidth(widths[i], a, 0, 1) == 32);
    pass("selection reserves its full 32pt slot");
    assert(VKClientMessageTextWidth(320, 0, 0, 0) - VKClientMessageTextWidth(320, 1, 0, 0) == 48);
    assert(VKClientMessageTextWidth(320, 0, 0, 0) - VKClientMessageTextWidth(320, 0, 1, 0) == 36);
    pass("avatar toggle gives the space back to text");
    assert(VKClientHeaderTitleWidth(0) == 0);
    assert(VKClientMessageTextWidth(0, 1, 1, 1) == 40);
    pass("degenerate bounds never produce negative widths");
    printf("%d client-design geometry tests passed\n", cases);
    return 0;
}
