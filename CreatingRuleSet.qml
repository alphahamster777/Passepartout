import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia
import LanguageHelper
import AppController
import FirebaseAiHelper

Page {
    id: page
    signal creatingRuleSetCancel()
    signal creatingRuleSetSave()
    property alias ruleSetModelRef: ruleSetModel
    property alias ruleSetName: topTextField.text
    property alias theoryBlocksModelRef: theoryBlocksModel
    property int ruleSetIdx: -1
    property string folderPath: ""
    property int selectedCardIndex: 0
    property bool titleError: false
    property string titleErrorMessage: ""
    property string previewPlayingPath: ""
    property string aiError: ""
    readonly property QtObject aiBackend: FirebaseAiHelper
    readonly property bool aiGenerating: page.aiBackend.ruleGenerating
    // Briefly highlights an MC question card whose "Correct answer(s)" was
    // left unset when Save is pressed — see the Save button's onClicked and
    // mcErrorFlashTimer below.
    property int mcErrorCardIndex: -1
    // Assigned to newly-added questions (independent of their position in
    // the list), so RuleTestController can tell a question was edited or
    // deleted — rather than merely reordered — when the learner is midway
    // through a test and comes back to it after editing.
    property int nextQuestionId: 1
    // Set by "+ Add question" (see the footer below), consumed by
    // pageScrollView's contentHeightChanged handler — see that Connections
    // for why a plain Qt.callLater right after ruleSetModel.append() can't
    // do this scroll itself.
    property bool pendingScrollToNewCard: false

    // ── AI generator language picker state ──────────────────────────────────
    // Mirrors CreatingRecSet.qml's aiFromLanguageId/aiToLanguageId: term
    // language governs the generated question sentences/options/answers
    // (the language being learned), explanation language governs the
    // "theory" paragraphs — same split as that file's "Word language"/"Hint
    // language", reusing the same app-wide "meaning language" default so a
    // learner can be quizzed in the target language while still reading the
    // rule explanation in one they understand.
    property string langPickerTarget: "term"   // "term" or "explanation"
    property int langPickerCurrentId: -1
    property int aiTermLanguageId: LanguageHelper.English
    property int aiExplanationLanguageId: AppController.defaultMeaningLanguage
    // "Explain grammar" toggle below — ticked by default, since most
    // creators do want the generated "theory" paragraphs. Unticking skips
    // asking Gemini for them (see FirebaseAiHelper::generateRuleSet's
    // includeTheory), which also makes the Explanation language picker
    // moot until it's ticked again.
    property bool aiIncludeTheory: true
    readonly property var langEntries: LanguageHelper.sortedLanguageEntries()

    Timer {
        id: mcErrorFlashTimer
        interval: 1200
        onTriggered: page.mcErrorCardIndex = -1
    }

    // ── AI backend signal handlers ─────────────────────────────────────────────
    Connections {
        target: page.aiBackend
        function onRuleSetGenerated(ruleSet) {
            // Replaces whatever's here rather than appending — unlike
            // CreatingRecSet.qml's word cards, a new rule set starts with
            // zero questions (no single blank "starter" row to detect/
            // replace), so there's no less-surprising alternative to
            // "Generate" fully populating the page.
            if (page.ruleSetName.trim() === "")
                page.ruleSetName = aiThemeField.text.trim()
            page.hydrateTheoryBlocks(theoryBlocksModel, ruleSet.theory || {})
            ruleSetModel.clear()
            var questions = ruleSet.questions || []
            for (var i = 0; i < questions.length; ++i) {
                // A throw here would otherwise abort this whole handler
                // silently — theory loaded, no questions, popup left open
                // with no message. Skip the offending question instead and
                // surface why.
                try {
                    var row = page.ruleSetRowFromQuestion(questions[i])
                    row.id = page.nextQuestionId++
                    ruleSetModel.append(row)
                } catch (e) {
                    console.warn("Rule set question", i, "(", questions[i].type, ") failed:", e)
                    page.aiError = qsTr("Could not load a %1 question: %2").arg(questions[i].type).arg(String(e))
                }
            }
            page.selectedCardIndex = ruleSetModel.count > 0 ? ruleSetModel.count - 1 : 0
            // A narrow/repetitive topic can make Gemini (or the server's own
            // validation) come up short of what was asked for even though
            // the call itself succeeded — see AiRuleSetShared::parseRuleSet's
            // "requestedCount". The generated questions are still usable and
            // stay loaded behind the popup, but closing silently in that case
            // would hide a real shortfall the creator never asked for and
            // might not otherwise notice, so the popup stays open with a
            // warning instead — same as a hard failure.
            var requested = ruleSet.requestedCount || 0
            if (page.aiError !== "") {
                // A per-question failure above already explained itself.
            } else if (requested > 0 && questions.length < requested) {
                page.aiError = qsTr("Generated only %1 of %2 requested questions — try a broader topic, or lower the counts above.")
                    .arg(questions.length).arg(requested)
            } else {
                page.aiError = ""
                aiGeneratorPopup.close()
            }
        }
        function onRuleGenerationFailed(error) {
            page.aiError = error
        }
    }

    // Returns the index of the first "mc"-type question (with non-blank
    // question text) that has no correct answer marked, or -1 if every
    // multiple-choice question is valid.
    function findUnmarkedMCQuestion() {
        for (var i = 0; i < ruleSetModel.count; ++i) {
            var row = ruleSetModel.get(i)
            if (row.questionType !== "mc") continue
            if ((row.questionText || "").trim() === "") continue
            if (parseIndices(row.mcCorrectIndicesText).length === 0) return i
        }
        return -1
    }

    // Same idea as findUnmarkedMCQuestion(), for "combobox": every blank
    // (option group) parsed from poolOptionsText needs its own tapped
    // correct-answer chip, or the question can't be saved.
    function findUnmarkedComboQuestion() {
        for (var i = 0; i < ruleSetModel.count; ++i) {
            var row = ruleSetModel.get(i)
            if (row.questionType !== "combobox") continue
            if ((row.questionText || "").trim() === "") continue
            var groups = parseOptionsPerGap(row.poolOptionsText)
            if (groups.length === 0) return i
            var correctIdx = parseComboCorrectIndices(row.comboCorrectIndicesText)
            for (var g = 0; g < groups.length; ++g) {
                var ci = g < correctIdx.length ? correctIdx[g] : -1
                if (ci < 0 || ci >= groups[g].length) return i
            }
        }
        return -1
    }

    // A multiple-choice question's set of correct-answer indices is kept as
    // a comma-separated string (like answersText/mcOptionsText elsewhere in
    // this row), not a JS array — QML's ListModel silently turns an array
    // assigned to a role into a nested list-model object instead of storing
    // it as a plain array, which broke reading it back (.indexOf() on that
    // object threw, silently swallowing every tap on a "correct answer" chip).
    function parseIndices(text) {
        return (text || "").split(",")
            .map(function(s) { return s.trim() })
            .filter(function(s) { return s !== "" })
            .map(function(s) { return parseInt(s, 10) })
    }

    // Splits `text` on `delimiter`, honoring "\\" as an escaped literal
    // backslash and "\<delimiter>" as an escaped literal occurrence of the
    // delimiter itself inside one option — e.g. splitting "goes\, going" on
    // "," keeps "goes, going" as a single option instead of breaking it in
    // two. Any other backslash sequence (e.g. the "\_" blank marker below)
    // is left untouched, since it isn't this delimiter.
    function splitEscaped(text, delimiter) {
        var result = []
        var current = ""
        var i = 0
        var s = text || ""
        var dLen = delimiter.length
        while (i < s.length) {
            if (s[i] === "\\" && s[i + 1] === "\\") {
                current += "\\"; i += 2
            } else if (s[i] === "\\" && s.substr(i + 1, dLen) === delimiter) {
                current += delimiter; i += 1 + dLen
            } else if (s.substr(i, dLen) === delimiter) {
                result.push(current); current = ""; i += dLen
            } else {
                current += s[i]; i += 1
            }
        }
        result.push(current)
        return result
    }

    // "___" authored as a whole option means "deliberately blank" — lets a
    // dropdown blank or drag-and-drop tile legitimately be empty (e.g. a
    // blank that's correctly left with no word in it), which a plain empty
    // entry between commas can't express since accidental blank entries
    // (stray commas) are otherwise silently dropped below.
    function decodeBlankMarker(s) {
        return s === "___" ? "" : s
    }

    // A "combobox" question's per-blank option groups: "," separates
    // choices within one blank, "::" separates one blank's group from the
    // next — e.g. "goes, go, going::every, some, most" is two blanks.
    function parseOptionsPerGap(text) {
        return splitEscaped(text || "", "::")
            .map(function(group) {
                return splitEscaped(group, ",")
                    .map(function(s) { return s.trim() })
                    .filter(function(s) { return s !== "" })
                    .map(decodeBlankMarker)
            })
            .filter(function(group) { return group.length > 0 })
    }

    // Which option (by index within its own group) is marked correct for
    // each blank, comma-separated, one entry per blank, in blank order —
    // same "index list as a string" trick as mcCorrectIndicesText/
    // parseIndices, and for the same reason (ListModel can't hold a plain
    // array role). -1 (or a missing entry) means "not yet marked".
    function parseComboCorrectIndices(text) {
        return (text || "").split(",")
            .map(function(s) { return s.trim() })
            .map(function(s) { return s === "" ? -1 : parseInt(s, 10) })
    }

    function setComboCorrectForGroup(rowIndex, groupIdx, optIdx) {
        var row = ruleSetModel.get(rowIndex)
        var current = parseComboCorrectIndices(row.comboCorrectIndicesText)
        while (current.length <= groupIdx) current.push(-1)
        current[groupIdx] = optIdx
        ruleSetModel.set(rowIndex, { comboCorrectIndicesText: current.join(",") })
    }

    // A "dragdrop" question's draggable tile pool — same comma-separated,
    // escape/blank-marker convention as poolOptionsText elsewhere in this row.
    function parseDragdropPool(text) {
        return splitEscaped(text || "", ",")
            .map(function(s) { return s.trim() })
            .filter(function(s) { return s !== "" })
            .map(decodeBlankMarker)
    }

    // Which pool tile (by index into parseDragdropPool's result) has been
    // dragged/tapped into each blank, comma-separated, one entry per blank,
    // in blank order — same "index list as a string" trick as
    // comboCorrectIndicesText, and for the same reason (ListModel can't hold
    // a plain array role). -1 (or a missing entry) means "not yet filled".
    function parseDdPlacements(text) {
        return (text || "").split(",")
            .map(function(s) { return s.trim() })
            .map(function(s) { return s === "" ? -1 : parseInt(s, 10) })
    }

    function setDdPlacement(rowIndex, gapIdx, poolIdx) {
        var row = ruleSetModel.get(rowIndex)
        var current = parseDdPlacements(row.ddPlacementsText)
        while (current.length <= gapIdx) current.push(-1)
        // A tile can only fill one blank at a time — vacate it from
        // wherever else it was already placed before moving it here.
        for (var i = 0; i < current.length; ++i)
            if (current[i] === poolIdx) current[i] = -1
        current[gapIdx] = poolIdx
        ruleSetModel.set(rowIndex, { ddPlacementsText: current.join(",") })
    }

    function clearDdPlacement(rowIndex, gapIdx) {
        var row = ruleSetModel.get(rowIndex)
        var current = parseDdPlacements(row.ddPlacementsText)
        if (gapIdx < current.length) current[gapIdx] = -1
        ruleSetModel.set(rowIndex, { ddPlacementsText: current.join(",") })
    }

    // Same idea as findUnmarkedComboQuestion(), for "dragdrop": every blank
    // in the question text needs a tile placed in it, or the question can't
    // be saved (there'd be no way to know its correct answer).
    function findUnmarkedDragdropQuestion() {
        for (var i = 0; i < ruleSetModel.count; ++i) {
            var row = ruleSetModel.get(i)
            if (row.questionType !== "dragdrop") continue
            if ((row.questionText || "").trim() === "") continue
            var gapCount = (row.questionText || "").split("___").length - 1
            if (gapCount === 0) return i
            var pool = parseDragdropPool(row.poolOptionsText)
            if (pool.length === 0) return i
            var placements = parseDdPlacements(row.ddPlacementsText)
            for (var g = 0; g < gapCount; ++g) {
                var pIdx = g < placements.length ? placements[g] : -1
                if (pIdx < 0 || pIdx >= pool.length) return i
            }
        }
        return -1
    }

    // Inverse of decodeBlankMarker + splitEscaped()'s delimiter-escaping —
    // re-encodes a stored option/answer value back into authored text.
    // Mirrors Main.qml's rootScope.escapeListValue exactly (duplicated
    // rather than shared — see splitEscaped's own comment above for why);
    // needed here for both importFromPath() and the AI generator below,
    // which both hand this page saved-shape data (options/answers as plain
    // strings) that must round-trip through the same authored-text fields
    // as anything typed by hand.
    function escapeListValue(s) {
        if (s === "") return "___"
        return String(s).replace(/\\/g, "\\\\").replace(/,/g, "\\,").replace(/::/g, "\\::")
    }

    // Converts one saved/JSON-shaped question — as returned by both
    // RuleSetManager::readSetFromZip (importFromPath below) and
    // AiRuleSetShared::parseRuleSet (the AI generator below) — into the row
    // shape ruleSetModel expects. Mirrors Main.qml's rootScope.
    // ruleSetRowFromQuestion, which does the same job for editing an
    // existing set — duplicated rather than shared since this page can't
    // reach that other document's rootScope id.
    function ruleSetRowFromQuestion(q) {
        if (q.type === "mc") {
            return {
                questionType: "mc",
                questionText: q.text || "",
                answersText: "",
                mcOptionsText: (q.options || []).map(page.escapeListValue).join(", "),
                mcCorrectIndicesText: (q.correctIndices || []).join(","),
                poolOptionsText: "",
                comboCorrectIndicesText: "",
                ddPlacementsText: "",
                mcSingleAnswer: q.singleAnswer === true
            }
        } else if (q.type === "combobox") {
            var loadedGroups = q.optionsPerGap || []
            var loadedAnswers = q.answers || []
            var comboCorrectIndices = loadedGroups.map(function(group, gIdx) {
                return group.indexOf(loadedAnswers[gIdx])
            })
            return {
                questionType: "combobox",
                questionText: q.text || "",
                answersText: "",
                mcOptionsText: "",
                mcCorrectIndicesText: "",
                poolOptionsText: loadedGroups
                    .map(function(group) { return group.map(page.escapeListValue).join(", ") })
                    .join("::"),
                comboCorrectIndicesText: comboCorrectIndices.join(","),
                ddPlacementsText: "",
                mcSingleAnswer: false
            }
        } else if (q.type === "dragdrop") {
            var ddPool = q.options || []
            var ddSavedAnswers = q.answers || []
            var ddUsed = []
            var ddPlacements = ddSavedAnswers.map(function(ans) {
                for (var pi = 0; pi < ddPool.length; ++pi) {
                    if (ddUsed[pi]) continue
                    if (ddPool[pi] === ans) { ddUsed[pi] = true; return pi }
                }
                return -1
            })
            return {
                questionType: "dragdrop",
                questionText: q.text || "",
                answersText: "",
                mcOptionsText: "",
                mcCorrectIndicesText: "",
                poolOptionsText: ddPool.map(page.escapeListValue).join(", "),
                comboCorrectIndicesText: "",
                ddPlacementsText: ddPlacements.join(","),
                mcSingleAnswer: false
            }
        }
        return {
            questionType: "gap",
            questionText: q.text || "",
            answersText: (q.answers || []).map(page.escapeListValue).join(", "),
            mcOptionsText: "",
            mcCorrectIndicesText: "",
            poolOptionsText: "",
            comboCorrectIndicesText: "",
            ddPlacementsText: "",
            mcSingleAnswer: false
        }
    }

    // Mirrors Main.qml's rootScope.hydrateTheoryBlocks — see
    // ruleSetRowFromQuestion above for why this is duplicated here too.
    function hydrateTheoryBlocks(blocksModelRef, theory) {
        blocksModelRef.clear()
        var blocks = (theory && theory.blocks) || []
        for (var bi = 0; bi < blocks.length; ++bi) {
            var b = blocks[bi]
            blocksModelRef.append({
                kind: b.kind || "text",
                value: b.value || "",
                imgHeight: b.imgHeight || (b.kind === "image" ? 200 : 0)
            })
        }
    }

    // "in 12d 4h" / "in 3h 20m" / "in 45m" / "soon" from an ISO 8601 UTC
    // instant — mirrors CreatingRecSet.qml's own formatResetTime exactly.
    function formatResetTime(isoString) {
        if (!isoString) return ""
        var resetDate = new Date(isoString)
        if (isNaN(resetDate.getTime())) return ""
        var diffMs = resetDate.getTime() - Date.now()
        if (diffMs <= 0) return qsTr("soon")
        var days = Math.floor(diffMs / 86400000)
        var hours = Math.floor((diffMs % 86400000) / 3600000)
        var mins = Math.floor((diffMs % 3600000) / 60000)
        if (days > 0) return qsTr("in %1d %2h").arg(days).arg(hours)
        return hours > 0 ? qsTr("in %1h %2m").arg(hours).arg(mins) : qsTr("in %1m").arg(mins)
    }

    // Populates this page's fields from an imported .ppset's parsed
    // {name, theory, questions} — called both from the header's Import
    // button/FileDialog and from Main.qml's onIncomingFileReady (an
    // "open with" shared file) via the same signal path CreatingRecSet.qml
    // already uses for its own importFromPath.
    function importFromPath(path) {
        var result = AppController.ruleSetManager.readSetFromZip(path)
        if (!result || !result.name) return
        page.ruleSetName = result.name
        page.hydrateTheoryBlocks(theoryBlocksModel, result.theory || {})
        ruleSetModel.clear()
        var questions = result.questions || []
        for (var i = 0; i < questions.length; ++i) {
            var row = page.ruleSetRowFromQuestion(questions[i])
            row.id = i + 1
            ruleSetModel.append(row)
        }
        page.nextQuestionId = questions.length + 1
        page.selectedCardIndex = questions.length > 0 ? questions.length - 1 : 0
    }

    // The Rule Explanation is an ordered list of blocks — "text"
    // (freely editable prose), "image" (with a resizable height) and
    // "audio" — edited directly in place rather than as raw text with
    // placement markers, so what the creator sees here (photo included) is
    // exactly what a learner sees, and reordering is a plain drag of the
    // block itself rather than repositioning a marker inside a text blob.
    ListModel { id: theoryBlocksModel }

    MediaPlayer {
        id: theoryAudioPreviewPlayer
        audioOutput: AudioOutput {}
        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState)
                page.previewPlayingPath = ""
        }
    }

    FileDialog {
        id: theoryImagePickerDialog
        title: qsTr("Select Image")
        nameFilters: ["Images (*.jpg *.jpeg *.png *.gif *.bmp *.webp)"]
        onAccepted: theoryBlocksModel.append({ kind: "image", value: selectedFile.toString(), imgHeight: 200 })
    }

    FileDialog {
        id: theoryAudioPickerDialog
        title: qsTr("Select Audio")
        nameFilters: ["Audio (*.mp3 *.ogg *.wav *.m4a *.aac *.flac *.opus)"]
        onAccepted: theoryBlocksModel.append({ kind: "audio", value: selectedFile.toString(), imgHeight: 0 })
    }

    background: Rectangle { color: "#f0f4f8" }

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
                text: page.ruleSetIdx === -1 ? qsTr("New Rule Set") : qsTr("Edit Rule Set")
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

    FileDialog {
        id: importDialog
        title: qsTr("Import Rule Set")
        nameFilters: ["Passepartout Set (*.ppset)", "All files (*)"]
        onAccepted: page.importFromPath(selectedFile.toString())
    }

    // A labeled +/- count control for one question type in the AI generator
    // popup below — pulled out as an inline component since the popup needs
    // four of these (one per question type the app supports) and the
    // SpinBox's custom indicator styling is too much to repeat four times
    // inline. Must be declared at this top level (a direct child of the
    // root Page) — QML inline components aren't allowed nested inside an
    // arbitrary Item.
    component AiTypeCountSpin: RowLayout {
        id: countRow
        property alias label: countLabel.text
        property alias value: countSpin.value
        width: parent ? parent.width : implicitWidth
        spacing: 10

        Label {
            id: countLabel
            font.pixelSize: 12; color: "#2c3e50"
            Layout.fillWidth: true
        }
        SpinBox {
            id: countSpin
            from: 0; to: 20
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
                text: countSpin.textFromValue(countSpin.value, countSpin.locale)
                font: countSpin.font
                color: "#2c3e50"
                horizontalAlignment: Qt.AlignHCenter
                verticalAlignment: Qt.AlignVCenter
                readOnly: !countSpin.editable
                validator: countSpin.validator
                inputMethodHints: Qt.ImhDigitsOnly
            }
            up.indicator: Rectangle {
                x: countSpin.width - width
                width: 36
                height: countSpin.height
                radius: 8
                color: countSpin.up.pressed ? "#7d3c98" : "#9b59b6"
                Text { text: "+"; anchors.centerIn: parent; color: "white"; font.pixelSize: 16; font.bold: true }
            }
            down.indicator: Rectangle {
                x: 0
                width: 36
                height: countSpin.height
                radius: 8
                color: countSpin.down.pressed ? "#7d3c98" : "#9b59b6"
                Text { text: "−"; anchors.centerIn: parent; color: "white"; font.pixelSize: 16; font.bold: true }
            }
            background: Rectangle {
                radius: 8
                color: "#faf6fc"
                border.color: "#e7d5ef"
            }
        }
    }

    // ── AI generator language picker popup ───────────────────────────────────
    // Same widget as CreatingRecSet.qml's languagePickerPopup, adapted for
    // this page's two targets ("term"/"explanation") in place of that file's
    // "card"/"aiFrom"/"aiTo" three — a rule set has no per-card language of
    // its own to edit, only the generator's two picks.
    Popup {
        id: ruleLanguagePickerPopup
        anchors.centerIn: Overlay.overlay
        width: Math.min(parent.width - 32, 340)
        padding: 0
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: Qt.callLater(function() {
            var entries = page.langEntries
            var currentId = page.langPickerCurrentId
            for (var i = 0; i < entries.length; ++i) {
                if (entries[i].id === currentId) {
                    var itemH = 48
                    var targetY = i * itemH
                    var center = targetY - (ruleLangFlick.height - itemH) / 2
                    ruleLangFlick.contentY = Math.max(0,
                        Math.min(center, Math.max(0, ruleLangFlick.contentHeight - ruleLangFlick.height)))
                    break
                }
            }
        })

        background: Rectangle { radius: 14; color: "white"; layer.enabled: true }

        contentItem: Column {
            Rectangle {
                width: ruleLanguagePickerPopup.availableWidth
                height: 52
                color: "#2c3e50"
                radius: 14
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 14; color: "#2c3e50"
                }
                Label {
                    anchors.centerIn: parent
                    text: page.langPickerTarget === "term" ? qsTr("Grammar Term Language") : qsTr("Explanation Language")
                    font.pixelSize: 16; font.bold: true; color: "white"
                }
            }

            Flickable {
                id: ruleLangFlick
                width: ruleLanguagePickerPopup.availableWidth
                height: Math.min(ruleLangCol.implicitHeight,
                                 (Overlay.overlay ? Overlay.overlay.height * 0.65 : 380) - 52 - 52)
                contentHeight: ruleLangCol.implicitHeight
                clip: true

                Column {
                    id: ruleLangCol
                    width: ruleLangFlick.width

                    Repeater {
                        model: page.langEntries
                        delegate: ItemDelegate {
                            width: ruleLangCol.width
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
                                if (page.langPickerTarget === "term") {
                                    page.aiTermLanguageId = modelData.id
                                } else {
                                    page.aiExplanationLanguageId = modelData.id
                                    AppController.defaultMeaningLanguage = modelData.id
                                }
                                ruleLanguagePickerPopup.close()
                            }
                        }
                    }
                }
            }

            Rectangle { width: ruleLanguagePickerPopup.availableWidth; height: 1; color: "#ececec" }
            ItemDelegate {
                width: ruleLanguagePickerPopup.availableWidth
                height: 50
                background: Rectangle { color: parent.pressed ? "#f0f4f8" : "white"; radius: 14 }
                contentItem: Text {
                    text: qsTr("Cancel"); color: "#e74c3c"
                    font.pixelSize: 15; font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: ruleLanguagePickerPopup.close()
            }
        }
    }

    // ── AI Rule Set Generator popup ──────────────────────────────────────────
    // Mirrors CreatingRecSet.qml's "AI Word Set Generator" popup closely (same
    // sizing/keyboard-avoidance approach, same footer/quota-line layout, same
    // language-picker pattern) — one +/- count per question type
    // (AiTypeCountSpin above) in place of a single "Number of words".
    Popup {
        id: aiGeneratorPopup
        readonly property bool keyboardUp: Qt.inputMethod.visible
        readonly property real overlayHeight: Overlay.overlay ? Overlay.overlay.height : 640
        // Read from the enclosing Page (not this Popup itself — positioning
        // a item from its own SafeArea is a binding loop, see Qt's SafeArea
        // docs and this same trick elsewhere, e.g. SetDirMenu.qml).
        readonly property real safeOverlayHeight:
            overlayHeight - page.SafeArea.margins.top - page.SafeArea.margins.bottom
        readonly property real visibleAreaHeight: keyboardUp ? safeOverlayHeight * 0.55 : safeOverlayHeight * 0.92

        // Centered via the same anchor RuleTest.qml's theoryPopup already
        // centers itself with successfully. Popup only supports this one
        // anchor line — no horizontalCenter/verticalCenter/*Offset
        // sub-properties; assigning anchors.verticalCenterOffset here
        // crashed the whole app at load with "Cannot assign to non-existent
        // property" — so there's no way to bias the center toward the safe
        // area specifically the way a hand-rolled "y" (this popup's earlier
        // approach, which didn't actually land centered on-device either)
        // would. It centers on the full overlay's middle instead; the
        // height cap below (visibleAreaHeight, built from the safe area) is
        // what actually keeps it clear of system chrome.
        anchors.centerIn: Overlay.overlay
        width: Math.min(parent.width - 32, 380)
        // Driven directly off the inner Column's own implicitHeight rather
        // than this Popup's (indirectly derived through the ScrollView
        // contentItem) — more reliable than trusting that to propagate
        // correctly, and it's what actually needs to fit/overflow here.
        height: Math.min(aiPopupColumn.implicitHeight, visibleAreaHeight)
        padding: 0
        modal: true
        // No automatic close: a plain CloseOnPressOutside let a scroll/drag
        // that starts inside the popup's own ScrollView (e.g. reaching the
        // Generate button past the keyboard) get misread as an outside tap
        // and dismiss the whole dialog, losing whatever the creator had
        // typed. Escape/Back is handled manually below instead of via
        // CloseOnEscape, so the first back-press while the keyboard is up
        // only dismisses the keyboard (standard Android behavior) rather
        // than closing the dialog outright.
        closePolicy: Popup.NoAutoClose
        focus: true
        function handleBackOrEscape(event) {
            event.accepted = true
            if (keyboardUp)
                Qt.inputMethod.hide()
            else
                aiGeneratorPopup.close()
        }
        Keys.onEscapePressed: (event) => handleBackOrEscape(event)
        Keys.onBackPressed: (event) => handleBackOrEscape(event)
        // Closing while a request is in flight (Cancel, Escape/Back once the
        // keyboard's already down) must abort it — otherwise the dialog just
        // disappears while Gemini keeps "generating" forever in the background,
        // and reopening it shows a stuck, unresponsive Generate button.
        onClosed: if (page.aiGenerating) page.aiBackend.cancelRuleGeneration()
        onOpened: FirebaseAiHelper.refreshRuleQuota()

        // While the keyboard is up, anchors.centerIn above would put the
        // popup right behind it — pin it near the top instead. A Binding
        // (rather than a second "y:" declared directly alongside
        // anchors.centerIn, which QML would just let one of the two
        // permanently win, with no way back once the other's condition
        // changes) is the documented way to temporarily override a property
        // an anchor already drives: it cleanly restores anchors.centerIn's
        // own position the moment the keyboard goes back down.
        Binding {
            target: aiGeneratorPopup
            property: "y"
            value: page.SafeArea.margins.top + 16
            when: aiGeneratorPopup.keyboardUp
        }

        background: Rectangle {
            radius: 18
            color: "white"
            layer.enabled: true
            border.color: "#e7d5ef"
            border.width: 1
        }

        contentItem: ScrollView {
            id: aiPopupScrollView
            clip: true
            contentWidth: availableWidth
            // ScrollView doesn't measure a positioner-style child's
            // scrollable extent on its own — without an explicit
            // contentHeight it can't tell its content is taller than the
            // popup, so nothing here actually scrolled and this popup's own
            // height/implicitHeight (see aiGeneratorPopup's "height" binding
            // below) came out wrong, letting the whole dialog render taller
            // than the screen with its Generate/Cancel row overflowing off
            // the bottom instead of being reachable by scrolling.
            contentHeight: aiPopupColumn.implicitHeight

            Column {
            id: aiPopupColumn
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
                        text: qsTr("✨ AI Rule Set Generator")
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

                    Label {
                        width: parent.width
                        visible: FirebaseAiHelper.ruleRemaining >= 0
                        text: "🎟️ " + qsTr("%1 of %2 generations left this month — resets %3")
                              .arg(FirebaseAiHelper.ruleRemaining)
                              .arg(FirebaseAiHelper.ruleMonthlyLimit)
                              .arg(page.formatResetTime(FirebaseAiHelper.ruleResetAt))
                        font.pixelSize: 11
                        color: "#7f8c8d"
                        wrapMode: Text.WordWrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("🎯 Rule/topic to explain")
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
                                // TextArea has no maximumLength property (unlike
                                // TextField) — enforce the cap manually. This is a
                                // UX nicety only; the Cloud Function is what
                                // actually enforces it (MAX_THEME_LENGTH).
                                readonly property int maxLength: 200
                                placeholderText: qsTr("Describe the rule you want — e.g. \"present simple vs present continuous\" or \"third conditional sentences\"…")
                                font.pixelSize: 14
                                color: "#2c3e50"
                                wrapMode: TextArea.Wrap
                                selectByMouse: true
                                background: null
                                onTextChanged: if (text.length > maxLength) text = text.substring(0, maxLength)
                            }
                        }
                    }
                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        text: qsTr("%1/%2").arg(aiThemeField.text.length).arg(aiThemeField.maxLength)
                        font.pixelSize: 10
                        color: aiThemeField.text.length >= aiThemeField.maxLength ? "#e74c3c" : "#b8a9c2"
                    }

                    RowLayout {
                        width: parent.width
                        spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Label { text: "🗣️ " + qsTr("Term language"); font.pixelSize: 11; color: "#7f8c8d" }
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
                                        text: LanguageHelper.languageNames()[page.aiTermLanguageId]
                                        font.pixelSize: 13; color: "#2c3e50"
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        page.langPickerTarget = "term"
                                        page.langPickerCurrentId = page.aiTermLanguageId
                                        ruleLanguagePickerPopup.open()
                                    }
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            // Moot while "Explain grammar" is off — nothing
                            // will be generated to translate.
                            opacity: page.aiIncludeTheory ? 1 : 0.4
                            Label { text: "💡 " + qsTr("Explanation language"); font.pixelSize: 11; color: "#7f8c8d" }
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
                                        text: LanguageHelper.languageNames()[page.aiExplanationLanguageId]
                                        font.pixelSize: 13; color: "#2c3e50"
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: page.aiIncludeTheory
                                    onClicked: {
                                        page.langPickerTarget = "explanation"
                                        page.langPickerCurrentId = page.aiExplanationLanguageId
                                        ruleLanguagePickerPopup.open()
                                    }
                                }
                            }
                        }
                    }

                    CheckBox {
                        id: aiIncludeTheoryCheck
                        width: parent.width
                        text: qsTr("💡 Explain grammar")
                        checked: page.aiIncludeTheory
                        onToggled: page.aiIncludeTheory = checked
                    }

                    Label {
                        width: parent.width
                        text: qsTr("🔢 Questions per type")
                        font.pixelSize: 12; font.bold: true; color: "#2c3e50"
                    }
                    AiTypeCountSpin { id: aiGapCountSpin; label: qsTr("📝 Fill in the Gap"); value: 5 }
                    AiTypeCountSpin { id: aiMcCountSpin; label: qsTr("🔘 Multiple Choice"); value: 5 }
                    AiTypeCountSpin { id: aiComboCountSpin; label: qsTr("🔽 Dropdown Choice"); value: 0 }
                    AiTypeCountSpin { id: aiDragdropCountSpin; label: qsTr("🫳 Drag & Drop"); value: 0 }

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
                    enabled: !page.aiGenerating && aiThemeField.text.trim() !== ""
                        && (aiGapCountSpin.value + aiMcCountSpin.value
                            + aiComboCountSpin.value + aiDragdropCountSpin.value) > 0
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
                        page.aiBackend.generateRuleSet(aiThemeField.text.trim(),
                            aiGapCountSpin.value, aiMcCountSpin.value,
                            aiComboCountSpin.value, aiDragdropCountSpin.value,
                            page.aiTermLanguageId, page.aiExplanationLanguageId,
                            page.aiIncludeTheory)
                    }
                }
            }
            }
        }
    }

    // ── Body ──────────────────────────────────────────────────────────────────
    // One scroll region for the whole page — title, explanation and
    // questions all scroll together as a single page, rather than the
    // question list having its own separately-scrolling nested viewport.
    ScrollView {
        id: pageScrollView
        anchors.fill: parent
        anchors.margins: 12
        clip: true

        // Scrolls to the bottom the moment the page's content actually grows
        // taller after a card is added — contentItem.contentHeight is still
        // stale (or -1) immediately after ruleSetModel.append(), and even
        // inside a Qt.callLater right after it, since the new card's Repeater
        // delegate hasn't been through layout yet at that point. Reacting to
        // contentHeightChanged itself is the only reliable way to catch the
        // moment it's actually settled.
        Connections {
            target: pageScrollView.contentItem
            function onContentHeightChanged() {
                if (!page.pendingScrollToNewCard) return
                page.pendingScrollToNewCard = false
                pageScrollView.contentItem.contentY =
                    Math.max(0, pageScrollView.contentItem.contentHeight - pageScrollView.height)
            }
        }

        ColumnLayout {
        width: pageScrollView.width
        spacing: 10

        // Label { text: qsTr("Set Title"); font.pixelSize: 12; font.bold: true; color: "#2c3e50" }
        TextField {
            id: topTextField
            Layout.fillWidth: true
            Layout.topMargin: 10
            font.pixelSize: 17
            placeholderText: qsTr("Set title…")
            // Default Material Outlined container (same as the question
            // fields below), so the placeholder floats onto the border
            // instead of sitting inside the box. The accent doubles as the
            // error color — the message label underneath spells it out.
            Material.accent: page.titleError ? "#e74c3c" : "#3498db"
            onTextChanged: page.titleError = false
            // See the per-question Question field's comment further down.
            onActiveFocusChanged: if (!activeFocus) cursorPosition = 0
        }

        Label {
            visible: page.titleError && page.titleErrorMessage !== ""
            text: page.titleErrorMessage
            color: "#e74c3c"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // ── Theory (single explanation for the whole set) ───────────────────
        // A directly-editable block list — text/photo/audio — rather than a
        // text box with placement markers behind it: what's shown here is
        // exactly what the learner sees, photos included, so there's no
        // separate raw-text view or preview pane to keep in sync.
        Label { text: qsTr("Theory Explanation"); font.pixelSize: 12; font.bold: true; color: "#2c3e50" }
        Label {
            text: qsTr("Hidden during testing until the learner makes a mistake — always readable in preview.")
            font.pixelSize: 10
            color: "#95a5a6"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Label {
            text: qsTr("Use ▲▼ to reorder a block. Drag a photo's // corner to resize it.")
            font.pixelSize: 10
            color: "#95a5a6"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: blocksColumn.implicitHeight + 24
            radius: 10
            color: "#faf6fc"
            border.color: "#e7d5ef"

            ColumnLayout {
                id: blocksColumn
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 10

                Repeater {
                    model: theoryBlocksModel
                    delegate: Rectangle {
                        id: blockDelegate
                        required property int index
                        required property string kind
                        required property string value
                        required property int imgHeight
                        Layout.fillWidth: true
                        implicitHeight: Math.max(blockRow.implicitHeight, 48)
                        radius: 8
                        color: "transparent"

                        RowLayout {
                            id: blockRow
                            width: blockDelegate.width
                            spacing: 8

                            // ── Reorder buttons ────────────────────────────
                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop
                                spacing: 2
                                ToolButton {
                                    implicitWidth: 28; implicitHeight: 28
                                    enabled: blockDelegate.index > 0
                                    contentItem: Text {
                                        text: "▲"; color: parent.enabled ? "#2c3e50" : "#c7cdd2"
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: theoryBlocksModel.move(blockDelegate.index, blockDelegate.index - 1, 1)
                                }
                                ToolButton {
                                    implicitWidth: 28; implicitHeight: 28
                                    enabled: blockDelegate.index < theoryBlocksModel.count - 1
                                    contentItem: Text {
                                        text: "▼"; color: parent.enabled ? "#2c3e50" : "#c7cdd2"
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: theoryBlocksModel.move(blockDelegate.index, blockDelegate.index + 1, 1)
                                }
                            }

                            // ── Text block ────────────────────────────────
                            TextArea {
                                visible: blockDelegate.kind === "text"
                                Layout.fillWidth: true
                                text: blockDelegate.value
                                placeholderText: qsTr("Explain the rule this set practices…")
                                wrapMode: TextArea.Wrap
                                selectByMouse: true
                                onEditingFinished: theoryBlocksModel.set(blockDelegate.index, { value: text })
                            }

                            // ── Photo block — shown directly, scalable via
                            // the ⤡ handle at its corner. ───────────────────
                            Rectangle {
                                visible: blockDelegate.kind === "image"
                                Layout.fillWidth: true
                                Layout.preferredHeight: blockDelegate.imgHeight
                                radius: 8
                                color: "#f0f4f8"
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: blockDelegate.value
                                    fillMode: Image.PreserveAspectFit
                                    // Phone photos are frequently stored with
                                    // EXIF orientation metadata rather than
                                    // pre-rotated pixels — without this,
                                    // portrait shots render sideways.
                                    autoTransform: true
                                }

                                Rectangle {
                                    id: resizeHandle
                                    width: 28; height: 28
                                    anchors { bottom: parent.bottom; right: parent.right; margins: 4 }
                                    radius: 6
                                    color: "#9b59b6"
                                    opacity: 0.9

                                    property int baseHeight: blockDelegate.imgHeight

                                    // Drawn rather than a "⤡"-style Unicode
                                    // glyph — dingbat/arrow symbols outside
                                    // the very common ranges aren't in every
                                    // Android font and render as a tofu box
                                    // (an empty square) instead of the icon.
                                    Canvas {
                                        anchors.fill: parent
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            ctx.strokeStyle = "white"
                                            ctx.lineWidth = 2
                                            ctx.lineCap = "round"
                                            ctx.beginPath()
                                            ctx.moveTo(width * 0.32, height * 0.68)
                                            ctx.lineTo(width * 0.68, height * 0.32)
                                            ctx.moveTo(width * 0.5, height * 0.82)
                                            ctx.lineTo(width * 0.82, height * 0.5)
                                            ctx.stroke()
                                        }
                                    }

                                    DragHandler {
                                        target: null
                                        onActiveChanged: {
                                            if (active) resizeHandle.baseHeight = blockDelegate.imgHeight
                                        }
                                        onTranslationChanged: {
                                            var newHeight = Math.round(Math.max(100, Math.min(420,
                                                resizeHandle.baseHeight + translation.y)))
                                            theoryBlocksModel.set(blockDelegate.index, { imgHeight: newHeight })
                                        }
                                    }
                                }
                            }

                            // ── Audio block ───────────────────────────────
                            RowLayout {
                                visible: blockDelegate.kind === "audio"
                                Layout.fillWidth: true
                                spacing: 8
                                ToolButton {
                                    text: page.previewPlayingPath === blockDelegate.value ? "■" : "▶"
                                    onClicked: {
                                        if (page.previewPlayingPath === blockDelegate.value) {
                                            theoryAudioPreviewPlayer.stop()
                                            page.previewPlayingPath = ""
                                        } else {
                                            theoryAudioPreviewPlayer.source = blockDelegate.value
                                            theoryAudioPreviewPlayer.play()
                                            page.previewPlayingPath = blockDelegate.value
                                        }
                                    }
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: qsTr("Audio clip")
                                    font.pixelSize: 13
                                    color: "#2c3e50"
                                }
                            }

                            // ── Remove ────────────────────────────────────
                            ToolButton {
                                Layout.alignment: Qt.AlignTop
                                contentItem: Text {
                                    text: "X"; color: "#e74c3c"; font.bold: true
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    if (blockDelegate.kind === "audio" && page.previewPlayingPath === blockDelegate.value) {
                                        theoryAudioPreviewPlayer.stop()
                                        page.previewPlayingPath = ""
                                    }
                                    theoryBlocksModel.remove(blockDelegate.index)
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Button {
                        Layout.fillWidth: true
                        text: qsTr("+ Text")
                        onClicked: theoryBlocksModel.append({ kind: "text", value: "", imgHeight: 0 })
                    }
                    Button {
                        Layout.fillWidth: true
                        text: qsTr("+ Photo")
                        onClicked: theoryImagePickerDialog.open()
                    }
                    Button {
                        Layout.fillWidth: true
                        text: qsTr("+ Audio")
                        onClicked: theoryAudioPickerDialog.open()
                    }
                }
            }
        }

        ColumnLayout {
                id: rowsColumn
                Layout.fillWidth: true
                spacing: 10

                ListModel { id: ruleSetModel }

                Repeater {
                    model: ruleSetModel
                    delegate: Rectangle {
                        id: cardRect
                        // Captured once so nested Repeaters below (the type
                        // toggle, the MC correct-answer chips) can reach this
                        // card's own position without their own "index"
                        // (which belongs to those inner Repeaters) shadowing it.
                        property int cardIndex: index
                        Layout.fillWidth: true
                        width: rowsColumn.width
                        Layout.preferredHeight: cardColumn.implicitHeight + 24
                        implicitHeight: cardColumn.implicitHeight + 24

                        radius: 10
                        color: "white"
                        border.color: page.selectedCardIndex === index ? "#9b59b6" : "#dce1e7"
                        border.width: page.selectedCardIndex === index ? 2 : 1

                        // Purple top accent bar — matches the rule-set accent
                        // color used in SetDirMenu.qml's list.
                        Rectangle {
                            width: parent.width; height: 3
                            radius: 10
                            color: "#9b59b6"
                            anchors.top: parent.top
                        }

                        ColumnLayout {
                            id: cardColumn
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 10

                            // ── Card header: question number + tap-to-select ──
                            Rectangle {
                                Layout.fillWidth: true
                                height: 24
                                color: "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    Label {
                                        text: qsTr("Question") + " " + (index + 1)
                                        font.pixelSize: 11
                                        color: "#95a5a6"
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        visible: page.selectedCardIndex === index
                                        text: qsTr("selected")
                                        font.pixelSize: 10
                                        color: "#9b59b6"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: page.selectedCardIndex = index
                                }
                            }

                            // ── Question type toggle ─────────────────────────────
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 6
                                rowSpacing: 6

                                Repeater {
                                    model: [
                                        { value: "gap", label: qsTr("Fill in the Gap") },
                                        { value: "mc", label: qsTr("Multiple Choice") },
                                        { value: "combobox", label: qsTr("Dropdown Choice") },
                                        { value: "dragdrop", label: qsTr("Drag & Drop") }
                                    ]
                                    delegate: ItemDelegate {
                                        id: typeChip
                                        required property int index
                                        required property var modelData
                                        Layout.preferredWidth: (cardColumn.width - 6) / 2
                                        height: 32
                                        readonly property bool selected:
                                            (questionType || "gap") === typeChip.modelData.value
                                        contentItem: Text {
                                            text: typeChip.modelData.label
                                            color: typeChip.selected ? "white" : "#2c3e50"
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        background: Rectangle {
                                            radius: 8
                                            color: typeChip.selected ? "#9b59b6" : "#f0f4f8"
                                        }
                                        onClicked: ruleSetModel.set(cardRect.cardIndex,
                                            { questionType: typeChip.modelData.value })
                                    }
                                }
                            }

                            // ── Question / prompt text ───────────────────────────
                            Label { text: qsTr("Question"); font.pixelSize: 12; font.bold: true; color: "#2c3e50" }
                            Label {
                                Layout.fillWidth: true
                                visible: (questionType || "gap") !== "mc"
                                text: qsTr("Use ___ (three underscores) for each blank the learner fills in.")
                                font.pixelSize: 10
                                color: "#95a5a6"
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: questionText
                                placeholderText: questionType === "mc"
                                    ? qsTr("e.g. What does she do every day?")
                                    : qsTr("e.g. She ___ to school every day.")
                                onEditingFinished: ruleSetModel.set(cardRect.cardIndex, { questionText: text })
                                // TextInput scrolls its viewport to follow the
                                // cursor while editing, but never scrolls back
                                // once you tap away — a sentence longer than the
                                // field stays stuck showing wherever the cursor
                                // last was (e.g. mid-sentence, clipping the
                                // start), which reads as broken. Snap the
                                // cursor to 0 on blur so the field always
                                // settles back to showing the beginning.
                                onActiveFocusChanged: if (!activeFocus) cursorPosition = 0
                            }

                            // ── Answers, one per gap in order (gap only —
                            // combobox derives its answers from the tapped
                            // chips below instead of typed text, and
                            // dragdrop derives them from which tile is
                            // dragged into each blank below its Options). ──
                            Label {
                                text: qsTr("Answers"); font.pixelSize: 12; font.bold: true; color: "#2c3e50"
                                visible: (questionType || "gap") === "gap"
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: (questionType || "gap") === "gap"
                                text: qsTr("One answer per blank, separated by commas, in order. Use \\, for a literal comma.")
                                font.pixelSize: 10
                                color: "#95a5a6"
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                Layout.fillWidth: true
                                visible: (questionType || "gap") === "gap"
                                text: answersText
                                placeholderText: qsTr("e.g. goes")
                                onEditingFinished: ruleSetModel.set(cardRect.cardIndex, { answersText: text })
                                // See the Question field above's comment.
                                onActiveFocusChanged: if (!activeFocus) cursorPosition = 0
                            }

                            // ── Options pool (dropdown choices / draggable tiles) ──
                            Label {
                                text: qsTr("Options"); font.pixelSize: 12; font.bold: true; color: "#2c3e50"
                                visible: questionType === "combobox" || questionType === "dragdrop"
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: questionType === "combobox"
                                text: qsTr("Separate choices for one blank with commas; separate blanks with double colons (::). A single : is safe as-is; use \\, for a literal comma, \\:: for a literal ::, and ___ for a deliberately blank choice. E.g. for two blanks: goes, go, going::every, some, most.")
                                font.pixelSize: 10
                                color: "#95a5a6"
                                wrapMode: Text.WordWrap
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: questionType === "dragdrop"
                                text: qsTr("Comma-separated draggable tiles — include the correct answers, plus optional decoys the learner can be tricked by. Use \\, for a literal comma, and ___ for a blank tile (for a blank that should correctly stay empty). Fill in the blanks below once these are set.")
                                font.pixelSize: 10
                                color: "#95a5a6"
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                Layout.fillWidth: true
                                visible: questionType === "combobox" || questionType === "dragdrop"
                                text: poolOptionsText
                                placeholderText: questionType === "combobox"
                                    ? qsTr("e.g. goes, go, going::every, some, most")
                                    : qsTr("e.g. goes, go, going, went")
                                // Live (not onEditingFinished) so the
                                // per-blank "correct answer" chip groups
                                // below appear/update as options are typed.
                                onTextChanged: ruleSetModel.set(cardRect.cardIndex, { poolOptionsText: text })
                                // See the Question field above's comment.
                                onActiveFocusChanged: if (!activeFocus) cursorPosition = 0
                            }

                            // ── Correct answer per blank (combobox only) —
                            // tap the right choice in each blank's own box,
                            // rather than re-typing it; guarantees the
                            // answer always matches an actual option. ──────
                            Label {
                                text: qsTr("Correct answer for each blank"); font.pixelSize: 12; font.bold: true
                                color: page.mcErrorCardIndex === cardRect.cardIndex ? "#e74c3c" : "#2c3e50"
                                visible: questionType === "combobox"
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: questionType === "combobox"
                                text: qsTr("Tap the correct choice in each box below.")
                                font.pixelSize: 10
                                color: "#95a5a6"
                                wrapMode: Text.WordWrap
                            }
                            // Briefly flashes a red border when Save was
                            // pressed with a blank left unmarked here.
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: comboErrorColumn.implicitHeight + 12
                                visible: questionType === "combobox"
                                radius: 8
                                color: page.mcErrorCardIndex === cardRect.cardIndex ? "#fdecea" : "transparent"
                                border.color: page.mcErrorCardIndex === cardRect.cardIndex ? "#e74c3c" : "transparent"
                                border.width: page.mcErrorCardIndex === cardRect.cardIndex ? 2 : 0
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                            ColumnLayout {
                                id: comboErrorColumn
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                                spacing: 10

                                Label {
                                    Layout.fillWidth: true
                                    visible: page.mcErrorCardIndex === cardRect.cardIndex
                                    text: qsTr("Select a correct answer for every blank.")
                                    font.pixelSize: 11
                                    color: "#e74c3c"
                                    wrapMode: Text.WordWrap
                                }

                                Repeater {
                                    model: questionType === "combobox" ? page.parseOptionsPerGap(poolOptionsText) : []

                                    delegate: ColumnLayout {
                                        id: comboAnswerGroup
                                        required property int index
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Label {
                                            visible: page.parseOptionsPerGap(poolOptionsText).length > 1
                                            text: qsTr("Blank %1").arg(comboAnswerGroup.index + 1)
                                            font.pixelSize: 11
                                            color: "#95a5a6"
                                        }

                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Repeater {
                                                model: comboAnswerGroup.modelData

                                                delegate: ItemDelegate {
                                                    id: comboAnswerChip
                                                    required property int index
                                                    required property string modelData
                                                    height: 32
                                                    readonly property bool selected: {
                                                        var arr = page.parseComboCorrectIndices(comboCorrectIndicesText)
                                                        return arr.length > comboAnswerGroup.index
                                                            && arr[comboAnswerGroup.index] === comboAnswerChip.index
                                                    }
                                                    contentItem: Text {
                                                        text: comboAnswerChip.modelData !== "" ? comboAnswerChip.modelData : "—"
                                                        color: comboAnswerChip.selected ? "white" : "#2c3e50"
                                                        font.pixelSize: 12
                                                        leftPadding: 10; rightPadding: 10
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                    background: Rectangle {
                                                        radius: 8
                                                        color: comboAnswerChip.selected ? "#27ae60" : "#f0f4f8"
                                                        border.color: "#dce1e7"
                                                    }
                                                    onClicked: page.setComboCorrectForGroup(
                                                        cardRect.cardIndex, comboAnswerGroup.index, comboAnswerChip.index)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            }

                            // ── Fill in the blanks (drag & drop only) — drag
                            // each tile from the pool below straight into its
                            // blank, almost exactly like the learner will
                            // during the actual test. Whichever tile ends up
                            // in a blank becomes that blank's correct answer
                            // — there's no separate "Answers" field to keep
                            // in sync with the pool by hand. ────────────────
                            Label {
                                text: qsTr("Fill in the blanks"); font.pixelSize: 12; font.bold: true
                                color: page.mcErrorCardIndex === cardRect.cardIndex ? "#e74c3c" : "#2c3e50"
                                visible: questionType === "dragdrop"
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: questionType === "dragdrop"
                                text: qsTr("Drag a tile onto a blank below, or tap a tile then tap a blank to place it.")
                                font.pixelSize: 10
                                color: "#95a5a6"
                                wrapMode: Text.WordWrap
                            }
                            // Briefly flashes a red border when Save was
                            // pressed with a blank left unfilled here.
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: ddAuthorColumn.implicitHeight + 12
                                visible: questionType === "dragdrop"
                                radius: 8
                                color: page.mcErrorCardIndex === cardRect.cardIndex ? "#fdecea" : "transparent"
                                border.color: page.mcErrorCardIndex === cardRect.cardIndex ? "#e74c3c" : "transparent"
                                border.width: page.mcErrorCardIndex === cardRect.cardIndex ? 2 : 0
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                            ColumnLayout {
                                id: ddAuthorColumn
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                                spacing: 10

                                // Ephemeral interaction state — which pool
                                // tile is tap-selected and which blank a drag
                                // is currently hovering over. Not persisted
                                // (unlike placements below): it only matters
                                // while this card is open and mid-gesture.
                                property int selectedTileIndex: -1
                                property int hoverBlank: -1
                                readonly property var pool: page.parseDragdropPool(poolOptionsText)
                                readonly property var placements: page.parseDdPlacements(ddPlacementsText)
                                readonly property var segments: (questionText || "").split("___")

                                Label {
                                    Layout.fillWidth: true
                                    visible: page.mcErrorCardIndex === cardRect.cardIndex
                                    text: qsTr("Fill every blank with a tile.")
                                    font.pixelSize: 11
                                    color: "#e74c3c"
                                    wrapMode: Text.WordWrap
                                }

                                // The sentence, with each blank shown as a
                                // drop target — same layout idea as the gap/
                                // combobox previews above.
                                Flow {
                                    id: ddAuthorFlow
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: questionType === "dragdrop" ? ddAuthorColumn.segments.length : 0

                                        delegate: Row {
                                            id: ddAuthorRow
                                            required property int index
                                            readonly property bool isBlank: ddAuthorRow.index < ddAuthorColumn.segments.length - 1
                                            spacing: 6

                                            Label {
                                                text: ddAuthorColumn.segments[ddAuthorRow.index]
                                                font.pixelSize: 15
                                                color: "#2c3e50"
                                                wrapMode: Text.WordWrap
                                                // Flow only wraps between whole
                                                // Rows, never inside one, so an
                                                // unbounded-width Label here let
                                                // a long sentence push its drop
                                                // target off the right edge,
                                                // cropped. Cap it to the Flow's
                                                // own width instead.
                                                width: Math.max(40, Math.min(implicitWidth,
                                                    ddAuthorFlow.width - (ddAuthorRow.isBlank ? ddAuthorBlank.width + 20 : 0)))
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            // Blank / drop target — tap a
                                            // selected tile's target here,
                                            // drag a tile onto it, or tap a
                                            // filled blank to send its tile
                                            // back to the pool.
                                            Rectangle {
                                                id: ddAuthorBlank
                                                visible: ddAuthorRow.isBlank
                                                readonly property int blankIndex: ddAuthorRow.index
                                                readonly property int placedTile:
                                                    ddAuthorColumn.placements.length > ddAuthorBlank.blankIndex
                                                        ? ddAuthorColumn.placements[ddAuthorBlank.blankIndex] : -1
                                                readonly property bool filled:
                                                    ddAuthorBlank.placedTile >= 0 && ddAuthorBlank.placedTile < ddAuthorColumn.pool.length
                                                width: Math.max(56, ddAuthorBlankLabel.implicitWidth + 20)
                                                height: 32
                                                radius: 8
                                                color: ddAuthorBlank.filled ? "#eaf2fb" : "#f7f9fb"
                                                border.width: 2
                                                border.color: page.mcErrorCardIndex === cardRect.cardIndex && !ddAuthorBlank.filled
                                                    ? "#e74c3c"
                                                    : (ddAuthorColumn.hoverBlank === ddAuthorBlank.blankIndex ? "#3498db" : "#dce1e7")

                                                Label {
                                                    id: ddAuthorBlankLabel
                                                    anchors.centerIn: parent
                                                    text: ddAuthorBlank.filled
                                                        ? (ddAuthorColumn.pool[ddAuthorBlank.placedTile] !== ""
                                                            ? ddAuthorColumn.pool[ddAuthorBlank.placedTile] : "—")
                                                        : "___"
                                                    font.pixelSize: 13
                                                    color: ddAuthorBlank.filled ? "#2c3e50" : "#b0b8c1"
                                                }

                                                DropArea {
                                                    anchors.fill: parent
                                                    keys: ["x-pp-author-ddtile"]
                                                    onEntered: ddAuthorColumn.hoverBlank = ddAuthorBlank.blankIndex
                                                    onExited: if (ddAuthorColumn.hoverBlank === ddAuthorBlank.blankIndex)
                                                        ddAuthorColumn.hoverBlank = -1
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        if (ddAuthorBlank.filled) {
                                                            page.clearDdPlacement(cardRect.cardIndex, ddAuthorBlank.blankIndex)
                                                        } else if (ddAuthorColumn.selectedTileIndex !== -1) {
                                                            page.setDdPlacement(cardRect.cardIndex,
                                                                ddAuthorBlank.blankIndex, ddAuthorColumn.selectedTileIndex)
                                                            ddAuthorColumn.selectedTileIndex = -1
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // The pool of draggable/tappable tiles —
                                // placed tiles disappear from here until
                                // their blank is cleared again.
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Repeater {
                                        model: questionType === "dragdrop" ? ddAuthorColumn.pool : []

                                        delegate: Rectangle {
                                            id: ddAuthorTile
                                            required property int index
                                            required property string modelData
                                            readonly property int tileIndex: ddAuthorTile.index
                                            visible: ddAuthorColumn.placements.indexOf(ddAuthorTile.tileIndex) === -1
                                            width: ddAuthorTileLabel.implicitWidth + 20
                                            height: 36
                                            radius: 8
                                            color: ddAuthorColumn.selectedTileIndex === ddAuthorTile.tileIndex ? "#d6eaf8" : "white"
                                            border.color: ddAuthorColumn.selectedTileIndex === ddAuthorTile.tileIndex ? "#3498db" : "#dce1e7"
                                            border.width: 2
                                            z: ddAuthorDragArea.drag.active ? 100 : 0

                                            Drag.active: ddAuthorDragArea.drag.active
                                            Drag.source: ddAuthorTile
                                            Drag.hotSpot.x: width / 2
                                            Drag.hotSpot.y: height / 2
                                            Drag.keys: ["x-pp-author-ddtile"]

                                            Label {
                                                id: ddAuthorTileLabel
                                                anchors.centerIn: parent
                                                text: ddAuthorTile.modelData !== "" ? ddAuthorTile.modelData : "—"
                                                font.pixelSize: 13
                                                color: "#2c3e50"
                                            }

                                            MouseArea {
                                                id: ddAuthorDragArea
                                                anchors.fill: parent
                                                drag.target: ddAuthorTile
                                                property bool wasDragging: false
                                                // Where Flow had this tile before the drag
                                                // started, so a drop that misses every blank
                                                // can snap it back there — Flow itself won't:
                                                // it only repositions children on add/remove/
                                                // resize/visibility change, not continuously,
                                                // so nothing re-settles a tile whose x/y a drag
                                                // left sitting in the middle of the row.
                                                property real startX: 0
                                                property real startY: 0
                                                onPressed: {
                                                    wasDragging = false
                                                    startX = ddAuthorTile.x
                                                    startY = ddAuthorTile.y
                                                }
                                                onPositionChanged: if (drag.active) wasDragging = true
                                                onReleased: {
                                                    var placed = wasDragging && ddAuthorColumn.hoverBlank !== -1
                                                    if (placed)
                                                        page.setDdPlacement(cardRect.cardIndex,
                                                            ddAuthorColumn.hoverBlank, ddAuthorTile.tileIndex)
                                                    ddAuthorColumn.hoverBlank = -1
                                                    // A successful placement hides this tile
                                                    // (see its "visible" binding above) and Flow
                                                    // reflows what's left, so there's nothing to
                                                    // restore here in that case.
                                                    if (!placed) {
                                                        ddAuthorTile.x = ddAuthorDragArea.startX
                                                        ddAuthorTile.y = ddAuthorDragArea.startY
                                                    }
                                                }
                                                onClicked: ddAuthorColumn.selectedTileIndex =
                                                    (ddAuthorColumn.selectedTileIndex === ddAuthorTile.tileIndex) ? -1 : ddAuthorTile.tileIndex
                                            }
                                        }
                                    }
                                }
                            }
                            }

                            // ── Options + correct answer (multiple-choice only) ──
                            Label {
                                text: qsTr("Options"); font.pixelSize: 12; font.bold: true; color: "#2c3e50"
                                visible: (questionType || "gap") === "mc"
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: (questionType || "gap") === "mc"
                                text: mcSingleAnswer
                                    ? qsTr("Comma-separated choices — tap the correct answer below. Use \\, for a literal comma.")
                                    : qsTr("Comma-separated choices — tap all correct answers below. Use \\, for a literal comma.")
                                font.pixelSize: 10
                                color: "#95a5a6"
                                wrapMode: Text.WordWrap
                            }
                            TextField {
                                Layout.fillWidth: true
                                visible: (questionType || "gap") === "mc"
                                text: mcOptionsText
                                placeholderText: qsTr("e.g. go, goes, going, went")
                                // Live (not onEditingFinished) so the "Correct
                                // answer(s)" chips below — bound to this same
                                // mcOptionsText — appear as each option is
                                // typed, not only once the field loses focus.
                                onTextChanged: ruleSetModel.set(cardRect.cardIndex, { mcOptionsText: text })
                                // See the Question field's comment above.
                                onActiveFocusChanged: if (!activeFocus) cursorPosition = 0
                            }
                            // Switches the chips below between "tap any
                            // number correct" (checkbox-like) and "tap one,
                            // picking it deselects whichever was picked
                            // before" (radio-like) — same choice RuleTest.qml
                            // renders the actual test with, see its
                            // "isSingleAnswer" binding.
                            RowLayout {
                                Layout.fillWidth: true
                                visible: (questionType || "gap") === "mc"
                                spacing: 10

                                Label {
                                    text: qsTr("Only one correct answer")
                                    font.pixelSize: 12
                                    color: "#2c3e50"
                                    Layout.fillWidth: true
                                }

                                Switch {
                                    checked: mcSingleAnswer === true
                                    onCheckedChanged: {
                                        if (checked === (mcSingleAnswer === true)) return
                                        // Switching into single-answer mode
                                        // with more than one already marked
                                        // correct would leave an invalid,
                                        // ambiguous state — keep just the
                                        // first one, same as if the author
                                        // had been in single mode all along.
                                        var current = page.parseIndices(mcCorrectIndicesText)
                                        var trimmed = checked && current.length > 1 ? [current[0]] : current
                                        ruleSetModel.set(cardRect.cardIndex, {
                                            mcSingleAnswer: checked,
                                            mcCorrectIndicesText: trimmed.join(",")
                                        })
                                    }
                                }
                            }
                            Label {
                                text: mcSingleAnswer ? qsTr("Correct answer") : qsTr("Correct answer(s)")
                                font.pixelSize: 12; font.bold: true
                                color: page.mcErrorCardIndex === cardRect.cardIndex ? "#e74c3c" : "#2c3e50"
                                visible: (questionType || "gap") === "mc"
                            }
                            // Briefly flashes a red border when Save was
                            // pressed with no correct answer marked here.
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: mcErrorColumn.implicitHeight + 12
                                visible: (questionType || "gap") === "mc"
                                radius: 8
                                color: page.mcErrorCardIndex === cardRect.cardIndex ? "#fdecea" : "transparent"
                                border.color: page.mcErrorCardIndex === cardRect.cardIndex ? "#e74c3c" : "transparent"
                                border.width: page.mcErrorCardIndex === cardRect.cardIndex ? 2 : 0
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                ColumnLayout {
                                    id: mcErrorColumn
                                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                                    spacing: 4

                                    Label {
                                        Layout.fillWidth: true
                                        visible: page.mcErrorCardIndex === cardRect.cardIndex
                                        text: mcSingleAnswer ? qsTr("Select the correct answer.") : qsTr("Select at least one correct answer.")
                                        font.pixelSize: 11
                                        color: "#e74c3c"
                                        wrapMode: Text.WordWrap
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: page.splitEscaped(mcOptionsText || "", ",")
                                                .map(function(s) { return s.trim() })
                                                .filter(function(s) { return s !== "" })
                                            delegate: ItemDelegate {
                                                id: optChip
                                                required property int index
                                                required property string modelData
                                                height: 32
                                                readonly property bool selected:
                                                    page.parseIndices(mcCorrectIndicesText).indexOf(optChip.index) !== -1
                                                contentItem: Text {
                                                    text: optChip.modelData
                                                    color: optChip.selected ? "white" : "#2c3e50"
                                                    font.pixelSize: 12
                                                    leftPadding: 10; rightPadding: 10
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                background: Rectangle {
                                                    radius: 8
                                                    color: optChip.selected ? "#27ae60" : "#f0f4f8"
                                                    border.color: "#dce1e7"
                                                }
                                                onClicked: {
                                                    if (mcSingleAnswer) {
                                                        // Radio-like: picking one always replaces
                                                        // whatever was marked before, rather than
                                                        // toggling independently.
                                                        ruleSetModel.set(cardRect.cardIndex,
                                                            { mcCorrectIndicesText: String(optChip.index) })
                                                        return
                                                    }
                                                    var current = page.parseIndices(mcCorrectIndicesText)
                                                    var pos = current.indexOf(optChip.index)
                                                    if (pos === -1) current.push(optChip.index)
                                                    else current.splice(pos, 1)
                                                    ruleSetModel.set(cardRect.cardIndex, { mcCorrectIndicesText: current.join(",") })
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    footer: Rectangle {
        height: footerColumn.implicitHeight + 24 + SafeArea.margins.bottom
        color: "#2c3e50"

        ColumnLayout {
            id: footerColumn
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                leftMargin: 16; rightMargin: 16; topMargin: 12
            }
            spacing: 8

            RowLayout {
                spacing: 8

                Button {
                    text: qsTr("+ Add question")
                    Layout.fillWidth: true
                    background: Rectangle { radius: 8; color: parent.pressed ? "#7d3c98" : "#9b59b6" }
                    contentItem: Text {
                        text: parent.text; color: "white"; font: parent.font
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        ruleSetModel.append({
                            id: page.nextQuestionId++,
                            questionType: "gap", questionText: "", answersText: "",
                            mcOptionsText: "", mcCorrectIndicesText: "", poolOptionsText: "",
                            comboCorrectIndicesText: "", ddPlacementsText: "", mcSingleAnswer: false
                        })
                        page.selectedCardIndex = ruleSetModel.count - 1
                        // The new card is always appended last, so scrolling
                        // all the way to the bottom brings it into view —
                        // see pageScrollView's Connections above for why this
                        // is a flag rather than scrolling directly here.
                        page.pendingScrollToNewCard = true
                    }
                }

                Button {
                    text: qsTr("Remove")
                    enabled: ruleSetModel.count > 0
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
                        if (idx >= 0 && idx < ruleSetModel.count) {
                            ruleSetModel.remove(idx)
                            page.selectedCardIndex = Math.min(idx, ruleSetModel.count - 1)
                        }
                    }
                }
            }

            RowLayout {
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
                            return
                        }
                        var badIdx = page.findUnmarkedMCQuestion()
                        if (badIdx === -1) badIdx = page.findUnmarkedComboQuestion()
                        if (badIdx === -1) badIdx = page.findUnmarkedDragdropQuestion()
                        if (badIdx !== -1) {
                            page.selectedCardIndex = badIdx
                            page.mcErrorCardIndex = badIdx
                            mcErrorFlashTimer.restart()
                            return
                        }
                        creatingRuleSetSave()
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
                    onClicked: creatingRuleSetCancel()
                }
            }
        }
    }
}
