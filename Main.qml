import QtQuick
import QtQuick.Controls
import AppController
import SetPreviewMenuController
import SpellingTestController

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 360
    height: 640
    title: "Passepartout"

    AppController{
        id:appController
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
        id: setPreviewMenu
        SetPreviewMenu{
        }
    }

    Component {
        id: spellingTestPage
        SpellingTest {
            // Pass any required properties to SpellingTest here, if needed
        }
    }

    Component {
        id: resultsPage
        Results {
            // Pass any required properties to SpellingTest here, if needed
        }
    }

///////////////////////////////connections/////////////////////////////////////////
    Loader {
        id: setDirConnectionLoader
        active: stackView.currentItem && typeof stackView.currentItem.recSetSelected === "function"
        sourceComponent: setDirConnectionComponent
    }

    Component {
        id: setDirConnectionComponent
        Connections {
            target: stackView.currentItem
            function onRecSetSelected(num: int){
                stackView.pop()
                setPreviewController.initialize(appController.recSetManager, num)
                spellingTestController.initialize(appController.recSetManager, num)
                stackView.push(setPreviewMenu)
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
        id: resultConnectionLoader
        active: stackView.currentItem && typeof stackView.currentItem.resultsNextPressed === "function"
        sourceComponent: resultConnectionComponent
    }

    Component {
        id: resultConnectionComponent
        Connections {
            target: stackView.currentItem
            function onResultsNextPressed() {
                stackView.pop(stackView.get(stackView.depth - 3))
            }
        }
    }
}

