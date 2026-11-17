"""Prints line coverage per file from coverage/lcov.info, lowest first.

Run after `flutter test --coverage`:  python3 tool/coverage_summary.py
Generated files (*.g.dart) are left out.
"""
import collections

files = collections.OrderedDict()
current = None
for line in open("coverage/lcov.info"):
    line = line.strip()
    if line.startswith("SF:"):
        current = line[3:]
        files[current] = [0, 0, []]
    elif line.startswith("DA:"):
        number, hits = line[3:].split(",")[:2]
        files[current][1] += 1
        if int(hits) > 0:
            files[current][0] += 1
        else:
            files[current][2].append(int(number))


def ranges(numbers):
    out, start, prev = [], None, None
    for n in numbers:
        if start is None:
            start = prev = n
        elif n == prev + 1:
            prev = n
        else:
            out.append((start, prev))
            start = prev = n
    if start is not None:
        out.append((start, prev))
    return " ".join(f"{a}-{b}" if a != b else str(a) for a, b in out)


hit = total = 0
rows = []
for name, (h, t, missed) in files.items():
    if name.endswith(".g.dart") or t == 0:
        continue
    hit += h
    total += t
    rows.append((h / t, name, h, t, missed))

for ratio, name, h, t, missed in sorted(rows):
    if ratio < 1:
        print(f"{ratio * 100:5.1f}% {h:4d}/{t:<4d} {name}  {ranges(missed)}")
full = sum(1 for r in rows if r[0] == 1)
print(f"TOTAL {hit}/{total} = {hit / total * 100:.1f}%  "
      f"files={len(rows)}  fully covered={full}")
