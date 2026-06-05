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

    background: Rectangle { color: "#f0f4f8" }

    // ── Audio player (one shared instance) ────────────────────────────────────
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
        }
    }

    // ── Header ────────────────────────────────────────────────────────────────
    header: ToolBar {
        height: 56
        background: Rectangle { color: "#2c3e50" }

        RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
            spacing: 4

            // placeholder so title stays centred
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
                spacing: 10

                ListModel { id: recSetModel }

                Repeater {
                    model: recSetModel
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        width: rowsColumn.width
                        height: cardColumn.implicitHeight + 20
                        radius: 10
                        color: "white"
                        border.color: "#dce1e7"

                        Rectangle {
                            width: parent.width; height: 3
                            radius: 10
                            color: "#3498db"
                            anchors.top: parent.top
                        }

                        ColumnLayout {
                            id: cardColumn
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                            spacing: 8

                            // ── Expression / Hint / Context ───────────────────
                            TextField {
                                id: exprField
                                Layout.fillWidth: true
                                placeholderText: qsTr("Expression")
                                text: expression
                                font.pixelSize: 15
                                background: Rectangle {
                                    radius: 6; color: "#f7f9fb"
                                    border.color: exprField.activeFocus ? "#3498db" : "#e0e6ed"
                                }
                                leftPadding: 10
                                onEditingFinished: recSetModel.set(index, { expression: exprField.text })
                            }

                            TextField {
                                id: hintField
                                Layout.fillWidth: true
                                placeholderText: qsTr("Hint / Translation")
                                text: hint
                                font.pixelSize: 15
                                background: Rectangle {
                                    radius: 6; color: "#f7f9fb"
                                    border.color: hintField.activeFocus ? "#3498db" : "#e0e6ed"
                                }
                                leftPadding: 10
                                onEditingFinished: recSetModel.set(index, { hint: hintField.text })
                            }

                            TextField {
                                id: contextField
                                Layout.fillWidth: true
                                placeholderText: qsTr("Context sentence (optional)")
                                text: context
                                font.pixelSize: 13
                                color: "#555"
                                background: Rectangle {
                                    radius: 6; color: "#f7f9fb"
                                    border.color: contextField.activeFocus ? "#3498db" : "#e0e6ed"
                                }
                                leftPadding: 10
                                onEditingFinished: recSetModel.set(index, { context: contextField.text })
                            }

                            // ── Image picker ──────────────────────────────────
                            Image {
                                visible: imagePath !== ""
                                source: imagePath
                                Layout.fillWidth: true
                                height: 90
                                fillMode: Image.PreserveAspectFit
                                Layout.alignment: Qt.AlignHCenter
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Button {
                                    Layout.fillWidth: true
                                    text: imagePath !== "" ? qsTr("Change image") : qsTr("Add image")
                                    font.pixelSize: 13
                                    background: Rectangle {
                                        radius: 6
                                        color: parent.pressed ? "#2980b9" : (imagePath !== "" ? "#27ae60" : "#3498db")
                                    }
                                    contentItem: Text {
                                        text: parent.text; color: "white"; font: parent.font
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: { page.activeCardIndex = index; imagePickerDialog.open() }
                                }

                                Button {
                                    visible: imagePath !== ""
                                    text: qsTr("✕"); font.pixelSize: 13; implicitWidth: 36
                                    background: Rectangle { radius: 6; color: "#e74c3c" }
                                    contentItem: Text {
                                        text: parent.text; color: "white"; font: parent.font
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: recSetModel.set(index, { imagePath: "" })
                                }
                            }

                            // ── Audio picker + preview ────────────────────────
                            Label {
                                visible: audioPath !== ""
                                text: {
                                    var p = audioPath
                                    if (!p) return ""
                                    var parts = p.split("/")
                                    return "♪ " + parts[parts.length - 1]
                                }
                                font.pixelSize: 12
                                color: "#27ae60"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Button {
                                    Layout.fillWidth: true
                                    text: audioPath !== "" ? qsTr("Change audio") : qsTr("Add audio")
                                    font.pixelSize: 13
                                    background: Rectangle {
                                        radius: 6
                                        color: parent.pressed ? "#7f8c8d" : (audioPath !== "" ? "#27ae60" : "#95a5a6")
                                    }
                                    contentItem: Text {
                                        text: parent.text; color: "white"; font: parent.font
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: { page.activeCardIndex = index; audioPickerDialog.open() }
                                }

                                // ── Play / Stop audio preview ─────────────────
                                Button {
                                    visible: audioPath !== ""
                                    implicitWidth: 80; implicitHeight: 36

                                    readonly property bool isPlaying:
                                        audioPlayer.playbackState === MediaPlayer.PlayingState &&
                                        page.currentPlayingPath === audioPath

                                    text: isPlaying ? qsTr("■ Stop") : qsTr("▶ Play")
                                    font.pixelSize: 13

                                    background: Rectangle {
                                        radius: 6
                                        color: parent.isPlaying
                                               ? (parent.pressed ? "#c0392b" : "#e74c3c")
                                               : (parent.pressed ? "#1a6ca8" : "#3498db")
                                    }
                                    contentItem: Text {
                                        text: parent.text; color: "white"; font: parent.font
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
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

                                Button {
                                    visible: audioPath !== ""
                                    text: qsTr("✕"); font.pixelSize: 13; implicitWidth: 36
                                    background: Rectangle { radius: 6; color: "#e74c3c" }
                                    contentItem: Text {
                                        text: parent.text; color: "white"; font: parent.font
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: {
                                        if (page.currentPlayingPath === audioPath)
                                            audioPlayer.stop()
                                        recSetModel.set(index, { audioPath: "" })
                                    }
                                }
                            }

                            // ── Language selectors ────────────────────────────
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Label { text: qsTr("From"); font.pixelSize: 12; color: "#7f8c8d" }
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: LanguageHelper.languageNames()
                                    font.pixelSize: 13
                                    onCurrentIndexChanged: recSetModel.set(index, { languageFrom: currentIndex })
                                    Component.onCompleted: currentIndex = languageFrom
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Label { text: qsTr("To"); font.pixelSize: 12; color: "#7f8c8d" }
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: LanguageHelper.languageNames()
                                    font.pixelSize: 13
                                    onCurrentIndexChanged: recSetModel.set(index, { languageTo: currentIndex })
                                    Component.onCompleted: currentIndex = languageTo
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
                    expression: "", hint: "", context: "", audioPath: "", imagePath: ""
                })
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
                    recSetModel.append({
                        languageFrom: LanguageHelper.NotSelected, languageTo: LanguageHelper.NotSelected,
                        expression: "", hint: "", context: "", audioPath: "", imagePath: ""
                    })
                }
            }

            Button {
                text: qsTr("Remove last")
                enabled: recSetModel.count > 1
                Layout.fillWidth: true
                background: Rectangle {
                    radius: 8
                    color: parent.enabled ? (parent.pressed ? "#c0392b" : "#e74c3c") : "#bbb"
                }
                contentItem: Text {
                    text: parent.text; color: "white"; font: parent.font
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: recSetModel.remove(recSetModel.count - 1)
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
