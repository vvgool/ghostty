import Testing
import Foundation

@testable import Ghostty

struct FileItemTests {
    // MARK: - Identifiable Tests

    @Test func testFileItemIsIdentifiable() {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        let item = FileItem(url: url, displayName: "test.txt", isDirectory: false, isSymlink: false, children: nil)

        // FileItem should conform to Identifiable
        let _: any Identifiable = item
        #expect(item.id == url)
    }

    // MARK: - Hashable Tests

    @Test func testFileItemIsHashable() {
        let url1 = URL(fileURLWithPath: "/tmp/test1.txt")
        let url2 = URL(fileURLWithPath: "/tmp/test2.txt")

        let item1 = FileItem(url: url1, displayName: "test1.txt", isDirectory: false, isSymlink: false, children: nil)
        let item2 = FileItem(url: url1, displayName: "test1.txt", isDirectory: false, isSymlink: false, children: nil)
        let item3 = FileItem(url: url2, displayName: "test2.txt", isDirectory: false, isSymlink: false, children: nil)

        // Same URL should have same hash
        #expect(item1.hashValue == item2.hashValue)

        // Different URLs should (likely) have different hashes
        #expect(item1.hashValue != item3.hashValue)
    }

    @Test func testFileItemEquality() {
        let url1 = URL(fileURLWithPath: "/tmp/test1.txt")
        let url2 = URL(fileURLWithPath: "/tmp/test2.txt")

        let item1 = FileItem(url: url1, displayName: "test1.txt", isDirectory: false, isSymlink: false, children: nil)
        let item2 = FileItem(url: url1, displayName: "test1.txt", isDirectory: false, isSymlink: false, children: nil)
        let item3 = FileItem(url: url2, displayName: "test2.txt", isDirectory: false, isSymlink: false, children: nil)

        // Same URL should be equal
        #expect(item1 == item2)

        // Different URLs should not be equal
        #expect(item1 != item3)
    }

    @Test func testFileItemCanBeAddedToSet() {
        let url1 = URL(fileURLWithPath: "/tmp/test1.txt")
        let url2 = URL(fileURLWithPath: "/tmp/test2.txt")

        let item1 = FileItem(url: url1, displayName: "test1.txt", isDirectory: false, isSymlink: false, children: nil)
        let item2 = FileItem(url: url1, displayName: "test1.txt", isDirectory: false, isSymlink: false, children: nil)
        let item3 = FileItem(url: url2, displayName: "test2.txt", isDirectory: false, isSymlink: false, children: nil)

        var set: Set<FileItem> = [item1, item2, item3]

        // item1 and item2 have same URL, so set should contain 2 items
        #expect(set.count == 2)
        #expect(set.contains(item1))
        #expect(set.contains(item3))
    }

    // MARK: - File vs Directory Tests

    @Test func testFileItemCanRepresentFile() {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        let item = FileItem(url: url, displayName: "test.txt", isDirectory: false, isSymlink: false, children: nil)

        #expect(item.isDirectory == false)
        #expect(item.isSymlink == false)
        #expect(item.children == nil)
    }

    @Test func testFileItemCanRepresentDirectory() {
        let url = URL(fileURLWithPath: "/tmp/folder")
        let item = FileItem(url: url, displayName: "folder", isDirectory: true, isSymlink: false, children: nil)

        #expect(item.isDirectory == true)
        #expect(item.isSymlink == false)
        #expect(item.children == nil)
    }

    @Test func testFileItemCanRepresentSymlink() {
        let url = URL(fileURLWithPath: "/tmp/link")
        let item = FileItem(url: url, displayName: "link", isDirectory: false, isSymlink: true, children: nil)

        #expect(item.isSymlink == true)
    }

    // MARK: - Children Semantics Tests

    @Test func testChildrenNilMeansUnexpandedDirectory() {
        let url = URL(fileURLWithPath: "/tmp/folder")
        let item = FileItem(url: url, displayName: "folder", isDirectory: true, isSymlink: false, children: nil)

        // nil children means directory hasn't been expanded yet
        #expect(item.children == nil)
        #expect(item.isDirectory == true)
    }

    @Test func testChildrenEmptyArrayMeansEmptyDirectory() {
        let url = URL(fileURLWithPath: "/tmp/empty_folder")
        let item = FileItem(url: url, displayName: "empty_folder", isDirectory: true, isSymlink: false, children: [])

        // empty array means directory has been expanded and is empty
        #expect(item.children == [])
        #expect(item.children?.isEmpty == true)
    }

    @Test func testChildrenEmptyArrayForFile() {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        let item = FileItem(url: url, displayName: "test.txt", isDirectory: false, isSymlink: false, children: [])

        // files can have empty children array (semantically means no children)
        #expect(item.children == [])
    }

    @Test func testChildrenWithItems() {
        let parentUrl = URL(fileURLWithPath: "/tmp/folder")
        let childUrl1 = URL(fileURLWithPath: "/tmp/folder/file1.txt")
        let childUrl2 = URL(fileURLWithPath: "/tmp/folder/file2.txt")

        let child1 = FileItem(url: childUrl1, displayName: "file1.txt", isDirectory: false, isSymlink: false, children: nil)
        let child2 = FileItem(url: childUrl2, displayName: "file2.txt", isDirectory: false, isSymlink: false, children: nil)

        let parent = FileItem(url: parentUrl, displayName: "folder", isDirectory: true, isSymlink: false, children: [child1, child2])

        #expect(parent.children?.count == 2)
        #expect(parent.children?.contains(child1) == true)
        #expect(parent.children?.contains(child2) == true)
    }

    // MARK: - Display Name Tests

    @Test func testDisplayNameIsFileName() {
        let url = URL(fileURLWithPath: "/tmp/folder/test.txt")
        let item = FileItem(url: url, displayName: "test.txt", isDirectory: false, isSymlink: false, children: nil)

        // displayName should be just the filename, not the full path
        #expect(item.displayName == "test.txt")
        #expect(item.displayName != "/tmp/folder/test.txt")
    }

    @Test func testDisplayNameForDirectory() {
        let url = URL(fileURLWithPath: "/tmp/my_folder")
        let item = FileItem(url: url, displayName: "my_folder", isDirectory: true, isSymlink: false, children: nil)

        #expect(item.displayName == "my_folder")
    }

    // MARK: - URL Identity Tests

    @Test func testUrlIsUniqueIdentifier() {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        let item1 = FileItem(url: url, displayName: "test.txt", isDirectory: false, isSymlink: false, children: nil)
        let item2 = FileItem(url: url, displayName: "different_name.txt", isDirectory: true, isSymlink: true, children: nil)

        // id 基于 URL，与其他属性无关
        #expect(item1.id == item2.id)
        // 相同 URL 且 children 状态相同（均为 nil）时相等
        #expect(item1 == item2)
    }

    @Test func testSameUrlDifferentChildrenStateAreNotEqual() {
        let url = URL(fileURLWithPath: "/tmp/folder")
        let unexpanded = FileItem(url: url, displayName: "folder", isDirectory: true, isSymlink: false, children: nil)
        let expanded = FileItem(url: url, displayName: "folder", isDirectory: true, isSymlink: false, children: [])

        // children 状态变化（nil ↔ 非 nil）必须被 SwiftUI 感知，因此不相等
        #expect(unexpanded != expanded)
    }

    @Test func testSameUrlSameChildCountButDifferentNestedChildrenAreNotEqual() {
        let parentURL = URL(fileURLWithPath: "/tmp/folder")
        let childDirectoryURL = parentURL.appendingPathComponent("child")

        let leafA = FileItem(
            url: childDirectoryURL.appendingPathComponent("README.md"),
            displayName: "README.md",
            isDirectory: false,
            isSymlink: false,
            children: nil
        )
        let leafB = FileItem(
            url: childDirectoryURL.appendingPathComponent("package.json"),
            displayName: "package.json",
            isDirectory: false,
            isSymlink: false,
            children: nil
        )

        let nestedA = FileItem(
            url: childDirectoryURL,
            displayName: "child",
            isDirectory: true,
            isSymlink: false,
            children: [leafA]
        )
        let nestedB = FileItem(
            url: childDirectoryURL,
            displayName: "child",
            isDirectory: true,
            isSymlink: false,
            children: [leafB]
        )

        let parentA = FileItem(
            url: parentURL,
            displayName: "folder",
            isDirectory: true,
            isSymlink: false,
            children: [nestedA]
        )
        let parentB = FileItem(
            url: parentURL,
            displayName: "folder",
            isDirectory: true,
            isSymlink: false,
            children: [nestedB]
        )

        #expect(parentA != parentB)
    }

    @Test func testDifferentUrlsAreDifferentItems() {
        let url1 = URL(fileURLWithPath: "/tmp/test1.txt")
        let url2 = URL(fileURLWithPath: "/tmp/test2.txt")

        let item1 = FileItem(url: url1, displayName: "test1.txt", isDirectory: false, isSymlink: false, children: nil)
        let item2 = FileItem(url: url2, displayName: "test1.txt", isDirectory: false, isSymlink: false, children: nil)

        // Different URLs mean different items, even with same displayName
        #expect(item1.id != item2.id)
        #expect(item1 != item2)
    }
}
