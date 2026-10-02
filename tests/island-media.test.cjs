const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const media = {};
const file = path.join(__dirname, '../modules/widgets/defaultview/IslandMedia.js');
if (fs.existsSync(file)) vm.runInNewContext(fs.readFileSync(file, 'utf8').replace(/^\.pragma library\s*/, ''), media);

test('expansion requires hover, a player and enabled setting', () => {
    assert.equal(typeof media.canExpand, 'function');
    assert.equal(media.canExpand(true, {}, false), true);
    for (const args of [[false, {}, false], [true, null, false], [true, {}, true]])
        assert.equal(media.canExpand(...args), false);
});
test('time uses MPRIS seconds and handles unknown or invalid durations', () => {
    assert.equal(typeof media.formatTime, 'function');
    assert.equal(media.formatTime(125), '2:05');
    assert.equal(media.formatTime(3661), '1:01:01');
    for (const value of [undefined, NaN, Infinity, -10]) assert.equal(media.formatTime(value), '0:00');
});
test('live or non-seekable players never enable seeking', () => {
    assert.equal(typeof media.canSeek, 'function');
    assert.equal(media.canSeek({ canSeek: true, length: 120 }), true);
    for (const player of [null, { canSeek: false, length: 120 }, { canSeek: true, length: 0 }, { canSeek: true, length: Infinity }])
        assert.equal(media.canSeek(player), false);
});
