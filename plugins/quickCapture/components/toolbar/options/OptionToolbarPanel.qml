import QtQuick
import qs.Common
import "../../core/Helpers.js" as Helpers

Rectangle {
    id: root

    property Item popupRoot: null

    x: root.popupRoot ? Helpers.popoverX(root.popupRoot.width, width, root.popupRoot.menuX) : 0
    y: root.popupRoot ? Helpers.popoverY(root.popupRoot.height, height, root.popupRoot.menuY, root.popupRoot.toolbarPosition) : 0
    scale: 0.95

    color: Theme.surfaceContainer
    border.color: Theme.withAlpha(Theme.outline, 0.15)
    border.width: 1
    radius: Theme.cornerRadius
}
