import SwiftUI
import SupermojiKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = SupermojiViewModel()
    @State private var emojiInput: String = ""

    var body: some View {
        VStack(spacing: 20) {
            // Sequence strip
            sequenceStrip

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
                    Text("Add emoji or images to get started")
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

    private var sequenceStrip: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(viewModel.items.enumerated()), id: \.offset) { index, item in
                        frameSourceTile(item, at: index)
                    }

                    addImageButton
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .frame(height: 52)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers)
            }

            // Emoji text input
            HStack(spacing: 8) {
                TextField("Type emoji...", text: $emojiInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .onSubmit {
                        guard !emojiInput.isEmpty else { return }
                        viewModel.addEmoji(emojiInput)
                        emojiInput = ""
                    }

                Text("press return to add")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func frameSourceTile(_ item: FrameSource, at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch item {
                case .emoji(let char):
                    Text(char)
                        .font(.system(size: 24))
                case .image(let url):
                    if let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 40, height: 40)
            .background(.background, in: RoundedRectangle(cornerRadius: 6))

            Button {
                viewModel.removeItem(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
        .draggable(String(index)) {
            Text(itemLabel(item))
                .padding(4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
        }
        .dropDestination(for: String.self) { dropped, _ in
            guard let sourceStr = dropped.first,
                  let sourceIndex = Int(sourceStr),
                  sourceIndex != index else { return false }
            withAnimation {
                viewModel.items.move(
                    fromOffsets: IndexSet(integer: sourceIndex),
                    toOffset: sourceIndex < index ? index + 1 : index
                )
                viewModel.render()
            }
            return true
        }
    }

    private var addImageButton: some View {
        Button {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
            panel.allowsMultipleSelection = true
            guard panel.runModal() == .OK else { return }
            viewModel.addImages(urls: panel.urls)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(.background, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                viewModel.addImages(urls: urls)
            }
        }
        return true
    }

    private func itemLabel(_ item: FrameSource) -> String {
        switch item {
        case .emoji(let char): char
        case .image(let url): url.lastPathComponent
        }
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
