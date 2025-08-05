//
//  Untitled.swift
//  mc.auv3_tilde
//
//  Created by Kota on 7/26/R7.
//
import CoreAudioKit
import os.log
extension AudioComponentDescription: @retroactive @unchecked Sendable {}
extension AUAudioUnit: @retroactive @unchecked Sendable, @retroactive ObservableObject {}
extension AUAudioUnitBus {
	func set(format: AVAudioFormat) -> Bool {
		do {
			try setFormat(format)
			return true
		} catch {
			os_log(.error, "%{public}@", "\(format) is not unsupported")
			return false
		}
	}
}
extension AUAudioUnitBusArray: @retroactive RandomAccessCollection {
	public var startIndex: Int {
		0
	}
	public var endIndex: Int {
		count
	}
}
extension AUAudioUnitBusArray {
	@inlinable
	var convertersF64: some Sequence<(Int, AVAudioConverter)> {
		switch busType {
		case.input:
			sequence(state: (0, lazy.prefix(while: \.isEnabled).map(\.format).makeIterator())) { s in
				s.1.next().flatMap { source in
					AVAudioFormat(commonFormat: .pcmFormatFloat64,
								  sampleRate: source.sampleRate,
								  monoChannels: .init(source.channelCount),
								  interleaved: false).flatMap {
						AVAudioConverter(from: $0, to: source)
					}
				}.map { converter in
					defer {
						s.0 += .init(converter.outputFormat.channelCount)
					}
					return (s.0, converter)
				}
			}
		case.output:
			sequence(state: (0, lazy.prefix(while: \.isEnabled).map(\.format).makeIterator())) { s in
				s.1.next().flatMap { target in
					AVAudioFormat(commonFormat: .pcmFormatFloat64,
								  sampleRate: target.sampleRate,
								  monoChannels: .init(target.channelCount),
								  interleaved: false).flatMap {
						AVAudioConverter(from: target, to: $0)
					}
				}.map { converter in
					defer {
						s.0 += .init(converter.outputFormat.channelCount)
					}
					return (s.0, converter)
				}
			}
		@unknown default:
			fatalError()
		}
	}
	@inlinable
	var offsetConverters: some Sequence<(Int, AVAudioConverter)> {
		switch busType {
		case.input:
			sequence(state: (0, lazy.prefix(while: \.isEnabled).map(\.format).makeIterator())) { s in
				s.1.next().flatMap { source in
					AVAudioFormat(commonFormat: .pcmFormatFloat64,
								  sampleRate: source.sampleRate,
								  monoChannels: .init(source.channelCount),
								  interleaved: false).flatMap {
						AVAudioConverter(from: $0, to: source)
					}
				}.map { converter in
					defer {
						s.0 += .init(converter.outputFormat.channelCount)
					}
					return (s.0, converter)
				}
			}
		case.output:
			sequence(state: (0, lazy.prefix(while: \.isEnabled).map(\.format).makeIterator())) { s in
				s.1.next().flatMap { target in
					AVAudioFormat(commonFormat: .pcmFormatFloat64,
								  sampleRate: target.sampleRate,
								  monoChannels: .init(target.channelCount),
								  interleaved: false).flatMap {
						AVAudioConverter(from: target, to: $0)
					}
				}.map { converter in
					defer {
						s.0 += .init(converter.outputFormat.channelCount)
					}
					return (s.0, converter)
				}
			}
		@unknown default:
			fatalError()
		}
	}
}
public protocol RangeValueModel<Value>: AnyObject & Observable {
	associatedtype Value: BinaryFloatingPoint where Value.Stride: BinaryFloatingPoint
	var value: Value { get set }
	var range: ClosedRange<Value> { get }
}
extension AUParameter: @retroactive ObservableObject {
	var normalizedValue: AUValue {
		get {
			( value - minValue ) / ( maxValue - minValue )
		}
		set {
			value = fma(newValue, maxValue - minValue, minValue)
		}
	}
	var displayValue: String {
		if flags.contains(.flag_ValuesHaveStrings) {
			withUnsafePointer(to: value, string(fromValue:))
		} else if case.indexed = unit, let valueStrings, let index = Int(exactly: value), valueStrings.indices ~= index {
			valueStrings[index]
		} else {
			value.description
		}
	}
}
extension AUParameter: @retroactive Observable {}
extension AUParameter: RangeValueModel {
	public var range: ClosedRange<AUValue> {
		minValue...maxValue
	}
}
extension AVAudioUnitComponent: @retroactive Identifiable {
	public var id: SIMD4<UInt32> {
		unsafeBitCast((
			audioComponentDescription.componentType,
			audioComponentDescription.componentSubType,
			audioComponentDescription.componentManufacturer,
			audioComponentDescription.componentFlags
		) as (UInt32, UInt32, UInt32, UInt32), to: SIMD4<UInt32>.self)
	}
}
struct AudioComponentComponent {
	let id: FourCharCode
	let description: String
}
extension AudioComponentComponent: Hashable {
	public static func==(lhs: AudioComponentComponent, rhs: AudioComponentComponent) -> Bool {
		lhs.id == rhs.id
	}
	public func hash(into hasher: inout Hasher) {
		id.hash(into: &hasher)
	}
}
extension AudioComponentComponent: Identifiable, CustomStringConvertible {}
