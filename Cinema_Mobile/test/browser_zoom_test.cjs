const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

test('Browser zoom bypasses Flutter without cancelling the native action', () => {
  const window = new EventTarget();
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../web/browser_zoom.js'), 'utf8'), { window });
  let handled = 0;
  for (const type of ['wheel', 'keydown', 'keyup']) {
    window.addEventListener(type, (event) => { handled++; event.preventDefault(); });
  }
  for (const [type, properties, native] of [
    ['wheel', { ctrlKey: true }, true],
    ['wheel', { ctrlKey: false }, false],
    ...['keydown', 'keyup'].flatMap(type => [
      ...['+', '=', '-', '0'].map(key => [type, { ctrlKey: true, key }, true]),
      [type, { metaKey: true, key: '+' }, true],
      [type, { ctrlKey: true, key: 'c' }, false],
      [type, { ctrlKey: false, key: '-' }, false],
    ]),
  ]) {
    const previous = handled;
    const event = Object.assign(new Event(type, { cancelable: true }), properties);
    window.dispatchEvent(event);
    assert.equal(event.defaultPrevented, !native);
    assert.equal(handled - previous, native ? 0 : 1);
  }
  const html = fs.readFileSync(path.join(__dirname, '../web/index.html'), 'utf8');
  assert.ok(html.indexOf('src="browser_zoom.js"') < html.indexOf('src="flutter_bootstrap.js"'));
});
