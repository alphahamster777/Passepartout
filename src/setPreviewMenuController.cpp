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
    auto recSet = m_recSetManager->getAllRecSets().at(idx);
    for (const auto& word : recSet) {
        QVariantMap expressionData;
        expressionData["expression"] = QString::fromStdString(word.getExpression());
        expressionData["hint"] = QString::fromStdString(word.getHint());
        expressionData["imagePath"] = QString::fromStdString(word.getImagePath().value_or(""));
        expressionData["audioPath"] = QString::fromStdString(word.getAudioPath().value_or(""));
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
