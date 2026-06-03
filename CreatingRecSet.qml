import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LanguageHelper
import AppController

Page {
    id: page
    anchors.margins: 16
    signal creatingRecSetCancel()
    signal creatingRecSetSave()
    property alias recSetModelRef: recSetModel
    property alias recSetName: topTextField.text
    property int recSetIdx: -1

    Rectangle {
        anchors.fill: parent
        color: "#f0f4f8"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        TextField {
            id: topTextField
            Layout.fillWidth: true
            font.pixelSize: 18
            placeholderText: qsTr("Subject, title, unit…")
            background: Rectangle {
                radius: 6
                color: "white"
                border.color: "#bbb"
            }
        }

        ScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                id: rowsColumn
                width: scrollView.width
                spacing: 10

                ListModel {
                    id: recSetModel
                }

                Repeater {
                    model: recSetModel
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        width: rowsColumn.width
                        height: cardColumn.implicitHeight + 16
                        radius: 8
                        color: "white"
                        border.color: "#ddd"

                        ColumnLayout {
                            id: cardColumn
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 8
                            }
                            spacing: 8

                            TextField {
                                id: exprField
                                Layout.fillWidth: true
                                placeholderText: qsTr("expression")
                                text: expression
                                onEditingFinished: recSetModel.set(index, {expression: exprField.text})
                            }

                            TextField {
                                id: hintField
                                Layout.fillWidth: true
                                placeholderText: qsTr("hint / translation")
                                text: hint
                                onEditingFinished: recSetModel.set(index, {hint: hintField.text})
                            }

                            TextField {
                                id: contextField
                                Layout.fillWidth: true
                                placeholderText: qsTr("context (optional sentence or note)")
                                text: context
                                onEditingFinished: recSetModel.set(index, {context: contextField.text})
                            }

                            Button {
                                text: qsTr("image")
                                Layout.fillWidth: true
                                onClicked: { /* TODO: image picker */ }
                            }

                            ComboBox {
                                Layout.fillWidth: true
                                model: LanguageHelper.languageNames()
                                onCurrentIndexChanged: recSetModel.set(index, {languageFrom: currentIndex})
                                Component.onCompleted: currentIndex = languageFrom
                            }

                            ComboBox {
                                Layout.fillWidth: true
                                model: LanguageHelper.languageNames()
                                onCurrentIndexChanged: recSetModel.set(index, {languageTo: currentIndex})
                                Component.onCompleted: currentIndex = languageTo
                            }
                        }
                    }
                }
            }

            Component.onCompleted: {
                recSetModel.append({
                    languageFrom: LanguageHelper.NotSelected,
                    languageTo:   LanguageHelper.NotSelected,
                    expression:   "",
                    hint:         "",
                    context:      "",
                    audioPath:    "",
                    imagePath:    ""
                })
            }
        }

        RowLayout {
            spacing: 8

            Button {
                text: qsTr("Add word")
                Layout.fillWidth: true
                onClicked: {
                    recSetModel.append({
                        languageFrom: LanguageHelper.NotSelected,
                        languageTo:   LanguageHelper.NotSelected,
                        expression:   "",
                        hint:         "",
                        context:      "",
                        audioPath:    "",
                        imagePath:    ""
                    })
                }
            }

            Button {
                text: qsTr("Remove last")
                enabled: recSetModel.count > 1
                Layout.fillWidth: true
                onClicked: recSetModel.remove(recSetModel.count - 1)
            }
        }
    }

    footer: Rectangle {
        height: footerRow.implicitHeight + 24
        color: "#3c4a5a"

        RowLayout {
            id: footerRow
            anchors {
                fill: parent
                leftMargin: 16
                rightMargin: 16
                topMargin: 12
                bottomMargin: 12
            }
            spacing: 12

            Button {
                text: qsTr("Save")
                Layout.fillWidth: true
                onClicked: creatingRecSetSave()
            }

            Button {
                text: qsTr("Cancel")
                Layout.fillWidth: true
                onClicked: creatingRecSetCancel()
            }
        }
    }
}
