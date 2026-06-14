import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia
import LanguageHelper
import AppController

Page {
    id: page
    signal creatingRecSetCancel()
    signal creatingRecSetSave()
    property alias recSetModelRef: recSetModel
    property alias recSetName: topTextField.text
    property int recSetIdx: -1
    property int activeCardIndex: -1
    property int selectedCardIndex: 0

    background: Rectangle { color: "#f0f4f8" }

    // ── Audio player ──────────────────────────────────────────────────────────
    MediaPlayer {
        id: audioPlayer
        audioOutput: AudioOutput {}
        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState)
                page.currentPlayingPath = ""
        }
    }
    property string currentPlayingPath: ""

    // ── File dialogs ──────────────────────────────────────────────────────────
    FileDialog {
        id: imagePickerDialog
        title: qsTr("Select Image")
        nameFilters: ["Images (*.jpg *.jpeg *.png *.gif *.bmp *.webp)"]
        onAccepted: {
            if (page.activeCardIndex >= 0)
                recSetModel.set(page.activeCardIndex, { imagePath: selectedFile.toString() })
        }
    }

    FileDialog {
        id: audioPickerDialog
        title: qsTr("Select Audio")
        nameFilters: ["Audio (*.mp3 *.ogg *.wav *.m4a *.aac *.flac *.opus)"]
        onAccepted: {
            if (page.activeCardIndex >= 0)
                recSetModel.set(page.activeCardIndex, { audioPath: selectedFile.toString() })
        }
    }

    FileDialog {
        id: importDialog
        title: qsTr("Import Word Set")
        nameFilters: ["Passepartout Set (*.ppset)", "XML files (*.xml)", "All files (*)"]
        onAccepted: {
            var path = selectedFile.toString()
            var result
            if (path.endsWith(".ppset"))
                result = AppController.recSetManager.readSetFromBinary(path)
            else
                result = AppController.recSetManager.readSetFromXml(path)

            if (!result || !result.name) return

            topTextField.text = result.name
            recSetModel.clear()
            var wordList = result.words
            for (var i = 0; i < wordList.length; i++) {
                recSetModel.append(wordList[i])
            }
            page.selectedCardIndex = Math.max(0, recSetModel.count - 1)
        }
    }

    // ── Header ────────────────────────────────────────────────────────────────
    header: ToolBar {
        height: 56
        background: Rectangle { color: "#2c3e50" }

        RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
            spacing: 4

            Item { implicitWidth: 76 }

            Label {
                Layout.fillWidth: true
                text: page.recSetIdx === -1 ? qsTr("New Word Set") : qsTr("Edit Word Set")
                font.pixelSize: 18
                font.bold: true
                color: "white"
                horizontalAlignment: Text.AlignHCenter
            }

            Button {
                implicitWidth: 76
                implicitHeight: 36
                text: qsTr("Import")
                background: Rectangle {
                    radius: 8
                    color: parent.pressed ? "#1a6ca8" : "#3498db"
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 13
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: importDialog.open()
            }
        }
    }

    // ── Body ──────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        TextField {
            id: topTextField
            Layout.fillWidth: true
            font.pixelSize: 17
            placeholderText: qsTr("Set title…")
            background: Rectangle {
                radius: 8
                color: "white"
                border.color: topTextField.activeFocus ? "#3498db" : "#dce1e7"
                border.width: topTextField.activeFocus ? 2 : 1
            }
            leftPadding: 12
        }

        ScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                id: rowsColumn
                width: scrollView.width
                height: implicitHeight
                spacing: 10

                ListModel { id: recSetModel }

                Repeater {
                    model: recSetModel
                    delegate: Rectangle {
                        id: cardRect
                        Layout.fillWidth: true
                        width: rowsColumn.width
                        Layout.preferredHeight: cardColumn.implicitHeight + 24
                        implicitHeight: cardColumn.implicitHeight + 24

                        radius: 10
                        color: "white"
                        border.color: page.selectedCardIndex === index ? "#3498db" : "#dce1e7"
                        border.width: page.selectedCardIndex === index ? 2 : 1

                        // Blue top accent bar
                        Rectangle {
                            width: parent.width; height: 3
                            radius: 10
                            color: "#3498db"
                            anchors.top: parent.top
                        }

                        ColumnLayout {
                            id: cardColumn
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 10

                            // ── Card header: word number + tap-to-select ──────
                            Rectangle {
                                Layout.fillWidth: true
                                height: 24
                                color: "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    Label {
                                        text: qsTr("Word") + " " + (index + 1)
                                        font.pixelSize: 11
                                        color: "#95a5a6"
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        visible: page.selectedCardIndex === index
                                        text: qsTr("selected")
                                        font.pixelSize: 10
                                        color: "#3498db"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: page.selectedCardIndex = index
                                }
                            }

                            // ── Word / Term ───────────────────────────────────
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label {
                                    text: qsTr("Word / Term")
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#2c3e50"
                                    Layout.fillWidth: true
                                }
                                ComboBox {
                                    id: langFromCombo
                                    implicitWidth: 138
                                    implicitHeight: 30
                                    model: LanguageHelper.languageNames()
                                    font.pixelSize: 11
                                    onCurrentIndexChanged: recSetModel.set(index, { languageFrom: currentIndex })
                                    Component.onCompleted: currentIndex = languageFrom
                                }
                            }
                            TextField {
                                id: exprField
                                Layout.fillWidth: true
                                placeholderText: qsTr("Enter word...")
                                text: expression
                                font.pixelSize: 15
                                background: Rectangle {
                                    radius: 6; color: "#f7f9fb"
                                    border.color: exprField.activeFocus ? "#3498db" : "#e0e6ed"
                                }
                                leftPadding: 10
                                onActiveFocusChanged: if (activeFocus) page.selectedCardIndex = index
                                onEditingFinished: recSetModel.set(index, { expression: exprField.text })
                            }

                            // ── Hint / meaning ──────────────────────────
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label {
                                    text: qsTr("Hint / meaning")
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#2c3e50"
                                    Layout.fillWidth: true
                                }
                                ComboBox {
                                    id: langToCombo
                                    implicitWidth: 138
                                    implicitHeight: 30
                                    model: LanguageHelper.languageNames()
                                    font.pixelSize: 11
                                    onCurrentIndexChanged: recSetModel.set(index, { languageTo: currentIndex })
                                    Component.onCompleted: currentIndex = languageTo
                                }
                            }
                            TextField {
                                id: hintField
                                Layout.fillWidth: true
                                placeholderText: qsTr("Hint, definition...")
                                text: hint
                                font.pixelSize: 15
                                background: Rectangle {
                                    radius: 6; color: "#f7f9fb"
                                    border.color: hintField.activeFocus ? "#3498db" : "#e0e6ed"
                                }
                                leftPadding: 10
                                onActiveFocusChanged: if (activeFocus) page.selectedCardIndex = index
                                onEditingFinished: recSetModel.set(index, { hint: hintField.text })
                            }

                            // ── Image preview — height adapts to aspect ratio ──
                            // Layout.preferredHeight (not height:) is what ColumnLayout
                            // actually uses; height: is ignored on layout-managed children.
                            Image {
                                id: imagePreview
                                visible: imagePath !== ""
                                source: imagePath
                                Layout.fillWidth: true
                                Layout.preferredHeight: (sourceSize.width > 0 && cardColumn.width > 0)
                                    ? Math.min(cardColumn.width * sourceSize.height / sourceSize.width, 260)
                                    : 0
                                fillMode: Image.PreserveAspectFit
                            }

                            // ── Image & Audio boxes ───────────────────────────
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                // Image box
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 72
                                    radius: 8
                                    color: "#f7f9fb"
                                    border.color: "#c8d6e5"
                                    border.width: 1

                                    // Picker tap target — declared FIRST so buttons above it in Z capture clicks first
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            page.selectedCardIndex = index
                                            page.activeCardIndex   = index
                                            imagePickerDialog.open()
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Label {
                                            text: imagePath !== "" ? qsTr("Change image") : qsTr("Add image")
                                            font.pixelSize: 11
                                            color: imagePath !== "" ? "#27ae60" : "#95a5a6"
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }

                                    // Remove image button — above picker MouseArea in Z
                                    Rectangle {
                                        visible: imagePath !== ""
                                        width: 20; height: 20
                                        radius: 10
                                        color: "#e74c3c"
                                        anchors { top: parent.top; right: parent.right; margins: 4 }
                                        Label {
                                            text: "x"; color: "white"; font.pixelSize: 12
                                            anchors.centerIn: parent
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: recSetModel.set(index, { imagePath: "" })
                                        }
                                    }
                                }

                                // Audio box
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 72
                                    radius: 8
                                    color: "#f7f9fb"
                                    border.color: "#c8d6e5"
                                    border.width: 1

                                    // Picker tap target — FIRST (lowest Z); buttons above intercept their own clicks
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            page.selectedCardIndex = index
                                            page.activeCardIndex   = index
                                            audioPickerDialog.open()
                                        }
                                    }

                                    // Filename label + centered play/stop button
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Label {
                                            text: {
                                                if (audioPath === "") return qsTr("Add audio")
                                                var parts = audioPath.split("/")
                                                var name = parts[parts.length - 1]
                                                return name.length > 16 ? name.substring(0, 14) + "…" : name
                                            }
                                            font.pixelSize: 11
                                            color: audioPath !== "" ? "#27ae60" : "#95a5a6"
                                            Layout.alignment: Qt.AlignHCenter
                                            wrapMode: Text.NoWrap
                                        }

                                        // Play / Stop button — centered, only when audio is set
                                        Button {
                                            visible: audioPath !== ""
                                            Layout.alignment: Qt.AlignHCenter
                                            implicitWidth: 52; implicitHeight: 26

                                            readonly property bool isPlaying:
                                                audioPlayer.playbackState === MediaPlayer.PlayingState &&
                                                page.currentPlayingPath === audioPath

                                            text: isPlaying ? qsTr("■ Stop") : qsTr("▶ Play")
                                            font.pixelSize: 10

                                            background: Rectangle {
                                                radius: 13
                                                color: parent.isPlaying
                                                    ? (parent.pressed ? "#c0392b" : "#e74c3c")
                                                    : (parent.pressed ? "#1a6ca8" : "#3498db")
                                            }
                                            contentItem: Text {
                                                text: parent.text; color: "white"; font: parent.font
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            onClicked: {
                                                if (isPlaying) {
                                                    audioPlayer.stop()
                                                    page.currentPlayingPath = ""
                                                } else {
                                                    audioPlayer.stop()
                                                    page.currentPlayingPath = audioPath
                                                    audioPlayer.source = audioPath
                                                    audioPlayer.play()
                                                }
                                            }
                                        }
                                    }

                                    // Remove audio — top-right corner, same style as image remove button
                                    Rectangle {
                                        visible: audioPath !== ""
                                        width: 20; height: 20
                                        radius: 10
                                        color: "#e74c3c"
                                        anchors { top: parent.top; right: parent.right; margins: 4 }
                                        Label {
                                            text: "x"; color: "white"; font.pixelSize: 12
                                            anchors.centerIn: parent
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (page.currentPlayingPath === audioPath)
                                                    audioPlayer.stop()
                                                recSetModel.set(index, { audioPath: "" })
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component.onCompleted: {
                recSetModel.append({
                    languageFrom: LanguageHelper.NotSelected,
                    languageTo:   LanguageHelper.NotSelected,
                    expression: "", hint: "", audioPath: "", imagePath: ""
                })
                page.selectedCardIndex = 0
            }
        }

        // ── Add / Remove ──────────────────────────────────────────────────────
        RowLayout {
            spacing: 8

            Button {
                text: qsTr("+ Add word")
                Layout.fillWidth: true
                background: Rectangle { radius: 8; color: parent.pressed ? "#2980b9" : "#3498db" }
                contentItem: Text {
                    text: parent.text; color: "white"; font: parent.font
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    var lastLangFrom = LanguageHelper.NotSelected
                    var lastLangTo   = LanguageHelper.NotSelected
                    if (recSetModel.count > 0) {
                        var last = recSetModel.get(recSetModel.count - 1)
                        lastLangFrom = last.languageFrom
                        lastLangTo   = last.languageTo
                    }
                    recSetModel.append({
                        languageFrom: lastLangFrom,
                        languageTo:   lastLangTo,
                        expression: "", hint: "", audioPath: "", imagePath: ""
                    })
                    page.selectedCardIndex = recSetModel.count - 1
                }
            }

            Button {
                text: qsTr("Remove")
                enabled: recSetModel.count > 0
                Layout.fillWidth: true
                background: Rectangle {
                    radius: 8
                    color: parent.enabled ? (parent.pressed ? "#c0392b" : "#e74c3c") : "#bbb"
                }
                contentItem: Text {
                    text: parent.text; color: "white"; font: parent.font
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    var idx = page.selectedCardIndex
                    if (idx >= 0 && idx < recSetModel.count) {
                        if (page.currentPlayingPath !== "" &&
                                recSetModel.get(idx).audioPath === page.currentPlayingPath)
                            audioPlayer.stop()
                        recSetModel.remove(idx)
                        page.selectedCardIndex = Math.min(idx, recSetModel.count - 1)
                    }
                }
            }
        }
    }

    // ── Footer ────────────────────────────────────────────────────────────────
    footer: Rectangle {
        height: footerRow.implicitHeight + 24
        color: "#2c3e50"

        RowLayout {
            id: footerRow
            anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 12; bottomMargin: 12 }
            spacing: 12

            Button {
                text: qsTr("Save")
                Layout.fillWidth: true
                background: Rectangle { radius: 8; color: parent.pressed ? "#1e8449" : "#27ae60" }
                contentItem: Text {
                    text: parent.text; color: "white"; font.pixelSize: 16; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: creatingRecSetSave()
            }

            Button {
                text: qsTr("Cancel")
                Layout.fillWidth: true
                background: Rectangle { radius: 8; color: parent.pressed ? "#555" : "#7f8c8d" }
                contentItem: Text {
                    text: parent.text; color: "white"; font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: creatingRecSetCancel()
            }
        }
    }
}
