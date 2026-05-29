/* -------------------------------------
chardefines.h (macOS port) — element-count + narrow strlen helpers.
------------------------------------- */
#ifndef CHARDEFINES_H
#define CHARDEFINES_H

#include <cstring>

#define COUNTCHAR(ar) COUNT(ar, TCHAR)
#define COUNT(ar, ty) (sizeof(ar) / sizeof(ty))

// UTF-8 narrow string model on macOS.
#define generic_strlen strlen

#endif // CHARDEFINES_H
