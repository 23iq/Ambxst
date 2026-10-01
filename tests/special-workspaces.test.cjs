const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const parser = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../modules/bar/workspaces/SpecialWorkspaces.js'), 'utf8').replace(/^\.pragma library\s*/, ''), parser);
const names = monitors => JSON.parse(JSON.stringify(parser.namesFromMonitors(monitors)));

test('closed or missing special workspaces have no label', () => {
    assert.deepEqual(names([]), {});
    assert.deepEqual(names([{name: 'DP-1'}, {name: 'DP-2', specialWorkspace: {id: 0, name: ''}}]), {});
});
test('names are parsed separately for each monitor', () => {
    assert.deepEqual(names([
        {name: 'DP-1', specialWorkspace: {id: -94, name: 'special:Telegram'}},
        {name: 'DP-2', specialWorkspace: {id: -95, name: 'special:Dev'}},
        {name: 'DP-3', specialWorkspace: {id: -96, name: 'special:Discord'}}
    ]), {'DP-1': 'Telegram', 'DP-2': 'Dev', 'DP-3': 'Discord'});
});
test('only the leading prefix is removed; Unicode and colons survive', () => {
    assert.deepEqual(names([{name: 'DP-1', specialWorkspace: {id: -2, name: 'special:Разработка:special:API'}}]), {'DP-1': 'Разработка:special:API'});
});
test('the unnamed scratchpad gets a readable fallback', () => {
    assert.deepEqual(names([{name: 'DP-1', specialWorkspace: {id: -99, name: 'special:'}}]), {'DP-1': 'special'});
});
test('regular workspaces are never treated as special', () => {
    assert.deepEqual(names([{name: 'DP-1', specialWorkspace: {id: 2, name: 'Dev'}}]), {});
});
