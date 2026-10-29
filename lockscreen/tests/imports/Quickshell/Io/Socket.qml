import QtQuick
Item {
    property string path
    property var parser
    property bool connected: false
    signal connectionStateChanged()
    signal error()
    onConnectedChanged: connectionStateChanged()
    function write(value) {}
    function flush() {}
}
