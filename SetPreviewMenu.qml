import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import MediaHelper
import AppController
import SpellingTestController

Page {
    id: page
    signal navigateToTest(int testType)

    // Resolves to whichever controller is active in Main.qml.
    // resetTestProgress / getUnfinishedCount live in BaseTestController and
    // handle any testType parameter regardless of which controller is active.
    property var spellingTestController: rootScope.spellingTestController

    // Incremented each time the popup opens (and after a swipe-reset) to force
    // all "remaining" bindings to re-read from disk even when progressVersion
    // hasn't changed (e.g. navigating back mid-question).
    property int popupRefresh: 0

    background: Rectangle { color: "#f0f4f8" }

    MediaPlayer {
        id: audioPlayer
        audioOutput: AudioOutput {}
        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState)
                page.currentPlayingPath = ""
        }
    }
    property string currentPlayingPath: ""

    // ── Test-type selection popup ─────────────────────────────────────────────
    Popup {
        id: testTypePopup
        anchors.centerIn: Overlay.overlay
        width: Math.min(parent.width - 32, 360)
        padding: 0
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onAboutToShow: page.popupRefresh++

        background: Rectangle { radius: 14; color: "white"; layer.enabled: true }

        contentItem: Column {
            // Title bar
            Rectangle {
                width: testTypePopup.availableWidth
                height: 52
                color: "#2c3e50"
                radius: 14
                // Fill the bottom-half radius so corners look square at the bottom
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 14; color: "#2c3e50"
                }
                Label {
                    anchors.centerIn: parent
                    text: qsTr("Choose Test Type")
                    font.pixelSize: 16; font.bold: true; color: "white"
                }
            }

            // Scrollable test-type list (handles small screens gracefully)
            Flickable {
                id: listFlick
                width: testTypePopup.availableWidth
                // Limit to 80 % of overlay height minus title + cancel rows
                height: Math.min(typeCol.implicitHeight,
                                 (Overlay.overlay ? Overlay.overlay.height * 0.8 : 480) - 52 - 52)
                contentHeight: typeCol.implicitHeight
                clip: true

                Column {
                    id: typeCol
                    width: listFlick.width

                    Repeater {
                        model: [
                            { type: SpellingTestController.TypeA_WriteFromHint,
                              icon: "✍️", title: qsTr("Write the Word"),
                              desc: qsTr("See the hint — type the expression") },
                            { type: SpellingTestController.TypeB_WriteFromWord,
                              icon: "\u21c4 ✍️", title: qsTr("Write the Hint (Reversed)"),
                              desc: qsTr("See the word — type its translation") },
                            { type: SpellingTestController.TypeC_MCFromHint,
                              icon: "🔍", title: qsTr("Pick the Word"),
                              desc: qsTr("See the hint — choose from 4 options") },
                            { type: SpellingTestController.TypeD_MCFromWord,
                              icon: "\u21c4 🔍", title: qsTr("Pick the Hint"),
                              desc: qsTr("See the word — choose from 4 options") },
                            { type: SpellingTestController.TypeE_Leitner,
                              icon: "📚", title: qsTr("Progressive Learning"),
                              desc: qsTr("MC to learn, then write to master all words") },
                            { type: SpellingTestController.TypeF_LeitnerReversed,
                              icon: "⇄ 📚", title: qsTr("Progressive Learning (Reversed)"),
                              desc: qsTr("See the word — pick hint to learn, then type to master") }
                        ]

                        SwipeDelegate {
                            id: swipeRow
                            width: typeCol.width
                            height: 64
                            enabled: swipeView.count > 0
                            clip: true

                            required property var modelData
                            property bool swipeResetDone: false

                            // Full-width background — red normally, green after a successful reset
                            swipe.right: Rectangle {
                                width: swipeRow.width
                                height: swipeRow.height
                                color: swipeRow.swipeResetDone ? "#27ae60" : "#e74c3c"

                                Behavior on color { ColorAnimation { duration: 200 } }

                                Label {
                                    anchors.centerIn: parent
                                    text: swipeRow.swipeResetDone ? qsTr("✓ Done") : qsTr("← Reset")
                                    color: "white"
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            // Swiping all the way left triggers reset and turns the row green
                            swipe.onCompleted: {
                                swipeRow.swipeResetDone = true
                                spellingTestController.resetTestProgress(
                                    AppController.recSetManager,
                                    setPreviewController.currentSetIndex,
                                    swipeRow.modelData.type)
                                page.popupRefresh++
                                Qt.callLater(function() { swipeRow.swipe.close() })
                            }

                            // Once the close animation finishes, restore red for the next attempt
                            swipe.onClosed: swipeRow.swipeResetDone = false

                            background: Rectangle {
                                color: swipeRow.pressed ? "#f0f4f8" : "white"
                                Rectangle {
                                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                    height: 1; color: "#ececec"
                                }
                            }

                            // Wrap in Item so the RowLayout's anchors don't land on contentItem itself
                            contentItem: Item {
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                                    spacing: 10

                                    Label { text: swipeRow.modelData.icon; font.pixelSize: 22 }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Label {
                                            text: swipeRow.modelData.title
                                            font.pixelSize: 13; font.bold: true; color: "#2c3e50"
                                        }
                                        Label {
                                            text: swipeRow.modelData.desc
                                            font.pixelSize: 11; color: "#7f8c8d"
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Label {
                                        id: remainingLabel
                                        property int remaining: {
                                            page.popupRefresh                         // re-evaluate when popup opens / after reset
                                            spellingTestController.progressVersion    // re-evaluate during an active test session
                                            return spellingTestController.getUnfinishedCount(
                                                AppController.recSetManager,
                                                setPreviewController.currentSetIndex,
                                                swipeRow.modelData.type)
                                        }
                                        text:  remaining > 0 ? remaining + " left" : "✓"
                                        color: remaining > 0 ? "#3498db" : "#27ae60"
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            onClicked: {
                                if (swipeRow.swipe.position !== 0) {
                                    swipeRow.swipe.close()
                                    return
                                }
                                testTypePopup.close()
                                page.navigateToTest(swipeRow.modelData.type)
                            }
                        }
                    }
                }
            }

            // Separator + Cancel
            Rectangle { width: testTypePopup.availableWidth; height: 1; color: "#ececec" }
            ItemDelegate {
                width: testTypePopup.availableWidth
                height: 50
                background: Rectangle { color: parent.pressed ? "#f0f4f8" : "white"; radius: 14 }
                contentItem: Text {
                    text: qsTr("Cancel"); color: "#e74c3c"
                    font.pixelSize: 15; font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: testTypePopup.close()
            }
        }
    }

    // ── Header ────────────────────────────────────────────────────────────────
    header: Rectangle {
        height: 56
        color: "#2c3e50"
        Label {
            anchors.centerIn: parent
            text: qsTr("Review Expressions")
            font.pixelSize: 18; font.bold: true
            color: "white"
        }
    }

    // ── Card swiper ───────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        SwipeView {
            id: swipeView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            onCurrentIndexChanged: {
                audioPlayer.stop()
                MediaHelper.stopSpeaking()
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

                            Label {
                                Layout.fillWidth: true
                                text: modelData.expression
                                font.pixelSize: 24; font.bold: true
                                color: "#2c3e50"
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: "#eee" }

                            Label {
                                Layout.fillWidth: true
                                text: modelData.hint
                                font.pixelSize: 17
                                color: "#3498db"
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }

                            Button {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 140; implicitHeight: 38
                                readonly property bool hasFile: modelData.audioPath !== ""
                                readonly property string ttsKey: "tts://" + modelData.expression
                                readonly property bool isPlayingFile:
                                    hasFile &&
                                    audioPlayer.playbackState === MediaPlayer.PlayingState &&
                                    page.currentPlayingPath === modelData.audioPath
                                readonly property bool isSpeaking:
                                    !hasFile && MediaHelper.speaking &&
                                    page.currentPlayingPath === ttsKey
                                readonly property bool isActive: isPlayingFile || isSpeaking

                                text: isActive ? qsTr("■  Stop") : qsTr("▶  Listen")
                                background: Rectangle {
                                    radius: 19
                                    color: parent.isActive
                                        ? (parent.pressed ? "#c0392b" : "#e74c3c")
                                        : (parent.pressed ? "#1a6ca8" : "#3498db")
                                }
                                contentItem: Text {
                                    text: parent.text; color: "white"
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    if (isActive) {
                                        audioPlayer.stop(); MediaHelper.stopSpeaking()
                                        page.currentPlayingPath = ""
                                    } else if (hasFile) {
                                        audioPlayer.stop(); MediaHelper.stopSpeaking()
                                        page.currentPlayingPath = modelData.audioPath
                                        audioPlayer.source = modelData.audioPath
                                        audioPlayer.play()
                                    } else {
                                        audioPlayer.stop(); MediaHelper.stopSpeaking()
                                        page.currentPlayingPath = ttsKey
                                        MediaHelper.speak(modelData.expression, modelData.exprLangID)
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
        }

        PageIndicator {
            Layout.alignment: Qt.AlignHCenter
            count: swipeView.count
            currentIndex: swipeView.currentIndex
        }
    }

    // ── Footer ────────────────────────────────────────────────────────────────
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
                text: parent.text; color: "white"
                font.pixelSize: 17; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: testTypePopup.open()
        }
    }
}
