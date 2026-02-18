import SwiftUI

/// A single chat message bubble. User messages are right-aligned (blue),
/// assistant messages are left-aligned (gray). Shows cloud/local badge
/// and timestamp on hover.
struct ChatBubble: View {
    let message: Message
    @State private var isHovering = false

    private var isUser: Bool { message.role == .user }
    private var isCloud: Bool { message.metadata.wasCloud == true }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // Badge row for assistant messages
                if !isUser {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text("aiDAEMON")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)

                        if let wasCloud = message.metadata.wasCloud {
                            modelBadge(isCloud: wasCloud)
                        }
                    }
                }

                // Message content
                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundStyle(isUser ? .white : .primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Timestamp (shown on hover)
                if isHovering {
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
                )
        }
    }

    private func modelBadge(isCloud: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: isCloud ? "cloud.fill" : "desktopcomputer")
                .font(.system(size: 8))
            Text(isCloud ? "Cloud" : "Local")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(isCloud ? .blue : .secondary)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill((isCloud ? Color.blue : Color.secondary).opacity(0.12))
        )
    }
}

/// Typing indicator shown while the model is generating.
struct TypingIndicator: View {
    @State private var dotIndex = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("aiDAEMON")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 6, height: 6)
                            .opacity(dotIndex == i ? 1.0 : 0.3)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
                        )
                )
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, 8)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                dotIndex = (dotIndex + 1) % 3
            }
        }
    }
}

/// The main chat view that displays conversation history with auto-scroll.
struct ChatView: View {
    @ObservedObject var conversation: Conversation
    let isGenerating: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(conversation.messages) { message in
                        if message.role != .system {
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }

                    if isGenerating {
                        TypingIndicator()
                    }

                    // Invisible anchor at the very bottom for reliable scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("scroll-anchor")
                }
                .padding(.vertical, 8)
            }
            .onChange(of: conversation.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isGenerating) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("scroll-anchor", anchor: .bottom)
            }
        }
    }
}
