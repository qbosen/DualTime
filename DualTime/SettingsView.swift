import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredOptions: [TimeZoneOption] {
        guard !searchText.isEmpty else { return model.timeZoneOptions }
        let query = searchText.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: model.locale)
        return model.timeZoneOptions.filter {
            [$0.identifier, $0.name, $0.offset].contains { value in
                value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).localizedCaseInsensitiveContains(query)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.timeZone.title")
                    .font(.headline)
                TextField("settings.timeZone.searchPlaceholder", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                List(selection: Binding(get: { model.timeZoneIdentifier }, set: { model.timeZoneIdentifier = $0 })) {
                    ForEach(filteredOptions) { option in
                        HStack {
                            Text(option.name)
                            Spacer()
                            Text(option.offset)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .tag(option.identifier)
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 175, maxHeight: .infinity)
                .layoutPriority(1)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("settings.display.title")
                    .font(.headline)
                Toggle("settings.display.showDate", isOn: $model.showDate)
                Toggle("settings.display.showWeekday", isOn: $model.showWeekday)
                Toggle("settings.display.flashSeparators", isOn: $model.flashTimeSeparators)
                Toggle("settings.display.showSeconds", isOn: $model.showSeconds)
            }

            HStack {
                Text("settings.language")
                Spacer()
                Picker("", selection: $model.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayNameKey).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Toggle("settings.launchAtLogin", isOn: $model.launchAtLogin)
            if let error = model.loginItemError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("settings.quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 520)
        .environment(\.locale, model.locale)
        .onAppear { model.markOnboardingComplete() }
    }
}
