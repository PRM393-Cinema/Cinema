from pathlib import Path
import shutil,re,json
ROOT=Path(__file__).resolve().parents[2]
out=ROOT/'docs'/'ieee-verification'
for kind in ('customer','admin'):
    name='flutter-web-'+kind+'-build.txt'
    shutil.copyfile(ROOT/'tmp'/'ieee-tools'/name,out/name)
    assert 'Built build' in (out/name).read_text(encoding='utf-8-sig',errors='replace')
for kind in ('web','mobile'):
    p=ROOT/'docs'/('ieee-'+kind)
    main=(p/'main.tex').read_text(encoding='utf-8')
    if kind=='web':
        extra=r'''
Both browser entry points also compiled successfully with
\code{flutter build web --no-pub --no-web-resources-cdn}; the admin build
selected \code{lib/main\_admin.dart} and base path \code{/admin/}.
These are compilation results, not browser-hosted acceptance tests.
'''
        main=main.replace('No application source\nwas changed to obtain the restored-package result.',
                          'No application source\nwas changed to obtain the restored-package result.\n'+extra)
    else:
        main=main.replace('No application source\nwas changed to obtain the restored-package result.',
                          'No application source\nwas changed to obtain the restored-package result.\nThe shared client also compiled for its two browser entry points;\nthis does not substitute for Android or iOS release verification.\n')
    # Include the observed client outcomes in the abstract without exceeding 250 words.
    if kind=='web':
        main=main.replace('Client verification outcomes are reported\nseparately from source implementation,',
                          'The Flutter suite passed 209 tests; both browser entry points compiled,\nand analysis retained one informational lint. These checks remain separate\nfrom source implementation,')
    else:
        main=main.replace('Docker-backed\nintegration was blocked,',
                          'The Flutter suite passed 209 tests, with one informational analysis lint.\nDocker-backed integration was blocked,')
    (p/'main.tex').write_text(main,encoding='utf-8')
    table=(p/'verification-table.tex').read_text(encoding='utf-8')
    if kind=='web':
        table=table.replace(r'Native release/device verification & NOT EXECUTED: no device acceptance run',
                            r'Customer/admin browser builds & PASS: both entry points compile')
    (p/'verification-table.tex').write_text(table,encoding='utf-8')
    for fig in ('architecture',):
        fp=p/'figures'/(fig+'.tex')
        s=fp.read_text(encoding='utf-8')
        s=s.replace('Verified deployment overview. The lower grouping names dependencies,\nnot a database-to-provider network connection; service code performs those calls.',
                    'Selected deployment overview. Requests enter the gateway; services\naccess their database contexts. The bottom box groups backend integrations.')
        fp.write_text(s,encoding='utf-8')
ledger=ROOT/'docs'/'ieee-evidence.md'
txt=ledger.read_text(encoding='utf-8')
txt += '\nBoth customer and admin Flutter Web release builds succeeded. Commands used `--no-pub --no-web-resources-cdn`; the admin target was `lib/main_admin.dart`, with `/admin/` base href and isolated `build/ieee-admin-verification` output. Raw build outputs are in `ieee-verification/`. Native release builds remain not executed.\n'
ledger.write_text(txt,encoding='utf-8')
print('Recorded both successful browser builds.')
