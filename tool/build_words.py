#!/usr/bin/env python3
"""data_src/*.txt -> assets/data/words.json

Satır biçimi: en|tr1;tr2|pos|topic|example_en|example_tr

Ek dosya data_src/extra_<seviye>.txt (isteğe bağlı), her satır:
  en|pos|ek_türkçe_anlamlar|eş_anlamlılar|zıt_anlamlılar   (listeler ; ile)
Ek anlamlar ana listenin sonuna eklenir; eş/zıt anlamlılar İngilizcedir.
'(verb)' / '(adj)' gibi parantezli ekler gösterimden çıkarılır, sadece benzersiz
kimlik için kullanılır.
"""
import json, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
LEVELS = ["a1", "a2", "b1", "b2", "c1", "c2"]
POS = {"n", "v", "adj", "adv", "pron", "prep", "conj", "num", "det", "int", "phr"}

def slug(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")

def split(s):
    return [a.strip() for a in s.split(";") if a.strip()]

words, seen, errors = [], set(), []
extras = {}  # (en, pos) -> (ek_tr, syn, ant)
for lvl in LEVELS:
    f = ROOT / "data_src" / f"extra_{lvl}.txt"
    if not f.exists():
        continue
    for ln, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) != 5:
            errors.append(f"{f.name}:{ln}: {len(parts)} sütun (5 olmalı)"); continue
        key = (parts[0].lower(), parts[1])
        if key in extras:
            errors.append(f"{f.name}:{ln}: '{parts[0]}' ({parts[1]}) iki kez var"); continue
        extras[key] = (lvl, ln, split(parts[2]), split(parts[3]), split(parts[4]))
used = set()
seen_en = {}  # (kelime, tür) -> ilk görüldüğü dosya; seviyeler arası tekrarı engeller
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
        key = (en.lower(), pos)
        if key in seen_en:
            errors.append(f"{f.name}:{ln}: '{en}' ({pos}) zaten {seen_en[key]} içinde var"); continue
        seen_en[key] = f.name
        wid = f"{lvl}_{slug(en)}_{pos}"
        if wid in seen:
            errors.append(f"{f.name}:{ln}: tekrar eden kelime '{en}' ({pos})"); continue
        seen.add(wid)
        syn, ant = [], []
        ex = extras.get(key)
        if ex:
            used.add(key)
            for a in ex[2]:
                if a.lower() not in {x.lower() for x in answers}:
                    answers.append(a)
            syn = [x for x in ex[3] if x.lower() != en.lower()]
            ant = ex[4]
        w = {"id": wid, "en": en, "tr": answers, "pos": pos, "level": lvl.upper(),
             "topic": topic, "exEn": ex_en, "exTr": ex_tr}
        if syn:
            w["syn"] = syn
        if ant:
            w["ant"] = ant
        words.append(w)

for key, ex in extras.items():
    if key not in used:
        errors.append(f"extra_{ex[0]}.txt:{ex[1]}: '{key[0]}' ({key[1]}) ana listede yok")

if errors:
    print("\n".join(errors)); sys.exit(1)
out = ROOT / "assets" / "data" / "words.json"
out.write_text(json.dumps(words, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
from collections import Counter
few = sum(1 for w in words if len(w["tr"]) < 4)
print(f"3'ten az diğer anlamı olan: {few}; eş anlamlısı olan: {sum(1 for w in words if 'syn' in w)}; zıt anlamlısı olan: {sum(1 for w in words if 'ant' in w)}")
print(len(words), "kelime ->", out.relative_to(ROOT), dict(Counter(w["level"] for w in words)))
