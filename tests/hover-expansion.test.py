"""Exercise the actual QML hover timers offscreen, without a desktop session."""
import os
os.environ['QT_QPA_PLATFORM'] = 'offscreen'
from pathlib import Path
from tempfile import TemporaryDirectory
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtTest import QTest

app = QGuiApplication([])
with TemporaryDirectory(prefix='ambxst-hover-test-') as temp:
    module = Path(temp) / 'qs/config'
    module.mkdir(parents=True)
    (module / 'qmldir').write_text('module qs.config\nsingleton Config 1.0 Config.qml\n')
    (module / 'Config.qml').write_text('''pragma Singleton
import QtQml
QtObject {
    property QtObject notch: QtObject {
        property bool disableHoverExpansion: false
        property int hoverExpandDelay: 30
        property int hoverCollapseDelay: 40
    }
}
''')
    engine = QQmlEngine()
    engine.addImportPath(temp)
    component = QQmlComponent(engine, QUrl.fromLocalFile(str(Path(__file__).resolve().parents[1] / 'modules/widgets/defaultview/HoverExpansion.qml')))
    item = component.create()
    assert item is not None, '\n'.join(e.toString() for e in component.errors())
    item.setProperty('available', True)
    item.setProperty('hovered', True)
    QTest.qWait(10)
    assert not item.property('expanded'), 'must not expand before opening delay'
    QTest.qWait(60)
    assert item.property('expanded'), 'must expand after deliberate hover'
    item.setProperty('hovered', False)
    QTest.qWait(10)
    assert item.property('expanded'), 'pointer crossing must retain card'
    item.setProperty('hovered', True)
    QTest.qWait(60)
    assert item.property('expanded'), 're-entry must cancel collapse'
    item.setProperty('suspended', True)
    assert not item.property('expanded'), 'launcher transitions freeze idle expansion'
    QTest.qWait(60)
    assert not item.property('expanded')
    item.setProperty('suspended', False)
    QTest.qWait(60)
    assert item.property('expanded')
    item.setProperty('available', False)
    assert not item.property('expanded'), 'closing player must collapse immediately'
    item.setProperty('available', True)
    QTest.qWait(60)
    item.setProperty('hovered', False)
    QTest.qWait(80)
    assert not item.property('expanded'), 'leaving island must collapse after delay'
    item.deleteLater()
    QTest.qWait(1)
print('HoverExpansion: opening delay, crossing, re-entry, suspension, player removal and collapse passed')
