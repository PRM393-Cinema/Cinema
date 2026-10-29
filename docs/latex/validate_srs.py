"""Verify source hashes, complete IDs, links, LaTeX logs and PDF text.

Run after build.ps1. Preview images are generated separately with pdftoppm.
"""
import collections
import hashlib
import html
import json
import re
import unicodedata
from pathlib import Path

from pypdf import PdfReader
from convert_srs import BASE, DOCS, JOBS, blocks


def normalize(text):
    # Font ToUnicode maps may select a Unicode hyphen/Greek question-mark
    # alias for an identical glyph. Compare semantics without these aliases.
    text = unicodedata.normalize("NFKC", text).replace("\u2010", "-").replace("\u00ad", "")
    return re.sub(r"\s+", "", text)


def prose(text):
    text = text.replace("\ua78f", "·")
    text = html.unescape(text)
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = text.replace("**", "").replace("`", "")
    return "".join(c for c in unicodedata.normalize("NFKC", text) if c.isalnum())


def validate():
    reports = []
    pattern = re.compile(r"(?:UC-)?(?:WEB|MOB)-(?:[A-Z]+-)*[A-Z0-9]+(?:-[A-Z0-9]+)*")
    for folder, stem, vi in JOBS:
        target = BASE / folder
        manifest = json.loads((target / "conversion-manifest.json").read_text(encoding="utf8"))
        raw = (DOCS / (stem + ".md")).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == manifest["source_sha256"], "Markdown changed"
        source = raw.decode("utf8")
        parsed = blocks(source)
        log = (target / (stem + ".log")).read_text(encoding="utf8", errors="replace")
        bad = re.findall(r"^.*(?:Overfull|Underfull|Missing character|undefined references|LaTeX Warning|Package \S+ Warning|Font Warning|Emergency stop).*$", log, re.M)
        assert not bad, (folder, bad)
        reader = PdfReader(target / (stem + ".pdf"))
        pages = [p.extract_text() or "" for p in reader.pages]
        pdftext = "\n".join(pages)
        assert "\ufffd" not in pdftext
        normalized = normalize(pdftext)
        missing_ids = [i for i in set(pattern.findall(source)) if normalize(i) not in normalized]
        assert not missing_ids, (folder, missing_ids)
        labels = re.findall(r"\\newlabel\{sec:srs-(\d+)\}", (target / (stem + ".aux")).read_text(encoding="utf8"))
        assert labels == [str(i) for i in range(1, 29)]
        links = []
        for m in re.finditer(r"\]\(([^)]+)\)", source):
            url = m[1]
            if not re.match(r"https?://|mailto:|#", url):
                assert (DOCS / url.split("#")[0]).resolve().exists(), url
                links.append(url)
        # Remove running furniture before joining page-spanning paragraphs.
        body_pages = []
        for text in pages:
            lines = text.splitlines()
            if lines and lines[0].startswith("Cinema "):
                lines = lines[1:]
            if lines and re.fullmatch(r"\d+|[ivxlcdm]+", lines[-1]):
                lines = lines[:-1]
            body_pages.append("\n".join(lines))
        flat_pdf = prose("\n".join(body_pages))
        values = []
        for b in parsed:
            if b["type"] == "paragraph":
                values.append(b["text"])
            elif b["type"] == "table":
                values.extend(c for row in [b["header"], *b["rows"]] for c in row)
        unmatched = [v for v in dict.fromkeys(values) if len(prose(v)) > 20 and prose(v) not in flat_pdf]
        assert not unmatched, (folder, "Source cells/paragraphs not found in PDF", unmatched)
        # A cell spanning pages contains a repeated header/footer; record it for
        # manual assessment rather than silently treating it as omitted content.
        selected = {"cover": 1, "contents": 3}
        for sec in [9, 12, 13, 22, 27, 28]:
            aux = (target / (stem + ".aux")).read_text(encoding="utf8")
            m = re.search(r"\\newlabel\{sec:srs-" + str(sec) + r"\}\{\{\d+\}\{(\d+)\}", aux)
            logical = int(m[1])
            for idx, page in enumerate(pages):
                if page.rstrip().endswith("\n" + str(logical)):
                    selected[f"section-{sec}"] = idx + 1
                    break
        reports.append({"document": stem, "folder": folder, "pages": len(pages), "sections": len(labels), "tables": len(manifest["tables"]), "source_sha256_unchanged": True, "technical_ids_verified": len(set(pattern.findall(source))), "source_links_verified": len(set(links)), "latex_warnings": bad, "pdf_replacement_characters": 0, "unique_source_cells_or_paragraphs": len(set(values)), "text_extraction_cells_requiring_review": unmatched, "preview_pages": selected})
        reader.close()
    (BASE / "validation-report.json").write_text(json.dumps(reports, ensure_ascii=False, indent=2) + "\n", encoding="utf8")
    print(json.dumps([{k: v for k, v in r.items() if k != "text_extraction_cells_requiring_review"} | {"text_review_count": len(r["text_extraction_cells_requiring_review"])} for r in reports], ensure_ascii=True, indent=2))


if __name__ == "__main__":
    validate()
