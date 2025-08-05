//
//  FourCode+.swift
//  mc.auv3_tilde
//
//  Created by Kota on 7/26/R7.
//
import typealias CoreFoundation.FourCharCode
func de(code: FourCharCode) -> String {
	withUnsafeBytes(of: code.bigEndian) {
		.init(bytes: $0, encoding: .ascii) ?? .init()
	}
}
func en(code: String) -> FourCharCode {
	code.compactMap(\.asciiValue).compactMap(FourCharCode.init(exactly:)).prefix(4).reduce(0) {
		$0 << 8 | .init($1)
	}
}
