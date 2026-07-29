import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import MediaHelper

Page {
    id: page

    signal photoCaptured(int cardIndex, string imagePath)
    signal cancelCapture()

    property int targetCardIndex: -1
    property string pendingCapturePath: ""

    background: Rectangle { color: "black" }

    // ── Capture session ───────────────────────────────────────────────────────
    CaptureSession {
        id: captureSession
        camera: Camera {
            id: camera
            active: page.visible
        }
        imageCapture: ImageCapture {
            id: imageCapture
            onImageSaved: function(id, path) {
                // path is already an absolute file path on all platforms
                var url = path.startsWith("file://") ? path : ("file://" + path)
                page.photoCaptured(page.targetCardIndex, url)
            }
            onErrorOccurred: function(id, error, message) {
                console.warn("Camera capture error:", message)
            }
        }
        videoOutput: viewfinder
    }

    // ── Viewfinder ────────────────────────────────────────────────────────────
    VideoOutput {
        id: viewfinder
        anchors.fill: parent
    }

    // ── Header ────────────────────────────────────────────────────────────────
    header: Rectangle {
        height: 56 + SafeArea.margins.top
        color: "#80000000"

        Label {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom; bottomMargin: (56 - implicitHeight) / 2
            }
            text: qsTr("Take Photo")
            font.pixelSize: 18
            font.bold: true
            color: "white"
        }
    }

    // ── Shutter + cancel controls ─────────────────────────────────────────────
    footer: Rectangle {
        height: 100 + SafeArea.margins.bottom
        color: "#80000000"

        RowLayout {
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                leftMargin: 24; rightMargin: 24; topMargin: 12
            }
            height: 100 - 24
            spacing: 16

            // Cancel
            Button {
                implicitWidth: 80; implicitHeight: 56
                text: qsTr("Cancel")
                background: Rectangle {
                    radius: 8
                    color: parent.pressed ? "#555" : "#7f8c8d"
                }
                contentItem: Text {
                    text: parent.text; color: "white"
                    font.pixelSize: 14; font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: page.cancelCapture()
            }

            Item { Layout.fillWidth: true }

            // Shutter
            Rectangle {
                width: 72; height: 72
                radius: 36
                color: shutterArea.pressed ? "#ccc" : "white"
                border.color: "#aaa"; border.width: 3

                Rectangle {
                    anchors.centerIn: parent
                    width: 58; height: 58
                    radius: 29
                    color: shutterArea.pressed ? "#ddd" : "white"
                }

                MouseArea {
                    id: shutterArea
                    anchors.fill: parent
                    onClicked: {
                        if (imageCapture.readyForCapture) {
                            page.pendingCapturePath = MediaHelper.newPhotoPath()
                            imageCapture.captureToFile(page.pendingCapturePath)
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Placeholder to balance cancel button
            Item { implicitWidth: 80 }
        }
    }
}
