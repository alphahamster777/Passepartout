import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page
    title: qsTr("About")

    signal licenseRequested(string title, string url)

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
            text: qsTr("About")
            font.pixelSize: 18; font.bold: true
            color: "white"
        }
    }

    // A ScrollView must not be positioned from its own SafeArea (that's a
    // binding loop — see Qt's SafeArea docs); read it from the Page instead,
    // whose geometry is fixed by the StackView and unaffected by this margin.
    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 16

            Item { Layout.preferredHeight: 16 }

            Label {
                text: qsTr(
                    "<b>Passepartout</b>" +
                    "<font color='#1e88e5'> v%1</font>"
                ).arg(Qt.application.version)
                font.pixelSize: 24
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

            Item { Layout.preferredHeight: page.SafeArea.margins.bottom }
        }
    }
}
