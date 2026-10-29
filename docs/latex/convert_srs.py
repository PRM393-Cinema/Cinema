"""Lossless, repository-specific Markdown -> standalone XeLaTeX conversion.

Only presentation is changed. Every source block/table cell is recorded in the
conversion manifest, and the Markdown files are never written.
"""
from __future__ import annotations

import hashlib
import html
import json
import re
from pathlib import Path

BASE = Path(__file__).resolve().parent
DOCS = BASE.parent
JOBS = [
    ("web-en", "Cinema_Web_NET_SRS_EN", False),
    ("web-vi", "Cinema_Web_NET_SRS_VI", True),
    ("mobile-en", "Cinema_Mobile_SRS_EN", False),
    ("mobile-vi", "Cinema_Mobile_SRS_VI", True),
]
SPECIAL = dict(zip("\\&%$#_{}~^", [r"\textbackslash{}", r"\&", r"\%", r"\$", r"\#", r"\_", r"\{", r"\}", r"\textasciitilde{}", r"\textasciicircum{}"] ))
SYMBOLS = {"✓": r"\ensuremath{\checkmark}", "→": r"\ensuremath{\rightarrow}", "↔": r"\ensuremath{\leftrightarrow}", "←": r"\ensuremath{\leftarrow}", "≥": r"\ensuremath{\geq}", "≤": r"\ensuremath{\leq}", "×": r"\ensuremath{\times}"}
TECH = re.compile(r"\b(?:(?:UC-)?(?:WEB|MOB)-(?:[A-Z]+-)*[A-Z0-9]+(?:-[A-Z0-9]+)*|(?:FR|BR|NFR)-[A-Z0-9-]+|[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+|[A-Z]{2,}(?:[A-Z0-9]+)?|[A-Za-z][A-Za-z0-9]*(?:[a-z][A-Z])[A-Za-z0-9]*|(?:400|401|403|404|409|429|500|503))\b")


def escape(s: str) -> str:
    return "".join(SYMBOLS.get(c, SPECIAL.get(c, c)) for c in s)


def mono(s: str) -> str:
    # Zero-width discretionary breaks preserve text while protecting narrow cells.
    chunks = []
    run = 0
    for i, c in enumerate(s):
        chunks.append(escape(c))
        run = run + 1 if c.isalnum() else 0
        camel = i + 1 < len(s) and c.islower() and s[i + 1].isupper()
        if c in "/_.-:,=+" or camel or run >= 8:
            chunks.append(r"\allowbreak{}")
            run = 0
    return r"\texttt{" + "".join(chunks) + "}"


def plain(s: str) -> str:
    out, pos = [], 0
    for m in TECH.finditer(s):
        out.extend([escape(s[pos:m.start()]).replace("/", r"/\allowbreak{}"), mono(m.group())])
        pos = m.end()
    return "".join(out) + escape(s[pos:]).replace("/", r"/\allowbreak{}")


def destination(url: str) -> str:
    if re.match(r"(?:https?://|mailto:|#)", url):
        return url
    # Resolve original links relative to docs/, then express from docs/latex/job/.
    return "../../" + url if not url.startswith("../") else "../../" + url


def inline(s: str) -> str:
    s = html.unescape(s)
    token = re.compile(r"`([^`]+)`|\[([^\]]+)\]\(([^)]+)\)|\*\*(.+?)\*\*|(?<!\*)\*([^*]+)\*(?!\*)")
    out, pos = [], 0
    for m in token.finditer(s):
        out.append(plain(s[pos:m.start()]))
        if m[1] is not None:
            out.append(mono(m[1]))
        elif m[2] is not None:
            label = mono(m[2]) if re.search(r"[/_]|\.(?:md|cs|dart|yml)", m[2]) else inline(m[2])
            out.append(r"\href{" + escape(destination(m[3])) + "}{" + label + "}")
        elif m[4] is not None:
            out.append(r"\textbf{" + inline(m[4]) + "}")
        else:
            out.append(r"\emph{" + inline(m[5]) + "}")
        pos = m.end()
    return "".join(out) + plain(s[pos:])


def blocks(text: str) -> list[dict]:
    lines = text.splitlines()
    result, i = [], 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        if line.startswith("```"):
            i += 1
            buf = []
            while i < len(lines) and not lines[i].startswith("```"):
                buf.append(lines[i])
                i += 1
            assert i < len(lines), "Unclosed code fence"
            result.append({"type": "code", "text": "\n".join(buf)})
            i += 1
        elif line.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                rows.append([x.strip() for x in lines[i].strip().strip("|").split("|")])
                i += 1
            assert len(rows) >= 2 and all(re.fullmatch(r":?-+:?", x) for x in rows[1]), "Invalid table separator"
            assert all(len(r) == len(rows[0]) for r in rows), "Mismatched table width"
            result.append({"type": "table", "header": rows[0], "rows": rows[2:]})
        elif m := re.match(r"^(#{1,6}) (.+)$", line):
            result.append({"type": "heading", "level": len(m[1]), "text": m[2]})
            i += 1
        else:
            buf = [line]
            i += 1
            while i < len(lines) and lines[i].strip() and not re.match(r"^(?:#|\||```)", lines[i]):
                buf.append(lines[i])
                i += 1
            result.append({"type": "paragraph", "text": "\n".join(buf)})
    return result


PREAMBLE = r"""% !TeX program = xelatex
% Generated from the unmodified Markdown source; see conversion-manifest.json.
\RequirePackage{fix-cm}
\documentclass[11pt,a4paper,oneside]{article}
\usepackage{fontspec}
\IfFontExistsTF{Times New Roman}{\setmainfont{Times New Roman}}{\setmainfont{TeX Gyre Termes}}
\IfFontExistsTF{Arial}{\setsansfont{Arial}}{\setsansfont{TeX Gyre Heros}}
\IfFontExistsTF{Consolas}{\setmonofont{Consolas}[Scale=MatchLowercase]}{\setmonofont{Latin Modern Mono}[Scale=MatchLowercase]}
\usepackage[margin=22mm,headheight=15pt,headsep=8mm,footskip=12mm]{geometry}
\usepackage{array,booktabs,longtable,tabularx}
\usepackage{amsmath,amssymb}
\usepackage{xcolor,graphicx,fancyvrb}
\usepackage{pdflscape}
\usepackage{fancyhdr,titlesec,needspace}
\usepackage[unicode,breaklinks,colorlinks=true,linkcolor=black,urlcolor=SRSlate]{hyperref}
\usepackage{bookmark}
\definecolor{SRSlate}{HTML}{263B50}
\definecolor{SRSRule}{HTML}{BAC4CE}
\hypersetup{pdftitle={@@PDFTITLE@@},pdfauthor={},pdfsubject={@@SUBJECT@@},bookmarksnumbered=true}
\renewcommand{\contentsname}{@@TOC@@}
\renewcommand{\listtablename}{@@LOT@@}
\renewcommand{\tablename}{@@TABLE@@}
\setcounter{tocdepth}{1}
\setcounter{secnumdepth}{2}
\setlength{\parindent}{0pt}
\setlength{\parskip}{6pt}
\setlength{\emergencystretch}{3em}
\tolerance=1600
\setlength{\LTpre}{6pt}
\setlength{\LTpost}{10pt}
\setlength{\LTleft}{0pt plus 1fill}
\setlength{\LTright}{0pt plus 1fill}
\setlength{\tabcolsep}{4pt}
\renewcommand{\arraystretch}{1.18}
\newcolumntype{P}[1]{>{\raggedright\arraybackslash\hspace{0pt}}p{#1}}
\newlength{\SRSWidth}
\titleformat{\section}{\Large\bfseries\color{SRSlate}}{\thesection.}{.6em}{}
\titleformat{\subsection}{\large\bfseries\color{SRSlate}}{\thesubsection}{.6em}{}
\titlespacing*{\section}{0pt}{18pt}{10pt}
\titlespacing*{\subsection}{0pt}{14pt}{7pt}
\pagestyle{fancy}
\fancyhf{}
\fancyhead[L]{\small\sffamily Cinema}
\fancyhead[R]{\small\sffamily @@RUNNING@@}
\fancyfoot[C]{\small\thepage}
\renewcommand{\headrulewidth}{.4pt}
\fvset{fontsize=\small,frame=single,framesep=7pt}
\begin{document}
\begin{titlepage}
\centering
\vspace*{32mm}
{\Large\sffamily\color{SRSlate}@@TITLE@@\par}
\vspace{14mm}
{\Huge\bfseries\color{SRSlate}@@PRODUCT@@\par}
\vspace{12mm}
{\color{SRSRule}\rule{.72\textwidth}{.7pt}\par}
\vfill
{\large @@VERSION@@ 3.0\par}
\vspace{4mm}
{\large 2026-10-28\par}
\vspace{20mm}
\end{titlepage}
\pagenumbering{roman}
"""


def render_table(b: dict, caption: str, number: int, vi: bool, outer_landscape: bool = False) -> str:
    cols = len(b["header"])
    # Wide matrices receive landscape A4 pages instead of tiny typography.
    landscape = not outer_landscape and (cols >= 6 or (cols == 5 and any(len(" ".join(r)) > 280 for r in b["rows"])))
    weights = {2: [.20, .80], 3: [.20, .58, .22], 4: [.20, .25, .25, .30], 5: [.19, .18, .15, .20, .28], 6: [.11, .22, .16, .18, .13, .20], 7: [.17, .13, .11, .14, .14, .14, .17]}.get(cols, [1 / cols] * cols)
    # Key/value rows need enough space for long translated field labels.
    if cols == 2 and len(b["rows"]) >= 10:
        weights = [.23, .77]
    spec = "@{}" + "".join(f"P{{{w:.5f}\\SRSWidth}}" for w in weights) + "@{}"
    header = " & ".join(r"\textbf{" + inline(x) + "}" for x in b["header"]) + r" \\"
    result = [r"\begin{landscape}" if landscape else "", r"\begingroup", r"\fontsize{9.5}{12}\selectfont", f"\\setlength{{\\SRSWidth}}{{\\dimexpr\\linewidth-{2 * (cols - 1)}\\tabcolsep\\relax}}", r"\begin{longtable}{" + spec + "}", r"\caption{" + inline(caption) + r"}\label{tab:srs-" + str(number) + r"}\\", r"\toprule", header, r"\midrule", r"\endfirsthead", r"\multicolumn{" + str(cols) + r"}{@{}l}{\small\itshape " + ("Bảng " if vi else "Table ") + r"\thetable{} — " + ("tiếp theo" if vi else "continued") + r"}\\[4pt]", r"\toprule", header, r"\midrule", r"\endhead", r"\midrule", r"\multicolumn{" + str(cols) + r"}{r@{}}{\footnotesize\itshape " + ("Còn tiếp ở trang sau" if vi else "Continued on next page") + r"}\\", r"\endfoot", r"\bottomrule", r"\endlastfoot"]
    for row in b["rows"]:
        result += [" & ".join(inline(x) for x in row) + r" \\[3pt]"]
    result += [r"\end{longtable}", r"\endgroup", r"\end{landscape}" if landscape else ""]
    return "\n".join(x for x in result if x) + "\n"


def convert(folder: str, stem: str, vi: bool) -> dict:
    src = DOCS / (stem + ".md")
    raw = src.read_bytes()
    text = raw.decode("utf-8-sig")
    parsed = blocks(text)
    top = [b["text"] for b in parsed if b["type"] == "heading" and b["level"] == 1]
    assert len(top) == 2
    target = BASE / folder
    sections = target / "sections"
    sections.mkdir(parents=True, exist_ok=True)
    pre = PREAMBLE
    substitutions = {"PDFTITLE": stem, "SUBJECT": top[0], "TITLE": top[0], "PRODUCT": top[1], "TOC": "Mục lục" if vi else "Contents", "LOT": "Danh mục bảng" if vi else "List of Tables", "TABLE": "Bảng" if vi else "Table", "RUNNING": ("Web .NET" if "Web_NET" in stem else "Mobile") + (" · Tiếng Việt" if vi else " · English"), "VERSION": "Phiên bản" if vi else "Version"}
    for key, val in substitutions.items():
        pre = pre.replace("@@" + key + "@@", escape(val))
    main = [pre]
    current, group, table_count, context = 0, [], 0, "Thông tin tài liệu" if vi else "Document metadata"
    inventory = []

    def flush() -> None:
        nonlocal group
        if not group:
            return
        if current in (13, 22):
            group.append(r"\end{landscape}")
        filename = f"{current:02d}-section.tex"
        (sections / filename).write_text("\n".join(group), encoding="utf-8")
        main.append(r"\input{sections/" + filename + "}")
        group = []

    for b in parsed:
        if b["type"] == "heading" and b["level"] == 1:
            continue  # Both original titles are printed verbatim on the cover.
        if b["type"] == "heading" and b["level"] == 2:
            flush()
            m = re.match(r"(\d+)\.\s*(.*)", b["text"])
            assert m and int(m[1]) == current + 1
            current += 1
            if current == 1:
                main += [r"\clearpage", r"\tableofcontents", r"\clearpage", r"\listoftables", r"\clearpage", r"\pagenumbering{arabic}"]
            context = b["text"]
            group += [r"\clearpage"]
            if current in (13, 22):
                group.append(r"\begin{landscape}")
            group.append(r"\section{" + inline(m[2]) + r"}\label{sec:srs-" + str(current) + "}")
        elif b["type"] == "heading":
            context = b["text"]
            group += [r"\Needspace{10\baselineskip}", r"\subsection{" + inline(b["text"]) + "}"]
        elif b["type"] == "table":
            table_count += 1
            inventory.append({"table": table_count, "section": current, "heading": context, "columns": len(b["header"]), "rows": len(b["rows"]), "cells_sha256": hashlib.sha256(json.dumps([b["header"], *b["rows"]], ensure_ascii=False).encode()).hexdigest()})
            group.append(render_table(b, context, table_count, vi, current in (13, 22)))
        elif b["type"] == "code":
            group += [r"\begin{Verbatim}", b["text"], r"\end{Verbatim}"]
        else:
            group += [inline(b["text"]), ""]
    flush()
    assert current == 28
    main.append(r"\end{document}")
    (target / "main.tex").write_text("\n".join(main) + "\n", encoding="utf-8")
    manifest = {"source": "../../" + stem + ".md", "source_sha256": hashlib.sha256(raw).hexdigest(), "sections": current, "headings": [b for b in parsed if b["type"] == "heading"], "blocks": len(parsed), "tables": inventory, "images": 0, "source_content_sha256": hashlib.sha256(json.dumps(parsed, ensure_ascii=False).encode()).hexdigest(), "output_pdf": stem + ".pdf"}
    (target / "conversion-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"folder": folder, "sections": current, "tables": table_count, "source_sha256": manifest["source_sha256"]}


if __name__ == "__main__":
    print(json.dumps([convert(*job) for job in JOBS], ensure_ascii=True, indent=2))
