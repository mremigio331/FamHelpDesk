import SwiftUI

/// A reusable back button component that integrates with NavigationContext
struct BackButton: View {
    @State private var navigationContext = NavigationContext.shared
    let title: String?
    let action: (() -> Void)?

    init(title: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: {
            if let customAction = action {
                customAction()
            } else {
                navigationContext.popBack()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))

                if let title {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .foregroundColor(.blue)
        }
        .disabled(!navigationContext.canNavigateBack && action == nil)
    }
}

/// A navigation toolbar that includes back button and breadcrumbs
struct NavigationToolbar: View {
    @State private var navigationContext = NavigationContext.shared
    let title: String
    let showBackButton: Bool
    let customBackAction: (() -> Void)?

    init(title: String, showBackButton: Bool = true, customBackAction: (() -> Void)? = nil) {
        self.title = title
        self.showBackButton = showBackButton
        self.customBackAction = customBackAction
    }

    var body: some View {
        HStack {
            // Back button
            if showBackButton, navigationContext.canNavigateBack || customBackAction != nil {
                BackButton(action: customBackAction)
            }

            // Title
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            // Breadcrumb indicator
            if !navigationContext.navigationBreadcrumbs.isEmpty {
                Text("\(navigationContext.navigationDepth)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
    }
}

/// A breadcrumb navigation component
struct BreadcrumbNavigation: View {
    @State private var navigationContext = NavigationContext.shared

    var body: some View {
        if !navigationContext.navigationBreadcrumbs.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(navigationContext.navigationBreadcrumbs.enumerated()), id: \.offset) { index, breadcrumb in
                        HStack(spacing: 4) {
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Button(breadcrumb) {
                                // Navigate back to this breadcrumb level
                                let itemsToRemove = navigationContext.navigationBreadcrumbs.count - index - 1
                                if itemsToRemove > 0 {
                                    for _ in 0 ..< itemsToRemove {
                                        navigationContext.popBack()
                                    }
                                }
                            }
                            .font(.caption)
                            .foregroundColor(index == navigationContext.navigationBreadcrumbs.count - 1 ? .primary : .blue)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 4)
            .background(Color(uiColor: .secondarySystemBackground))
        }
    }
}

#Preview {
    VStack {
        NavigationToolbar(title: "Sample View")
        BreadcrumbNavigation()
        Spacer()
    }
}
