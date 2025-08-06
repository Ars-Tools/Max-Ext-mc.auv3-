import CoreAudioKit
import AVFAudio
import Synchronization
import SwiftUI
import Accelerate
final class Core: Observable, @unchecked Sendable {
	@usableFromInline let native: UnsafeMutableRawPointer
	@usableFromInline let window: NSWindow
	@usableFromInline var select: Optional<AUAudioUnit>
	@usableFromInline var kernel: (UnsafePointer<UnsafeMutablePointer<Float64>>, Int,
								   UnsafePointer<UnsafeMutablePointer<Float64>>, Int,
								   Int) -> OSStatus
	@usableFromInline let tempo: Atomic<Float64>
	@usableFromInline let beat: Atomic<Int>
	@MainActor
	init(object: UnsafeMutableRawPointer) {
		assert(Thread.isMainThread)
		native = object
		window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 512, height: 512),
			styleMask: [.titled, .closable, .resizable, .miniaturizable],
			backing: .buffered,
			defer: true)
		select = .none
		kernel = type(of: self).UninitializedKernel
		tempo = .init(.nan)
		beat = .init(4)
		window.isReleasedWhenClosed = false
		window.minSize = .init(width: 960, height: 540)
		set(view: View(core: self))
	}
	deinit {
		Task { @MainActor [window] in
			window.close()
		}
	}
}
extension Core {
	static func UninitializedKernel(i: UnsafePointer<UnsafeMutablePointer<Float64>>, numi: Int,
									o: UnsafePointer<UnsafeMutablePointer<Float64>>, numo: Int,
									count: Int) -> OSStatus {
		kAudioUnitErr_Uninitialized
	}
	nonisolated(unsafe) static let manager: AVAudioUnitComponentManager = .shared()
}
extension Core {
	func load(type: FourCharCode, subtype: FourCharCode, manufacturer: FourCharCode) {
		load(description: .init(componentType: type,
								componentSubType: subtype,
								componentManufacturer: manufacturer,
								componentFlags: 0, componentFlagsMask: 0))
	}
	func load(description: AudioComponentDescription) {
		Task { @MainActor in
			let unit = try await AUAudioUnit.instantiate(with: description, options: .loadOutOfProcess)
			window.title = [
				unit.audioUnitShortName ?? unit.audioUnitName,
				unit.manufacturerName
			].compactMap(\.self).joined(separator: " - ")
			if unit.providesUserInterface, let controller = await unit.requestViewController(), 1 < controller.preferredContentSize.area {
				set(view: controller)
			} else {
				SDK.Print(native, "Default UI will be used for \(unit.audioUnitName ?? unit.audioUnitShortName ?? "unknown")")
				set(view: UnitView(core: self, unit: unit))
			}
			unit.parameterTree?.implementorValueObserver = { [native] in
				SDK.ParameterOut(native, $0.address, .init($1))
			}
			unit.midiOutputEventBlock = { [native] in
				SDK.MIDIOut(native, $3, .init($2))
				return 0
			}
//			unit.midiOutputEventListBlock = { [unowned self] in
//				midi_out(at: $0, cable: $1, event: $2)
//			}
			select = .some(unit)
			SDK.LoadOut(native,
						unit.componentDescription.componentType,
						unit.componentDescription.componentSubType,
						unit.componentDescription.componentManufacturer)
		}
	}
	@MainActor
	func unload() {
		select = .none
		set(view: View(core: self))
	}
	@MainActor
	func reload() {
		switch select.map(\.componentDescription) {
		case.some(let description):
			load(description: description)
		case.none:
			SDK.Error(native, "No Audio Unit (V3) Loaded")
		}
	}
}
extension Core {
	@MainActor
	func set(view controller: NSViewController) {
		window.contentViewController = controller
	}
	@MainActor
	func set(view: some SwiftUI.View) {
		set(view: NSHostingController(rootView: view.frame(minWidth: window.minSize.width,
														   minHeight: window.minSize.height)))
	}
}
extension Core {
	@MainActor
	func dblclick() {
		window.makeKeyAndOrderFront(.none)
	}
}
extension Core {
	func setup(samplerate: Float64, vectorsize: Int, i: Array<Int>, o: Array<Int>) -> Bool {
		guard let select else {
			SDK.Error(native, "No Audio Unit (V3) Select")
			return false
		}
		select.deallocateRenderResources()
		select.maximumFramesToRender = .init(vectorsize)
		let busses = (
			i: select.inputBusses,
			o: select.outputBusses
		)
		for (bus, count) in zip(busses.i, i) {
			let format = [
				.init(commonFormat: .pcmFormatFloat64, sampleRate: samplerate, monoChannels: count, interleaved: false),
				.init(sampleRate: samplerate, monoChannels: count),
				.init(standardFormatWithSampleRate: samplerate, channels: .init(count))
			] as Array<Optional<AVAudioFormat>>
			bus.isEnabled = format.compactMap(\.self).first(where: bus.set(format:)) != .none
		}
		for (bus, count) in zip(busses.o, o) {
			let format = [
				.init(commonFormat: .pcmFormatFloat64, sampleRate: samplerate, monoChannels: count, interleaved: false),
				.init(sampleRate: samplerate, monoChannels: count),
				.init(standardFormatWithSampleRate: samplerate, channels: .init(count))
			] as Array<Optional<AVAudioFormat>>
			bus.isEnabled = format.compactMap(\.self).first(where: bus.set(format:)) != .none
		}
		let render = select.renderBlock
		let count = Atomic<Int>(0)
		let iconv = Array(busses.i.convertersF64)
		let oconv = Array(busses.o.convertersF64)
		select.musicalContextBlock = { [unowned self]
			currentTempo,
			timeSignatureNumerator,
			timeSignatureDenominator,
			currentBeatPosition,
			sampleOffsetToNextBeat,
			currentMeasureDownbeatPosition in
			var result = false
			if let currentTempo {
				currentTempo.pointee = .init(tempo.load(ordering: .acquiring))
				result = true
			}
			if let timeSignatureNumerator {
				timeSignatureNumerator.pointee = .init(count.load(ordering: .acquiring))
				result = true
			}
			if let timeSignatureDenominator {
				timeSignatureDenominator.pointee = .init(samplerate)
				result = true
			}
			return result
		}
//		select.transportStateBlock = {
//			transportStateFlags,
//			currentSamplePosition,
//			cycleStartBeatPosition,
//			cycleEndBeatPosition in
//			transportStateFlags?.pointee = .
//			currentSamplePosition?.pointee = count.load(ordering: .acquiring)
//			cycleStartBeatPosition?.pointee = 0
//			cycleEndBeatPosition?.pointee = 0
//			return true
//		}
		kernel = { [native, busses] in
			let source = zip((0..<$1).lazy.map($0.advanced(by:)).map(\.pointee), repeatElement($4, count: $1)).map(UnsafeMutableBufferPointer<Float64>.init(start:count:)) as Array
			let target = zip((0..<$3).lazy.map($2.advanced(by:)).map(\.pointee), repeatElement($4, count: $3)).map(UnsafeMutableBufferPointer<Float64>.init(start:count:)) as Array
			let inputs = {
				guard busses.i.indices ~= $3, busses.i[$3].isEnabled else {
					return kAudioUnitErr_CannotDoInCurrentContext
				}
				let (offset, converter) = iconv[$3]
				let buffer = AudioBufferList.allocate(maximumBuffers: .init(converter.inputFormat.channelCount))
				defer {
					buffer.unsafePointer.deallocate()
				}
				for (offset, source) in source.dropFirst(offset).enumerated() {
					buffer[offset] = .init(source, numberOfChannels: 1)
				}
				let status = converter.convert(to: $4) { count in
					AVAudioPCMBuffer(pcmFormat: converter.inputFormat, bufferListNoCopy: buffer.unsafeMutablePointer, deallocator: .none).map {
						$0.frameLength = $0.frameCapacity
						return $0
					}
				}
				switch status {
				case.haveData:
					break
				case.inputRanDry:
					SDK.Error(native, "In[\($3)] DRY")
				case.error:
					SDK.Error(native, "In[\($3)] ERR")
				case.endOfStream:
					SDK.Error(native, "In[\($3)] EOF")
				@unknown default:
					SDK.Error(native, "In[\($3)] UNK")
				}
				return kAudio_NoError
			} as AURenderPullInputBlock
			var action = AudioUnitRenderActionFlags()
			var elapse = AudioTimeStamp(mSampleTime: .init(count.add($4, ordering: .acquiringAndReleasing).oldValue),
										mHostTime: .init(CFAbsoluteTime()),
										mRateScalar: 1,
										mWordClockTime: 0,
										mSMPTETime: .init(),
										mFlags: [.sampleHostTimeValid, .rateScalarValid],
										mReserved: 0)
			for (bus, (offset, converter)) in oconv.enumerated() where busses.o[bus].isEnabled {
				let buffer = AudioBufferList.allocate(maximumBuffers: .init(converter.outputFormat.channelCount))
				defer {
					buffer.unsafePointer.deallocate()
				}
				for (offset, target) in target.dropFirst(offset).enumerated() {
					buffer[offset] = .init(target, numberOfChannels: 1)
				}
				let status = converter.convert(to: buffer.unsafePointer) {
					AVAudioPCMBuffer(pcmFormat: converter.inputFormat, frameCapacity: $0)
						.flatMap {
							switch render(&action, &elapse, $0.frameCapacity, bus, $0.mutableAudioBufferList, .some(inputs)) {
							case.zero:
								$0.frameLength = $0.frameCapacity
								return.some($0)
							case let status:
								SDK.Error(native, "Input for \(bus): \(status)")
								return.none
							}
						}
				}
				switch status {
				case.haveData:
					break
				case.inputRanDry:
					SDK.Error(native, "Out[\(bus)] DRY")
				case.error:
					SDK.Error(native, "Out[\(bus)] ERR")
				case.endOfStream:
					SDK.Error(native, "Out[\(bus)] EOF")
				@unknown default:
					SDK.Error(native, "Out[\(bus)] UNK")
				}
			}
			return 0
		}
		do {
			try select.allocateRenderResources()
			return true
		} catch {
			SDK.Error(native, "\(error)")
			return false
		}
	}
}
extension Core {
	var bypass: Bool {
		get {
			select?.shouldBypassEffect ?? false
		}
		set {
			select?.shouldBypassEffect = newValue
		}
	}
	@inlinable @inline(__always)
	func dsp(i: UnsafePointer<UnsafeMutablePointer<Float64>>, ni: Int,
			 o: UnsafePointer<UnsafeMutablePointer<Float64>>, no: Int,
			 count: Int) {
		switch kernel(i, ni, o, no, count) {
		case.zero:
			break
		default:
			break
		}
	}
}
extension Core {
	func input(index: Int, count: Int) -> Bool {
		if let select, select.inputBusses.indices ~= index, let format = AVAudioFormat(sampleRate: select.inputBusses[index].format.sampleRate, monoChannels: count) {
			do {
				try select.inputBusses[index].setFormat(format)
				return true
			} catch {
				SDK.Error(native, "Invalid input, \(error), \(select.inputBusses.map(\.format)), \(index), \(count)")
				return false
			}
		} else {
			return false
		}
	}
}
extension Core {
	func output(index: Int) -> Int {
		if let select, select.outputBusses.indices ~= index {
			.init(select.outputBusses[index].format.channelCount)
		} else {
			1
		}
	}
}
extension Core {
	@inlinable @inline(__always)
	func send(msg: UnsafeBufferPointer<UInt32>) {
		guard let select else {
			SDK.Print(native, "No Audio Unit (V3) Select")
			return
		}
		withUnsafeTemporaryAllocation(byteCount: MemoryLayout<MIDIEventPacket>.size, alignment: MemoryLayout<UInt32>.alignment) {
			let length = $0.count
			let target = $0.baseAddress.unsafelyUnwrapped.assumingMemoryBound(to: MIDIEventList.self)
			let cursor = MIDIEventListAdd(target, length, MIDIEventListInit(target, ._1_0), 0, msg.count, msg.baseAddress.unsafelyUnwrapped)
			assert(0 != .init(bitPattern: cursor))
			switch select.scheduleMIDIEventListBlock?(AUEventSampleTimeImmediate, 0, target) {
			case.some(.zero):
				break
			default:
				break
			}
		}
	}
	func note_on(note: UInt8, velocity: UInt8, channel: UInt8, group: UInt8) {
		withUnsafeBytes(of: MIDI1UPNoteOn(group, channel, note, velocity)) {
			$0.withMemoryRebound(to: UInt32.self, send)
		}
	}
	func note_off(note: UInt8, velocity: UInt8, channel: UInt8, group: UInt8) {
		withUnsafeBytes(of: MIDI1UPNoteOff(group, channel, note, velocity)) {
			$0.withMemoryRebound(to: UInt32.self, send)
		}
	}
}
extension Core {
	func midi_in(msg: UnsafeBufferPointer<UInt8>) {
		guard let unit = select else {
			SDK.Error(native, "No Audio Unit Select")
			return
		}
		unit.scheduleMIDIEventBlock?(AUEventSampleTimeImmediate, 0, .init(msg.count), msg.baseAddress.unsafelyUnwrapped)
	}
}
extension Core {
	func parameter_in(address: AUParameterAddress, value: AUValue) {
		guard let select else {
			SDK.Error(native, "No Audio Unit (V3) Select")
			return
		}
		guard let parameterTree = select.parameterTree, let parameter = parameterTree.parameter(withAddress: address) else {
			SDK.Print(native, "Parameter \(address) is not available")
			return
		}
		parameter.setValue(value, originator: .none)
		parameter.objectWillChange.send()
//		select.objectWillChange.send()
	}
}
extension Core {
	func preset(factory index: Int) {
		do {
			guard let select else { throw Status.noAudioUnitSelected }
			defer {
				for parameter in select.parameterTree.map(\.allParameters) ?? [] {
					parameter.objectWillChange.send()
				}
				select.objectWillChange.send()
				SDK.PresetOut(native, "factory", index)
			}
			select.currentPreset = select.factoryPresets.flatMap {
				$0.indices.contains(index) ? .some($0[index]) : .none
			}
//			select.fullState = try select.currentPreset.map(select.presetState(for:))
		} catch {
			SDK.Error(native, String(describing: error))
		}
	}
	func preset(load index: Int) {
		do {
			guard let select else { throw Status.noAudioUnitSelected }
			defer {
				for parameter in select.parameterTree.map(\.allParameters) ?? [] {
					parameter.objectWillChange.send()
				}
				select.objectWillChange.send()
				SDK.PresetOut(native, "load", index)
			}
			select.currentPreset = select.userPresets.first { $0.number == index }
		} catch {
			SDK.Error(native, String(describing: error))
		}
	}
	func preset(save index: Int) {
		do {
			guard let select else { throw Status.noAudioUnitSelected }
			defer {
				SDK.PresetOut(native, "save", index)
			}
			try select.userPresets.first { $0.number == index }.map(select.saveUserPreset)
		} catch {
			SDK.Error(native, String(describing: error))
		}
	}
	func preset(create index: Int, as name: String) {
		do {
			guard let select else { throw Status.noAudioUnitSelected }
			defer {
				SDK.PresetOut(native, "create", index)
			}
			let preset = select.userPresets.first { $0.number == index } ?? .init()
			preset.number = index
			preset.name = name
			preset.setValuesForKeys(select.fullState ?? .init())
			select.currentPreset = preset
		} catch {
			SDK.Error(native, String(describing: error))
		}
	}
	func preset(delete index: Int) {
		do {
			guard let select else { throw Status.noAudioUnitSelected }
			defer {
				SDK.PresetOut(native, "delete", index)
			}
			try select.userPresets.first { $0.number == index }.map(select.deleteUserPreset)
		} catch {
			SDK.Error(native, String(describing: error))
		}
	}
	func preset(dump index: Int) {
		do {
			guard let select else { throw Status.noAudioUnitSelected }
			try select.userPresets.first { $0.number == index }.map(select.saveUserPreset)
		} catch {
			SDK.Error(native, String(describing: error))
		}
	}
}
extension Core {
	enum Status: Swift.Error {
		case noAudioUnitSelected
	}
}
@MainActor
@_cdecl("core_new")
func new(native: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
	Unmanaged<Core>.passRetained(.init(object: native)).toOpaque()
}
@MainActor
@_cdecl("core_del")
func del(object: UnsafeMutableRawPointer) {
	Unmanaged<Core>.fromOpaque(object).release()
}
@MainActor
@_cdecl("core_dblclick")
func dblclick(object: UnsafeMutableRawPointer) {
	Unmanaged<Core>.fromOpaque(object).takeUnretainedValue().dblclick()
}
@_cdecl("core_setup")
func setup(object: UnsafeMutableRawPointer, samplerate: CDouble, vectorsize: CLong,
		   i: UnsafePointer<CLong>, ic: CLong, o: UnsafePointer<CLong>, oc: CLong) -> CBool {
	.init(Unmanaged<Core>.fromOpaque(object).takeUnretainedValue()
		.setup(samplerate: .init(samplerate),
			   vectorsize: .init(vectorsize),
			   i: UnsafeBufferPointer(start: i, count: .init(ic)).compactMap(Int.init(exactly:)),
			   o: UnsafeBufferPointer(start: o, count: .init(oc)).compactMap(Int.init(exactly:))))
}
@_cdecl("core_bypass")
func bypass(object: UnsafeMutableRawPointer, flag: CBool) {
	Unmanaged<Core>.fromOpaque(object).takeUnretainedValue().bypass = .init(flag)
}
@_cdecl("core_dsp")
func dsp(object: UnsafeMutableRawPointer,
		 ins: UnsafePointer<UnsafeMutablePointer<CDouble>>, numins: CLong,
		 out: UnsafePointer<UnsafeMutablePointer<CDouble>>, numout: CLong,
		 length: CLong, parameter: UnsafeMutableRawPointer) {
	Unmanaged<Core>.fromOpaque(object).takeUnretainedValue()
		.dsp(i: ins, ni: numins,
			 o: out, no: numout,
			 count: length)
}
@_cdecl("core_input")
func input(object: UnsafeMutableRawPointer, index: CLong, count: CLong) -> CLong {
	Unmanaged<Core>.fromOpaque(object).takeUnretainedValue().input(index: .init(index), count: .init(count)) ? 1 : 0
}
@_cdecl("core_output")
func output(object: UnsafeMutableRawPointer, index: CLong) -> CLong {
	.init(Unmanaged<Core>.fromOpaque(object).takeUnretainedValue().output(index: index))
}
@_cdecl("core_parameter")
func parameter(object: UnsafeMutableRawPointer, address: CLong, value: CDouble) {
	Unmanaged<Core>.fromOpaque(object).takeUnretainedValue().parameter_in(address: .init(address), value: .init(value))
}
@_cdecl("core_note")
func note(object: UnsafeMutableRawPointer, note: UInt8, velocity: UInt8, channel: UInt8, group: UInt8) {
	switch velocity {
	case.zero:
		Unmanaged<Core>.fromOpaque(object).takeUnretainedValue().note_off(note: note, velocity: velocity, channel: channel, group: group)
	default:
		Unmanaged<Core>.fromOpaque(object).takeUnretainedValue().note_on(note: note, velocity: velocity, channel: channel, group: group)
	}
}
@_cdecl("core_midi")
func midi(object: UnsafeMutableRawPointer, start: UnsafePointer<CUnsignedChar>, count: CLong) {
	Unmanaged<Core>.fromOpaque(object).takeUnretainedValue().midi_in(msg: .init(start: start, count: .init(count)))
}
@_cdecl("core_preset")
func preset(object: UnsafeMutableRawPointer, key: CChar, value: CLong) {
	switch key {
	case 0b000:
		Unmanaged<Core>.fromOpaque(object).takeUnretainedValue().preset(factory: .init(value))
	case 0b100:
		Unmanaged<Core>.fromOpaque(object).takeUnretainedValue().preset(load: .init(value))
	case 0b101:
		Unmanaged<Core>.fromOpaque(object).takeUnretainedValue().preset(save: .init(value))
	default:
		break
	}
}
@MainActor
@_cdecl("core_load")
func load(object: UnsafeMutableRawPointer, type: UInt32, subtype: UInt32, manufacturer: UInt32) {
	Unmanaged<Core>.fromOpaque(object).takeUnretainedValue().load(type: type, subtype: subtype, manufacturer: manufacturer)
}
@MainActor
@_cdecl("core_unload")
func unload(object: UnsafeMutableRawPointer) {
	Unmanaged<Core>.fromOpaque(object).takeUnretainedValue().unload()
}
@MainActor
@_cdecl("core_reload")
func reload(object: UnsafeMutableRawPointer) {
	Unmanaged<Core>.fromOpaque(object).takeUnretainedValue().reload()
}
