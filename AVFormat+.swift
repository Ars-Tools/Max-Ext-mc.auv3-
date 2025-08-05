//
//  AVFormat+.swift
//  mc.auv3_tilde
//
//  Created by Kota on 7/26/R7.
//
@_exported @preconcurrency import typealias AVFoundation.AVAudioFormat
@preconcurrency import typealias AVFoundation.AVAudioCommonFormat
@preconcurrency import typealias AVFoundation.AudioChannelLayout
@preconcurrency import let AVFoundation.kAudioChannelLabel_Mono
extension AVAudioFormat: @retroactive @unchecked Sendable {
	public convenience init?(sampleRate: Float64, monoChannels count: Int) {
		let layout = AudioChannelLayout.allocate(maximumDescriptions: count)
		defer {
			layout.unsafePointer.deallocate()
		}
		for index in layout.indices {
			layout[index] = .init(mChannelLabel: .init(kAudioChannelLabel_Mono), mChannelFlags: .init(rawValue: 0), mCoordinates: (0, 0, 0))
		}
		self.init(standardFormatWithSampleRate: sampleRate, channelLayout: .init(layout: layout.unsafePointer))
	}
	public convenience init?(commonFormat: AVAudioCommonFormat, sampleRate: Float64, monoChannels count: Int, interleaved: Bool) {
		let layout = AudioChannelLayout.allocate(maximumDescriptions: count)
		defer {
			layout.unsafePointer.deallocate()
		}
		for index in layout.indices {
			layout[index] = .init(mChannelLabel: .init(kAudioChannelLabel_Mono), mChannelFlags: .init(rawValue: 0), mCoordinates: (0, 0, 0))
		}
		self.init(commonFormat: commonFormat, sampleRate: sampleRate, interleaved: interleaved, channelLayout: .init(layout: layout.unsafePointer))
	}
}
