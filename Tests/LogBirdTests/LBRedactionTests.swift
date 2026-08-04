import XCTest
@testable import LogBird

final class LBRedactionTests: XCTestCase {

    func testAdditionalInfoRedactsDefaultKeys() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-defaults")

        logBird.log("login", additionalInfo: [
            "username": .string("javier"),
            "password": .string("123456"),
            "Authorization": .string("Bearer abc123"),
            "retries": .int(2)
        ])

        let info = logBird.logs.first?.additionalInfo
        XCTAssertEqual(info?["username"], .string("javier"))
        XCTAssertEqual(info?["password"], .string("<redacted>"))
        XCTAssertEqual(info?["Authorization"], .string("<redacted>"))
        XCTAssertEqual(info?["retries"], .int(2))
    }

    func testSensitiveKeyMatchingIsCaseInsensitiveSubstring() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-matching")

        logBird.log("matching", additionalInfo: [
            "accessToken": .string("a"),
            "AUTH_TOKEN": .string("b"),
            "apiKey": .string("c"),
            "mySecret": .string("d"),
            "sessionId": .string("e")
        ])

        let info = logBird.logs.first?.additionalInfo
        XCTAssertEqual(info?["accessToken"], .string("<redacted>"))
        XCTAssertEqual(info?["AUTH_TOKEN"], .string("<redacted>"))
        XCTAssertEqual(info?["apiKey"], .string("<redacted>"))
        XCTAssertEqual(info?["mySecret"], .string("<redacted>"))
        XCTAssertEqual(info?["sessionId"], .string("e"))
    }

    func testRedactedValueBecomesStringRegardlessOfOriginalType() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-type")

        logBird.log("typed", additionalInfo: ["token": .int(12345)])

        let info = logBird.logs.first?.additionalInfo
        XCTAssertEqual(info?["token"], .string("<redacted>"))
    }

    func testRedactionCanBeDisabled() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-disabled")
        logBird.redactSensitiveFields = false

        logBird.log("raw", additionalInfo: ["token": .string("abc123")])

        let info = logBird.logs.first?.additionalInfo
        XCTAssertEqual(info?["token"], .string("abc123"))
    }

    func testCustomSensitiveKeysReplaceDefaults() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-custom")
        logBird.sensitiveKeys(.set(["session"]))

        logBird.log("custom", additionalInfo: [
            "sessionId": .string("xyz"),
            "token": .string("abc123")
        ])

        let info = logBird.logs.first?.additionalInfo
        XCTAssertEqual(info?["sessionId"], .string("<redacted>"))
        XCTAssertEqual(info?["token"], .string("abc123"))
    }

    func testRedactionConfigIsPerInstance() {
        let first = LogBird(subsystem: "com.logbird.tests", category: "redaction-first")
        let second = LogBird(subsystem: "com.logbird.tests", category: "redaction-second")

        first.redactSensitiveFields = false

        first.log("raw", additionalInfo: ["token": .string("abc123")])
        second.log("redacted", additionalInfo: ["token": .string("abc123")])

        XCTAssertEqual(first.logs.first?.additionalInfo?["token"], .string("abc123"))
        XCTAssertEqual(second.logs.first?.additionalInfo?["token"], .string("<redacted>"))
        XCTAssertEqual(second.sensitiveKeys, LBRedactor.initialDefaultSensitiveKeys)
    }

    func testEmptySensitiveKeysRedactNothing() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-empty-keys")
        logBird.sensitiveKeys(.clear)

        logBird.log("raw", additionalInfo: ["token": .string("abc123")])

        let info = logBird.logs.first?.additionalInfo
        XCTAssertEqual(info?["token"], .string("abc123"))
    }

    func testBlankSensitiveKeysAreIgnored() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-blank-keys")
        logBird.sensitiveKeys(.set(["", "  "]))

        logBird.log("raw", additionalInfo: ["token": .string("abc123")])

        XCTAssertEqual(logBird.logs.first?.additionalInfo?["token"], .string("abc123"))
    }

    func testSensitiveKeysActionSetAddDefaultClear() {
        defer {
            LogBird.setDefaultSensitiveKeys(Array(LBRedactor.initialDefaultSensitiveKeys))
        }

        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-actions")

        // Initial default set matches initial needles
        XCTAssertEqual(logBird.sensitiveKeys, LBRedactor.initialDefaultSensitiveKeys)

        // .add preserves global defaults and adds custom keys
        logBird.sensitiveKeys(.add(["anotherkey"]))
        XCTAssertEqual(logBird.sensitiveKeys, LBRedactor.initialDefaultSensitiveKeys.union(["anotherkey"]))

        // Changing global default dynamically updates logBird which added custom keys
        LogBird.setDefaultSensitiveKeys(["password", "token", "newglobal"])
        XCTAssertEqual(logBird.sensitiveKeys, ["password", "token", "newglobal", "anotherkey"])

        // .set replaces completely for this instance
        logBird.sensitiveKeys(.set(["customkey"]))
        XCTAssertEqual(logBird.sensitiveKeys, ["customkey"])

        // .clear empties this instance
        logBird.sensitiveKeys(.clear)
        XCTAssertTrue(logBird.sensitiveKeys.isEmpty)

        // .reset restores pure global default set
        logBird.sensitiveKeys(.reset)
        XCTAssertEqual(logBird.sensitiveKeys, ["password", "token", "newglobal"])
    }

    func testStaticFacadeSensitiveKeysActions() {
        defer {
            LogBird.setDefaultSensitiveKeys(Array(LBRedactor.initialDefaultSensitiveKeys))
            LogBird.sensitiveKeys(.reset)
        }

        LogBird.sensitiveKeys(.set(["facadekey"]))
        XCTAssertEqual(LogBird.sensitiveKeys, ["facadekey"])

        LogBird.sensitiveKeys(.add(["extrakey"]))
        XCTAssertEqual(LogBird.sensitiveKeys, ["facadekey", "extrakey"])

        LogBird.sensitiveKeys(.clear)
        XCTAssertTrue(LogBird.sensitiveKeys.isEmpty)

        LogBird.sensitiveKeys(.reset)
        XCTAssertEqual(LogBird.sensitiveKeys, LBRedactor.initialDefaultSensitiveKeys)

        LogBird.setDefaultSensitiveKeys(["globalappdefault"])
        LogBird.sensitiveKeys(.reset)
        XCTAssertEqual(LogBird.sensitiveKeys, ["globalappdefault"])
    }

    func testSensitiveKeyMatchingIgnoresSeparators() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-separators")

        logBird.log("separators", additionalInfo: [
            "api_key": .string("a"),
            "x-api-key": .string("b"),
            "API-KEY": .string("c"),
            "auth token": .string("d")
        ])

        let info = logBird.logs.first?.additionalInfo
        XCTAssertEqual(info?["api_key"], .string("<redacted>"))
        XCTAssertEqual(info?["x-api-key"], .string("<redacted>"))
        XCTAssertEqual(info?["API-KEY"], .string("<redacted>"))
        XCTAssertEqual(info?["auth token"], .string("<redacted>"))
    }

    func testExtraMessageValuesAreRedactedByKey() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-extra-messages")

        logBird.log("request", extraMessages: [
            LBExtraMessage(key: "Authorization", value: "Bearer abc123"),
            LBExtraMessage(key: "endpoint", value: "/login")
        ])

        let extraMessages = logBird.logs.first?.extraMessages
        XCTAssertEqual(extraMessages?.first(where: { $0.key == "Authorization" })?.value, "<redacted>")
        XCTAssertEqual(extraMessages?.first(where: { $0.key == "endpoint" })?.value, "/login")
    }

    func testExtraMessageRedactionKeepsEntryIdentity() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-extra-identity")
        let original = LBExtraMessage(key: "session_token", value: "abc123")

        logBird.log("request", extraMessages: [original])

        let redacted = logBird.logs.first?.extraMessages?.first
        XCTAssertEqual(redacted?.id, original.id)
        XCTAssertEqual(redacted?.key, "session_token")
        XCTAssertEqual(redacted?.value, "<redacted>")
    }

    func testExtraMessagesUntouchedWhenRedactionDisabled() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-extra-disabled")
        logBird.redactSensitiveFields = false

        logBird.log("request", extraMessages: [LBExtraMessage(key: "Authorization", value: "Bearer abc123")])

        XCTAssertEqual(logBird.logs.first?.extraMessages?.first?.value, "Bearer abc123")
    }

    func testPlainTextExportDoesNotLeakSensitiveValues() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-plaintext")

        logBird.log("auth", additionalInfo: ["token": .string("Bearer abc123")])

        let text = String(decoding: try logBird.export(format: .plainText).data, as: UTF8.self)
        XCTAssertFalse(text.contains("Bearer abc123"))
        XCTAssertTrue(text.contains(LogBird.redactionPlaceholder))
    }

    func testErrorUserInfoIsRedacted() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-error")
        let error = NSError(domain: "com.test.networking", code: 401, userInfo: [
            "Authorization": "Bearer abc123",
            "url": "https://api.example.com/login"
        ])

        logBird.log("request failed", error: error, level: .error)

        let userInfo = logBird.logs.first?.error?.userInfo
        XCTAssertEqual(userInfo?["Authorization"], "<redacted>")
        XCTAssertEqual(userInfo?["url"], "https://api.example.com/login")
    }

    func testExportDoesNotLeakSensitiveValues() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-export")
        let error = NSError(domain: "com.test", code: 1, userInfo: ["secret": "shhh"])

        logBird.log("auth", additionalInfo: ["token": .string("Bearer abc123")], error: error)

        let json = String(decoding: try logBird.export(format: .json).data, as: UTF8.self)
        XCTAssertFalse(json.contains("Bearer abc123"))
        XCTAssertFalse(json.contains("shhh"))
        XCTAssertTrue(json.contains("<redacted>"))
    }

    func testDefaultKeysIncludeAllCuratedNeedles() {
        let expectedNeedles: Set<String> = [
            "password", "token", "authorization", "auth", "secret",
            "apikey", "cookie", "bearer", "credentials", "privatekey"
        ]
        XCTAssertEqual(LBRedactor.initialDefaultSensitiveKeys, expectedNeedles)
    }

    func testSensitiveKeysActionNormalizesInputKeys() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-norm-test")

        logBird.sensitiveKeys(.set(["API_KEY", "X-Auth-Token"]))
        XCTAssertEqual(logBird.sensitiveKeys, ["apikey", "xauthtoken"])

        logBird.sensitiveKeys(.add(["User_SSN"]))
        XCTAssertEqual(logBird.sensitiveKeys, ["apikey", "xauthtoken", "userssn"])
    }

    func testExpandedDefaultKeysMatchCommonVariants() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-variants")

        logBird.log("login", additionalInfo: [
            "access_token": .string("token1"),
            "refresh_token": .string("token2"),
            "set-cookie": .string("session=123"),
            "x-api-key": .string("key123"),
            "private_key": .string("pem-data"),
            "user_credentials": .string("creds"),
            "bearer": .string("token3"),
            "auth_code": .string("code123")
        ])

        let info = logBird.logs.first?.additionalInfo
        XCTAssertEqual(info?["access_token"], .string("<redacted>"))
        XCTAssertEqual(info?["refresh_token"], .string("<redacted>"))
        XCTAssertEqual(info?["set-cookie"], .string("<redacted>"))
        XCTAssertEqual(info?["x-api-key"], .string("<redacted>"))
        XCTAssertEqual(info?["private_key"], .string("<redacted>"))
        XCTAssertEqual(info?["user_credentials"], .string("<redacted>"))
        XCTAssertEqual(info?["bearer"], .string("<redacted>"))
        XCTAssertEqual(info?["auth_code"], .string("<redacted>"))
    }
}
