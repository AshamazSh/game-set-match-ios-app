import SwiftUI

/// Local presentation state prevents a retained snapshot from replaying on appearance.
struct SideChangeNotification: ViewModifier {
    let event: SideChangeEvent?
    @State private var presented: SideChangeEvent?

    func body(content: Content) -> some View {
        ZStack {
            #if os(watchOS)
            content.opacity(presented == nil ? 1 : 0)
                .allowsHitTesting(presented == nil)
            #else
            content
            #endif
            if let presented {
                SideChangeAnimation {
                    if self.presented?.id == presented.id { self.presented = nil }
                }
                .id(presented.id)
                .allowsHitTesting(false)
                .zIndex(10)
            }
        }
        #if os(watchOS)
        .onChange(of: event) { value in present(value) }
        #else
        .onChange(of: event) { _, value in present(value) }
        #endif
    }

    private func present(_ value: SideChangeEvent?) {
        presented = value?.isRecent == true ? value : nil
    }
}

private struct SideChangeAnimation: View {
    let completion: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opacity = 0.0
    @State private var degrees = 0.0

    private var symbol: String {
        if #available(iOS 18.0, watchOS 11.0, *) {
            return "arrow.trianglehead.2.clockwise.rotate.90"
        }
        return "arrow.triangle.2.circlepath"
    }

    private var icon: some View {
        Image(systemName: symbol)
            .font(.system(size: 64, weight: .medium))
            .foregroundStyle(.white)
            .rotationEffect(.degrees(degrees))
            .accessibilityHidden(true)
    }

    private var notificationContent: some View {
        VStack(spacing: 12) {
            icon.frame(width: 72, height: 72)
            Text("Change sides")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
    }

    var body: some View {
        ZStack {
            #if os(watchOS)
            Color.black.ignoresSafeArea()
            notificationContent.padding(16).opacity(opacity)
            #else
            notificationContent
                .padding(20)
                .frame(minWidth: 160, minHeight: 160)
                .background(Color(white: 0.7), in: RoundedRectangle(cornerRadius: 24))
                .opacity(opacity)
            #endif
        }
        .accessibilityIdentifier("sideChangeNotification")
        .task {
            withAnimation(.linear(duration: 0.3)) { opacity = 1 }
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(.linear(duration: 0.5)) { degrees = reduceMotion ? 0 : 180 }
                try await Task.sleep(nanoseconds: 500_000_000)
                // Keep the completed rotation visible briefly before fading out.
                try await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(.linear(duration: 0.3)) { opacity = 0 }
                try await Task.sleep(nanoseconds: 300_000_000)
                completion()
            } catch { /* A newer notification or a dismissed match cancels this animation. */ }
        }
    }
}
