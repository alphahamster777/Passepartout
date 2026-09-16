import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

import AppController
import SetPreviewMenuController
import SpellingTestController
import LeitnerTestController
import FlashCardController
import RuleTestController
import RecSetManager
import ShareHelper
import GoogleSignInHelper
import FirebaseAiHelper
import AppLifecycleBridge

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 360
    height: 640
    title: "Passepartout"

    // ApplicationWindow auto-pads contentItem by SafeArea.margins (top/bottom)
    // by default; disabled here because each Page's header/footer already grows
    // by the same margins itself so its colored bar can extend behind the system
    // bars instead of leaving a gap in the window's own plain background.
    topPadding: 0
    bottomPadding: 0

    FocusScope {
        id: rootScope
        anchors.fill: parent
        focus: true

        property string signInError: ""
        property string shareErrorMessage: ""

        // Pops the current test page and returns to the Choose Test Type popup
        // on Review Expressions (reopening it also refreshes its "remaining"
        // counts, since that's wired to popupRefresh via testTypePopup.onAboutToShow).
        function backToTestTypeMenu() {
            stackView.pop()
            Qt.callLater(function() {
                if (typeof stackView.currentItem.openTestTypePopup === "function")
                    stackView.currentItem.openTestTypePopup()
            })
        }

        // Mirrors CreatingRuleSet.qml's splitEscaped()/decodeBlankMarker() —
        // needed again here since this is where rule-set questions are
        // actually parsed into their saved shape (and reconstructed back
        // into editable text). Splits `text` on `delimiter`, honoring "\\"
        // as an escaped literal backslash and "\<delimiter>" as an escaped
        // literal occurrence of the delimiter itself inside one option.
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

        // "___" authored as a whole option means "deliberately blank" — see
        // CreatingRuleSet.qml's Options hint for combobox/dragdrop questions.
        function decodeBlankMarker(s) {
            return s === "___" ? "" : s
        }

        // Inverse of decodeBlankMarker + splitEscaped()'s delimiter-escaping
        // — re-encodes a stored option/answer value back into authored text
        // so editing an existing question round-trips exactly, including
        // any literal comma/"::" it contains or an intentionally blank ("")
        // value. A lone ":" never needs escaping — splitEscaped() only ever
        // splits on the exact 2-character "::" — so only "\\", ",", and an
        // actual "::" run get escaped here, matching what splitEscaped()
        // actually knows how to reverse.
        function escapeListValue(s) {
            if (s === "") return "___"
            return String(s).replace(/\\/g, "\\\\").replace(/,/g, "\\,").replace(/::/g, "\\::")
        }

        // Converts one saved/JSON-shaped question — as returned by both
        // RuleSetManager::getQuestionFromSetQML (editing an existing set)
        // and RuleSetManager::readSetFromZip (importing a shared .ppset) —
        // into the row shape CreatingRuleSet.qml's ruleSetModel expects.
        // Shared between onEditRuleSet and onIncomingFileReady below since
        // both need the exact same conversion. Doesn't set "id" — the
        // caller assigns that based on its own context (an existing
        // question's saved id vs. a freshly imported question having none).
        function ruleSetRowFromQuestion(q) {
            if (q.type === "mc") {
                return {
                    questionType: "mc",
                    questionText: q.text || "",
                    answersText: "",
                    mcOptionsText: (q.options || []).map(rootScope.escapeListValue).join(", "),
                    mcCorrectIndicesText: (q.correctIndices || []).join(","),
                    poolOptionsText: "",
                    comboCorrectIndicesText: "",
                    ddPlacementsText: "",
                    mcSingleAnswer: q.singleAnswer === true
                }
            } else if (q.type === "combobox") {
                var loadedGroups = q.optionsPerGap || []
                var loadedAnswers = q.answers || []
                // Re-derive which chip was tapped from the saved answer's
                // position within its own blank's group.
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
                        .map(function(group) { return group.map(rootScope.escapeListValue).join(", ") })
                        .join("::"),
                    comboCorrectIndicesText: comboCorrectIndices.join(","),
                    ddPlacementsText: "",
                    mcSingleAnswer: false
                }
            } else if (q.type === "dragdrop") {
                var ddPool = q.options || []
                var ddSavedAnswers = q.answers || []
                // Re-derive which pool tile fills each blank from the saved
                // answer's position in the saved pool — each pool tile used
                // at most once, so a repeated answer value (two identical
                // decoy-free tiles) still maps each blank to its own
                // distinct tile.
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
                    poolOptionsText: ddPool.map(rootScope.escapeListValue).join(", "),
                    comboCorrectIndicesText: "",
                    ddPlacementsText: ddPlacements.join(","),
                    mcSingleAnswer: false
                }
            }
            return {
                questionType: "gap",
                questionText: q.text || "",
                answersText: (q.answers || []).map(rootScope.escapeListValue).join(", "),
                mcOptionsText: "",
                mcCorrectIndicesText: "",
                poolOptionsText: "",
                comboCorrectIndicesText: "",
                ddPlacementsText: "",
                mcSingleAnswer: false
            }
        }

        // Shared between onEditRuleSet and onIncomingFileReady's rule-set
        // import path — populates a CreatingRuleSet page's theory blocks
        // model from a {blocks:[...]} theory object.
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

        // CreatingRuleSet.qml's counterpart to CreatingRecSet.qml's own
        // importFromPath() — that one lives on the page itself since
        // RecSetManager::readSetFromZip returns words directly in the
        // row shape recSetModel wants; a rule set's saved questions need
        // the same ruleSetRowFromQuestion() conversion onEditRuleSet uses,
        // so this lives here instead where that's already in scope.
        function importRuleSetFromPath(page, path) {
            var result = AppController.ruleSetManager.readSetFromZip(path)
            if (!result || !result.name) return
            page.ruleSetName = result.name
            rootScope.hydrateTheoryBlocks(page.theoryBlocksModelRef, result.theory || {})
            var gModelRef = page.ruleSetModelRef
            gModelRef.clear()
            var questions = result.questions || []
            for (var i = 0; i < questions.length; ++i) {
                var row = rootScope.ruleSetRowFromQuestion(questions[i])
                row.id = i + 1
                gModelRef.append(row)
            }
            page.nextQuestionId = questions.length + 1
            page.selectedCardIndex = questions.length > 0 ? questions.length - 1 : 0
        }

        Keys.onReleased: function(event) {
            // Nothing to navigate behind the sign-in screen — let the OS
            // handle back as usual (e.g. minimize on Android) instead of
            // popping/quitting a stack the user can't see or reach.
            if (!FirebaseAiHelper.signedIn) return

            const androidBackPressed =
                Qt.platform.os === "android" && event.key === Qt.Key_Back

            const desktopLeftPressed =
                Qt.platform.os !== "android" && event.key === Qt.Key_Left

            if (androidBackPressed || desktopLeftPressed) {
                // If the current page has its own popup open (e.g. Choose Test
                // Type), close that first instead of navigating the stack.
                if (stackView.currentItem &&
                    typeof stackView.currentItem.testTypePopupVisible !== "undefined" &&
                    stackView.currentItem.testTypePopupVisible) {
                    stackView.currentItem.closeTestTypePopup()
                    event.accepted = true
                    return
                }

                if (stackView.depth > 1) {
                    if (typeof stackView.currentItem.getResults === "function" &&
                        !spellingTestController.isTestComplete()) {
                        // Mid-test back. If an answer was already submitted but
                        // "Next" wasn't pressed yet, commit it first (nextQuestion
                        // advances the queue position and saves) — otherwise the
                        // saved queuePos stays one behind the already-counted
                        // answer, and resuming lets that same word be answered
                        // (and counted) again, eventually pushing correctAnswers
                        // past totalQuestions.
                        if (typeof stackView.currentItem.answerSubmitted !== "undefined" &&
                            stackView.currentItem.answerSubmitted) {
                            spellingTestController.nextQuestion()
                        } else {
                            spellingTestController.saveProgress()
                        }
                        rootScope.backToTestTypeMenu()
                    } else {
                        stackView.pop()
                    }
                } else {
                    Qt.quit()
                }
                event.accepted = true
            }
        }

        SpellingTestController {
            id: regularTestController
        }

        LeitnerTestController {
            id: leitnerTestController
        }

        FlashCardController {
            id: flashCardController
        }

        RuleTestController {
            id: ruleTestController
        }
        // Bridges the id above into a property reachable from separately
        // pushed pages (ids declared here aren't visible from other .qml
        // files) — RuleSetPreview.qml needs a stable handle to the
        // rule controller itself, independent of whatever the shared
        // "active controller" slot below currently points to.
        property var ruleTestControllerRef: ruleTestController

        // Active controller — this same slot is repointed at ruleTestController
        // for rule sets too (see onRuleSetSelected below), since it's what
        // SpellingTest.qml/FlashCard.qml/Results.qml already read from; despite
        // the name, it just means "whichever controller is running the current
        // test session." RuleTestController's testType (100) doesn't match
        // any BaseTestController::TestType, so Results.qml's Leitner/FlashCard
        // branches correctly fall through to its plain session-totals display.
        property var spellingTestController: regularTestController

        SetPreviewMenuController {
            id: setPreviewController
        }

        StackView {
            id: stackView
            anchors.fill: parent
            initialItem: setDirMenu
        }

        // Sign-in is mandatory for the whole app (Google first, Apple later)
        // — this sits above everything else and blocks it until
        // FirebaseAiHelper.signedIn is true. Kept as an always-present
        // overlay rather than a StackView page so there's nothing to pop
        // back behind and no page transition to fight with on sign-out.
        Rectangle {
            id: signInScreen
            anchors.fill: parent
            visible: !FirebaseAiHelper.signedIn
            z: 100
            color: "#2c3e50"

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 64, 320)
                spacing: 24

                Label {
                    Layout.fillWidth: true
                    text: qsTr("Passepartout")
                    font.pixelSize: 28
                    font.bold: true
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                }

                Label {
                    Layout.fillWidth: true
                    text: qsTr("Sign in to continue")
                    font.pixelSize: 14
                    color: "#bdc3c7"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Label {
                    Layout.fillWidth: true
                    visible: rootScope.signInError !== ""
                    text: "⚠ " + rootScope.signInError
                    color: "#e74c3c"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                ItemDelegate {
                    id: googleSignInButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    enabled: !GoogleSignInHelper.signingIn
                    background: Rectangle {
                        radius: 10
                        color: googleSignInButton.pressed ? "#f0f0f0" : "white"
                    }
                    contentItem: RowLayout {
                        spacing: 10
                        Item { Layout.fillWidth: true }
                        BusyIndicator {
                            visible: GoogleSignInHelper.signingIn
                            running: GoogleSignInHelper.signingIn
                            implicitWidth: 20; implicitHeight: 20
                        }
                        Text {
                            text: GoogleSignInHelper.signingIn ? qsTr("Opening browser…") : qsTr("Sign in with Google")
                            color: "#3c4043"
                            font.pixelSize: 15; font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                    }
                    onClicked: {
                        rootScope.signInError = ""
                        GoogleSignInHelper.beginSignIn()
                    }
                }
            }
        }

        Connections {
            target: GoogleSignInHelper
            function onSignInSucceeded(idToken, refreshToken, expiresInSeconds) {
                rootScope.signInError = ""
                FirebaseAiHelper.adoptSignIn(idToken, refreshToken, expiresInSeconds)
            }
            function onSignInFailed(error) {
                rootScope.signInError = error
            }
        }

        // Saved reference to the CreatingRecSet page so the camera result can update it
        property var creatingPageRef: null

        Component { id: setDirMenu;         SetDirMenu {}           }
        Component { id: creatingRecSetMenu; CreatingRecSet {}       }
        Component { id: creatingRuleSetMenu; CreatingRuleSet {} }
        Component { id: ruleSetPreviewPage; RuleSetPreview {} }
        Component { id: ruleTestPage;    RuleTest {}          }
        Component { id: setPreviewMenu;     SetPreviewMenu {}       }
        Component { id: spellingTestPage;   SpellingTest {}         }
        Component { id: flashCardPage;      FlashCard {}            }
        Component { id: resultsPage;        Results {}              }
        Component { id: cameraCaptureMenu;  CameraCapture {}        }
        Component { id: aboutPage;          AboutOpenSourcePage {}  }
        Component { id: licenseTextPage;    LicenseTextPage {}      }

        ///////////////////////////////connections/////////////////////////////////////////

        Loader {
            id: setDirMenuConnectionLoader
            active: stackView.currentItem &&
                    typeof stackView.currentItem.recSetSelected === "function" &&
                    typeof stackView.currentItem.addRecSet      === "function" &&
                    typeof stackView.currentItem.editRecSet     === "function" &&
                    typeof stackView.currentItem.folderSelected === "function"
            sourceComponent: setDirMenuConnectionComponent
        }

        Component {
            id: setDirMenuConnectionComponent
            Connections {
                target: stackView.currentItem

                function onRecSetSelected(num: int) {
                    // Push SetPreview without popping the SetDirMenu so that
                    // back-from-test can return to the correct directory.
                    setPreviewController.initialize(AppController.recSetManager, num)
                    stackView.push(setPreviewMenu)
                }
                function onAddRecSet() {
                    stackView.push(creatingRecSetMenu,
                                   { folderPath: stackView.currentItem.folderPath })
                }
                function onEditRecSet(num: int) {
                    stackView.push(creatingRecSetMenu)
                    var mgr = AppController.recSetManager
                    var info = mgr.getRecSetInfoQML(num)
                    stackView.currentItem.recSetName   = info.name
                    stackView.currentItem.recSetIdx    = num
                    stackView.currentItem.folderPath   = info.folderPath
                    var modelRef = stackView.currentItem.recSetModelRef
                    modelRef.clear()
                    for (var i = 0; i < info.wordCount; ++i) {
                        var rec = mgr.getWordFromRecSetQML(num, i)
                        modelRef.append({
                            languageFrom: rec.exprLangID,
                            languageTo:   rec.hintLangID,
                            expression:   rec.expression,
                            hint:         rec.hint,
                            audioPath:    rec.audioPath,
                            imagePath:    rec.imagePath,
                            exampleUsage: rec.exampleUsage
                        })
                    }
                    stackView.currentItem.selectedCardIndex = info.wordCount > 0 ? info.wordCount - 1 : 0
                }
                function onFolderSelected(path: string) {
                    stackView.push(setDirMenu, { folderPath: path })
                }
                function onRuleSetSelected(num: int) {
                    // Theory is freely readable here before testing — it's
                    // only hidden (behind a mistake-triggered popup link)
                    // once the actual test starts.
                    var gmgr = AppController.ruleSetManager
                    var ginfo = gmgr.getRuleSetInfoQML(num)
                    stackView.push(ruleSetPreviewPage, {
                        ruleSetIdx: num,
                        setName: ginfo.name,
                        theory: ginfo.theory,
                        questionCount: ginfo.questionCount
                    })
                }
                function onAddRuleSet() {
                    stackView.push(creatingRuleSetMenu,
                                   { folderPath: stackView.currentItem.folderPath })
                }
                function onEditRuleSet(num: int) {
                    stackView.push(creatingRuleSetMenu)
                    var gmgr = AppController.ruleSetManager
                    var ginfo = gmgr.getRuleSetInfoQML(num)
                    stackView.currentItem.ruleSetName = ginfo.name
                    stackView.currentItem.ruleSetIdx  = num
                    stackView.currentItem.folderPath     = ginfo.folderPath
                    rootScope.hydrateTheoryBlocks(stackView.currentItem.theoryBlocksModelRef, ginfo.theory || {})
                    var gModelRef = stackView.currentItem.ruleSetModelRef
                    gModelRef.clear()
                    var maxQuestionId = 0
                    for (var gi = 0; gi < ginfo.questionCount; ++gi) {
                        var q = gmgr.getQuestionFromSetQML(num, gi)
                        // Questions saved before ids existed have none —
                        // assign one from position so old sets still work.
                        var qId = q.id !== undefined && q.id !== null ? q.id : (gi + 1)
                        maxQuestionId = Math.max(maxQuestionId, qId)
                        var row = rootScope.ruleSetRowFromQuestion(q)
                        row.id = qId
                        gModelRef.append(row)
                    }
                    stackView.currentItem.nextQuestionId = maxQuestionId + 1
                    stackView.currentItem.selectedCardIndex = ginfo.questionCount > 0 ? ginfo.questionCount - 1 : 0
                }
            }
        }

        Loader {
            id: setPreviewMenuConnectionLoader
            active: stackView.currentItem && typeof stackView.currentItem.navigateToTest === "function"
            sourceComponent: setPreviewMenuConnectionComponent
        }

        Component {
            id: setPreviewMenuConnectionComponent
            Connections {
                target: stackView.currentItem
                function onNavigateToTest(testType) {
                    rootScope.spellingTestController =
                        (testType === SpellingTestController.TypeE_Leitner ||
                         testType === SpellingTestController.TypeF_LeitnerReversed)
                            ? leitnerTestController
                            : (testType === SpellingTestController.TypeG_FlashCard)
                                ? flashCardController
                                : regularTestController
                    rootScope.spellingTestController.initialize(
                        AppController.recSetManager,
                        setPreviewController.currentSetIndex,
                        testType)
                    stackView.push(testType === SpellingTestController.TypeG_FlashCard
                                   ? flashCardPage : spellingTestPage)
                }
            }
        }

        Loader {
            id: ruleSetPreviewConnectionLoader
            active: stackView.currentItem && typeof stackView.currentItem.startRuleTest === "function"
            sourceComponent: ruleSetPreviewConnectionComponent
        }

        Component {
            id: ruleSetPreviewConnectionComponent
            Connections {
                target: stackView.currentItem
                function onStartRuleTest(idx: int) {
                    rootScope.spellingTestController = ruleTestController
                    ruleTestController.initialize(AppController.ruleSetManager, idx)
                    stackView.push(ruleTestPage)
                }
            }
        }

        Loader {
            id: spellingTestConnectionLoader
            active: stackView.currentItem && typeof stackView.currentItem.getResults === "function"
            sourceComponent: spellingTestConnectionComponent
        }

        Component {
            id: spellingTestConnectionComponent
            Connections {
                target: stackView.currentItem
                function onGetResults() {
                    stackView.pop()
                    stackView.push(resultsPage)
                }
            }
        }

        Loader {
            id: resultsConnectionLoader
            active: stackView.currentItem && typeof stackView.currentItem.resultsNextPressed === "function"
            sourceComponent: resultsConnectionComponent
        }

        Loader {
            id: flashCardConnectionLoader
            active: stackView.currentItem && typeof stackView.currentItem.flashCardExit === "function"
            sourceComponent: flashCardConnectionComponent
        }

        Component {
            id: flashCardConnectionComponent
            Connections {
                target: stackView.currentItem
                function onFlashCardExit() {
                    flashCardController.saveProgress()
                    rootScope.backToTestTypeMenu()
                }
            }
        }

        Loader {
            id: cameraConnectionLoader
            active: stackView.currentItem && typeof stackView.currentItem.photoCaptured === "function"
            sourceComponent: cameraConnectionComponent
        }

        Component {
            id: cameraConnectionComponent
            Connections {
                target: stackView.currentItem
                function onPhotoCaptured(cardIndex, imagePath) {
                    stackView.pop()
                    if (rootScope.creatingPageRef && cardIndex >= 0)
                        rootScope.creatingPageRef.recSetModelRef.set(cardIndex, { imagePath: imagePath })
                    rootScope.creatingPageRef = null
                }
                function onCancelCapture() {
                    stackView.pop()
                    rootScope.creatingPageRef = null
                }
            }
        }

        Component {
            id: resultsConnectionComponent
            Connections {
                target: stackView.currentItem
                function onResultsNextPressed() {
                    // Pop back to SetPreview (Results → SpellingTest → SetPreview).
                    // Stack: [..., SetDirMenu, SetPreview, SpellingTest, Results]
                    stackView.pop(stackView.get(stackView.depth - 3))
                }
            }
        }

        Loader {
            id: creatingRecSetConnectionLoader
            active: stackView.currentItem &&
                    typeof stackView.currentItem.creatingRecSetCancel === "function"
            sourceComponent: creatingRecSetConnectionComponent
        }

        Component {
            id: creatingRecSetConnectionComponent
            Connections {
                target: stackView.currentItem

                function onCreatingRecSetCancel() {
                    rootScope.creatingPageRef = null
                    stackView.pop()
                }

                function onRequestCameraCapture(cardIndex) {
                    rootScope.creatingPageRef = stackView.currentItem
                    stackView.push(cameraCaptureMenu)
                    stackView.currentItem.targetCardIndex = cardIndex
                }

                function onCreatingRecSetSave() {
                    var recSetName    = stackView.currentItem.recSetName
                    var recSetIdx     = stackView.currentItem.recSetIdx
                    var recFolderPath = stackView.currentItem.folderPath
                    var modelRef      = stackView.currentItem.recSetModelRef
                    var mgr           = AppController.recSetManager

                    if (recSetName === "") return

                    if (recSetIdx === -1) {
                        // Names only need to be unique within their own folder.
                        recSetIdx = mgr.createRecSet(recSetName, recFolderPath)
                        if (recSetIdx === -1) {
                            stackView.currentItem.titleErrorMessage =
                                qsTr("A library or set with this name already exists here.")
                            stackView.currentItem.titleError = true
                            return
                        }
                    } else {
                        if (!mgr.renameRecSet(recSetIdx, recSetName)) {
                            stackView.currentItem.titleErrorMessage =
                                qsTr("A library or set with this name already exists here.")
                            stackView.currentItem.titleError = true
                            return
                        }
                        mgr.clearRecordsFromRecSetAt(recSetIdx)
                    }

                    for (var i = 0; i < modelRef.count; ++i) {
                        var rec = modelRef.get(i)
                        if (rec.expression === null || rec.expression.trim() === "") continue
                        var hintSet    = rec.hint         != null && rec.hint.trim()         !== ""
                        var audioSet   = rec.audioPath    != null && rec.audioPath.trim()    !== ""
                        var imageSet   = rec.imagePath    != null && rec.imagePath.trim()    !== ""
                        var exampleSet = rec.exampleUsage != null && rec.exampleUsage.trim() !== ""
                        if (!hintSet && !audioSet && !imageSet && !exampleSet) continue
                        var wordData = {
                            languageFrom: rec.languageFrom,
                            languageTo:   rec.languageTo,
                            expression:   rec.expression,
                            hint:         rec.hint,
                            audioPath:    rec.audioPath,
                            imagePath:    rec.imagePath,
                            exampleUsage: rec.exampleUsage
                        }
                        mgr.addRecToRecSetAt(recSetIdx, wordData)
                    }

                    AppController.saveData()
                    AppController.recSetNameListChanged()
                    stackView.pop()
                }
            }
        }

        Loader {
            id: creatingRuleSetConnectionLoader
            active: stackView.currentItem &&
                    typeof stackView.currentItem.creatingRuleSetCancel === "function"
            sourceComponent: creatingRuleSetConnectionComponent
        }

        Component {
            id: creatingRuleSetConnectionComponent
            Connections {
                target: stackView.currentItem

                function onCreatingRuleSetCancel() {
                    stackView.pop()
                }

                function onCreatingRuleSetSave() {
                    var setName      = stackView.currentItem.ruleSetName
                    var setIdx       = stackView.currentItem.ruleSetIdx
                    var setFolder    = stackView.currentItem.folderPath
                    var blocksModelRef = stackView.currentItem.theoryBlocksModelRef
                    var modelRef     = stackView.currentItem.ruleSetModelRef
                    var mgr          = AppController.ruleSetManager

                    if (setName === "") return

                    if (setIdx === -1) {
                        setIdx = mgr.createRuleSet(setName, setFolder)
                        if (setIdx === -1) {
                            stackView.currentItem.titleErrorMessage =
                                qsTr("A library or set with this name already exists here.")
                            stackView.currentItem.titleError = true
                            return
                        }
                    } else {
                        if (!mgr.renameRuleSet(setIdx, setName)) {
                            stackView.currentItem.titleErrorMessage =
                                qsTr("A library or set with this name already exists here.")
                            stackView.currentItem.titleError = true
                            return
                        }
                        mgr.clearQuestionsAt(setIdx)
                    }

                    // Blank text blocks (e.g. a leftover "+ Text" the creator
                    // never filled in) are dropped rather than persisted.
                    var blocks = []
                    for (var bi = 0; bi < blocksModelRef.count; ++bi) {
                        var b = blocksModelRef.get(bi)
                        if (b.kind === "text" && (b.value || "").trim() === "") continue
                        blocks.push({ kind: b.kind, value: b.value, imgHeight: b.imgHeight || 0 })
                    }
                    mgr.setTheoryAt(setIdx, { blocks: blocks })

                    for (var i = 0; i < modelRef.count; ++i) {
                        var q = modelRef.get(i)
                        if (q.questionText === null || q.questionText.trim() === "") continue
                        if (q.questionType === "mc") {
                            var options = rootScope.splitEscaped(q.mcOptionsText || "", ",")
                                .map(function(a) { return a.trim() })
                                .filter(function(a) { return a !== "" })
                            if (options.length < 2) continue
                            var correctIndices = (q.mcCorrectIndicesText || "").split(",")
                                .map(function(s) { return s.trim() })
                                .filter(function(s) { return s !== "" })
                                .map(function(s) { return parseInt(s, 10) })
                                .filter(function(idx) { return idx >= 0 && idx < options.length })
                            if (correctIndices.length === 0) correctIndices = [0]
                            // Defensive clamp — the chip UI itself already
                            // keeps this to one entry in single-answer mode.
                            if (q.mcSingleAnswer && correctIndices.length > 1) correctIndices = [correctIndices[0]]
                            mgr.addQuestionToSetAt(setIdx, {
                                id: q.id, type: "mc", text: q.questionText,
                                options: options, correctIndices: correctIndices,
                                singleAnswer: q.mcSingleAnswer === true
                            })
                        } else if (q.questionType === "combobox") {
                            // "::" separates one blank's option group from
                            // the next, "," separates choices within a
                            // group — see CreatingRuleSet.qml's Options hint.
                            var optionsPerGap = rootScope.splitEscaped(q.poolOptionsText || "", "::")
                                .map(function(group) {
                                    return rootScope.splitEscaped(group, ",")
                                        .map(function(a) { return a.trim() })
                                        .filter(function(a) { return a !== "" })
                                        .map(rootScope.decodeBlankMarker)
                                })
                                .filter(function(group) { return group.length > 0 })
                            if (optionsPerGap.length === 0) continue
                            // The answer for each blank is whichever chip
                            // was tapped in that blank's group (see
                            // CreatingRuleSet.qml's comboCorrectIndicesText),
                            // not typed text — every blank must have a valid
                            // tapped choice, or the question can't be saved.
                            var comboCorrectIdx = (q.comboCorrectIndicesText || "").split(",")
                                .map(function(s) { return s.trim() === "" ? -1 : parseInt(s.trim(), 10) })
                            var comboAnswers = []
                            var comboValid = true
                            for (var gIdx = 0; gIdx < optionsPerGap.length; ++gIdx) {
                                var ci = gIdx < comboCorrectIdx.length ? comboCorrectIdx[gIdx] : -1
                                if (ci < 0 || ci >= optionsPerGap[gIdx].length) { comboValid = false; break }
                                comboAnswers.push(optionsPerGap[gIdx][ci])
                            }
                            if (!comboValid) continue
                            mgr.addQuestionToSetAt(setIdx, {
                                id: q.id, type: "combobox", text: q.questionText,
                                answers: comboAnswers, optionsPerGap: optionsPerGap
                            })
                        } else if (q.questionType === "dragdrop") {
                            var pool = rootScope.splitEscaped(q.poolOptionsText || "", ",")
                                .map(function(a) { return a.trim() })
                                .filter(function(a) { return a !== "" })
                                .map(rootScope.decodeBlankMarker)
                            var ddGapCount = (q.questionText || "").split("___").length - 1
                            if (pool.length === 0 || ddGapCount === 0) continue
                            // The answer for each blank is whichever tile was
                            // dragged/tapped into it (see CreatingRuleSet.qml's
                            // "Fill in the blanks" section), not typed text —
                            // every blank must have a tile placed, or the
                            // question can't be saved.
                            var ddPlacements = (q.ddPlacementsText || "").split(",")
                                .map(function(s) { return s.trim() === "" ? -1 : parseInt(s.trim(), 10) })
                            var ddAnswers = []
                            var ddValid = true
                            for (var ddGap = 0; ddGap < ddGapCount; ++ddGap) {
                                var ddIdx = ddGap < ddPlacements.length ? ddPlacements[ddGap] : -1
                                if (ddIdx < 0 || ddIdx >= pool.length) { ddValid = false; break }
                                ddAnswers.push(pool[ddIdx])
                            }
                            if (!ddValid) continue
                            mgr.addQuestionToSetAt(setIdx, {
                                id: q.id, type: "dragdrop", text: q.questionText,
                                answers: ddAnswers, options: pool
                            })
                        } else {
                            var answers = rootScope.splitEscaped(q.answersText || "", ",")
                                .map(function(a) { return a.trim() })
                                .filter(function(a) { return a !== "" })
                            mgr.addQuestionToSetAt(setIdx, { id: q.id, type: "gap", text: q.questionText, answers: answers })
                        }
                    }

                    AppController.saveData()
                    AppController.recSetNameListChanged()
                    stackView.pop()
                }
            }
        }

        Loader {
            active: stackView.currentItem && typeof stackView.currentItem.aboutRequested === "function"
            sourceComponent: Component {
                Connections {
                    target: stackView.currentItem
                    function onAboutRequested() { stackView.push(aboutPage) }
                }
            }
        }

        Loader {
            active: stackView.currentItem && typeof stackView.currentItem.licenseRequested === "function"
            sourceComponent: Component {
                Connections {
                    target: stackView.currentItem
                    function onLicenseRequested(title, url) {
                        stackView.push(licenseTextPage, { pageTitle: title, licenseUrl: url })
                    }
                }
            }
        }

        // Handles the app being opened (cold start) or brought back to the
        // foreground (already running) by tapping a .ppset file — Android
        // delivers a warm resume via onNewIntent() rather than a fresh
        // Component.onCompleted, so this needs checking on both, not just
        // cold start (that gap meant a .ppset opened while the app was
        // already alive in memory silently did nothing until the app was
        // eventually killed and relaunched fresh). checkIncomingFile()
        // itself is async — see incomingFileReady/incomingFileFailed below
        // — since reading a shared file can block on the sending app.
        Component.onCompleted: ShareHelper.checkIncomingFile()

        // Belt-and-suspenders on top of the belt-and-suspenders below: two
        // different event-driven ways of noticing "a new intent might be
        // waiting" (onNewIntentReceived, Qt.application.onStateChanged)
        // have each individually failed to fire reliably in the field, for
        // reasons not fully pinned down without device logs. This doesn't
        // depend on any lifecycle callback at all — both checks are cheap,
        // safe to call redundantly, and no-ops when nothing is pending — so
        // worst case this guarantees detection within ~1.5s regardless of
        // whatever the deeper issue turns out to be.
        Timer {
            interval: 1500
            running: true
            repeat: true
            onTriggered: {
                GoogleSignInHelper.checkForPendingRedirect()
                ShareHelper.checkIncomingFile()
            }
        }

        Connections {
            target: ShareHelper
            function onIncomingFileReady(localPath) {
                // Each fresh tap of a shared file is a new intent, so
                // without this, re-opening (the same or another) file while
                // an earlier import page is still on the stack piles up a
                // duplicate page on top of it instead of replacing it.
                // Return to the root first, same as any normal "open with" flow.
                stackView.pop(null)
                // A rule-set .ppset's manifest carries "kind":"ruleset" (see
                // RuleSetManager::exportSetToZip); a word-set one has no
                // "kind" at all. Checked up front so this routes to the
                // right creation page instead of always assuming word set —
                // opening a grammar .ppset through the wrong importer just
                // silently produced an empty word set sharing its name.
                if (AppController.ruleSetManager.isRuleSetZip(localPath)) {
                    var rulePage = stackView.push(creatingRuleSetMenu)
                    Qt.callLater(function() { rootScope.importRuleSetFromPath(rulePage, localPath) })
                } else {
                    var wordPage = stackView.push(creatingRecSetMenu)
                    Qt.callLater(function() { wordPage.importFromPath(localPath) })
                }
            }
            function onIncomingFileFailed(error) {
                console.warn("Couldn't open shared file:", error)
                rootScope.shareErrorMessage = error
                shareErrorClearTimer.restart()
            }
        }

        // The reliable path: Android calls Activity.onNewIntent()
        // unconditionally whenever a new Intent reaches this already-running
        // app (see AppLifecycleBridge's doc comment for why the
        // Qt.application.state-based Connections block below turned out to
        // miss some of these).
        Connections {
            target: AppLifecycleBridge
            function onNewIntentReceived() {
                GoogleSignInHelper.checkForPendingRedirect()
                ShareHelper.checkIncomingFile()
            }
        }

        Connections {
            target: Qt.application
            function onAboutToQuit() {
                // Persist any in-progress test state when the app is closed
                if (typeof stackView.currentItem !== "undefined" &&
                    typeof stackView.currentItem.getResults === "function" &&
                    !spellingTestController.isTestComplete()) {
                    spellingTestController.saveProgress()
                }
            }
            // Belt-and-suspenders fallback alongside AppLifecycleBridge
            // above, in case some resume path doesn't go through
            // onNewIntent() — both checks are safe to call redundantly.
            function onStateChanged() {
                if (Qt.application.state === Qt.ApplicationActive) {
                    GoogleSignInHelper.checkForPendingRedirect()
                    ShareHelper.checkIncomingFile()
                }
            }
        }

        Timer {
            id: shareErrorClearTimer
            interval: 5000
            onTriggered: rootScope.shareErrorMessage = ""
        }

        // Brief top banner for ShareHelper.incomingFileFailed — previously
        // only logged to console.warn, so a failed shared-file read (e.g. a
        // sending app's content:// provider rejecting the read) looked
        // exactly like nothing happening at all, with no way to tell
        // detection-failed from read-failed.
        Rectangle {
            id: shareErrorBanner
            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: SafeArea.margins.top }
            height: rootScope.shareErrorMessage !== "" ? shareErrorLabel.implicitHeight + 20 : 0
            visible: height > 0
            clip: true
            color: "#e74c3c"
            z: 200

            Behavior on height { NumberAnimation { duration: 150 } }

            Label {
                id: shareErrorLabel
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 }
                text: "⚠ " + rootScope.shareErrorMessage
                color: "white"
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }
    }
}
