import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SpellingTestController

Page {
    id: root
    signal getResults()
    signal saveAndGoBack()  // emitted when user presses Back mid-test

    // Resolves to whichever controller is active in Main.qml (standard or Leitner).
    property var spellingTestController: rootScope.spellingTestController

    // Shorthand
    readonly property int ttype: spellingTestController.testType
    readonly property bool isLeitner:
        ttype === SpellingTestController.TypeE_Leitner ||
        ttype === SpellingTestController.TypeF_LeitnerReversed
    readonly property bool isMC:
        ttype === SpellingTestController.TypeC_MCFromHint ||
        ttype === SpellingTestController.TypeD_MCFromWord ||
        (isLeitner && spellingTestController.leitnerMCPhase)
    readonly property bool isWritePhase:
        ttype === SpellingTestController.TypeA_WriteFromHint ||
        ttype === SpellingTestController.TypeB_WriteFromWord ||
        (isLeitner && !spellingTestController.leitnerMCPhase)

    // Per-question state (reset each word)
    property bool answerSubmitted: false
    property bool answerIsCorrect: false

    // Allow "mark as correct" for type A, B (write) and type D (MC pick hint)
    readonly property bool canMarkAsCorrect:
        answerSubmitted && !answerIsCorrect &&
        (ttype === SpellingTestController.TypeA_WriteFromHint ||
         ttype === SpellingTestController.TypeB_WriteFromWord ||
         ttype === SpellingTestController.TypeD_MCFromWord ||
         (isLeitner && !spellingTestController.leitnerMCPhase))

    // Reset UI state whenever the controller loads a new word
    Connections {
        target: spellingTestController
        function onCurrentWordChanged() { root.resetQuestion() }
    }

    // If the test was already completed before this page opened, go to results
    Component.onCompleted: {
        if (spellingTestController.isTestComplete()) {
            Qt.callLater(function() { root.getResults() })
        } else if (isWritePhase) {
            guessInputField.forceActiveFocus()
        }
    }

    function resetQuestion() {
        answerSubmitted = false
        answerIsCorrect = false
        guessInputField.text = ""
        guessInputField.color = "#2c3e50"
    }

    background: Rectangle { color: "#f0f4f8" }

    // ── Header ─────────────────────────────────────────────────────────────────
    header: Rectangle {
        readonly property int contentHeight: 56
        height: contentHeight + SafeArea.margins.top
        color: "#2c3e50"

        ColumnLayout {
            anchors {
                left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: 16; rightMargin: 16; bottomMargin: 4
            }
            height: parent.contentHeight - 8
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: {
                        if (ttype === SpellingTestController.TypeB_WriteFromWord ||
                            ttype === SpellingTestController.TypeD_MCFromWord ||
                            ttype === SpellingTestController.TypeF_LeitnerReversed)
                            return spellingTestController.currentWord
                        return spellingTestController.currentHint
                    }
                    font.pixelSize: 18
                    font.bold: true
                    color: "white"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                }

                Label {
                    text: spellingTestController.correctAnswers + "/" +
                          spellingTestController.totalQuestions
                    font.pixelSize: 13
                    color: "#3498db"
                }
            }

            // Leitner phase indicator
            Label {
                visible: isLeitner
                text: spellingTestController.leitnerMCPhase
                    ? qsTr("Learning ▸ Set1: %1 remaining").arg(spellingTestController.leitnerSet1Count)
                    : qsTr("Testing ▸ Set2: %1 to master").arg(spellingTestController.leitnerSet2Count)
                font.pixelSize: 11
                color: spellingTestController.leitnerMCPhase ? "#f39c12" : "#2ecc71"
            }
        }
    }

    // ── Body ───────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Image
        Rectangle {
            Layout.fillWidth: true
            height: 160
            radius: 12
            color: spellingTestController.currentImageUrl !== "" ? "transparent" : "#eaf4fb"
            clip: true
            border.color: "#dce1e7"
            visible: !isMC

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                source: spellingTestController.currentImageUrl
                visible: spellingTestController.currentImageUrl !== ""
            }
            Label {
                anchors.centerIn: parent
                text: "🖼"
                font.pixelSize: 56
                opacity: 0.2
                visible: spellingTestController.currentImageUrl === ""
            }
        }

        // Only rendered when the word has an example usage
        Label {
            Layout.fillWidth: true
            text: spellingTestController.currentExampleUsage
            visible: !isMC && spellingTestController.currentExampleUsage !== ""
            font.italic: true
            font.pixelSize: 13
            color: "#7f8c8d"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        // ── Text-input section (types A, B, Leitner write phase) ──────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: isWritePhase

            TextField {
                id: guessInputField
                Layout.fillWidth: true
                placeholderText: (ttype === SpellingTestController.TypeB_WriteFromWord ||
                                  ttype === SpellingTestController.TypeF_LeitnerReversed)
                    ? qsTr("Type the hint / translation…")
                    : qsTr("Type the expression…")
                font.pixelSize: 18
                color: {
                    if (!answerSubmitted) return "#2c3e50"
                    return answerIsCorrect ? "#27ae60" : "#e74c3c"
                }
                background: Rectangle {
                    radius: 10
                    color: "white"
                    border.color: {
                        if (!answerSubmitted)
                            return guessInputField.activeFocus ? "#3498db" : "#dce1e7"
                        return answerIsCorrect ? "#27ae60" : "#e74c3c"
                    }
                    border.width: answerSubmitted ? 2 : (guessInputField.activeFocus ? 2 : 1)
                }
                leftPadding: 14
                enabled: !answerSubmitted
                onEditingFinished: submitTextAnswer()
            }

            // Show correct answer when wrong
            Label {
                visible: answerSubmitted && !answerIsCorrect
                text: {
                    if (ttype === SpellingTestController.TypeB_WriteFromWord ||
                        ttype === SpellingTestController.TypeF_LeitnerReversed)
                        return qsTr("Correct: ") + spellingTestController.currentHint
                    return qsTr("Correct: ") + spellingTestController.currentWord
                }
                color: "#e74c3c"
                font.pixelSize: 15
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // "Mark as correct" button for typos
            Button {
                visible: canMarkAsCorrect
                text: qsTr("✓ Mark as correct (I mistyped)")
                Layout.fillWidth: true
                background: Rectangle {
                    radius: 10
                    color: parent.pressed ? "#1a6ca8" : "#3498db"
                }
                contentItem: Text {
                    text: parent.text; color: "white"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    spellingTestController.markAsCorrect()
                    answerIsCorrect = true
                }
            }

            // Submit button (before answering)
            Button {
                visible: !answerSubmitted
                text: qsTr("Submit")
                Layout.fillWidth: true
                background: Rectangle {
                    radius: 10
                    color: parent.pressed ? "#1e8449" : "#27ae60"
                }
                contentItem: Text {
                    text: parent.text; color: "white"
                    font.pixelSize: 15; font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: submitTextAnswer()
            }
        }

        // In MC mode (no image, no write section) this spacer shares the empty
        // vertical space with the bottom spacer, centering the option group.
        Item { Layout.fillHeight: true; visible: isMC }

        // ── Multiple-choice section (types C, D, Leitner MC phase) ────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: isMC

            Repeater {
                model: spellingTestController.options

                Button {
                    id: optBtn
                    required property int index
                    required property string modelData
                    Layout.fillWidth: true
                    text: modelData
                    height: 56

                    readonly property bool isSelected: answerSubmitted &&
                        spellingTestController.selectedOption === index
                    readonly property bool isCorrect: answerSubmitted &&
                        spellingTestController.correctOptionIndex === index

                    background: Rectangle {
                        radius: 10
                        color: {
                            if (!answerSubmitted) return optBtn.pressed ? "#d0d8e0" : "white"
                            if (optBtn.isCorrect) return "#27ae60"
                            if (optBtn.isSelected) return "#e74c3c"
                            return "#f0f4f8"
                        }
                        border.color: {
                            if (!answerSubmitted) return optBtn.pressed ? "#3498db" : "#dce1e7"
                            if (optBtn.isCorrect) return "#1e8449"
                            if (optBtn.isSelected) return "#c0392b"
                            return "#dce1e7"
                        }
                        border.width: (optBtn.isCorrect || optBtn.isSelected) ? 2 : 1
                    }
                    contentItem: Text {
                        text: optBtn.text
                        color: {
                            if (!answerSubmitted) return "#2c3e50"
                            if (optBtn.isCorrect || optBtn.isSelected) return "white"
                            return "#95a5a6"
                        }
                        font.pixelSize: 15
                        font.bold: optBtn.isCorrect || optBtn.isSelected
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                    }
                    enabled: !answerSubmitted
                    onClicked: {
                        spellingTestController.selectOption(index)
                        answerIsCorrect = spellingTestController.lastAnswerCorrect
                        answerSubmitted = true
                    }
                }
            }

            // "Mark as correct" for type D (misclicked)
            Button {
                visible: canMarkAsCorrect
                text: qsTr("✓ Mark as correct (I misclicked)")
                Layout.fillWidth: true
                background: Rectangle {
                    radius: 10
                    color: parent.pressed ? "#1a6ca8" : "#3498db"
                }
                contentItem: Text {
                    text: parent.text; color: "white"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    spellingTestController.markAsCorrect()
                    answerIsCorrect = true
                }
            }
        }

        // ── Progress bar ───────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Label {
                text: qsTr("Correct: %1 / %2")
                    .arg(spellingTestController.correctAnswers)
                    .arg(spellingTestController.totalQuestions)
                font.pixelSize: 12
                color: "#7f8c8d"
            }
            ProgressBar {
                id: progressBar
                Layout.fillWidth: true
                from: 0
                to: spellingTestController.totalQuestions
                value: spellingTestController.correctAnswers
                background: Rectangle { radius: 4; color: "#dce1e7"; implicitHeight: 8 }
                // Qt's resizeContent() overrides width on a direct contentItem Rectangle,
                // so wrap in Item and let the inner Rectangle compute its own width.
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

    // ── Footer ─────────────────────────────────────────────────────────────────
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
            text: spellingTestController.testComplete
                ? qsTr("See Results")
                : qsTr("Next →")
            enabled: answerSubmitted
            background: Rectangle {
                radius: 22
                color: !nextButton.enabled ? "#4a6070"
                     : nextButton.pressed   ? "#2980b9"
                     : "#3498db"
            }
            contentItem: Text {
                text: nextButton.text
                color: nextButton.enabled ? "white" : "#8fa7b8"
                font.pixelSize: 17; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                spellingTestController.nextQuestion()///here
                if (spellingTestController.testComplete) {///here
                    spellingTestController.saveProgress()
                    getResults()
                    return
                }

                root.answerSubmitted = false
                root.answerIsCorrect = false
                guessInputField.text = ""
                guessInputField.color = "#2c3e50"
                if (isWritePhase)
                    guessInputField.forceActiveFocus()
                if (spellingTestController.testComplete)
                    answerSubmitted = true
            }
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────────
    function submitTextAnswer() {
        if (answerSubmitted) return
        const correct = spellingTestController.checkTypedAnswer(guessInputField.text)
        answerIsCorrect = correct
        answerSubmitted = true
        if (!correct) {
            const expected = (ttype === SpellingTestController.TypeB_WriteFromWord ||
                              ttype === SpellingTestController.TypeF_LeitnerReversed)
                ? spellingTestController.currentHint
                : spellingTestController.currentWord
            guessInputField.text   = expected
            guessInputField.color  = "#e74c3c"
        } else {
            guessInputField.color  = "#27ae60"
        }
        nextButton.forceActiveFocus()
    }
}
