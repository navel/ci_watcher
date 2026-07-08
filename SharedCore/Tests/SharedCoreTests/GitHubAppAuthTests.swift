import XCTest
@testable import SharedCore

@available(macOS 13.0, iOS 16.0, *)
final class GitHubAppAuthTests: XCTestCase {
    
    func testGitHubAppAuthInitialization() {
        let auth = GitHubAppAuth(appID: TestFixtures.testAppID, privateKey: TestFixtures.rsaPrivateKeyPEM)
        XCTAssertNotNil(auth)
    }
    
    func testJWTGeneration() async throws {
        let auth = GitHubAppAuth(appID: TestFixtures.testAppID, privateKey: TestFixtures.rsaPrivateKeyPEM)
        let jwt = try await auth.generateJWT()
        
        XCTAssertFalse(jwt.isEmpty)
        XCTAssertEqual(jwt.components(separatedBy: ".").count, 3)
    }
    
    func testJWTGenerationWithBase64EncodedKey() async throws {
        let pemData = TestFixtures.rsaPrivateKeyPEM.data(using: .utf8)!
        let base64Key = pemData.base64EncodedString()
        
        let auth = GitHubAppAuth(appID: TestFixtures.testAppID, privateKey: base64Key)
        let jwt = try await auth.generateJWT()
        
        XCTAssertEqual(jwt.components(separatedBy: ".").count, 3)
    }
    
    func testInvalidPrivateKeyThrows() async {
        let auth = GitHubAppAuth(appID: TestFixtures.testAppID, privateKey: "not-a-valid-key")
        
        do {
            _ = try await auth.generateJWT()
            XCTFail("Expected invalidPrivateKey error")
        } catch let error as GitHubAppAuthError {
            if case .invalidPrivateKey = error {
                // expected
            } else {
                XCTFail("Expected invalidPrivateKey, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
