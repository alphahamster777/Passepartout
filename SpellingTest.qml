import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: root
    signal getResults()

    property int nextCounter: 0
    property bool isExpressionEntered: false
    property bool isCorrect: false

    background: Rectangle { color: "#f0f4f8" }

    header: Rectangle {
        height: 56
        color: "#2c3e50"

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }

            Label {
                text: spellingTestController.currentHint
                font.pixelSize: 20
                font.bold: true
                color: "white"
                Layout.fillWidth: true
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }

            Label {
                text: spellingTestController.correctAnswers + "/" + spellingTestController.totalQuestions
                font.pixelSize: 14
                color: "#3498db"
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ── Image ─────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 200
            radius: 12
            color: spellingTestController.currentImageUrl !== "" ? "transparent" : "#eaf4fb"
            clip: true
            border.color: "#dce1e7"

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                source: spellingTestController.currentImageUrl
                visible: spellingTestController.currentImageUrl !== ""
            }

            Label {
                anchors.centerIn: parent
                text: "🖼"
                font.pixelSize: 64
                opacity: 0.2
                visible: spellingTestController.currentImageUrl === ""
            }
        }

        // ── Input ─────────────────────────────────────────────────────────────
        TextField {
            id: guessInputField
            Layout.fillWidth: true
            placeholderText: qsTr("Type the expression…")
            font.pixelSize: 18
            color: isExpressionEntered ? (isCorrect ? "#27ae60" : "#e74c3c") : "#2c3e50"
            background: Rectangle {
                radius: 10
                color: "white"
                border.color: {
                    if (!isExpressionEntered) return guessInputField.activeFocus ? "#3498db" : "#dce1e7"
                    return isCorrect ? "#27ae60" : "#e74c3c"
                }
                border.width: isExpressionEntered ? 2 : (guessInputField.activeFocus ? 2 : 1)
            }
            leftPadding: 14
            onEditingFinished: {
                if (isExpressionEntered) return
                isExpressionEntered = true

                if (spellingTestController.currentWord === guessInputField.text) {
                    isCorrect = true
                    spellingTestController.correctAnswers++
                } else {
                    isCorrect = false
                    text = spellingTestController.currentWord
                }
                nextButton.forceActiveFocus()
            }
        }

        // ── Progress bar ──────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Label {
                text: qsTr("Correct: %1 / %2").arg(spellingTestController.correctAnswers).arg(spellingTestController.totalQuestions)
                font.pixelSize: 13
                color: "#7f8c8d"
            }
            ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: spellingTestController.totalQuestions
                value: spellingTestController.correctAnswers
                background: Rectangle { radius: 4; color: "#dce1e7"; implicitHeight: 10 }
                contentItem: Rectangle {
                    width: parent.visualPosition * parent.width
                    height: parent.height
                    radius: 4
                    color: "#27ae60"
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    footer: Rectangle {
        height: 64
        color: "#2c3e50"

        Button {
            id: nextButton
            anchors.centerIn: parent
            width: parent.width * 0.7
            height: 44
            text: nextCounter + 1 >= spellingTestController.totalQuestions ? qsTr("See Results") : qsTr("Next →")
            background: Rectangle {
                radius: 22
                color: parent.pressed ? "#2980b9" : "#3498db"
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.pixelSize: 17
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                nextCounter++
                if (nextCounter >= spellingTestController.totalQuestions) {
                    getResults()
                    return
                }
                guessInputField.text = ""
                guessInputField.color = "#2c3e50"
                isExpressionEntered = false
                isCorrect = false
                guessInputField.forceActiveFocus()
                spellingTestController.nextQuestion()
            }
        }
    }
}
