import QtQuick
import QtQuick.Controls

Page {
    anchors.fill: parent
    anchors.topMargin: 16
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    anchors.bottomMargin: 16

    header: Label {
        text: "Revise expressions"
        font.pixelSize: 20
        horizontalAlignment: Text.AlignHCenter
        anchors.horizontalCenter: parent.horizontalCenter
    }

    SwipeView {
        id: swipeView
        anchors.centerIn: parent
        width: parent.width
        height: parent.height/2
        // anchors.fill: parent

        Repeater {
            model: setPreviewController.expressionList
            delegate: Rectangle {
                width: swipeView.width
                height: swipeView.height
                color: "blue"

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        width: swipeView.width
                        height: 200
                        color: "yellow"
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            source: modelData.imagePath
                        }
                    }

                    Label {
                        text: modelData.expression
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Label {
                        text: modelData.hint
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    footer: Button {
        text: "Start Test"
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        onClicked: {
            setPreviewController.navigateToTest()
        }
    }
}

