from pathlib import Path
import json,re,hashlib,subprocess

ROOT=Path(__file__).resolve().parents[2]
quality=ROOT/'docs'/'ieee-verification'/'pdf-quality.json'
data=json.loads(quality.read_text(encoding='utf-8'))
for kind,record in data.items():
    record['visual_review']=f"All {record['pages']} final Poppler-rendered pages inspected; architecture, tables, listings, acknowledgment, and final reference columns checked."
    record['presentation_revision']='Wide architecture figure, compact author block, emphasized technical points, consistent tables, numbered syntax-colored listings.'
    p=ROOT/'docs'/('ieee-'+kind)
    t=(p/'main.tex').read_text(encoding='utf-8')
    before=(ROOT/'tmp'/'ieee-before-polish'/kind/'main.tex').read_text(encoding='utf-8')
    cite=lambda s:set(key.strip() for group in re.findall(r'\\cite\{([^}]+)\}',s) for key in group.split(','))
    assert cite(t)==cite(before),'Citation scope changed'
    assert len(re.findall(r'\\section\{',t))==9
    assert len(re.findall(r'\\begin\{table\}',t))==3
    for key in ('209','17','21'):
        assert key in t
    code=re.search(r'\\begin\{lstlisting\}[^\n]*\n(.*?)\\end\{lstlisting\}',t,re.S).group(1)
    original_code=re.search(r'\\begin\{lstlisting\}[^\n]*\n(.*?)\\end\{lstlisting\}',before,re.S).group(1)
    assert re.sub(r'\s','',code)==re.sub(r'\s','',original_code),'Listing tokens changed'
    assert record['pdf_sha256']==hashlib.sha256((p/'main.pdf').read_bytes()).hexdigest()
    readme=(p/'README.md').read_text(encoding='utf-8')
    readme=readme.replace('The user explicitly waived the unavailable DIKE format reference in favor of the supplied IEEE requirements.',
       'The initial draft followed the supplied IEEE requirements. The presentation revision consulted the subsequently supplied Dike.pdf for visual hierarchy only; its project content and technical claims were not imported.')
    readme=readme.replace('TikZ, listings, url, hyperref, balance.', 'TikZ, listings, xcolor, url, hyperref, balance.')
    readme+='''
## Presentation revision

- Compact centered title/author block retains all five student IDs and advisor details.
- A two-column vector architecture figure separates service/database ownership from named SMTP, RabbitMQ, and PayOS bindings, and shows BookingService-to-MovieService HTTP access.
- Selected technical paragraphs use bold labels and concise lists; table headers and verification statuses are emphasized.
- Source-equivalent code listings use line numbers and restrained syntax colors. Figure fills and rules use a consistent muted palette.
- Final column breaks keep the Web acknowledgment intact and the Mobile bibliography split between entries. Recheck those manual breaks after substantive content changes.

This revision does not rerun application tests or change their previously recorded results. The pre-revision files are preserved under `tmp/ieee-before-polish`.
'''
    (p/'README.md').write_text(readme,encoding='utf-8')
quality.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
ledger=ROOT/'docs'/'ieee-evidence.md'
ledger.write_text(ledger.read_text(encoding='utf-8')+'''
## Presentation revision after visual comparison

The user authorized revising both reports after supplying `D:/Downloads/Downloads/Dike.pdf`. That paper informed visual hierarchy only. The CosmoQ reports retain the same citation-key sets, nine numbered sections, original verification results, and source-equivalent listing tokens. The architecture was redrawn as a two-column vector figure with explicit service/database ownership and integration bindings; selected prose was reorganized without introducing new system capabilities. Final outputs: Web 7 pages, Mobile 8 pages. All 15 pages were rendered and visually inspected. Final TeX logs contain no overfull boxes, undefined citations/references, missing glyphs, or font substitution warnings. No application source was modified and no application tests were rerun for this layout-only revision.
''',encoding='utf-8')
print('Recorded final visual review, unchanged evidence scope, and listing equivalence.')
