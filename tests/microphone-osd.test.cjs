const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const volume = {};
const file = path.join(__dirname, '../modules/shell/osd/MicrophoneVolume.js');
if (fs.existsSync(file)) vm.runInNewContext(fs.readFileSync(file, 'utf8').replace(/^\.pragma library\s*/, ''), volume);

test('startup and repeated volume samples do not open the microphone OSD', () => {
    assert.equal(typeof volume.observe, 'function');
    const node = {};
    let state = volume.observe(null, node, 0.5, true);
    assert.equal(state.show, false);
    // Audio emits the same volume on both mute and unmute.
    state = volume.observe(state, node, 0.5, true);
    assert.equal(state.show, false);
    assert.equal(volume.observe(state, node, 0.5, true).show, false);
});

test('actual volume changes open the OSD regardless of mute state', () => {
    assert.equal(typeof volume.observe, 'function');
    const node = {};
    let state = volume.observe(null, node, 0.5, true);
    state = volume.observe(state, node, 0.6, true);
    assert.equal(state.show, true);
    assert.equal(volume.observe(state, node, 0.6, true).show, false);
    assert.equal(volume.observe(state, node, 0, true).show, true);
});

test('replacement and unavailable devices start a fresh baseline', () => {
    assert.equal(typeof volume.observe, 'function');
    const first = {}, replacement = {};
    let state = volume.observe(null, first, 0.5, true);
    state = volume.observe(state, replacement, 0.8, true);
    assert.equal(state.show, false);
    assert.equal(volume.observe(state, replacement, 0.9, true).show, true);
    state = volume.observe(state, replacement, 0.8, false);
    assert.equal(state.show, false);
    assert.equal(volume.observe(state, replacement, 0.9, true).show, false);
});

test('invalid samples cannot produce a volume notice', () => {
    assert.equal(typeof volume.observe, 'function');
    const node = {};
    for (const invalid of [NaN, Infinity, undefined]) {
        const state = volume.observe(null, node, invalid, true);
        assert.equal(state.show, false);
        assert.equal(volume.observe(state, node, 0.5, true).show, false);
    }
    assert.equal(volume.observe(null, null, 0.5, true).show, false);
});
