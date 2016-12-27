import PackageDescription

let package = Package(
    name: "AliyunOSSMac",
    dependencies: [
        .Package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", majorVersion: 0, minor: 6)
    ]
)
