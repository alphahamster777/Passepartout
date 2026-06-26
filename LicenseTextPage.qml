import QtQuick
import QtQuick.Controls

Page {
    id: root

    property string pageTitle: ""
    property string licenseUrl: ""

    title: pageTitle

    Component.onCompleted: {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                textArea.text = (xhr.status === 0 || xhr.status === 200)
                    ? xhr.responseText
                    : qsTr("Could not load license text.")
            }
        }
        xhr.open("GET", licenseUrl)
        xhr.send()
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        TextArea {
            id: textArea
            width: parent.width
            readOnly: true
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            font.family: "monospace"
        }
    }
}
