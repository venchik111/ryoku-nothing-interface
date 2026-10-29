import QtQuick
import QtQuick.Window

Window {
    id: fixture
    width: 1920; height: 1080; visible: true
    property var config: ({ background: argument("--background") })

    function argument(name) {
        const index = Qt.application.arguments.indexOf(name)
        return index >= 0 ? Qt.application.arguments[index + 1] : ""
    }
    function check(condition, message) {
        if (!condition) throw new Error(message)
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const result = find(child, name)
            if (result) return result
        }
        return null
    }

    QtObject {
        id: mockSddm
        property var fingerprintState: fixture.argument("--mode") === "lockscreen" ? "idle" : undefined
        property bool canPowerOff: true
        property bool canReboot: true
        property bool canSuspend: true
        property int shutdowns: 0
        property int reboots: 0
        property int suspends: 0
        property int loginSession: -1
        signal loginFailed()
        function login(user, password, session) { loginSession = session }
        function powerOff() { shutdowns++ }
        function reboot() { reboots++ }
        function suspend() { suspends++ }
    }
    QtObject { id: mockUser; property string lastUser: "demo" }
    ListModel {
        id: mockSessions
        property int lastIndex: 1
        ListElement { name: "Hyprland" }
        ListElement { name: "Hyprland (UWSM)" }
        ListElement { name: "Weston" }
    }
    Loader {
        id: theme
        anchors.fill: parent
        property var config: fixture.config
        property var sddm: mockSddm
        property var userModel: mockUser
        property var sessionModel: mockSessions
        source: "../nothing-interface/Main.qml"
        onLoaded: {
            item.width = fixture.width
            item.height = fixture.height
            runChecks.start()
        }
    }
    Timer {
        id: runChecks
        interval: 800
        onTriggered: {
            try {
                const root = theme.item
                const picker = fixture.find(root, "sessionPicker")
                const password = fixture.find(root, "passwordInput")
                const background = fixture.find(root, "backgroundImage")
                const lockMode = fixture.argument("--mode") === "lockscreen"
                fixture.check(root.inSession === lockMode, "Unexpected sign-in/lock mode")
                fixture.check(picker.visible === !lockMode, "Session selection visible in the wrong mode")
                fixture.check(background.status === Image.Ready, "Saved background did not load")
                fixture.check(root.sessionIndex === 1, "Previous session was not selected")
                picker.currentIndex = 2
                password.text = "test fixture"
                root.submit()
                fixture.check(mockSddm.loginSession === 2, "Login ignored the selected session")
                mockSddm.loginFailed()
                fixture.check(password.text === "" && root.errorMessage.length > 0, "Password error handling failed")
                root.errorMessage = ""
                root.requestPower("powerOff")
                fixture.check(mockSddm.shutdowns === 0, "Shutdown occurred before confirmation")
                root.confirmPower()
                fixture.check(mockSddm.shutdowns === 1, "Confirmed shutdown was not dispatched")
                root.requestPower("reboot")
                fixture.check(mockSddm.reboots === 0, "Reboot occurred before confirmation")
                root.confirmPower()
                fixture.check(mockSddm.reboots === 1, "Confirmed reboot was not dispatched")
                root.requestPower("suspend")
                fixture.check(mockSddm.suspends === 1, "Suspend was not dispatched")
                mockSddm.canSuspend = false
                root.requestPower("suspend")
                fixture.check(mockSddm.suspends === 1, "Unavailable suspend was dispatched")
                mockSddm.canSuspend = true
                picker.currentIndex = 1
                console.log("PASS: wallpaper, session selection, password errors, power confirmation and capabilities")
                if (fixture.argument("--mode") === "session-menu") picker.popup.open()
                else if (fixture.argument("--mode") === "power-confirm") root.requestPower("powerOff")
                capture.start()
            } catch (error) {
                console.error("FAIL:", error.message)
                Qt.exit(1)
            }
        }
    }
    Timer {
        id: capture
        interval: 300
        onTriggered: {
            const output = fixture.argument("--output")
            if (!output) { Qt.quit(); return }
            fixture.contentItem.grabToImage(function(result) {
                if (!result.saveToFile(output)) { console.error("FAIL: saving preview"); Qt.exit(1); return }
                console.log("Preview saved")
                Qt.quit()
            })
        }
    }
    Timer { interval: 8000; running: true; onTriggered: { console.error("FAIL: preview timed out"); Qt.exit(1) } }
}
