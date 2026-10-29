import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import "i18n"

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#24262B"
    focus: true

    // Ryoku's in-session SDDM shim exposes fingerprintState; the system greeter
    // does not. Keep Quickshell-only imports in LiveData.qml.
    readonly property bool inSession: typeof sddm !== "undefined"
        && typeof sddm.fingerprintState !== "undefined"
    readonly property var live: liveData.item
    readonly property var battery: live ? live.battery : ({level: -1, charging: false})
    readonly property var activity: live ? live.activity : ({seconds: 0, available: false})
    readonly property var media: live ? live.media : ({available: false, playing: false})
    property date now: new Date()
    property string errorMessage: ""
    property string pendingPowerAction: ""
    readonly property int sessionIndex: Math.max(0, sessionPicker.currentIndex)
    readonly property string savedWallpaper: typeof config !== "undefined" && config.background
        ? String(config.background) : ""
    readonly property string backgroundUrl: root.live && root.live.wallpaperUrl.length > 0
        ? root.live.wallpaperUrl : root.savedWallpaper
    readonly property bool canPowerOff: typeof sddm !== "undefined"
        && typeof sddm.powerOff === "function" && sddm.canPowerOff !== false
    readonly property bool canReboot: typeof sddm !== "undefined"
        && typeof sddm.reboot === "function" && sddm.canReboot !== false
    readonly property bool canSuspend: typeof sddm !== "undefined"
        && typeof sddm.suspend === "function" && sddm.canSuspend !== false
    readonly property string loginUser: (typeof userModel !== "undefined" && userModel.lastUser)
        ? userModel.lastUser : ""
    readonly property real uiScale: Math.min(width / 1280, height / 720)

    // The shipped Ryoku translation catalogue at /usr/share/ryoku/i18n is the
    // single language table for this lockscreen. The theme ships no per-language
    // copy; every visible string goes through I18n.tr() and falls back to the
    // English key on a miss.
    function duration(seconds) {
        const value = Math.max(0, Math.floor(Number(seconds || 0)))
        return Math.floor(value / 3600) + ":" + String(Math.floor(value % 3600 / 60)).padStart(2, "0")
    }
    function stamp(seconds) {
        const value = Math.max(0, Math.floor(Number(seconds || 0)))
        return Math.floor(value / 60) + ":" + String(value % 60).padStart(2, "0")
    }
    function submit() {
        if (!password.text.length || !loginUser.length) return
        errorMessage = ""
        sddm.login(loginUser, password.text, sessionIndex)
    }
    function requestPower(action) {
        if (action === "suspend") {
            if (canSuspend) sddm.suspend()
            return
        }
        if ((action === "powerOff" && !canPowerOff) || (action === "reboot" && !canReboot)) return
        pendingPowerAction = action
        powerDialog.open()
    }
    function confirmPower() {
        const action = pendingPowerAction
        powerDialog.close()
        pendingPowerAction = ""
        if (action === "powerOff" && canPowerOff) sddm.powerOff()
        else if (action === "reboot" && canReboot) sddm.reboot()
    }

    Loader { id: liveData; active: root.inSession; source: "LiveData.qml" }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Timer { id: errorTimer; interval: 3200; onTriggered: root.errorMessage = "" }
    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            password.text = ""
            root.errorMessage = I18n.tr("Login Failed")
            errorTimer.restart()
            password.forceActiveFocus()
        }
    }
    // Input Focus — defer to ensure the greeter has settled before stealing focus
    Timer {
        id: focusTimer
        interval: 300
        running: true
        onTriggered: {
            if (typeof password !== "undefined")
                password.forceActiveFocus()
        }
    }

    Image {
        id: backgroundImage
        objectName: "backgroundImage"
        anchors.fill: parent
        visible: source.toString().length > 0
        source: root.backgroundUrl
        fillMode: root.live && root.live.fit === "Contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
    Loader {
        id: videoLayer
        anchors.fill: parent
        active: root.inSession && root.live && root.live.videoUrl.length > 0
        source: "LiveVideo.qml"
        onLoaded: item.sourceUrl = root.live.videoUrl
    }
    Connections {
        target: root.live
        function onVideoUrlChanged() {
            if (videoLayer.item) videoLayer.item.sourceUrl = root.live.videoUrl
        }
    }
    Rectangle { anchors.fill: parent; color: "#550F1013" }

    Item {
        width: 1072
        height: 528
        anchors.centerIn: parent
        scale: root.uiScale

        Text {
            x: 0; y: -43
            text: Qt.locale().toString(root.now, "dddd, d MMMM")
            font.family: "Noto Sans"; font.pixelSize: 20
            color: "#F5F5F5"
        }

        // A seven-row dot matrix drawn from vector primitives, no font asset.
        Canvas {
            id: clockDots
            x: 0; y: 28; width: 460; height: 112
            property string digits: Qt.formatTime(root.now, "hh:mm")
            onDigitsChanged: requestPaint()
            onPaint: {
                const glyphs = {
                    "0": ["11111","10001","10011","10101","11001","10001","11111"],
                    "1": ["00100","01100","00100","00100","00100","00100","01110"],
                    "2": ["11111","00001","00001","11111","10000","10000","11111"],
                    "3": ["11111","00001","00001","01111","00001","00001","11111"],
                    "4": ["10001","10001","10001","11111","00001","00001","00001"],
                    "5": ["11111","10000","10000","11111","00001","00001","11111"],
                    "6": ["11111","10000","10000","11111","10001","10001","11111"],
                    "7": ["11111","00001","00010","00100","01000","01000","01000"],
                    "8": ["11111","10001","10001","11111","10001","10001","11111"],
                    "9": ["11111","10001","10001","11111","00001","00001","11111"],
                    ":": ["0","0","1","0","1","0","0"]
                }
                const painter = getContext("2d")
                painter.clearRect(0, 0, width, height)
                const pitch = 14, radius = 4.4
                let column = 0
                for (const digit of digits) {
                    const bitmap = glyphs[digit]
                    if (!bitmap) continue
                    for (let row = 0; row < bitmap.length; row++) {
                        for (let col = 0; col < bitmap[row].length; col++) {
                            if (bitmap[row][col] !== "1") continue
                            painter.beginPath()
                            painter.arc((column + col) * pitch + radius, row * pitch + radius, radius, 0, Math.PI * 2)
                            painter.fillStyle = "#F5F5F5"
                            painter.fill()
                        }
                    }
                    column += bitmap[0].length + (digit === ":" ? 1 : 2)
                }
            }
        }
        Text {
            x: 0; y: 160
            text: "NOTHING INTERFACE"
            font.family: "Noto Sans"; font.pixelSize: 12; font.weight: Font.Medium
            font.letterSpacing: 2.8
            color: "#D6D6DA"
        }

        Rectangle {
            x: 544; y: 0; width: 256; height: 120; radius: 30
            color: "#1C1D21"
            Text {
                x: 22; y: 18
                text: I18n.tr("BATTERY")
                font.family: "Noto Sans"; font.pixelSize: 11; font.letterSpacing: 1.5
                color: "#B1B3B3"
            }
            Text {
                x: 22; y: 47
                text: root.battery.level >= 0 ? root.battery.level + "%" : "—"
                font.family: "Noto Sans"; font.pixelSize: 38; font.weight: Font.Medium
                color: "#F5F5F5"
            }
            Text {
                x: 145; y: 78
                text: root.battery.level < 0 ? I18n.tr("No data") : (root.battery.charging ? I18n.tr("Charging") : (root.battery.plugged ? I18n.tr("PLUGGED IN") : I18n.tr("On battery")))
                font.family: "Noto Sans"; font.pixelSize: 10
                color: "#B1B3B3"
            }
            Rectangle {
                x: 22; y: 104; width: 212; height: 3; radius: 2; color: "#414247"
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Number(root.battery.level) / 100))
                    height: parent.height; radius: parent.radius; color: "#F5F5F5"
                }
            }
        }

        Rectangle {
            x: 816; y: 0; width: 256; height: 120; radius: 30
            color: "#1C1D21"
            Text {
                x: 22; y: 18
                text: I18n.tr("USAGE")
                font.family: "Noto Sans"; font.pixelSize: 11; font.letterSpacing: 1.5
                color: "#B1B3B3"
            }
            Text {
                x: 22; y: 49
                text: root.activity.available ? root.duration(root.activity.seconds) : I18n.tr("No data")
                font.family: "Noto Sans"; font.pixelSize: 25; font.weight: Font.Medium
                color: "#F5F5F5"
            }
            Text {
                x: 22; y: 96
                text: I18n.tr("Today") + " · Ryoku Rashin"
                font.family: "Noto Sans"; font.pixelSize: 11
                color: "#B1B3B3"
            }
        }

        Rectangle {
            x: 544; y: 136; width: 528; height: 256; radius: 30
            color: "#1C1D21"
            Text {
                x: 24; y: 19
                text: I18n.tr("NOW PLAYING")
                font.family: "Noto Sans"; font.pixelSize: 11; font.letterSpacing: 1.5
                color: "#B1B3B3"
            }
            Text {
                x: 148; y: 57; width: 356
                text: root.media.available ? (root.media.title || I18n.tr("Music")) : I18n.tr("Nothing playing")
                font.family: "Noto Sans"; font.pixelSize: 26; font.weight: Font.Medium
                color: "#F5F5F5"; elide: Text.ElideRight
            }
            Text {
                x: 148; y: 104; width: 356
                text: root.media.available ? (root.media.artist || " ") : ""
                font.family: "Noto Sans"; font.pixelSize: 15
                color: "#B1B3B3"; elide: Text.ElideRight
            }
            Rectangle {
                x: 24; y: 56; width: 104; height: 104; radius: 52
                color: "#303136"; border.color: "#515258"; border.width: 1
            }
            Image {
                x: 24; y: 56; width: 104; height: 104
                source: root.media.available ? String(root.media.artUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: status === Image.Ready
            }
            Rectangle {
                x: 24; y: 174; width: 480; height: 3; radius: 2; color: "#414247"
                Rectangle {
                    width: parent.width * (Number(root.media.length) > 0
                        ? Math.max(0, Math.min(1, Number(root.media.position) / Number(root.media.length))) : 0)
                    height: parent.height; radius: parent.radius; color: "#F5F5F5"
                }
            }
            Text {
                x: 24; y: 188
                text: root.stamp(root.media.position) + " / " + root.stamp(root.media.length)
                font.family: "Noto Sans"; font.pixelSize: 11; color: "#B1B3B3"
            }
            Rectangle {
                x: 451; y: 190; width: 54; height: 54; radius: 27
                color: "#303136"; opacity: root.media.available ? 1 : 0.5
                Text {
                    anchors.centerIn: parent
                    text: root.media.playing ? "Ⅱ" : "▶"
                    font.family: "Noto Sans"; font.pixelSize: 24; color: "#F5F5F5"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.live) root.live.togglePlayback()
                }
            }
        }

        Rectangle {
            x: 0; y: 364; width: 440; height: 164; radius: 30
            color: "#1C1D21"
            Text {
                x: 24; y: 16
                text: root.loginUser.length ? root.loginUser : I18n.tr("USER")
                font.family: "Noto Sans"; font.pixelSize: 14; font.weight: Font.Medium
                color: "#F5F5F5"
            }
            Rectangle {
                x: 24; y: 50; width: 392; height: 52; radius: 26
                color: "#303136"
                border.color: password.activeFocus ? "#77787D" : "#44454A"
                TextInput {
                    id: password
                    objectName: "passwordInput"
                    anchors.fill: parent
                    anchors.leftMargin: 20; anchors.rightMargin: 20
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    font.family: "Noto Sans"; font.pixelSize: 18
                    color: "#F5F5F5"
                    verticalAlignment: TextInput.AlignVCenter
                    onAccepted: root.submit()
                }
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    verticalAlignment: Text.AlignVCenter
                    visible: password.text.length === 0
                    text: I18n.tr("Password")
                    font.family: "Noto Sans"; font.pixelSize: 15
                    color: "#A9AAAE"
                    MouseArea { anchors.fill: parent; onClicked: password.forceActiveFocus() }
                }
            }
            Text {
                x: 24; y: 112
                width: 330
                visible: root.errorMessage.length > 0
                text: root.errorMessage
                font.family: "Noto Sans"; font.pixelSize: 12
                color: "#D84545"
            }
            Rectangle {
                x: 369; y: 108; width: 47; height: 43; radius: 21
                color: "#F5F5F5"
                Text {
                    anchors.centerIn: parent
                    text: "→"; font.family: "Noto Sans"; font.pixelSize: 22
                    color: "#1C1D21"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submit()
                }
            }
        }

        Controls.ComboBox {
            id: sessionPicker
            objectName: "sessionPicker"
            x: 544; y: 416; width: 528; height: 48
            visible: !root.inSession
            model: typeof sessionModel !== "undefined" ? sessionModel : null
            textRole: "name"
            currentIndex: typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0
                ? sessionModel.lastIndex : 0
            font.family: "Noto Sans"; font.pixelSize: 14
            leftPadding: 22; rightPadding: 44
            contentItem: Text {
                text: I18n.tr("Session") + " · " + sessionPicker.displayText
                font: sessionPicker.font
                color: "#F5F5F5"
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            indicator: Text {
                x: parent.width - width - 20
                anchors.verticalCenter: parent.verticalCenter
                text: "⌄"; font.pixelSize: 22; color: "#D6D6DA"
            }
            background: Rectangle {
                radius: 24; color: "#1C1D21"
                border.width: sessionPicker.activeFocus ? 2 : 0
                border.color: "#D6D6DA"
            }
            delegate: Controls.ItemDelegate {
                id: sessionOption
                required property var model
                required property int index
                width: sessionPicker.popup.availableWidth
                implicitHeight: 44 * root.uiScale
                padding: 12 * root.uiScale
                text: model.name
                font: sessionPicker.font
                highlighted: sessionPicker.highlightedIndex === index
                contentItem: Text {
                    text: sessionOption.text
                    font.family: "Noto Sans"; font.pixelSize: 14 * root.uiScale
                    color: "#F5F5F5"
                    elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle { radius: 16 * root.uiScale; color: sessionOption.highlighted ? "#383A40" : "#1C1D21" }
            }
            popup: Controls.Popup {
                y: -height / root.uiScale - 8
                width: sessionPicker.width * root.uiScale
                padding: 8 * root.uiScale
                implicitHeight: Math.min(contentItem.implicitHeight + 16 * root.uiScale, 240 * root.uiScale)
                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: sessionPicker.popup.visible ? sessionPicker.delegateModel : null
                    currentIndex: sessionPicker.highlightedIndex
                    Controls.ScrollIndicator.vertical: Controls.ScrollIndicator {}
                }
                background: Rectangle { radius: 24 * root.uiScale; color: "#1C1D21"; border.color: "#515258" }
            }
        }

        Row {
            x: 544; y: 480
            spacing: 16
            ActionButton {
                objectName: "powerOffButton"
                text: I18n.tr("Shutdown"); iconName: "power"
                enabled: root.canPowerOff
                onClicked: root.requestPower("powerOff")
            }
            ActionButton {
                objectName: "rebootButton"
                text: I18n.tr("Reboot"); iconName: "reboot"
                enabled: root.canReboot
                onClicked: root.requestPower("reboot")
            }
            ActionButton {
                objectName: "suspendButton"
                text: I18n.tr("Suspend"); iconName: "sleep"
                enabled: root.canSuspend
                onClicked: root.requestPower("suspend")
            }
        }
    }

    Controls.Popup {
        id: powerDialog
        objectName: "powerDialog"
        parent: root
        width: 420 * root.uiScale
        height: 196 * root.uiScale
        x: (root.width - width) / 2; y: (root.height - height) / 2
        modal: true; dim: true; focus: true
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
        onClosed: password.forceActiveFocus()
        background: Rectangle { radius: 30 * root.uiScale; color: "#1C1D21"; border.color: "#515258" }
        Controls.Overlay.modal: Rectangle { color: "#AA101115" }
        contentItem: Item {
            Item {
                width: 396; height: 172
                anchors.centerIn: parent
                scale: root.uiScale
                Text {
                    x: 16; y: 14
                    width: 364
                    text: root.pendingPowerAction === "powerOff" ? I18n.tr("Shutdown") : I18n.tr("Reboot")
                    elide: Text.ElideRight
                    font.family: "Noto Sans"; font.pixelSize: 20; font.weight: Font.Medium
                    color: "#F5F5F5"
                }
                Text {
                    x: 16; y: 52
                    width: 364
                    text: root.pendingPowerAction === "powerOff" ? I18n.tr("Are you sure you want to shut down?") : I18n.tr("Are you sure you want to reboot?")
                    wrapMode: Text.WordWrap
                    font.family: "Noto Sans"; font.pixelSize: 13; color: "#B1B3B3"
                }
                Row {
                    x: 16; y: 106; spacing: 18
                    ActionButton { text: I18n.tr("Cancel"); onClicked: powerDialog.close() }
                    ActionButton {
                        objectName: "confirmPowerButton"
                        text: root.pendingPowerAction === "powerOff" ? I18n.tr("Shutdown") : I18n.tr("Reboot")
                        destructive: true
                        onClicked: root.confirmPower()
                    }
                }
            }
        }
    }
}
