//
//  PagingMenuViewController.swift
//  PagingViewController
//
//  Created by Kazuhiro Hayashi on 7/2/17.
//  Copyright © 2017 Kazuhiro Hayashi. All rights reserved.
//

import UIKit

public protocol PagingMenuViewControllerDelegate: class {
    func menuViewController(viewController: PagingMenuViewController,  focusViewDidEndTransition focusView: PagingMenuFocusView)
    func menuViewController(viewController: PagingMenuViewController, didSelect page: Int, previousPage: Int)
}

extension PagingMenuViewControllerDelegate {
    public func menuViewController(viewController: PagingMenuViewController,  focusViewDidEndTransition focusView: PagingMenuFocusView) {}
}

public protocol PagingMenuViewControllerDataSource: class {
    func numberOfItemForMenuViewController(viewController: PagingMenuViewController) -> Int
    func menuViewController(viewController: PagingMenuViewController, cellForItemAt index: Int) -> PagingMenuCell
    func menuViewController(viewController: PagingMenuViewController, areaForItemAt index: Int) -> CGFloat
}

public class PagingMenuFocusView: UIView {
    var selectedIndex: Int?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

public class PagingMenuViewController: UIViewController {
    public weak var delegate: PagingMenuViewControllerDelegate?
    public weak var dataSource: PagingMenuViewControllerDataSource?
    
    fileprivate var focusView = PagingMenuFocusView(frame: .zero)
    
    public var focusPointerOffset: CGPoint {
        return focusView.center
    }

    public var percentOffset: CGFloat {
        return menuView.contentOffset.x / menuView.contentSize.width
    }
    
    public func scroll(index: Int, percent: CGFloat = 0, animated: Bool = true) {
        let rightIndex = index + 1

        guard let leftFrame = menuView.rectForItem(at: index),
            let rightFrame = menuView.rectForItem(at: rightIndex) else { return }
        
        let width = (rightFrame.width - leftFrame.width) * percent + leftFrame.width
        let height = (rightFrame.height - leftFrame.height) * percent + leftFrame.height
        focusView.frame.size = CGSize(width: width, height: height)
        
        let centerPointX = leftFrame.midX + (rightFrame.midX - leftFrame.midX) * percent
        let offsetX = centerPointX - menuView.bounds.width / 2
        let maxOffsetX = max(0, menuView.contentSize.width - menuView.bounds.width)
        let normaizedOffsetX = min(max(0, offsetX), maxOffsetX)
        
        let centerPointY = leftFrame.midY + (rightFrame.midY - leftFrame.midY) * percent
        let offsetY = centerPointY - menuView.bounds.height / 2
        let maxOffsetY = max(0, menuView.contentSize.height - menuView.bounds.height)
        let normaizedOffsetY = min(max(0, offsetY), maxOffsetY)
        let offset = CGPoint(x: normaizedOffsetX, y:normaizedOffsetY)
        
        focusView.center = CGPoint(x: centerPointX, y: centerPointY)
        
        menuView.setContentOffset(offset, animated: animated)
        focusView.selectedIndex = index
        
        if percent == 0 && !animated {
            delegate?.menuViewController(viewController: self, focusViewDidEndTransition: focusView)
        }
    }
    
    public var visibleCells: [PagingMenuCell] {
        return menuView.visibleCell
    }
    
    public var currentFocusedCell: PagingMenuCell? {
        return menuView.indexForItem(at: focusView.center).flatMap(menuView.cellForItem)
    }
    
    public var currentFocusedIndex: Int? {
        return menuView.indexForItem(at: focusView.center)
    }
    
    public func cellForItem(at index: Int) -> PagingMenuCell? {
        return menuView.cellForItem(at: index)
    }
    
    public func registerFocusView(view: UIView, isBehindCell: Bool = false) {
        view.translatesAutoresizingMaskIntoConstraints = true
        view.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleWidth, .flexibleHeight]
        view.frame = focusView.bounds
        focusView.addSubview(view)
        focusView.layer.zPosition = isBehindCell ? -1 : 0
    }
    
    public func registerFocusView(nib: UINib, isBehindCell: Bool = false) {
        let view = nib.instantiate(withOwner: self, options: nil).first as! UIView
        registerFocusView(view: view, isBehindCell: isBehindCell)
    }
    
    public func register(nib: UINib?, forCellWithReuseIdentifier identifier: String) {
        menuView.register(nib: nib, with: identifier)
    }
    
    public func dequeueReusableCell(withReuseIdentifier identifier: String, for index: Int) -> PagingMenuCell {
        return menuView.dequeue(with: identifier)
    }
    
    public func reloadDate(startingOn index: Int? = nil, completionHandler: ((Bool) -> Void)? = nil) {
        UIView.animate(
            withDuration: 0,
            animations: { [weak self] in
                self?.menuView.reloadData()
            },
            completion: {  [weak self] (finish) in
                if let index = index {
                    guard let _self = self else { return }
                    _self.scroll(index: index, percent: 0, animated: false)
                    completionHandler?(finish)
                }
            }
        )
    }
    
    fileprivate var menuView: PagingMenuView = {
        let view = PagingMenuView(frame: .zero)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.translatesAutoresizingMaskIntoConstraints = true
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleTopMargin, .flexibleLeftMargin]
        return view
    }()
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        menuView.delegate = self
        menuView.dataSource = self

        menuView.frame = view.bounds
        view.addSubview(menuView)
        
        view.backgroundColor = .clear

        focusView.frame = menuView.bounds
        menuView.addSubview(focusView)
    }
    
    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutHandler?()
    }
    
    var layoutHandler: (() -> Void)?
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        let index = menuView.indexForItem(at: focusView.center)
        layoutHandler = { [weak self] in
            self?.scroll(index: index ?? 0, percent: 0, animated: false)
            self?.layoutHandler = nil
        }
    }
}

extension PagingMenuViewController: PagingMenuViewDelegate {
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        delegate?.menuViewController(viewController: self, focusViewDidEndTransition: focusView)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            delegate?.menuViewController(viewController: self, focusViewDidEndTransition: focusView)
        }
    }
    
    public func pagingMenuView(pagingMenuView: PagingMenuView, didSelectItemAt index: Int) {
        guard let itemFrame = pagingMenuView.rectForItem(at: index) else { return }
        
        delegate?.menuViewController(viewController: self, didSelect: index, previousPage: focusView.selectedIndex ?? 0)
        
        focusView.selectedIndex = index
        
        let offset: CGPoint
        let offsetX = itemFrame.midX - menuView.bounds.width / 2
        let maxOffsetX = menuView.contentSize.width - menuView.bounds.width
        offset = CGPoint(x: min(max(0, offsetX), maxOffsetX), y: 0)
        menuView.setContentOffset(offset, animated: true)
        
        UIView.perform(.delete, on: [], options: UIViewAnimationOptions(rawValue: 0), animations: { [weak self] in
            self?.focusView.frame = itemFrame
            self?.view.setNeedsLayout()
            self?.view.layoutIfNeeded()
        }, completion: { [weak self] finish in
            guard let _self = self, finish else { return }
            _self.delegate?.menuViewController(viewController: _self, focusViewDidEndTransition: _self.focusView)
        })
    }
}

extension PagingMenuViewController: PagingMenuViewDataSource {
    public func numberOfItemForPagingMenuView() -> Int {
        return dataSource?.numberOfItemForMenuViewController(viewController: self) ?? 0
    }
    
    public func pagingMenuView(pagingMenuView: PagingMenuView, widthForItemAt index: Int) -> CGFloat {
        let area = dataSource?.menuViewController(viewController: self, areaForItemAt: index) ?? 0
        return area
    }

    public func pagingMenuView(pagingMenuView: PagingMenuView, cellForItemAt index: Int) -> PagingMenuCell {
        return dataSource!.menuViewController(viewController: self, cellForItemAt: index)
    }
}

