#include "setPreviewMenuController.h"

SetPreviewMenuController::SetPreviewMenuController(QObject* parent)
    : QObject(parent), m_recSetManager(nullptr) {
    // Populate the expression list from RecSetManager

}

void SetPreviewMenuController::initialize(QObject *manager, int idx) {
    auto m = qobject_cast<RecSetManager*>(manager);
    if (!m) {
        qWarning() << "initialize(): not a RecSetManager*";
        return;
    }
    // m_recSetManager = m;
    m_expressionList.clear();
    m_recSetManager = m;
    m_currentSetIndex = idx;
    emit currentSetIndexChanged();
    auto recSet = m_recSetManager->getAllRecSets().at(idx);
    for (const auto& word : recSet) {
        QVariantMap expressionData;
        expressionData["expression"]   = word.getExpression();
        expressionData["hint"]         = word.getHint();
        expressionData["imagePath"]    = word.getImagePath();
        expressionData["audioPath"]    = word.getAudioPath();
        expressionData["exprLangID"]   = word.getExprLanguageID();
        expressionData["exampleUsage"] = word.getExampleUsage();
        m_expressionList.append(expressionData);
    }
    emit expressionListChanged();
}

QList<QVariant> SetPreviewMenuController::getExpressionList() const {
    return m_expressionList;
}

// void SetPreviewMenuController::startTests() {
//     // Logic to initialize tests can go here
//     emit navigateToTest(); // Trigger navigation signal
// }
