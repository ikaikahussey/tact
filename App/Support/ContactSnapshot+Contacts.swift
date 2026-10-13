import Contacts

extension ContactSnapshot {
    /// Keys Tact reads from a contact. The Notes field is deliberately excluded:
    /// it requires a special entitlement and fetching it fails without one.
    static let fetchKeys: [CNKeyDescriptor] = [
        CNContactGivenNameKey,
        CNContactFamilyNameKey,
        CNContactPhoneNumbersKey,
        CNContactEmailAddressesKey,
        CNContactPostalAddressesKey,
        CNContactBirthdayKey,
        CNContactOrganizationNameKey,
        CNContactJobTitleKey,
        CNContactUrlAddressesKey,
    ].map { $0 as CNKeyDescriptor }

    /// Copies the available fields. Fields the contact was not fetched with are
    /// skipped instead of raising an exception.
    init(contact: CNContact) {
        func has(_ key: String) -> Bool { contact.isKeyAvailable(key) }

        let given = has(CNContactGivenNameKey) ? contact.givenName : ""
        let family = has(CNContactFamilyNameKey) ? contact.familyName : ""
        let organization = has(CNContactOrganizationNameKey) ? contact.organizationName : ""
        var name = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
        if name.isEmpty { name = organization }
        if name.isEmpty { name = "Contact" }

        self.name = name
        phones = has(CNContactPhoneNumbersKey) ? contact.phoneNumbers.map { $0.value.stringValue } : []
        emails = has(CNContactEmailAddressesKey) ? contact.emailAddresses.map { String($0.value) } : []
        addresses = has(CNContactPostalAddressesKey)
            ? contact.postalAddresses.map { CNPostalAddressFormatter.string(from: $0.value, style: .mailingAddress) }
            : []
        birthday = has(CNContactBirthdayKey) ? contact.birthday.flatMap { Self.format(birthday: $0) } : nil
        self.organization = organization.isEmpty ? nil : organization
        let title = has(CNContactJobTitleKey) ? contact.jobTitle : ""
        jobTitle = title.isEmpty ? nil : title
        urls = has(CNContactUrlAddressesKey) ? contact.urlAddresses.map { String($0.value) } : []
    }

    /// "March 4" or "March 4, 1990", in the user's locale.
    static func format(birthday: DateComponents, locale: Locale = .current) -> String? {
        guard let month = birthday.month, let day = birthday.day else { return nil }
        var components = DateComponents()
        components.year = birthday.year ?? 2000   // leap year, so Feb 29 is valid
        components.month = month
        components.day = day
        guard let date = Calendar(identifier: .gregorian).date(from: components) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(birthday.year == nil ? "MMMMd" : "yMMMMd")
        return formatter.string(from: date)
    }
}
