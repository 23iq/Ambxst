const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require('node:path').join(__dirname, '../modules/services/Notifications.qml'), 'utf8');
function setup(notif, live = [], entries = [], clients = []) {
    const events = [];
    const root = { list: [notif], idOffset: 10, discardNotification: id => events.push(['discard', id]) };
    const context = { root, notifServer: { trackedNotifications: { values: live } },
        DesktopEntries: { applications: { values: entries }, byId: id => entries.find(e => e.id === id) },
        AxctlService: { clients: { values: clients }, dispatch: cmd => events.push(['focus', cmd]) } };
    for (const name of ['attemptInvokeAction', 'activateNotification']) {
        const start = source.indexOf('    function ' + name + '(');
        if (start < 0) continue;
        const open = source.indexOf('{', start);
        let depth = 1, end = open + 1;
        while (depth && end < source.length) { if (source[end] === '{') depth++; if (source[end] === '}') depth--; end++; }
        vm.runInNewContext(source.slice(start, end) + '\nroot.' + name + ' = ' + name, context);
    }
    return { root, events };
}
test('body click invokes the default action, not reply or delete', () => {
    const calls = [];
    const { root, events } = setup({ id: 17, appName: 'Slack', actions: [] }, [{ id: 7, actions: [
        { identifier: 'reply', invoke: () => calls.push('reply') },
        { identifier: 'default', invoke: () => calls.push('default') }
    ] }]);
    assert.equal(typeof root.activateNotification, 'function');
    assert.equal(root.activateNotification(17), true);
    assert.deepEqual(calls, ['default']);
    assert.deepEqual(events, [['discard', 17]]);
});
test('without a default action, focus the matching running app', () => {
    const { root, events } = setup({ id: 17, desktopEntry: 'com.slack.Slack', appName: 'Slack' }, [],
        [{ id: 'com.slack.Slack', name: 'Slack', startupClass: 'Slack' }],
        [{ address: '0x12', class: 'Slack' }, { address: '0x99', class: 'Discord' }]);
    assert.equal(typeof root.activateNotification, 'function');
    assert.equal(root.activateNotification(17), true);
    assert.deepEqual(events, [['focus', 'focuswindow address:0x12'], ['discard', 17]]);
});
test('cached notifications open the app without invoking stale actions', () => {
    const calls = [];
    const { root } = setup({ id: 17, isCached: true, desktopEntry: 'slack', appName: 'Slack', actions: [{ identifier: 'delete' }] }, [],
        [{ id: 'slack', name: 'Slack', execute: () => calls.push('launch') }]);
    assert.equal(typeof root.activateNotification, 'function');
    assert.equal(root.activateNotification(17), true);
    assert.deepEqual(calls, ['launch']);
});
test('unresolvable notification remains visible and does not invoke destructive actions', () => {
    const { root, events } = setup({ id: 17, appName: 'Unknown' }, [{ id: 7, actions: [{ identifier: 'delete', invoke: () => events.push('delete') }] }]);
    assert.equal(typeof root.activateNotification, 'function');
    assert.equal(root.activateNotification(17), false);
    assert.deepEqual(events, []);
});
