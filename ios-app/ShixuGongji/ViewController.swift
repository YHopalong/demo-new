//
//  ViewController.swift
//  时序躬记
//
//  WKWebView 封装 + 原生文件导入导出桥接
//

import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, UIDocumentPickerDelegate {

    var webView: WKWebView!
    var pendingExportURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        loadApp()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()

        // 允许 JavaScript
        config.preferences.javaScriptEnabled = true
        if #available(iOS 14.0, *) {
            config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        }

        // 消息桥接：JS → Native
        let controller = WKUserContentController()
        controller.add(self, name: "exportData")
        controller.add(self, name: "importData")
        config.userContentController = controller

        // 允许内嵌播放
        config.allowsInlineMediaPlayback = true

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.backgroundColor = UIColor(red: 0.957, green: 0.953, blue: 0.941, alpha: 1.0)
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true

        // 透明滚动条，避免遮挡
        webView.scrollView.indicatorStyle = .default

        view.addSubview(webView)

        // 约束：避开安全区域
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadApp() {
        guard let url = Bundle.main.url(forResource: "workbench-desktop", withExtension: "html", subdirectory: "Web") else {
            print("ERROR: workbench-desktop.html not found in bundle")
            return
        }
        let directory = url.deletingLastPathComponent()
        webView.loadFileURL(url, allowingReadAccessTo: directory)
    }

    // MARK: - WKScriptMessageHandler (JS → Native)

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "exportData":
            handleExport(dataString: message.body as? String ?? "")
        case "importData":
            handleImport()
        default:
            break
        }
    }

    // MARK: - 导出数据

    private func handleExport(dataString: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStr = dateFormatter.string(from: Date())
        let filename = "时序躬记-数据-\(dateStr).json"

        // 写入临时目录
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try dataString.write(to: fileURL, atomically: true, encoding: .utf8)
            pendingExportURL = fileURL

            // 弹出分享面板，用户可保存到「文件」APP / 隔空投送 / 其他应用
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            activityVC.popoverPresentationController?.sourceView = view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            present(activityVC, animated: true)
        } catch {
            showAlert(title: "导出失败", message: error.localizedDescription)
        }
    }

    // MARK: - 导入数据

    private func handleImport() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileURL = urls.first else { return }

        do {
            let jsonString = try String(contentsOf: fileURL, encoding: .utf8)
            // 将文件内容传回 JS
            let escaped = jsonString.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            let js = "window.__nativeImportData && window.__nativeImportData('\(escaped)')"
            webView.evaluateJavaScript(js) { [weak self] _, error in
                if let error = error {
                    self?.showAlert(title: "导入失败", message: error.localizedDescription)
                }
            }
        } catch {
            showAlert(title: "读取文件失败", message: error.localizedDescription)
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 页面加载完成后，注入原生桥接函数
        let bridgeJS = """
        (function(){
          // 覆盖 store.exportData 调用原生分享
          if (window.store && store.exportData) {
            store._originalExport = store.exportData.bind(store);
            store.exportData = function() {
              try {
                window.webkit.messageHandlers.exportData.postMessage(JSON.stringify(data));
              } catch(e) {
                store._originalExport();
              }
            };
          }
          // 覆盖 store.importData 调用原生文件选择器
          if (window.store && store.importData) {
            store._originalImport = store.importData.bind(store);
            document.addEventListener('click', function(e) {
              var btn = e.target.closest && e.target.closest('#btnImport');
              if (btn) {
                e.preventDefault();
                e.stopPropagation();
                try { window.webkit.messageHandlers.importData.postMessage(''); } catch(err) {}
              }
            }, true);
          }
          // 原生回调：导入数据
          window.__nativeImportData = function(jsonStr) {
            try {
              data = JSON.parse(jsonStr);
              store.save().then(function() { render(); alert('导入成功！'); });
            } catch(err) {
              alert('导入失败：' + err.message);
            }
          };
        })();
        """
        webView.evaluateJavaScript(bridgeJS, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView load failed: \(error.localizedDescription)")
    }

    // MARK: - 辅助

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好的", style: .default))
        present(alert, animated: true)
    }

    // 横屏支持
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    // 隐藏状态栏（更像 APP）
    override var prefersStatusBarHidden: Bool {
        return false
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
}
