# SVG Draw App ✍️📐

<p align="center">
  <img src="images/app-icon.jpg" width="140" alt="SVG Draw App Icon">
</p>

> Apple Pencilによる手描き表現をSVGデータへ変換する、レーザー加工向けドローイングアプリ。

![Platform](https://img.shields.io/badge/Platform-iPadOS-blue)
![Language](https://img.shields.io/badge/Language-Swift-orange)
![Framework](https://img.shields.io/badge/Framework-SwiftUI-green)
![Drawing](https://img.shields.io/badge/Drawing-PencilKit-purple)
![Output](https://img.shields.io/badge/Output-SVG-red)

Apple Pencilを使ってiPad上に自由にイラストを描き、その描画データをSVG形式で保存できるドローイングアプリです。

通常の画像保存ではなく、拡大しても劣化しにくいベクターデータとして出力できるため、レーザー加工やデジタル制作への活用を想定して開発しました。

---

## 📱 アプリ画面

![Main Screen](images/main-screen.PNG)

---

## 🎬 デモ動画

以下の動画では、描画・用紙設定・SVGプレビューまでの流れを確認できます。

[▶ デモ動画を見る](images/drawSVG_demomovie.mov)

> ※ GitHub上で動画を直接再生したい場合は、README編集画面に `drawSVG_demomovie.mov` をドラッグ＆ドロップし、生成されたURLをここに貼ると表示されやすいです。

---

## 🚀 作成背景（研究・開発の目的）

本プロジェクトは、**手描きの自由な表現をそのままデジタル加工用データへ変換すること**を目的として開発しました。

一般的なドローイングアプリでは、描いたイラストをPNGやJPEGなどの画像として保存することが多く、レーザー加工やカッティングなどに利用する場合には、別途ベクターデータへ変換する必要があります。

そこで本アプリでは、iPad上で描いた線を直接SVG形式として保存できるようにし、手描きから加工用データ作成までの流れを簡単にすることを目指しました。

開発にあたり、以下の3つを重視しました。

### 1. Apple Pencilによる自然な描画体験

PencilKitの `PKCanvasView` を用いることで、Apple Pencilによる滑らかな描画を実現しました。

線幅・色・透明度を調整できるようにし、通常のペン描画に近い操作感を保ちながら、作成した線をSVGデータとして扱えるようにしています。

### 2. SVG出力による加工連携

描画データである `PKDrawing` のストローク情報を取得し、各点の座標をSVGの `<path>` に変換する処理を実装しました。

SVG形式で保存することで、拡大縮小しても画質が劣化しにくく、レーザー加工やデジタル制作に利用しやすいデータ形式を実現しています。

### 3. 用紙設定とプレビューによる制作支援

A4やA3などの用紙サイズ、縦向き・横向きの設定、用紙枠の表示・移動・ズームに対応しました。

さらに、保存前にSVGプレビューを確認できるようにすることで、出力結果を事前に把握しやすくしました。

---

## ✨ 主な機能

### ✍️ Apple Pencilによる描画機能

iPad上でApple Pencilや指を使って自由に描画できます。PencilKitを利用しているため、滑らかな線の描画が可能です。

![Drawing Screen](images/main-screen.PNG)

- ペン描画
- 消しゴム機能
- 色の変更
- 線幅の変更
- 透明度の調整
- 全消去
- 戻る・進む操作

---

### 🧽 ペン / 消しゴム切り替えUI

現在使用しているツールを大きく表示し、使っていないツールを小さく表示するUIを実装しました。

- **ペン使用中:** `[ペン]` ⇄ `[消しゴム]`
- **消しゴム使用中:** `[消しゴム]` ⇄ `[ペン]`

これにより、現在どちらのツールを使っているのかを直感的に判断できます。

---

### 📐 用紙サイズ・向きの設定機能

描画エリア上に点線の用紙枠を表示し、制作物のサイズ感を確認しながら描けるようにしました。

用紙の向きもワンタップで切り替えられます。

![Paper Setting Mode](images/paper-setting-mode.PNG)

#### 対応している用紙サイズ例

- A5
- A4
- A3
- A2
- A1
- A0
- はがき
- 100×100mm
- 150×150mm
- 300×300mm
- 300×200mm
- 450×300mm
- 600×400mm

#### 向きの切り替え

- **縦向き中:** `[縦向き]` ⇄ `[横]`
- **横向き中:** `[横向き]` ⇄ `[縦]`

---

### 🔍 ズーム機能

操作モードによってズームの挙動を分けることで、操作性を向上させています。

- **通常モード:** イラストと用紙枠を一緒にズーム
- **用紙設定モード:** 用紙枠だけをズーム

通常モードでは描画に集中でき、用紙設定モードではサイズや配置の調整を行いやすくしています。

---

### 🖼️ SVGプレビュー機能

保存前に、生成されたSVGをアプリ内で確認できます。

WebKitの `WKWebView` を使い、実際のSVGの見た目をプレビューできるため、出力ミスやサイズ感のズレに気づきやすくなっています。

![SVG Preview](images/svg-preview.PNG)

---

### 💾 SVG保存機能

描画した内容をSVGファイルとしてファイルアプリへ保存できます。

保存時には以下の情報がSVGへ反映されます。

- 線の座標
- 線幅
- 色
- 透明度
- 用紙サイズ
- `viewBox`
- SVGの幅・高さ

---

### 🕘 保存履歴機能

アプリ内で保存したファイル名と保存日時を簡易的に確認できます。

※現時点では、アプリ起動中のみ履歴を保持しています。

---

## ⚙️ システム構成（アルゴリズムフロー）

```text
[ Apple Pencil / 指による描画 ]
        │
        ▼
[ PencilKitのPKCanvasViewに描画データを保存 ]
        │
        ▼
[ PKDrawingからストローク情報を取得 ]
        │
        ▼
[ 各ストロークの座標・線幅・色・透明度を抽出 ]
        │
        ▼
[ 点の間引き処理でSVGパスを軽量化 ]
        │
        ▼
[ SVGのpathタグへ変換 ]
        │
        ▼
[ WKWebViewでSVGプレビュー表示 ]
        │
        ▼
[ FileDocument + fileExporterでSVG保存 ]
```

---

## 💻 注目コード（コアロジックの抜粋）

本作の中心となる処理は、PencilKitの描画データをSVG形式へ変換する部分です。

### 1. PKDrawingからストローク情報を取得

`PKDrawing` に含まれる複数のストロークを順番に取り出し、それぞれの点の座標や線幅情報を取得しています。

```swift
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
}
```

---

### 2. 描画点をSVGのpathに変換

取得・最適化した座標を、SVGのパスデータである `d` 属性のコマンドへ変換します。

```swift
for (index, pointData) in simplified.enumerated() {
    let p = pointData.location

    let x = offsetX + (p.x - bounds.minX) * scale
    let y = offsetY + (p.y - bounds.minY) * scale

    if index == 0 {
        d += "M \(format(x)) \(format(y)) "
    } else {
        d += "L \(format(x)) \(format(y)) "
    }
}
```

---

### 3. SVGとして出力

線の色、太さ、透明度を反映しながら、最終的なSVGの `<path>` 要素として組み立てます。

```swift
svg += """
<path d="\(d)" stroke="\(colorHex)" stroke-width="\(format(svgStrokeWidth))" stroke-opacity="\(format(strokeOpacity))" fill="none" stroke-linecap="round" stroke-linejoin="round" />
"""
```

---

## 💡 工夫した点

### 描画モードと用紙設定モードの分離

描画中に誤って用紙枠を動かしてしまわないよう、モードを明確に分離しました。

通常モードでは描画に集中でき、用紙設定モードでは用紙枠の移動やズームだけを行えます。

---

### iPadの縦向き・横向きに対応したUI

iPadを横向きにした場合は上部バーを1段で表示し、縦向きにした場合は2段表示になるようにレスポンシブなUIを構築しました。

画面幅が狭い状態でも操作要素が画面外に隠れないようにしています。

---

### 用紙枠だけをズームできる設計

用紙設定モードでは、イラストではなく用紙枠だけをズームできるようにしました。

これにより、描画内容と混同せず、サイズや配置の調整が行えるようにしています。

---

### 保存前のプレビュー表示

書き出す前に `WKWebView` でSVGの見た目をプレビュー確認できるため、意図通りのデータになっているかを事前にチェックできます。

---

### 点の間引きによるデータ軽量化

Apple Pencilで描いた線は多くの点を含むため、そのままSVG化するとファイルサイズが大きくなります。

そこで、点の数を調整できる「間引き」機能を実装し、レーザー加工機等で扱いやすい軽量なSVGデータを出力できるようにしました。

---

## 🛠️ 使用技術

| カテゴリ | 技術・ツール |
|---|---|
| 言語 | Swift |
| UI | SwiftUI |
| 描画 | PencilKit / PKCanvasView / PKDrawing |
| ツール | PKInkingTool / PKEraserTool |
| SVG生成 | 独自のSVG変換処理 |
| SVGプレビュー | WebKit / WKWebView |
| ファイル保存 | FileDocument / fileExporter |
| 開発環境 | Xcode |
| 実行環境 | iPadOS / Apple Pencil |

---

## 🔮 今後の展望（ロードマップ）

- [ ] レイヤー機能の追加
- [ ] 保存履歴の永続化
- [ ] SVGの線をより滑らかにする補正
- [ ] ベジェ曲線化への対応
- [ ] レーザー加工機向けの出力設定追加
- [ ] 出力パワーや速度ごとの色分け
- [ ] グリッド・ガイド線・テンプレート機能の追加
- [ ] 図形ツールの追加
- [ ] テキスト入力機能の追加
- [ ] 複数ページへの対応
- [ ] PDFやPNGなど、他形式への出力対応
- [ ] iCloud連携によるファイル管理の改善

---

## 📄 ライセンス

MIT License
