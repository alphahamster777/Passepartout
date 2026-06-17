import QtQuick
import QtQuick.Controls
import QtQuick.Window

import AppController
import SetPreviewMenuController
import SpellingTestController
import RecSetManager

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
                    stackView.pop()
                } else {
                    Qt.quit()
                }
                event.accepted = true
            }
        }

        SpellingTestController {
            id: spellingTestController
        }

        SetPreviewMenuController {
            id: setPreviewController
        }

        StackView {
            id: stackView
            anchors.fill: parent
            initialItem: setDirMenu
        }

        Component { id: setDirMenu;         SetDirMenu {}       }
        Component { id: creatingRecSetMenu; CreatingRecSet {}   }
        Component { id: setPreviewMenu;     SetPreviewMenu {}   }
        Component { id: spellingTestPage;   SpellingTest {}     }
        Component { id: resultsPage;        Results {}          }

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
                    spellingTestController.initialize(AppController.recSetManager, num)
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
                function onNavigateToTest() {
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

        Component {
            id: resultsConnectionComponent
            Connections {
                target: stackView.currentItem
                function onResultsNextPressed() {
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
                    stackView.pop()
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
    }
}
