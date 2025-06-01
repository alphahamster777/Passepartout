import QtQuick
import QtQuick.Controls
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
        active: stackView.currentItem && typeof stackView.currentItem.recSetSelected === "function" && typeof stackView.currentItem.addRecSet === "function"
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
                var recSetName =  stackView.currentItem.recSetName.text

                if(recSetName === "") {
                    return;
                }

                var recSetModelRef = stackView.currentItem.recSetModelRef

                var recSetManagerRef = AppController.recSetManager

                for (var i = 0; i < recSetModelRef.count; ++i) {
                    var rec = recSetModelRef.get(i)
                    if(rec.expression === null || rec.expression.trim() === "" ){
                        continue
                    }

                    var hintPreset = rec.hint != null && rec.hint.trim() != ""
                    var audioPreset = rec.audioPath != null && rec.audioPath.trim() != ""
                    var imagePreset = rec.imagePath != null && rec.imagePath.trim() != ""


                    if(!hintPreset && !audioPreset && !imagePreset){
                        continue
                    }

                    // console.log("hintPreset = ", hintPreset, "audioPreset = ", audioPreset, "imagePreset = ", imagePreset)

                    recSetManagerRef.addRecToRecSet(recSetName, rec)
                }
                AppController.recSetNameListChanged()
                stackView.pop();
            }


        }
    }
}

