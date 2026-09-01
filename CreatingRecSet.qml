import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia
import LanguageHelper
import AppController
import MediaHelper
import GeminiHelper

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
    property bool titleError: false
    property string titleErrorMessage: ""
    property string aiError: ""
    property bool aiEditingKey: GeminiHelper.apiKey === ""
    readonly property bool aiGenerating: GeminiHelper.generating
    // "card" = languagePickerPopup edits recSetModel[langPickerCardIndex]; "aiFrom"/"aiTo" = it edits the AI dialog's own selection instead.
    property string langPickerTarget: "card"
    property int aiFromLanguageId: LanguageHelper.English
    property int aiToLanguageId: LanguageHelper.English
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

    // Fires off an image fetch for every existing card that has a word but no
    // image yet — used when Auto-fetch is switched on for a set that already
    // has words in it, not just words typed afterward.
    function fetchMissingImagesForAllCards() {
        for (var i = 0; i < recSetModel.count; i++) {
            var w = recSetModel.get(i)
            if (w.expression && w.expression.trim() !== "" && w.imagePath === "")
                MediaHelper.fetchWikimediaImageUrl(w.expression.trim(), i, w.languageFrom)
        }
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

    // ── GeminiHelper signal handlers ──────────────────────────────────────────
    Connections {
        target: GeminiHelper
        function onWordSetGenerated(words) {
            // Replace the single blank starter card, if nothing else was typed.
            if (recSetModel.count === 1) {
                var only = recSetModel.get(0)
                if (only.expression === "" && only.hint === "")
                    recSetModel.remove(0)
            }
            for (var i = 0; i < words.length; i++)
                recSetModel.append(words[i])
            if (topTextField.text.trim() === "")
                topTextField.text = aiThemeField.text.trim()
            if (page.autoMedia)
                page.fetchMissingImagesForAllCards()
            page.selectedCardIndex = Math.max(0, recSetModel.count - 1)
            page.aiError = ""
            aiGeneratorPopup.close()
        }
        function onGenerationFailed(error) {
            page.aiError = error
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
                                if (page.langPickerTarget === "aiFrom") {
                                    page.aiFromLanguageId = modelData.id
                                } else if (page.langPickerTarget === "aiTo") {
                                    page.aiToLanguageId = modelData.id
                                } else {
                                    var cardIdx = page.langPickerCardIndex
                                    if (cardIdx >= 0) {
                                        if (page.langPickerIsFrom)
                                            recSetModel.set(cardIdx, { languageFrom: modelData.id })
                                        else
                                            recSetModel.set(cardIdx, { languageTo: modelData.id })
                                    }
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

    // ── AI generator popup ───────────────────────────────────────────────────
    Popup {
        id: aiGeneratorPopup
        // Keep the popup within whatever room the on-screen keyboard leaves —
        // anchors.centerIn: Overlay.overlay ignored the keyboard entirely, so once
        // it opened (e.g. typing the theme), everything below the focused field
        // ended up hidden underneath it with no way to reach it.
        //
        // Qt.inputMethod.keyboardRectangle isn't reliably in the same coordinate
        // space as the QML scene across platforms (notably Android, where it can
        // come back in device pixels while the scene is in logical pixels), so
        // subtracting it directly produced a wildly wrong, tiny popup. Instead,
        // only trust the boolean Qt.inputMethod.visible and claim a generous fixed
        // share of the screen while it's up; the ScrollView below is the real
        // safety net for anything that still doesn't fit.
        readonly property bool keyboardUp: Qt.inputMethod.visible
        readonly property real overlayHeight: Overlay.overlay ? Overlay.overlay.height : 640
        readonly property real visibleAreaHeight: keyboardUp ? overlayHeight * 0.55 : overlayHeight * 0.92

        x: Overlay.overlay ? (Overlay.overlay.width - width) / 2 : 0
        y: keyboardUp ? 16 : Math.max(20, (overlayHeight - height) / 2)
        width: Math.min(parent.width - 32, 380)
        height: Math.min(implicitHeight, visibleAreaHeight)
        padding: 0
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        // Closing while a request is in flight (Cancel, tap outside, Escape,
        // the Android back gesture) must abort it — otherwise the dialog just
        // disappears while Gemini keeps "generating" forever in the background,
        // and reopening it shows a stuck, unresponsive Generate button.
        onClosed: if (page.aiGenerating) GeminiHelper.cancelGeneration()

        background: Rectangle {
            radius: 18
            color: "white"
            layer.enabled: true
            border.color: "#e7d5ef"
            border.width: 1
        }

        // A ScrollView so that whenever the full dialog doesn't fit the space
        // left by the keyboard, every field and both footer buttons stay
        // reachable by scrolling instead of being clipped off underneath it.
        contentItem: ScrollView {
            id: aiPopupScrollView
            clip: true
            contentWidth: availableWidth

            Column {
            width: aiPopupScrollView.availableWidth

            // ── Gradient header ──────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: 68
                radius: 18
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#a55cc2" }
                    GradientStop { position: 1.0; color: "#8e44ad" }
                }
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 18; color: "#8e44ad"
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("✨ AI Word Set Generator")
                        font.pixelSize: 17; font.bold: true; color: "white"
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Powered by Gemini")
                        font.pixelSize: 10; color: "#f3e5f9"
                    }
                }
            }

            Item {
                width: parent.width
                implicitHeight: formColumn.implicitHeight + 36
                height: implicitHeight

                Column {
                    id: formColumn
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                    spacing: 12

                    RowLayout {
                        width: parent.width
                        visible: !page.aiEditingKey
                        spacing: 8
                        Label {
                            text: qsTr("🔑 Gemini API key saved")
                            font.pixelSize: 11
                            color: "#27ae60"
                            Layout.fillWidth: true
                        }
                        Label {
                            text: qsTr("Change")
                            font.pixelSize: 11
                            font.underline: true
                            font.bold: true
                            color: "#9b59b6"
                            MouseArea { anchors.fill: parent; onClicked: page.aiEditingKey = true }
                        }
                    }

                    Column {
                        width: parent.width
                        visible: page.aiEditingKey
                        spacing: 5
                        Label {
                            width: parent.width
                            text: qsTr("🔑 Gemini API key (free — get one at aistudio.google.com/apikey). Stored on this device only, for now.")
                            font.pixelSize: 11
                            color: "#7f8c8d"
                            wrapMode: Text.WordWrap
                        }
                        TextField {
                            id: aiKeyField
                            width: parent.width
                            echoMode: TextInput.Password
                            placeholderText: qsTr("Paste API key…")
                            font.pixelSize: 13
                            background: Rectangle {
                                radius: 8; color: "#faf6fc"
                                border.color: aiKeyField.activeFocus ? "#9b59b6" : "#e7d5ef"
                                border.width: aiKeyField.activeFocus ? 2 : 1
                            }
                            leftPadding: 10
                            onEditingFinished: {
                                if (text.trim() !== "") {
                                    GeminiHelper.apiKey = text.trim()
                                    text = ""
                                    page.aiEditingKey = false
                                }
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        text: qsTr("🎯 Theme")
                        font.pixelSize: 12; font.bold: true; color: "#2c3e50"
                    }
                    Rectangle {
                        width: parent.width
                        height: 88
                        radius: 10
                        color: "#faf6fc"
                        border.color: aiThemeField.activeFocus ? "#9b59b6" : "#e7d5ef"
                        border.width: aiThemeField.activeFocus ? 2 : 1

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 6
                            clip: true
                            TextArea {
                                id: aiThemeField
                                placeholderText: qsTr("Describe the set you want — e.g. \"kitchen items you'd find in a French household\" or \"business travel phrases for a conference\"…")
                                font.pixelSize: 14
                                color: "#2c3e50"
                                wrapMode: TextArea.Wrap
                                selectByMouse: true
                                background: null
                            }
                        }
                    }

                    RowLayout {
                        width: parent.width
                        spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Label { text: qsTr("🗣 Word language"); font.pixelSize: 11; color: "#7f8c8d" }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: 8
                                color: "#faf6fc"
                                border.color: "#e7d5ef"; border.width: 1
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                                    spacing: 2
                                    Label {
                                        Layout.fillWidth: true
                                        text: LanguageHelper.languageNames()[page.aiFromLanguageId]
                                        font.pixelSize: 13; color: "#2c3e50"
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    // Label { text: "▾"; font.pixelSize: 10; color: "#9b59b6" }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        page.langPickerTarget = "aiFrom"
                                        page.langPickerIsFrom = true
                                        page.langPickerCurrentId = page.aiFromLanguageId
                                        languagePickerPopup.open()
                                    }
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Label { text: qsTr("💡 Hint language"); font.pixelSize: 11; color: "#7f8c8d" }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: 8
                                color: "#faf6fc"
                                border.color: "#e7d5ef"; border.width: 1
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                                    spacing: 2
                                    Label {
                                        Layout.fillWidth: true
                                        text: LanguageHelper.languageNames()[page.aiToLanguageId]
                                        font.pixelSize: 13; color: "#2c3e50"
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    // Label { text: "▾"; font.pixelSize: 10; color: "#9b59b6" }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        page.langPickerTarget = "aiTo"
                                        page.langPickerIsFrom = false
                                        page.langPickerCurrentId = page.aiToLanguageId
                                        languagePickerPopup.open()
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        width: parent.width
                        spacing: 10
                        Label {
                            text: qsTr("🔢 Number of words")
                            font.pixelSize: 12; color: "#2c3e50"
                            Layout.fillWidth: true
                        }
                        SpinBox {
                            id: aiCountSpin
                            from: 1; to: 30; value: 10
                            editable: true
                            font.pixelSize: 14
                            implicitWidth: 140
                            implicitHeight: 40

                            contentItem: TextInput {
                                anchors {
                                    left: parent.left; leftMargin: 36
                                    right: parent.right; rightMargin: 36
                                    verticalCenter: parent.verticalCenter
                                }
                                text: aiCountSpin.textFromValue(aiCountSpin.value, aiCountSpin.locale)
                                font: aiCountSpin.font
                                color: "#2c3e50"
                                horizontalAlignment: Qt.AlignHCenter
                                verticalAlignment: Qt.AlignVCenter
                                readOnly: !aiCountSpin.editable
                                validator: aiCountSpin.validator
                                inputMethodHints: Qt.ImhDigitsOnly
                            }
                            up.indicator: Rectangle {
                                x: aiCountSpin.width - width
                                width: 36
                                height: aiCountSpin.height
                                radius: 8
                                color: aiCountSpin.up.pressed ? "#7d3c98" : "#9b59b6"
                                Text { text: "+"; anchors.centerIn: parent; color: "white"; font.pixelSize: 16; font.bold: true }
                            }
                            down.indicator: Rectangle {
                                x: 0
                                width: 36
                                height: aiCountSpin.height
                                radius: 8
                                color: aiCountSpin.down.pressed ? "#7d3c98" : "#9b59b6"
                                Text { text: "−"; anchors.centerIn: parent; color: "white"; font.pixelSize: 16; font.bold: true }
                            }
                            background: Rectangle {
                                radius: 8
                                color: "#faf6fc"
                                border.color: "#e7d5ef"
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        visible: page.aiError !== ""
                        text: "⚠ " + page.aiError
                        color: "#e74c3c"
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        width: parent.width
                        visible: page.aiGenerating
                        spacing: 8
                        BusyIndicator {
                            running: page.aiGenerating
                            implicitWidth: 22; implicitHeight: 22
                            Material.accent: "#9b59b6"
                        }
                        Label { text: qsTr("Asking Gemini…"); font.pixelSize: 12; color: "#7f8c8d" }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#ececec" }

            Row {
                width: parent.width
                ItemDelegate {
                    width: parent.width / 2
                    height: 52
                    background: Rectangle { color: parent.pressed ? "#f0f4f8" : "white"; radius: 18 }
                    contentItem: Text {
                        text: page.aiGenerating ? qsTr("Cancel request") : qsTr("Cancel")
                        color: "#e74c3c"
                        font.pixelSize: 15; font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    // aiGeneratorPopup.onClosed aborts the in-flight request, if any.
                    onClicked: aiGeneratorPopup.close()
                }
                ItemDelegate {
                    id: generateButton
                    width: parent.width / 2
                    height: 52
                    enabled: !page.aiGenerating && aiThemeField.text.trim() !== "" && GeminiHelper.apiKey !== ""
                    background: Item {
                        Rectangle {
                            anchors.fill: parent
                            radius: 18
                            visible: generateButton.enabled
                            opacity: generateButton.pressed ? 0.85 : 1.0
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#a55cc2" }
                                GradientStop { position: 1.0; color: "#8e44ad" }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: 18
                            color: "#bbb"
                            visible: !generateButton.enabled
                        }
                    }
                    contentItem: Text {
                        text: qsTr("✨ Generate"); color: "white"
                        font.pixelSize: 15; font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        page.aiError = ""
                        GeminiHelper.generateWordSet(aiThemeField.text.trim(), page.aiFromLanguageId,
                                                      page.aiToLanguageId, aiCountSpin.value)
                    }
                }
            }
            }
        }
    }

    // ── Header ────────────────────────────────────────────────────────────────
    header: ToolBar {
        height: 56 + SafeArea.margins.top
        background: Rectangle { color: "#2c3e50" }

        RowLayout {
            anchors {
                left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: 8; rightMargin: 8
            }
            height: 56
            spacing: 4

            Button {
                implicitWidth: 76
                implicitHeight: 36
                text: qsTr("✨ AI")
                background: Rectangle {
                    radius: 8
                    color: parent.pressed ? "#7d3c98" : "#9b59b6"
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 13
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    page.aiError = ""
                    aiGeneratorPopup.open()
                }
            }

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
                border.color: page.titleError ? "#e74c3c"
                            : topTextField.activeFocus ? "#3498db" : "#dce1e7"
                border.width: (page.titleError || topTextField.activeFocus) ? 2 : 1
            }
            leftPadding: 12
            onTextChanged: page.titleError = false
        }

        Label {
            visible: page.titleError && page.titleErrorMessage !== ""
            text: page.titleErrorMessage
            color: "#e74c3c"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
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
                    text: qsTr("Auto-fetch images")
                    font.pixelSize: 13
                    color: "#2c3e50"
                    Layout.fillWidth: true
                }

                Switch {
                    id: autoMediaSwitch
                    checked: page.autoMedia
                    onCheckedChanged: {
                        page.autoMedia = checked
                        if (checked)
                            page.fetchMissingImagesForAllCards()
                    }
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
                                            text: languageFrom >= 0 ? LanguageHelper.languageNames()[languageFrom]
                                                                    : qsTr("Not selected")
                                            font.pixelSize: 11; color: "#2c3e50"
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        // Label { text: "▾"; font.pixelSize: 10; color: "#7f8c8d" }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            page.langPickerTarget = "card"
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
                                            text: languageTo >= 0 ? LanguageHelper.languageNames()[languageTo]
                                                                  : qsTr("Not selected")
                                            font.pixelSize: 11; color: "#2c3e50"
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        // Label { text: "▾"; font.pixelSize: 10; color: "#7f8c8d" }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            page.langPickerTarget = "card"
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

                            // ── Example usage ────────────────────────────────
                            Label {
                                text: qsTr("Example usage")
                                font.pixelSize: 12
                                font.bold: true
                                color: "#2c3e50"
                            }
                            TextField {
                                id: exampleUsageField
                                Layout.fillWidth: true
                                placeholderText: qsTr("Example sentence using the word...")
                                text: exampleUsage
                                font.pixelSize: 15
                                background: Rectangle {
                                    radius: 6; color: "#f7f9fb"
                                    border.color: exampleUsageField.activeFocus ? "#3498db" : "#e0e6ed"
                                }
                                leftPadding: 10
                                onActiveFocusChanged: if (activeFocus) page.selectedCardIndex = index
                                onEditingFinished: recSetModel.set(index, { exampleUsage: exampleUsageField.text })
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
                                    height: 96
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
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4

                                        Label {
                                            text: imagePath !== "" ? qsTr("Change image") : qsTr("Add image")
                                            font.pixelSize: 11
                                            color: imagePath !== "" ? "#27ae60" : "#95a5a6"
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            // Auto-fetch button
                                            Button {
                                                visible: imagePath === "" && page.autoMedia && exprField.text.trim() !== ""
                                                Layout.fillWidth: true
                                                implicitHeight: 38
                                                text: qsTr("Fetch")
                                                font.pixelSize: 10
                                                background: Rectangle {
                                                    radius: 19
                                                    color: parent.pressed ? "#2980b9" : "#3498db"
                                                }
                                                contentItem: Item {
                                                    anchors.fill: parent
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: parent.parent.text
                                                        color: "white"
                                                        font.pixelSize: 10
                                                    }
                                                }
                                                onClicked: {
                                                    page.activeCardIndex = index
                                                    MediaHelper.fetchWikimediaImageUrl(exprField.text.trim(), index, languageFrom)
                                                }
                                            }

                                            // Camera button
                                            Button {
                                                Layout.fillWidth: true
                                                implicitHeight: 38
                                                text: qsTr("Camera")
                                                font.pixelSize: 10
                                                background: Rectangle {
                                                    radius: 19
                                                    color: parent.pressed ? "#7f5b00" : "#f39c12"
                                                }
                                                contentItem: Item {
                                                    anchors.fill: parent
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: parent.parent.text
                                                        color: "white"
                                                        font.pixelSize: 10
                                                    }
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
                                        width: 24; height: 24
                                        radius: 12
                                        color: "#e74c3c"
                                        anchors { top: parent.top; right: parent.right; margins: 4 }
                                        Text {
                                            text: "x"; color: "white"; font.pixelSize: 14; font.bold: true
                                            anchors.centerIn: parent
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
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
                                    height: 96
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
                                        anchors.fill: parent
                                        anchors.margins: 8
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
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.NoWrap
                                        }

                                        // One 32px slot — Play or TTS+Rec, never both
                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: 38

                                            // Play / Stop (when audio file exists)
                                            Button {
                                                visible: audioPath !== ""
                                                anchors.fill: parent

                                                readonly property bool isPlaying:
                                                    audioPlayer.playbackState === MediaPlayer.PlayingState &&
                                                    page.currentPlayingPath === audioPath

                                                text: isPlaying ? qsTr("■ Stop") : qsTr("▶ Play")
                                                font.pixelSize: 10

                                                background: Rectangle {
                                                    radius: 19
                                                    color: parent.isPlaying
                                                        ? (parent.pressed ? "#c0392b" : "#e74c3c")
                                                        : (parent.pressed ? "#1a6ca8" : "#3498db")
                                                }
                                                contentItem: Item {
                                                    anchors.fill: parent
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: parent.parent.text
                                                        color: "white"
                                                        font.pixelSize: 10
                                                    }
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

                                            // TTS + Rec (when no audio file)
                                            RowLayout {
                                                visible: audioPath === ""
                                                anchors.fill: parent
                                                spacing: 6

                                                // TTS preview
                                                Button {
                                                    visible: exprField.text.trim() !== ""
                                                    Layout.fillWidth: true
                                                    implicitHeight: 38

                                                    readonly property bool isSpeakingThis:
                                                        MediaHelper.speaking &&
                                                        page.currentPlayingPath === ("tts://" + expression)

                                                    text: isSpeakingThis ? qsTr("■") : qsTr("▶ TTS")
                                                    font.pixelSize: 10

                                                    background: Rectangle {
                                                        radius: 19
                                                        color: parent.isSpeakingThis
                                                            ? (parent.pressed ? "#c0392b" : "#e74c3c")
                                                            : (parent.pressed ? "#7f5b00" : "#f39c12")
                                                    }
                                                    contentItem: Item {
                                                        anchors.fill: parent
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: parent.parent.text
                                                            color: "white"
                                                            font.pixelSize: 10
                                                        }
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
                                                    Layout.fillWidth: true
                                                    implicitHeight: 38

                                                    readonly property bool isRecordingThis:
                                                        audioRecorder.recorderState === MediaRecorder.RecordingState &&
                                                        page.recordingCardIndex === index

                                                    text: isRecordingThis ? qsTr("⬛ Stop") : qsTr("● Rec")
                                                    font.pixelSize: 10

                                                    background: Rectangle {
                                                        radius: 19
                                                        color: parent.isRecordingThis
                                                            ? (parent.pressed ? "#c0392b" : "#e74c3c")
                                                            : (parent.pressed ? "#1a3a00" : "#27ae60")
                                                    }
                                                    contentItem: Item {
                                                        anchors.fill: parent
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: parent.parent.text
                                                            color: "white"
                                                            font.pixelSize: 10
                                                        }
                                                    }
                                                    onClicked: {
                                                        if (isRecordingThis) {
                                                            audioRecorder.stop()
                                                        } else {
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
                                    }

                                    // Remove audio
                                    Rectangle {
                                        visible: audioPath !== ""
                                        width: 24; height: 24
                                        radius: 12
                                        color: "#e74c3c"
                                        anchors { top: parent.top; right: parent.right; margins: 4 }
                                        Text {
                                            text: "x"; color: "white"; font.pixelSize: 14; font.bold: true
                                            anchors.centerIn: parent
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
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
                    expression: "", hint: "", audioPath: "", imagePath: "", exampleUsage: ""
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
                        expression: "", hint: "", audioPath: "", imagePath: "", exampleUsage: ""
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
        height: footerRow.implicitHeight + 24 + SafeArea.margins.bottom
        color: "#2c3e50"

        RowLayout {
            id: footerRow
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                leftMargin: 16; rightMargin: 16; topMargin: 12
            }
            spacing: 12

            Button {
                text: qsTr("Save")
                Layout.fillWidth: true
                background: Rectangle { radius: 8; color: parent.pressed ? "#1e8449" : "#27ae60" }
                contentItem: Text {
                    text: parent.text; color: "white"; font.pixelSize: 16; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (topTextField.text.trim() === "") {
                        page.titleErrorMessage = qsTr("Title is required")
                        page.titleError = true
                    } else {
                        creatingRecSetSave()
                    }
                }
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
