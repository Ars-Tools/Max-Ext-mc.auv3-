//
//  AVConverter+.swift
//  mc.auv3_tilde
//
//  Created by Kota on 7/31/R7.
//
import AVFoundation
extension AVAudioConverter {
	func convert(to: UnsafePointer<AudioBufferList>, from: (AVAudioFrameCount) -> Optional<AVAudioPCMBuffer>) -> AVAudioConverterOutputStatus {
		guard let target = AVAudioPCMBuffer(pcmFormat: outputFormat, bufferListNoCopy: to, deallocator: .none) else { return.error }
		var error: NSError?
		let status = withoutActuallyEscaping(from) { fetch in
			convert(to: target, error: &error) {
				switch fetch($0) {
				case.some(let buffer):
					$1.pointee = .haveData
					return.some(buffer)
				case.none:
					$1.pointee = .noDataNow
					return.none
				}
			}
		}
		return if case.some = error {
			.error
		} else {
			status
		}
	}
	func convert(to: UnsafePointer<AudioBufferList>, from: (AVAudioPCMBuffer) -> AVAudioFrameCount) -> AVAudioConverterOutputStatus {
		guard let target = AVAudioPCMBuffer(pcmFormat: outputFormat, bufferListNoCopy: to, deallocator: .none) else { return.endOfStream }
		var error: NSError?
		let status = withoutActuallyEscaping(from) { fetch in
			convert(to: target, error: &error)
			{ [inputFormat] in
				switch AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: $0) {
				case.some(let source):
					source.frameLength = fetch(source)
					$1.pointee = .haveData
					return.some(source)
				case.none:
					$1.pointee = .noDataNow
					return.none
				}
			}
		}
		return if case.some = error {
			.error
		} else {
			status
		}
	}
	func convert(to: some Collection<UnsafeMutableBufferPointer<Float64>>, from: (AVAudioPCMBuffer) -> AVAudioFrameCount) -> AVAudioConverterOutputStatus {
		let target = AudioBufferList.allocate(maximumBuffers: to.count)
		defer {
			target.unsafePointer.deallocate()
		}
		for (index, source) in to.enumerated() {
			target[index] = .init(source, numberOfChannels: 1)
		}
		guard let target = AVAudioPCMBuffer(pcmFormat: outputFormat, bufferListNoCopy: target.unsafeMutablePointer, deallocator: .none) else { return.endOfStream }
		var error: NSError?
		let status = withoutActuallyEscaping(from) { fetch in
			convert(to: target, error: &error)
			{ [inputFormat] in
				switch AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: $0) {
				case.some(let source):
					source.frameLength = fetch(source)
					$1.pointee = .haveData
					return.some(source)
				case.none:
					$1.pointee = .noDataNow
					return.none
				}
			}
		}
		return if case.some = error {
			.error
		} else {
			status
		}
	}
}
