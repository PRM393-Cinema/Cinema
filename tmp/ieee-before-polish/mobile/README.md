# CosmoQ Cinema — Mobile IEEE report

This independent paper uses `IEEEtran` conference format. `main.tex` is the entry point;
`references.bib` contains IEEE references; `figures/*.tex` are reproducible TikZ diagrams.
All source references use repository snapshot `55642353331f7119c16d4fef05f54bfc559cae8b` and database snapshot `e455d297c76b14e3fd6aa8c0af4bb11f77ec6a2b`.
The user explicitly waived the unavailable DIKE format reference in favor of the supplied IEEE requirements.

## Compile

From this directory, run either:

```powershell
tectonic --keep-logs --keep-intermediates main.tex
```

or, with a full TeX installation:

```powershell
pdflatex -interaction=nonstopmode -halt-on-error main.tex
bibtex main
pdflatex -interaction=nonstopmode -halt-on-error main.tex
pdflatex -interaction=nonstopmode -halt-on-error main.tex
```

The parent `ieee-common-build.ps1` builds both reports. An isolated Tectonic executable
was downloaded under `tmp/ieee-tools`; it is a report-generation tool, not an app dependency.
Required TeX packages: IEEEtran, fontenc, cite, amsmath, amssymb, graphicx, booktabs,
array, tabularx, TikZ, listings, url, hyperref, balance. No shell escape is needed.

See `../ieee-evidence.md` for claim-to-source mapping and review limitations.
Verification results are bounded by the documented environment and test doubles.

## Final build and review

Compiled successfully with Tectonic 0.17.0: 7 pages, 17 cited references, 3 figures and 4 tables. The final build has no overfull boxes, missing glyphs, font substitutions, or undefined citations/references. Ordinary underfull justification diagnostics remain. Pages were rendered using Poppler for visual review.

Verified outcomes: 209 Flutter tests, 17 isolated BookingService unit tests, 21 ApiGateway tests; both Web entry points compile. Analysis retains 1 informational lint; MovieService has 4 nullable warnings. Docker-dependent suites, live PayOS/SMTP, migrations, and physical-device/release acceptance were not executed. See the evidence ledger for boundaries.
