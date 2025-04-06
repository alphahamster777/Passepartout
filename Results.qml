import QtQuick
import QtQuick.Controls
// import QtMultimedia

Page {
    anchors.topMargin: 16
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    anchors.bottomMargin: 16
    signal resultsNextPressed()
    property int nextCounter: 0

    Rectangle {
        width: parent.width
        height: parent.width * 0.8
        color: "gray"

        Label {
            text: "You gave " + spellingTestController.correctAnswers + " out of " + spellingTestController.totalQuestions + " correct answers"
            font.pixelSize: 18
            font.italic: true
            color: "blue"
            anchors.centerIn:parent
        }
    }

    footer: Button {
        text: "More exercises"
        anchors.horizontalCenter: parent.horizontalCenter        
        onClicked: {
            highlighted = false
            resultsNextPressed()            
        }
        onPressed:{//potential bug with releasing should be tested on smartphones
            highlighted = true
        }
    }
}
