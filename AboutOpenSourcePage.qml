import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    title: qsTr("About")

    signal licenseRequested(string title, string url)

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 16

            Label {
                text: qsTr("Passepartout")
                font.pixelSize: 24
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Label {
                text: qsTr("Vocabulary trainer for memorizing word sets.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Frame {
                Layout.fillWidth: true

                ColumnLayout {
                    width: parent.width
                    spacing: 10

                    Label {
                        text: qsTr("Open Source Licenses")
                        font.pixelSize: 20
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Label {
                        text: qsTr("This application uses Qt under the GNU Lesser General Public License version 3.")
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Button {
                        text: qsTr("Qt notice")
                        Layout.fillWidth: true
                        onClicked: licenseRequested(qsTr("Qt Notice"), "qrc:/licenses/qt_notice.txt")
                    }

                    Button {
                        text: qsTr("GNU LGPL v3")
                        Layout.fillWidth: true
                        onClicked: licenseRequested(qsTr("GNU LGPL v3"), "qrc:/licenses/LGPL-3.0.txt")
                    }

                    Button {
                        text: qsTr("GNU GPL v3")
                        Layout.fillWidth: true
                        onClicked: licenseRequested(qsTr("GNU GPL v3"), "qrc:/licenses/GPL-3.0.txt")
                    }

                    Button {
                        text: qsTr("Qt source code")
                        Layout.fillWidth: true
                        onClicked: Qt.openUrlExternally("https://www.qt.io/development/offline-installers")
                    }

                    Button {
                        text: qsTr("Qt project website")
                        Layout.fillWidth: true
                        onClicked: Qt.openUrlExternally("https://www.qt.io/")
                    }
                }
            }
        }
    }
}
