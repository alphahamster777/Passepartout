import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SpellingTestController

Page {
    id: page
    signal practiceSetAgain()
    signal findAnotherSet()

    property var spellingTestController: rootScope.spellingTestController
    readonly property bool isE_LeitnerType:
        spellingTestController.testType === SpellingTestController.TypeE_Leitner ||
        spellingTestController.testType === SpellingTestController.TypeF_LeitnerReversed
    readonly property bool isFlashCardType:
        spellingTestController.testType === SpellingTestController.TypeG_FlashCard

    // Flash cards use cumulative totals (every card in the set, across every
    // session so far) for the headline score; other test types use just the
    // session that ended.
    readonly property int displayCorrect:
        isFlashCardType ? spellingTestController.totalKnownCount : spellingTestController.correctAnswers
    readonly property int displayTotal:
        isFlashCardType ? spellingTestController.totalWordCount : spellingTestController.totalQuestions
    readonly property bool allCorrect:
        displayTotal > 0 && displayCorrect >= displayTotal

    background: Rectangle { color: "#f0f4f8" }

    header: Rectangle {
        height: 56 + SafeArea.margins.top
        color: "#2c3e50"
        Label {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom; bottomMargin: (56 - implicitHeight) / 2
            }
            text: qsTr("Results")
            font.pixelSize: 18
            font.bold: true
            color: "white"
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24
        width: parent.width * 0.8

        // ── Score circle (hidden for Leitner types) ───────────────────────────
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 160
            Layout.preferredHeight: 160
            radius: 80
            color: {
                var ratio = page.displayTotal > 0 ? page.displayCorrect / page.displayTotal : 0
                if (ratio >= 0.8) return "#27ae60"
                if (ratio >= 0.5) return "#f39c12"
                return "#e74c3c"
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2
                // Both labels shrink to fit the circle — translations of
                // "Well"/"done" (e.g. "Отлично") are much wider than English.
                // (Sized from the measured width rather than fontSizeMode,
                // which shrinks the glyphs but keeps the full line height and
                // leaves a gap between the two lines.)
                Label {
                    id: scoreTopLabel
                    Layout.alignment: Qt.AlignHCenter
                    text: page.isE_LeitnerType? qsTr("Well"): page.displayCorrect
                    TextMetrics { id: scoreTopMetrics; font.bold: true; font.pixelSize: 52; text: scoreTopLabel.text }
                    font.pixelSize: Math.max(16, Math.min(52, Math.floor(52 * 128 / Math.max(1, scoreTopMetrics.advanceWidth))))
                    font.bold: true
                    color: "white"
                }
                Label {
                    id: scoreBottomLabel
                    Layout.alignment: Qt.AlignHCenter
                    readonly property int baseSize: page.isE_LeitnerType ? 30 : 14
                    text: page.isE_LeitnerType? qsTr("done"): qsTr("out of %1").arg(page.displayTotal)
                    TextMetrics { id: scoreBottomMetrics; font.pixelSize: scoreBottomLabel.baseSize; text: scoreBottomLabel.text }
                    font.pixelSize: Math.max(10, Math.min(baseSize, Math.floor(baseSize * 136 / Math.max(1, scoreBottomMetrics.advanceWidth))))
                    color: "white"
                    opacity: 0.85
                }
            }
        }

        // ── Message ───────────────────────────────────────────────────────────
        Label {
            Layout.fillWidth: true
            text: {
                if (page.isE_LeitnerType) return qsTr("Excellent work! Keep it up!")
                var ratio = page.displayTotal > 0 ? page.displayCorrect / page.displayTotal : 0
                if (ratio >= 0.8) return qsTr("Excellent work! Keep it up!")
                if (ratio >= 0.5) return qsTr("Good effort! Keep practising.")
                return qsTr("Don't give up – practice makes perfect!")
            }
            font.pixelSize: page.allCorrect ? 22 : 16
            font.bold: page.allCorrect
            font.italic: !page.allCorrect
            color: page.allCorrect ? "#27ae60" : "#7f8c8d"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        // ── Flash cards: how this particular session went ──────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: page.isFlashCardType
            spacing: 10

            Rectangle { Layout.fillWidth: true; height: 1; color: "#dce1e7" }

            Label {
                Layout.fillWidth: true
                Layout.topMargin: 8
                text: qsTr("This session")
                font.pixelSize: 12
                font.bold: true
                color: "#7f8c8d"
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 40

                ColumnLayout {
                    spacing: 2
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: page.spellingTestController.unknownCount
                        color: "#e74c3c"
                        font.pixelSize: 26; font.bold: true
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Don't know")
                        color: "#7f8c8d"
                        font.pixelSize: 12
                    }
                }
                ColumnLayout {
                    spacing: 2
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: page.spellingTestController.correctAnswers
                        color: "#27ae60"
                        font.pixelSize: 26; font.bold: true
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Know")
                        color: "#7f8c8d"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    footer: Rectangle {
        height: 64 + SafeArea.margins.bottom
        color: "#2c3e50"

        RowLayout {
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                leftMargin: 16; rightMargin: 16; topMargin: 10
            }
            height: 44
            spacing: 12

            Button {
                id: practiceAgainBtn
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                text: qsTr("Practice again")
                background: Rectangle {
                    radius: 22
                    color: practiceAgainBtn.pressed ? "#2980b9" : "#3498db"
                }
                contentItem: Text {
                    text: practiceAgainBtn.text
                    color: "white"
                    font.pixelSize: 15
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 11
                }
                onClicked: page.practiceSetAgain()
            }

            Button {
                id: findAnotherSetBtn
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                text: qsTr("Find another set")
                background: Rectangle {
                    radius: 22
                    color: findAnotherSetBtn.pressed ? "#3d566e" : "transparent"
                    border.color: "#3498db"
                    border.width: 2
                }
                contentItem: Text {
                    text: findAnotherSetBtn.text
                    color: "white"
                    font.pixelSize: 15
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 11
                }
                onClicked: page.findAnotherSet()
            }
        }
    }
}
