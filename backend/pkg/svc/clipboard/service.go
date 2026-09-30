package clipboard

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	"ambxst/backend/pkg/ipc"
	"ambxst/backend/pkg/paths"
)

// Service owns the clipboard history (two encrypted SQLite stores: pinned
// + unpinned, capped history, images as blobs) and the clipboard watcher.
// The watcher is a native wlr-data-control client (no wl-clipboard
// subprocesses, race-free self-copy tracking); it is also the selection
// owner for every copy performed through this service. All state lives
// behind the store; this type only adapts IPC.
type Service struct {
	paths *paths.Paths

	watchMu sync.Mutex
	wl      *wlClient

	subsMu sync.Mutex
	subs   []*ipc.Subscriber

	initMu  sync.Mutex
	store   *store
	initErr error

	cacheMu    sync.Mutex
	imageCache map[string]string
}

// NewService keeps daemon boot cheap: the encrypted stores (and the
// legacy migration) open lazily on first clipboard use.
func NewService(p *paths.Paths) *Service {
	// Stale materialized images from a previous session are junk.
	os.RemoveAll(p.ClipboardImageCacheDir())
	return &Service{
		paths:      p,
		imageCache: map[string]string{},
	}
}

// getStore lazily creates the store on first use.
func (s *Service) getStore() (*store, error) {
	s.initMu.Lock()
	defer s.initMu.Unlock()
	if s.store != nil {
		return s.store, nil
	}
	if s.initErr != nil {
		return nil, s.initErr
	}
	st, err := newStore(s.paths)
	if err != nil {
		s.initErr = err
		log.Printf("[clipboard] store init: %v", err)
		return nil, err
	}
	s.store = st
	return st, nil
}

// Prewarm opens the encrypted stores in the background so the first
// clipboard.list doesn't pay the (adiantum + FTS5) init cost, and
// rewrites bloated stores left by history churn.
func (s *Service) Prewarm() {
	st, err := s.getStore()
	if err != nil {
		log.Printf("[clipboard] prewarm: %v", err)
		return
	}
	st.VacuumIfBloated()
}

func (s *Service) Register(srv *ipc.Server) {
	srv.Register(&ipc.Service{
		Name: "clipboard",
		Methods: map[string]ipc.HandlerFunc{
			"list":           s.list,
			"getContent":     s.getContent,
			"delete":         s.delete,
			"clear":          s.clear,
			"togglePin":      s.togglePin,
			"setAlias":       s.setAlias,
			"reorder":        s.reorder,
			"swap":           s.swap,
			"copy":           s.copy,
			"emojiType":      s.emojiType,
			"dataUrl":        s.dataURL,
			"imagePath":      s.imagePath,
			"clearClipboard": s.clearClipboard,
			"setTmpMode":     s.setTmpMode,
			"check":          s.check,
			"copyText":       s.copyText,
			"copyData":       s.copyData,
			"copyFile":       s.copyFile,
			"liveMimes":      s.liveMimes,
			"liveContent":    s.liveContent,
		},
		Subscribe: s.subscribe,
	})
}

func (s *Service) Close() {
	s.watchMu.Lock()
	if s.wl != nil {
		s.wl.stop()
		s.wl = nil
	}
	s.watchMu.Unlock()
	s.initMu.Lock()
	defer s.initMu.Unlock()
	if s.store != nil {
		s.store.close()
	}
}

// --- subscriber fan-out ---

// Send broadcasts a service event to every live subscriber.
func (s *Service) Send(service string, data any) {
	s.subsMu.Lock()
	live := s.subs[:0]
	for _, sub := range s.subs {
		select {
		case <-sub.StopCh():
			continue
		default:
		}
		live = append(live, sub)
		sub.Send(service, data)
	}
	s.subs = live
	s.subsMu.Unlock()
}

func (s *Service) subscribe(sub *ipc.Subscriber) {
	s.subsMu.Lock()
	s.subs = append(s.subs, sub)
	s.subsMu.Unlock()
	s.ensureWatcher()
}

// ensureWatcher starts the native wlr-data-control watcher once. There is
// no fallback: every supported compositor (Hyprland, Niri, Mango, any
// wlroots derivative) implements the protocol.
func (s *Service) ensureWatcher() {
	s.watchMu.Lock()
	defer s.watchMu.Unlock()
	if s.wl != nil {
		return
	}
	wl, err := startWayland(s)
	if err != nil {
		log.Printf("[clipboard] native watcher unavailable, clipboard history disabled: %v", err)
		return
	}
	s.wl = wl
}

// captureContent stores freshly observed clipboard content. Returns
// whether subscribers should refresh.
func (s *Service) captureContent(mime string, mimes []string, content []byte, isImage bool, size int64) bool {
	st, err := s.getStore()
	if err != nil {
		log.Printf("[clipboard] insert: %v", err)
		return false
	}
	inserted, err := st.insertUnpinned(mime, mimes, content, isImage, size)
	if err != nil {
		log.Printf("[clipboard] insert: %v", err)
	}
	return inserted
}

// --- IPC handlers ---

func (s *Service) list(_ json.RawMessage) (any, error) {
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return st.listItems(), nil
}

func (s *Service) getContent(params json.RawMessage) (any, error) {
	var p struct {
		ID string `json:"id"`
	}
	json.Unmarshal(params, &p)
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	content, err := st.getContent(id)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"id": p.ID, "content": content}, nil
}

func (s *Service) delete(params json.RawMessage) (any, error) {
	var p struct {
		ID string `json:"id"`
	}
	json.Unmarshal(params, &p)
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	hash, err := st.deleteItem(id)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if hash != "" {
		s.clearLiveIfHash(hash)
	}
	return map[string]any{"hash": hash}, nil
}

// clearLiveIfHash unsets the live selection when it still holds the
// deleted content (hash comparison over exact captured bytes).
func (s *Service) clearLiveIfHash(hash string) {
	s.watchMu.Lock()
	wl := s.wl
	s.watchMu.Unlock()
	if wl != nil && wl.liveHashValue() == hash {
		wl.clearSelection()
	}
}

func (s *Service) clear(_ json.RawMessage) (any, error) {
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if err := st.clearUnpinned(); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	// Respond immediately; reclaim the freed pages off the hot path.
	go st.VacuumIfBloated()
	s.watchMu.Lock()
	wl := s.wl
	s.watchMu.Unlock()
	if wl != nil {
		wl.clearSelection()
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) togglePin(params json.RawMessage) (any, error) {
	var p struct {
		ID string `json:"id"`
	}
	json.Unmarshal(params, &p)
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if err := st.togglePin(id); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) setAlias(params json.RawMessage) (any, error) {
	var p struct {
		ID    string `json:"id"`
		Alias string `json:"alias"`
	}
	json.Unmarshal(params, &p)
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if err := st.setAlias(id, p.Alias); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) reorder(params json.RawMessage) (any, error) {
	var p struct {
		ID       string `json:"id"`
		NewIndex int    `json:"new_index"`
	}
	json.Unmarshal(params, &p)
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if err := st.reorder(id, p.NewIndex); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) swap(params json.RawMessage) (any, error) {
	var p struct {
		ID1 string `json:"id1"`
		ID2 string `json:"id2"`
	}
	json.Unmarshal(params, &p)
	id1, ok1 := parseID(p.ID1)
	id2, ok2 := parseID(p.ID2)
	if !ok1 || !ok2 {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if err := st.swap(id1, id2); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

// copy puts an item's content back on the clipboard (text, file URI or
// image blob). The daemon becomes the selection owner with no subprocess
// fork race; the QML side needs no follow-up "check" pass.
func (s *Service) copy(params json.RawMessage) (any, error) {
	var p struct {
		ID   string `json:"id"`
		Mime string `json:"mime"`
	}
	json.Unmarshal(params, &p)
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	mime, content, err := st.copyRow(id)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if p.Mime != "" {
		mime = p.Mime
	}
	if err := s.CopyData(mime, content); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

// CopyText makes the daemon the selection owner for a plain-text value.
// Used by QML copy actions and CLI tools instead of spawning wl-copy.
func (s *Service) CopyText(text string) error {
	return s.CopyData("text/plain;charset=utf-8", []byte(text))
}

// CopyData serves arbitrary content as the clipboard selection.
func (s *Service) CopyData(mime string, content []byte) error {
	if mime == "" {
		mime = "text/plain;charset=utf-8"
	}
	s.watchMu.Lock()
	wl := s.wl
	s.watchMu.Unlock()
	if wl == nil {
		return errors.New("clipboard watcher unavailable")
	}
	return wl.copyContent(mime, content)
}

// CopyFile serves a file's bytes as the clipboard selection (screenshots,
// exported images) without shipping the payload over IPC.
func (s *Service) CopyFile(path, mime string) error {
	if mime == "" {
		mime = "image/png"
	}
	content, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return s.CopyData(mime, content)
}

// emojiType copies an emoji and types it via wtype. The daemon waits for
// the compositor to confirm our selection ownership before typing, so the
// paste can never race a stale selection.
func (s *Service) emojiType(params json.RawMessage) (any, error) {
	var p struct {
		Emoji string `json:"emoji"`
	}
	json.Unmarshal(params, &p)
	emoji := p.Emoji
	if emoji == "" {
		return map[string]any{"error": "empty emoji"}, nil
	}
	s.watchMu.Lock()
	wl := s.wl
	s.watchMu.Unlock()
	if wl == nil {
		return map[string]any{"error": "clipboard watcher unavailable"}, nil
	}
	wl.copyTextAwait("text/plain;charset=utf-8", []byte(emoji))
	exec.Command("wtype", "-M", "ctrl", "-P", "v", "-p", "v", "-m", "ctrl").Run()
	return map[string]any{"ok": true}, nil
}

// dataURL returns a base64 data URL for an image item (cached).
func (s *Service) dataURL(params json.RawMessage) (any, error) {
	var p struct {
		ID   string `json:"id"`
		Mime string `json:"mime"`
	}
	json.Unmarshal(params, &p)
	s.cacheMu.Lock()
	if v, ok := s.imageCache[p.ID]; ok {
		s.cacheMu.Unlock()
		return map[string]any{"id": p.ID, "data_url": v}, nil
	}
	s.cacheMu.Unlock()
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	blob, mime, err := st.imageBlob(id)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if p.Mime != "" {
		mime = p.Mime
	}
	if mime == "" {
		mime = "image/png"
	}
	url := "data:" + mime + ";base64," + base64.StdEncoding.EncodeToString(blob)
	s.cacheMu.Lock()
	s.imageCache[p.ID] = url
	s.cacheMu.Unlock()
	return map[string]any{"id": p.ID, "data_url": url}, nil
}

// imagePath materializes an image blob to a tmpfs file so QML can use it
// as a file URI (drag-and-drop, external open).
func (s *Service) imagePath(params json.RawMessage) (any, error) {
	var p struct {
		ID string `json:"id"`
	}
	json.Unmarshal(params, &p)
	id, ok := parseID(p.ID)
	if !ok {
		return map[string]any{"error": "invalid id"}, nil
	}
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	blob, mime, err := st.imageBlob(id)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	ext := "img"
	switch mime {
	case "image/png":
		ext = "png"
	case "image/jpeg":
		ext = "jpg"
	case "image/gif":
		ext = "gif"
	case "image/webp":
		ext = "webp"
	case "image/bmp":
		ext = "bmp"
	case "image/svg+xml":
		ext = "svg"
	}
	dir := s.paths.ClipboardImageCacheDir()
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	path := filepath.Join(dir, fmt.Sprintf("%s.%s", strings.ReplaceAll(p.ID, ":", ""), ext))
	if err := os.WriteFile(path, blob, 0o600); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"id": p.ID, "path": path}, nil
}

// clearClipboard unsets the live selection.
func (s *Service) clearClipboard(_ json.RawMessage) (any, error) {
	s.watchMu.Lock()
	wl := s.wl
	s.watchMu.Unlock()
	if wl != nil {
		wl.clearSelection()
	}
	return map[string]any{"ok": true}, nil
}

// check is a no-op kept for IPC compatibility: both the native client and
// the legacy watcher capture every clipboard change automatically.
func (s *Service) check(_ json.RawMessage) (any, error) {
	return map[string]any{"ok": true}, nil
}

// setTmpMode switches where the unpinned history lives (local share vs
// tmpfs). QML owns the persisted flag; the daemon re-reads it on boot.
func (s *Service) setTmpMode(params json.RawMessage) (any, error) {
	var p struct {
		Enabled bool `json:"enabled"`
	}
	json.Unmarshal(params, &p)
	st, err := s.getStore()
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if err := st.setTmpMode(p.Enabled); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	log.Printf("[clipboard] tmpfs mode: %v", p.Enabled)
	return map[string]any{"ok": true}, nil
}

// liveMimes reports the MIME types offered by the current selection
// (tracked from the last data-control selection event).
func (s *Service) liveMimes(_ json.RawMessage) (any, error) {
	s.watchMu.Lock()
	wl := s.wl
	s.watchMu.Unlock()
	if wl == nil {
		return map[string]any{"mimes": []string{}}, nil
	}
	return map[string]any{"mimes": wl.liveMimes()}, nil
}

func (s *Service) copyText(params json.RawMessage) (any, error) {
	var p struct {
		Text string `json:"text"`
	}
	json.Unmarshal(params, &p)
	if err := s.CopyText(p.Text); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) copyData(params json.RawMessage) (any, error) {
	var p struct {
		Mime          string `json:"mime"`
		ContentBase64 string `json:"content_base64"`
	}
	json.Unmarshal(params, &p)
	content, err := base64.StdEncoding.DecodeString(p.ContentBase64)
	if err != nil {
		return map[string]any{"error": "invalid base64 content"}, nil
	}
	if err := s.CopyData(p.Mime, content); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

func (s *Service) copyFile(params json.RawMessage) (any, error) {
	var p struct {
		Path string `json:"path"`
		Mime string `json:"mime"`
	}
	json.Unmarshal(params, &p)
	if p.Path == "" {
		return map[string]any{"error": "missing path"}, nil
	}
	if err := s.CopyFile(p.Path, p.Mime); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"ok": true}, nil
}

// liveContent reads the requested MIME type from the current selection
// (equivalent of wl-paste, served through our own data-control offer).
func (s *Service) liveContent(params json.RawMessage) (any, error) {
	var p struct {
		Mime string `json:"mime"`
	}
	json.Unmarshal(params, &p)
	if p.Mime == "" {
		p.Mime = "text/plain;charset=utf-8"
	}
	s.watchMu.Lock()
	wl := s.wl
	s.watchMu.Unlock()
	if wl == nil {
		return map[string]any{"error": "clipboard watcher unavailable"}, nil
	}
	content, err := wl.liveContent(p.Mime)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"mime": p.Mime, "content_base64": base64.StdEncoding.EncodeToString(content)}, nil
}
