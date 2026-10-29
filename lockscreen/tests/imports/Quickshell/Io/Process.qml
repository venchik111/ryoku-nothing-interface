import QtQuick
Item {
    property var command: []
    property var stdout
    property bool running: false
    property var startedCommand: []
    signal exited()
    onRunningChanged: if (running) startedCommand = command.slice()
}
