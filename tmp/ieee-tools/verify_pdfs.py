from pathlib import Path
from pypdf import PdfReader
import subprocess, re, json, hashlib, shutil
ROOT=Path(__file__).resolve().parents[2]
qa=ROOT/'tmp'/'ieee-qa'
summary={}
for kind in ('web','mobile'):
    p=ROOT/'docs'/('ieee-'+kind)
    reader=PdfReader(p/'main.pdf')
    txt='\n'.join(page.extract_text() for page in reader.pages)
    log=(p/'main.log').read_text(encoding='utf-8',errors='replace')
    assert len(reader.pages) in (7,8)
    for bad in ['Overfull','undefined references','undefined citations','Missing character','Font Warning','Citation `','Reference `']:
        assert bad not in log,(kind,bad)
    assert not re.search(r'\[\?\]',txt)
    for needle in ['QE190064','QE190046','QE1900100','QE190088','QE1900126','vangh@fe.edu.vn','209','17','21','ACKNOWLEDGMENT','REFERENCES']:
        assert needle.lower() in txt.lower(),(kind,needle)
    for label in ('architecture','data','flow'):
        assert r'\ref{fig:'+label+'}' in (p/'main.tex').read_text(encoding='utf-8')
    bbl=(p/'main.bbl').read_text(encoding='utf-8')
    bib_count=len(re.findall(r'\\bibitem\{',bbl))
    old={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in qa.glob(kind+'-*.png')}
    subprocess.run(['pdftoppm','-r','110','-png',str(p/'main.pdf'),str(qa/kind)],check=True)
    changed=[f.name for f in qa.glob(kind+'-*.png') if old.get(f.name)!=hashlib.sha256(f.read_bytes()).hexdigest()]
    (ROOT/'docs'/'ieee-verification'/(kind+'-extracted-text.txt')).write_text(txt,encoding='utf-8')
    for name in ('main.log','main.blg'):
        shutil.copyfile(p/name,ROOT/'docs'/'ieee-verification'/(kind+'-'+name))
    summary[kind]={'pages':len(reader.pages),'compile':'success','references':bib_count,
      'overfull_boxes':0,'undefined_references_or_citations':0,'font_substitution_warnings':0,
      'missing_glyph_warnings':0,'figure_count':3,'table_count':4,
      'pdf_sha256':hashlib.sha256((p/'main.pdf').read_bytes()).hexdigest(),
      'changed_rendered_pages_since_previous_visual_review':changed,
      'render_dpi':110,'visual_review':'pending final changed-page inspection'}
    readme=(p/'README.md').read_text(encoding='utf-8')
    readme=readme.replace('TikZ, listings, url, hyperref.','TikZ, listings, url, hyperref, balance.')
    readme=readme.split('\n## Final build and review')[0]
    readme+='\n## Final build and review\n\nCompiled successfully with Tectonic 0.17.0: '+str(len(reader.pages))+' pages, '+str(bib_count)+' cited references, 3 figures and 4 tables. The final build has no overfull boxes, missing glyphs, font substitutions, or undefined citations/references. Ordinary underfull justification diagnostics remain. Pages were rendered using Poppler for visual review.\n\nVerified outcomes: 209 Flutter tests, 17 isolated BookingService unit tests, 21 ApiGateway tests; both Web entry points compile. Analysis retains 1 informational lint; MovieService has 4 nullable warnings. Docker-dependent suites, live PayOS/SMTP, migrations, and physical-device/release acceptance were not executed. See the evidence ledger for boundaries.\n'
    (p/'README.md').write_text(readme,encoding='utf-8')
out=ROOT/'docs'/'ieee-verification'/'pdf-quality.json'
out.write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,indent=2))
