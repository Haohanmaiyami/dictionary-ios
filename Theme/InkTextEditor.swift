//
//  InkTextEditor.swift
//  DictionaryApp
//
//  Text input drawn on copybook paper: Chinese is typed into 稿纸 grid cells,
//  Russian on ruled lines. Cells are drawn from the same metrics as the text,
//  so characters stay inside them while the field scrolls.
//

import SwiftUI
import UIKit

struct InkTextEditor: UIViewRepresentable {
    @Binding var text: String
    var paper: InkPaperTextView.Paper
    var isEditable = true
    var accessibilityLabel = "Текст для перевода"

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> InkPaperTextView {
        let view = InkPaperTextView()
        view.delegate = context.coordinator
        view.paper = paper
        view.attributedText = NSAttributedString(string: text, attributes: view.paperAttributes)
        view.accessibilityLabel = accessibilityLabel
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ view: InkPaperTextView, context: Context) {
        context.coordinator.parent = self
        view.paper = paper
        view.isEditable = isEditable
        // Never replace text while an input method (e.g. pinyin) is composing.
        if view.markedTextRange == nil, view.text != text {
            view.attributedText = NSAttributedString(string: text, attributes: view.paperAttributes)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: InkTextEditor

        init(_ parent: InkTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            if textView.markedTextRange == nil, let paperView = textView as? InkPaperTextView {
                // Pasted text may carry other fonts; keep every character on the grid.
                paperView.normalizeAttributesIfNeeded()
            }
            if parent.text != textView.text {
                parent.text = textView.text
            }
        }
    }
}

final class InkPaperTextView: UITextView {
    enum Paper: Equatable {
        case grid
        case lined
    }

    /// Side of a grid cell and height of a ruled line.
    static let cell: CGFloat = 28
    /// Point size of Chinese characters inside a grid cell.
    static let gridFontSize: CGFloat = 20
    private static let verticalInset: CGFloat = 8

    var paper: Paper = .grid {
        didSet {
            guard paper != oldValue else { return }
            applyPaperStyle()
        }
    }

    private let paperBackground = InkPaperBackgroundView()

    // Text set from outside typing (accessibility, system services) skips the
    // typing attributes and the delegate: put it back on the grid and report it.
    override var text: String! {
        didSet { textWasReplaced() }
    }

    override var attributedText: NSAttributedString! {
        didSet { textWasReplaced() }
    }

    private func textWasReplaced() {
        guard markedTextRange == nil else { return }
        applyAttributesToText()
        delegate?.textViewDidChange?(self)
    }

    init() {
        super.init(frame: .zero, textContainer: nil)
        backgroundColor = .clear
        textContainer.lineFragmentPadding = 0
        alwaysBounceVertical = false
        paperBackground.isUserInteractionEnabled = false
        insertSubview(paperBackground, at: 0)
        applyPaperStyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var paperAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = Self.cell
        paragraph.maximumLineHeight = Self.cell
        var attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraph,
            .foregroundColor: Ink.uiColor(light: 0x1E1A16, dark: 0xEDE4D3),
        ]
        switch paper {
        case .grid:
            paragraph.lineBreakMode = .byCharWrapping
            attributes[.font] = InkFont.uiChinese(size: Self.gridFontSize, bold: false)
            attributes[.kern] = Self.cell - Self.gridFontSize
        case .lined:
            paragraph.lineBreakMode = .byWordWrapping
            attributes[.font] = InkFont.uiSerif(size: 17)
        }
        return attributes
    }

    func normalizeAttributesIfNeeded() {
        let expectedFont = paperAttributes[.font] as? UIFont
        var needsUpdate = false
        textStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: textStorage.length), options: []) { value, _, stop in
            if (value as? UIFont) != expectedFont {
                needsUpdate = true
                stop.pointee = true
            }
        }
        if needsUpdate {
            applyAttributesToText()
        }
    }

    private func applyPaperStyle() {
        typingAttributes = paperAttributes
        applyAttributesToText()
        setNeedsLayout()
    }

    private func applyAttributesToText() {
        guard markedTextRange == nil, textStorage.length > 0 else { return }
        let selection = selectedRange
        textStorage.setAttributes(paperAttributes, range: NSRange(location: 0, length: textStorage.length))
        selectedRange = selection
        typingAttributes = paperAttributes
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let cell = Self.cell
        let columns = max(1, Int((bounds.width - 12) / cell))
        let side = floor((bounds.width - CGFloat(columns) * cell) / 2)
        // A little slack on the right so exactly `columns` cells fit on a line.
        let inset = UIEdgeInsets(top: Self.verticalInset, left: side, bottom: Self.verticalInset, right: max(0, side - 2))
        if textContainerInset != inset {
            textContainerInset = inset
        }
        // Each Chinese glyph is followed by its kerning; centre it in the cell.
        let gridShift = paper == .grid ? (cell - Self.gridFontSize) / 2 : 0
        paperBackground.frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(contentSize.height, bounds.height))
        paperBackground.configure(
            paper: paper,
            origin: CGPoint(x: side - gridShift, y: Self.verticalInset),
            columns: columns,
            lineWidth: CGFloat(columns) * cell
        )
        sendSubviewToBack(paperBackground)
    }
}

final class InkPaperBackgroundView: UIView {
    private var paper: InkPaperTextView.Paper = .grid
    private var origin: CGPoint = .zero
    private var columns = 0
    private var lineWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }

    // iOS 16.6 is supported, so the pre-iOS 17 trait callback is used.
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            setNeedsDisplay()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(paper: InkPaperTextView.Paper, origin: CGPoint, columns: Int, lineWidth: CGFloat) {
        guard paper != self.paper || origin != self.origin || columns != self.columns || lineWidth != self.lineWidth else { return }
        self.paper = paper
        self.origin = origin
        self.columns = columns
        self.lineWidth = lineWidth
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), columns > 0 else { return }
        let cell = InkPaperTextView.cell
        let rows = Int((bounds.height - origin.y) / cell)
        guard rows > 0 else { return }
        let color = Ink.uiColor(light: 0xEAD1C8, dark: 0x4A2E28).resolvedColor(with: traitCollection)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1)

        switch paper {
        case .grid:
            let width = CGFloat(columns) * cell
            let height = CGFloat(rows) * cell
            for row in 0...rows {
                let y = origin.y + CGFloat(row) * cell
                context.move(to: CGPoint(x: origin.x, y: y))
                context.addLine(to: CGPoint(x: origin.x + width, y: y))
            }
            for column in 0...columns {
                let x = origin.x + CGFloat(column) * cell
                context.move(to: CGPoint(x: x, y: origin.y))
                context.addLine(to: CGPoint(x: x, y: origin.y + height))
            }
        case .lined:
            for row in 1...rows {
                let y = origin.y + CGFloat(row) * cell - 0.5
                context.move(to: CGPoint(x: origin.x, y: y))
                context.addLine(to: CGPoint(x: origin.x + lineWidth, y: y))
            }
        }
        context.strokePath()
    }
}
