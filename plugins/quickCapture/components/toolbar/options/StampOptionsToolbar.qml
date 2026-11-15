import QtQuick
import qs.Common
import "../../core/Constants.js" as Constants

OptionToolbarPopup {
    id: root

    // States for options
    property string currentFormat: "numeric"

    signal formatSelected(string format)

    panelWidth: contentRow.implicitWidth + Theme.spacingM * 2
    panelHeight: Constants.subToolbarHeight
        
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.spacingS

        Repeater {
            model: [
                { icon: "looks_one", format: "numeric" },
                { icon: "title", format: "alpha" },
                { icon: "tag", format: "roman" }
            ]

            delegate: OptionToolbarButton {
                iconName: modelData.icon
                active: root.currentFormat === modelData.format
                onClicked: {
                    root.formatSelected(modelData.format);
                    root.close();
                }
            }
        }
    }
}
