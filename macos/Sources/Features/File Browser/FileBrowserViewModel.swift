import Foundation

// MARK: - Directory Enumerating Protocol

protocol FileBrowserDirectoryEnumerating: Sendable {
    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL]
}

extension FileManager: FileBrowserDirectoryEnumerating {}

// MARK: - ViewModel

@MainActor
final class FileBrowserViewModel: ObservableObject {
    @Published var items: [FileItem] = []
    @Published var errorMessage: String?
    @Published var truncateMessage: String?
    @Published var isLoading: Bool = false

    private let maxItemsPerDirectory = 500
    private let enumerator: any FileBrowserDirectoryEnumerating
    private var currentDirectoryURL: URL?

    /// 当前目录的显示名称（仅最后一段路径）
    var currentDirectoryName: String {
        currentDirectoryURL?.lastPathComponent ?? ""
    }

    init(enumerator: any FileBrowserDirectoryEnumerating = FileManager.default) {
        self.enumerator = enumerator
    }

    func loadDirectory(url: URL) async {
        currentDirectoryURL = url
        isLoading = true
        errorMessage = nil
        truncateMessage = nil
        defer { isLoading = false }

        let capturedEnumerator = enumerator
        let result = await Task.detached(priority: .userInitiated) { () -> Result<[URL], Error> in
            do {
                let urls = try capturedEnumerator.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                    options: [.skipsHiddenFiles]
                )
                return .success(urls)
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let urls):
            let sorted = sortedURLs(urls)
            let truncated = Array(sorted.prefix(maxItemsPerDirectory))
            items = truncated.map { makeFileItem(url: $0) }
            if truncated.count < sorted.count {
                truncateMessage = "Showing first \(maxItemsPerDirectory) items"
            }
        case .failure(let error):
            items = []
            errorMessage = error.localizedDescription
        }
    }

    /// 重新加载当前目录
    func refresh() async {
        guard let url = currentDirectoryURL else { return }
        await loadDirectory(url: url)
    }

    func expandItem(_ item: FileItem) async {
        guard item.isDirectory, item.children == nil else { return }

        let capturedEnumerator = enumerator
        let result = await Task.detached(priority: .userInitiated) { () -> Result<[URL], Error> in
            do {
                let urls = try capturedEnumerator.contentsOfDirectory(
                    at: item.url,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                    options: [.skipsHiddenFiles]
                )
                return .success(urls)
            } catch {
                return .failure(error)
            }
        }.value

        let children: [FileItem]
        switch result {
        case .success(let urls):
            let sorted = sortedURLs(urls)
            let truncated = Array(sorted.prefix(maxItemsPerDirectory))
            children = truncated.map { makeFileItem(url: $0) }
        case .failure:
            children = []
        }

        let updated = item.replacing(children: children)
        items = replaceItem(in: items, matching: item.url, with: updated)
    }

    /// 折叠目录，将 children 重置为 nil（未展开语义）
    func collapseItem(_ item: FileItem) {
        guard item.isDirectory, item.children != nil else { return }
        let updated = item.replacing(children: nil)
        items = replaceItem(in: items, matching: item.url, with: updated)
    }

    // MARK: - Private Helpers

    private func sortedURLs(_ urls: [URL]) -> [URL] {
        urls.sorted { lhs, rhs in
            let lhsIsDir = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let rhsIsDir = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if lhsIsDir != rhsIsDir {
                return lhsIsDir
            }
            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }
    }

    private func makeFileItem(url: URL) -> FileItem {
        let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        let isDirectory = resourceValues?.isDirectory ?? false
        let isSymlink = resourceValues?.isSymbolicLink ?? false
        return FileItem(
            url: url,
            displayName: url.lastPathComponent,
            isDirectory: isDirectory,
            isSymlink: isSymlink,
            children: nil
        )
    }

    private func replaceItem(in items: [FileItem], matching url: URL, with replacement: FileItem) -> [FileItem] {
        items.map { item in
            if item.url == url {
                return replacement
            }
            if let children = item.children {
                let updatedChildren = replaceItem(in: children, matching: url, with: replacement)
                return item.replacing(children: updatedChildren)
            }
            return item
        }
    }
}

// MARK: - FileItem Extension

private extension FileItem {
    func replacing(children: [FileItem]?) -> FileItem {
        FileItem(
            url: url,
            displayName: displayName,
            isDirectory: isDirectory,
            isSymlink: isSymlink,
            children: children
        )
    }
}
