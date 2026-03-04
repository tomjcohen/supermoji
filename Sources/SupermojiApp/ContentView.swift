import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SupermojiViewModel()

    var body: some View {
        VStack(spacing: 16) {
            // Emoji input
            TextField("Type emoji here...", text: $viewModel.emojiText)
                .textFieldStyle(.roundedBorder)
                .font(.title)
                .onChange(of: viewModel.emojiText) {
                    viewModel.render()
                }

            // Preview
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)

                if let frame = viewModel.currentFrame {
                    Image(nsImage: frame)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .padding(24)
                } else {
                    Text("Your emoji will appear here")
                        .foregroundStyle(.secondary)
                        .font(.body)
                }
            }
            .frame(height: 256)

            // Controls
            HStack {
                Picker("Size", selection: $viewModel.size) {
                    ForEach(EmojiSize.allCases, id: \.self) { size in
                        Text(size.label).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.size) {
                    viewModel.render()
                }

                Picker("Speed", selection: $viewModel.speed) {
                    ForEach(EmojiSpeed.allCases, id: \.self) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.speed) {
                    viewModel.render()
                }
            }

            // Save button
            Button(action: viewModel.save) {
                Label("Save GIF", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.frames.isEmpty)
        }
        .padding(24)
        .frame(width: 360)
    }
}
