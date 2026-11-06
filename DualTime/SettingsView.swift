import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var isAddingClock = false
    @State private var draggedClockID: UUID?

    var body: some View {
        TabView {
            menuBarSettings
                .tabItem { Label("settings.tab.menuBar", systemImage: "menubar.rectangle") }
            clockSettings
                .tabItem { Label("settings.tab.clocks", systemImage: "globe") }
            behaviorSettings
                .tabItem { Label("settings.tab.behavior", systemImage: "cursorarrow") }
            generalSettings
                .tabItem { Label("settings.tab.general", systemImage: "gearshape") }
        }
        .padding(20)
        .frame(minWidth: 580, minHeight: 600)
        .environment(\.locale, model.locale)
        .onAppear { model.markOnboardingComplete() }
        .sheet(isPresented: $isAddingClock) {
            ClockZonePicker(model: model) { identifier in
                model.worldClocks.append(WorldClock(timeZoneIdentifier: identifier))
                isAddingClock = false
            }
        }
    }

    private var menuBarSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("settings.timeZone.title").font(.headline)
            ClockZoneList(model: model, selection: $model.timeZoneIdentifier)
                .frame(minHeight: 180)
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("settings.display.showDate", isOn: $model.showDate)
                    Toggle("settings.display.showWeekday", isOn: $model.showWeekday)
                    Toggle("settings.display.showSeconds", isOn: $model.showSeconds)
                    Toggle("settings.display.flashSeparators", isOn: $model.flashTimeSeparators)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            } label: { Text("settings.display.title") }
            Text(model.displayText)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(16)
    }

    private var clockSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("settings.tab.clocks").font(.headline)
                    Spacer()
                    Button { isAddingClock = true } label: {
                        Label("clocks.add", systemImage: "plus")
                    }
                }
                VStack(spacing: 0) {
                    ForEach(Array(model.worldClocks.enumerated()), id: \.element.id) { index, clock in
                        HStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(Text("clocks.reorder"))
                                .onDrag {
                                    draggedClockID = clock.id
                                    return NSItemProvider(object: clock.id.uuidString as NSString)
                                }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(clock.name(style: .full, language: model.language))
                                Text(clock.timeZoneIdentifier).font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if model.clockListFormat.nameStyle == .custom {
                                TextField("clocks.customName", text: customNameBinding(for: clock.id))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 130)
                            }
                            Button { model.worldClocks.swapAt(index, index - 1) } label: {
                                Image(systemName: "chevron.up")
                            }
                            .disabled(index == 0)
                            .help(Text("clocks.moveUp"))
                            Button { model.worldClocks.swapAt(index, index + 1) } label: {
                                Image(systemName: "chevron.down")
                            }
                            .disabled(index == model.worldClocks.count - 1)
                            .help(Text("clocks.moveDown"))
                            Button { model.worldClocks.removeAll { $0.id == clock.id } } label: {
                                Image(systemName: "minus")
                            }
                            .disabled(model.worldClocks.count == 1)
                            .help(Text("clocks.remove"))
                        }
                        .padding(10)
                        .contentShape(Rectangle())
                        .onDrop(of: [UTType.text], isTargeted: nil) { _ in
                            guard let sourceID = draggedClockID,
                                  let source = model.worldClocks.firstIndex(where: { $0.id == sourceID }),
                                  let target = model.worldClocks.firstIndex(where: { $0.id == clock.id }) else { return false }
                            let moved = model.worldClocks.remove(at: source)
                            model.worldClocks.insert(moved, at: target)
                            draggedClockID = nil
                            return true
                        }
                        if index < model.worldClocks.count - 1 { Divider() }
                    }
                }
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                Text("clocks.orderHint").font(.caption).foregroundStyle(.secondary)
                Form {
                    Picker("clocks.nameStyle", selection: $model.clockListFormat.nameStyle) {
                        ForEach(ClockNameStyle.allCases) { style in Text(style.label).tag(style) }
                    }
                    Picker("clocks.dateStyle", selection: $model.clockListFormat.dateStyle) {
                        ForEach(ClockDateStyle.allCases) { style in Text(style.label).tag(style) }
                    }
                    Toggle("settings.display.showWeekday", isOn: $model.clockListFormat.showWeekday)
                    Toggle("clocks.use24Hour", isOn: $model.clockListFormat.use24Hour)
                    Toggle("settings.display.showSeconds", isOn: $model.clockListFormat.showSeconds)
                }
                Text("clocks.preview").font(.headline)
                ClockListView(model: model)
                    .frame(maxWidth: .infinity)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(16)
        }
    }

    private var behaviorSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                VStack(spacing: 18) {
                    HStack {
                        Text("behavior.pointerExit")
                        Spacer()
                        Picker("behavior.pointerExit", selection: $model.pointerExitDelay) {
                            ForEach(PointerExitDelay.allCases) { delay in
                                Text(LocalizedStringKey(delay.localizationKey)).tag(delay)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    HStack {
                        Text("behavior.outsideClick")
                        Spacer()
                        Toggle("behavior.outsideClick", isOn: $model.closeOnOutsideClick)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
                .padding(12)
            } label: { Text("behavior.rehide").font(.headline) }
            Text("behavior.hint")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var generalSettings: some View {
        Form {
            Picker("settings.language", selection: $model.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayNameKey).tag(language)
                }
            }
            Toggle("settings.launchAtLogin", isOn: $model.launchAtLogin)
            if let error = model.loginItemError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func customNameBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { model.worldClocks.first { $0.id == id }?.customName ?? "" },
            set: { value in
                if let index = model.worldClocks.firstIndex(where: { $0.id == id }) {
                    model.worldClocks[index].customName = value
                }
            }
        )
    }
}

private struct ClockZoneList: View {
    @ObservedObject var model: AppModel
    @Binding var selection: String
    @State private var searchText = ""

    private var filteredOptions: [TimeZoneOption] {
        guard !searchText.isEmpty else { return model.timeZoneOptions }
        return model.timeZoneOptions.filter { option in
            [option.identifier, option.name, option.offset].contains {
                $0.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive], locale: model.locale) != nil
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            TextField("settings.timeZone.searchPlaceholder", text: $searchText)
                .textFieldStyle(.roundedBorder)
            List(selection: $selection) {
                ForEach(filteredOptions) { option in
                    HStack {
                        Text(option.name)
                        Spacer()
                        Text(option.offset).foregroundStyle(.secondary).font(.caption)
                    }
                    .tag(option.identifier)
                }
            }
            .listStyle(.inset)
        }
    }
}

private struct ClockZonePicker: View {
    @ObservedObject var model: AppModel
    var onSelect: (String) -> Void
    @State private var selection = "Asia/Shanghai"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("clocks.add").font(.headline)
            ClockZoneList(model: model, selection: $selection)
            HStack {
                Spacer()
                Button("clocks.cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("clocks.add") { onSelect(selection) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440, height: 460)
        .environment(\.locale, model.locale)
    }
}

struct ClockListView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: Date(timeIntervalSince1970: 0), by: model.clockListFormat.showSeconds ? 1 : 60)) { context in
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                ForEach(model.worldClocks) { clock in
                    if let zone = TimeZone(identifier: clock.timeZoneIdentifier) {
                        GridRow {
                            Text(clock.name(style: model.clockListFormat.nameStyle, language: model.language))
                            Text(model.clockListFormat.dateText(at: context.date, in: zone, language: model.language))
                                .foregroundStyle(.secondary)
                            Text(model.clockListFormat.timeText(at: context.date, in: zone, language: model.language))
                                .monospacedDigit()
                                .gridColumnAlignment(.trailing)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .font(.system(size: 13))
            .fixedSize()
            .padding(16)
        }
        .environment(\.locale, model.locale)
    }
}
