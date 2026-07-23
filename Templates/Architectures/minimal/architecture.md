**Minimal.** No architectural layering is imposed: a single application target
with sources under `App/`.

Start by putting types where they obviously belong and let the structure emerge
from what the app actually does. When a folder starts to feel crowded, split it
along the seam the code is already showing you rather than along a pattern
chosen in advance.

If you later want a named pattern — MVVM, MVVM-C, Clean — introduce it when
there is enough code to justify it, not before.
