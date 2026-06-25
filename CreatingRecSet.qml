import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia
import LanguageHelper
import AppController
import MediaHelper

Page {
    id: page
    signal creatingRecSetCancel()
    signal creatingRecSetSave()
    signal requestCameraCapture(int cardIndex)
    property alias recSetModelRef: recSetModel
    property alias recSetName: topTextField.text
    property int recSetIdx: -1
    property string folderPath: ""
    property int activeCardIndex: -1
    property int selectedCardIndex: 0
    property bool autoMedia: false
    property string currentPlayingPath: ""
    property int recordingCardIndex: -1   // card currently being recorded into
    property int pendingRecordCardIndex: -1  // waiting for mic permission
    property int pendingCameraCardIndex: -1  // waiting for camera permission
    property int langPickerCardIndex: -1     // card whose language is being picked
    property bool langPickerIsFrom: true     // true = word/expr language, false = hint language
    property int langPickerCurrentId: -1    // enum value of the currently selected language
    readonly property var langEntries: LanguageHelper.sortedLanguageEntries()

    background: Rectangle { color: "#f0f4f8" }

    // ── Audio player ──────────────────────────────────────────────────────────
    MediaPlayer {
        id: audioPlayer
        audioOutput: AudioOutput {}
        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState)
                page.currentPlayingPath = ""
        }
    }

    // ── Audio recorder ────────────────────────────────────────────────────────
    CaptureSession {
        id: recSession
        audioInput: AudioInput { id: recAudioInput }
        recorder: MediaRecorder {
            id: audioRecorder
            onRecorderStateChanged: {
                if (recorderState === MediaRecorder.StoppedState) {
                    var path = audioRecorder.actualLocation.toString()
                    if (path !== "" && page.recordingCardIndex >= 0) {
                        if (!path.startsWith("file://"))
                            path = "file://" + path
                        recSetModel.set(page.recordingCardIndex, { audioPath: path })
                        page.recordingCardIndex = -1
                    }
                }
            }
        }
    }

    function importFromPath(path) {
        var result
        if (path.endsWith(".xml"))
            result = AppController.recSetManager.readSetFromXml(path)
        else
            result = AppController.recSetManager.readSetFromZip(path)
        if (!result || !result.name) return
        topTextField.text = result.name
        recSetModel.clear()
        var wordList = result.words
        for (var i = 0; i < wordList.length; i++)
            recSetModel.append(wordList[i])
        page.selectedCardIndex = Math.max(0, recSetModel.count - 1)
    }

    function startRecording(cardIndex) {
        page.recordingCardIndex = cardIndex
        var dest = MediaHelper.newRecordingPath()
        audioRecorder.outputLocation = "file://" + dest
        audioRecorder.record()
    }

    // ── MediaHelper signal handlers ───────────────────────────────────────────
    Connections {
        target: MediaHelper
        function onImageFetched(cardIndex, url) {
            if (cardIndex >= 0 && cardIndex < recSetModel.count)
                recSetModel.set(cardIndex, { imagePath: url })
        }
        function onMicrophonePermissionGranted() {
            if (page.pendingRecordCardIndex >= 0) {
                page.startRecording(page.pendingRecordCardIndex)
                page.pendingRecordCardIndex = -1
            }
        }
        function onCameraPermissionGranted() {
            if (page.pendingCameraCardIndex >= 0) {
                page.requestCameraCapture(page.pendingCameraCardIndex)
                page.pendingCameraCardIndex = -1
            }
        }
    }

    // ── File dialogs ──────────────────────────────────────────────────────────
    FileDialog {
        id: imagePickerDialog
        title: qsTr("Select Image")
        nameFilters: ["Images (*.jpg *.jpeg *.png *.gif *.bmp *.webp)"]
        onAccepted: {
            if (page.activeCardIndex >= 0)
                recSetModel.set(page.activeCardIndex, { imagePath: selectedFile.toString() })
        }
    }

    FileDialog {
        id: audioPickerDialog
        title: qsTr("Select Audio")
        nameFilters: ["Audio (*.mp3 *.ogg *.wav *.m4a *.aac *.flac *.opus)"]
        onAccepted: {
            if (page.activeCardIndex >= 0)
                recSetModel.set(page.activeCardIndex, { audioPath: selectedFile.toString() })
        }
    }

    FileDialog {
        id: importDialog
        title: qsTr("Import Word Set")
        nameFilters: ["Passepartout Set (*.ppset)", "XML files (*.xml)", "All files (*)"]
        onAccepted: {
            var path = selectedFile.toString()
            var result
            if (path.endsWith(".xml"))
                result = AppController.recSetManager.readSetFromXml(path)
            else
                result = AppController.recSetManager.readSetFromZip(path)

            if (!result || !result.name) return

            topTextField.text = result.name
            recSetModel.clear()
            var wordList = result.words
            for (var i = 0; i < wordList.length; i++) {
                recSetModel.append(wordList[i])
            }
            page.selectedCardIndex = Math.max(0, recSetModel.count - 1)
        }
    }

    // ── Language picker popup ─────────────────────────────────────────────────
    Popup {
        id: languagePickerPopup
        anchors.centerIn: Overlay.overlay
        width: Math.min(parent.width - 32, 340)
        padding: 0
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        // Scroll to the currently selected language after the popup has opened.
        onOpened: Qt.callLater(function() {
            var entries = page.langEntries
            var currentId = page.langPickerCurrentId
            for (var i = 0; i < entries.length; ++i) {
                if (entries[i].id === currentId) {
                    var itemH = 48
                    var targetY = i * itemH
                    var center = targetY - (langFlick.height - itemH) / 2
                    langFlick.contentY = Math.max(0,
                        Math.min(center, Math.max(0, langFlick.contentHeight - langFlick.height)))
                    break
                }
            }
        })

        background: Rectangle { radius: 14; color: "white"; layer.enabled: true }

        contentItem: Column {
            Rectangle {
                width: languagePickerPopup.availableWidth
                height: 52
                color: "#2c3e50"
                radius: 14
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 14; color: "#2c3e50"
                }
                Label {
                    anchors.centerIn: parent
                    text: page.langPickerIsFrom ? qsTr("Word Language") : qsTr("Hint Language")
                    font.pixelSize: 16; font.bold: true; color: "white"
                }
            }

            Flickable {
                id: langFlick
                width: languagePickerPopup.availableWidth
                height: Math.min(langCol.implicitHeight,
                                 (Overlay.overlay ? Overlay.overlay.height * 0.65 : 380) - 52 - 52)
                contentHeight: langCol.implicitHeight
                clip: true

                Column {
                    id: langCol
                    width: langFlick.width

                    Repeater {
                        model: page.langEntries
                        delegate: ItemDelegate {
                            width: langCol.width
                            height: 48
                            required property int index
                            required property var modelData

                            readonly property bool isCurrent: modelData.id === page.langPickerCurrentId

                            background: Rectangle {
                                color: isCurrent ? "#eaf4fb"
                                     : parent.pressed ? "#f0f4f8" : "white"
                                Rectangle {
                                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                    height: 1; color: "#ececec"
                                }
                            }
                            contentItem: Item {
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                                    spacing: 8
                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: isCurrent ? "#3498db" : "#2c3e50"
                                        font.pixelSize: 15
                                        font.bold: isCurrent
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    Label {
                                        visible: isCurrent
                                        text: "✓"
                                        color: "#3498db"
                                        font.pixelSize: 14
                                    }
                                }
                            }
                            onClicked: {
                                var cardIdx = page.langPickerCardIndex
                                if (cardIdx >= 0) {
                                    if (page.langPickerIsFrom)
                                        recSetModel.set(cardIdx, { languageFrom: modelData.id })
                                    else
                                        recSetModel.set(cardIdx, { languageTo: modelData.id })
                                }
                                languagePickerPopup.close()
                            }
                        }
                    }
                }
            }

            Rectangle { width: languagePickerPopup.availableWidth; height: 1; color: "#ececec" }
            ItemDelegate {
                width: languagePickerPopup.availableWidth
                height: 50
                background: Rectangle { color: parent.pressed ? "#f0f4f8" : "white"; radius: 14 }
                contentItem: Text {
                    text: qsTr("Cancel"); color: "#e74c3c"
                    font.pixelSize: 15; font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: languagePickerPopup.close()
            }
        }
    }

    // ── Header ────────────────────────────────────────────────────────────────
    header: ToolBar {
        height: 56
        background: Rectangle { color: "#2c3e50" }

        RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
            spacing: 4

            Item { implicitWidth: 76 }

            Label {
                Layout.fillWidth: true
                text: page.recSetIdx === -1 ? qsTr("New Word Set") : qsTr("Edit Word Set")
                font.pixelSize: 18
                font.bold: true
                color: "white"
                horizontalAlignment: Text.AlignHCenter
            }

            Button {
                implicitWidth: 76
                implicitHeight: 36
                text: qsTr("Import")
                background: Rectangle {
                    radius: 8
                    color: parent.pressed ? "#1a6ca8" : "#3498db"
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 13
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: importDialog.open()
            }
        }
    }

    // ── Body ──────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        TextField {
            id: topTextField
            Layout.fillWidth: true
            font.pixelSize: 17
            placeholderText: qsTr("Set title…")
            background: Rectangle {
                radius: 8
                color: "white"
                border.color: topTextField.activeFocus ? "#3498db" : "#dce1e7"
                border.width: topTextField.activeFocus ? 2 : 1
            }
            leftPadding: 12
        }

        // ── Auto-fetch toggle ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 42
            radius: 8
            color: "white"
            border.color: "#dce1e7"

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 10

                Label {
                    text: qsTr("Auto-fetch image & pronunciation")
                    font.pixelSize: 13
                    color: "#2c3e50"
                    Layout.fillWidth: true
                }

                Switch {
                    id: autoMediaSwitch
                    checked: page.autoMedia
                    onCheckedChanged: page.autoMedia = checked
                }
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
                height: implicitHeight
                spacing: 10

                ListModel { id: recSetModel }

                Repeater {
                    model: recSetModel
                    delegate: Rectangle {
                        id: cardRect
                        Layout.fillWidth: true
                        width: rowsColumn.width
                        Layout.preferredHeight: cardColumn.implicitHeight + 24
                        implicitHeight: cardColumn.implicitHeight + 24

                        radius: 10
                        color: "white"
                        border.color: page.selectedCardIndex === index ? "#3498db" : "#dce1e7"
                        border.width: page.selectedCardIndex === index ? 2 : 1

                        // Blue top accent bar
                        Rectangle {
                            width: parent.width; height: 3
                            radius: 10
                            color: "#3498db"
                            anchors.top: parent.top
                        }

                        ColumnLayout {
                            id: cardColumn
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 10

                            // ── Card header: word number + tap-to-select ──────
                            Rectangle {
                                Layout.fillWidth: true
                                height: 24
                                color: "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    Label {
                                        text: qsTr("Word") + " " + (index + 1)
                                        font.pixelSize: 11
                                        color: "#95a5a6"
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        visible: page.selectedCardIndex === index
                                        text: qsTr("selected")
                                        font.pixelSize: 10
                                        color: "#3498db"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: page.selectedCardIndex = index
                                }
                            }

                            // ── Word / Term ───────────────────────────────────
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label {
                                    text: qsTr("Word / Term")
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#2c3e50"
                                    Layout.fillWidth: true
                                }
                                Rectangle {
                                    implicitWidth: 138; implicitHeight: 30
                                    radius: 6
                                    color: "#f0f4f8"
                                    border.color: "#dce1e7"; border.width: 1
                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                                        spacing: 2
                                        Label {
                                            Layout.fillWidth: true
                                            text: LanguageHelper.languageNames()[languageFrom]
                                            font.pixelSize: 11; color: "#2c3e50"
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        // Label { text: "▾"; font.pixelSize: 10; color: "#7f8c8d" }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            page.langPickerCardIndex = index
                                            page.langPickerIsFrom = true
                                            page.langPickerCurrentId = languageFrom
                                            languagePickerPopup.open()
                                        }
                                    }
                                }
                            }
                            TextField {
                                id: exprField
                                Layout.fillWidth: true
                                placeholderText: qsTr("Enter word...")
                                text: expression
                                font.pixelSize: 15
                                background: Rectangle {
                                    radius: 6; color: "#f7f9fb"
                                    border.color: exprField.activeFocus ? "#3498db" : "#e0e6ed"
                                }
                                leftPadding: 10
                                onActiveFocusChanged: if (activeFocus) page.selectedCardIndex = index
                                onEditingFinished: {
                                    recSetModel.set(index, { expression: exprField.text })
                                    if (page.autoMedia && exprField.text.trim() !== "" && imagePath === "")
                                        MediaHelper.fetchWikimediaImageUrl(exprField.text.trim(), index, languageFrom)
                                }
                            }

                            // ── Hint / meaning ──────────────────────────
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label {
                                    text: qsTr("Hint / meaning")
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#2c3e50"
                                    Layout.fillWidth: true
                                }
                                Rectangle {
                                    implicitWidth: 138; implicitHeight: 30
                                    radius: 6
                                    color: "#f0f4f8"
                                    border.color: "#dce1e7"; border.width: 1
                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                                        spacing: 2
                                        Label {
                                            Layout.fillWidth: true
                                            text: LanguageHelper.languageNames()[languageTo]
                                            font.pixelSize: 11; color: "#2c3e50"
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        // Label { text: "▾"; font.pixelSize: 10; color: "#7f8c8d" }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            page.langPickerCardIndex = index
                                            page.langPickerIsFrom = false
                                            page.langPickerCurrentId = languageTo
                                            languagePickerPopup.open()
                                        }
                                    }
                                }
                            }
                            TextField {
                                id: hintField
                                Layout.fillWidth: true
                                placeholderText: qsTr("Hint, definition...")
                                text: hint
                                font.pixelSize: 15
                                background: Rectangle {
                                    radius: 6; color: "#f7f9fb"
                                    border.color: hintField.activeFocus ? "#3498db" : "#e0e6ed"
                                }
                                leftPadding: 10
                                onActiveFocusChanged: if (activeFocus) page.selectedCardIndex = index
                                onEditingFinished: recSetModel.set(index, { hint: hintField.text })
                            }

                            // ── Image preview — height adapts to aspect ratio ──
                            Image {
                                id: imagePreview
                                visible: imagePath !== ""
                                source: imagePath
                                Layout.fillWidth: true
                                Layout.preferredHeight: (sourceSize.width > 0 && cardColumn.width > 0)
                                    ? Math.min(cardColumn.width * sourceSize.height / sourceSize.width, 260)
                                    : 0
                                fillMode: Image.PreserveAspectFit
                            }

                            // ── Image & Audio boxes ───────────────────────────
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                // Image box
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 72
                                    radius: 8
                                    color: "#f7f9fb"
                                    border.color: "#c8d6e5"
                                    border.width: 1

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            page.selectedCardIndex = index
                                            page.activeCardIndex   = index
                                            imagePickerDialog.open()
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 3

                                        Label {
                                            text: imagePath !== "" ? qsTr("Change image") : qsTr("Add image")
                                            font.pixelSize: 11
                                            color: imagePath !== "" ? "#27ae60" : "#95a5a6"
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        RowLayout {
                                            Layout.alignment: Qt.AlignHCenter
                                            spacing: 4

                                            // Auto-fetch button
                                            Button {
                                                visible: imagePath === "" && page.autoMedia && exprField.text.trim() !== ""
                                                implicitWidth: 56; implicitHeight: 22
                                                text: qsTr("Fetch")
                                                font.pixelSize: 10
                                                background: Rectangle {
                                                    radius: 11
                                                    color: parent.pressed ? "#2980b9" : "#3498db"
                                                }
                                                contentItem: Text {
                                                    text: parent.text; color: "white"; font: parent.font
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                onClicked: {
                                                    page.activeCardIndex = index
                                                    MediaHelper.fetchWikimediaImageUrl(exprField.text.trim(), index, languageFrom)
                                                }
                                            }

                                            // Camera button
                                            Button {
                                                implicitWidth: 56; implicitHeight: 22
                                                text: qsTr("Camera")
                                                font.pixelSize: 10
                                                background: Rectangle {
                                                    radius: 11
                                                    color: parent.pressed ? "#7f5b00" : "#f39c12"
                                                }
                                                contentItem: Text {
                                                    text: parent.text; color: "white"; font: parent.font
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                onClicked: {
                                                    page.activeCardIndex = index
                                                    if (MediaHelper.hasCameraPermission()) {
                                                        page.requestCameraCapture(index)
                                                    } else {
                                                        page.pendingCameraCardIndex = index
                                                        MediaHelper.requestCameraPermission()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Remove image button
                                    Rectangle {
                                        visible: imagePath !== ""
                                        width: 20; height: 20
                                        radius: 10
                                        color: "#e74c3c"
                                        anchors { top: parent.top; right: parent.right; margins: 4 }
                                        Label {
                                            text: "x"; color: "white"; font.pixelSize: 12
                                            anchors.centerIn: parent
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: recSetModel.set(index, { imagePath: "" })
                                        }
                                    }
                                }

                                // Audio box
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 72
                                    radius: 8
                                    color: "#f7f9fb"
                                    border.color: "#c8d6e5"
                                    border.width: 1

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            page.selectedCardIndex = index
                                            page.activeCardIndex   = index
                                            audioPickerDialog.open()
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Label {
                                            text: {
                                                if (audioPath === "") return qsTr("Add audio")
                                                var parts = audioPath.split("/")
                                                var name = parts[parts.length - 1]
                                                return name.length > 16 ? name.substring(0, 14) + "…" : name
                                            }
                                            font.pixelSize: 11
                                            color: audioPath !== "" ? "#27ae60" : "#95a5a6"
                                            Layout.alignment: Qt.AlignHCenter
                                            wrapMode: Text.NoWrap
                                        }

                                        // Play / Stop button for file audio
                                        Button {
                                            visible: audioPath !== ""
                                            Layout.alignment: Qt.AlignHCenter
                                            implicitWidth: 52; implicitHeight: 26

                                            readonly property bool isPlaying:
                                                audioPlayer.playbackState === MediaPlayer.PlayingState &&
                                                page.currentPlayingPath === audioPath

                                            text: isPlaying ? qsTr("■ Stop") : qsTr("▶ Play")
                                            font.pixelSize: 10

                                            background: Rectangle {
                                                radius: 13
                                                color: parent.isPlaying
                                                    ? (parent.pressed ? "#c0392b" : "#e74c3c")
                                                    : (parent.pressed ? "#1a6ca8" : "#3498db")
                                            }
                                            contentItem: Text {
                                                text: parent.text; color: "white"; font: parent.font
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            onClicked: {
                                                if (isPlaying) {
                                                    audioPlayer.stop()
                                                    page.currentPlayingPath = ""
                                                } else {
                                                    audioPlayer.stop()
                                                    page.currentPlayingPath = audioPath
                                                    audioPlayer.source = audioPath
                                                    audioPlayer.play()
                                                }
                                            }
                                        }

                                        // Row: TTS preview + Record mic (when no audio file set)
                                        RowLayout {
                                            visible: audioPath === ""
                                            Layout.alignment: Qt.AlignHCenter
                                            spacing: 6

                                            // TTS preview
                                            Button {
                                                visible: exprField.text.trim() !== ""
                                                implicitWidth: 58; implicitHeight: 24

                                                readonly property bool isSpeakingThis:
                                                    MediaHelper.speaking &&
                                                    page.currentPlayingPath === ("tts://" + expression)

                                                text: isSpeakingThis ? qsTr("■") : qsTr("▶ TTS")
                                                font.pixelSize: 10

                                                background: Rectangle {
                                                    radius: 12
                                                    color: parent.isSpeakingThis
                                                        ? (parent.pressed ? "#c0392b" : "#e74c3c")
                                                        : (parent.pressed ? "#7f5b00" : "#f39c12")
                                                }
                                                contentItem: Text {
                                                    text: parent.text; color: "white"; font: parent.font
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                onClicked: {
                                                    var key = "tts://" + expression
                                                    if (isSpeakingThis) {
                                                        MediaHelper.stopSpeaking()
                                                        page.currentPlayingPath = ""
                                                    } else {
                                                        MediaHelper.stopSpeaking()
                                                        audioPlayer.stop()
                                                        page.currentPlayingPath = key
                                                        MediaHelper.speak(exprField.text.trim(), languageFrom)
                                                    }
                                                }
                                            }

                                            // Microphone record button
                                            Button {
                                                implicitWidth: 58; implicitHeight: 24

                                                readonly property bool isRecordingThis:
                                                    audioRecorder.recorderState === MediaRecorder.RecordingState &&
                                                    page.recordingCardIndex === index

                                                text: isRecordingThis ? qsTr("⬛ Stop") : qsTr("● Rec")
                                                font.pixelSize: 10

                                                background: Rectangle {
                                                    radius: 12
                                                    color: parent.isRecordingThis
                                                        ? (parent.pressed ? "#c0392b" : "#e74c3c")
                                                        : (parent.pressed ? "#1a3a00" : "#27ae60")
                                                }
                                                contentItem: Text {
                                                    text: parent.text; color: "white"; font: parent.font
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                onClicked: {
                                                    if (isRecordingThis) {
                                                        audioRecorder.stop()
                                                    } else {
                                                        // Stop any other active recording first
                                                        if (audioRecorder.recorderState === MediaRecorder.RecordingState)
                                                            audioRecorder.stop()
                                                        if (MediaHelper.hasMicrophonePermission()) {
                                                            page.startRecording(index)
                                                        } else {
                                                            page.pendingRecordCardIndex = index
                                                            MediaHelper.requestMicrophonePermission()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Remove audio
                                    Rectangle {
                                        visible: audioPath !== ""
                                        width: 20; height: 20
                                        radius: 10
                                        color: "#e74c3c"
                                        anchors { top: parent.top; right: parent.right; margins: 4 }
                                        Label {
                                            text: "x"; color: "white"; font.pixelSize: 12
                                            anchors.centerIn: parent
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (page.currentPlayingPath === audioPath)
                                                    audioPlayer.stop()
                                                recSetModel.set(index, { audioPath: "" })
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component.onCompleted: {
                recSetModel.append({
                    languageFrom: LanguageHelper.English,
                    languageTo:   LanguageHelper.English,
                    expression: "", hint: "", audioPath: "", imagePath: ""
                })
                page.selectedCardIndex = 0
            }
        }

        // ── Add / Remove ──────────────────────────────────────────────────────
        RowLayout {
            spacing: 8

            Button {
                text: qsTr("+ Add word")
                Layout.fillWidth: true
                background: Rectangle { radius: 8; color: parent.pressed ? "#2980b9" : "#3498db" }
                contentItem: Text {
                    text: parent.text; color: "white"; font: parent.font
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    var lastLangFrom = LanguageHelper.NotSelected
                    var lastLangTo   = LanguageHelper.NotSelected
                    if (recSetModel.count > 0) {
                        var last = recSetModel.get(recSetModel.count - 1)
                        lastLangFrom = last.languageFrom
                        lastLangTo   = last.languageTo
                    }
                    recSetModel.append({
                        languageFrom: lastLangFrom,
                        languageTo:   lastLangTo,
                        expression: "", hint: "", audioPath: "", imagePath: ""
                    })
                    page.selectedCardIndex = recSetModel.count - 1
                }
            }

            Button {
                text: qsTr("Remove")
                enabled: recSetModel.count > 0
                Layout.fillWidth: true
                background: Rectangle {
                    radius: 8
                    color: parent.enabled ? (parent.pressed ? "#c0392b" : "#e74c3c") : "#bbb"
                }
                contentItem: Text {
                    text: parent.text; color: "white"; font: parent.font
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    var idx = page.selectedCardIndex
                    if (idx >= 0 && idx < recSetModel.count) {
                        if (page.currentPlayingPath !== "" &&
                                recSetModel.get(idx).audioPath === page.currentPlayingPath)
                            audioPlayer.stop()
                        recSetModel.remove(idx)
                        page.selectedCardIndex = Math.min(idx, recSetModel.count - 1)
                    }
                }
            }
        }
    }

    // ── Footer ────────────────────────────────────────────────────────────────
    footer: Rectangle {
        height: footerRow.implicitHeight + 24
        color: "#2c3e50"

        RowLayout {
            id: footerRow
            anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 12; bottomMargin: 12 }
            spacing: 12

            Button {
                text: qsTr("Save")
                Layout.fillWidth: true
                background: Rectangle { radius: 8; color: parent.pressed ? "#1e8449" : "#27ae60" }
                contentItem: Text {
                    text: parent.text; color: "white"; font.pixelSize: 16; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: creatingRecSetSave()
            }

            Button {
                text: qsTr("Cancel")
                Layout.fillWidth: true
                background: Rectangle { radius: 8; color: parent.pressed ? "#555" : "#7f8c8d" }
                contentItem: Text {
                    text: parent.text; color: "white"; font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: creatingRecSetCancel()
            }
        }
    }
}
