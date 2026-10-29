import QtQuick
import QtQuick.Controls as Controls

Controls.Button {
    id: control
    property string iconName: ""
    property bool destructive: false
    implicitWidth: 165
    implicitHeight: 48
    padding: 12
    font.family: "Noto Sans"
    font.pixelSize: 14
    opacity: enabled ? 1 : 0.4
    contentItem: Row {
        spacing: 9
        Canvas {
            id: actionIcon
            width: 20; height: 20
            anchors.verticalCenter: parent.verticalCenter
            visible: control.iconName.length > 0
            property string iconName: control.iconName
            onIconNameChanged: requestPaint()
            onPaint: {
                const painter = getContext("2d")
                painter.clearRect(0, 0, width, height)
                painter.save()
                painter.scale(width / 24, height / 24)
                painter.strokeStyle = "#F5F5F5"
                painter.lineWidth = 1.8
                painter.lineCap = "round"
                painter.lineJoin = "round"
                painter.beginPath()
                if (iconName === "power") {
                    painter.moveTo(12, 3)
                    painter.lineTo(12, 12)
                    painter.moveTo(17.5, 5.5)
                    painter.arc(12, 12, 8.5, -0.87, Math.PI + 0.87)
                } else if (iconName === "reboot") {
                    painter.arc(12, 12, 8, 0.8, Math.PI * 2)
                    painter.moveTo(20, 7)
                    painter.lineTo(20, 12)
                    painter.lineTo(15, 12)
                } else if (iconName === "sleep") {
                    painter.moveTo(20, 14.5)
                    painter.bezierCurveTo(10, 17, 7, 11, 9.5, 4)
                    painter.bezierCurveTo(-3, 8, 4, 27, 16, 20)
                    painter.bezierCurveTo(18, 18.8, 19.3, 16.8, 20, 14.5)
                }
                painter.stroke()
                painter.restore()
            }
        }
        Text {
            width: control.availableWidth - (actionIcon.visible ? actionIcon.width + 9 : 0)
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            font: control.font
            color: "#F5F5F5"
            elide: Text.ElideRight
        }
    }
    background: Rectangle {
        radius: height / 2
        color: control.destructive ? "#AC2933" : (control.down ? "#45464C" : (control.hovered ? "#383A40" : "#1C1D21"))
        border.width: control.activeFocus ? 2 : 0
        border.color: "#D6D6DA"
    }
}
