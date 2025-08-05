//
//  Knob.swift
//  mc.auv3_tilde
//
//  Created by Kota on 8/1/R7.
//
import AudioUnit
import SwiftUI
@MainActor
public struct Knob<Model: RangeValueModel>: SwiftUI.View {
	@State private var tapLocation: CGPoint = .zero
	@State private var releaseLocation: CGPoint = .zero
	@State private var distanceOnTap: CGFloat = 0.0
	@State private var distanceOnRelease: CGFloat = 0.0
	@State private var tap: CGPoint = .zero
	@State private var degree: Float64 = 0.0
	public var body: some SwiftUI.View {
		GeometryReader { geometry in
			let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
			ZStack {
				Group {
					Circle()
						.fill(LinearGradient(colors: [
							Color.white,
							Color.gray
						], startPoint: .top, endPoint: .bottom))
						.scaleEffect(1)
					ZStack {
						Circle()
							.fill(LinearGradient(colors: [
								Color.white,
								Color.gray,
								Color.white,
							], startPoint: .leading, endPoint: .trailing))
						Circle()
							.fill(LinearGradient(colors: [
								Color.white,
								Color.gray,
								Color.white,
							], startPoint: .top, endPoint: .bottom))
							.blendMode(.darken)
						//					Circle()
						//						.fill(EllipticalGradient(colors: [
						//							Color.white,
						//							Color.gray,
						//							Color.white,
						//							Color.gray,
						//							Color.white,
						//						], startRadiusFraction: 0.36, endRadiusFraction: 0.45))
						//						.blendMode(.colorBurn)
					}
					.scaleEffect(0.93)
				}
				.frame(width: geometry.size.width, height: geometry.size.height)
				.position(center)
				Group {
					Circle()
						.fill(EllipticalGradient(colors: [
							Color.white,
							Color.cyan,
							Color.white,
							Color.cyan,
							Color.blue,
						]))
					
					Circle()
						.fill(EllipticalGradient(colors: [
							Color.white,
							Color.gray,
						]))
						.blendMode(.screen)
				}
				.scaleEffect(0.1)
				.position(x: center.x + geometry.size.width / 2 * 0.75 * cos(degree),
						  y: center.y + geometry.size.height / 2 * 0.75 * sin(degree))
				
			}
			.gesture(
				DragGesture(minimumDistance: 0)
					.onChanged { value in
						let origin = CGPoint(x: geometry.size.width / 2,
											 y: geometry.size.height / 2)
						degree = atan2(value.location.x - origin.x,
									   value.location.y - origin.y)
						tapLocation = value.location
						distanceOnTap = distance(from: origin, to: tapLocation)
					}
					.onEnded { value in
						let origin = CGPoint(x: geometry.size.width / 2,
											 y: geometry.size.height / 2)
						releaseLocation = value.location
						distanceOnRelease = distance(from: origin, to: releaseLocation)
					}
			)
		}
	}
	private func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
		return sqrt(pow(point2.x - point1.x, 2) + pow(point2.y - point1.y, 2))
	}
}
struct AquaKnobView: SwiftUI.View {
	@ObservedObject var parameter: AUParameter
	@State private var angle: Angle = .zero
	@State private var isDragging = false
	private let knobSize: CGFloat = 70
	private let indicatorRadius: CGFloat = 4
	private let totalAngleRange = Angle(degrees: 270) // from -135˚ to +135˚
	var rotate: Angle {
		get {
			.degrees(fma(.init(parameter.normalizedValue), 300.0, -150.0))
		}
		nonmutating set {
			parameter.normalizedValue = min(1, max(0, .init(newValue.degrees + 150.0) / 300.0))
		}
	}
	var body: some SwiftUI.View {
		VStack(spacing: 10) {
			ZStack {
				// --- 1. Knob body
				ZStack {
					// base and shadow
					Circle()
						.fill(Color(white: 0.8))
						.frame(width: knobSize, height: knobSize)
						.shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
					// inner shadow for convex
					Circle()
						.stroke(Color.black.opacity(0.3), lineWidth: 1)
						.frame(width: knobSize - 1, height: knobSize - 1)
						.blur(radius: 1)
					// gradient for metalic texture
					Circle()
						.fill(
							RadialGradient(
								gradient: Gradient(colors: [Color(white: 0.95), Color(white: 0.6)]),
								center: .center,
								startRadius: 1,
								endRadius: knobSize / 2
							)
						)
						.frame(width: knobSize - 2, height: knobSize - 2)
					// Highlight for Aqua style
					Circle()
						.fill(
							LinearGradient(
								gradient: Gradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0.0)]),
								startPoint: .top,
								endPoint: .bottom
							)
						)
						.frame(width: knobSize - 10, height: knobSize - 10)
						.offset(y: -5)
						.blur(radius: 5)
					// Indicator for button
					Circle()
						.fill(Color.black.opacity(0.4))
						.frame(width: indicatorRadius * 2, height: indicatorRadius * 2)
						.offset(y: -knobSize / 2 + 12)
						.rotationEffect(rotate)
						.blur(radius: 0.5)
				}
				.gesture(DragGesture(minimumDistance: 0).onChanged { value in
					isDragging = true
					let Δ = CGVector(dx: value.location.x - knobSize / 2, dy: value.location.y - knobSize / 2)
					let θ = Angle(radians: atan2(Δ.dx, -Δ.dy))
					rotate = θ
				}.onEnded { action in
					isDragging = false
				})
				// --- 2. Blue ring to indicate
				Circle()
					.trim(from: 0, to: CGFloat(parameter.normalizedValue) * 300 / 360.0)
					.stroke(
						Color.blue.opacity(isDragging ? 0.8 : 0.2),
						style: StrokeStyle(lineWidth: 4, lineCap: .round)
					)
					.frame(width: knobSize + 12, height: knobSize + 12)
					.rotationEffect(.degrees(-240))
					.animation(.spring(), value: parameter.value)
					.animation(.spring(), value: isDragging)
					.allowsHitTesting(false)
			}
			.frame(width: knobSize + 20, height: knobSize + 20)
			// --- 3. Text
			VStack(spacing: 2) {
				Text(parameter.displayName)
					.font(.system(size: 12, weight: .medium, design: .default))
					.foregroundColor(Color(white: 0.3))
				Text(parameter.displayValue)
					.font(.system(.body, design: .monospaced))
					.foregroundColor(Color(white: 0.1))
					.frame(minHeight: 20)
			}
		}
		.onReceive(parameter.publisher(for: \.value)) { _ in
			parameter.objectWillChange.send()
		}
	}
}
extension Color {
	static let aquaPanelBrushedMetalStart = Color(white: 0.85)
	static let aquaPanelBrushedMetalEnd = Color(white: 0.7)
}
