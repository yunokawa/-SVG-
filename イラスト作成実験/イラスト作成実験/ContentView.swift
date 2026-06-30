import SwiftUI
import PencilKit
import UIKit
import WebKit
import UniformTypeIdentifiers

// MARK: - ContentView

struct ContentView: View {
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()

    @State private var selectedColor: Color = .black
    @State private var lineWidth: CGFloat = 5.0
    @State private var selectedPaperSize: PaperSize = .a4
    @State private var paperOrientation: PaperOrientation = .portrait

    @State private var targetPointCount: Double = 120
    @State private var opacity: Double = 1.0
    @State private var isEraserMode: Bool = false

    @State private var isPaperMoveMode: Bool = false
    @State private var guideOffset: CGSize = .zero

    // 描画モード用：イラストと用紙枠をまとめて見るための表示ズーム
    @State private var workspaceZoom: CGFloat = 1.0
    @State private var lastWorkspaceZoom: CGFloat = 1.0

    // 用紙設定用：用紙枠そのものの倍率。SVG出力範囲にも反映する
    @State private var paperGuideZoom: CGFloat = 1.0
    @State private var lastPaperGuideZoom: CGFloat = 1.0

    @State private var canvasSize: CGSize = .zero

    @State private var showPreview = false
    @State private var previewSVG = ""
    @State private var isPreviewLoading = false

    @State private var showFileNameAlert = false
    @State private var fileName = "drawing"

    @State private var svgDocument = SVGDocument(text: "")
    @State private var showFileExporter = false

    @State private var showHistory = false
    @State private var saveHistory: [SaveHistoryItem] = []

    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - 上部バー
            Group {
                if isPaperMoveMode {
                    PaperModeBar(
                        selectedPaperSize: $selectedPaperSize,
                        paperOrientation: $paperOrientation,
                        isPaperMoveMode: $isPaperMoveMode,
                        guideOffset: $guideOffset,
                        paperGuideZoom: $paperGuideZoom,
                        lastPaperGuideZoom: $lastPaperGuideZoom
                    )
                } else {
                    MainToolBar(
                        canvasView: canvasView,
                        selectedColor: $selectedColor,
                        lineWidth: $lineWidth,
                        opacity: $opacity,
                        targetPointCount: $targetPointCount,
                        isPaperMoveMode: $isPaperMoveMode,
                        isEraserMode: $isEraserMode,
                        workspaceZoom: $workspaceZoom,
                        lastWorkspaceZoom: $lastWorkspaceZoom,
                        onUpdateTool: {
                            updatePencilTool()
                        },
                        onClear: {
                            showClearConfirmation = true
                        },
                        onPreview: {
                            showSVGPreview()
                        },
                        onHistory: {
                            showHistory = true
                        },
                        onSave: {
                            promptForSave()
                        }
                    )
                }
            }
            .zIndex(10)

            // MARK: - キャンバス領域
            GeometryReader { geometry in
                ZStack {
                    Color.white

                    PencilCanvas(
                        canvasView: $canvasView,
                        toolPicker: $toolPicker,
                        selectedColor: $selectedColor,
                        lineWidth: $lineWidth,
                        opacity: $opacity,
                        isEraserMode: $isEraserMode,
                        isDrawingEnabled: !isPaperMoveMode
                    )
                    .background(Color.white)
                    .scaleEffect(isPaperMoveMode ? 1.0 : workspaceZoom)

                    PaperGuideView(
                        paperSize: selectedPaperSize,
                        orientation: paperOrientation,
                        guideOffset: $guideOffset,
                        isMoveMode: isPaperMoveMode,
                        canvasSize: geometry.size,
                        currentZoom: isPaperMoveMode ? paperGuideZoom : workspaceZoom * paperGuideZoom
                    )
                    .scaleEffect(isPaperMoveMode ? paperGuideZoom : workspaceZoom * paperGuideZoom)
                    .allowsHitTesting(isPaperMoveMode)

                    if isPaperMoveMode {
                        VStack {
                            Text("用紙設定モード")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.white.opacity(0.92))
                                .cornerRadius(8)
                                .shadow(radius: 1)

                            Spacer()
                        }
                        .padding(.top, 12)
                    }
                }
                .contentShape(Rectangle())
                .clipped()
                .onAppear {
                    canvasSize = geometry.size
                }
                .onChange(of: geometry.size) { _ in
                    canvasSize = geometry.size
                }
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            if isPaperMoveMode {
                                let newZoom = lastPaperGuideZoom * value
                                paperGuideZoom = min(max(newZoom, 0.5), 4.0)
                            } else {
                                let newZoom = lastWorkspaceZoom * value
                                workspaceZoom = min(max(newZoom, 0.5), 4.0)
                            }
                        }
                        .onEnded { _ in
                            if isPaperMoveMode {
                                lastPaperGuideZoom = paperGuideZoom
                            } else {
                                lastWorkspaceZoom = workspaceZoom
                            }
                        }
                )
                .zIndex(0)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPaperMoveMode)

        // MARK: - SVGプレビュー
        .sheet(isPresented: $showPreview) {
            NavigationView {
                ZStack {
                    if isPreviewLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.4)

                            Text("SVGを読み込み中...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        SVGPreviewView(svgText: previewSVG)
                    }
                }
                .navigationTitle("SVGプレビュー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("保存") {
                            showPreview = false

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                promptForSave()
                            }
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") {
                            showPreview = false
                            isPreviewLoading = false
                        }
                    }
                }
            }
        }

        // MARK: - 保存履歴
        .sheet(isPresented: $showHistory) {
            NavigationView {
                List {
                    if saveHistory.isEmpty {
                        Text("まだ保存履歴はありません")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(saveHistory) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.fileName)
                                    .font(.headline)

                                Text(item.paperDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .navigationTitle("保存履歴")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") {
                            showHistory = false
                        }
                    }
                }
            }
        }

        // MARK: - 全消去確認
        .confirmationDialog(
            "すべての線を削除しますか？",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("全消去", role: .destructive) {
                canvasView.drawing = PKDrawing()
            }

            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せますが、誤操作防止のため確認しています。")
        }

        // MARK: - ファイル名入力
        .alert("保存するファイル名", isPresented: $showFileNameAlert) {
            TextField("ファイル名", text: $fileName)

            Button("キャンセル", role: .cancel) {}

            Button("保存") {
                fileName = normalizedSVGFileName(fileName)
                svgDocument = SVGDocument(text: exportSVG(from: canvasView.drawing))
                showFileExporter = true
            }
        } message: {
            Text("\(selectedPaperSize.displayName)・\(paperOrientation.displayName) のSVGとして保存します。")
        }

        // MARK: - ファイル保存
        .fileExporter(
            isPresented: $showFileExporter,
            document: svgDocument,
            contentType: .svgDocument,
            defaultFilename: fileName
        ) { result in
            switch result {
            case .success(let url):
                recordSaveHistory(fileName: url.lastPathComponent)
                print("保存成功: \(url)")
            case .failure(let error):
                print("保存失敗: \(error)")
            }
        }

        .onAppear {
            loadSaveHistory()
            updatePencilTool()
        }
    }

    // MARK: - アクション

    func showSVGPreview() {
        isPreviewLoading = true
        previewSVG = ""
        showPreview = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            previewSVG = exportSVG(from: canvasView.drawing)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isPreviewLoading = false
            }
        }
    }

    func promptForSave() {
        fileName = "drawing_\(Int(Date().timeIntervalSince1970))"
        showFileNameAlert = true
    }

    func normalizedSVGFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty ? "drawing" : trimmed

        if baseName.lowercased().hasSuffix(".svg") {
            return baseName
        } else {
            return baseName + ".svg"
        }
    }

    // MARK: - ペン / 消しゴム切り替え

    func updatePencilTool() {
        if isEraserMode {
            canvasView.tool = PKEraserTool(.bitmap)
        } else {
            let uiColor = UIColor(selectedColor).withAlphaComponent(CGFloat(opacity))
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: lineWidth)
        }
    }

    // MARK: - 保存履歴

    func loadSaveHistory() {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.saveHistory),
              let decoded = try? JSONDecoder().decode([SaveHistoryItem].self, from: data) else {
            saveHistory = []
            return
        }

        saveHistory = decoded
    }

    func storeSaveHistory() {
        guard let data = try? JSONEncoder().encode(saveHistory) else {
            return
        }

        UserDefaults.standard.set(data, forKey: StorageKeys.saveHistory)
    }

    func recordSaveHistory(fileName: String) {
        let item = SaveHistoryItem(
            fileName: fileName,
            date: Date(),
            paperDescription: "\(selectedPaperSize.displayName)・\(paperOrientation.displayName)"
        )

        saveHistory.insert(item, at: 0)
        saveHistory = Array(saveHistory.prefix(30))
        storeSaveHistory()
    }

    // MARK: - SVGエクスポート

    func exportSVG(from drawing: PKDrawing) -> String {
        let exportCanvasSize = currentCanvasSize()
        let paperWidth = selectedPaperSize.widthMM(for: paperOrientation)
        let paperHeight = selectedPaperSize.heightMM(for: paperOrientation)

        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="\(format(paperWidth))mm" height="\(format(paperHeight))mm" viewBox="0 0 \(format(paperWidth)) \(format(paperHeight))">
        <title>iPad SVG Drawing</title>
        <desc>\(selectedPaperSize.displayName) \(paperOrientation.displayName)</desc>
        <defs>
            <clipPath id="paperClip">
                <rect x="0" y="0" width="\(format(paperWidth))" height="\(format(paperHeight))" />
            </clipPath>
        </defs>
        """

        guard !drawing.strokes.isEmpty else {
            svg += "\n</svg>"
            return svg
        }

        let paperFrame = exportPaperFrame(in: exportCanvasSize)
        let mmPerPointX = paperWidth / max(paperFrame.width, 1)
        let mmPerPointY = paperHeight / max(paperFrame.height, 1)
        let strokeWidthMMPerPoint = min(mmPerPointX, mmPerPointY)

        svg += "\n<g clip-path=\"url(#paperClip)\">"

        for stroke in drawing.strokes {
            var rawPoints: [StrokePointData] = []

            stroke.path.forEach { point in
                rawPoints.append(
                    StrokePointData(
                        location: point.location,
                        size: point.size,
                        opacity: point.opacity
                    )
                )
            }

            guard rawPoints.count > 1 else {
                continue
            }

            let simplified = simplifyPoints(
                rawPoints,
                targetCount: Int(targetPointCount)
            )

            guard simplified.count > 1 else {
                continue
            }

            let uiColor = stroke.ink.color
            let colorHex = uiColor.hexString
            let pointOpacity = simplified.map { $0.opacity }.reduce(0, +) / CGFloat(simplified.count)
            let strokeOpacity = min(max(uiColor.alphaValue * pointOpacity, 0), 1)

            let averagePointWidth = simplified.map { $0.size.width }.reduce(0, +) / CGFloat(simplified.count)
            let svgStrokeWidth = max(0.1, averagePointWidth * strokeWidthMMPerPoint)

            var d = ""

            for (index, pointData) in simplified.enumerated() {
                let point = pointData.location

                let x = (point.x - paperFrame.minX) * mmPerPointX
                let y = (point.y - paperFrame.minY) * mmPerPointY

                if index == 0 {
                    d += "M \(format(x)) \(format(y)) "
                } else {
                    d += "L \(format(x)) \(format(y)) "
                }
            }

            svg += """

            <path d="\(d)" stroke="\(colorHex)" stroke-width="\(format(svgStrokeWidth))" stroke-opacity="\(format(strokeOpacity))" fill="none" stroke-linecap="round" stroke-linejoin="round" />
            """
        }

        svg += "\n</g>"
        svg += "\n</svg>"
        return svg
    }

    func currentCanvasSize() -> CGSize {
        if canvasSize.width > 0, canvasSize.height > 0 {
            return canvasSize
        }

        if canvasView.bounds.width > 0, canvasView.bounds.height > 0 {
            return canvasView.bounds.size
        }

        return CGSize(width: 1024, height: 768)
    }

    func exportPaperFrame(in canvasSize: CGSize) -> CGRect {
        let paperWidthMM = selectedPaperSize.widthMM(for: paperOrientation)
        let paperHeightMM = selectedPaperSize.heightMM(for: paperOrientation)

        let padding: CGFloat = 20
        let maxWidth = max(1, canvasSize.width - padding * 2)
        let maxHeight = max(1, canvasSize.height - padding * 2)

        let mmToPoint = min(maxWidth / paperWidthMM, maxHeight / paperHeightMM)

        let guideWidth = paperWidthMM * mmToPoint * paperGuideZoom
        let guideHeight = paperHeightMM * mmToPoint * paperGuideZoom

        let centerX = canvasSize.width / 2 + guideOffset.width
        let centerY = canvasSize.height / 2 + guideOffset.height

        return CGRect(
            x: centerX - guideWidth / 2,
            y: centerY - guideHeight / 2,
            width: guideWidth,
            height: guideHeight
        )
    }

    // MARK: - SVG点数調整

    func simplifyPoints(_ points: [StrokePointData], targetCount: Int) -> [StrokePointData] {
        let safeTargetCount = max(2, targetCount)

        guard points.count > safeTargetCount else {
            return points
        }

        var minX = points[0].location.x
        var maxX = points[0].location.x
        var minY = points[0].location.y
        var maxY = points[0].location.y

        for point in points {
            minX = min(minX, point.location.x)
            maxX = max(maxX, point.location.x)
            minY = min(minY, point.location.y)
            maxY = max(maxY, point.location.y)
        }

        var lowTolerance: CGFloat = 0
        var highTolerance = max(maxX - minX, maxY - minY, 1)
        var best = points

        for _ in 0..<12 {
            let tolerance = (lowTolerance + highTolerance) / 2
            let simplified = douglasPeucker(points, tolerance: tolerance)

            if simplified.count > safeTargetCount {
                lowTolerance = tolerance
            } else {
                highTolerance = tolerance
                best = simplified
            }
        }

        if best.count > safeTargetCount {
            return downsamplePoints(best, targetCount: safeTargetCount)
        }

        return best
    }

    func douglasPeucker(_ points: [StrokePointData], tolerance: CGFloat) -> [StrokePointData] {
        guard points.count > 2 else {
            return points
        }

        var keep = Array(repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true

        func simplifySection(start: Int, end: Int) {
            guard end > start + 1 else {
                return
            }

            let startPoint = points[start].location
            let endPoint = points[end].location

            var maxDistance: CGFloat = 0
            var farthestIndex = start

            for index in (start + 1)..<end {
                let distance = perpendicularDistance(
                    from: points[index].location,
                    toLineStart: startPoint,
                    lineEnd: endPoint
                )

                if distance > maxDistance {
                    maxDistance = distance
                    farthestIndex = index
                }
            }

            if maxDistance > tolerance {
                keep[farthestIndex] = true
                simplifySection(start: start, end: farthestIndex)
                simplifySection(start: farthestIndex, end: end)
            }
        }

        simplifySection(start: 0, end: points.count - 1)

        return points.enumerated().compactMap { index, point in
            keep[index] ? point : nil
        }
    }

    func perpendicularDistance(
        from point: CGPoint,
        toLineStart start: CGPoint,
        lineEnd end: CGPoint
    ) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y

        guard dx != 0 || dy != 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }

        let numerator = abs(dy * point.x - dx * point.y + end.x * start.y - end.y * start.x)
        let denominator = hypot(dx, dy)

        return numerator / denominator
    }

    func downsamplePoints(_ points: [StrokePointData], targetCount: Int) -> [StrokePointData] {
        guard points.count > targetCount, targetCount > 1 else {
            return points
        }

        let step = Double(points.count - 1) / Double(targetCount - 1)
        var result: [StrokePointData] = []

        for index in 0..<targetCount {
            let sourceIndex = min(points.count - 1, Int(round(Double(index) * step)))
            result.append(points[sourceIndex])
        }

        return result
    }

    func format(_ value: CGFloat) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double(value))
    }
}

// MARK: - 通常モードバー

struct MainToolBar: View {
    let canvasView: PKCanvasView

    @Binding var selectedColor: Color
    @Binding var lineWidth: CGFloat
    @Binding var opacity: Double
    @Binding var targetPointCount: Double
    @Binding var isPaperMoveMode: Bool
    @Binding var isEraserMode: Bool
    @Binding var workspaceZoom: CGFloat
    @Binding var lastWorkspaceZoom: CGFloat

    let onUpdateTool: () -> Void
    let onClear: () -> Void
    let onPreview: () -> Void
    let onHistory: () -> Void
    let onSave: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let isPortraitLike = geometry.size.width < 900

            if isPortraitLike {
                portraitBar
            } else {
                landscapeBar
            }
        }
        .frame(height: 116)
        .background(Color(.systemGray6))
    }

    private var portraitBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Button {
                    canvasView.undoManager?.undo()
                } label: {
                    CompactToolButton(systemName: "arrow.uturn.backward", text: "戻る")
                }

                Button {
                    canvasView.undoManager?.redo()
                } label: {
                    CompactToolButton(systemName: "arrow.uturn.forward", text: "進む")
                }

                ToolSwitchControl(
                    isEraserMode: $isEraserMode,
                    onUpdateTool: onUpdateTool
                )

                Button {
                    onClear()
                } label: {
                    CompactToolButton(systemName: "trash", text: "全消去")
                }

                Button {
                    onHistory()
                } label: {
                    CompactToolButton(systemName: "clock", text: "履歴")
                }

                Button {
                    onPreview()
                } label: {
                    CompactToolButton(systemName: "eye", text: "確認")
                }

                Button {
                    isPaperMoveMode = true
                    isEraserMode = false
                    onUpdateTool()
                } label: {
                    WideToolButton(systemName: "doc.viewfinder", text: "用紙設定")
                }

                Spacer(minLength: 4)

                Button {
                    onSave()
                } label: {
                    CompactToolButton(systemName: "square.and.arrow.down", text: "保存")
                }
            }

            HStack(spacing: 8) {
                ColorPicker("", selection: $selectedColor)
                    .labelsHidden()
                    .frame(width: 36)
                    .onChange(of: selectedColor) { _ in
                        isEraserMode = false
                        onUpdateTool()
                    }

                CompactSlider(
                    title: "線幅",
                    valueText: "\(Int(lineWidth))",
                    value: Binding(
                        get: { Double(lineWidth) },
                        set: {
                            lineWidth = CGFloat($0)
                            isEraserMode = false
                            onUpdateTool()
                        }
                    ),
                    range: 1...30,
                    step: 1,
                    width: 120
                )

                CompactSlider(
                    title: "透明度",
                    valueText: "\(Int(opacity * 100))%",
                    value: $opacity,
                    range: 0.1...1.0,
                    step: 0.05,
                    width: 120
                )
                .onChange(of: opacity) { _ in
                    isEraserMode = false
                    onUpdateTool()
                }

                CompactSlider(
                    title: "SVG精度",
                    valueText: "\(Int(targetPointCount))",
                    value: $targetPointCount,
                    range: 20...300,
                    step: 10,
                    width: 120
                )

                CompactSlider(
                    title: "表示ズーム",
                    valueText: "\(Int(workspaceZoom * 100))%",
                    value: Binding(
                        get: {
                            Double(workspaceZoom)
                        },
                        set: {
                            workspaceZoom = CGFloat($0)
                            lastWorkspaceZoom = workspaceZoom
                        }
                    ),
                    range: 0.5...4.0,
                    step: 0.05,
                    width: 150
                )

                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var landscapeBar: some View {
        HStack(spacing: 6) {
            Button {
                canvasView.undoManager?.undo()
            } label: {
                CompactToolButton(systemName: "arrow.uturn.backward", text: "戻る")
            }

            Button {
                canvasView.undoManager?.redo()
            } label: {
                CompactToolButton(systemName: "arrow.uturn.forward", text: "進む")
            }

            ToolSwitchControl(
                isEraserMode: $isEraserMode,
                onUpdateTool: onUpdateTool
            )

            Button {
                onClear()
            } label: {
                CompactToolButton(systemName: "trash", text: "全消去")
            }

            Button {
                onHistory()
            } label: {
                CompactToolButton(systemName: "clock", text: "履歴")
            }

            Button {
                onPreview()
            } label: {
                CompactToolButton(systemName: "eye", text: "確認")
            }

            Button {
                isPaperMoveMode = true
                isEraserMode = false
                onUpdateTool()
            } label: {
                WideToolButton(systemName: "doc.viewfinder", text: "用紙設定")
            }

            Divider()
                .frame(height: 42)

            ColorPicker("", selection: $selectedColor)
                .labelsHidden()
                .frame(width: 36)
                .onChange(of: selectedColor) { _ in
                    isEraserMode = false
                    onUpdateTool()
                }

            CompactSlider(
                title: "線幅",
                valueText: "\(Int(lineWidth))",
                value: Binding(
                    get: { Double(lineWidth) },
                    set: {
                        lineWidth = CGFloat($0)
                        isEraserMode = false
                        onUpdateTool()
                    }
                ),
                range: 1...30,
                step: 1,
                width: 85
            )

            CompactSlider(
                title: "透明度",
                valueText: "\(Int(opacity * 100))%",
                value: $opacity,
                range: 0.1...1.0,
                step: 0.05,
                width: 85
            )
            .onChange(of: opacity) { _ in
                isEraserMode = false
                onUpdateTool()
            }

            CompactSlider(
                title: "SVG精度",
                valueText: "\(Int(targetPointCount))",
                value: $targetPointCount,
                range: 20...300,
                step: 10,
                width: 85
            )

            CompactSlider(
                title: "表示ズーム",
                valueText: "\(Int(workspaceZoom * 100))%",
                value: Binding(
                    get: {
                        Double(workspaceZoom)
                    },
                    set: {
                        workspaceZoom = CGFloat($0)
                        lastWorkspaceZoom = workspaceZoom
                    }
                ),
                range: 0.5...4.0,
                step: 0.05,
                width: 105
            )

            Spacer(minLength: 6)

            Button {
                onSave()
            } label: {
                CompactToolButton(systemName: "square.and.arrow.down", text: "保存")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

// MARK: - 用紙モードバー

struct PaperModeBar: View {
    @Binding var selectedPaperSize: PaperSize
    @Binding var paperOrientation: PaperOrientation
    @Binding var isPaperMoveMode: Bool
    @Binding var guideOffset: CGSize
    @Binding var paperGuideZoom: CGFloat
    @Binding var lastPaperGuideZoom: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let isPortraitLike = geometry.size.width < 900

            if isPortraitLike {
                portraitBar
            } else {
                landscapeBar
            }
        }
        .frame(height: 110)
        .background(Color.blue.opacity(0.10))
    }

    private var portraitBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    isPaperMoveMode = false
                } label: {
                    WideToolButton(systemName: "pencil", text: "描画モードへ")
                }

                Menu {
                    ForEach(PaperSize.allCases) { size in
                        Button(size.displayName) {
                            selectedPaperSize = size
                            guideOffset = .zero
                            paperGuideZoom = 1.0
                            lastPaperGuideZoom = 1.0
                        }
                    }
                } label: {
                    CompactToolButton(systemName: "doc", text: selectedPaperSize.shortName)
                }

                OrientationSwitchControl(
                    paperOrientation: $paperOrientation,
                    guideOffset: $guideOffset
                )

                Button {
                    guideOffset = .zero
                } label: {
                    CompactToolButton(systemName: "scope", text: "中央")
                }

                Spacer()
            }

            HStack(spacing: 8) {
                CompactSlider(
                    title: "用紙倍率",
                    valueText: "\(Int(paperGuideZoom * 100))%",
                    value: Binding(
                        get: {
                            Double(paperGuideZoom)
                        },
                        set: {
                            paperGuideZoom = CGFloat($0)
                            lastPaperGuideZoom = paperGuideZoom
                        }
                    ),
                    range: 0.5...4.0,
                    step: 0.05,
                    width: 200
                )

                Text("用紙枠をドラッグで移動・倍率で出力範囲を調整")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var landscapeBar: some View {
        HStack(spacing: 8) {
            Button {
                isPaperMoveMode = false
            } label: {
                WideToolButton(systemName: "pencil", text: "描画モードへ")
            }

            Menu {
                ForEach(PaperSize.allCases) { size in
                    Button(size.displayName) {
                        selectedPaperSize = size
                        guideOffset = .zero
                        paperGuideZoom = 1.0
                        lastPaperGuideZoom = 1.0
                    }
                }
            } label: {
                CompactToolButton(systemName: "doc", text: selectedPaperSize.shortName)
            }

            OrientationSwitchControl(
                paperOrientation: $paperOrientation,
                guideOffset: $guideOffset
            )

            Button {
                guideOffset = .zero
            } label: {
                CompactToolButton(systemName: "scope", text: "中央")
            }

            CompactSlider(
                title: "用紙倍率",
                valueText: "\(Int(paperGuideZoom * 100))%",
                value: Binding(
                    get: {
                        Double(paperGuideZoom)
                    },
                    set: {
                        paperGuideZoom = CGFloat($0)
                        lastPaperGuideZoom = paperGuideZoom
                    }
                ),
                range: 0.5...4.0,
                step: 0.05,
                width: 160
            )

            Text("用紙枠をドラッグで移動・倍率で出力範囲を調整")
                .font(.caption)
                .foregroundColor(.blue)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

// MARK: - ペン / 消しゴム切り替えUI

struct ToolSwitchControl: View {
    @Binding var isEraserMode: Bool
    let onUpdateTool: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button {
                isEraserMode = false
                onUpdateTool()
            } label: {
                ActiveToolButton(
                    systemName: "pencil.tip",
                    text: "ペン",
                    color: isEraserMode ? .secondary : .blue,
                    isActive: !isEraserMode
                )
            }

            Button {
                isEraserMode = true
                onUpdateTool()
            } label: {
                ActiveToolButton(
                    systemName: isEraserMode ? "eraser.fill" : "eraser",
                    text: "消しゴム",
                    color: isEraserMode ? .orange : .secondary,
                    isActive: isEraserMode
                )
            }
        }
    }
}

// MARK: - 縦向き / 横向き切り替えUI

struct OrientationSwitchControl: View {
    @Binding var paperOrientation: PaperOrientation
    @Binding var guideOffset: CGSize

    var body: some View {
        HStack(spacing: 4) {
            Button {
                paperOrientation = .portrait
                guideOffset = .zero
            } label: {
                ActiveToolButton(
                    systemName: "rectangle.portrait.fill",
                    text: "縦向き",
                    color: paperOrientation == .portrait ? .blue : .secondary,
                    isActive: paperOrientation == .portrait
                )
            }

            Button {
                paperOrientation = .landscape
                guideOffset = .zero
            } label: {
                ActiveToolButton(
                    systemName: "rectangle.fill",
                    text: "横向き",
                    color: paperOrientation == .landscape ? .blue : .secondary,
                    isActive: paperOrientation == .landscape
                )
            }
        }
    }
}

// MARK: - 現在のツール / 向きボタン

struct ActiveToolButton: View {
    let systemName: String
    let text: String
    let color: Color
    let isActive: Bool

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))

            Text(text)
                .font(.system(size: 9, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 60, height: 46)
        .background(isActive ? color.opacity(0.20) : Color.white)
        .foregroundColor(color)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? color : color.opacity(0.35), lineWidth: isActive ? 2 : 1)
        )
        .cornerRadius(10)
        .shadow(radius: 1)
    }
}

// MARK: - 通常ボタン

struct CompactToolButton: View {
    let systemName: String
    let text: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: systemName)
                .font(.system(size: 15))

            Text(text)
                .font(.system(size: 10))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 50, height: 46)
        .background(Color.white)
        .foregroundColor(.primary)
        .cornerRadius(10)
        .shadow(radius: 1)
    }
}

// MARK: - 横長ボタン

struct WideToolButton: View {
    let systemName: String
    let text: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: systemName)
                .font(.system(size: 15))

            Text(text)
                .font(.system(size: 10))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 100, height: 46)
        .background(Color.white)
        .foregroundColor(.primary)
        .cornerRadius(10)
        .shadow(radius: 1)
    }
}

// MARK: - スライダー

struct CompactSlider: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 10))

                Text(valueText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Slider(value: $value, in: range, step: step)
        }
        .frame(width: width)
    }
}

// MARK: - PencilKit Canvas

struct PencilCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    @Binding var selectedColor: Color
    @Binding var lineWidth: CGFloat
    @Binding var opacity: Double
    @Binding var isEraserMode: Bool
    let isDrawingEnabled: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        canvasView.isOpaque = true

        canvasView.minimumZoomScale = 1.0
        canvasView.maximumZoomScale = 1.0
        canvasView.zoomScale = 1.0
        canvasView.bouncesZoom = false

        applyTool(to: canvasView)

        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()

        canvasView.isUserInteractionEnabled = isDrawingEnabled

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        applyTool(to: uiView)
        uiView.isUserInteractionEnabled = isDrawingEnabled
    }

    private func applyTool(to canvasView: PKCanvasView) {
        if isEraserMode {
            canvasView.tool = PKEraserTool(.bitmap)
        } else {
            let uiColor = UIColor(selectedColor).withAlphaComponent(CGFloat(opacity))
            canvasView.tool = PKInkingTool(.pen, color: uiColor, width: lineWidth)
        }
    }
}

// MARK: - 用紙ガイド

struct PaperGuideView: View {
    let paperSize: PaperSize
    let orientation: PaperOrientation
    @Binding var guideOffset: CGSize
    let isMoveMode: Bool
    let canvasSize: CGSize
    let currentZoom: CGFloat

    @State private var dragStartOffset: CGSize?

    var body: some View {
        let paperWidthMM = paperSize.widthMM(for: orientation)
        let paperHeightMM = paperSize.heightMM(for: orientation)

        let padding: CGFloat = 20
        let maxWidth = max(1, canvasSize.width - padding * 2)
        let maxHeight = max(1, canvasSize.height - padding * 2)

        let mmToPoint = min(maxWidth / paperWidthMM, maxHeight / paperHeightMM)

        let guideWidth = paperWidthMM * mmToPoint
        let guideHeight = paperHeightMM * mmToPoint

        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2

        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(width: guideWidth, height: guideHeight)
                .contentShape(Rectangle())

            Rectangle()
                .stroke(
                    guideColor,
                    style: StrokeStyle(
                        lineWidth: 2,
                        dash: [8, 6]
                    )
                )
                .frame(width: guideWidth, height: guideHeight)

            VStack(spacing: 4) {
                Text("\(paperSize.displayName)・\(orientation.displayName)")
                    .font(.caption)
                    .foregroundColor(guideColor)
                    .padding(6)
                    .background(Color.white.opacity(0.85))
                    .cornerRadius(6)

                Text("\(Int(paperWidthMM)) × \(Int(paperHeightMM)) mm")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(Color.white.opacity(0.75))
                    .cornerRadius(5)

                if isMoveMode {
                    Text("ドラッグで移動")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(Color.white.opacity(0.75))
                        .cornerRadius(5)
                }

                Spacer()
            }
            .frame(width: guideWidth, height: guideHeight)
        }
        .frame(width: guideWidth, height: guideHeight)
        .contentShape(Rectangle())
        .position(
            x: centerX + guideOffset.width,
            y: centerY + guideOffset.height
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard isMoveMode else { return }

                    let startOffset = dragStartOffset ?? guideOffset
                    if dragStartOffset == nil {
                        dragStartOffset = guideOffset
                    }

                    let adjustedTranslation = CGSize(
                        width: value.translation.width / max(currentZoom, 0.1),
                        height: value.translation.height / max(currentZoom, 0.1)
                    )

                    let proposedOffset = CGSize(
                        width: startOffset.width + adjustedTranslation.width,
                        height: startOffset.height + adjustedTranslation.height
                    )

                    guideOffset = clampedOffset(
                        proposedOffset,
                        canvasSize: canvasSize,
                        guideWidth: guideWidth * currentZoom,
                        guideHeight: guideHeight * currentZoom
                    )
                }
                .onEnded { _ in
                    guard isMoveMode else { return }
                    dragStartOffset = nil
                }
        )
        .onChange(of: paperSize) { _ in
            guideOffset = .zero
            dragStartOffset = nil
        }
        .onChange(of: orientation) { _ in
            guideOffset = .zero
            dragStartOffset = nil
        }
        .onChange(of: isMoveMode) { _ in
            dragStartOffset = nil
        }
    }

    var guideColor: Color {
        isMoveMode ? .blue : .gray
    }

    func clampedOffset(
        _ offset: CGSize,
        canvasSize: CGSize,
        guideWidth: CGFloat,
        guideHeight: CGFloat
    ) -> CGSize {
        let maxX = max(0, (canvasSize.width - guideWidth) / 2)
        let maxY = max(0, (canvasSize.height - guideHeight) / 2)

        let clampedX = min(max(offset.width, -maxX), maxX)
        let clampedY = min(max(offset.height, -maxY), maxY)

        return CGSize(width: clampedX, height: clampedY)
    }
}

// MARK: - SVG Preview

struct SVGPreviewView: UIViewRepresentable {
    let svgText: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
        body {
            margin: 0;
            padding: 20px;
            background: #f2f2f2;
        }
        .container {
            background: white;
            border: 1px solid #ccc;
            width: 100%;
            overflow: auto;
            box-sizing: border-box;
        }
        svg {
            width: 100%;
            height: auto;
            display: block;
        }
        </style>
        </head>
        <body>
        <div class="container">
        \(svgText)
        </div>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - SVG FileDocument

struct SVGDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.svgDocument]
    }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            text = string
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - 用紙の向き

enum PaperOrientation: String, CaseIterable, Identifiable {
    case portrait
    case landscape

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .portrait:
            return "縦向き"
        case .landscape:
            return "横向き"
        }
    }
}

// MARK: - 用紙サイズ

enum PaperSize: String, CaseIterable, Identifiable {
    case a5
    case a4
    case a3
    case a2
    case a1
    case a0
    case postcard
    case square100
    case square150
    case square300
    case laserSmall
    case laserMedium
    case laserLarge

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .a5:
            return "A5"
        case .a4:
            return "A4"
        case .a3:
            return "A3"
        case .a2:
            return "A2"
        case .a1:
            return "A1"
        case .a0:
            return "A0"
        case .postcard:
            return "はがき"
        case .square100:
            return "100×100mm"
        case .square150:
            return "150×150mm"
        case .square300:
            return "300×300mm"
        case .laserSmall:
            return "300×200mm"
        case .laserMedium:
            return "450×300mm"
        case .laserLarge:
            return "600×400mm"
        }
    }

    var shortName: String {
        switch self {
        case .square100:
            return "100"
        case .square150:
            return "150"
        case .square300:
            return "300"
        case .laserSmall:
            return "300×200"
        case .laserMedium:
            return "450×300"
        case .laserLarge:
            return "600×400"
        default:
            return displayName
        }
    }

    var widthMM: CGFloat {
        switch self {
        case .a5:
            return 148
        case .a4:
            return 210
        case .a3:
            return 297
        case .a2:
            return 420
        case .a1:
            return 594
        case .a0:
            return 841
        case .postcard:
            return 100
        case .square100:
            return 100
        case .square150:
            return 150
        case .square300:
            return 300
        case .laserSmall:
            return 300
        case .laserMedium:
            return 450
        case .laserLarge:
            return 600
        }
    }

    var heightMM: CGFloat {
        switch self {
        case .a5:
            return 210
        case .a4:
            return 297
        case .a3:
            return 420
        case .a2:
            return 594
        case .a1:
            return 841
        case .a0:
            return 1189
        case .postcard:
            return 148
        case .square100:
            return 100
        case .square150:
            return 150
        case .square300:
            return 300
        case .laserSmall:
            return 200
        case .laserMedium:
            return 300
        case .laserLarge:
            return 400
        }
    }

    func widthMM(for orientation: PaperOrientation) -> CGFloat {
        switch orientation {
        case .portrait:
            return widthMM
        case .landscape:
            return heightMM
        }
    }

    func heightMM(for orientation: PaperOrientation) -> CGFloat {
        switch orientation {
        case .portrait:
            return heightMM
        case .landscape:
            return widthMM
        }
    }
}

// MARK: - 保存履歴

struct SaveHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let fileName: String
    let date: Date
    let paperDescription: String

    init(
        id: UUID = UUID(),
        fileName: String,
        date: Date,
        paperDescription: String
    ) {
        self.id = id
        self.fileName = fileName
        self.date = date
        self.paperDescription = paperDescription
    }
}

// MARK: - ストロークデータ

struct StrokePointData {
    let location: CGPoint
    let size: CGSize
    let opacity: CGFloat
}

// MARK: - Storage Keys

enum StorageKeys {
    static let saveHistory = "svgDrawingApp.saveHistory"
}

// MARK: - UIColor Extension

extension UIColor {
    var hexString: String {
        let components = rgbaComponents
        let r = Int(components.red * 255)
        let g = Int(components.green * 255)
        let b = Int(components.blue * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var alphaValue: CGFloat {
        rgbaComponents.alpha
    }

    private var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (red, green, blue, alpha)
        }

        var white: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            return (white, white, white, alpha)
        }

        return (0, 0, 0, 1)
    }
}

// MARK: - UTType Extension

extension UTType {
    static var svgDocument: UTType {
        UTType(filenameExtension: "svg", conformingTo: .xml) ?? .plainText
    }
}

