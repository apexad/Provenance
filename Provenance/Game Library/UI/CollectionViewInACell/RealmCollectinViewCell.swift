//
//  RecentlyPlayedCollectionCell.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/15/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation

protocol RealmCollectinViewCellDelegate {
	func didSelectObject(_ : Object)
}

protocol RealmCollectionViewCellBase {
	var minimumInteritemSpacing : CGFloat { get}
}

extension RealmCollectionViewCellBase {
	var minimumInteritemSpacing : CGFloat {
		#if os(tvOS)
		return 50
		#else
		return 5.0
		#endif
	}
}

class RealmCollectinViewCell<CellClass:UICollectionViewCell, SelectionObject:Object> : UICollectionViewCell, RealmCollectionViewCellBase, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate, UICollectionViewDataSource {
	var queryUpdateToken: NotificationToken?
	var selectionDelegate : RealmCollectinViewCellDelegate?

	let query: Results<SelectionObject>
	let cellId : String

	var numberOfRows = 1

	var subCellSize : CGSize {
		return CGSize(width: 124, height: 144)
	}

	lazy var layout : CenterViewFlowLayout = {
		let layout = CenterViewFlowLayout()
		layout.scrollDirection = .horizontal
		layout.minimumLineSpacing = 0
		layout.minimumInteritemSpacing = minimumInteritemSpacing

		let spacing : CGFloat = numberOfRows > 1 ? 36 + 5 : 36
		let height = max(0, (self.bounds.height / CGFloat(numberOfRows)) - spacing)
		let minimumItemsPerPageRow : CGFloat = 3.0
		let width = self.bounds.width - ((layout.minimumInteritemSpacing) * (minimumItemsPerPageRow) * 0.5)
		//		let square = min(width, height)
		let square = 120
		// TODO : Fix me, hard coded these cause the maths are weird with CenterViewFlowLayout and margins - Joe M
		layout.itemSize = subCellSize
		return layout
	}()

	lazy var internalCollectionView: UICollectionView = {
		let collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.layout)
		collectionView.translatesAutoresizingMaskIntoConstraints = false
		collectionView.showsHorizontalScrollIndicator = false
		collectionView.showsVerticalScrollIndicator = false
		#if os(iOS)
		collectionView.isPagingEnabled = true
		#endif
		collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 2, left: 2, bottom: 0, right: 2)
		collectionView.indicatorStyle = .white
		return collectionView
	}()

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	init(frame: CGRect, query : Results<SelectionObject>, cellId : String) {
		self.cellId = cellId
		self.query = query
		super.init(frame: frame)
		setupViews()
		setupToken()
	}

	func setupViews() {
		#if os(iOS)
		backgroundColor = Theme.currentTheme.gameLibraryBackground
		#endif

		addSubview(internalCollectionView)

		internalCollectionView.delegate = self
		internalCollectionView.dataSource = self

		registerSubCellClass()
		internalCollectionView.frame = self.bounds

		if #available(iOS 9.0, tvOS 9.0, *) {
			let margins = self.layoutMarginsGuide

			internalCollectionView.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: 8).isActive = true
			internalCollectionView.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: 8).isActive = true
			internalCollectionView.heightAnchor.constraint(equalTo: margins.heightAnchor, constant: 0).isActive = true
		} else {
			NSLayoutConstraint(item: internalCollectionView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leadingMargin, multiplier: 1.0, constant: 8.0).isActive = true
			NSLayoutConstraint(item: internalCollectionView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailingMargin, multiplier: 1.0, constant: 8.0).isActive = true
			NSLayoutConstraint(item: internalCollectionView, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1.0, constant:0.0).isActive = true
		}
		#if os(iOS)
		internalCollectionView.backgroundColor = Theme.currentTheme.gameLibraryBackground
		#endif

		// setup page indicator layout
		self.addSubview(pageIndicator)
		if #available(iOS 9.0, tvOS 9.0, *) {
			let margins = self.layoutMarginsGuide

			pageIndicator.leadingAnchor.constraint(lessThanOrEqualTo: margins.leadingAnchor, constant: 8).isActive = true
			pageIndicator.trailingAnchor.constraint(lessThanOrEqualTo: margins.trailingAnchor, constant: 8).isActive = true
			pageIndicator.centerXAnchor.constraint(equalTo: margins.centerXAnchor).isActive = true
			pageIndicator.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: 0).isActive = true
			pageIndicator.heightAnchor.constraint(equalToConstant: 36).isActive = true
			pageIndicator.numberOfPages = layout.numberOfPages
		} else {
			NSLayoutConstraint(item: pageIndicator, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerXWithinMargins, multiplier: 1.0, constant: 0).isActive = true
			NSLayoutConstraint(item: pageIndicator, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant:0.0).isActive = true
			NSLayoutConstraint(item: pageIndicator, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1.0, constant: 36).isActive = true
			NSLayoutConstraint(item: pageIndicator, attribute: .leading, relatedBy: .lessThanOrEqual, toItem: self, attribute: .leadingMargin, multiplier: 1.0, constant: 8.0).isActive = true
			NSLayoutConstraint(item: pageIndicator, attribute: .trailing, relatedBy: .lessThanOrEqual, toItem: self, attribute: .trailingMargin, multiplier: 1.0, constant: 8.0).isActive = true
		}
		//internalCollectionView
	}

	func registerSubCellClass() {
		internalCollectionView.register(CellClass.self, forCellWithReuseIdentifier: cellId)
	}

	override func layoutMarginsDidChange() {
		super.layoutMarginsDidChange()
		internalCollectionView.flashScrollIndicators()
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		selectionDelegate = nil
		queryUpdateToken?.invalidate()
		queryUpdateToken = nil
	}

	lazy var pageIndicator : UIPageControl = {
		let pageIndicator = UIPageControl(frame: CGRect(origin: CGPoint(x: bounds.midX - 38.2, y: bounds.maxY-18), size: CGSize(width:38, height:36)))
		pageIndicator.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
		pageIndicator.translatesAutoresizingMaskIntoConstraints = false
		#if os(iOS)
		pageIndicator.currentPageIndicatorTintColor = Theme.currentTheme.defaultTintColor
		pageIndicator.pageIndicatorTintColor = Theme.currentTheme.gameLibraryText
		#endif
		return pageIndicator
	}()

	// ----
	private func setupToken() {
		queryUpdateToken = query.observe { [unowned self] (changes: RealmCollectionChange) in
			switch changes {
			case .initial(let result):
				DLOG("Initial query result: \(result.count)")
				DispatchQueue.main.async {
					self.internalCollectionView.reloadData()
					self.pageIndicator.numberOfPages = self.layout.numberOfPages
				}
			case .update(_, let deletions, let insertions, let modifications):
				// Query results have changed, so apply them to the UICollectionView
				self.handleUpdate(deletions: deletions, insertions: insertions, modifications: modifications)
			case .error(let error):
				// An error occurred while opening the Realm file on the background worker thread
				fatalError("\(error)")
			}
		}
	}

	func handleUpdate( deletions: [Int], insertions: [Int], modifications: [Int]) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
			self.internalCollectionView.reloadData()
			self.pageIndicator.numberOfPages = self.layout.numberOfPages
		}
		//		internalCollectionView.performBatchUpdates({
		//			ILOG("Section SaveStates updated with Insertions<\(insertions.count)> Mods<\(modifications.count)> Deletions<\(deletions.count)>")
		//			internalCollectionView.insertItems(at: insertions.map({ return IndexPath(row: $0, section: 0) }))
		//			internalCollectionView.deleteItems(at: deletions.map({  return IndexPath(row: $0, section: 0) }))
		//			internalCollectionView.reloadItems(at: modifications.map({  return IndexPath(row: $0, section: 0) }))
		//		}, completion: { (completed) in
		//
		//		})
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		let pageIndicatorHeight = pageIndicator.frame.height
		let spacing : CGFloat = numberOfRows > 1 ? minimumInteritemSpacing + pageIndicatorHeight : pageIndicatorHeight
		let height = max(0, (collectionView.frame.size.height / CGFloat(numberOfRows)) - spacing)

		let viewWidth = internalCollectionView.bounds.size.width

		let itemsPerRow :CGFloat = viewWidth > 800 ? 6 : 3
		let width :CGFloat = max(0, (viewWidth / itemsPerRow) - (minimumInteritemSpacing * itemsPerRow))

		return CGSize(width: width, height: height)
	}

	/// whether or not dragging has ended
	fileprivate var endDragging = false

	/// the current page
	var currentIndex: Int = 0 {
		didSet {
			updateAccessoryViews()
		}
	}

	// MARK: - UICollectionViewDataSource
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 1
	}

	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		let count = query.count
		return count
	}

	// MARK: - UICollectionViewDelegate
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		let selectedObject = query[indexPath.row]
		selectionDelegate?.didSelectObject(selectedObject)
	}

	// MARK: - UICollectionViewDataSource
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		guard let cell = internalCollectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as? CellClass else {
			fatalError("Couldn't create cell of type ...")
		}

		if indexPath.row < query.count {
			let objectForRow = query[indexPath.row]
			setCellObject(objectForRow, cell: cell)
		}

		return cell
	}

	func setCellObject(_ object : SelectionObject, cell: CellClass) {
		//
		fatalError("Override me")
	}
//}
//
//
//extension RealmCollectinViewCell : UIScrollViewDelegate {

	/**
	Update accessory views (i.e. UIPageControl, UIButtons).
	*/
	func updateAccessoryViews() {
		pageIndicator.numberOfPages = layout.numberOfPages
		pageIndicator.currentPage = currentIndex
	}

	/**
	scroll view did end dragging
	- parameter scrollView: the scroll view
	- parameter decelerate: wether the view is decelerating or not.
	*/
	public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		if !decelerate {
			endScrolling(scrollView)
		} else {
			endDragging = true
		}
	}

	/**
	Scroll view did end decelerating
	*/
	public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		if endDragging {
			endDragging = false
			endScrolling(scrollView)
		}
	}

	/**
	end scrolling
	*/
	fileprivate func endScrolling(_ scrollView: UIScrollView) {
		let width = scrollView.bounds.width
		let page = (scrollView.contentOffset.x + (0.5 * width)) / width
		currentIndex = Int(page)
	}
}

// TODO: This is so similiar to the save states versoin that they can probably be combined by generalziing
// 1) Cell class to use for sub items
// 2) Query and return type

class RecentlyPlayedCollectionCell: RealmCollectinViewCell<PVGameLibraryCollectionViewCell, PVRecentGame> {
	typealias SelectionObject = PVRecentGame
	typealias CellClass = PVGameLibraryCollectionViewCell

	@objc init(frame: CGRect) {
		let recentGamesQuery: Results<SelectionObject> = SelectionObject.all.filter("game != nil").sorted(byKeyPath: #keyPath(SelectionObject.lastPlayedDate), ascending: false)
		super.init(frame: frame, query: recentGamesQuery, cellId: PVGameLibraryCollectionViewCellIdentifier)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func setCellObject(_ object: PVRecentGame, cell: PVGameLibraryCollectionViewCell) {
		cell.game = object.game
	}
}

class SaveStatesCollectionCell: RealmCollectinViewCell<PVSaveStateCollectionViewCell, PVSaveState> {
	typealias SelectionObject = PVSaveState
	typealias CellClass = PVSaveStateCollectionViewCell

	override var subCellSize : CGSize {
		return CGSize(width: 124, height: 144)
	}

	@objc init(frame: CGRect) {
		let saveStatesQuery: Results<SelectionObject> = SelectionObject.all.filter("game != nil").sorted(byKeyPath: #keyPath(SelectionObject.lastOpened), ascending: false).sorted(byKeyPath: #keyPath(SelectionObject.date), ascending: false)
		super.init(frame: frame, query: saveStatesQuery, cellId: "SaveStateView")
	}

	override func registerSubCellClass() {
		#if os(tvOS)
		internalCollectionView.register(UINib(nibName: "PVSaveStateCollectionViewCell~tvOS", bundle: nil), forCellWithReuseIdentifier: "SaveStateView")
		#else
		internalCollectionView.register(UINib(nibName: "PVSaveStateCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "SaveStateView")
		#endif
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func setCellObject(_ object: SelectionObject, cell: PVSaveStateCollectionViewCell) {
		cell.saveState = object
	}
}
