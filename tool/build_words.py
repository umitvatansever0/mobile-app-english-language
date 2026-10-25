#!/usr/bin/env python3
"""data_src/*.txt -> assets/data/words.json

Satır biçimi: en|tr1;tr2|pos|topic|example_en|example_tr
'(verb)' / '(adj)' gibi parantezli ekler gösterimden çıkarılır, sadece benzersiz
kimlik için kullanılır.
"""
import json, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
LEVELS = ["a1", "a2", "b1", "b2", "c1"]
POS = {"n", "v", "adj", "adv", "pron", "prep", "conj", "num", "det", "int", "phr"}

def slug(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")

words, seen, errors = [], set(), []
for lvl in LEVELS:
    f = ROOT / "data_src" / f"{lvl}.txt"
    if not f.exists():
        continue
    for ln, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) != 6:
            errors.append(f"{f.name}:{ln}: {len(parts)} sütun (6 olmalı)"); continue
        en_raw, tr, pos, topic, ex_en, ex_tr = parts
        if pos not in POS:
            errors.append(f"{f.name}:{ln}: bilinmeyen tür '{pos}'"); continue
        en = re.sub(r"\s*\((verb|adj|noun)\)$", "", en_raw)
        answers = [a.strip() for a in tr.split(";") if a.strip()]
        wid = f"{lvl}_{slug(en)}_{pos}"
        if wid in seen:
            errors.append(f"{f.name}:{ln}: tekrar eden kelime '{en}' ({pos})"); continue
        seen.add(wid)
        words.append({"id": wid, "en": en, "tr": answers, "pos": pos, "level": lvl.upper(),
                      "topic": topic, "exEn": ex_en, "exTr": ex_tr})

if errors:
    print("\n".join(errors)); sys.exit(1)
out = ROOT / "assets" / "data" / "words.json"
out.write_text(json.dumps(words, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
from collections import Counter
print(len(words), "kelime ->", out.relative_to(ROOT), dict(Counter(w["level"] for w in words)))
