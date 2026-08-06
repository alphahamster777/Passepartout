import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SpellingTestController

Page {
    id: page
    signal resultsNextPressed()

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
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: page.isE_LeitnerType? qsTr("Well"): page.displayCorrect
                    font.pixelSize: 52
                    font.bold: true
                    color: "white"
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: page.isE_LeitnerType? qsTr("done"): qsTr("out of %1").arg(page.displayTotal)
                    font.pixelSize: page.isE_LeitnerType? 30 : 14
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

        Button {
            id: practiceAgainBtn
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top; topMargin: (64 - height) / 2
            }
            width: parent.width * 0.7
            height: 44
            text: qsTr("Practice Again")
            background: Rectangle {
                radius: 22
                color: practiceAgainBtn.pressed ? "#2980b9" : "#3498db"
            }
            contentItem: Text {
                text: practiceAgainBtn.text
                color: "white"
                font.pixelSize: 17
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: page.resultsNextPressed()
        }
    }
}
