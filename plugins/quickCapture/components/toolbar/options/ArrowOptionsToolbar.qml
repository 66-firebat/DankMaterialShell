import QtQuick
import qs.Common
import "../../core/Constants.js" as Constants

OptionToolbarPopup {
    id: root

    property string currentLineStyle: "solid"
    property string currentHeadStyle: "single-filled"

    signal lineStyleSelected(string style)
    signal headStyleSelected(string style)

    panelWidth: contentColumn.implicitWidth + Theme.spacingM * 2
    panelHeight: contentColumn.implicitHeight + Theme.spacingM * 2
        
    Column {
        id: contentColumn
        anchors.centerIn: parent
        spacing: Theme.spacingS

        // Top Row: Arrow Head Styles (Filled, Open, Double)
        Row {
            id: headRow
            spacing: Theme.spacingS
            Repeater {
                model: [
                    { icon: "trending_flat", style: "single-filled" },
                    { icon: "chevron_right", style: "single-open" },
                    { icon: "swap_horiz", style: "double-filled" }
                ]

                delegate: OptionToolbarButton {
                    iconName: modelData.icon
                    active: root.currentHeadStyle === modelData.style
                    onClicked: {
                        root.headStyleSelected(modelData.style);
                        root.close();
                    }
                }
            }
        }

        // Horizontal Separator
        Rectangle {
            width: headRow.implicitWidth; height: 1
            color: Theme.withAlpha(Theme.outline, 0.15)
        }

        // Bottom Row: Line Styles (Solid, Dashed, Dotted)
        Row {
            id: lineRow
            spacing: Theme.spacingS
            Repeater {
                model: [
                    { icon: "line_weight", style: "solid" },
                    { icon: "border_style", style: "dashed" },
                    { icon: "more_horiz", style: "dotted" }
                ]

                delegate: OptionToolbarButton {
                    iconName: modelData.icon
                    active: root.currentLineStyle === modelData.style
                    onClicked: {
                        root.lineStyleSelected(modelData.style);
                        root.close();
                    }
                }
            }
        }
    }
}
