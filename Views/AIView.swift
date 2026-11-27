import SwiftUI
import UIKit
import Foundation

struct AIView: View {
    @AppStorage(AIPrivacySettings.consentKey) private var aiConsentGranted = false
    @State private var text: String = ""
    @State private var natural: String = ""
    @State private var pinyin: String = ""
    @State private var keywords: [String] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var errorKind: AIErrorKind = .generic
    @State private var isCNMode = true
    /// Direction of the request that produced the current result.
    @State private var resultIsCNMode = true
    @State private var copiedNatural = false
    @State private var dictionaryHits: [AIDictionaryHit] = []
    @State private var isShowingAIConsent = false
    @State private var isShowingPrivacy = false

    private var hasResult: Bool {
        !natural.isEmpty || !pinyin.isEmpty || !keywords.isEmpty || !dictionaryHits.isEmpty
    }

    private var characterCount: Int { text.unicodeScalars.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        InkScreenHeader(label: "翻译") {
                            InkInfoButton { isShowingPrivacy = true }
                        }
                        InkLargeTitle(text: "ИИ-перевод")
                            .padding(.top, 2)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { hideKeyboard() }

                    // MODE SWITCH
                    modePicker
                        .padding(.top, 14)

                    // INPUT
                    inputCard
                        .padding(.top, 14)

                    // BUTTON
                    translateButton
                        .padding(.top, 12)

                    // STATES
                    stateSection
                        .padding(.top, 14)
                        .contentShape(Rectangle())
                        .onTapGesture { hideKeyboard() }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Ink.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationTitle("ИИ-перевод")
            .sheet(isPresented: $isShowingAIConsent) {
                consentSheet
            }
            .sheet(isPresented: $isShowingPrivacy) {
                NavigationStack { PrivacyDisclosureView() }
            }
        }
    }

    // MARK: - Mode, input and button

    private var modePicker: some View {
        HStack(spacing: 4) {
            modeButton(title: "中文 → Русский", isCN: true)
            modeButton(title: "Русский → 中文", isCN: false)
        }
        .padding(4)
        .background(Capsule().fill(Ink.segment))
        .disabled(isLoading)
    }

    private func modeButton(title: String, isCN: Bool) -> some View {
        let isSelected = isCNMode == isCN
        return Button {
            isCNMode = isCN
        } label: {
            Text(title)
                .font(InkFont.serif(14, isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Ink.ink : Ink.inkTertiary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Ink.card)
                            .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(isCN ? "ai-mode-cn-ru" : "ai-mode-ru-cn")
    }

    private var inputCard: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                InkTextEditor(text: $text, paper: isCNMode ? .grid : .lined, isEditable: !isLoading)
                    .frame(height: 128)

                if text.isEmpty {
                    Text("Введите текст...")
                        .font(InkFont.serif(15, italic: true))
                        .foregroundStyle(Ink.muted)
                        .padding(.top, 12)
                        .padding(.leading, 19)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }

            HStack {
                Text("До 1000 символов за один перевод")
                Spacer(minLength: 8)
                Text(verbatim: "\(characterCount) / \(APIService.maximumAITextLength)")
                    .monospacedDigit()
                    .foregroundStyle(characterCount > APIService.maximumAITextLength ? Ink.cinnabar : Ink.muted)
            }
            .font(InkFont.serif(12, relativeTo: .caption1))
            .foregroundStyle(Ink.muted)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18).fill(Ink.card))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Ink.line, lineWidth: 1))
    }

    private var translateButton: some View {
        Button {
            hideKeyboard()
            if aiConsentGranted {
                Task { await analyze() }
            } else {
                isShowingAIConsent = true
            }
        } label: {
            HStack(spacing: 12) {
                InkSeal(text: "译", size: 28)
                Text("Перевести")
            }
        }
        .buttonStyle(InkPrimaryButtonStyle())
        .disabled(
            isLoading ||
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .accessibilityLabel(isCNMode ? "Перевести (CN -> RU)" : "Перевести (RU -> CN)")
    }

    // MARK: - States

    @ViewBuilder
    private var stateSection: some View {
        if isLoading {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Ink.cinnabar)
                    Text(isCNMode ? "ИИ анализирует… ожидайте ответ" : "ИИ переводит… ожидайте ответ")
                        .font(InkFont.serif(15, italic: true))
                        .foregroundStyle(Ink.inkTertiary)
                }
                InkSkeletonBar()
                    .padding(.top, 6)
                InkSkeletonBar(width: 230)
                InkSkeletonBar(width: 170)
            }
            .inkCard(dashed: true)
            .accessibilityElement(children: .combine)
        } else if let error {
            HStack(alignment: .top, spacing: 12) {
                InkSeal(text: errorKind.seal, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(errorKind.title)
                        .font(InkFont.serif(18, .semibold, relativeTo: .headline))
                        .foregroundStyle(Ink.ink)
                    Text(error)
                        .font(InkFont.serif(14, relativeTo: .subheadline))
                        .foregroundStyle(Ink.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Ink.card))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Ink.cinnabar, lineWidth: 1))
            .accessibilityElement(children: .combine)
        } else if hasResult {
            resultCards
        } else {
            VStack(alignment: .leading, spacing: 6) {
                cardLabel("Что вы получите")
                Text(isCNMode
                     ? "Естественный перевод, пиньинь, ключевые слова и найденные в словаре слова."
                     : "Перевод на китайский с пиньинем.")
                    .font(InkFont.serif(14, relativeTo: .subheadline))
                    .foregroundStyle(Ink.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .inkCard(dashed: true)
        }
    }

    private var resultCards: some View {
        VStack(alignment: .leading, spacing: 10) {

            // NATURAL
            if !natural.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        cardLabel("Естественный перевод")

                        Spacer(minLength: 4)

                        if copiedNatural {
                            Label("Скопировано", systemImage: "checkmark")
                                .font(InkFont.serif(12))
                                .foregroundStyle(Ink.onInk)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(Capsule().fill(Ink.ink))
                                .transition(.opacity)
                        }

                        Button {
                            UIPasteboard.general.string = natural
                            copiedNatural = true

                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copiedNatural = false
                            }
                        } label: {
                            Image(systemName: copiedNatural ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 18))
                                .foregroundStyle(Ink.ink)
                                .frame(width: 44, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Скопировать")
                    }

                    Text(resultIsCNMode
                         ? InkFont.mixed(natural, size: 20, weight: .medium, relativeTo: .title3)
                         : InkFont.mixed(natural, size: 24, weight: .semibold, relativeTo: .title2))
                        .foregroundStyle(Ink.ink)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                    if !resultIsCNMode, !pinyin.isEmpty {
                        Text(formatPinyin(pinyin))
                            .font(InkFont.serif(14, italic: true, relativeTo: .subheadline))
                            .foregroundStyle(Ink.inkTertiary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .inkCard()
            }

            // PINYIN
            if !pinyin.isEmpty, resultIsCNMode || natural.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    cardLabel("Пиньинь")
                    Text(formatPinyin(pinyin))
                        .font(InkFont.serif(14, italic: true, relativeTo: .subheadline))
                        .foregroundStyle(Ink.inkTertiary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .inkCard()
            }

            // KEYWORDS (AI)
            if !keywords.isEmpty {
                InkSectionLabel(title: "Ключевые слова")
                    .padding(.top, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(keywords, id: \.self) { word in
                            Text(word)
                                .font(InkFont.chinese(16))
                                .foregroundStyle(Ink.ink)
                                .padding(.horizontal, 13)
                                .frame(height: 34)
                                .overlay(Capsule().stroke(Ink.ink, lineWidth: 1))
                        }
                    }
                    .padding(1)
                }
            }

            // DICTIONARY HITS
            if !dictionaryHits.isEmpty {
                InkSectionLabel(title: "Словарь")
                    .padding(.top, 8)

                VStack(spacing: 0) {
                    ForEach(dictionaryHits) { hit in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(hit.hanzi ?? "—")
                                .font(InkFont.chinese(20))
                                .foregroundStyle(Ink.ink)
                                .frame(minWidth: 64, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                if let pinyin = hit.pinyin, !pinyin.isEmpty {
                                    Text(formatPinyin(pinyin))
                                        .font(InkFont.serif(15, .medium, italic: true))
                                        .foregroundStyle(Ink.muted)
                                }

                                if let ru = hit.ru, !ru.isEmpty {
                                    Text(InkFont.mixed(ru, size: 14, relativeTo: .subheadline))
                                        .foregroundStyle(Ink.inkSecondary)
                                        .lineLimit(3)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Ink.lineSoft).frame(height: 1)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func cardLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(InkFont.serif(11.5, .semibold, relativeTo: .caption1))
            .tracking(2.2)
            .foregroundStyle(Ink.cinnabarDeep)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Consent

    private var consentSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                InkSeal(text: "译", size: 52, rotation: -4)
                    .padding(.top, 8)

                Text("Передача текста для ИИ")
                    .font(InkFont.serif(27, .semibold, relativeTo: .title1))
                    .foregroundStyle(Ink.ink)
                    .padding(.top, 14)
                    .accessibilityAddTraits(.isHeader)

                Text("Введённый текст будет отправлен на сервер приложения, а затем в Selectel Token Factory для ИИ-анализа или перевода. Согласие можно отозвать в разделе «Конфиденциальность».")
                    .font(InkFont.serif(15))
                    .foregroundStyle(Ink.inkSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                Button("Согласен и отправить") {
                    aiConsentGranted = true
                    isShowingAIConsent = false
                    Task { await analyze() }
                }
                .buttonStyle(InkPrimaryButtonStyle())
                .padding(.top, 24)

                Button {
                    isShowingAIConsent = false
                } label: {
                    Text("Отмена")
                        .font(InkFont.serif(16))
                        .foregroundStyle(Ink.inkTertiary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)
        }
        .background(Ink.paper.ignoresSafeArea())
        .presentationDetents([.height(470), .large])
        .presentationDragIndicator(.visible)
    }



    func formatPinyin(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "？", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parseRuCn(_ text: String) -> (translation: String, pinyin: String, comment: String) {
        var translation = ""
        var pinyin = ""
        var comment = ""

        var currentSection = ""

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            if line.hasPrefix("Китайский перевод:") || line.hasPrefix("Китайский перевод：") {
                currentSection = "translation"
                translation = line
                    .replacingOccurrences(of: "Китайский перевод:", with: "")
                    .replacingOccurrences(of: "Китайский перевод：", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            if line.hasPrefix("Пиньинь:") || line.hasPrefix("Пиньинь：") {
                currentSection = "pinyin"
                pinyin = line
                    .replacingOccurrences(of: "Пиньинь:", with: "")
                    .replacingOccurrences(of: "Пиньинь：", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            if line.hasPrefix("Краткий комментарий:") || line.hasPrefix("Комментарий:") {
                currentSection = "comment"
                comment = line
                    .replacingOccurrences(of: "Краткий комментарий:", with: "")
                    .replacingOccurrences(of: "Комментарий:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            if currentSection == "translation", translation.isEmpty {
                translation = line
            } else if currentSection == "pinyin", pinyin.isEmpty {
                pinyin = line
            } else if currentSection == "comment", comment.isEmpty {
                comment = line
            }
        }

        return (translation, pinyin, comment)
    }


    // MARK: - Logic

    @MainActor
    func analyze() async {
        guard !isLoading else { return }
        guard aiConsentGranted else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let requestIsCNMode = isCNMode

        isLoading = true
        defer {
            isLoading = false
        }

        error = nil
        copiedNatural = false

        natural = ""
        pinyin = ""
        keywords = []
        dictionaryHits = []

        do {
            if requestIsCNMode {
                let response = try await APIService.shared.analyzeChinese(
                    text: trimmed
                )

                natural = response.natural
                pinyin = response.pinyin
                keywords = response.keywords
                dictionaryHits = response.dictionaryHits
            } else {
                let response = try await APIService.shared.translateRuToCn(
                    text: trimmed
                )

                natural = response.translation
                pinyin = response.pinyin
            }
            resultIsCNMode = requestIsCNMode
        } catch {
            self.errorKind = AIErrorKind(error)
            self.error = NetworkErrorPresentation.message(for: error)
        }
    }
}

/// Short heading and seal shown above the AI error text.
private enum AIErrorKind {
    case wait, network, timeout, busy, input, generic

    init(_ error: Error) {
        if let aiError = error as? AIServiceError {
            switch aiError {
            case .emptyInput, .inputTooLong:
                self = .input
            case let .http(status, _, _):
                switch status {
                case 400, 413, 422: self = .input
                case 429: self = .wait
                case 503: self = .busy
                case 504: self = .timeout
                default: self = .generic
                }
            }
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost,
                 .dnsLookupFailed, .networkConnectionLost:
                self = .network
            case .timedOut:
                self = .timeout
            default:
                self = .generic
            }
        } else {
            self = .generic
        }
    }

    var title: String {
        switch self {
        case .wait: return "Подождите немного"
        case .network: return "Нет связи"
        case .timeout: return "Слишком долго"
        case .busy: return "ИИ занят"
        case .input: return "Проверьте текст"
        case .generic: return "Не получилось"
        }
    }

    var seal: String {
        switch self {
        case .wait: return "等"
        case .network: return "断"
        case .timeout: return "时"
        case .busy: return "忙"
        case .input: return "字"
        case .generic: return "误"
        }
    }
}

// MARK: - Keyboard

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
