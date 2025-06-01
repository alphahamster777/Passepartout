import QtQuick
import QtQuick.Controls
import AppController

Page {
    anchors.topMargin: 16
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    anchors.bottomMargin: 16

    signal recSetSelected(idx: int)
    signal addRecSet()

    Rectangle{
        anchors.fill: parent
        color: "red"
    }

    ListView {
        id: listView
        anchors.centerIn: parent

        anchors.fill: parent
        spacing: 10
        model: AppController.recSetNameList

        delegate: Button {
            width: listView.width
            height: listView.height/5

            text: modelData

            onClicked:{
                highlighted = false
                recSetSelected(index)
            }
            onPressed:{//potential bug with releasing should be tested on smartphones
                highlighted = true
            }
        }
    }
    footer: Row {
        spacing: 20
        padding: 10
        // Center the row horizontally within the footer area
        anchors.horizontalCenter: parent.horizontalCenter

        Button {
            text: "add new"
            onClicked: {
                addRecSet()
            }
        }
    }
}
