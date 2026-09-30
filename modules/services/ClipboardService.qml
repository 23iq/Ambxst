pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    property bool active: true
    property var items: []
    property var imageDataById: ({})
    property var imagePathById: ({})
    property var linkPreviewCache: ({})
    property int revision: 0

    property bool _initialized: false
    signal listCompleted()

    // All persistence lives in the Go daemon (two encrypted SQLite
    // stores: pinned + unpinned). The watcher is a native wlr-data-control
    // client owned by the daemon; it emits a "clipboard.refresh" event on
    // every clipboard change and is the selection owner for every copy,
    // so no wl-clipboard subprocesses are involved. We just re-list.
    property int clipboardWatchHandle: -1
    property bool _watchBound: false

    property var _suspendWatch: Connections {
        target: SuspendManager
        function onPreparingForSleep() {
            if (root.clipboardWatchHandle >= 0) BackendService.setSubscriptionActive(root.clipboardWatchHandle, false);
        }
        function onWakingUp() {
            Qt.callLater(() => {
                if (!SuspendManager.isSuspending && root.clipboardWatchHandle >= 0) {
                    BackendService.setSubscriptionActive(root.clipboardWatchHandle, true);
                }
            });
        }
    }

    function bindWatcher() {
        if (root._watchBound) return;
        root._watchBound = true;
        root.clipboardWatchHandle = BackendService.addSubscription(["clipboard"], (service, data) => {
            if (service === "clipboard.refresh") {
                Qt.callLater(root.list);
            }
        });
        BackendService.setSubscriptionActive(root.clipboardWatchHandle, true);
    }

    // External trigger to start watching + load history.
    function start() {
        root.list();
    }

    signal fullContentRetrieved(string itemId, string content)
    signal linkPreviewFetched(string url, var metadata, string itemId)

    // Function to decode URL-encoded strings
    function decodeUriString(str) {
        try {
            return decodeURIComponent(str);
        } catch (e) {
            // If decoding fails, return original string
            return str;
        }
    }

    function fetchLinkPreview(url, itemId) {
        // Check cache first
        if (linkPreviewCache[url]) {
            Qt.callLater(function() {
                root.linkPreviewFetched(url, linkPreviewCache[url], itemId);
            });
            return;
        }

        BackendService.call("linkpreview.fetch", {url: url, timeout: 5}, (metadata, error) => {
            if (error || !metadata) {
                root.linkPreviewFetched(url, {'error': 'Failed to fetch preview'}, itemId);
                return;
            }
            const responseUrl = metadata.request_url || metadata.url || url;
            if (!metadata.error && responseUrl) {
                root.linkPreviewCache[responseUrl] = metadata;
            }
            root.linkPreviewFetched(responseUrl, metadata, itemId);
        });
    }

    function list() {
        BackendService.call("clipboard.list", {}, (result, error) => {
            if (error || !result) {
                console.warn("ClipboardService: list failed:", error || "no data");
                return;
            }
            var clipboardItems = [];
            for (var i = 0; i < result.length; i++) {
                var item = result[i];
                var isFile = item.mime_type === "text/uri-list";

                // For files, extract the filename from the URI for preview
                var preview = item.preview;
                if (item.is_image === 1) {
                    preview = "[Image]";
                }

                clipboardItems.push({
                    id: item.id,
                    preview: preview,
                    fullContent: item.preview,
                    mime: item.mime_type,
                    isImage: item.is_image === 1,
                    isFile: isFile,
                    binaryPath: "",
                    hash: item.content_hash || "",
                    size: item.size || 0,
                    createdAt: item.created_at || 0,
                    pinned: item.pinned === 1,
                    alias: item.alias || "",
                    displayIndex: item.display_index !== null && item.display_index !== undefined ? item.display_index : -1
                });
            }
            root.items = clipboardItems;
            root.pruneImageCaches();
            root.listCompleted();
        });
    }

    function getFullContent(id) {
        BackendService.call("clipboard.getContent", {id: id}, (result, error) => {
            if (error || !result) {
                root.fullContentRetrieved(id, "");
                return;
            }
            root.fullContentRetrieved(id, result.content || "");
        });
    }

    function deleteItem(id) {
        BackendService.call("clipboard.delete", {id: id}, (result, error) => {
            if (error || !result) {
                console.warn("ClipboardService: delete failed:", error || "no data");
                return;
            }
            // The daemon clears the live selection itself when it still
            // holds the deleted content (exact-byte hash comparison).
            Qt.callLater(root.list);
        });
    }

    function clear() {
        BackendService.call("clipboard.clear", {}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: clear failed:", error);
                return;
            }
            Qt.callLater(root.list);
        });
    }

    function togglePin(id) {
        BackendService.call("clipboard.togglePin", {id: id}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: togglePin failed:", error);
                return;
            }
            Qt.callLater(root.list);
        });
    }

    function setAlias(id, alias) {
        BackendService.call("clipboard.setAlias", {id: id, alias: alias}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: setAlias failed:", error);
                return;
            }
            Qt.callLater(root.list);
        });
    }

    // Reorder item by moving it to a new index
    function reorderItem(itemId, newIndex) {
        if (newIndex < 0) newIndex = 0;
        BackendService.call("clipboard.reorder", {id: itemId, new_index: newIndex}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: reorder failed:", error);
                return;
            }
            Qt.callLater(root.list);
        });
    }

    // Move item up (decrease index)
    function moveItemUp(itemId) {
        var currentIdx = -1;
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === itemId) {
                currentIdx = i;
                break;
            }
        }
        if (currentIdx <= 0) return;

        var item = items[currentIdx];
        var prevItem = items[currentIdx - 1];
        if (prevItem.pinned !== item.pinned) return;

        // Optimistic update: swap in local array
        var temp = items[currentIdx];
        items[currentIdx] = items[currentIdx - 1];
        items[currentIdx - 1] = temp;
        listCompleted();

        swapItems(itemId, prevItem.id);
    }

    // Move item down (increase index)
    function moveItemDown(itemId) {
        var currentIdx = -1;
        for (var i = 0; i < items.length; i++) {
            if (items[i].id === itemId) {
                currentIdx = i;
                break;
            }
        }
        if (currentIdx < 0 || currentIdx >= items.length - 1) return;

        var item = items[currentIdx];
        var nextItem = items[currentIdx + 1];
        if (nextItem.pinned !== item.pinned) return;

        // Optimistic update: swap in local array
        var temp = items[currentIdx];
        items[currentIdx] = items[currentIdx + 1];
        items[currentIdx + 1] = temp;
        listCompleted();

        swapItems(itemId, nextItem.id);
    }

    // Swap display indices between two items
    function swapItems(itemId1, itemId2) {
        BackendService.call("clipboard.swap", {id1: itemId1, id2: itemId2}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: swap failed:", error);
                return;
            }
            Qt.callLater(root.list);
        });
    }

    // Copy an item back to the clipboard (text, file URI or image blob).
    // The daemon becomes the selection owner and records the copy itself,
    // so no follow-up "check" pass is needed.
    function copyItem(id, mime) {
        BackendService.call("clipboard.copy", {id: id, mime: mime || ""}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: copy failed:", error);
            }
        });
    }

    // Load image data as data URL (images live as encrypted blobs now).
    // Caches are keyed by "id|hash": rowids alone are not stable enough
    // across stores, and the hash guarantees a recycled id can never
    // serve a previous item's image.
    function decodeToDataUrl(id, mime, hash) {
        var key = cacheKey(id, hash);
        if (imageDataById[key]) {
            return;
        }
        BackendService.call("clipboard.dataUrl", {id: id, mime: mime || ""}, (result, error) => {
            if (error || !result || !result.data_url) {
                return;
            }
            root.imageDataById[key] = result.data_url;
            root.revision++;
        });
    }

    function getImageData(id, hash) {
        return imageDataById[cacheKey(id, hash)] || "";
    }

    // Materialize an image blob to a tmpfs path (drag-and-drop / open).
    function requestImagePath(id, hash) {
        var key = cacheKey(id, hash);
        if (imagePathById[key]) {
            return;
        }
        BackendService.call("clipboard.imagePath", {id: id}, (result, error) => {
            if (error || !result || !result.path) {
                return;
            }
            root.imagePathById[key] = result.path;
            root.revision++;
        });
    }

    function getImagePath(id, hash) {
        return imagePathById[cacheKey(id, hash)] || "";
    }

    function cacheKey(id, hash) {
        return id + "|" + (hash || "");
    }

    // Purge cache entries whose item no longer exists in the history.
    function pruneImageCaches() {
        var live = {};
        for (var i = 0; i < items.length; i++) {
            live[cacheKey(items[i].id, items[i].hash)] = true;
        }
        var changed = false;
        for (var k in imageDataById) {
            if (!live[k]) {
                delete imageDataById[k];
                changed = true;
            }
        }
        for (var k2 in imagePathById) {
            if (!live[k2]) {
                delete imagePathById[k2];
                changed = true;
            }
        }
        if (changed) {
            root.revision++;
        }
    }

    // Copy and paste emoji via Ctrl+V (the daemon waits for selection
    // ownership before typing, so a stale clipboard is never pasted)
    function copyAndTypeEmoji(emojiText) {
        BackendService.call("clipboard.emojiType", {emoji: emojiText}, (result, error) => {
            if (error) {
                console.warn("ClipboardService: emojiType failed:", error);
            }
        });
    }

    Component.onCompleted: {
        // Bind clipboard watcher at boot (cheap - just adds IPC subscription)
        bindWatcher();
    }
}
