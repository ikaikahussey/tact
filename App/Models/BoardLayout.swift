import CoreGraphics

/// Where each cell of the four-column board is drawn. On one screen the
/// board is a single column of rows. Across a vertical fold, such as the
/// iPhone Duo opened flat, it is a spread of two pages: the first rows fill
/// the left page, the next rows the right page, and further rows start a
/// new spread below. Cells keep their numbers either way, so placements,
/// games and drops are the same on every device; only where a cell is
/// drawn changes. The grid and the games use the same layout so each game
/// piece lands on the back of its tile.
struct BoardLayout: Equatable {
    static let columns = TileLayout.columns
    /// Narrowest page a spread allows; narrower halves stay one board.
    static let minimumPageWidth: CGFloat = 280
    /// Fewest rows a spread page holds, so the four-row games stay on the
    /// first page.
    static let minimumPageRows = 4

    /// Side of one cell.
    let cellSide: CGFloat
    let spacing: CGFloat
    /// Leading edge of the first column on each page.
    let pageX: [CGFloat]
    /// Rows on a page before the board continues on the next page. Nil for
    /// a single page, which runs down without limit.
    let rowsPerPage: Int?

    var pitch: CGFloat { cellSide + spacing }
    var isSpread: Bool { pageX.count > 1 && rowsPerPage != nil }
    var pageCount: Int { isSpread ? pageX.count : 1 }
    /// Width of one page's four columns.
    var boardWidth: CGFloat { TileLayout.boardWidth(cellSide: cellSide) }

    // MARK: Making

    /// One board centred on a canvas `width` wide.
    static func single(width: CGFloat, zoom: CGFloat = 1) -> BoardLayout {
        let side = (TileLayout.cellSide(forWidth: width) * zoom).rounded(.down)
        return BoardLayout(cellSide: side, spacing: TileLayout.spacing,
                           pageX: [TileLayout.inset(forWidth: width, cellSide: side)], rowsPerPage: nil)
    }

    /// Two pages either side of a vertical `fold` (its left and right
    /// edges on the canvas), mirrored about it: both boards are sized to
    /// the narrower half and sit the same distance in from the fold, so
    /// the spread is symmetrical about the hinge even when a safe area
    /// narrows one side of the canvas. Nil when a half is too narrow to
    /// be a page.
    static func spread(width: CGFloat, height: CGFloat, fold: ClosedRange<CGFloat>, zoom: CGFloat = 1) -> BoardLayout? {
        let left = fold.lowerBound
        let right = width - fold.upperBound
        let page = min(left, right)
        guard page >= minimumPageWidth else { return nil }
        let side = (TileLayout.cellSide(forWidth: page) * zoom).rounded(.down)
        guard side > 0 else { return nil }
        let pitch = side + TileLayout.spacing
        let fits = Int(((height + TileLayout.spacing) / pitch).rounded(.down))
        let inset = TileLayout.inset(forWidth: page, cellSide: side)
        return BoardLayout(cellSide: side, spacing: TileLayout.spacing,
                           pageX: [fold.lowerBound - inset - TileLayout.boardWidth(cellSide: side),
                                   fold.upperBound + inset],
                           rowsPerPage: max(minimumPageRows, fits))
    }

    /// A spread when the canvas has a vertical fold wide enough to split,
    /// otherwise one board.
    static func make(size: CGSize, fold: ClosedRange<CGFloat>?, zoom: CGFloat = 1) -> BoardLayout {
        if let fold, fold.lowerBound > 0, fold.upperBound < size.width,
           let spread = spread(width: size.width, height: size.height, fold: fold, zoom: zoom) {
            return spread
        }
        return single(width: size.width, zoom: zoom)
    }

    // MARK: Cells

    /// Where a cell is drawn: its page and its row down the canvas.
    func slot(of cell: Int) -> (page: Int, row: Int, column: Int) {
        let row = cell / Self.columns, column = cell % Self.columns
        guard isSpread, let perPage = rowsPerPage else { return (0, row, column) }
        let perSpread = perPage * pageCount
        let within = row % perSpread
        return (within / perPage, (row / perSpread) * perPage + within % perPage, column)
    }

    /// Top-left corner of a cell.
    func origin(of cell: Int) -> CGPoint {
        let slot = slot(of: cell)
        return CGPoint(x: pageX[slot.page] + CGFloat(slot.column) * pitch, y: CGFloat(slot.row) * pitch)
    }

    /// Middle of a cell.
    func center(of cell: Int) -> CGPoint {
        let origin = origin(of: cell)
        return CGPoint(x: origin.x + cellSide / 2, y: origin.y + cellSide / 2)
    }

    /// The cell under a point, or nil in a margin or the fold.
    func cell(at point: CGPoint) -> Int? {
        guard point.y >= 0, pitch > 0 else { return nil }
        for page in 0..<pageCount {
            let x = point.x - pageX[page]
            guard x >= 0, x < boardWidth else { continue }
            let column = min(Self.columns - 1, Int(x / pitch))
            let drawnRow = Int(point.y / pitch)
            guard isSpread, let perPage = rowsPerPage else { return drawnRow * Self.columns + column }
            let row = (drawnRow / perPage) * perPage * pageCount + page * perPage + drawnRow % perPage
            return row * Self.columns + column
        }
        return nil
    }

    // MARK: Rows

    /// Rows down the canvas that board rows `0..<rows` take up.
    func drawnRows(forRows rows: Int) -> Int {
        guard rows > 0 else { return 0 }
        guard isSpread, let perPage = rowsPerPage else { return rows }
        let perSpread = perPage * pageCount
        return (rows / perSpread) * perPage + min(rows % perSpread, perPage)
    }

    /// Height of the canvas that board rows `0..<rows` take up.
    func height(rows: Int) -> CGFloat {
        CGFloat(drawnRows(forRows: rows)) * pitch
    }

    /// Board rows to draw so the canvas is filled: at least `minimum`, and
    /// on a spread whole spreads, so the right page is never left short.
    func filledRows(atLeast minimum: Int) -> Int {
        guard isSpread, let perPage = rowsPerPage else { return minimum }
        let perSpread = perPage * pageCount
        return max(1, Int((Double(max(minimum, 1)) / Double(perSpread)).rounded(.up))) * perSpread
    }

    /// Board rows that fill a canvas `height` tall.
    func visibleRows(height: CGFloat) -> Int {
        guard pitch > 0 else { return 0 }
        if isSpread, let perPage = rowsPerPage { return perPage * pageCount }
        return Int((height / pitch).rounded(.up))
    }
}

/// The tray an open stack's tiles are laid out in. It opens directly under
/// the stack's row, and every row below moves down to make room.
struct StackTray: Equatable {
    /// Space above and below the tiles in the tray.
    static let inset: CGFloat = 8
    /// The cell the stack sits in.
    let cell: Int
    /// How many tiles the stack holds.
    let count: Int
}

extension BoardLayout {
    /// Rows of tiles in the tray, four across.
    func trayRows(_ tray: StackTray) -> Int {
        max(1, (tray.count + Self.columns - 1) / Self.columns)
    }

    /// How far the rows below the stack move down.
    func trayHeight(_ tray: StackTray) -> CGFloat {
        CGFloat(trayRows(tray)) * pitch + StackTray.inset * 2
    }

    /// Where the tray is drawn: the width of the stack's page, under its row.
    func trayFrame(_ tray: StackTray) -> CGRect {
        let slot = slot(of: tray.cell)
        return CGRect(x: pageX[slot.page], y: CGFloat(slot.row + 1) * pitch,
                      width: boardWidth, height: trayHeight(tray) - spacing)
    }

    /// Top-left corner of the tray's `index`th tile.
    func trayOrigin(of index: Int, in tray: StackTray) -> CGPoint {
        let frame = trayFrame(tray)
        return CGPoint(x: frame.minX + CGFloat(index % Self.columns) * pitch,
                       y: frame.minY + StackTray.inset + CGFloat(index / Self.columns) * pitch)
    }

    /// Top-left corner of a cell while `tray` is open: rows drawn below
    /// the stack's row are pushed down by the tray, on every page.
    func origin(of cell: Int, tray: StackTray?) -> CGPoint {
        var point = origin(of: cell)
        if let tray, slot(of: cell).row > slot(of: tray.cell).row { point.y += trayHeight(tray) }
        return point
    }

    /// Height of the canvas for board rows `0..<rows` with `tray` open.
    func height(rows: Int, tray: StackTray?) -> CGFloat {
        height(rows: rows) + (tray.map(trayHeight) ?? 0)
    }
}
