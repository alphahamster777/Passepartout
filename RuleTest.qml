import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Page {
    id: root
    signal getResults()

    // Used to size each combobox blank's wheel picker to fit its widest
    // option, rather than one fixed width for every blank.
    FontMetrics {
        id: comboWheelFontMetrics
        font.pixelSize: 17
    }
    function widestOptionWidth(options) {
        var maxW = 0
        for (var i = 0; i < options.length; ++i)
            maxW = Math.max(maxW, comboWheelFontMetrics.advanceWidth(options[i]))
        return maxW
    }

    // Shared "active test controller" slot — Main.qml repoints it at the
    // rule controller before pushing this page (see onStartRuleTest),
    // the same slot SpellingTest.qml/FlashCard.qml/Results.qml already read.
    property var ruleTestController: rootScope.spellingTestController
    readonly property var question: ruleTestController.currentQuestion
    readonly property bool isAnswered: ruleTestController.isAnswered

    // Text segments around each "___" gap marker — shared by "gap",
    // "combobox" and "dragdrop" question types, which differ only in the
    // per-gap widget (typed field, tap-to-choose boxes, or a drop target).
    readonly property var segments: (question.text || "").split("___")

    property var dragdropShuffledOptions: []
    // Per blank: index into dragdropShuffledOptions placed there, or -1.
    property var dragdropPlacements: []
    property int dragdropSelectedTileIndex: -1
    // Which blank a drag is currently hovering over, tracked live via each
    // blank's DropArea onEntered/onExited (not queried once at release
    // time — see the tile's onReleased for why).
    property int dragdropHoverBlank: -1

    function shuffledCopy(arr) {
        var a = arr.slice()
        for (var i = a.length - 1; i > 0; --i) {
            var j = Math.floor(Math.random() * (i + 1))
            var tmp = a[i]; a[i] = a[j]; a[j] = tmp
        }
        return a
    }

    function resetDragdrop() {
        root.dragdropShuffledOptions = root.shuffledCopy(question.options || [])
        var placements = []
        for (var i = 0; i < root.segments.length - 1; ++i) placements.push(-1)
        root.dragdropPlacements = placements
        root.dragdropSelectedTileIndex = -1
        root.dragdropHoverBlank = -1
    }

    // Moves the tile at dragdropShuffledOptions[tileIdx] into blankIdx,
    // first vacating any other blank it already occupied (so a tile can be
    // moved from one blank straight to another, not just pool<->blank).
    function placeDragdropTile(tileIdx, blankIdx) {
        if (root.isAnswered) return
        var arr = root.dragdropPlacements.slice()
        for (var i = 0; i < arr.length; ++i)
            if (arr[i] === tileIdx) arr[i] = -1
        arr[blankIdx] = tileIdx
        root.dragdropPlacements = arr
        root.dragdropSelectedTileIndex = -1
    }

    function clearDragdropBlank(blankIdx) {
        if (root.isAnswered) return
        var arr = root.dragdropPlacements.slice()
        arr[blankIdx] = -1
        root.dragdropPlacements = arr
    }

    function collectDragdropAnswers() {
        var result = []
        for (var i = 0; i < root.dragdropPlacements.length; ++i) {
            var tileIdx = root.dragdropPlacements[i]
            result.push(tileIdx !== -1 ? root.dragdropShuffledOptions[tileIdx] : "")
        }
        return result
    }

    // "combobox" question: one tap-to-choose option group per blank.
    // question.optionsPerGap is [[opt,opt,...], [opt,opt,...], ...] — one
    // array per blank, in order (see CreatingRuleSet.qml's ";"/","-split
    // authoring field).
    readonly property var comboOptionsPerGap: question.optionsPerGap || []
    // The value picked for each blank so far, null where unpicked. null
    // (not "") is the "unpicked" sentinel specifically so an authored
    // deliberately-blank option ("" — see CreatingRuleSet.qml's "\_"
    // marker) can still be spun to and submitted as a real, distinct pick.
    property var comboSelections: []

    // No separate "reset" pass for this one — each blank's wheel picker
    // (see the combobox section below) always has some value centered, so
    // it registers its own current pick the moment it's created for a new
    // question, rather than needing to be told to clear a previous one.
    function setComboSelection(blankIdx, value) {
        if (root.isAnswered) return
        var arr = root.comboSelections.slice()
        arr[blankIdx] = value
        root.comboSelections = arr
    }

    // True once every blank has been spun off its implicit leading null
    // onto a real option. A blank whose own authored options include a
    // deliberate blank ("___" — see CreatingRuleSet.qml) never actually
    // sits on that null — its wheel starts right on the blank entry itself
    // (registered as "", not null — see comboGroup.wheelOptions below), so
    // it's already submittable without spinning.
    function comboSelectionsComplete() {
        if (root.comboSelections.length < root.comboOptionsPerGap.length) return false
        for (var i = 0; i < root.comboOptionsPerGap.length; ++i) {
            var v = root.comboSelections[i]
            if (v === null || v === undefined) return false
        }
        return true
    }

    // { blocks: [ {kind:"text",value} | {kind:"image",value,imgHeight} |
    //             {kind:"audio",value}, ... ] } — rendered in that order.
    readonly property var theoryBlocks: ruleTestController.theory.blocks || []

    Connections {
        target: ruleTestController
        function onCurrentQuestionChanged() { root.resetQuestion() }
    }

    Component.onCompleted: {
        // Also called directly here (not just from onCurrentQuestionChanged
        // above) because the controller's very first question is shown
        // while still on the preview screen, before this page — and its
        // Connections — exist to catch that signal. Without this, the very
        // first question's dragdrop tile pool / combo selections never got
        // initialized and appeared empty.
        root.resetQuestion()
        if (ruleTestController.testComplete)
            Qt.callLater(function() { root.getResults() })
    }

    // gapRepeater's delegate count often stays the same from one question to
    // the next (same number of gaps), and Qt Quick's Repeater reuses
    // delegate instances rather than recreating them when the count is
    // unchanged — so a previous answer would otherwise persist visually
    // into the next question. Deferred via callLater so it runs after the
    // Repeater has finished resizing for the new question's segment count.
    // Options the learner has tapped, for a multiple-choice question — a
    // question may have more than one correct answer, so this is a set of
    // indices, not one. Local until Submit is pressed, since
    // submitMCAnswer() locks the answer in immediately (like
    // submitGapAnswers() does for gaps).
    property var selectedMCIndices: []

    function toggleMCOption(idx) {
        // "singleAnswer" questions (see CreatingRuleSet.qml's "Only one
        // correct answer" toggle) behave like radio buttons — picking one
        // always replaces whatever was selected before, rather than each
        // option toggling independently.
        if (question.singleAnswer === true) {
            root.selectedMCIndices = [idx]
            return
        }
        var current = root.selectedMCIndices.slice()
        var pos = current.indexOf(idx)
        if (pos === -1) current.push(idx)
        else current.splice(pos, 1)
        root.selectedMCIndices = current
    }

    // Deferred as one unit (rather than resetting selectedMCIndices/
    // dragdrop/combo synchronously and only the gap fields via callLater)
    // so every reset reads "question" only after its own property binding —
    // and the Repeater sizes depending on it — have actually settled.
    // Reading it synchronously here after a currentQuestionChanged signal
    // isn't reliable, since a plain Connections handler isn't guaranteed to
    // run after this page's own "question" binding has re-evaluated.
    function resetQuestion() {
        Qt.callLater(function() {
            root.selectedMCIndices = []
            root.resetDragdrop()
            for (var i = 0; i < gapRepeater.count; ++i) {
                var item = gapRepeater.itemAt(i)
                if (item) item.resetField()
            }
        })
    }

    function submitAnswers() {
        if ((question.type || "gap") === "mc") {
            ruleTestController.submitMCAnswer(root.selectedMCIndices)
            return
        }
        if (question.type === "dragdrop") {
            ruleTestController.submitGapAnswers(root.collectDragdropAnswers())
            return
        }
        if (question.type === "combobox") {
            ruleTestController.submitGapAnswers(root.comboSelections)
            return
        }
        var answers = []
        for (var i = 0; i < gapRepeater.count; ++i) {
            var item = gapRepeater.itemAt(i)
            if (item && item.isGap)
                answers.push(item.fieldText)
        }
        ruleTestController.submitGapAnswers(answers)
    }

    background: Rectangle { color: "#f0f4f8" }

    // ── Header ────────────────────────────────────────────────────────────────
    header: Rectangle {
        height: 56 + SafeArea.margins.top
        color: "#2c3e50"

        RowLayout {
            anchors {
                left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: 16; rightMargin: 16; bottomMargin: 8
            }
            height: 40
            Label {
                Layout.fillWidth: true
                text: qsTr("Rule")
                font.pixelSize: 18
                font.bold: true
                color: "white"
            }
            Label {
                text: ruleTestController.correctAnswers + "/" + ruleTestController.totalQuestions
                font.pixelSize: 13
                color: "#3498db"
            }
        }
    }

    // ── Theory popup — hidden behind a link that only appears after a
    // mistake, per theoryUnlocked; freely readable ahead of time on the
    // preview screen instead. Height is capped and scrollable (rather than
    // sized to content unbounded) since theory can include several images/
    // audio rows and would otherwise overflow the screen. ──────────────────
    MediaPlayer {
        id: theoryPopupAudioPlayer
        audioOutput: AudioOutput {}
        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState)
                theoryPopup.playingPath = ""
        }
    }

    Popup {
        id: theoryPopup
        property string playingPath: ""
        anchors.centerIn: Overlay.overlay
        width: Math.min(parent.width - 32, 380)
        padding: 0
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: theoryPopupAudioPlayer.stop()

        background: Rectangle { radius: 16; color: "white"; layer.enabled: true }

        contentItem: Column {
            width: theoryPopup.availableWidth

            // Title bar — matches the colored-header popup style used
            // elsewhere in the app (e.g. the test-type picker).
            Rectangle {
                id: theoryPopupTitleBar
                width: parent.width
                height: 52
                color: "#2c3e50"
                radius: 16
                // Fill the bottom-half radius so corners look square at the
                // bottom, where it meets the content below.
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 16; color: "#2c3e50"
                }
                Label {
                    anchors.centerIn: parent
                    text: qsTr("💡 Rule Explanation")
                    font.pixelSize: 16; font.bold: true; color: "white"
                }
            }

            Flickable {
                id: theoryFlick
                width: parent.width - 40
                anchors.horizontalCenter: parent.horizontalCenter
                topMargin: 16
                bottomMargin: 4
                // Cap to the shorter of the content's natural height or 75%
                // of the overlay minus the title/button chrome, so a short
                // theory sizes to fit and a long one scrolls instead of
                // stretching the popup off-screen.
                height: Math.min(theoryContent.implicitHeight + topMargin + bottomMargin,
                                  (Overlay.overlay ? Overlay.overlay.height * 0.75 : 480)
                                  - theoryPopupTitleBar.height - 80)
                contentWidth: width
                contentHeight: theoryContent.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: theoryContent
                    width: theoryFlick.width
                    spacing: 10

                    // Text/photo/audio blocks in the exact order the
                    // creator arranged them in. A single delegate with
                    // visible-toggled children, rather than a Loader
                    // swapping components — Loader's implicit resize-to-item
                    // behavior doesn't respect Layout.* size hints on the
                    // loaded item, which left images collapsed to 0x0 and
                    // invisible.
                    Repeater {
                        model: root.theoryBlocks
                        delegate: Item {
                            id: blockDelegate
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: blockDelegate.modelData.kind === "image" ? (blockDelegate.modelData.imgHeight || 200)
                                : blockDelegate.modelData.kind === "audio" ? blockAudioRow.implicitHeight
                                : blockTextLabel.implicitHeight

                            Label {
                                id: blockTextLabel
                                visible: blockDelegate.modelData.kind === "text"
                                width: blockDelegate.width
                                text: blockDelegate.modelData.value || ""
                                wrapMode: Text.WordWrap
                                color: "#2c3e50"
                            }
                            Rectangle {
                                visible: blockDelegate.modelData.kind === "image"
                                width: blockDelegate.width
                                height: blockDelegate.modelData.imgHeight || 200
                                radius: 8
                                color: "#f0f4f8"
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: blockDelegate.modelData.value || ""
                                    fillMode: Image.PreserveAspectFit
                                    autoTransform: true
                                }
                            }
                            RowLayout {
                                id: blockAudioRow
                                visible: blockDelegate.modelData.kind === "audio"
                                width: blockDelegate.width
                                spacing: 8
                                ToolButton {
                                    text: theoryPopup.playingPath === blockDelegate.modelData.value ? "■" : "▶"
                                    onClicked: {
                                        if (theoryPopup.playingPath === blockDelegate.modelData.value) {
                                            theoryPopupAudioPlayer.stop()
                                            theoryPopup.playingPath = ""
                                        } else {
                                            theoryPopupAudioPlayer.source = blockDelegate.modelData.value
                                            theoryPopupAudioPlayer.play()
                                            theoryPopup.playingPath = blockDelegate.modelData.value
                                        }
                                    }
                                }
                                Label {
                                    text: qsTr("Audio clip")
                                    font.pixelSize: 13
                                    color: "#2c3e50"
                                }
                            }
                        }
                    }
                }
            }

            Button {
                width: parent.width - 40
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 14
                bottomPadding: 20
                text: qsTr("Cancel")
                background: Rectangle {
                    radius: 8
                    implicitHeight: 40
                    color: parent.pressed ? "#555" : "#7f8c8d"
                }
                contentItem: Text {
                    text: parent.text; color: "white"; font.pixelSize: 15; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: theoryPopup.close()
            }
        }
    }

    // ── Body ──────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Reveal link — invisible until the learner has made a mistake.
        Button {
            Layout.alignment: Qt.AlignRight
            visible: ruleTestController.theoryUnlocked
            flat: true
            text: qsTr("💡 View rule")
            onClicked: theoryPopup.open()
        }

        // ── Fill-in-the-gap question ─────────────────────────────────────────
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: (question.type || "gap") === "gap"

            Repeater {
                id: gapRepeater
                // No gaps to render for mc/combobox/dragdrop — kept at 0
                // rather than root.segments.length so submitAnswers()'s
                // gap-collecting loop has nothing spurious to iterate.
                model: (question.type || "gap") === "gap" ? root.segments.length : 0

                Row {
                    id: gapRow
                    required property int index
                    readonly property bool isGap: gapRow.index < root.segments.length - 1
                    // Exposed so resetQuestion()/submitAnswers() can reach
                    // straight into whichever delegate the Repeater is
                    // currently showing at this slot, instead of tracking
                    // instances by hand (which breaks under delegate reuse).
                    readonly property string fieldText: gapField.text
                    function resetField() { gapField.text = "" }
                    spacing: 6

                    Label {
                        text: root.segments[gapRow.index]
                        font.pixelSize: 17
                        color: "#2c3e50"
                        wrapMode: Text.WordWrap
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextField {
                        id: gapField
                        visible: gapRow.isGap
                        width: 110
                        font.pixelSize: 16
                        enabled: !root.isAnswered
                        readonly property bool gapCorrect:
                            root.isAnswered && ruleTestController.lastGapResults.length > gapRow.index
                                ? ruleTestController.lastGapResults[gapRow.index] : true
                        color: !root.isAnswered ? "#2c3e50" : (gapCorrect ? "#27ae60" : "#e74c3c")
                        background: Rectangle {
                            radius: 8
                            color: "white"
                            border.color: !root.isAnswered ? "#dce1e7"
                                : (gapField.gapCorrect ? "#27ae60" : "#e74c3c")
                            border.width: root.isAnswered ? 2 : 1
                        }
                        onAccepted: if (!root.isAnswered) root.submitAnswers()
                    }
                }
            }
        }

        // ── Dropdown-choice question ──────────────────────────────────────────
        // Each blank gets its own box of tappable option chips below the
        // sentence (a separate box per blank when there's more than one),
        // rather than an inline widget — the sentence blanks themselves are
        // just a read-only placeholder reflecting the current pick.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: question.type === "combobox"

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: question.type === "combobox" ? root.segments.length : 0

                    delegate: Row {
                        id: comboRow
                        required property int index
                        readonly property bool isGap: comboRow.index < root.segments.length - 1
                        spacing: 6

                        Label {
                            text: root.segments[comboRow.index]
                            font.pixelSize: 17
                            color: "#2c3e50"
                            wrapMode: Text.WordWrap
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            id: comboBlank
                            visible: comboRow.isGap
                            // null (not yet spun) is kept distinct from ""
                            // (spun to a deliberately-blank option) so the
                            // preview can tell "not answered" from "answered
                            // with nothing" — see comboSelections above.
                            readonly property var picked:
                                root.comboSelections.length > comboRow.index ? root.comboSelections[comboRow.index] : null
                            readonly property bool hasPick: picked !== null && picked !== undefined
                            readonly property bool gapCorrect:
                                root.isAnswered && ruleTestController.lastGapResults.length > comboRow.index
                                    ? ruleTestController.lastGapResults[comboRow.index] : true
                            width: Math.max(70, comboBlankLabel.implicitWidth + 24)
                            height: 36
                            radius: 8
                            color: hasPick ? "#eaf2fb" : "#f7f9fb"
                            border.width: 2
                            border.color: root.isAnswered
                                ? (gapCorrect ? "#27ae60" : "#e74c3c")
                                : "#dce1e7"

                            Label {
                                id: comboBlankLabel
                                anchors.centerIn: parent
                                // A pick of "" (deliberately blank — see
                                // CreatingRuleSet.qml's "___" marker) shows
                                // nothing here, same as its slot on the
                                // cylinder — only the not-yet-spun "___"
                                // placeholder below is actually drawn.
                                text: !comboBlank.hasPick ? "___" : comboBlank.picked
                                font.pixelSize: 14
                                color: comboBlank.hasPick ? "#2c3e50" : "#b0b8c1"
                            }
                        }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("Spin the wheel to choose each blank's word.")
                font.pixelSize: 11
                color: "#95a5a6"
            }

            // One wheel picker per blank, side by side — width follows the
            // longest option in that particular blank's list so a wheel of
            // short words (e.g. "a, an") isn't as wide as one full of long
            // ones (e.g. "unbelievably, undeniably").
            Flow {
                Layout.fillWidth: true
                spacing: 14

                Repeater {
                    model: question.type === "combobox" ? root.comboOptionsPerGap : []

                    delegate: ColumnLayout {
                        id: comboGroup
                        required property int index
                        required property var modelData
                        spacing: 6
                        visible: comboGroup.modelData.length > 0
                        // If this blank's own authored options already
                        // include a deliberate blank ("___" — see
                        // CreatingRuleSet.qml), that entry already serves as
                        // the wheel's "nothing chosen" row (rendered as an
                        // empty slot — see the PathView delegate below) —
                        // prepending a second, separate null placeholder on
                        // top would show two rows for the same idea. So
                        // only wheels with no authored blank get one
                        // prepended; a wheel that already has one starts
                        // sitting right on it, already answered (registered
                        // as "", not null), submittable without spinning.
                        readonly property bool hasAuthoredBlank: comboGroup.modelData.indexOf("") !== -1
                        readonly property var wheelOptions: comboGroup.hasAuthoredBlank
                            ? comboGroup.modelData
                            : [null].concat(comboGroup.modelData)
                        // Where the wheel starts: right on the authored
                        // blank if there is one (wherever it was typed in
                        // the option list), otherwise the leading null.
                        readonly property int initialIndex: comboGroup.hasAuthoredBlank
                            ? comboGroup.modelData.indexOf("") : 0

                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.comboOptionsPerGap.length > 1
                            text: qsTr("Blank %1").arg(comboGroup.index + 1)
                            font.pixelSize: 11
                            font.bold: true
                            color: "#95a5a6"
                        }

                        // The "cylinder": a vertically-snapping wheel of
                        // options, the centered one being the current pick.
                        Rectangle {
                            id: wheelFrame
                            // Includes the word "null" itself — every wheel
                            // shows it somewhere (the unspun placeholder or
                            // the crossed-out authored blank, see
                            // wheelOptions above), so a narrow wheel of
                            // short options (e.g. "a, an") must still be
                            // wide enough for it to fit without clipping.
                            Layout.preferredWidth: Math.max(90,
                                root.widestOptionWidth(comboGroup.modelData.concat([qsTr("null")])) + 44)
                            Layout.preferredHeight: 128
                            radius: 14
                            color: "white"
                            border.color: root.isAnswered
                                ? (comboWheelCorrect ? "#27ae60" : "#e74c3c")
                                : "#dce1e7"
                            border.width: 2
                            clip: true

                            readonly property bool comboWheelCorrect:
                                ruleTestController.lastGapResults.length > comboGroup.index
                                    ? ruleTestController.lastGapResults[comboGroup.index] : true

                            // Highlight band marking the centered/selected row.
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 34
                                radius: 8
                                color: "#eaf2fb"
                            }
                            // Top/bottom fade so the wheel reads as a
                            // cylinder curving away rather than a flat list.
                            Rectangle {
                                anchors { top: parent.top; left: parent.left; right: parent.right }
                                height: 40
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#ffffff" }
                                    GradientStop { position: 1.0; color: "#00ffffff" }
                                }
                            }
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 40
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#00ffffff" }
                                    GradientStop { position: 1.0; color: "#ffffff" }
                                }
                            }

                            PathView {
                                id: comboWheel
                                anchors.fill: parent
                                model: comboGroup.wheelOptions
                                interactive: !root.isAnswered
                                pathItemCount: 5
                                preferredHighlightBegin: 0.5
                                preferredHighlightEnd: 0.5
                                highlightRangeMode: PathView.StrictlyEnforceRange
                                path: Path {
                                    startX: wheelFrame.width / 2; startY: -17
                                    PathLine { x: wheelFrame.width / 2; y: wheelFrame.height + 17 }
                                }
                                delegate: Item {
                                    required property int index
                                    // "var", not "string" — a plain string
                                    // property would coerce both the
                                    // unspun-placeholder null and the
                                    // authored blank ("") to the same JS
                                    // value, making them indistinguishable
                                    // below. Keeping it "var" preserves the
                                    // difference between the two.
                                    required property var modelData
                                    width: comboWheel.width
                                    height: 34
                                    Text {
                                        anchors.centerIn: parent
                                        // Both the not-yet-spun placeholder
                                        // (null) and an authored blank ("")
                                        // read as the word "null" — the
                                        // blank one struck through, since
                                        // spinning to it is a real, already-
                                        // submittable pick of "nothing"
                                        // rather than an unset default.
                                        text: (modelData === null || modelData === "") ? qsTr("null") : modelData
                                        font.strikeout: modelData === ""
                                        font.pixelSize: PathView.isCurrentItem ? 17 : 14
                                        font.bold: PathView.isCurrentItem
                                        color: PathView.isCurrentItem ? "#2c3e50" : "#b0b8c1"
                                        Behavior on font.pixelSize { NumberAnimation { duration: 120 } }
                                    }
                                }
                                // A picker always shows some value centered —
                                // register it the moment this blank's wheel
                                // appears (a new question replaces this whole
                                // Repeater's model, recreating every wheel),
                                // and again on every spin. Starts on
                                // initialIndex — the leading null for a
                                // normal wheel (registers null, so it isn't
                                // submittable until spun away from), or
                                // right on the authored blank for one that
                                // has one (registers "", already submittable
                                // — see comboGroup.hasAuthoredBlank above).
                                onCurrentIndexChanged: root.setComboSelection(
                                    comboGroup.index, comboGroup.wheelOptions[currentIndex])
                                Component.onCompleted: {
                                    if (comboGroup.initialIndex !== 0)
                                        comboWheel.currentIndex = comboGroup.initialIndex
                                    root.setComboSelection(
                                        comboGroup.index, comboGroup.wheelOptions[comboWheel.currentIndex])
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Drag & drop sentence-building question ───────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: question.type === "dragdrop"

            // The sentence, with each numbered blank shown as a drop target.
            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    id: ddBlankRepeater
                    model: question.type === "dragdrop" ? root.segments.length : 0

                    delegate: Row {
                        id: ddRow
                        required property int index
                        readonly property bool isBlank: ddRow.index < root.segments.length - 1
                        spacing: 6

                        Label {
                            text: root.segments[ddRow.index]
                            font.pixelSize: 17
                            color: "#2c3e50"
                            wrapMode: Text.WordWrap
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Blank / drop target — tap a selected tile's target
                        // here, drag a tile onto it, tap a filled blank to
                        // send its tile back to the pool, or drag a filled
                        // blank's tile straight out to another blank (or
                        // back to the pool) to change your mind mid-answer.
                        Rectangle {
                            id: ddBlank
                            visible: ddRow.isBlank
                            readonly property int blankIndex: ddRow.index
                            readonly property int placedTile:
                                root.dragdropPlacements.length > ddBlank.blankIndex ? root.dragdropPlacements[ddBlank.blankIndex] : -1
                            readonly property bool gapCorrect:
                                root.isAnswered && ruleTestController.lastGapResults.length > ddBlank.blankIndex
                                    ? ruleTestController.lastGapResults[ddBlank.blankIndex] : true
                            width: Math.max(70, ddBlankLabel.implicitWidth + 24)
                            height: 36
                            radius: 8
                            color: ddBlank.placedTile !== -1 ? "#eaf2fb" : "#f7f9fb"
                            border.width: 2
                            border.color: root.isAnswered
                                ? (ddBlank.gapCorrect ? "#27ae60" : "#e74c3c")
                                : (root.dragdropHoverBlank === ddBlank.blankIndex ? "#3498db" : "#dce1e7")

                            Label {
                                id: ddBlankLabel
                                anchors.centerIn: parent
                                // Hidden while its tile is draggable (see
                                // placedTileDrag below), which shows the
                                // same text itself so there's no doubling.
                                visible: !placedTileDrag.visible
                                text: {
                                    if (ddBlank.placedTile === -1) return ""
                                    var tile = root.dragdropShuffledOptions[ddBlank.placedTile]
                                    return tile !== "" ? tile : "—"
                                }
                                font.pixelSize: 14
                                color: "#2c3e50"
                            }

                            DropArea {
                                anchors.fill: parent
                                keys: ["x-pp-ddtile"]
                                enabled: !root.isAnswered
                                // Tracked live as the drag moves (rather than
                                // queried once at release time) — whether
                                // containsDrag has already reset to false by
                                // the moment the release handler runs isn't
                                // something to rely on.
                                onEntered: root.dragdropHoverBlank = ddBlank.blankIndex
                                onExited: if (root.dragdropHoverBlank === ddBlank.blankIndex) root.dragdropHoverBlank = -1
                            }

                            MouseArea {
                                anchors.fill: parent
                                // Only handles the "empty blank, place the
                                // selected pool tile" tap — a filled blank's
                                // tap-to-clear and drag both live on
                                // placedTileDrag above it once occupied.
                                enabled: !root.isAnswered && ddBlank.placedTile === -1
                                onClicked: {
                                    if (root.dragdropSelectedTileIndex !== -1)
                                        root.placeDragdropTile(root.dragdropSelectedTileIndex, ddBlank.blankIndex)
                                }
                            }

                            // The tile currently occupying this blank,
                            // draggable exactly like a pool tile so it can
                            // be grabbed straight out to another blank or
                            // back to the pool, without first tapping to
                            // clear it.
                            Rectangle {
                                id: placedTileDrag
                                visible: ddBlank.placedTile !== -1 && !root.isAnswered
                                // width/height (not anchors.fill) — an
                                // active anchor would re-assert x/y every
                                // frame and fight drag.target below,
                                // pinning the tile in place instead of
                                // letting it move with the pointer.
                                width: ddBlank.width
                                height: ddBlank.height
                                radius: 8
                                color: placedTileDragArea.drag.active ? "#d6eaf8" : "transparent"
                                border.width: placedTileDragArea.drag.active ? 2 : 0
                                border.color: "#3498db"
                                z: placedTileDragArea.drag.active ? 100 : 0

                                Drag.active: placedTileDragArea.drag.active
                                Drag.source: placedTileDrag
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2
                                Drag.keys: ["x-pp-ddtile"]

                                Label {
                                    anchors.centerIn: parent
                                    text: ddBlankLabel.text
                                    font.pixelSize: 14
                                    color: "#2c3e50"
                                }

                                MouseArea {
                                    id: placedTileDragArea
                                    anchors.fill: parent
                                    drag.target: placedTileDrag
                                    property bool wasDragging: false
                                    onPressed: wasDragging = false
                                    onPositionChanged: if (drag.active) wasDragging = true
                                    onReleased: {
                                        if (wasDragging) {
                                            if (root.dragdropHoverBlank !== -1 && root.dragdropHoverBlank !== ddBlank.blankIndex)
                                                root.placeDragdropTile(ddBlank.placedTile, root.dragdropHoverBlank)
                                            else if (root.dragdropHoverBlank === -1)
                                                root.clearDragdropBlank(ddBlank.blankIndex)
                                            // else: dropped back on its own
                                            // blank — leave it in place.
                                            root.dragdropHoverBlank = -1
                                        }
                                        // Unlike the pool's Flow (which
                                        // repositions its children itself),
                                        // nothing repositions this overlay
                                        // after a drag — reset it to fill
                                        // its blank again; if the tile moved
                                        // or got cleared this instance is
                                        // hidden anyway, so the reset is a
                                        // no-op in that case.
                                        placedTileDrag.x = 0
                                        placedTileDrag.y = 0
                                    }
                                    onClicked: root.clearDragdropBlank(ddBlank.blankIndex)
                                }
                            }
                        }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("Drag a tile onto a blank, or tap a tile then tap a blank to place it.")
                font.pixelSize: 11
                color: "#95a5a6"
                wrapMode: Text.WordWrap
            }

            // The pool of draggable/tappable tiles — placed tiles disappear
            // from here until their blank is cleared again.
            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: question.type === "dragdrop" ? root.dragdropShuffledOptions : []

                    delegate: Rectangle {
                        id: tileDelegate
                        required property int index
                        required property string modelData
                        readonly property int tileIndex: tileDelegate.index
                        visible: root.dragdropPlacements.indexOf(tileDelegate.index) === -1
                        width: tileLabel.implicitWidth + 24
                        height: 40
                        radius: 8
                        color: root.dragdropSelectedTileIndex === tileDelegate.tileIndex ? "#d6eaf8" : "white"
                        border.color: root.dragdropSelectedTileIndex === tileDelegate.tileIndex ? "#3498db" : "#dce1e7"
                        border.width: 2
                        // Above its Flow siblings and the blanks above it
                        // while actively being dragged, so it's never drawn
                        // underneath something else mid-drag.
                        z: tileDragArea.drag.active ? 100 : 0

                        Drag.active: tileDragArea.drag.active
                        Drag.source: tileDelegate
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2
                        Drag.keys: ["x-pp-ddtile"]

                        Label {
                            id: tileLabel
                            anchors.centerIn: parent
                            text: tileDelegate.modelData !== "" ? tileDelegate.modelData : "—"
                            font.pixelSize: 14
                            color: "#2c3e50"
                        }

                        MouseArea {
                            id: tileDragArea
                            anchors.fill: parent
                            enabled: !root.isAnswered
                            drag.target: tileDelegate
                            // Set the instant an actual drag starts (well
                            // before release), rather than checking
                            // drag.active synchronously inside onReleased —
                            // whether that property has already flipped
                            // back to false by the time onReleased's
                            // handler runs isn't something to rely on.
                            property bool wasDragging: false
                            // Where Flow had this tile before the drag
                            // started, so a drop that misses every blank can
                            // snap it back there — Flow itself won't: it only
                            // repositions children on add/remove/resize/
                            // visibility change, not continuously, so
                            // nothing re-settles a tile whose x/y a drag left
                            // sitting in the middle of the row.
                            property real startX: 0
                            property real startY: 0
                            onPressed: {
                                wasDragging = false
                                startX = tileDelegate.x
                                startY = tileDelegate.y
                            }
                            onPositionChanged: if (drag.active) wasDragging = true
                            onReleased: {
                                // A plain tap (no real drag) never "drops"
                                // the tile; see onClicked below.
                                var placed = wasDragging && root.dragdropHoverBlank !== -1
                                if (placed)
                                    root.placeDragdropTile(tileDelegate.tileIndex, root.dragdropHoverBlank)
                                root.dragdropHoverBlank = -1
                                // A successful placement hides this tile (see
                                // its "visible" binding above) and Flow
                                // reflows what's left, so there's nothing to
                                // restore here in that case.
                                if (!placed) {
                                    tileDelegate.x = tileDragArea.startX
                                    tileDelegate.y = tileDragArea.startY
                                }
                            }
                            onClicked: {
                                root.dragdropSelectedTileIndex =
                                    (root.dragdropSelectedTileIndex === tileDelegate.tileIndex) ? -1 : tileDelegate.tileIndex
                            }
                        }
                    }
                }
            }
        }

        // ── Multiple-choice question ─────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: (question.type || "gap") === "mc"

            Label {
                Layout.fillWidth: true
                text: question.text || ""
                font.pixelSize: 17
                color: "#2c3e50"
                wrapMode: Text.WordWrap
            }
            Label {
                Layout.fillWidth: true
                text: question.singleAnswer === true ? qsTr("Select the correct answer.") : qsTr("Select all that apply.")
                font.pixelSize: 11
                color: "#95a5a6"
            }

            Repeater {
                model: (question.type || "gap") === "mc" ? (question.options || []) : []
                delegate: ItemDelegate {
                    id: mcOption
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true
                    height: 44
                    enabled: !root.isAnswered
                    readonly property bool isSelected: root.selectedMCIndices.indexOf(mcOption.index) !== -1
                    readonly property bool isCorrectOption:
                        (question.correctIndices || []).indexOf(mcOption.index) !== -1
                    readonly property bool isWrongPick: root.isAnswered && mcOption.isSelected && !mcOption.isCorrectOption
                    contentItem: RowLayout {
                        spacing: 10
                        // Drawn rather than "☑"/"☐"/"◉"/"○" — those
                        // dingbat-block glyphs aren't in every Android font
                        // and can render as a tofu box instead of a
                        // checkbox/radio button. A "singleAnswer" question
                        // (see CreatingRuleSet.qml's "Only one correct
                        // answer" toggle) gets a fully round radio-style
                        // indicator instead of a checkbox — question.
                        // singleAnswer doesn't change once this delegate
                        // exists (a new question rebuilds this Repeater from
                        // scratch), so it's safe to read once here rather
                        // than needing a reactive binding.
                        Rectangle {
                            Layout.leftMargin: 12
                            width: 18; height: 18
                            radius: question.singleAnswer === true ? width / 2 : 3
                            color: mcOption.isSelected ? "#3498db" : "white"
                            border.color: mcOption.isSelected ? "#3498db" : "#95a5a6"
                            border.width: 2
                            Canvas {
                                anchors.fill: parent
                                visible: mcOption.isSelected
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    if (question.singleAnswer === true) {
                                        ctx.fillStyle = "white"
                                        ctx.beginPath()
                                        ctx.arc(width / 2, height / 2, width * 0.22, 0, 2 * Math.PI)
                                        ctx.fill()
                                        return
                                    }
                                    ctx.strokeStyle = "white"
                                    ctx.lineWidth = 2
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.beginPath()
                                    ctx.moveTo(width * 0.22, height * 0.52)
                                    ctx.lineTo(width * 0.42, height * 0.72)
                                    ctx.lineTo(width * 0.78, height * 0.28)
                                    ctx.stroke()
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: mcOption.modelData
                            color: "#2c3e50"
                            font.pixelSize: 15
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    background: Rectangle {
                        radius: 8
                        color: root.isAnswered && mcOption.isCorrectOption ? "#d4efdf"
                            : mcOption.isWrongPick ? "#fadbd8"
                            : mcOption.isSelected ? "#eaf2fb" : "white"
                        border.color: root.isAnswered && mcOption.isCorrectOption ? "#27ae60"
                            : mcOption.isWrongPick ? "#e74c3c"
                            : mcOption.isSelected ? "#3498db" : "#dce1e7"
                        border.width: (mcOption.isSelected || (root.isAnswered && mcOption.isCorrectOption) || mcOption.isWrongPick) ? 2 : 1
                    }
                    onClicked: root.toggleMCOption(mcOption.index)
                }
            }
        }

        // Correct answer(s) shown when wrong.
        Label {
            visible: root.isAnswered && !ruleTestController.lastAnswerCorrect
            Layout.fillWidth: true
            text: (question.type || "gap") === "mc"
                ? qsTr("Correct: ") + (question.correctIndices || [])
                    .map(function(i) { return (question.options || [])[i] })
                    .join(", ")
                // A blank whose correct answer is deliberately empty (see
                // the "\_" marker) would otherwise leave a bare "," in this
                // list — show "—" for it instead, same as the wheel/tile UI.
                : qsTr("Correct: ") + (question.answers || [])
                    .map(function(a) { return a !== "" ? a : "—" })
                    .join(", ")
            color: "#e74c3c"
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }

        Button {
            visible: !root.isAnswered
            enabled: ((question.type || "gap") !== "mc" || root.selectedMCIndices.length > 0)
                && ((question.type || "gap") !== "combobox" || root.comboSelectionsComplete())
            text: qsTr("Submit")
            Layout.fillWidth: true
            background: Rectangle {
                radius: 10
                color: !parent.enabled ? "#a9dfbf" : (parent.pressed ? "#1e8449" : "#27ae60")
            }
            contentItem: Text {
                text: parent.text; color: "white"; font.pixelSize: 15; font.bold: true
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            onClicked: root.submitAnswers()
        }

        // ── Progress bar ─────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Label {
                text: qsTr("Correct: %1 / %2")
                    .arg(ruleTestController.correctAnswers)
                    .arg(ruleTestController.totalQuestions)
                font.pixelSize: 12
                color: "#7f8c8d"
            }
            ProgressBar {
                id: progressBar
                Layout.fillWidth: true
                from: 0
                to: ruleTestController.totalQuestions
                value: ruleTestController.correctAnswers
                background: Rectangle { radius: 4; color: "#dce1e7"; implicitHeight: 8 }
                contentItem: Item {
                    implicitHeight: 8
                    clip: true
                    Rectangle {
                        width: progressBar.visualPosition * parent.width
                        height: parent.height
                        radius: 4
                        color: "#27ae60"
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    // ── Footer ────────────────────────────────────────────────────────────────
    footer: Rectangle {
        height: 64 + SafeArea.margins.bottom
        color: "#2c3e50"

        Button {
            id: nextButton
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top; topMargin: (64 - height) / 2
            }
            width: parent.width * 0.7
            height: 44
            text: ruleTestController.testComplete ? qsTr("See Results") : qsTr("Next →")
            enabled: root.isAnswered
            background: Rectangle {
                radius: 22
                color: !nextButton.enabled ? "#4a6070" : (nextButton.pressed ? "#2980b9" : "#3498db")
            }
            contentItem: Text {
                text: nextButton.text
                color: nextButton.enabled ? "white" : "#8fa7b8"
                font.pixelSize: 17; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                ruleTestController.nextQuestion()
                if (ruleTestController.testComplete)
                    getResults()
            }
        }
    }
}
