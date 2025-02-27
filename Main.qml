import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 360
    height: 640
    title: "Passepartout"

    // color: "red"

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: setPreviewMenu

        visible: true

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
            // tackView.push(setPreviewPage)////kher
        }
    }
}

