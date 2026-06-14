import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Page {
    id: page
    signal navigateToTest()

    background: Rectangle { color: "#f0f4f8" }

    // Single shared player — stopping the previous card's audio when a new one starts
    MediaPlayer {
        id: audioPlayer
        audioOutput: AudioOutput {}
        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState)
                page.currentPlayingPath = ""
        }
    }
    property string currentPlayingPath: ""

    header: Rectangle {
        height: 56
        color: "#2c3e50"
        Label {
            anchors.centerIn: parent
            text: qsTr("Review Expressions")
            font.pixelSize: 18
            font.bold: true
            color: "white"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ── Card swiper ───────────────────────────────────────────────────────
        SwipeView {
            id: swipeView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Stop playback when the user swipes to another card
            onCurrentIndexChanged: {
                audioPlayer.stop()
                page.currentPlayingPath = ""
            }

            Repeater {
                model: setPreviewController.expressionList
                delegate: Item {
                    width: swipeView.width
                    height: swipeView.height

                    readonly property string cardAudioPath: modelData.audioPath

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        height: parent.height - 16
                        radius: 14
                        color: "white"
                        border.color: "#dce1e7"

                        ColumnLayout {
                            anchors { fill: parent; margins: 16 }
                            spacing: 12

                            // Image area
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 160
                                radius: 10
                                color: modelData.imagePath !== "" ? "transparent" : "#eaf4fb"
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    source: modelData.imagePath
                                    visible: modelData.imagePath !== ""
                                }

                                Label {
                                    anchors.centerIn: parent
                                    text: "🖼"
                                    font.pixelSize: 48
                                    visible: modelData.imagePath === ""
                                    opacity: 0.25
                                }
                            }

                            // Expression
                            Label {
                                Layout.fillWidth: true
                                text: modelData.expression
                                font.pixelSize: 24
                                font.bold: true
                                color: "#2c3e50"
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }

                            // Divider
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#eee" }

                            // Hint
                            Label {
                                Layout.fillWidth: true
                                text: modelData.hint
                                font.pixelSize: 17
                                color: "#3498db"
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }

                            // ── Audio playback ────────────────────────────────
                            Button {
                                Layout.alignment: Qt.AlignHCenter
                                visible: modelData.audioPath !== ""
                                implicitWidth: 140; implicitHeight: 38

                                readonly property bool isPlaying:
                                    audioPlayer.playbackState === MediaPlayer.PlayingState &&
                                    page.currentPlayingPath === modelData.audioPath

                                text: isPlaying ? qsTr("■  Stop") : qsTr("▶  Listen")

                                background: Rectangle {
                                    radius: 19
                                    color: parent.isPlaying
                                           ? (parent.pressed ? "#c0392b" : "#e74c3c")
                                           : (parent.pressed ? "#1a6ca8" : "#3498db")
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    if (isPlaying) {
                                        audioPlayer.stop()
                                        page.currentPlayingPath = ""
                                    } else {
                                        audioPlayer.stop()
                                        page.currentPlayingPath = modelData.audioPath
                                        audioPlayer.source = modelData.audioPath
                                        audioPlayer.play()
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
        }

        // ── Page indicator ────────────────────────────────────────────────────
        PageIndicator {
            Layout.alignment: Qt.AlignHCenter
            count: swipeView.count
            currentIndex: swipeView.currentIndex
        }
    }

    footer: Rectangle {
        height: 64
        color: "#2c3e50"

        Button {
            anchors.centerIn: parent
            width: parent.width * 0.7
            height: 44
            text: swipeView.count > 0 ? qsTr("Start Test") : qsTr("No words yet")
            enabled: swipeView.count > 0
            background: Rectangle {
                radius: 22
                color: !parent.enabled ? "#95a5a6"
                     : parent.pressed  ? "#1e8449"
                     : "#27ae60"
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.pixelSize: 17
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: navigateToTest()
        }
    }
}
