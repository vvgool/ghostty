import Foundation

/// 文件树中的单个节点，代表文件或目录
///
/// `FileItem` 是一个轻量级数据模型，用于表示文件系统中的文件或目录。
/// 它遵循 `Identifiable` 和 `Hashable` 协议，允许在集合中使用和唯一标识。
///
/// - 唯一标识：使用 `URL` 作为唯一标识符（`id` 属性）
/// - 目录展开语义：
///   - `children == nil`：目录尚未展开（未加载子项）
///   - `children == []`：目录已展开但为空，或文件没有子项
///   - `children == [...]`：目录已展开，包含子项列表
struct FileItem: Identifiable, Hashable {
    /// 文件或目录的 URL，用作唯一标识符
    let url: URL

    /// 文件或目录的显示名称（仅文件名，不包含完整路径）
    let displayName: String

    /// 是否为目录
    let isDirectory: Bool

    /// 是否为符号链接
    let isSymlink: Bool

    /// 子项列表
    /// - `nil`：目录尚未展开
    /// - `[]`：目录已展开但为空，或文件没有子项
    /// - `[...]`：包含的子项
    let children: [FileItem]?

    /// 唯一标识符，使用 URL
    var id: URL { url }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(children)
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.url == rhs.url
            && lhs.children == rhs.children
    }
}
