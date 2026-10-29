from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
for kind in ('web','mobile'):
    p=ROOT/'docs'/('ieee-'+kind)/'main.tex'
    t=p.read_text(encoding='utf-8')
    if not t.startswith(r'\ifdefined'):
        t=r'\ifdefined\XeTeXversion\RequirePackage[T1]{fontenc}\fi'+'\n'+t
    for prefix in ('showtimes','bookings'):
        for suffix in ('seats','summary','payment'):
            t=t.replace(r'\code{/'+prefix+r'/\{id\}/'+suffix+'}',
                        r'\code{/'+prefix+r'/}\allowbreak\code{\{id\}/'+suffix+'}')
    if kind=='mobile':
        t=t.replace(r'Session storage & \code{flutter\_secure\_storage}',
                    r'Session storage & \code{flutter\_secure\_}\allowbreak\code{storage}')
    p.write_text(t,encoding='utf-8')
print('Adjusted narrow route/package cells and XeTeX font encoding.')
