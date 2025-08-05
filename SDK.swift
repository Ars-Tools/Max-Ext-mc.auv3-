//
//  SDK.swift
//  mc.auv3_tilde
//
//  Created by Kota on 7/26/R7.
//
import Darwin
enum SDK {
	@_silgen_name("post")
	static func Post(_ msg: UnsafePointer<CChar>)
	@_silgen_name("object_post")
	static func Print(_ object: UnsafeRawPointer, _ msg: UnsafePointer<CChar>)
	@_silgen_name("object_error")
	static func Error(_ object: UnsafeRawPointer, _ msg: UnsafePointer<CChar>)
	@_silgen_name("parameter_in")
	static func ParameterIn(_ this: UnsafeRawPointer, _ address: UInt64, _ value: Float64)
	@_silgen_name("parameter_out")
	static func ParameterOut(_ this: UnsafeRawPointer, _ address: UInt64, _ value: Float64)
	@_silgen_name("midi_in")
	static func MIDIIn(_ this: UnsafeRawPointer, _ msg: UnsafePointer<UInt8>, _ count: UInt64)
	@_silgen_name("midi_out")
	static func MIDIOut(_ this: UnsafeRawPointer, _ msg: UnsafePointer<UInt8>, _ count: UInt64)
	@_silgen_name("preset_in")
	static func PresetIn(_ this: UnsafeRawPointer, _ type: FourCharCode, _ subtype: FourCharCode, _ manufacturer: FourCharCode)
	@_silgen_name("preset_out")
	static func PresetOut(_ this: UnsafeRawPointer, _ str: UnsafePointer<CChar>, _ value: CLong)
	@_silgen_name("load_in")
	static func LoadIn(_ this: UnsafeRawPointer, _ type: FourCharCode, _ subtype: FourCharCode, _ manufacturer: FourCharCode)
	@_silgen_name("load_out")
	static func LoadOut(_ this: UnsafeRawPointer, _ type: FourCharCode, _ subtype: FourCharCode, _ manufacturer: FourCharCode)
}
