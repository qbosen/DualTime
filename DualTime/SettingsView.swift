import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredOptions: [TimeZoneOption] {
        guard !searchText.isEmpty else { return model.timeZoneOptions }
        let query = searchText.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: model.language == .chinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US"))
        return model.timeZoneOptions.filter {
            [$0.identifier, $0.name, $0.offset].contains { value in
                value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).localizedCaseInsensitiveContains(query)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.language == .chinese ? "显示时区" : "Display time zone")
                    .font(.headline)
                TextField(model.language == .chinese ? "搜索城市或时区" : "Search city or time zone", text: $searchText)
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
                Text(model.language == .chinese ? "时间显示" : "Time display")
                    .font(.headline)
                Toggle(model.language == .chinese ? "显示日期" : "Show date", isOn: $model.showDate)
                Toggle(model.language == .chinese ? "显示星期" : "Show day of the week", isOn: $model.showWeekday)
                Toggle(model.language == .chinese ? "闪烁时间分隔符" : "Flash the time separators", isOn: $model.flashTimeSeparators)
                Toggle(model.language == .chinese ? "显示秒" : "Display the time with seconds", isOn: $model.showSeconds)
            }

            HStack {
                Text(model.language == .chinese ? "语言" : "Language")
                Spacer()
                Picker("", selection: $model.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Toggle(model.language == .chinese ? "登录时启动" : "Launch at login", isOn: $model.launchAtLogin)
            if let error = model.loginItemError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(model.language == .chinese ? "退出应用" : "Quit DualTime") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 520)
        .onAppear { model.markOnboardingComplete() }
    }
}
