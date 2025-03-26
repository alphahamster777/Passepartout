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

    Connections {
        target: setPreviewController
        function onNavigateToTest (){ stackView.push(spellingTestPage)}
    }

    Connections {
        target: stackView.currentItem
        function onGetResults() {
            stackView.pop()
            stackView.push(resultsPage)
        }
    }

    Connections {
        target:  stackView.currentItem
        function onResultsNextPressed (){
            stackView.pop()
            stackView.pop()//more beautiful solution should be realized
        }
    }

    Connections {
        target:  stackView.currentItem
        function onRecSetSelected(num: int){
            stackView.pop()
            setPreviewController.initialize(appController.recSetManager, num)
            spellingTestController.initialize(appController.recSetManager, num)
            stackView.push(setPreviewMenu)
        }
    }
}

