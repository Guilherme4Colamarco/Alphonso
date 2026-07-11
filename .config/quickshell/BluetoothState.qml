pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: state

    property bool visible: false
    property var parentWindow: null
    property int popupX: 0
    property int popupY: 0
    property bool power: false
    property var devices: []

    function show(win, x, y) {
        parentWindow = win
        popupX = x
        popupY = y
        visible = true
    }

    function hide() {
        visible = false
        parentWindow = null
    }

    function toggle(win, x, y) {
        if (visible) hide()
        else show(win, x, y)
    }

    function closeAll() {
        hide()
    }
}