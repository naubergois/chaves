import XCTest
@testable import Chaves

final class VaultDecodingTests: XCTestCase {
    func testDecodesMaskedKeyAndCredit() throws {
        let json = """
        {
          "ok": true,
          "keys": [{
            "name": "OPENAI_API_KEY",
            "label": "OpenAI",
            "category": "llm",
            "category_label": "Modelos",
            "hint": "GPT",
            "credit_provider": "openai",
            "configured": true,
            "masked": "sk-p…xyz1",
            "source": "mongodb",
            "credit": {
              "ok": true,
              "provider": "openai",
              "status": "ok",
              "label": "$12.40",
              "detail": "saldo",
              "balance": 12.4,
              "unit": "usd",
              "error": null
            }
          }],
          "stats": {"configured": 1, "total": 1, "missing": 0, "with_credit": 1}
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(VaultPayload.self, from: json)
        XCTAssertTrue(payload.ok)
        XCTAssertEqual(payload.keys.first?.masked, "sk-p…xyz1")
        XCTAssertEqual(payload.keys.first?.credit?.label, "$12.40")
        XCTAssertEqual(payload.stats.withCredit, 1)
        XCTAssertFalse(payload.keys.first?.masked.contains("sk-proj") ?? true)
    }

    func testSidebarFilterHidesMissing() {
        let missing = KeyRecord(
            name: "HF_TOKEN",
            label: "Hugging Face",
            category: "media",
            categoryLabel: "Imagem e vídeo",
            hint: "",
            creditProvider: "",
            configured: false,
            masked: "",
            source: "",
            credit: nil
        )
        XCTAssertTrue(SidebarFilter.missing.matches(missing))
        XCTAssertFalse(SidebarFilter.configured.matches(missing))
        XCTAssertTrue(SidebarFilter.media.matches(missing))
    }
}
