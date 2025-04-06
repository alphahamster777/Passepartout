import QtQuick
import QtQuick.Controls
// import QtMultimedia

Page {
    id:root

    signal getResults()
    property int nextCounter: 0

    property bool isExpressionEntered: false

    header: Label {
        id: expressionExplanationText
        text: spellingTestController.currentHint
        font.pixelSize: 20
        horizontalAlignment: Text.AlignHCenter
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Column {
        anchors.fill: parent
        anchors.topMargin: 16
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16
        spacing: 16

        Rectangle {
            width: parent.width
            height: 200
            color: "lightblue"
            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                source: spellingTestController.currentImageUrl
            }
        }

        TextField {
            id: guessInputField
            placeholderText: qsTr("Type here...")
            text: ""
            color: "gray"
            font.pixelSize: 18
            width: parent.width * 0.8
            // height: 200
            anchors.horizontalCenter:parent.horizontalCenter
            onEditingFinished: {
                if(isExpressionEntered)
                    return
                isExpressionEntered = true

                if(spellingTestController.currentWord === guessInputField.text){
                    spellingTestController.correctAnswers++
                } else {
                    color = "red"
                    text = spellingTestController.currentWord
                }

                nextButton.focus = true;
                nextButton.highlighted = true;
            }
        }

        ProgressBar {
            id: progressBar
            from: 0
            to: spellingTestController.totalQuestions
            value: spellingTestController.correctAnswers
            width: parent.width * 0.8
            anchors.horizontalCenter:parent.horizontalCenter
        }
    }

    footer: Button {
        id: nextButton
        text: "Next"
        anchors.horizontalCenter:parent.horizontalCenter
        // focusPolicy: Qt.StrongFocus
        onClicked: {
            nextCounter++
            if(nextCounter >= spellingTestController.totalQuestions){
                getResults()
                // nextCounter = 0;
                return
            }
            guessInputField.color = "gray"
            guessInputField.text = ""
            isExpressionEntered = false
            highlighted = false;
            guessInputField.focus = true

            spellingTestController.nextQuestion()
        }

    }
}
