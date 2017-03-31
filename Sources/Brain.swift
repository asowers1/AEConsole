//
// Brain.swift
//
// Copyright (c) 2016 Marko Tadić <tadija@me.com> http://tadija.net
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import UIKit
import AELog

class Brain: NSObject {
    
    // MARK: - Outlets
    
    var console: View!
    
    // MARK: - Properties
    
    fileprivate let config = Config.shared
    
    var lines = [Line]()
    var filteredLines = [Line]()
    
    var contentWidth: CGFloat = 0.0
    
    var filterText: String? {
        didSet {
            isFilterActive = !isEmpty(filterText)
        }
    }
    
    var isFilterActive = false {
        didSet {
            updateFilter()
            updateInterfaceIfNeeded()
        }
    }
    
    // MARK: - API
    
    func configureConsole(with appDelegate: UIApplicationDelegate) {
        guard let _window = appDelegate.window, let window = _window else { return }

        console = createConsoleView(in: window)
        console.tableView.dataSource = self
        console.tableView.delegate = self
        console.textField.delegate = self
    }
    
    public func configureConsoleUI(with delegate: UIApplicationDelegate, injectedConsoleView: View) {
        guard let _window = delegate.window, let window = _window else { return }
        
        let aConsole = injectedConsoleView
        aConsole.frame = window.bounds
        aConsole.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        aConsole.isOnScreen = Config.shared.isAutoStartEnabled
        window.addSubview(aConsole)
        
        console = aConsole
        console.tableView.dataSource = self
        console.tableView.delegate = self
        console.tableView.rowHeight = UITableViewAutomaticDimension
        console.textField.delegate = self
    }
    
    func addLogLine(_ line: Line) {
        calculateContentWidth(for: line)
        updateFilteredLines(with: line)
        if let lastLine = lines.last, lastLine.message != line.message {
            lines.append(line)
        } else if lines.last == nil {
            lines.append(line)
        }
        updateInterfaceIfNeeded()
    }
    
    func isEmpty(_ text: String?) -> Bool {
        guard let text = text else { return true }
        let characterSet = CharacterSet.whitespacesAndNewlines
        let isTextEmpty = text.trimmingCharacters(in: characterSet).isEmpty
        return isTextEmpty
    }
    
    // MARK: - Actions
    
    func clearLog() {
        lines.removeAll()
        filteredLines.removeAll()
        updateInterfaceIfNeeded()
    }
    
    func exportAllLogLines() {
        let stringLines = lines.map({ $0.description })
        let log = stringLines.joined(separator: "\n")
        
        if isEmpty(log) {
            aelog("Log is empty, nothing to export here.")
        } else {
            writeLog(log)
        }
    }
    
}

extension Brain {
    
    // MARK: - Helpers
    
    fileprivate func updateFilter() {
        if isFilterActive {
            applyFilter()
        } else {
            clearFilter()
        }
    }
    
    private func applyFilter() {
        guard let filter = filterText else { return }
        aelog("Filter Lines [\(isFilterActive)] - <\(filter)>")
        let filtered = lines.filter({ $0.description.localizedCaseInsensitiveContains(filter) })
        filteredLines = filtered
    }
    
    private func clearFilter() {
        aelog("Filter Lines [\(isFilterActive)]")
        filteredLines.removeAll()
    }
    
    fileprivate func updateInterfaceIfNeeded() {
        if console.isOnScreen {
            console.updateUI()
        }
    }
    
    fileprivate func createConsoleView(in window: UIWindow) -> View {
        let view = View()
        
        view.frame = window.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.isOnScreen = config.isAutoStartEnabled
        window.addSubview(view)
        
        return view
    }
    
    fileprivate func calculateContentWidth(for line: Line) {
        contentWidth = UIScreen.main.bounds.width
    }
    
    fileprivate func updateFilteredLines(with line: Line) {
        if isFilterActive {
            guard let filter = filterText else { return }
            if line.description.contains(filter) {
                filteredLines.append(line)
            }
        }
    }
    
    private func getWidth(for line: Line) -> CGFloat {
        let text = line.description
        let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: config.rowHeight)
        let options = NSStringDrawingOptions.usesLineFragmentOrigin
        let attributes = [NSFontAttributeName : config.consoleFont]
        let nsText = text as NSString
        let size = nsText.boundingRect(with: maxSize, options: options, attributes: attributes, context: nil)
        let width = size.width
        return width
    }
    
    fileprivate func writeLog(_ log: String) {
        let filename = "\(Date().timeIntervalSince1970).aelog"
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let documentsURL = URL(fileURLWithPath: documentsPath)
        let fileURL = documentsURL.appendingPathComponent(filename)
        
        do {
            try log.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
            aelog("Log is exported to path: \(fileURL)")
        } catch {
            aelog(error)
        }
    }
    
}

extension Brain: UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let rows = isFilterActive ? filteredLines : lines
        return rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Cell.identifier) as! Cell
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let rows = isFilterActive ? filteredLines : lines
        let logLine = rows[indexPath.row]
        cell.textLabel?.text = logLine.description
    }
    
    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = lines.reduce("\n ") { $0 + $1.message + "\n" }
    }
    
    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        if action == "copy:" {
            return true
        }
        
        return false
    }
    
    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            console.currentOffsetX = scrollView.contentOffset.x
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        console.currentOffsetX = scrollView.contentOffset.x
    }
    
}

extension Brain: UITextFieldDelegate {
    
    // MARK: - UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if !isEmpty(textField.text) {
            filterText = textField.text
        }
        return true
    }
    
}
