import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

import AppController
import SetPreviewMenuController
import SpellingTestController
import LeitnerTestController
import FlashCardController
import RecSetManager
import ShareHelper
import GoogleSignInHelper
import FirebaseAiHelper

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

        // Active controller — switches to leitnerTestController for TypeE_Leitner,
        // stays on regularTestController for all other test types.
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

        // If the app was opened by tapping a .ppset file, import it immediately.
        Component.onCompleted: {
            var incoming = ShareHelper.incomingFilePath()
            if (incoming === "") return
            var page = stackView.push(creatingRecSetMenu)
            Qt.callLater(function() { page.importFromPath(incoming) })
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
            // Google's consent screen hands control back to this already-
            // running app via a new Intent, but nothing pushes that into QML
            // (see GoogleSignInHelper::checkForPendingRedirect's comment) —
            // so poll for it every time the app becomes active again.
            function onStateChanged() {
                if (Qt.application.state === Qt.ApplicationActive)
                    GoogleSignInHelper.checkForPendingRedirect()
            }
        }
    }
}
