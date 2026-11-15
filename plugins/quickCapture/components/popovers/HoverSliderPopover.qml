import QtQuick
import qs.Common
import qs.Widgets
import "../core/Constants.js" as Constants
import "../core/Helpers.js" as Helpers

PopoverSurface {
    id: popoverRoot

    width: isVertical ? Constants.btnSize : Constants.customRatioPopoverHeight
    height: isVertical ? Constants.customRatioPopoverHeight : Constants.btnSize
    property int minimum: 0
    property int maximum: 100
    property int value: 0
    property int stepSize: 5
    property bool isVertical: false
    onValueChanged: slider.value = value

    signal userValueChanged(int val)

    function valueFromRatio(ratio) {
        let rawVal = minimum + ratio * (maximum - minimum);
        let newVal = stepSize > 1 ? Math.round(rawVal / stepSize) * stepSize : Math.round(rawVal);
        return Helpers.clamp(newVal, minimum, maximum);
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: popoverRoot.open()
        onExited: popoverRoot.startCloseTimer()
        
        onWheel: (wheel) => {
            let step = wheel.angleDelta.y > 0 ? popoverRoot.stepSize : -popoverRoot.stepSize;
            let newVal = Helpers.clamp(popoverRoot.value + step, popoverRoot.minimum, popoverRoot.maximum);
            popoverRoot.userValueChanged(newVal);
        }

        DankSlider {
            id: slider
            visible: !popoverRoot.isVertical
            minimum: popoverRoot.minimum
            maximum: popoverRoot.maximum
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            value: popoverRoot.value
            showValue: false
            onSliderValueChanged: val => {
                if (!popoverRoot.isVertical) popoverRoot.userValueChanged(val)
            }
        }

        Item {
            id: verticalSliderContainer
            visible: popoverRoot.isVertical
            anchors.fill: parent
            anchors.margins: Theme.spacingS

            StyledRect {
                id: verticalTrack
                width: 8
                height: parent.height
                anchors.centerIn: parent
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.outline, Theme.popupTransparency)
                
                StyledRect {
                    id: verticalFill
                    width: parent.width
                    radius: Theme.cornerRadius
                    anchors.bottom: parent.bottom
                    height: {
                        const range = popoverRoot.maximum - popoverRoot.minimum;
                        const ratio = range === 0 ? 0 : (popoverRoot.value - popoverRoot.minimum) / range;
                        return Helpers.clamp(verticalTrack.height * ratio, 0, verticalTrack.height);
                    }
                    color: Theme.primary
                }
                
                StyledRect {
                    id: verticalHandle
                    width: 20
                    height: 8
                    radius: Theme.cornerRadius
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: {
                        const range = popoverRoot.maximum - popoverRoot.minimum;
                        const ratio = range === 0 ? 0 : (popoverRoot.value - popoverRoot.minimum) / range;
                        const travel = verticalTrack.height - height;
                        return Helpers.clamp(travel * (1 - ratio), 0, travel);
                    }
                    color: Theme.primary
                }
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                function updateValue(mouseY) {
                    if (verticalSliderContainer.height <= 0) return;
                    let ratio = 1 - Helpers.clamp(mouseY / verticalSliderContainer.height, 0, 1);
                    let newVal = popoverRoot.valueFromRatio(ratio);
                    if (newVal !== popoverRoot.value) {
                        popoverRoot.userValueChanged(newVal);
                    }
                }
                
                onPressed: mouse => updateValue(mouse.y)
                onPositionChanged: mouse => { if (pressed) updateValue(mouse.y) }
                onClicked: mouse => updateValue(mouse.y)
            }
        }
    }
}
