import QtQuick
import QtQuick.Controls

Page {
    anchors.fill: parent
    anchors.topMargin: 16
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    anchors.bottomMargin: 16

    signal recSetSelected(idx: int)
    Rectangle{
        anchors.fill: parent
        color: "red"
    }
    ListView {
        id: listView
        anchors.centerIn: parent
        // width: parent.width
        // height: parent.height/2
        anchors.fill: parent
        spacing: 10
            model: appController.recSetNameList

            delegate: Button {
                width: listView.width
                height: listView.height/5
                // color: "blue"
                // border.color: "black"
                // border.width: 5
                // radius: 10

                    text: modelData
                //     font.pixelSize: 18
                //     horizontalAlignment: Text.AlignHCenter
                //     // verticalAlignment:
                //     anchors.centerIn: parent
                //     anchors.horizontalCenter: parent.horizontalCenter
                // }
                    onClicked:{
                        // recSetSelected(modelData)
                        recSetSelected(index)
                    }

            }
        // }
    }
}
