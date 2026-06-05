import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import AppController

Page {
    id: page
    signal recSetSelected(idx: int)
    signal addRecSet()
    signal editRecSet(idx: int)

    property int exportSetIdx: -1

    background: Rectangle { color: "#f0f4f8" }

    // ── Export dialogs ────────────────────────────────────────────────────────
    FileDialog {
        id: binaryExportDialog
        title: qsTr("Export as Binary")
        fileMode: FileDialog.SaveFile
        nameFilters: ["Passepartout Set (*.ppset)"]
        defaultSuffix: "ppset"
        onAccepted: {
            AppController.recSetManager.exportSetToBinary(page.exportSetIdx, selectedFile.toString())
        }
    }

    FileDialog {
        id: xmlExportDialog
        title: qsTr("Export as XML")
        fileMode: FileDialog.SaveFile
        nameFilters: ["XML files (*.xml)"]
        defaultSuffix: "xml"
        onAccepted: {
            AppController.recSetManager.exportSetToXml(page.exportSetIdx, selectedFile.toString())
        }
    }

    // ── Header ────────────────────────────────────────────────────────────────
    header: Rectangle {
        height: 64
        color: "#2c3e50"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2
            Label {
                text: "Passepartout"
                font.pixelSize: 22
                font.bold: true
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }
            Label {
                text: qsTr("Your word sets")
                font.pixelSize: 12
                color: "#95a5a6"
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // ── List ──────────────────────────────────────────────────────────────────
    ListView {
        id: listView
        anchors {
            fill: parent
            margins: 12
            bottomMargin: 72
        }
        spacing: 8
        clip: true
        model: AppController.recSetNameList

        delegate: Rectangle {
            id: delegateRect
            width: listView.width
            height: 64
            radius: 10
            color: "white"
            border.color: "#dce1e7"

            // left accent bar
            Rectangle {
                width: 4; height: parent.height
                radius: 2
                color: "#3498db"
                anchors.left: parent.left
            }

            // drop-shadow effect (fake via slightly larger rect underneath)
            layer.enabled: true
            layer.effect: null

            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                spacing: 8

                Label {
                    text: modelData
                    font.pixelSize: 16
                    font.bold: true
                    color: "#2c3e50"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                // ── Context menu ──────────────────────────────────────────────
                Menu {
                    id: contextMenu

                    MenuItem {
                        text: qsTr("Edit")
                        onTriggered: editRecSet(index)
                    }
                    MenuItem {
                        text: qsTr("Delete")
                        onTriggered: {
                            AppController.recSetManager.deleteRecSet(modelData)
                            AppController.saveData()
                            AppController.recSetNameListChanged()
                        }
                    }
                    MenuSeparator {}
                    MenuItem {
                        text: qsTr("Export binary (.ppset)")
                        onTriggered: {
                            page.exportSetIdx = index
                            binaryExportDialog.open()
                        }
                    }
                    MenuItem {
                        text: qsTr("Export XML (.xml)")
                        onTriggered: {
                            page.exportSetIdx = index
                            xmlExportDialog.open()
                        }
                    }
                }

                ToolButton {
                    text: "⋮"
                    font.pixelSize: 22
                    onClicked: contextMenu.popup()
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        contextMenu.popup()
                    } else {
                        recSetSelected(index)
                    }
                }
                onPressAndHold: contextMenu.popup()
            }
        }

        Label {
            anchors.centerIn: parent
            visible: listView.count === 0
            text: qsTr("No word sets yet.\nTap + to create one.")
            horizontalAlignment: Text.AlignHCenter
            color: "#95a5a6"
            font.pixelSize: 16
        }
    }

    // ── FAB ───────────────────────────────────────────────────────────────────
    Rectangle {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 16 }
        width: 180; height: 48
        radius: 24
        color: "#3498db"

        Label {
            anchors.centerIn: parent
            text: qsTr("+ New Set")
            color: "white"
            font.pixelSize: 16
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: addRecSet()
        }
    }
}
