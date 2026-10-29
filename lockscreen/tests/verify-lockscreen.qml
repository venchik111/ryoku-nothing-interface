import QtQuick
import QtQuick.Window
import "../nothing-interface/i18n"

Window {
    id: fixture
    width: 1280; height: 720; visible: true
    QtObject { id: mockSddm; signal loginFailed(); function login(user, password, session) {} }
    QtObject { id: mockUser; property string lastUser: "test" }
    QtObject { id: mockSessions; property int lastIndex: 0 }
    Loader {
        id: theme
        anchors.fill: parent
        property var sddm: mockSddm
        property var userModel: mockUser
        property var sessionModel: mockSessions
        source: "../nothing-interface/Main.qml"
    }
    Loader { id: live; source: "../nothing-interface/LiveData.qml" }
    function check(condition, message) {
        if (!condition) throw new Error(message)
    }
    function walk(item, callback) {
        callback(item)
        for (const child of item.children || []) walk(child, callback)
    }
    Timer {
        interval: 700; running: true
        onTriggered: {
            try {
                fixture.check(theme.status === Loader.Ready && live.status === Loader.Ready, "Theme/data loading")
                let input = null
                let dateLabel = ""
                fixture.walk(theme.item, function(item) {
                    if (item.echoMode !== undefined) input = item
                    if (item.y === -43) dateLabel = item.text
                })
                fixture.check(input && input.activeFocus, "Password focus")
                fixture.check(dateLabel === Qt.locale().toString(theme.item.now, "dddd, d MMMM"), "Localized date")
                fixture.check(I18n.tr("__missing_key__") === "__missing_key__", "English fallback")
                fixture.check(theme.item.duration(3900) === "1:05", "Neutral duration")
                input.text = "mock"
                mockSddm.loginFailed()
                fixture.check(input.text === "" && theme.item.errorMessage === I18n.tr("Login Failed"), "Failed login reset")

                let playback = null
                live.item.media = {available: true, player: "ryotunes"}
                live.item.togglePlayback()
                fixture.walk(live.item, function(item) {
                    if (item.command && item.command.indexOf("play-pause") >= 0) playback = item
                })
                fixture.check(playback && playback.running, "Playback process started")
                fixture.check(JSON.stringify(playback.startedCommand) === JSON.stringify(["playerctl", "-p", "ryotunes", "play-pause"]), "Displayed player targeted")
                live.item.media = {available: true, player: "browser"}
                live.item.togglePlayback()
                fixture.check(playback.command[2] === "ryotunes", "Running command stays on original player")
                playback.running = false
                live.item.togglePlayback()
                fixture.check(playback.startedCommand[2] === "browser", "Next click targets new displayed player")
                playback.running = false
                live.item.media = {available: true, player: ""}
                live.item.togglePlayback()
                fixture.check(!playback.running, "No untargeted playback command")
                live.item.media = {available: false, player: "browser"}
                live.item.togglePlayback()
                fixture.check(!playback.running, "Unavailable media disabled")
                console.log("BATTERY=" + I18n.tr("BATTERY"))
                console.log("PASS locale, focus, login reset and targeted playback")
                Qt.quit()
            } catch (error) {
                console.error("FAIL", error.message)
                Qt.exit(1)
            }
        }
    }
    Timer { interval: 4000; running: true; onTriggered: Qt.exit(2) }
}
