#include "spellingTestController.h"
#include "dictRec.h"
#include <iostream>

SpellingTestController::SpellingTestController(QObject* parent) : QObject(parent), m_recSetManager(nullptr) {
    // m_recSetManager.createRecSet("Default Set");
    // m_recSetManager.addRecToRecSet("Default Set", DictRec(2, 1, "der Fahrrad", "bicycle", "audio.mp3", "qrc:/images/bicycle.jpg"));
    // m_recSetManager.addRecToRecSet("Default Set", DictRec(2, 1, "die Käse", "cheese", "audio.mp3", "qrc:/images/cheese.jpg"));
    // m_recSetManager.addRecToRecSet("Default Set", DictRec(1, 2, "opportunity", "Möglichkeit", "audio.mp3", "qrc:/images/default_logo.jpg"));

}

void SpellingTestController::initialize(RecSetManager *manager) {
    m_recSetManager = manager;
    // Additional initialization as needed.
    currentRecSetNum = 0;
    currentDictRecNum = 0;
    try {
        auto element = m_recSetManager->getAllRecSets().at(currentRecSetNum).getWordAt(currentDictRecNum++);

        m_currentWord = QString::fromStdString(element.getExpression());
        m_currentHint = QString::fromStdString(element.getHint());
        m_audioUrl = QString::fromStdString(element.getAudioPath().value_or(""));
        m_imageUrl = QString::fromStdString(element.getImagePath().value_or(""));
        emit currentWordChanged();
        emit currentHintChanged();
        emit audioUrlChanged();
        emit imageUrlChanged();
    } catch (const std::out_of_range& e) {
        std::cout << "Out of Range error. " << e.what();
    }
    m_totalQuestions = m_recSetManager->getAllRecSets().at(0).getWordCount();
}

void SpellingTestController::nextQuestion() {
    try {
        auto element = m_recSetManager->getAllRecSets().at(currentRecSetNum).getWordAt(currentDictRecNum++);

        m_currentWord = QString::fromStdString(element.getExpression());
        m_currentHint = QString::fromStdString(element.getHint());
        m_audioUrl = QString::fromStdString(element.getAudioPath().value_or(""));
        m_imageUrl = QString::fromStdString(element.getImagePath().value_or(""));
        emit currentWordChanged();
        emit currentHintChanged();
        emit audioUrlChanged();
        emit imageUrlChanged();
    } catch (const std::out_of_range& e) {
        std::cout << "Out of Range error. " << e.what();

    }
}
