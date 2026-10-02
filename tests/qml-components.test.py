"""Construct island QML offscreen with external shell services stubbed.

This checks QML type/loading errors, not live shell behavior or integration.
"""
import os, pathlib, tempfile, shutil
os.environ['QT_QPA_PLATFORM']='offscreen'
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent
from PySide6.QtCore import QUrl, QPoint, QPointF, Qt
from PySide6.QtQuick import QQuickWindow, QQuickItem
from PySide6.QtTest import QTest
from PySide6.QtQml import QQmlExpression
app=QGuiApplication([])
repo=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='ambxst-components-') as tmp:
 p=pathlib.Path(tmp)
 def module(name, files):
  d=p/name.replace('.','/'); d.mkdir(parents=True)
  lines=['module '+name]
  for n, body in files.items():
   singleton=body.startswith('pragma Singleton')
   (d/(n+'.qml')).write_text(body)
   lines.append(('singleton ' if singleton else '')+n+' 1.0 '+n+'.qml')
  (d/'qmldir').write_text('\n'.join(lines))
 module('qs.config',{'Config':'''pragma Singleton
import QtQuick
QtObject { function resolveColor(c) { return c; } property QtObject performance: QtObject { property bool blurTransition: false }; property QtObject theme: QtObject { property QtObject srBg: QtObject { property var border: ["white", 1] } }; property int animDuration: 160; property bool showBackground: true; property int roundness: 12; property string notchTheme: "island"; property string notchPosition: "top"; property QtObject bar: QtObject { property string position: "top" }; property QtObject notch: QtObject { property bool disableHoverExpansion: false; property int hoverExpandDelay: 90; property int hoverCollapseDelay: 200; property int expandedMediaWidth: 440; property int expandedArtworkSize: 64; property int microphoneNoticeDuration: 1800; property int mediaAnimationDuration: 160; property string customText: "Ambxst" } }'''})
 module('qs.modules.theme',{
 'Styling':'''pragma Singleton
import QtQuick
QtObject { property string defaultFont: "Sans"; function fontSize(n) { return 14+n; } function radius(n) { return 12+n; } function srItem(n) { return "white"; } }''',
 'Colors':'''pragma Singleton
import QtQuick
QtObject { property color overBackground: "white"; property color criticalRed: "red"; property color primary: "blue"; property color surfaceBright: "gray"; property color shadow: "black" }''',
 'Icons':'''pragma Singleton
import QtQuick
QtObject { property string font: "Sans"; property string player: "P"; property string spotify: "S"; property string previous: "<"; property string next: ">"; property string play: "P"; property string pause: "II"; property string mic: "M"; property string micSlash: "X" }'''})
 module('qs.modules.services',{
 'I18n':'''pragma Singleton
import QtQuick
QtObject { function t(s) { return s; } }''',
 'MicrophoneStatus':'''pragma Singleton
import QtQuick
QtObject { property bool muted: false; property bool available: true; property bool noticeVisible: false; property string noticeScreen: "" }''',
 'MprisController':'''pragma Singleton
import QtQuick
QtObject { property var activePlayer: null; property var filteredPlayers: []; function setActivePlayer(p) {} }''',
 'Notifications':'''pragma Singleton
import QtQuick
QtObject { property var popupList: [] }''',
 'Visibilities':'''pragma Singleton
import QtQuick
QtObject { property bool playerMenuOpen: false }'''})
 module('qs.modules.components',{
 'StyledRect':'''import QtQuick
Item { property string variant; property real radius; property bool enableBorder; property real backgroundOpacity; property bool animateRadius; property real topLeftRadius; property real topRightRadius; property real bottomLeftRadius; property real bottomRightRadius; property color item: "white" }''',
 'StyledSlider':'''import QtQuick
Item { property bool resizeParent; property bool wavy; property bool playing; property real wavyAmplitude; property real wavyFrequency; property real heightMultiplier; property color progressColor; property color backgroundColor; property bool smoothDrag; property bool scroll; property bool tooltip; property bool updateOnRelease; property bool isDragging: false; property real value: 0 }''',
 'Separator':'''import QtQuick
Item { property bool vert; width: 1; height: 10 }''',
 'BarPopup':'''import QtQuick
Item { property Item anchorItem; property var bar; property int contentWidth; property int contentHeight; property int popupPadding: 8; property bool isOpen: false; function toggle() { isOpen = !isOpen; } }'''})
 module('qs.modules.notch', {'NotchNotificationView':'''import QtQuick
Item { property bool isNavigating: false; property bool notchHovered: false; implicitHeight: 80 }'''})
 module('qs.modules.globals', {'GlobalStates': 'pragma Singleton\nimport QtQuick\nQtObject {}'})
 module('qs.modules.corners', {'RoundCorner': 'import QtQuick\nItem { enum CornerEnum { TopRight, BottomRight, TopLeft, BottomLeft } property int corner; property real size; property color color }'})
 children=p/'children'; children.mkdir()
 names=['AlbumBackdrop','HoverExpansion','MediaTimeline','MediaTransportControls','ExpandedMedia','MediaSummary','IslandHeader','IslandNotifications','DefaultView']
 for n in ['Notch', 'NotchViewTransition']: shutil.copy(repo/'modules/notch'/(n+'.qml'), children)
 for n in names: shutil.copy(repo/'modules/widgets/defaultview'/(n+'.qml'),children)
 shutil.copy(repo/'modules/widgets/defaultview/IslandMedia.js',children)
 for n in ['UserInfo','NotificationIndicator']:
  (children/(n+'.qml')).write_text('import QtQuick\nItem { width: 20; height: 20 }')
 (children/'CompactPlayer.qml').write_text('import QtQuick\nItem { property var player; property bool notchHovered }')
 (children/'NotchSmoke.qml').write_text('import QtQuick\nNotch { defaultViewComponent: Component { Item { implicitWidth: 300; implicitHeight: 44 } } }')
 names += ['NotchViewTransition', 'NotchSmoke']
 engine=QQmlEngine(); engine.addImportPath(tmp)
 failed=False
 for n in names:
  c=QQmlComponent(engine,QUrl.fromLocalFile(str(children/(n+'.qml'))))
  obj=c.createWithInitialProperties({'player':None} if n in ['MediaTimeline','MediaTransportControls','ExpandedMedia','MediaSummary','IslandHeader'] else {})
  print(n+': '+('PASS' if obj else 'FAIL'))
  for e in c.errors(): print(e.toString())
  failed = failed or obj is None
 if failed: raise SystemExit(1)

 c=QQmlComponent(engine,QUrl.fromLocalFile(str(children/'DefaultView.qml')))
 view=c.create()
 def evaluate(obj, expression):
  e=QQmlExpression(engine.contextForObject(obj), obj, expression)
  result=e.evaluate()
  assert not e.hasError(), e.error().toString()
  return result[0] if isinstance(result, tuple) else result
 evaluate(view, 'MprisController.activePlayer = ({trackTitle: "Song", identity: "Player"})')
 evaluate(view, 'Notifications.popupList = [{id: 1}]')
 window=QQuickWindow(); window.resize(700, 500)
 view.setParentItem(window.contentItem()); view.setX(100); view.setY(100)
 window.show(); QTest.qWait(40)
 def move(item):
  point=item.mapToScene(item.boundingRect().center()).toPoint()
  QTest.mouseMove(window, point); QTest.qWait(350)
 header=evaluate(view, 'header')
 summary=next(i for i in header.childItems() if 'Loader' in i.metaObject().className())
 def move_badge():
  point=summary.mapToScene(QPointF(summary.width()-12, summary.height()/2)).toPoint()
  QTest.mouseMove(window, point); QTest.qWait(350)
  return point
 notification=evaluate(view, 'notificationSlot')
 move_badge()
 assert not view.property('mediaHoverExpanded'), 'selector badge must not open a collapsed player'
 QTest.mouseClick(window, Qt.LeftButton, pos=move_badge()); QTest.qWait(350)
 assert evaluate(view, 'header.selectorOpen'), 'badge click must open player selector'
 assert not view.property('mediaHoverExpanded'), 'selector menu must not open a collapsed player'
 QTest.mouseClick(window, Qt.LeftButton, pos=move_badge()); QTest.qWait(350)
 move(notification)
 assert not view.property('mediaHoverExpanded'), 'notification hover must not expand media'
 assert evaluate(view, 'notifications.hovered'), 'notification hover must enlarge notification'
 move(summary)
 assert view.property('mediaHoverExpanded'), 'player hover must expand media'
 assert evaluate(view, 'notifications.hovered'), 'player hover must also enlarge notification'
 move_badge()
 assert view.property('mediaHoverExpanded'), 'selector badge must keep an expanded player open'
 QTest.mouseClick(window, Qt.LeftButton, pos=move_badge()); QTest.qWait(350)
 move(header.childItems()[0])
 assert view.property('mediaHoverExpanded'), 'selector menu must keep an already expanded player open'
 QTest.mouseClick(window, Qt.LeftButton, pos=move_badge()); QTest.qWait(350)
 move(evaluate(view, 'expandedMedia'))
 assert view.property('mediaHoverExpanded'), 'expanded player controls must keep media open'
 move(header.childItems()[0])
 assert not view.property('mediaHoverExpanded'), 'user area must not keep media expanded'
 assert not evaluate(view, 'notifications.hovered'), 'user area must not enlarge notification'
 evaluate(view, 'MprisController.activePlayer = null')
 move(summary)
 assert not evaluate(view, 'notifications.hovered'), 'idle text without a player must not enlarge notifications'
 evaluate(view, 'MprisController.activePlayer = ({trackTitle: "Song", identity: "Player"})')
 evaluate(view, 'Notifications.popupList = []')
 move(summary)
 assert view.property('mediaHoverExpanded'), 'player must expand without notifications'
 window.close()
 print('Island pointer routing: notification, player, controls, user area and no notifications passed')
