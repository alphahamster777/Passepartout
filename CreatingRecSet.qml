import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LanguageHelper

Page {
    anchors.margins: 16
    signal creatingRecSetCancel()
    signal creatingRecSetSave()
    property alias recSetModelRef: recSetModel
    property alias recSetName: topTextField

    Rectangle{
        anchors.fill: parent
        color: "lightblue"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 30
        spacing: 16

        // Header field
        TextField {
            id: topTextField

            Layout.fillWidth: true
            font.pixelSize: 18
            placeholderText: qsTr("Subject, title, unit…")
        }

        // Scrollable area for your rows
        ScrollView {
            id: scrollView

            Layout.fillWidth: true
            // Let the ScrollView take up all remaining vertical space
            Layout.fillHeight: true
            clip: true

            // Inside the ScrollView, stack your delegates vertically
            ColumnLayout {
                id: rowsColumn
                width: scrollView.width
                // spacing: 50
                ListModel {
                    id: recSetModel
                    // start empty, or seed with one element if you like
                }

                Repeater {
                    model: recSetModel
                    delegate: ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true

                        TextField {
                            id: exprField
                            Layout.fillWidth: true
                            placeholderText: qsTr("expression")

                            onTextChanged: recSetModel.set(index, {expression: exprField.text})
                        }

                        TextField {
                            id: hintField
                            Layout.fillWidth: true
                            placeholderText: qsTr("hint")

                            // initialize from model
                            // text: expression
                            // write back on every change
                            onTextChanged: recSetModel.set(index, {hint: hintField.text})


                        }
                        Button {
                            text: qsTr("image")
                            Layout.fillWidth: true
                            onClicked: { /* … */ }
                        }
                        ComboBox {
                            // id: comboBoxFrom
                            Layout.fillWidth: true
                            model: LanguageHelper.languageNames()
                            onCurrentIndexChanged: {
                                recSetModel.set(index, {languageFrom: currentIndex})
                            }

                            Component.onCompleted:{
                                currentIndex = LanguageHelper.English
                            }
                        }
                        ComboBox {
                            // id: comboBoxTo
                            Layout.fillWidth: true
                            model: LanguageHelper.languageNames()
                            onCurrentIndexChanged: {
                                recSetModel.set(index, {languageTo: currentIndex})
                            }

                            Component.onCompleted:{
                                currentIndex = LanguageHelper.NotSelected
                            }
                        }
                    }
                }
            }

            Component.onCompleted:{
                recSetModel.append({
                                       languageFrom: LanguageHelper.NotSelected,
                                       languageTo: LanguageHelper.NotSelected,
                                       expression: "",
                                       hint: "",
                                       audioPath: "",
                                       imagePath: ""
                                   })

            }
        }

        RowLayout {
            Button {
                text: qsTr("Add")
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    recSetModel.append({
                                           languageFrom: LanguageHelper.English,
                                           languageTo: LanguageHelper.NotSelected,
                                           expression: "",
                                           hint: "",
                                           audioPath: "",
                                           imagePath: ""
                                       })
                }
            }

            Button {
                text: qsTr("Remove")
                enabled: recSetModel.count > 1

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    recSetModel.remove(recSetModel.count - 1)
                }
            }
        }
    }
    footer:  Rectangle {
        height: row.implicitHeight
        color: "grey"

        RowLayout {
            id: row
            anchors.fill: parent
            spacing: 20

            Button {
                text: qsTr("Create");
                Layout.alignment: Qt.AlignLeft | Qt.AlignBottom
                Layout.leftMargin: 16
                Layout.bottomMargin: 16
                Layout.preferredWidth: parent.width/2.5
                onClicked:{
                    creatingRecSetSave()
                }
            }
            Button {
                text: qsTr("Cancel");
                Layout.alignment: Qt.AlignRight | Qt.AlignBottom
                Layout.rightMargin: 16
                Layout.bottomMargin: 16
                Layout.preferredWidth: parent.width/2.5
                onClicked: {
                    creatingRecSetCancel()
                }
            }
        }
    }
}
