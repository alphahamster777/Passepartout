#include "spellingTestController.h"
#include "dictRec.h"
#include <iostream>

SpellingTestController::SpellingTestController(QObject* parent) : QObject(parent), m_recSetManager(nullptr) {
    // m_recSetManager.createRecSet("Default Set");
    // m_recSetManager.addRecToRecSet("Default Set", DictRec(2, 1, "der Fahrrad", "bicycle", "audio.mp3", "qrc:/images/bicycle.jpg"));
    // m_recSetManager.addRecToRecSet("Default Set", DictRec(2, 1, "die Käse", "cheese", "audio.mp3", "qrc:/images/cheese.jpg"));
    // m_recSetManager.addRecToRecSet("Default Set", DictRec(1, 2, "opportunity", "Möglichkeit", "audio.mp3", "qrc:/images/default_logo.jpg"));

}

void SpellingTestController::initialize(QObject *manager, int idx) {

    auto m = qobject_cast<RecSetManager*>(manager);
    if (!m) {
        qWarning() << "initialize(): not a RecSetManager*";
        return;
    }
    m_recSetManager = m;

    // Additional initialization as needed.
    currentDictRecNum = 0;
    try {
        currentRecSetNum = idx;
        currentDictRecNum = 0;
        auto element = m_recSetManager->getAllRecSets().at(idx).getWordAt(currentDictRecNum++);
        m_totalQuestions = m_recSetManager->getAllRecSets().at(idx).getWordCount();
        m_correctAnswers = 0;
        m_currentWord = element.getExpression();
        m_currentHint = element.getHint();
        m_currentAudioUrl = element.getAudioPath();
        m_currentImageUrl = element.getImagePath();
        // emit currentAnswersChanged();
        emit currentWordChanged();
        emit currentHintChanged();
        emit currentAudioUrlChanged();
        emit currentImageUrlChanged();
        emit totalQuestionsChanged();
    } catch (const std::out_of_range& e) {
        std::cout << "Out of Range error. " << e.what();
    }
}

void SpellingTestController::nextQuestion() {
    try {
        auto element = m_recSetManager->getAllRecSets().at(currentRecSetNum).getWordAt(currentDictRecNum++);

        m_currentWord = element.getExpression();
        m_currentHint = element.getHint();
        m_currentAudioUrl = element.getAudioPath();
        m_currentImageUrl = element.getImagePath();
        emit currentWordChanged();
        emit currentHintChanged();
        emit currentAudioUrlChanged();
        emit currentImageUrlChanged();
    } catch (const std::out_of_range& e) {
        std::cout << "Out of Range error. " << e.what();

    }
}
