import QtQuick
import qs.Common
import "../../core/Constants.js" as Constants

OptionToolbarPopup {
    id: root

    // States for options
    property bool boldActive: false
    property bool italicActive: false
    property bool underlineActive: false
    property bool backgroundActive: false

    signal boldToggled()
    signal italicToggled()
    signal underlineToggled()
    signal backgroundToggled()

    panelWidth: contentRow.implicitWidth + Theme.spacingM * 2
    panelHeight: Constants.subToolbarHeight
        
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.spacingS

        Repeater {
            model: [
                { icon: "format_bold", active: root.boldActive, tag: "bold" },
                { icon: "format_italic", active: root.italicActive, tag: "italic" },
                { icon: "format_underlined", active: root.underlineActive, tag: "underline" },
                { icon: "layers", active: root.backgroundActive, tag: "bg" }
            ]

            delegate: OptionToolbarButton {
                iconName: modelData.icon
                active: modelData.active
                onClicked: {
                    if (modelData.tag === "bold") root.boldToggled();
                    else if (modelData.tag === "italic") root.italicToggled();
                    else if (modelData.tag === "underline") root.underlineToggled();
                    else if (modelData.tag === "bg") root.backgroundToggled();
                }
            }
        }
    }
}
