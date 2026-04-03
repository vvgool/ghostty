import SwiftUI

/// 文件浏览器侧边栏视图
///
/// 展示当前目录的文件树，支持展开/折叠子目录。
/// 视图包含标题栏（目录名 + 刷新按钮）、加载态、错误态、文件树列表态和截断提示。
struct FileBrowserView: View {
    @ObservedObject var viewModel: FileBrowserViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
            if let truncateMsg = viewModel.truncateMessage {
                truncateFooter(message: truncateMsg)
            }
        }
        .frame(minWidth: 150)
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(spacing: 4) {
            Text(viewModel.currentDirectoryName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMsg = viewModel.errorMessage {
            errorView(message: errorMsg)
        } else {
            fileTreeView
        }
    }

    /// 文件树视图：使用 ScrollView + LazyVStack 递归渲染，
    /// 避免 List 行复用机制导致子节点被错误地渲染为兄弟行。
    private var fileTreeView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.items) { item in
                    FileItemNode(item: item, viewModel: viewModel, depth: 0)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func truncateFooter(message: String) -> some View {
        Text(message)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - File Item Node

/// 递归渲染单个文件树节点，通过 depth 控制缩进层级。
/// 目录节点支持展开/折叠，文件节点直接渲染行内容。
private struct FileItemNode: View {
    let item: FileItem
    @ObservedObject var viewModel: FileBrowserViewModel
    let depth: Int

    /// 每层缩进宽度（点）
    private static let indentWidth: CGFloat = 16

    var body: some View {
        if item.isDirectory {
            DirectoryNode(item: item, viewModel: viewModel, depth: depth)
        } else {
            FileItemRow(item: item)
                .padding(.leading, CGFloat(depth) * Self.indentWidth + 20)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Directory Node

/// 目录节点：带展开/折叠箭头，展开时递归渲染子节点。
///
/// 使用 `@State var isExpandedLocally` 作为乐观 UI 状态，
/// 点击箭头时立即翻转，不等待异步 `expandItem` 完成。
/// 当 `item.children` 从外部（如 refresh）重置为 nil 时，同步折叠本地状态。
private struct DirectoryNode: View {
    let item: FileItem
    @ObservedObject var viewModel: FileBrowserViewModel
    let depth: Int

    @State private var isExpandedLocally: Bool = false

    private static let indentWidth: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 目录行：箭头 + 图标 + 名称
            HStack(spacing: 2) {
                // 缩进占位
                Spacer()
                    .frame(width: CGFloat(depth) * Self.indentWidth)

                // 展开/折叠箭头按钮
                Button {
                    isExpandedLocally.toggle()
                } label: {
                    Image(systemName: isExpandedLocally ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)

                // 目录图标 + 名称（点击可展开/折叠）
                Button {
                    isExpandedLocally.toggle()
                } label: {
                    FileItemRow(item: item)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)

            // 展开时渲染子节点
            if isExpandedLocally, let children = item.children {
                ForEach(children) { child in
                    FileItemNode(item: child, viewModel: viewModel, depth: depth + 1)
                }
            }
        }
        .onChange(of: isExpandedLocally) { expanding in
            if expanding {
                Task { await viewModel.expandItem(item) }
            } else {
                viewModel.collapseItem(item)
            }
        }
        .onChange(of: item.children == nil) { isNilNow in
            // 当外部（如 refresh）将 children 重置为 nil 时，同步折叠本地状态
            if isNilNow {
                isExpandedLocally = false
            }
        }
    }
}

// MARK: - File Item Row

private struct FileItemRow: View {
    let item: FileItem

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: item.isDirectory ? "folder" : "doc")
                .foregroundStyle(item.isDirectory ? Color.yellow : Color.primary)
                .font(.system(size: 13))
            Text(item.displayName)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .accessibilityLabel(item.displayName)
        .accessibilityHint(item.isDirectory ? "Directory" : "File")
    }
}
