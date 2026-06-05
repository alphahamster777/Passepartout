import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page
    signal resultsNextPressed()

    background: Rectangle { color: "#f0f4f8" }

    header: Rectangle {
        height: 56
        color: "#2c3e50"
        Label {
            anchors.centerIn: parent
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

        // ── Score circle ──────────────────────────────────────────────────────
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 160; height: 160
            radius: 80
            color: {
                var ratio = spellingTestController.totalQuestions > 0
                    ? spellingTestController.correctAnswers / spellingTestController.totalQuestions
                    : 0
                if (ratio >= 0.8) return "#27ae60"
                if (ratio >= 0.5) return "#f39c12"
                return "#e74c3c"
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: spellingTestController.correctAnswers
                    font.pixelSize: 52
                    font.bold: true
                    color: "white"
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("out of %1").arg(spellingTestController.totalQuestions)
                    font.pixelSize: 14
                    color: "white"
                    opacity: 0.85
                }
            }
        }

        // ── Message ───────────────────────────────────────────────────────────
        Label {
            Layout.fillWidth: true
            text: {
                var ratio = spellingTestController.totalQuestions > 0
                    ? spellingTestController.correctAnswers / spellingTestController.totalQuestions
                    : 0
                if (ratio >= 0.8) return qsTr("Excellent work! Keep it up!")
                if (ratio >= 0.5) return qsTr("Good effort! Keep practising.")
                return qsTr("Don't give up – practice makes perfect!")
            }
            font.pixelSize: 16
            font.italic: true
            color: "#7f8c8d"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    footer: Rectangle {
        height: 64
        color: "#2c3e50"

        Button {
            anchors.centerIn: parent
            width: parent.width * 0.7
            height: 44
            text: qsTr("Practice Again")
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
            onClicked: resultsNextPressed()
        }
    }
}
