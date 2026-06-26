import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQml.Models
import AppController
import ShareHelper
import RecSetManager

Page {
    id: page

    // "" = root, "Travel" = inside Travel library, "Travel/Europe" = nested
    property string folderPath: ""

    // Display name shown in the header (last path component)
    readonly property string folderName: {
        if (folderPath === "") return "Passepartout"
        return folderPath.split("/").pop()
    }

    signal recSetSelected(idx: int)
    signal addRecSet()
    signal editRecSet(idx: int)
    signal folderSelected(path: string)
    signal aboutRequested()

    property int exportSetIdx: -1

    // Set by dwell timer (folder item) or parent zone:
    //   "into:FULLPATH"  → drop will move dragged item inside that library
    //   "parent"         → drop will move dragged item to parent directory
    //   ""               → drop will save current reorder
    property string pendingDropAction: ""

    background: Rectangle { color: "#f0f4f8" }

    // ── Local model for drag-and-drop ─────────────────────────────────────────
    ListModel { id: itemModel }

    function refreshModel() {
        itemModel.clear()
        var items = AppController.recSetManager.getFolderItems(page.folderPath)
        for (var i = 0; i < items.length; ++i)
            itemModel.append(items[i])
    }

    Component.onCompleted: refreshModel()

    Connections {
        target: AppController
        function onRecSetNameListChanged() { page.refreshModel() }
    }

    // ── Export dialog ─────────────────────────────────────────────────────────
    FileDialog {
        id: zipExportDialog
        title: qsTr("Export as .ppset")
        fileMode: FileDialog.SaveFile
        nameFilters: ["Passepartout Set (*.ppset)"]
        defaultSuffix: "ppset"
        onAccepted: {
            AppController.recSetManager.exportSetToZip(page.exportSetIdx, selectedFile.toString())
        }
    }

    // ── New Library dialog ────────────────────────────────────────────────────
    Dialog {
        id: newFolderDialog
        title: qsTr("New Library")
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 320)
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel

        ColumnLayout {
            width: parent.width
            spacing: 8
            Label { text: qsTr("Library name:"); color: "#2c3e50" }
            TextField {
                id: folderNameField
                Layout.fillWidth: true
                placeholderText: qsTr("e.g. Travel, Work, School…")
                onAccepted: newFolderDialog.accept()
            }
        }

        onOpened:  { folderNameField.text = ""; folderNameField.forceActiveFocus() }
        onAccepted: {
            var name = folderNameField.text.trim()
            if (name === "") return
            var fullPath = page.folderPath === "" ? name : page.folderPath + "/" + name
            AppController.recSetManager.createFolder(fullPath)
            AppController.saveData()
            page.refreshModel()
        }
    }

    // ── Rename folder dialog ──────────────────────────────────────────────────
    Dialog {
        id: renameFolderDialog
        title: qsTr("Rename Library")
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 320)
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel

        property string targetFullPath: ""

        ColumnLayout {
            width: parent.width
            spacing: 8
            Label { text: qsTr("New name:"); color: "#2c3e50" }
            TextField {
                id: renameFolderField
                Layout.fillWidth: true
                onAccepted: renameFolderDialog.accept()
            }
        }

        onOpened: renameFolderField.forceActiveFocus()
        onAccepted: {
            var newName = renameFolderField.text.trim()
            if (newName === "" || targetFullPath === "") return
            var parentPart = targetFullPath.includes("/")
                ? targetFullPath.substring(0, targetFullPath.lastIndexOf("/"))
                : ""
            var newPath = parentPart === "" ? newName : parentPart + "/" + newName
            AppController.recSetManager.renameFolder(targetFullPath, newPath)
            AppController.saveData()
            page.refreshModel()
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
                text: page.folderName
                font.pixelSize: 22
                font.bold: true
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }
            Label {
                text: page.folderPath === "" ? qsTr("Your word sets") : qsTr("Library")
                font.pixelSize: 12
                color: "#95a5a6"
                Layout.alignment: Qt.AlignHCenter
            }
        }

        ToolButton {
            visible: page.folderPath === ""
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
            text: "ⓘ"
            font.pixelSize: 22
            contentItem: Label {
                text: "ⓘ"
                font.pixelSize: 22
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Item {}
            onClicked: page.aboutRequested()
        }
    }

    // ── Body ──────────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        // "Move to parent" zone — always reserves space when inside a subfolder
        // so the ListView position never jumps when a drag starts.
        Item {
            id: parentZoneContainer
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: page.folderPath !== "" ? 56 : 0
            clip: true

            DropArea {
                id: parentDropArea
                anchors.fill: parent
                enabled: listView.dragActive
                keys: ["x-pp-listitem"]
                onEntered: page.pendingDropAction = "parent"
                onExited:  { if (page.pendingDropAction === "parent") page.pendingDropAction = "" }
            }

            Rectangle {
                anchors { fill: parent; margins: 8 }
                visible: listView.dragActive
                radius: 8
                color: parentDropArea.containsDrag ? "#e8f4fd" : "#eef1f5"
                border.color: parentDropArea.containsDrag ? "#3498db" : "#b0bec5"
                border.width: parentDropArea.containsDrag ? 2 : 1

                Label {
                    anchors.centerIn: parent
                    text: "↑ " + qsTr("Move out of") + " \"" + page.folderName + "\""
                    color: parentDropArea.containsDrag ? "#2980b9" : "#7f8c8d"
                    font.pixelSize: 13
                    font.bold: parentDropArea.containsDrag
                }
            }
        }

        // ── Drag-and-drop list ────────────────────────────────────────────────
        ListView {
            id: listView
            anchors {
                top: parentZoneContainer.bottom
                left: parent.left; right: parent.right; bottom: parent.bottom
                margins: 12
                bottomMargin: 72
            }
            spacing: 8
            clip: true
            interactive: !dragActive

            property bool dragActive: false

            model: DelegateModel {
                id: visualModel
                model: itemModel

                delegate: Item {
                    id: delegateRoot
                    width: listView.width
                    height: 64

                    property int  visualIndex:  DelegateModel.itemsIndex
                    property bool isDropTarget: model.type === "folder" &&
                                               page.pendingDropAction === ("into:" + model.fullPath)

                    // ── Dwell timer for "enter folder" detection ───────────────
                    Timer {
                        id: dwellTimer
                        interval: 600
                        onTriggered: {
                            if (model.type === "folder")
                                page.pendingDropAction = "into:" + model.fullPath
                        }
                    }

                    // ── Drop area ─────────────────────────────────────────────
                    DropArea {
                        anchors.fill: parent
                        keys: ["x-pp-listitem"]

                        onEntered: function(drag) {
                            if (model.type === "folder") {
                                // Don't reorder: wait for dwell to decide "into" vs "past"
                                dwellTimer.restart()
                            } else {
                                // Immediate reorder for set items
                                var from = drag.source.visualIndex
                                var to   = delegateRoot.visualIndex
                                if (from !== to) {
                                    visualModel.items.move(from, to, 1)
                                    itemModel.move(from, to, 1)
                                }
                            }
                        }
                        onExited: {
                            dwellTimer.stop()
                            // If we were in "into" mode for this folder, leaving clears it
                            if (page.pendingDropAction === ("into:" + model.fullPath))
                                page.pendingDropAction = ""
                        }
                    }

                    // ── Card ──────────────────────────────────────────────────
                    Rectangle {
                        id: card
                        width: delegateRoot.width
                        height: 64
                        radius: 10

                        color: {
                            if (dragHandle.held)      return "#e8f0fe"
                            if (delegateRoot.isDropTarget) return "#fff8e1"
                            return "white"
                        }
                        border.color: {
                            if (dragHandle.held)      return "#3498db"
                            if (delegateRoot.isDropTarget) return "#f39c12"
                            return "#dce1e7"
                        }
                        border.width: (dragHandle.held || delegateRoot.isDropTarget) ? 2 : 1

                        Drag.active: dragHandle.held
                        Drag.source: delegateRoot
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2
                        Drag.keys: ["x-pp-listitem"]

                        states: State {
                            when: card.Drag.active
                            ParentChange {
                                target: card
                                parent: listView
                            }
                            AnchorChanges {
                                target: card
                                anchors.horizontalCenter: undefined
                                anchors.verticalCenter: undefined
                            }
                        }

                        // Left accent bar – blue for sets, amber for libraries
                        Rectangle {
                            width: 4; height: parent.height
                            radius: 2
                            color: model.type === "folder" ? "#f39c12" : "#3498db"
                            anchors.left: parent.left
                        }

                        // "Drop to enter" overlay shown on the target folder
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            visible: delegateRoot.isDropTarget
                            color: "#fff8e1"
                            opacity: 0.85
                            z: 2

                            Label {
                                anchors.centerIn: parent
                                text: "→  " + qsTr("Drop to move inside")
                                color: "#e67e22"
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 16; rightMargin: 4 }
                            spacing: 8

                            // Icon
                            Label {
                                text: model.type === "folder" ? "/" : ""
                                font.pixelSize: 20
                            }

                            // Name + word count
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label {
                                    text: model.name
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: "#2c3e50"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Label {
                                    visible: model.type === "set"
                                    text: model.wordCount + " " + qsTr("words")
                                    font.pixelSize: 11
                                    color: "#95a5a6"
                                }
                            }

                            // Context menu ────────────────────────────────────
                            Menu {
                                id: contextMenu

                                // Folder items
                                MenuItem {
                                    visible: model.type === "folder"
                                    height: visible ? implicitHeight : 0
                                    text: qsTr("Rename")
                                    onTriggered: {
                                        renameFolderDialog.targetFullPath = model.fullPath
                                        renameFolderField.text = model.name
                                        renameFolderDialog.open()
                                    }
                                }
                                MenuItem {
                                    visible: model.type === "folder"
                                    height: visible ? implicitHeight : 0
                                    text: qsTr("Delete Library")
                                    onTriggered: {
                                        AppController.recSetManager.deleteFolder(model.fullPath)
                                        AppController.saveData()
                                        page.refreshModel()
                                    }
                                }
                                MenuSeparator { visible: model.type === "folder"; height: visible ? implicitHeight : 0 }

                                // Set items
                                MenuItem {
                                    visible: model.type === "set"
                                    height: visible ? implicitHeight : 0
                                    text: qsTr("Edit")
                                    onTriggered: editRecSet(model.index)
                                }
                                MenuItem {
                                    visible: model.type === "set"
                                    height: visible ? implicitHeight : 0
                                    text: qsTr("Delete")
                                    onTriggered: {
                                        AppController.recSetManager.deleteRecSet(model.name)
                                        AppController.saveData()
                                        AppController.recSetNameListChanged()
                                    }
                                }
                                MenuSeparator { visible: model.type === "set"; height: visible ? implicitHeight : 0 }
                                MenuItem {
                                    visible: model.type === "set"
                                    height: visible ? implicitHeight : 0
                                    enabled: Qt.platform.os === "android"
                                    text: qsTr("Share .ppset file")
                                    onTriggered: {
                                        var path = ShareHelper.shareableExportPath(model.name)
                                        AppController.recSetManager.exportSetToZip(model.index, path)
                                        ShareHelper.shareFile(path, model.name)
                                    }
                                }
                                MenuSeparator { visible: model.type === "set"; height: visible ? implicitHeight : 0 }
                                MenuItem {
                                    visible: model.type === "set"
                                    height: visible ? implicitHeight : 0
                                    text: qsTr("Export .ppset (save to disk)")
                                    onTriggered: {
                                        page.exportSetIdx = model.index
                                        zipExportDialog.open()
                                    }
                                }
                            }

                            ToolButton {
                                text: "⋮"
                                font.pixelSize: 22
                                onClicked: contextMenu.popup()
                            }

                            // Drag handle ─────────────────────────────────────
                            Item {
                                width: 32; height: parent.height

                                MouseArea {
                                    id: dragHandle
                                    anchors.fill: parent
                                    property bool held: false

                                    drag.target: held ? card : undefined
                                    drag.axis: Drag.YAxis

                                    onPressed: {
                                        held = true
                                        listView.dragActive = true
                                    }
                                    onReleased: {
                                        var myIndex = delegateRoot.visualIndex
                                        card.Drag.drop()
                                        held = false
                                        listView.dragActive = false

                                        var action = page.pendingDropAction
                                        page.pendingDropAction = ""
                                        dwellTimer.stop()

                                        if (action.startsWith("into:")) {
                                            var targetFolder = action.substring(5)
                                            var itm = itemModel.get(myIndex)
                                            if (itm.type === "folder") {
                                                AppController.recSetManager.moveFolderToFolder(
                                                    itm.fullPath, targetFolder)
                                            } else {
                                                AppController.recSetManager.moveSetToFolder(
                                                    itm.index, targetFolder)
                                            }
                                            AppController.saveData()
                                            AppController.recSetNameListChanged()
                                        } else if (action === "parent") {
                                            var parentPath = page.folderPath.includes("/")
                                                ? page.folderPath.substring(
                                                      0, page.folderPath.lastIndexOf("/"))
                                                : ""
                                            var itm2 = itemModel.get(myIndex)
                                            if (itm2.type === "folder") {
                                                AppController.recSetManager.moveFolderToFolder(
                                                    itm2.fullPath, parentPath)
                                            } else {
                                                AppController.recSetManager.moveSetToFolder(
                                                    itm2.index, parentPath)
                                            }
                                            AppController.saveData()
                                            AppController.recSetNameListChanged()
                                        } else {
                                            saveOrder()
                                        }
                                    }
                                }

                                // ≡ icon — three lines
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Repeater {
                                        model: 3
                                        Rectangle { width: 16; height: 2; color: "#b0bec5"; radius: 1 }
                                    }
                                }
                            }
                        }

                        // Tap handler — covers card except the ⋮ button + drag handle
                        MouseArea {
                            anchors {
                                fill: parent
                                rightMargin: 80
                            }
                            onClicked: {
                                if (model.type === "folder")
                                    folderSelected(model.fullPath)
                                else
                                    recSetSelected(model.index)
                            }
                        }
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: itemModel.count === 0
                text: qsTr("Nothing here yet.\nTap + Create to add a word set or library.")
                horizontalAlignment: Text.AlignHCenter
                color: "#95a5a6"
                font.pixelSize: 15
            }
        }
    }

    // Persist the visual order back to C++
    function saveOrder() {
        var keys = []
        for (var i = 0; i < itemModel.count; ++i) {
            var item = itemModel.get(i)
            keys.push(item.type === "folder" ? "folder:" + item.fullPath : "set:" + item.name)
        }
        AppController.recSetManager.reorderFolderItems(page.folderPath, keys)
        AppController.saveData()
    }

    // ── "+ Create" FAB ────────────────────────────────────────────────────────
    Menu {
        id: createMenu
        MenuItem {
            text: qsTr("Word Set")
            onTriggered: page.addRecSet()
        }
        MenuItem {
            text: qsTr("Library")
            onTriggered: newFolderDialog.open()
        }
    }

    Rectangle {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 16 }
        width: 160; height: 48
        radius: 24
        color: "#3498db"

        Label {
            anchors.centerIn: parent
            text: qsTr("+ Create")
            color: "white"
            font.pixelSize: 16
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: createMenu.popup()
        }
    }
}
