import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import AppController

Page {
    id: page
    signal startRuleTest(idx: int)

    property int ruleSetIdx: -1
    property string setName: ""
    // { blocks: [ {kind:"text",value} | {kind:"image",value,imgHeight} |
    //             {kind:"audio",value}, ... ] } — rendered in that order.
    property var theory: ({})
    property int questionCount: 0
    readonly property var theoryBlocks: theory.blocks || []

    MediaPlayer {
        id: audioPlayer
        audioOutput: AudioOutput {}
        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState)
                page.playingPath = ""
        }
    }
    property string playingPath: ""

    // Stable handle to the rule controller itself (see
    // rootScope.ruleTestControllerRef in Main.qml) — initializing it here
    // (rather than only when "Start Test" is pressed) lets this screen show
    // real progress and reset it up front. Also repoints the shared "active
    // test controller" slot RuleTest.qml/Results.qml read from, so it's
    // already correct by the time "Start Test" pushes that page.
    readonly property var ruleTestController: rootScope.ruleTestControllerRef

    Component.onCompleted: {
        rootScope.spellingTestController = ruleTestController
        ruleTestController.initialize(AppController.ruleSetManager, page.ruleSetIdx)
    }

    background: Rectangle { color: "#f0f4f8" }

    header: Rectangle {
        height: 56 + SafeArea.margins.top
        color: "#2c3e50"
        Label {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom; bottomMargin: (56 - implicitHeight) / 2
            }
            text: page.setName
            font.pixelSize: 18; font.bold: true
            color: "white"
        }
    }

    // ── Reset confirmation ───────────────────────────────────────────────────
    Dialog {
        id: resetConfirmDialog
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 320)
        modal: true
        standardButtons: Dialog.Yes | Dialog.No
        title: qsTr("Reset Test Progress?")

        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            text: qsTr("This clears your progress on this rule set and starts a fresh session.")
        }

        onAccepted: {
            ruleTestController.resetTestProgress()
        }
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 16
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 12

            // ── Progress + Reset — same white rounded card, row style
            // (ItemDelegate with a pressed-state fill, a 1px "#ececec"
            // separator) as Choose Test Type's popup uses for its list rows
            // and Cancel button. ─────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: progressCardColumn.implicitHeight
                radius: 14
                color: "white"
                border.color: "#dce1e7"
                clip: true

                ColumnLayout {
                    id: progressCardColumn
                    width: parent.width
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.margins: 14
                        Label {
                            Layout.fillWidth: true
                            // "Next question" while there's still one to
                            // answer, rather than a static total — more
                            // useful when picking this set back up mid-test.
                            // Once it's done, there's no "next" to point at.
                            text: ruleTestController.testComplete
                                ? qsTr("Test is completed")
                                : qsTr("Next question: #%1").arg(ruleTestController.currentPosition)
                            font.pixelSize: 13
                            color: "#7f8c8d"
                        }
                        Label {
                            visible: ruleTestController.totalQuestions > 0
                            text: qsTr("Correct: %1 / %2")
                                .arg(ruleTestController.correctAnswers)
                                .arg(ruleTestController.totalQuestions)
                            font.pixelSize: 12
                            color: ruleTestController.testComplete ? "#27ae60" : "#3498db"
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#ececec" }

                    ItemDelegate {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        background: Rectangle { color: parent.pressed ? "#f0f4f8" : "white" }
                        contentItem: Text {
                            text: qsTr("← Reset")
                            color: "#e74c3c"
                            font.pixelSize: 15; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: resetConfirmDialog.open()
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("Rule Explanation")
                font.pixelSize: 15
                font.bold: true
                color: "#2c3e50"
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: theoryColumn.implicitHeight + 24
                radius: 14
                color: "white"
                border.color: "#dce1e7"

                ColumnLayout {
                    id: theoryColumn
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 10

                    Label {
                        Layout.fillWidth: true
                        visible: page.theoryBlocks.length === 0
                        text: qsTr("No explanation was added for this set.")
                        color: "#95a5a6"
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                    }

                    // Text/photo/audio blocks in the exact order the creator
                    // arranged them in. A single delegate with
                    // visible-toggled children, rather than a Loader
                    // swapping components — Loader's implicit resize-to-item
                    // behavior doesn't respect Layout.* size hints on the
                    // loaded item, which left images collapsed to 0x0 and
                    // invisible.
                    Repeater {
                        model: page.theoryBlocks
                        delegate: Item {
                            id: blockDelegate
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: blockDelegate.modelData.kind === "image" ? (blockDelegate.modelData.imgHeight || 200)
                                : blockDelegate.modelData.kind === "audio" ? blockAudioRow.implicitHeight
                                : blockTextLabel.implicitHeight

                            Label {
                                id: blockTextLabel
                                visible: blockDelegate.modelData.kind === "text"
                                width: blockDelegate.width
                                text: blockDelegate.modelData.value || ""
                                color: "#2c3e50"
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                            }
                            Rectangle {
                                visible: blockDelegate.modelData.kind === "image"
                                width: blockDelegate.width
                                height: blockDelegate.modelData.imgHeight || 200
                                radius: 8
                                color: "#f0f4f8"
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: blockDelegate.modelData.value || ""
                                    fillMode: Image.PreserveAspectFit
                                    autoTransform: true
                                }
                            }
                            RowLayout {
                                id: blockAudioRow
                                visible: blockDelegate.modelData.kind === "audio"
                                width: blockDelegate.width
                                spacing: 8
                                ToolButton {
                                    text: page.playingPath === blockDelegate.modelData.value ? "■" : "▶"
                                    onClicked: {
                                        if (page.playingPath === blockDelegate.modelData.value) {
                                            audioPlayer.stop()
                                            page.playingPath = ""
                                        } else {
                                            audioPlayer.source = blockDelegate.modelData.value
                                            audioPlayer.play()
                                            page.playingPath = blockDelegate.modelData.value
                                        }
                                    }
                                }
                                Label {
                                    text: qsTr("Audio clip")
                                    font.pixelSize: 13
                                    color: "#2c3e50"
                                }
                            }
                        }
                    }
                }
            }


            // ── Spelling strictness — same global setting word-set tests use,
            // since rule's answer-checking reuses the same fuzzy-match
            // logic and strictness level. Same white rounded card + 16px-
            // margin Column as Choose Test Type's own strictnessBlock. ─────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: strictnessColumn.implicitHeight + 32
                radius: 14
                color: "white"
                border.color: "#dce1e7"

                Column {
                    id: strictnessColumn
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 8

                    Label {
                        text: qsTr("✍️ Spelling strictness")
                        font.pixelSize: 12; font.bold: true; color: "#2c3e50"
                    }
                    Row {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: [
                                { value: 0, label: qsTr("Strict") },
                                { value: 1, label: qsTr("Normal") },
                                { value: 2, label: qsTr("Lenient") }
                            ]
                            delegate: ItemDelegate {
                                width: (strictnessColumn.width - 12) / 3
                                height: 32
                                readonly property bool selected: AppController.spellingStrictness === modelData.value
                                background: Rectangle {
                                    radius: 8
                                    color: selected ? "#3498db" : "#f0f4f8"
                                }
                                contentItem: Text {
                                    text: modelData.label
                                    color: selected ? "white" : "#2c3e50"
                                    font.pixelSize: 12
                                    font.bold: selected
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: AppController.spellingStrictness = modelData.value
                            }
                        }
                    }
                }
            }
        }
    }

    footer: Rectangle {
        height: 64 + SafeArea.margins.bottom
        color: "#2c3e50"

        Button {
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top; topMargin: (64 - height) / 2
            }
            width: parent.width * 0.7
            height: 44
            text: qsTr("Start Test")
            enabled: page.questionCount > 0
            background: Rectangle {
                radius: 22
                color: !parent.enabled ? "#4a6070" : (parent.pressed ? "#2980b9" : "#3498db")
            }
            contentItem: Text {
                text: parent.text
                color: parent.enabled ? "white" : "#8fa7b8"
                font.pixelSize: 17; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: page.startRuleTest(page.ruleSetIdx)
        }
    }
}
