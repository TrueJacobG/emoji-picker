import AppKit

struct PasteboardSnapshot {
    struct Item {
        struct Entry {
            let type: NSPasteboard.PasteboardType
            let data: Data
        }

        let entries: [Entry]
    }

    let items: [Item]

    static func capture(from pasteboard: NSPasteboard = .general) -> PasteboardSnapshot {
        let items: [Item] = pasteboard.pasteboardItems?.compactMap { item in
            let entries: [Item.Entry] = item.types.compactMap { (type: NSPasteboard.PasteboardType) -> Item.Entry? in
                guard let data = item.data(forType: type) else {
                    return nil
                }

                return Item.Entry(type: type, data: data)
            }

            guard !entries.isEmpty else {
                return nil
            }

            return Item(entries: entries)
        } ?? []

        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        guard !items.isEmpty else {
            return
        }

        let pasteboardItems = items.map { item in
            let pasteboardItem = NSPasteboardItem()

            for entry in item.entries {
                pasteboardItem.setData(entry.data, forType: entry.type)
            }

            return pasteboardItem
        }

        pasteboard.writeObjects(pasteboardItems)
    }
}

func writeStringToPasteboard(_ text: String, pasteboard: NSPasteboard = .general) {
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

enum TextReplacementResult {
    case success(updatedText: String, newCursorLocation: Int)
    case failure
}

func replaceTextAtSelection(currentText: String, selectionLocation: Int, selectionLength: Int, replacement: String) -> TextReplacementResult {
    let nsCurrent = currentText as NSString
    let maxValidLocation = nsCurrent.length

    let effectiveLocation: Int
    let effectiveLength: Int

    if selectionLocation == NSNotFound || selectionLocation + selectionLength > maxValidLocation {
        effectiveLocation = maxValidLocation
        effectiveLength = 0
    } else {
        effectiveLocation = selectionLocation
        effectiveLength = selectionLength
    }

    let selectedNSRange = NSRange(location: effectiveLocation, length: effectiveLength)
    let updatedValue = nsCurrent.replacingCharacters(in: selectedNSRange, with: replacement)
    let newCursorLocation = effectiveLocation + (replacement as NSString).length

    return .success(updatedText: updatedValue, newCursorLocation: newCursorLocation)
}

func appendText(currentText: String, text: String) -> TextReplacementResult {
    let updated = currentText + text
    return .success(updatedText: updated, newCursorLocation: (updated as NSString).length)
}
