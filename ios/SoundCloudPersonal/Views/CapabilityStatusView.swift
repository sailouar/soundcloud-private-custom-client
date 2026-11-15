import SwiftUI
import SoundCloudCore

struct CapabilityStatusViewModel: Equatable {
    let title: String
    let detail: String

    init(response: CapabilityResponse) {
        title = response.state.displayName
        detail = response.reason ?? "No additional explanation was supplied."
    }
}

struct CapabilityStatusView: View {
    let model: CapabilityStatusViewModel

    init(response: CapabilityResponse) {
        model = CapabilityStatusViewModel(response: response)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SoundCloud capability")
                .font(.headline)
            Text(model.title)
                .font(.title3)
            Text(model.detail)
                .foregroundStyle(.secondary)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

private extension CapabilityState {
    var displayName: String {
        switch self {
        case .supported:
            return "Supported"
        case .unsupported:
            return "Unsupported"
        case .requiresUserPermission:
            return "Requires user permission"
        case .temporarilyUnavailable:
            return "Temporarily unavailable"
        }
    }
}
