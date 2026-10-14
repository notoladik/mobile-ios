#ifndef VK_CLIENT_DESIGN_GEOMETRY_H
#define VK_CLIENT_DESIGN_GEOMETRY_H
#include <math.h>

/* Kept independent of UIKit so the actual layout arithmetic can be tested. */
static inline int VKClientValidFirstTab(int value) { return value >= 0 && value <= 2 ? value : 0; }
static inline double VKClientValidMessageFont(double value) {
    return isfinite(value) && value >= 13.0 && value <= 19.0 ? value : 15.0;
}
static inline double VKClientHeaderTitleWidth(double width) { return fmax(0.0, width - 3.0 * 44.0 - 24.0); }
static inline double VKClientMessageTextWidth(double width, int avatars, int groupIncoming, int selecting) {
    double slot = avatars ? 58.0 : (groupIncoming ? 46.0 : 10.0);
    return fmax(40.0, width - 50.0 - slot - (selecting ? 32.0 : 0.0));
}
#endif
