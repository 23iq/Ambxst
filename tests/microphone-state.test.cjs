const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const mic = {};
const file = path.join(__dirname, '../modules/services/MicrophoneState.js');
if (fs.existsSync(file)) vm.runInNewContext(fs.readFileSync(file, 'utf8').replace(/^\.pragma library\s*/, ''), mic);
test('discovery establishes a baseline; only a subsequent mute change produces a notice', () => {
    assert.equal(typeof mic.observe, 'function');
    const source = {};
    let state = mic.observe(null, source, false, false);
    assert.equal(state.notify, false);
    state = mic.observe(state, source, true, true);
    assert.equal(state.notify, false);
    state = mic.observe(state, source, true, false);
    assert.equal(state.notify, true);
    state = mic.observe(state, source, true, false);
    assert.equal(state.notify, false);
});
test('device replacement and disappearance never claim a mute transition', () => {
    assert.equal(typeof mic.observe, 'function');
    let state = mic.observe(null, {}, true, true);
    state = mic.observe(state, {}, true, false);
    assert.equal(state.notify, false);
    state = mic.observe(state, null, false, false);
    assert.equal(state.notify, false);
});
