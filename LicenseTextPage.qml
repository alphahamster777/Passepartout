import QtQuick
import QtQuick.Controls

Page {
    id: root

    property string pageTitle: ""
    property string licenseUrl: ""

    title: pageTitle

    background: Rectangle { color: "#f0f4f8" }

    // Status bar icons are forced white app-wide (themes.xml) to read against
    // the navy header used on every other page — this page needs one too,
    // otherwise the icons are invisible against the plain light background.
    header: Rectangle {
        height: 56 + SafeArea.margins.top
        color: "#2c3e50"
        Label {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom; bottomMargin: (56 - implicitHeight) / 2
            }
            text: root.pageTitle
            font.pixelSize: 18; font.bold: true
            color: "white"
        }
    }

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

    // The ScrollView itself must not be positioned from its own SafeArea (that's
    // a binding loop — see Qt's SafeArea docs); read it from the Page instead,
    // via TextArea's own padding, which insets content without moving the
    // ScrollView/TextArea's outer geometry.
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
            topPadding: 12
            bottomPadding: root.SafeArea.margins.bottom
        }
    }
}
