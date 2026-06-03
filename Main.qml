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

    // Make the window’s content a FocusScope:
    FocusScope {
        id: rootScope
        anchors.fill: parent
        focus: true

        Keys.onReleased: function(event){
            if (event.key === Qt.Key_Back
                    || event.key === Qt.Key_Backspace) {
                if (stackView.depth > 1) {
                    stackView.pop()
                } else {
                    // no more pages to pop → default behavior
                    Qt.quit()
                }

                event.accepted = true
            }
        }

        SpellingTestController {
            id: spellingTestController
            // Component.onCompleted: initialize(appController.recSetManager)
        }

        SetPreviewMenuController {
            id: setPreviewController
            // Component.onCompleted: initialize(appController.recSetManager)
        }

        StackView {
            id: stackView
            anchors.fill: parent
            initialItem: setDirMenu
            visible: true
        }

        Component {
            id: setDirMenu
            SetDirMenu{
            }
        }

        Component {
            id: creatingRecSetMenu
            CreatingRecSet{
            }
        }

        Component {
            id: setPreviewMenu
            SetPreviewMenu{
            }
        }

        Component {
            id: spellingTestPage
            SpellingTest {
            }
        }

        Component {
            id: resultsPage
            Results {
            }
        }

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
                function onRecSetSelected(num: int){
                    stackView.pop()
                    setPreviewController.initialize(AppController.recSetManager, num)
                    spellingTestController.initialize(AppController.recSetManager, num)
                    stackView.push(setPreviewMenu)
                }
                function onAddRecSet() {
                    stackView.push(creatingRecSetMenu)
                }
                function onEditRecSet(num: int){
                    stackView.push(creatingRecSetMenu)
                    var recSetManagerRef = AppController.recSetManager
                    var recSetInfo = recSetManagerRef.getRecSetInfoQML(num)
                    stackView.currentItem.recSetName = recSetInfo.name
                    stackView.currentItem.recSetIdx = num
                    var recSetModelRef = stackView.currentItem.recSetModelRef
                    recSetModelRef.clear()
                    for (var i = 0; i < recSetInfo.wordCount; ++i) {
                        var rec = recSetManagerRef.getWordFromRecSetQML(num, i)
                        recSetModelRef.append({
                            languageFrom: rec.exprLangID,
                            languageTo:   rec.hintLangID,
                            expression:   rec.expression,
                            hint:         rec.hint,
                            context:      rec.context,
                            audioPath:    rec.audioPath,
                            imagePath:    rec.imagePath
                        })
                    }
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
                    stackView.pop();
                    stackView.push(resultsPage);
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
            active: stackView.currentItem && typeof stackView.currentItem.creatingRecSetCancel === "function" || typeof stackView.currentItem.creatingRecSetCancel === "function"
            sourceComponent: creatingRecSetConnectionComponent
        }

        Component {
            id: creatingRecSetConnectionComponent
            Connections {
                target: stackView.currentItem
                function onCreatingRecSetCancel(){
                    stackView.pop();
                }

                function onCreatingRecSetSave() {
                    var recSetName = stackView.currentItem.recSetName
                    var recSetIdx  = stackView.currentItem.recSetIdx
                    var recSetModelRef = stackView.currentItem.recSetModelRef
                    var recSetManagerRef = AppController.recSetManager

                    if (recSetName === "")
                        return

                    if (recSetIdx === -1) {
                        // Creating a new set
                        recSetManagerRef.createRecSet(recSetName)
                    } else {
                        // Editing existing set: clear old words, then rename
                        var oldInfo = recSetManagerRef.getRecSetInfoQML(recSetIdx)
                        recSetManagerRef.clearRecordsFromRecSet(oldInfo.name)
                        recSetManagerRef.renameRecSet(recSetIdx, recSetName)
                    }

                    for (var i = 0; i < recSetModelRef.count; ++i) {
                        var rec = recSetModelRef.get(i)
                        if (rec.expression === null || rec.expression.trim() === "")
                            continue
                        var hintPreset  = rec.hint      != null && rec.hint.trim()      !== ""
                        var audioPreset = rec.audioPath != null && rec.audioPath.trim() !== ""
                        var imagePreset = rec.imagePath != null && rec.imagePath.trim() !== ""
                        if (!hintPreset && !audioPreset && !imagePreset)
                            continue
                        recSetManagerRef.addRecToRecSet(recSetName, rec)
                    }

                    AppController.recSetNameListChanged()
                    stackView.pop()
                }


            }
        }
    }
}

