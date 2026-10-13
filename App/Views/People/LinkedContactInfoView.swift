import SwiftUI

/// Shows the details copied from a linked contact, with call, message, email,
/// map and web shortcuts.
struct LinkedContactInfoView: View {
    let contact: ContactSnapshot
    var onUnlink: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(contact.name).font(.title2).fontWeight(.semibold)
                    if let organization = contact.organization {
                        LabeledContent("Organization", value: organization)
                    }
                    if let jobTitle = contact.jobTitle {
                        LabeledContent("Job Title", value: jobTitle)
                    }
                    if let birthday = contact.birthday {
                        LabeledContent("Birthday", value: birthday)
                    }
                }

                if !contact.phones.isEmpty {
                    Section("Phone") {
                        ForEach(contact.phones, id: \.self) { phone in
                            HStack {
                                Text(phone)
                                Spacer()
                                actionLink("phone.fill", label: "Call", url: Self.phoneURL(scheme: "tel", phone))
                                actionLink("message.fill", label: "Message", url: Self.phoneURL(scheme: "sms", phone))
                            }
                        }
                    }
                }

                if !contact.emails.isEmpty {
                    Section("Email") {
                        ForEach(contact.emails, id: \.self) { email in
                            HStack {
                                Text(email).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                actionLink("envelope.fill", label: "Email", url: Self.mailURL(email))
                            }
                        }
                    }
                }

                if !contact.addresses.isEmpty {
                    Section("Address") {
                        ForEach(contact.addresses, id: \.self) { address in
                            HStack(alignment: .top) {
                                Text(address)
                                Spacer()
                                actionLink("map.fill", label: "Open in Maps", url: Self.mapURL(address))
                            }
                        }
                    }
                }

                if !contact.urls.isEmpty {
                    Section("Websites") {
                        ForEach(contact.urls, id: \.self) { raw in
                            HStack {
                                Text(raw).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                actionLink("safari.fill", label: "Open", url: Self.webURL(raw))
                            }
                        }
                    }
                }

                Section {
                    Button("Unlink Contact", role: .destructive) {
                        onUnlink()
                        dismiss()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Contact Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func actionLink(_ systemImage: String, label: String, url: URL?) -> some View {
        if let url {
            Link(destination: url) {
                Image(systemName: systemImage)
            }
            .accessibilityLabel(label)
        }
    }

    // MARK: URL builders

    static func phoneURL(scheme: String, _ phone: String) -> URL? {
        let digits = phone.filter { "+0123456789".contains($0) }
        guard !digits.isEmpty else { return nil }
        return URL(string: "\(scheme):\(digits)")
    }

    static func mailURL(_ email: String) -> URL? {
        guard let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "mailto:\(encoded)")
    }

    static func mapURL(_ address: String) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "address", value: address.replacingOccurrences(of: "\n", with: ", "))]
        return components?.url
    }

    static func webURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.lowercased().hasPrefix("http") ? trimmed : "https://\(trimmed)"
        return URL(string: withScheme)
    }
}
