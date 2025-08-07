//
//  ToastManager.swift
//  Hermes
//
//  Created by Claude Code on 8/6/25.
//

import SwiftUI
import Foundation

/// Toast notification manager for showing temporary messages
@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: Toast?
    
    private init() {}
    
    /// Show a toast notification
    func show(
        message: String,
        type: ToastType = .info,
        duration: TimeInterval = 3.0,
        position: ToastPosition = .topRight
    ) {
        let toast = Toast(
            id: UUID(),
            message: message,
            type: type,
            duration: duration,
            position: position
        )
        
        currentToast = toast
        
        // Auto-hide after duration
        Task {
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if currentToast?.id == toast.id {
                withAnimation(.easeOut(duration: 0.3)) {
                    currentToast = nil
                }
            }
        }
    }
    
    /// Show success toast
    func showSuccess(_ message: String, duration: TimeInterval = 3.0) {
        show(message: message, type: .success, duration: duration)
    }
    
    /// Show error toast
    func showError(_ message: String, duration: TimeInterval = 4.0) {
        show(message: message, type: .error, duration: duration)
    }
    
    /// Show warning toast
    func showWarning(_ message: String, duration: TimeInterval = 3.5) {
        show(message: message, type: .warning, duration: duration)
    }
    
    /// Show info toast
    func showInfo(_ message: String, duration: TimeInterval = 3.0) {
        show(message: message, type: .info, duration: duration)
    }
    
    /// Hide current toast immediately
    func hide() {
        withAnimation(.easeOut(duration: 0.3)) {
            currentToast = nil
        }
    }
}

// MARK: - Toast Model

struct Toast: Identifiable, Equatable {
    let id: UUID
    let message: String
    let type: ToastType
    let duration: TimeInterval
    let position: ToastPosition
    let timestamp: Date = Date()
    
    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

enum ToastType: CaseIterable {
    case success
    case error
    case warning
    case info
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}

enum ToastPosition {
    case topLeft
    case topRight
    case topCenter
    case bottomLeft
    case bottomRight
    case bottomCenter
}

// MARK: - Toast View

struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: toast.type.icon)
                .foregroundColor(toast.type.color)
                .font(.system(size: 16, weight: .medium))
            
            // Message
            Text(toast.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Spacer(minLength: 0)
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(0.7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
                )
        }
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .frame(maxWidth: 350)
    }
}

// MARK: - Toast Container

struct ToastContainer: View {
    @StateObject private var toastManager = ToastManager.shared
    
    var body: some View {
        ZStack {
            if let toast = toastManager.currentToast {
                VStack {
                    HStack {
                        if toast.position == .topRight || toast.position == .topCenter {
                            Spacer()
                        }
                        
                        ToastView(toast: toast) {
                            toastManager.hide()
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        
                        if toast.position == .topLeft || toast.position == .topCenter {
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Bottom positions would go here
                }
                .allowsHitTesting(true)
                .zIndex(1000)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toastManager.currentToast?.id)
    }
}