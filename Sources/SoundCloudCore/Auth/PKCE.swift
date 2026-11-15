import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Failures raised while producing or validating RFC 7636 PKCE material.
public enum PKCEError: Error, Equatable, Sendable {
    case invalidVerifierLength
    case invalidVerifierCharacter(Character)
    case hashingUnavailable(String)
}

/// Secure randomness boundary so tests can supply deterministic bytes.
public protocol SecureRandomSource: Sendable {
    func bytes(count: Int) -> [UInt8]
}

/// Uses `SystemRandomNumberGenerator`, which Apple documents as cryptographically
/// secure. Only the app adapter may substitute another source.
public struct SystemSecureRandomSource: SecureRandomSource {
    public init() {}

    public func bytes(count: Int) -> [UInt8] {
        guard count > 0 else { return [] }
        var generator = SystemRandomNumberGenerator()
        var output: [UInt8] = []
        output.reserveCapacity(count)
        for _ in 0..<count {
            output.append(UInt8.random(in: UInt8.min...UInt8.max, using: &generator))
        }
        return output
    }
}

/// S256 challenge derivation boundary. The production implementation lives in
/// `CryptoKitPKCEHasher`; the core never embeds its own cryptography.
public protocol PKCEHashing: Sendable {
    func s256Challenge(for verifier: String) throws -> String
}

/// RFC 7636 helpers: verifier, state nonce, and base64url encoding.
public enum PKCE {
    public static let minimumVerifierLength = 43
    public static let maximumVerifierLength = 128
    public static let verifierByteCount = 32
    public static let stateByteCount = 32

    public static func makeVerifier(
        random: any SecureRandomSource = SystemSecureRandomSource()
    ) -> String {
        base64URL(Data(random.bytes(count: verifierByteCount)))
    }

    /// A random nonce for CSRF/state validation. It is not derived from the verifier.
    public static func makeState(
        random: any SecureRandomSource = SystemSecureRandomSource()
    ) -> String {
        base64URL(Data(random.bytes(count: stateByteCount)))
    }

    public static func isValidVerifier(_ verifier: String) -> Bool {
        guard (minimumVerifierLength...maximumVerifierLength).contains(verifier.count) else {
            return false
        }
        return verifier.unicodeScalars.allSatisfy(isAllowedVerifierScalar)
    }

    public static func validate(_ verifier: String) throws {
        guard (minimumVerifierLength...maximumVerifierLength).contains(verifier.count) else {
            throw PKCEError.invalidVerifierLength
        }
        for character in verifier {
            guard isAllowedVerifierCharacter(character) else {
                throw PKCEError.invalidVerifierCharacter(character)
            }
        }
    }

    public static func challenge(
        for verifier: String,
        hashing: any PKCEHashing
    ) throws -> String {
        try validate(verifier)
        return try hashing.s256Challenge(for: verifier)
    }

    /// base64url without padding, as required by RFC 7636 and RFC 4648 section 5.
    public static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func isAllowedVerifierCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.count == 1 && character.unicodeScalars.allSatisfy(isAllowedVerifierScalar)
    }

    private static func isAllowedVerifierScalar(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        let isUppercase = value >= 0x41 && value <= 0x5A
        let isLowercase = value >= 0x61 && value <= 0x7A
        let isDigit = value >= 0x30 && value <= 0x39
        let isUnreservedSymbol = value == 0x2D || value == 0x2E || value == 0x5F || value == 0x7E
        return isUppercase || isLowercase || isDigit || isUnreservedSymbol
    }
}

#if canImport(CryptoKit)
/// SHA-256 challenge generation through the platform crypto module.
public struct CryptoKitPKCEHasher: PKCEHashing {
    public init() {}

    public func s256Challenge(for verifier: String) throws -> String {
        try PKCE.validate(verifier)
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return PKCE.base64URL(Data(digest))
    }
}
#endif
