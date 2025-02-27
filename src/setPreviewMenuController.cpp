#include "setPreviewMenuController.h"

SetPreviewMenuController::SetPreviewMenuController(RecSetManager* manager, QObject* parent)
    : QObject(parent), m_recSetManager(manager) {
    // Populate the expression list from RecSetManager
    auto recSets = m_recSetManager->getAllRecSets();
    for (const auto& recSet : recSets) {
        for (const auto& word : recSet) {
            QVariantMap expressionData;
            expressionData["expression"] = QString::fromStdString(word.getExpression());
            expressionData["hint"] = QString::fromStdString(word.getHint());
            expressionData["imagePath"] = QString::fromStdString(word.getImagePath().value_or(""));
            expressionData["audioPath"] = QString::fromStdString(word.getAudioPath().value_or(""));
            m_expressionList.append(expressionData);
        }
    }
    emit expressionListChanged();
}

QList<QVariant> SetPreviewMenuController::getExpressionList() const {
    return m_expressionList;
}

void SetPreviewMenuController::startTests() {
    // Logic to initialize tests can go here
    emit navigateToTest(); // Trigger navigation signal
}
