import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: root
    signal getResults()
    signal flashCardExit()  // emitted by the close (✕) button, mid-review

    property var flashCardController: rootScope.spellingTestController

    // 1-based position of the card currently on screen within this session
    readonly property int currentPosition:
        flashCardController.correctAnswers + flashCardController.unknownCount + 1

    Component.onCompleted: {
        if (flashCardController.isTestComplete())
            Qt.callLater(function() { root.getResults() })
    }

    function commitDecision(known) {
        if (known)
            flashCardController.markKnown()
        else
            flashCardController.markUnknown()
        swipeWrapper.dragOffset = 0
        if (flashCardController.testComplete)
            root.getResults()
    }

    background: Rectangle { color: "#f0f4f8" }

    // ── Header ─────────────────────────────────────────────────────────────────
    header: Rectangle {
        height: 56 + SafeArea.margins.top
        color: "#2c3e50"

        RowLayout {
            anchors {
                left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: 12; rightMargin: 12; bottomMargin: 6
            }
            height: 40
            spacing: 4

            ToolButton {
                implicitWidth: 40; implicitHeight: 40
                background: Item {}
                contentItem: Text {
                    text: "x"
                    color: "white"
                    font.pixelSize: 20
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.flashCardExit()
            }

            Label {
                Layout.fillWidth: true
                text: root.currentPosition + " / " + flashCardController.totalQuestions
                font.pixelSize: 15; font.bold: true
                color: "white"
                horizontalAlignment: Text.AlignHCenter
            }

            // Balances the close button so the counter stays centred
            Item { implicitWidth: 40 }
        }
    }

    // ── Body ───────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Progress through this session's queue — words already decided out
        // of the words queued up for review this session.
        ProgressBar {
            id: sessionProgressBar
            Layout.fillWidth: true
            from: 0
            to: Math.max(flashCardController.totalQuestions, 1)
            value: flashCardController.correctAnswers + flashCardController.unknownCount
            background: Rectangle { radius: 4; color: "#dce1e7"; implicitHeight: 6 }
            contentItem: Item {
                implicitHeight: 6
                clip: true
                Rectangle {
                    width: sessionProgressBar.visualPosition * parent.width
                    height: parent.height
                    radius: 4
                    color: "#3498db"
                }
            }
        }

        // ── Known / unknown counters — this session only ────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Rectangle {
                implicitWidth: 44; implicitHeight: 28
                radius: 14
                color: "transparent"
                border.color: "#e74c3c"; border.width: 2
                Label {
                    anchors.centerIn: parent
                    text: flashCardController.unknownCount
                    color: "#e74c3c"
                    font.bold: true
                    font.pixelSize: 14
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: 44; implicitHeight: 28
                radius: 14
                color: "transparent"
                border.color: "#27ae60"; border.width: 2
                Label {
                    anchors.centerIn: parent
                    text: flashCardController.correctAnswers
                    color: "#27ae60"
                    font.bold: true
                    font.pixelSize: 14
                }
            }
        }

        // ── Card ───────────────────────────────────────────────────────────────
        // swipeWrapper handles the left/right "know / don't know" drag gesture;
        // the Flipable nested inside it handles the independent tap-to-flip
        // front/back rotation. The two transforms (translate+tilt vs. 3D flip)
        // apply to different items so they don't fight each other.
        Item {
            id: cardArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                id: swipeWrapper
                anchors.fill: parent
                property real dragOffset: 0

                transform: [
                    Translate { x: swipeWrapper.dragOffset },
                    Rotation {
                        angle: swipeWrapper.dragOffset / 20
                        origin.x: swipeWrapper.width / 2
                        origin.y: swipeWrapper.height / 2
                    }
                ]

                Behavior on dragOffset {
                    enabled: !dragArea.pressed
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                Flipable {
                    id: flipable
                    anchors.fill: parent

                    // Front: the clue side — picture, hint and example usage.
                    front: Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: "white"
                        border.width: 2
                        border.color: swipeWrapper.dragOffset > 30 ? "#27ae60"
                                    : swipeWrapper.dragOffset < -30 ? "#e74c3c"
                                    : "#dce1e7"

                        ColumnLayout {
                            anchors { fill: parent; margins: 20 }
                            spacing: 14

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 90
                                radius: 10
                                color: "transparent"
                                clip: true
                                visible: flashCardController.currentImageUrl !== ""

                                Image {
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectFit
                                    source: flashCardController.currentImageUrl
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: flashCardController.currentHint
                                font.pixelSize: 22
                                color: "#3498db"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                Layout.fillWidth: true
                                text: flashCardController.currentExampleUsage
                                visible: flashCardController.currentExampleUsage !== ""
                                font.italic: true
                                font.pixelSize: 13
                                color: "#7f8c8d"
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                Layout.fillWidth: true
                                text: qsTr("Tap to flip")
                                font.pixelSize: 13
                                color: "#95a5a6"
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // Back: the answer side — the word itself.
                    // No manual counter-rotation here: Flipable already keeps the
                    // back side's own transform correct internally, so adding one
                    // ourselves double-flips it and mirrors the text.
                    back: Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: "white"
                        border.width: 2
                        border.color: swipeWrapper.dragOffset > 30 ? "#27ae60"
                                    : swipeWrapper.dragOffset < -30 ? "#e74c3c"
                                    : "#dce1e7"

                        ColumnLayout {
                            anchors { fill: parent; margins: 20 }
                            spacing: 14

                            Label {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: flashCardController.currentWord
                                font.pixelSize: 28; font.bold: true
                                color: "#2c3e50"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                Layout.fillWidth: true
                                text: qsTr("Tap to flip back")
                                font.pixelSize: 13
                                color: "#95a5a6"
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    transform: Rotation {
                        id: flipRotation
                        origin.x: flipable.width / 2
                        origin.y: flipable.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: flashCardController.isRevealed ? 180 : 0

                        Behavior on angle {
                            NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                Label {
                    text: qsTr("KNOW")
                    color: "#27ae60"
                    font.bold: true
                    font.pixelSize: 24
                    rotation: -14
                    opacity: Math.max(0, Math.min(swipeWrapper.dragOffset / 90, 1))
                    anchors { top: parent.top; left: parent.left; margins: 18 }
                }
                Label {
                    text: qsTr("SKIP")
                    color: "#e74c3c"
                    font.bold: true
                    font.pixelSize: 24
                    rotation: 14
                    opacity: Math.max(0, Math.min(-swipeWrapper.dragOffset / 90, 1))
                    anchors { top: parent.top; right: parent.right; margins: 18 }
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    property real pressX: 0
                    property real filteredX: 0
                    property bool moved: false

                    onPressed: function(mouse) {
                        pressX = mouse.x
                        moved = false
                    }
                    onPositionChanged: function(mouse) {
                        var delta = mouse.x - pressX
                        if (!moved && Math.abs(delta) > 6) {
                            moved = true
                            filteredX = delta  // seed so the card doesn't jump when dragging starts
                        }
                        if (moved) {
                            // Low-pass filter: raw touch coordinates are noisy by a
                            // few pixels even from a finger held still, and feeding
                            // that noise straight into the tilt transform reads as
                            // a visible tremble. Chase the real position smoothly
                            // instead of snapping straight to it.
                            filteredX += (delta - filteredX) * 0.25
                            swipeWrapper.dragOffset = filteredX
                        }
                    }
                    onReleased: {
                        if (!moved) {
                            flashCardController.toggleReveal()
                            swipeWrapper.dragOffset = 0
                            return
                        }
                        if (swipeWrapper.dragOffset > cardArea.width * 0.28)
                            root.commitDecision(true)
                        else if (swipeWrapper.dragOffset < -cardArea.width * 0.28)
                            root.commitDecision(false)
                        else
                            swipeWrapper.dragOffset = 0
                    }
                }
            }
        }

        // ── Know / Don't know buttons ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                Layout.fillWidth: true
                text: qsTr("x  Don't know")
                background: Rectangle { radius: 22; color: parent.pressed ? "#c0392b" : "#e74c3c" }
                contentItem: Text {
                    text: parent.text; color: "white"
                    font.pixelSize: 15; font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.commitDecision(false)
            }

            Button {
                Layout.fillWidth: true
                text: qsTr("✓  Know")
                background: Rectangle { radius: 22; color: parent.pressed ? "#1e8449" : "#27ae60" }
                contentItem: Text {
                    text: parent.text; color: "white"
                    font.pixelSize: 15; font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.commitDecision(true)
            }
        }
    }

    // ── Footer — undo the last decision ─────────────────────────────────────────
    footer: Rectangle {
        height: 64 + SafeArea.margins.bottom
        color: "#2c3e50"

        Button {
            id: undoButton
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top; topMargin: (64 - height) / 2
            }
            width: 56; height: 44
            enabled: flashCardController.canUndo
            background: Rectangle {
                radius: 22
                color: !undoButton.enabled ? "#4a6070" : (undoButton.pressed ? "#2980b9" : "#3498db")
            }
            contentItem: Text {
                text: "<"
                color: undoButton.enabled ? "white" : "#8fa7b8"
                font.pixelSize: 20
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: flashCardController.undoLast()
        }
    }
}
