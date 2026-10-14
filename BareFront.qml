import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "barefront.launcher"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf11b"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: "BareFront — install or launch"
    onPressed: {
      const script = decodeURIComponent(Qt.resolvedUrl("scripts/open.sh").toString().replace(/^file:\/\//, ""))
      Quickshell.execDetached(["omarchy", "launch", "terminal", "bash", script])
    }
  }
}
