import Testing
import Foundation
@testable import Ghostty

// MARK: - Mock Directory Enumerator

private final class MockDirectoryEnumerator: FileBrowserDirectoryEnumerating {
    private let result: Result<[URL], Error>

    init(result: Result<[URL], Error>) {
        self.result = result
    }

    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        try result.get()
    }
}

// MARK: - Tests

@MainActor
struct FileBrowserViewModelTests {
    // MARK: - Initialization

    @Test func testInitialStateIsEmpty() {
        let vm = FileBrowserViewModel()
        #expect(vm.items.isEmpty)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - loadDirectory success

    @Test func testLoadDirectoryPopulatesItems() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let fileURL = tmpDir.appendingPathComponent("hello.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        let subDir = tmpDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let vm = FileBrowserViewModel()
        await vm.loadDirectory(url: tmpDir)

        #expect(!vm.items.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    @Test func testLoadDirectoryDirectoriesBeforeFiles() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let fileURL = tmpDir.appendingPathComponent("aaa.txt")
        try "".write(to: fileURL, atomically: true, encoding: .utf8)

        let subDir = tmpDir.appendingPathComponent("zzz")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let vm = FileBrowserViewModel()
        await vm.loadDirectory(url: tmpDir)

        let items = vm.items
        #expect(items.count == 2)
        #expect(items[0].isDirectory == true)
        #expect(items[1].isDirectory == false)
    }

    @Test func testLoadDirectorySkipsHiddenFiles() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let visibleFile = tmpDir.appendingPathComponent("visible.txt")
        try "".write(to: visibleFile, atomically: true, encoding: .utf8)

        let hiddenFile = tmpDir.appendingPathComponent(".hidden")
        try "".write(to: hiddenFile, atomically: true, encoding: .utf8)

        let vm = FileBrowserViewModel()
        await vm.loadDirectory(url: tmpDir)

        let names = vm.items.map(\.displayName)
        #expect(names.contains("visible.txt"))
        #expect(!names.contains(".hidden"))
    }

    // MARK: - loadDirectory error

    @Test func testLoadDirectoryPermissionErrorLeavesItemsEmpty() async {
        let permissionError = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileReadNoPermissionError,
            userInfo: [NSLocalizedDescriptionKey: "Permission denied"]
        )
        let mock = MockDirectoryEnumerator(result: .failure(permissionError))
        let vm = FileBrowserViewModel(enumerator: mock)

        await vm.loadDirectory(url: URL(fileURLWithPath: "/private/restricted"))

        #expect(vm.items.isEmpty)
        #expect(vm.errorMessage != nil)
    }

    @Test func testLoadDirectoryErrorMessageIsNonNilOnFailure() async {
        let error = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let mock = MockDirectoryEnumerator(result: .failure(error))
        let vm = FileBrowserViewModel(enumerator: mock)

        await vm.loadDirectory(url: URL(fileURLWithPath: "/nonexistent"))

        #expect(vm.errorMessage != nil)
    }

    // MARK: - expandItem lazy loading

    @Test func testExpandItemFillsChildrenForUnexpandedDirectory() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let subDir = tmpDir.appendingPathComponent("child")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let childFile = subDir.appendingPathComponent("file.txt")
        try "".write(to: childFile, atomically: true, encoding: .utf8)

        let vm = FileBrowserViewModel()
        await vm.loadDirectory(url: tmpDir)

        let dirItem = try #require(vm.items.first(where: { $0.isDirectory }))
        #expect(dirItem.children == nil)

        await vm.expandItem(dirItem)

        let expanded = try #require(vm.items.first(where: { $0.url == dirItem.url }))
        #expect(expanded.children != nil)
    }

    @Test func testExpandItemDoesNotReloadAlreadyExpandedDirectory() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let subDir = tmpDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let vm = FileBrowserViewModel()
        await vm.loadDirectory(url: tmpDir)

        let dirItem = try #require(vm.items.first(where: { $0.isDirectory }))
        await vm.expandItem(dirItem)

        let afterFirst = try #require(vm.items.first(where: { $0.url == dirItem.url }))
        let childrenAfterFirst = afterFirst.children

        await vm.expandItem(afterFirst)

        let afterSecond = try #require(vm.items.first(where: { $0.url == dirItem.url }))
        #expect(afterSecond.children == childrenAfterFirst)
    }

    @Test func testExpandItemIgnoresFiles() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let fileURL = tmpDir.appendingPathComponent("readme.txt")
        try "".write(to: fileURL, atomically: true, encoding: .utf8)

        let vm = FileBrowserViewModel()
        await vm.loadDirectory(url: tmpDir)

        let fileItem = try #require(vm.items.first(where: { !$0.isDirectory }))
        await vm.expandItem(fileItem)

        let after = try #require(vm.items.first(where: { $0.url == fileItem.url }))
        #expect(after.children == nil)
    }

    // MARK: - collapseItem

    @Test func testCollapseItemResetsChildrenToNil() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let subDir = tmpDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let vm = FileBrowserViewModel()
        await vm.loadDirectory(url: tmpDir)

        let dirItem = try #require(vm.items.first(where: { $0.isDirectory }))
        await vm.expandItem(dirItem)

        let expanded = try #require(vm.items.first(where: { $0.url == dirItem.url }))
        #expect(expanded.children != nil)

        vm.collapseItem(expanded)

        let collapsed = try #require(vm.items.first(where: { $0.url == dirItem.url }))
        #expect(collapsed.children == nil)
    }

    @Test func testCollapseItemIgnoresAlreadyCollapsed() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let subDir = tmpDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let vm = FileBrowserViewModel()
        await vm.loadDirectory(url: tmpDir)

        let dirItem = try #require(vm.items.first(where: { $0.isDirectory }))
        // children == nil，尚未展开
        #expect(dirItem.children == nil)

        // 折叠一个未展开的目录不应改变状态
        vm.collapseItem(dirItem)

        let after = try #require(vm.items.first(where: { $0.url == dirItem.url }))
        #expect(after.children == nil)
    }

    @Test func testCollapseItemIgnoresFiles() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let fileURL = tmpDir.appendingPathComponent("readme.txt")
        try "".write(to: fileURL, atomically: true, encoding: .utf8)

        let vm = FileBrowserViewModel()
        await vm.loadDirectory(url: tmpDir)

        let fileItem = try #require(vm.items.first(where: { !$0.isDirectory }))
        vm.collapseItem(fileItem)

        let after = try #require(vm.items.first(where: { $0.url == fileItem.url }))
        #expect(after.children == nil)
    }
    // MARK: - Truncation

    @Test func testTruncationAt500Entries() async {
        let urls = (0..<600).map { i in
            URL(fileURLWithPath: "/tmp/file\(i).txt")
        }
        let mock = MockDirectoryEnumerator(result: .success(urls))
        let vm = FileBrowserViewModel(enumerator: mock)

        await vm.loadDirectory(url: URL(fileURLWithPath: "/tmp"))

        #expect(vm.items.count == 500)
        #expect(vm.truncateMessage != nil)
    }

    @Test func testNoTruncationMessageWhenUnder500() async {
        let urls = (0..<10).map { i in
            URL(fileURLWithPath: "/tmp/file\(i).txt")
        }
        let mock = MockDirectoryEnumerator(result: .success(urls))
        let vm = FileBrowserViewModel(enumerator: mock)

        await vm.loadDirectory(url: URL(fileURLWithPath: "/tmp"))

        #expect(vm.items.count == 10)
        #expect(vm.errorMessage == nil)
    }
}
