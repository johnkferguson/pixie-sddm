/**
 * Pixie SDDM - PowerBar Component
 * Author: xCaptaiN09
 */
import QtQuick
import QtQuick.Controls

Row {
    id: powerBarRoot
    spacing: 20
    height: 30

    property color textColor: "white"

    FontLoader { id: iconFont; source: "../assets/fonts/MaterialDesignIcons.ttf" }

    component PowerButton: Text {
        id: btn
        property string tooltip: ""
        signal clicked()

        color: powerBarRoot.textColor
        font.pixelSize: 20
        font.family: iconFont.name
        anchors.verticalCenter: parent.verticalCenter
        scale: clickArea.containsMouse ? 1.15 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        MouseArea {
            id: clickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }

        ToolTip {
            visible: clickArea.containsMouse && btn.tooltip.length > 0
            text: btn.tooltip
            delay: 500
        }
    }

    // Battery (With forced live updates)
    Row {
        id: batteryRow
        spacing: 5
        visible: typeof battery !== "undefined" && typeof battery.percent !== "undefined"
        anchors.verticalCenter: parent.verticalCenter

        Text {
            id: batteryText
            text: (typeof battery !== "undefined" ? battery.percent : "0") + "%"
            color: textColor
            font.pixelSize: 14
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            id: batteryIcon
            text: (typeof battery !== "undefined" && battery.charging) ? "󱐋" : "󰁹"
            color: textColor
            font.pixelSize: 18
            font.family: iconFont.name
            anchors.verticalCenter: parent.verticalCenter
        }

        // Bulletproof Live Update: SDDM sometimes fails to emit battery signals,
        // so we force a check every 5 seconds.
        Timer {
            interval: 5000
            running: typeof battery !== "undefined" && battery.present
            repeat: true
            onTriggered: {
                batteryText.text = battery.percent + "%"
                batteryIcon.text = battery.charging ? "󱐋" : "󰁹"
            }
        }
    }

    // Keyboard Layout
    Text {
        text: (typeof keyboard !== "undefined" && keyboard.layouts[keyboard.currentLayout]) ? keyboard.layouts[keyboard.currentLayout].shortName : "US"
        color: textColor
        font.pixelSize: 14
        font.capitalization: Font.AllUppercase
        visible: typeof keyboard !== "undefined" && keyboard.layouts.length > 1
        anchors.verticalCenter: parent.verticalCenter

        MouseArea {
            anchors.fill: parent
            onClicked: {
                keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
            }
        }
    }

    PowerButton {
        visible: config.showSuspend === "true"
        text: "󰤄"
        tooltip: "Suspend"
        onClicked: sddm.suspend()
    }

    PowerButton {
        visible: config.showRestart === "true"
        text: "󰑐"
        tooltip: "Restart"
        onClicked: sddm.reboot()
    }

    PowerButton {
        visible: config.showShutdown === "true"
        text: "󰐥"
        tooltip: "Shutdown"
        onClicked: sddm.powerOff()
    }
}
