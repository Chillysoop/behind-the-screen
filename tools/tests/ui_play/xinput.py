"""Real input on an X display through XTest, the way a mouse and keyboard would send it.

    python3 xinput.py click X Y [hold_seconds]     left click (default hold 0.1 s, like a person)
    python3 xinput.py rclick X Y [hold_seconds]
    python3 xinput.py move X Y
    python3 xinput.py key NAME [NAME...]           X keysym names: Return, space, Tab, 1, F...
    python3 xinput.py scroll X Y N                 mouse wheel: N > 0 up, N < 0 down
    python3 xinput.py drag X1 Y1 X2 Y2 [button]

The display comes from $DISPLAY (default :91). Also importable: from xinput import X.
"""
import ctypes, os, sys, time


class X:
    def __init__(self, display=None):
        display = display or os.environ.get("DISPLAY", ":91")
        self.x11 = ctypes.cdll.LoadLibrary("libX11.so.6")
        self.xt = ctypes.cdll.LoadLibrary("libXtst.so.6")
        x11, xt = self.x11, self.xt
        x11.XOpenDisplay.restype = ctypes.c_void_p
        x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
        x11.XFlush.argtypes = [ctypes.c_void_p]
        x11.XStringToKeysym.restype = ctypes.c_ulong
        x11.XStringToKeysym.argtypes = [ctypes.c_char_p]
        x11.XKeysymToKeycode.restype = ctypes.c_ubyte
        x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
        xt.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
        xt.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
        xt.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
        self.d = x11.XOpenDisplay(display.encode())
        if not self.d:
            raise SystemExit("can't open display " + display)
        # A slow software-rendered game (1 or 2 frames a second) misses a press and release that
        # both land between two frames: XHOLD holds keys and buttons longer, and with it held that
        # long, key autorepeat goes off so a held key isn't pressed twice.
        self.hold = float(os.environ.get("XHOLD", "0") or 0)
        if self.hold > 0:
            x11.XAutoRepeatOff.argtypes = [ctypes.c_void_p]
            x11.XAutoRepeatOff(self.d)
            x11.XFlush(self.d)

    def move(self, x, y):
        self.xt.XTestFakeMotionEvent(self.d, -1, int(x), int(y), 0)
        self.x11.XFlush(self.d)

    def button(self, b, down):
        self.xt.XTestFakeButtonEvent(self.d, b, 1 if down else 0, 0)
        self.x11.XFlush(self.d)

    def click(self, x, y, hold=0.1, b=1, settle=0.0):
        hold = max(hold, self.hold)
        self.move(x, y)
        if settle:
            time.sleep(settle)
        self.button(b, True)
        time.sleep(hold)
        self.button(b, False)

    def key(self, name, hold=0.1):
        hold = max(hold, self.hold)
        kc = self.x11.XKeysymToKeycode(self.d, self.x11.XStringToKeysym(name.encode()))
        self.xt.XTestFakeKeyEvent(self.d, kc, 1, 0)
        self.x11.XFlush(self.d)
        time.sleep(hold)
        self.xt.XTestFakeKeyEvent(self.d, kc, 0, 0)
        self.x11.XFlush(self.d)

    def scroll(self, x, y, n):
        self.move(x, y)
        time.sleep(0.2)
        b = 4 if n > 0 else 5
        for _ in range(abs(n)):
            self.button(b, True)
            time.sleep(0.05)
            self.button(b, False)
            time.sleep(0.15)

    def drag(self, x1, y1, x2, y2, b=1):
        self.move(x1, y1)
        time.sleep(0.2)
        self.button(b, True)
        for i in range(1, 21):
            self.move(x1 + (x2 - x1) * i / 20, y1 + (y2 - y1) * i / 20)
            time.sleep(0.03)
        time.sleep(0.15)
        self.button(b, False)


if __name__ == "__main__":
    x = X()
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd in ("click", "rclick"):
        x.click(int(args[0]), int(args[1]), float(args[2]) if len(args) > 2 else 0.1, 1 if cmd == "click" else 3)
    elif cmd == "move":
        x.move(int(args[0]), int(args[1]))
    elif cmd == "key":
        for name in args:
            x.key(name)
            time.sleep(0.1)
    elif cmd == "scroll":
        x.scroll(int(args[0]), int(args[1]), int(args[2]))
    elif cmd == "drag":
        x.drag(*[int(a) for a in args[:4]], b=int(args[4]) if len(args) > 4 else 1)
    else:
        raise SystemExit(__doc__)
