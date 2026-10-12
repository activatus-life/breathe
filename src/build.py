"""Builds index.html: one self-contained file with screenshots, schema data and migrations inlined."""
import base64, html, json, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
bundle = root / 'src/bundle'
content = (root / 'src/content.html').read_text()

for image in (root / 'screens').glob('*.jpg'):
    data = base64.b64encode(image.read_bytes()).decode()
    content = content.replace('{{img:%s}}' % image.stem, 'data:image/jpeg;base64,' + data)

files = sorted((bundle / 'supabase/migrations').glob('*.sql')) + [
    bundle / 'supabase/seed.sql', bundle / 'src/types/databaseTypes.ts', bundle / 'package.scripts.json']
blocks = []
for path in files:
    label = str(path.relative_to(bundle))
    blocks.append(f'<details><summary>{label}</summary><pre><code>{html.escape(path.read_text())}</code></pre></details>')
content = content.replace('{{migrations}}', '\n'.join(blocks))

schema = (pathlib.Path(__file__).resolve().parent / 'schema.json').read_text()
page = (root / 'src/template.html').read_text().replace('{{content}}', content).replace('{{schema}}', schema)
assert '{{' not in page, 'unfilled placeholder'
(root / 'index.html').write_text(page)
print('index.html', round(len(page) / 1024), 'KB')
