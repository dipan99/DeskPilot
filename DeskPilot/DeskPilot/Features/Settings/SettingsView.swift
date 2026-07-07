//
//  SettingsView.swift
//  DeskPilot
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.Keys.userName) private var userName = AppSettings.Defaults.userName
    @AppStorage(AppSettings.Keys.userLocation) private var userLocation = AppSettings.Defaults.userLocation
    @AppStorage(AppSettings.Keys.modelEndpoint) private var modelEndpoint = AppSettings.Defaults.modelEndpoint
    @AppStorage(AppSettings.Keys.modelName) private var modelName = AppSettings.Defaults.modelName
    @AppStorage(AppSettings.Keys.maxTokens) private var maxTokens = AppSettings.Defaults.maxTokens
    @AppStorage(AppSettings.Keys.conversationMemory) private var conversationMemory = AppSettings.Defaults.conversationMemory
    @AppStorage(AppSettings.Keys.responseStyle) private var responseStyle = AppSettings.Defaults.responseStyle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                profileSection

                assistantSection

                modelSection

                resetSection
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.largeTitle)
                .bold()
                .accessibilityIdentifier("Settings_title")

            Text("Configure your profile, assistant behavior, and local model settings.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var profileSection: some View {
        SettingsSection(title: "Profile", subtitle: "Used by the assistant to personalize answers when helpful.") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledContent("Your Name") {
                    TextField("Optional", text: $userName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)
                        .accessibilityIdentifier("settingsUserNameField")
                }

                LabeledContent("Your Location") {
                    TextField("City, state, or country", text: $userLocation)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)
                        .accessibilityIdentifier("settingsUserLocationField")
                }
            }
        }
    }

    private var assistantSection: some View {
        SettingsSection(title: "Assistant", subtitle: "Controls how much context the assistant sends and how it should respond.") {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Response Style", selection: $responseStyle) {
                    ForEach(AppSettings.ResponseStyle.allCases) { style in
                        Text(style.label).tag(style.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .accessibilityIdentifier("settingsResponseStylePicker")

                Stepper(value: $conversationMemory, in: 0...30) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Conversation Memory: \(conversationMemory) messages")
                        Text("Recent chat messages included with each assistant request.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("settingsConversationMemoryStepper")
            }
        }
    }

    private var modelSection: some View {
        SettingsSection(title: "Local Model", subtitle: "Settings used when DeskPilot talks to the local MLX-compatible server.") {
            VStack(alignment: .leading, spacing: 14) {
                LabeledContent("Server URL") {
                    TextField("MLX endpoint", text: $modelEndpoint)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 460)
                        .accessibilityIdentifier("settingsModelEndpointField")
                }

                LabeledContent("Model Name") {
                    TextField("Model name", text: $modelName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                        .accessibilityIdentifier("settingsModelNameField")
                }

                Stepper(value: $maxTokens, in: 256...8192, step: 256) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max Tokens: \(maxTokens)")
                        Text("Upper limit for the model response size.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("settingsMaxTokensStepper")
            }
        }
    }

    private var resetSection: some View {
        HStack {
            Spacer()

            Button("Reset to Defaults", role: .destructive) {
                AppSettings.reset()
                userName = AppSettings.Defaults.userName
                userLocation = AppSettings.Defaults.userLocation
                modelEndpoint = AppSettings.Defaults.modelEndpoint
                modelName = AppSettings.Defaults.modelName
                maxTokens = AppSettings.Defaults.maxTokens
                conversationMemory = AppSettings.Defaults.conversationMemory
                responseStyle = AppSettings.Defaults.responseStyle
            }
            .accessibilityIdentifier("settingsResetButton")
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    SettingsView()
}
