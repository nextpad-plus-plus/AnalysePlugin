/* -------------------------------------
myDebug.h (macOS port) — no-op debug macros.

The Windows original routed the DBG macros to the CRT debug reporter. On macOS
the portable core only uses these for trace output, so we compile them out (the
same as the Windows release build's no-debug branch). Flip to NSLog here if a
trace is ever needed.
------------------------------------- */
#ifndef MYDEBUG_H
#define MYDEBUG_H

#define DBGDEF(par)
#define DBGNDEF(par) par

#define DBG0(msg)
#define DBG1(msg, arg1)
#define DBG2(msg, arg1, arg2)
#define DBG3(msg, arg1, arg2, arg3)
#define DBG4(msg, arg1, arg2, arg3, arg4)
#define DBGW0(msg)
#define DBGW1(msg, arg1)
#define DBGW2(msg, arg1, arg2)
#define DBGW3(msg, arg1, arg2, arg3)
#define DBGW4(msg, arg1, arg2, arg3, arg4)
#define DBGA0(msg)
#define DBGA1(msg, arg1)
#define DBGA2(msg, arg1, arg2)
#define DBGA3(msg, arg1, arg2, arg3)
#define DBGA4(msg, arg1, arg2, arg3, arg4)

#endif // MYDEBUG_H
