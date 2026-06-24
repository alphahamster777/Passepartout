import QtQuick
import QtQuick.Controls
import QtQuick.Window

import AppController
import SetPreviewMenuController
import SpellingTestController
import LeitnerTestController
import RecSetManager
import ShareHelper

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 360
    height: 640
    title: "Passepartout"

    FocusScope {
        id: rootScope
        anchors.fill: parent
        focus: true

        Keys.onReleased: function(event) {
            const androidBackPressed =
                Qt.platform.os === "android" && event.key === Qt.Key_Back

            const desktopLeftPressed =
                Qt.platform.os !== "android" && event.key === Qt.Key_Left

            if (androidBackPressed || desktopLeftPressed) {
                if (stackView.depth > 1) {
                    // Save test progress when leaving the spelling test mid-run
                    if (typeof stackView.currentItem.getResults === "function" &&
                        !spellingTestController.isTestComplete()) {
                        spellingTestController.saveProgress()
                    }
                    stackView.pop()
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

        // Saved reference to the CreatingRecSet page so the camera result can update it
        property var creatingPageRef: null

        Component { id: setDirMenu;         SetDirMenu {}       }
        Component { id: creatingRecSetMenu; CreatingRecSet {}   }
        Component { id: setPreviewMenu;     SetPreviewMenu {}   }
        Component { id: spellingTestPage;   SpellingTest {}     }
        Component { id: resultsPage;        Results {}          }
        Component { id: cameraCaptureMenu;  CameraCapture {}    }

        ///////////////////////////////connections/////////////////////////////////////////

        Loader {
            id: setDirMenuConnectionLoader
            active: stackView.currentItem &&
                    typeof stackView.currentItem.recSetSelected === "function" &&
                    typeof stackView.currentItem.addRecSet === "function" &&
                    typeof stackView.currentItem.editRecSet === "function"
            sourceComponent: setDirMenuConnectionComponent
        }

        Component {
            id: setDirMenuConnectionComponent
            Connections {
                target: stackView.currentItem
                function onRecSetSelected(num: int) {
                    stackView.pop()
                    setPreviewController.initialize(AppController.recSetManager, num)
                    stackView.push(setPreviewMenu)
                }
                function onAddRecSet() {
                    stackView.push(creatingRecSetMenu)
                }
                function onEditRecSet(num: int) {
                    stackView.push(creatingRecSetMenu)
                    var mgr = AppController.recSetManager
                    var info = mgr.getRecSetInfoQML(num)
                    stackView.currentItem.recSetName = info.name
                    stackView.currentItem.recSetIdx  = num
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
                            imagePath:    rec.imagePath
                        })
                    }
                    stackView.currentItem.selectedCardIndex = info.wordCount > 0 ? info.wordCount - 1 : 0
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
                        (testType === SpellingTestController.TypeE_Leitner)
                            ? leitnerTestController
                            : regularTestController
                    rootScope.spellingTestController.initialize(
                        AppController.recSetManager,
                        setPreviewController.currentSetIndex,
                        testType)
                    stackView.push(spellingTestPage)
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
                    // // Clear the completed-run flag so the next launch starts fresh
                    // rootScope.spellingTestController.resetTestProgress(
                    //     AppController.recSetManager,
                    //     setPreviewController.currentSetIndex,
                    //     rootScope.spellingTestController.testType)
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
                    var recSetName   = stackView.currentItem.recSetName
                    var recSetIdx    = stackView.currentItem.recSetIdx
                    var modelRef     = stackView.currentItem.recSetModelRef
                    var mgr          = AppController.recSetManager

                    if (recSetName === "") return

                    if (recSetIdx === -1) {
                        mgr.createRecSet(recSetName)
                    } else {
                        var oldInfo = mgr.getRecSetInfoQML(recSetIdx)
                        mgr.clearRecordsFromRecSet(oldInfo.name)
                        mgr.renameRecSet(recSetIdx, recSetName)
                    }

                    for (var i = 0; i < modelRef.count; ++i) {
                        var rec = modelRef.get(i)
                        if (rec.expression === null || rec.expression.trim() === "") continue
                        var hintSet  = rec.hint      != null && rec.hint.trim()      !== ""
                        var audioSet = rec.audioPath != null && rec.audioPath.trim() !== ""
                        var imageSet = rec.imagePath != null && rec.imagePath.trim() !== ""
                        if (!hintSet && !audioSet && !imageSet) continue
                        var wordData = {
                            languageFrom: rec.languageFrom,
                            languageTo:   rec.languageTo,
                            expression:   rec.expression,
                            hint:         rec.hint,
                            audioPath:    rec.audioPath,
                            imagePath:    rec.imagePath
                        }
                        mgr.addRecToRecSet(recSetName, wordData)
                    }

                    AppController.saveData()
                    AppController.recSetNameListChanged()
                    stackView.pop()
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
        }
    }
}
