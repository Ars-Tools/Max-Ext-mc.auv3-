//
//  View.swift
//  mc.auv3_tilde
//
//  Created by Kota on 7/25/R7.
//
import SwiftUI
import CoreAudioKit
struct View: SwiftUI.View {
	weak var core: Optional<Core>
	@State var select: AudioComponentDescription = .init()
	var components: Array<AVAudioUnitComponent> {
		Core.manager.components(matching: select)
	}
	var types: Array<AudioComponentComponent> {
		[.init(id: 0, description: "ANY")] + Set(components.map {
			.init(id: $0.audioComponentDescription.componentType, description: $0.typeName)
		}).sorted(using: KeyPathComparator(\.description))
	}
	var manufacturers: Array<AudioComponentComponent> {
		[.init(id: 0, description: "ANY")] + Set(components.map {
			.init(id: $0.audioComponentDescription.componentManufacturer, description: $0.manufacturerName)
		}).sorted(using: KeyPathComparator(\.description))
	}
	var body: some SwiftUI.View {
		VStack {
			HStack {
				Picker("Type", selection: $select.componentType) {
					ForEach(types, id: \.id) {
						Text($0.description)
					}
				}
				.pickerStyle(.menu)
				Picker("Manufacturer", selection: $select.componentManufacturer) {
					ForEach(manufacturers, id: \.id) {
						Text($0.description)
					}
				}
				.pickerStyle(.menu)
			}
			List {
				ForEach(components) { component in
					Button(component.name, systemImage: "waveform.circle") {
						if case.some(let core) = core {
							core.load(description: component.audioComponentDescription)
						}
					}
				}
			}
		}.padding(.all)
	}
}
struct UnitView: SwiftUI.View {
	weak var core: Optional<Core>
	@ObservedObject var unit: AUAudioUnit
	var factoryPreset: Binding<Int> {
		.init {
			unit.currentPreset.map(\.number) ?? 0
		} set: {
			core?.preset(factory: $0)
		}
	}
	var userPreset: Binding<Int> {
		.init {
			unit.currentPreset.map(\.number) ?? 0
		} set: {
			core?.preset(load: $0)
		}
	}
	var body: some SwiftUI.View {
		Group {
			if let factoryPreset = unit.factoryPresets {
				Picker("Factory Preset", selection: self.factoryPreset) {
					ForEach(factoryPreset, id: \.number) {
						Text($0.name)
					}
				}.pickerStyle(.automatic)
					.padding(.all)
			}
			if unit.supportsUserPresets {
				Picker("User Preset", selection: self.userPreset) {
					ForEach(unit.userPresets, id: \.number) {
						Text($0.name)
					}
				}.pickerStyle(.automatic)
					.padding(.all)
			}
			if let parameterTree = unit.parameterTree {
				ScrollView {
					LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)],
							  alignment: .center,
							  spacing: 30) {
						ForEach(parameterTree.allParameters, id: \.address, content: AquaKnobView.init(parameter:))
					}.padding()
				}
			}
		}.background(Rectangle()
			.fill(LinearGradient(gradient: Gradient(colors: [.aquaPanelBrushedMetalStart, .aquaPanelBrushedMetalEnd]),
								 startPoint: .top,
								 endPoint: .bottom))
				.edgesIgnoringSafeArea(.all)
		)
	}
}
