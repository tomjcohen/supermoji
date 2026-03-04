import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SupermojiViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Emoji input
            TextField("Type emoji here...", text: $viewModel.emojiText)
                .textFieldStyle(.plain)
                .font(.system(size: 32))
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                .onChange(of: viewModel.emojiText) {
                    viewModel.render()
                }

            // Preview
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quinary)

                if let frame = viewModel.currentFrame {
                    Image(nsImage: frame)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .padding(32)
                } else {
                    Text("Your emoji will appear here")
                        .foregroundStyle(.tertiary)
                        .font(.body)
                }
            }
            .frame(height: 220)

            // Controls
            VStack(spacing: 12) {
                LabeledPicker(title: "Size", selection: $viewModel.size) {
                    ForEach(EmojiSize.allCases, id: \.self) { size in
                        Text(size.label).tag(size)
                    }
                }
                .onChange(of: viewModel.size) {
                    viewModel.render()
                }

                LabeledPicker(title: "Speed", selection: $viewModel.speed) {
                    ForEach(EmojiSpeed.allCases, id: \.self) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
                .onChange(of: viewModel.speed) {
                    viewModel.startAnimation()
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: viewModel.copyToClipboard) {
                    Label(viewModel.copied ? "Copied!" : "Copy",
                          systemImage: viewModel.copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(viewModel.frames.isEmpty)

                Button(action: viewModel.save) {
                    Label("Save GIF", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.frames.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

struct LabeledPicker<SelectionValue: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: SelectionValue
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)

            Picker(title, selection: $selection) {
                content()
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}
